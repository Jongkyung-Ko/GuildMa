#!/usr/bin/env python3
"""Split weapons_4x4_sheet.png into transparent icons under assets/items/."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tools" / "item_sheets" / "weapons_4x4_sheet.png"
OUT = ROOT / "assets" / "items"

NAMES = [
    ["rusty_sword", "iron_sword", "steel_arming_sword", "ornate_sword"],
    ["scimitar", "twin_daggers", "gem_dagger", "hand_axe"],
    ["battle_axe", "double_axe", "spiked_mace", "flanged_mace"],
    ["lion_hammer", "spiked_flail", "ornate_rapier", "ritual_dagger"],
]


def remove_black_bg(cell: Image.Image, thresh: int = 16) -> Image.Image:
    arr = np.array(cell.convert("RGBA"))
    rgb = arr[..., :3].astype(np.int16)
    near_black = (rgb[:, :, 0] <= thresh) & (rgb[:, :, 1] <= thresh) & (rgb[:, :, 2] <= thresh)
    out = arr.copy()
    out[..., 3] = np.where(near_black, 0, arr[..., 3]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def trim_and_pad(cell: Image.Image, size: int = 256, pad_ratio: float = 0.06) -> Image.Image:
    bbox = cell.split()[-1].getbbox()
    if not bbox:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cropped = cell.crop(bbox)
    cw, ch = cropped.size
    side = max(cw, ch)
    pad = int(side * pad_ratio)
    canvas = Image.new("RGBA", (side + pad * 2, side + pad * 2), (0, 0, 0, 0))
    canvas.paste(cropped, ((canvas.size[0] - cw) // 2, (canvas.size[1] - ch) // 2), cropped)
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    im = Image.open(SRC).convert("RGBA")
    w, h = im.size
    cw, ch = w // 4, h // 4
    for r in range(4):
        for c in range(4):
            name = NAMES[r][c]
            cell = remove_black_bg(im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)))
            icon = trim_and_pad(cell, 256)
            icon.save(OUT / f"{name}.png")
            print("wrote", name)


if __name__ == "__main__":
    main()
