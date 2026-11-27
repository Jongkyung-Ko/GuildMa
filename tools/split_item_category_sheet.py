#!/usr/bin/env python3
"""Split a painted category sheet into ≥256 transparent icons under assets/items/.

Usage:
  python3 tools/split_item_category_sheet.py \\
    --sheet tools/item_sheets/sheet_weapon_1h.png \\
    --names sword_ornate,sword_bronze,sword_knight,club_oak \\
    --cols 2 --rows 2
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "items"


def remove_dark_bg(cell: Image.Image, thresh: int = 22) -> Image.Image:
    arr = np.array(cell.convert("RGBA"))
    rgb = arr[..., :3].astype(np.int16)
    # Near-black OR near-uniform dark purple studio backdrops
    near_black = (rgb[:, :, 0] <= thresh) & (rgb[:, :, 1] <= thresh) & (rgb[:, :, 2] <= thresh)
    # Also punch very dark near-gray backgrounds
    luma = (0.2126 * rgb[:, :, 0] + 0.7152 * rgb[:, :, 1] + 0.0722 * rgb[:, :, 2])
    near_dark = luma <= float(thresh)
    # Soften: only clear where originally opaque-ish
    mask = near_black | near_dark
    out = arr.copy()
    out[..., 3] = np.where(mask, 0, arr[..., 3]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def flood_clear_corners(cell: Image.Image, thresh: int = 28) -> Image.Image:
    """Flood-fill from corners to clear connected dark background."""
    arr = np.array(cell.convert("RGBA"))
    h, w = arr.shape[:2]
    rgb = arr[..., :3].astype(np.int16)
    luma = (0.2126 * rgb[:, :, 0] + 0.7152 * rgb[:, :, 1] + 0.0722 * rgb[:, :, 2])
    is_bg = luma <= float(thresh)
    visited = np.zeros((h, w), dtype=bool)
    stack = [(0, 0), (0, w - 1), (h - 1, 0), (h - 1, w - 1)]
    # also mid-edges
    stack += [(0, w // 2), (h - 1, w // 2), (h // 2, 0), (h // 2, w - 1)]
    while stack:
        y, x = stack.pop()
        if y < 0 or y >= h or x < 0 or x >= w or visited[y, x]:
            continue
        if not is_bg[y, x]:
            continue
        visited[y, x] = True
        stack.extend([(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)])
    out = arr.copy()
    out[..., 3] = np.where(visited, 0, arr[..., 3]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def trim_and_pad(cell: Image.Image, size: int = 256, pad_ratio: float = 0.07) -> Image.Image:
    alpha = cell.split()[-1]
    bbox = alpha.getbbox()
    if not bbox:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cropped = cell.crop(bbox)
    cw, ch = cropped.size
    side = max(cw, ch)
    pad = max(2, int(side * pad_ratio))
    canvas = Image.new("RGBA", (side + pad * 2, side + pad * 2), (0, 0, 0, 0))
    canvas.paste(cropped, ((canvas.size[0] - cw) // 2, (canvas.size[1] - ch) // 2), cropped)
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def split_sheet(sheet: Path, names: list[str], cols: int, rows: int, size: int = 256) -> list[dict]:
    im = Image.open(sheet).convert("RGBA")
    w, h = im.size
    cw, ch = w // cols, h // rows
    results = []
    OUT.mkdir(parents=True, exist_ok=True)
    idx = 0
    for r in range(rows):
        for c in range(cols):
            if idx >= len(names):
                break
            name = names[idx]
            cell = im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
            cell = flood_clear_corners(cell)
            cell = remove_dark_bg(cell)
            icon = trim_and_pad(cell, size=size)
            dest = OUT / f"{name}.png"
            icon.save(dest)
            opaque = sum(1 for p in icon.getdata() if p[3] > 10)
            corner_a = icon.getpixel((0, 0))[3]
            results.append({
                "id": name,
                "path": str(dest.relative_to(ROOT)),
                "size": icon.size,
                "opaque_px": opaque,
                "corner_alpha": corner_a,
                "ok_size": icon.size[0] >= 256 and icon.size[1] >= 256,
                "ok_alpha": corner_a == 0 and opaque > 500,
            })
            print(f"wrote {name} size={icon.size} opaque={opaque} corner_a={corner_a}")
            idx += 1
    return results


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", required=True)
    ap.add_argument("--names", required=True, help="comma-separated item ids left-to-right, top-to-bottom")
    ap.add_argument("--cols", type=int, required=True)
    ap.add_argument("--rows", type=int, required=True)
    ap.add_argument("--size", type=int, default=256)
    args = ap.parse_args()
    names = [n.strip() for n in args.names.split(",") if n.strip()]
    split_sheet(Path(args.sheet), names, args.cols, args.rows, args.size)


if __name__ == "__main__":
    main()
