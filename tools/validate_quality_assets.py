#!/usr/bin/env python3
"""GuildMaster quality asset/data gates (automatable).

Checks (items catalog + linked icons by default):
  - duplicate IDs
  - missing icon paths
  - resolution (>= 256)
  - format (PNG)
  - transparency / alpha channel (+ corner alpha sample when Pillow available)
  - placeholder candidate list (manifest + heuristics)
  - counts by category
  - bad refs (empty icon, non-res path, identical-byte collisions)

Visual style is NEVER auto-approved. Exit 0 only when hard gates pass.
Soft findings (identical bytes, tiny files, declared placeholders) are
reported but do not fail by default. Pass --strict to fail on soft findings.
Visual style is NEVER auto-approved.

Usage:
  python3 tools/validate_quality_assets.py
  python3 tools/validate_quality_assets.py --json
  python3 tools/validate_quality_assets.py --strict
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import struct
import sys
from collections import Counter, defaultdict
from typing import Any, Dict, List, Optional, Tuple

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ITEMS_JSON = os.path.join(ROOT, "data", "items.json")
PLACEHOLDER_MANIFEST = os.path.join(
    ROOT, "docs", "standards", "placeholder_assets.manifest.json"
)
MIN_ICON_PX = 256


def _rel(path: str) -> str:
    return os.path.relpath(path, ROOT).replace("\\", "/")


def load_items(path: str) -> List[Dict[str, Any]]:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, dict) and "items" in data:
        return list(data["items"])
    if isinstance(data, list):
        return list(data)
    raise ValueError("items.json must be a list or {items: [...]}")


def load_placeholder_manifest(path: str) -> Dict[str, Any]:
    if not os.path.isfile(path):
        return {"declared_placeholders": [], "notes": "manifest missing"}
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def res_to_fs(res_path: str) -> Optional[str]:
    if not res_path or not isinstance(res_path, str):
        return None
    if res_path.startswith("res://"):
        return os.path.join(ROOT, res_path[len("res://") :])
    return os.path.join(ROOT, res_path)


def png_ihdr(path: str) -> Dict[str, Any]:
    info: Dict[str, Any] = {"path": path}
    try:
        with open(path, "rb") as f:
            sig = f.read(8)
            if sig != b"\x89PNG\r\n\x1a\n":
                info["error"] = "not_png"
                return info
            while True:
                hdr = f.read(8)
                if len(hdr) < 8:
                    break
                length, ctype = struct.unpack(">I4s", hdr)
                data = f.read(length)
                f.read(4)  # crc
                if ctype == b"IHDR":
                    w, h, bit, color, _c, _f, _i = struct.unpack(">IIBBBBB", data)
                    info.update(
                        {
                            "w": w,
                            "h": h,
                            "bit_depth": bit,
                            "color_type": color,
                            "has_alpha_chunk_hint": color in (4, 6),
                        }
                    )
                elif ctype == b"tRNS":
                    info["has_trns"] = True
                elif ctype == b"IEND":
                    break
    except OSError as e:
        info["error"] = str(e)
    return info


def pillow_alpha_corners(path: str) -> Optional[Dict[str, Any]]:
    try:
        from PIL import Image  # type: ignore
    except Exception:
        return None
    im = Image.open(path)
    mode = im.mode
    rgba = im.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()
    corners = [
        px[0, 0][3],
        px[w - 1, 0][3],
        px[0, h - 1][3],
        px[w - 1, h - 1][3],
    ]
    # crude opaque-rect heuristic: all corners fully opaque AND very few transparent pixels
    sample_step = max(1, min(w, h) // 32)
    transparent = 0
    total = 0
    for y in range(0, h, sample_step):
        for x in range(0, w, sample_step):
            total += 1
            if px[x, y][3] < 16:
                transparent += 1
    return {
        "mode": mode,
        "corner_alpha": corners,
        "sample_transparent_ratio": (transparent / total) if total else 0.0,
    }


def file_sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser(description="GuildMaster quality asset gates")
    ap.add_argument("--json", action="store_true", help="print machine-readable JSON")
    ap.add_argument(
        "--strict",
        action="store_true",
        help="also fail on soft findings (dup bytes, declared placeholders, tiny files)",
    )
    ap.add_argument(
        "--min-px",
        type=int,
        default=MIN_ICON_PX,
        help="minimum icon width/height (default 256)",
    )
    args = ap.parse_args()

    hard_fails: List[str] = []
    soft_fails: List[str] = []
    passes: List[str] = []
    report: Dict[str, Any] = {
        "visual_style_auto_approved": False,
        "note": "Automation never approves visual style.",
    }

    if not os.path.isfile(ITEMS_JSON):
        hard_fails.append(f"missing { _rel(ITEMS_JSON) }")
        return _emit(args, report, hard_fails, soft_fails, passes)

    items = load_items(ITEMS_JSON)
    report["item_count"] = len(items)
    passes.append(f"loaded items.json count={len(items)}")

    # --- IDs ---
    ids = [str(it.get("id", "")) for it in items]
    id_counts = Counter(ids)
    dup_ids = sorted([i for i, n in id_counts.items() if i and n > 1])
    empty_ids = sum(1 for i in ids if not i)
    if empty_ids:
        hard_fails.append(f"{empty_ids} items missing id")
    if dup_ids:
        hard_fails.append(f"duplicate item ids: {', '.join(dup_ids)}")
    else:
        passes.append("item ids unique")

    # --- categories / counts ---
    cats = Counter(str(it.get("category", "")) for it in items)
    report["category_counts"] = dict(cats)
    passes.append("category counts: " + ", ".join(f"{k or '?'}={v}" for k, v in sorted(cats.items())))

    # --- paths / format / resolution / transparency ---
    missing_paths: List[str] = []
    bad_refs: List[str] = []
    low_res: List[str] = []
    not_png: List[str] = []
    no_alpha: List[str] = []
    opaque_rect: List[str] = []
    icon_files: List[str] = []

    for it in items:
        iid = str(it.get("id", "?"))
        icon = it.get("icon", "")
        if not icon:
            bad_refs.append(f"{iid}: empty icon")
            continue
        if not str(icon).startswith("res://"):
            bad_refs.append(f"{iid}: icon not res:// ({icon})")
        fs = res_to_fs(str(icon))
        if fs is None or not os.path.isfile(fs):
            missing_paths.append(f"{iid}: {icon}")
            continue
        icon_files.append(fs)
        info = png_ihdr(fs)
        if info.get("error") == "not_png":
            not_png.append(f"{iid}: {_rel(fs)}")
            continue
        if info.get("error"):
            bad_refs.append(f"{iid}: read error {info['error']}")
            continue
        w, h = int(info.get("w") or 0), int(info.get("h") or 0)
        if w < args.min_px or h < args.min_px:
            low_res.append(f"{iid}: {w}x{h} < {args.min_px}")
        alphaish = bool(info.get("has_alpha_chunk_hint")) or bool(info.get("has_trns"))
        pillow = pillow_alpha_corners(fs)
        if pillow:
            report.setdefault("pillow", True)
            if pillow["mode"] not in ("RGBA", "LA", "PA") and not alphaish:
                no_alpha.append(f"{iid}: mode={pillow['mode']}")
            # heuristic: no meaningful transparency → possible solid rect placeholder
            if pillow["sample_transparent_ratio"] < 0.005 and min(pillow["corner_alpha"]) > 250:
                opaque_rect.append(f"{iid}: appears fully opaque (possible solid rect)")
        elif not alphaish:
            no_alpha.append(f"{iid}: color_type={info.get('color_type')} (no alpha hint)")

    if missing_paths:
        hard_fails.append(f"{len(missing_paths)} missing icon paths")
        report["missing_paths"] = missing_paths
    else:
        passes.append("all item icon paths resolve")

    if bad_refs:
        hard_fails.append(f"{len(bad_refs)} bad icon refs")
        report["bad_refs"] = bad_refs
    else:
        passes.append("no empty/non-res icon refs among checked items")

    if not_png:
        hard_fails.append(f"{len(not_png)} non-PNG icons")
        report["not_png"] = not_png
    else:
        passes.append("linked icons are PNG")

    if low_res:
        hard_fails.append(f"{len(low_res)} icons below {args.min_px}px")
        report["low_res"] = low_res
    else:
        passes.append(f"linked icons >= {args.min_px}px")

    if no_alpha:
        hard_fails.append(f"{len(no_alpha)} icons without alpha channel hint")
        report["no_alpha"] = no_alpha
    else:
        passes.append("linked icons report alpha/transparency")

    if opaque_rect:
        soft_fails.append(f"{len(opaque_rect)} icons look fully opaque (review for placeholders)")
        report["opaque_rect_candidates"] = opaque_rect

    # --- identical bytes among linked icons ---
    hash_map: Dict[str, List[str]] = defaultdict(list)
    for fs in icon_files:
        hash_map[file_sha256(fs)].append(_rel(fs))
    identical = [paths for paths in hash_map.values() if len(paths) > 1]
    if identical:
        soft_fails.append(f"{len(identical)} identical-byte icon groups (possible unintended reuse)")
        report["identical_byte_groups"] = identical
    else:
        passes.append("no identical-byte collisions among linked icons")

    # --- placeholder manifesto + tiny-file heuristic on assets/items ---
    manifest = load_placeholder_manifest(PLACEHOLDER_MANIFEST)
    declared = [str(x) for x in manifest.get("declared_placeholders", [])]
    report["declared_placeholders"] = declared
    report["declared_placeholder_count"] = len(declared)
    if declared:
        soft_fails.append(
            f"{len(declared)} declared placeholders in {_rel(PLACEHOLDER_MANIFEST)} "
            "(must not be claimed as final art)"
        )
    else:
        passes.append("placeholder manifest has zero declared entries")

    items_dir = os.path.join(ROOT, "assets", "items")
    tiny: List[str] = []
    if os.path.isdir(items_dir):
        pngs = [f for f in os.listdir(items_dir) if f.endswith(".png")]
        report["assets_items_png_count"] = len(pngs)
        for name in pngs:
            p = os.path.join(items_dir, name)
            if os.path.getsize(p) < 1500:
                tiny.append(_rel(p))
    if tiny:
        soft_fails.append(f"{len(tiny)} very small PNGs under assets/items (<1500B) — review")
        report["tiny_png_candidates"] = tiny

    report["passes"] = passes
    report["hard_fails"] = hard_fails
    report["soft_fails"] = soft_fails

    return _emit(args, report, hard_fails, soft_fails, passes)


def _emit(
    args: argparse.Namespace,
    report: Dict[str, Any],
    hard_fails: List[str],
    soft_fails: List[str],
    passes: List[str],
) -> int:
    failed = bool(hard_fails) or (bool(soft_fails) and args.strict)
    report["result"] = "FAIL" if failed else "PASS"
    report["strict"] = bool(args.strict)

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print("=== validate_quality_assets (Python) ===")
        for msg in passes:
            print(f"OK: {msg}")
        for msg in soft_fails:
            print(f"SOFT: {msg}")
        for msg in hard_fails:
            print(f"FAIL: {msg}")
        if soft_fails and not args.strict:
            print("NOTE: soft findings reported; use --strict to fail on them")
        print(
            "NOTE: visual style is NEVER auto-approved by this script."
        )
        print(f"=== RESULT: {report['result']} ===")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
