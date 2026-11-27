#!/usr/bin/env python3
"""Generate consistent square fantasy item icons for GuildMaster shop/blacksmith."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / "assets" / "sprites" / "items"
SIZE = 64


def new_canvas() -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    # soft wood-plank tile behind silhouette
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((2, 2, 61, 61), radius=8, fill=(42, 28, 18, 230))
    d.rounded_rectangle((4, 4, 59, 59), radius=7, fill=(58, 40, 26, 255))
    for y in range(8, 58, 7):
        d.line((8, y, 56, y), fill=(70, 48, 30, 90), width=1)
    return img


def shade(c: tuple[int, int, int], f: float) -> tuple[int, int, int]:
    return tuple(max(0, min(255, int(v * f))) for v in c)


def draw_sword(d: ImageDraw.ImageDraw, tip_y: int, hilt_y: int, color: tuple[int, int, int], gem=None) -> None:
    # blade
    d.polygon([(32, tip_y), (38, hilt_y - 4), (26, hilt_y - 4)], fill=color)
    d.line([(32, tip_y + 2), (32, hilt_y - 6)], fill=shade(color, 1.25), width=1)
    # guard
    d.rectangle((22, hilt_y - 4, 42, hilt_y), fill=(180, 150, 70))
    # grip
    d.rectangle((29, hilt_y, 35, hilt_y + 12), fill=(90, 55, 35))
    d.rectangle((28, hilt_y + 12, 36, hilt_y + 16), fill=(200, 170, 80))
    if gem:
        d.ellipse((30, hilt_y + 3, 34, hilt_y + 7), fill=gem)


def draw_axe(d: ImageDraw.ImageDraw) -> None:
    d.rectangle((30, 10, 34, 52), fill=(110, 70, 40))
    d.polygon([(34, 14), (52, 20), (52, 34), (34, 30)], fill=(170, 175, 185))
    d.polygon([(34, 16), (48, 22), (48, 30), (34, 28)], fill=(210, 215, 225))
    d.ellipse((28, 50, 36, 56), fill=(80, 50, 30))


def draw_dagger(d: ImageDraw.ImageDraw) -> None:
    d.polygon([(32, 8), (36, 30), (28, 30)], fill=(200, 210, 230))
    d.line([(32, 10), (32, 28)], fill=(240, 245, 255), width=1)
    d.rectangle((24, 30, 40, 34), fill=(160, 120, 50))
    d.rectangle((29, 34, 35, 48), fill=(70, 40, 90))
    d.ellipse((28, 48, 36, 54), fill=(180, 140, 60))


def draw_staff(d: ImageDraw.ImageDraw) -> None:
    d.rectangle((30, 18, 34, 56), fill=(120, 80, 40))
    d.ellipse((24, 8, 40, 24), fill=(90, 160, 210))
    d.ellipse((27, 11, 37, 21), fill=(140, 210, 240))
    d.ellipse((30, 14, 34, 18), fill=(220, 250, 255))


def draw_rune_blade(d: ImageDraw.ImageDraw) -> None:
    draw_sword(d, 8, 40, (150, 160, 210), gem=(120, 80, 220))
    for y in (16, 22, 28):
        d.line([(29, y), (35, y)], fill=(180, 140, 255), width=1)


def draw_armor_leather(d: ImageDraw.ImageDraw) -> None:
    d.polygon([(20, 18), (44, 18), (48, 50), (16, 50)], fill=(140, 90, 50))
    d.polygon([(24, 22), (40, 22), (42, 46), (22, 46)], fill=(170, 115, 65))
    d.line([(32, 22), (32, 46)], fill=(100, 60, 30), width=2)
    d.ellipse((28, 30, 36, 38), fill=(90, 55, 30))


def draw_armor_chain(d: ImageDraw.ImageDraw) -> None:
    d.polygon([(18, 16), (46, 16), (50, 52), (14, 52)], fill=(120, 125, 135))
    for y in range(20, 50, 5):
        for x in range(20, 46, 6):
            d.ellipse((x, y, x + 4, y + 4), outline=(180, 185, 195))
    d.rectangle((28, 16, 36, 22), fill=(200, 170, 80))


def draw_shield(d: ImageDraw.ImageDraw) -> None:
    d.ellipse((14, 12, 50, 54), fill=(150, 100, 50))
    d.ellipse((18, 16, 46, 50), fill=(180, 130, 70))
    d.ellipse((26, 24, 38, 42), fill=(90, 140, 80))
    d.line([(32, 16), (32, 50)], fill=(120, 80, 40), width=2)
    d.line([(18, 32), (46, 32)], fill=(120, 80, 40), width=2)


def draw_helm(d: ImageDraw.ImageDraw) -> None:
    d.ellipse((16, 14, 48, 44), fill=(150, 155, 165))
    d.rectangle((16, 30, 48, 46), fill=(130, 135, 145))
    d.rectangle((22, 32, 42, 40), fill=(30, 30, 40))
    d.rectangle((28, 10, 36, 16), fill=(200, 170, 80))


def draw_boots(d: ImageDraw.ImageDraw) -> None:
    d.polygon([(18, 24), (34, 24), (36, 48), (14, 48)], fill=(120, 75, 45))
    d.polygon([(34, 34), (52, 38), (50, 50), (34, 48)], fill=(100, 60, 35))
    d.rectangle((16, 44, 36, 50), fill=(70, 45, 25))


def draw_plate(d: ImageDraw.ImageDraw) -> None:
    d.polygon([(16, 14), (48, 14), (52, 52), (12, 52)], fill=(170, 175, 190))
    d.polygon([(22, 20), (42, 20), (44, 46), (20, 46)], fill=(200, 205, 220))
    d.rectangle((28, 14, 36, 22), fill=(220, 180, 70))
    d.polygon([(32, 26), (38, 36), (32, 42), (26, 36)], fill=(90, 140, 200))


def draw_ring(d: ImageDraw.ImageDraw, metal: tuple[int, int, int], gem: tuple[int, int, int] | None = None) -> None:
    d.ellipse((16, 16, 48, 48), outline=metal, width=6)
    d.ellipse((22, 22, 42, 42), outline=shade(metal, 0.7), width=2)
    if gem:
        d.ellipse((28, 12, 36, 22), fill=gem)
        d.ellipse((30, 14, 34, 18), fill=shade(gem, 1.3))


def draw_amulet(d: ImageDraw.ImageDraw) -> None:
    d.arc((18, 8, 46, 28), 200, 340, fill=(200, 180, 80), width=3)
    d.polygon([(32, 24), (44, 42), (32, 52), (20, 42)], fill=(70, 120, 180))
    d.polygon([(32, 28), (40, 40), (32, 48), (24, 40)], fill=(110, 170, 220))
    d.ellipse((29, 36, 35, 42), fill=(240, 220, 120))


def draw_belt(d: ImageDraw.ImageDraw) -> None:
    d.rectangle((10, 26, 54, 42), fill=(110, 70, 40))
    d.rectangle((12, 28, 52, 40), fill=(140, 90, 50))
    d.rectangle((26, 22, 38, 46), fill=(190, 160, 70))
    d.rectangle((28, 28, 36, 40), fill=(80, 50, 30))


def draw_potion(d: ImageDraw.ImageDraw, liquid: tuple[int, int, int], tall: bool = False) -> None:
    top = 10 if tall else 14
    d.rectangle((28, top, 36, top + 8), fill=(180, 170, 150))
    d.rectangle((26, top + 6, 38, top + 10), fill=(140, 100, 60))
    body_top = top + 10
    d.ellipse((18, body_top, 46, 54), fill=(210, 220, 230, 220))
    d.ellipse((22, body_top + 6, 42, 50), fill=liquid)
    d.ellipse((26, body_top + 10, 32, body_top + 18), fill=shade(liquid, 1.35))


def draw_elixir(d: ImageDraw.ImageDraw) -> None:
    d.polygon([(32, 8), (40, 20), (38, 50), (26, 50), (24, 20)], fill=(200, 210, 220))
    d.polygon([(32, 16), (36, 22), (34, 46), (30, 46), (28, 22)], fill=(220, 90, 50))
    d.ellipse((28, 6, 36, 14), fill=(180, 150, 60))


def draw_ore(d: ImageDraw.ImageDraw, colors: list[tuple[int, int, int]]) -> None:
    pts = [(18, 40), (12, 28), (22, 14), (36, 10), (50, 20), (52, 36), (40, 50), (24, 48)]
    d.polygon(pts, fill=colors[0])
    d.polygon([(22, 28), (30, 16), (40, 22), (36, 34)], fill=colors[1])
    d.polygon([(28, 34), (38, 28), (46, 36), (34, 44)], fill=colors[2])


def draw_crystal(d: ImageDraw.ImageDraw) -> None:
    d.polygon([(32, 8), (48, 28), (40, 54), (24, 54), (16, 28)], fill=(200, 70, 40))
    d.polygon([(32, 12), (42, 28), (36, 48), (28, 48), (22, 28)], fill=(240, 120, 60))
    d.line([(32, 14), (32, 48)], fill=(255, 200, 140), width=2)


def draw_leather_scrap(d: ImageDraw.ImageDraw) -> None:
    d.polygon([(14, 20), (40, 12), (52, 30), (44, 50), (18, 46)], fill=(150, 95, 55))
    d.polygon([(20, 24), (36, 18), (46, 30), (38, 44), (22, 40)], fill=(175, 115, 70))
    d.line([(24, 28), (40, 34)], fill=(100, 60, 35), width=1)
    d.ellipse((30, 30, 34, 34), fill=(80, 50, 30))


def draw_enhance_stone(d: ImageDraw.ImageDraw) -> None:
    d.polygon([(32, 8), (50, 22), (44, 48), (20, 48), (14, 22)], fill=(80, 140, 200))
    d.polygon([(32, 14), (44, 24), (40, 42), (24, 42), (20, 24)], fill=(140, 200, 255))
    d.ellipse((28, 26, 36, 34), fill=(255, 240, 160))
    for a in range(0, 360, 45):
        rad = math.radians(a)
        x2 = 32 + int(math.cos(rad) * 18)
        y2 = 30 + int(math.sin(rad) * 18)
        d.line([(32, 30), (x2, y2)], fill=(255, 230, 140, 180), width=1)


DRAWERS = {
    "sword_basic": lambda d: draw_sword(d, 8, 40, (190, 195, 205)),
    "sword_steel": lambda d: draw_sword(d, 8, 40, (150, 160, 180), gem=(80, 160, 220)),
    "axe_battle": draw_axe,
    "dagger_swift": draw_dagger,
    "staff_oak": draw_staff,
    "blade_rune": draw_rune_blade,
    "armor_leather": draw_armor_leather,
    "armor_chain": draw_armor_chain,
    "shield_wood": draw_shield,
    "helm_iron": draw_helm,
    "boots_leather": draw_boots,
    "plate_guardian": draw_plate,
    "ring_copper": lambda d: draw_ring(d, (180, 110, 60), (200, 80, 60)),
    "ring_silver": lambda d: draw_ring(d, (200, 210, 220), (120, 180, 255)),
    "amulet_ward": draw_amulet,
    "belt_power": draw_belt,
    "potion_hp_s": lambda d: draw_potion(d, (200, 60, 70), False),
    "potion_hp_m": lambda d: draw_potion(d, (220, 40, 55), True),
    "potion_mp_s": lambda d: draw_potion(d, (60, 100, 210), False),
    "potion_mp_m": lambda d: draw_potion(d, (50, 90, 230), True),
    "elixir_str": draw_elixir,
    "ore_iron": lambda d: draw_ore(d, [(90, 95, 100), (140, 145, 150), (70, 75, 80)]),
    "ore_mithril": lambda d: draw_ore(d, [(140, 170, 190), (200, 230, 245), (100, 140, 170)]),
    "crystal_fire": draw_crystal,
    "leather_scrap": draw_leather_scrap,
    "enhance_stone": draw_enhance_stone,
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for item_id, drawer in DRAWERS.items():
        img = new_canvas()
        drawer(ImageDraw.Draw(img, "RGBA"))
        # slight sharpen for pixel-readable silhouette
        img = img.filter(ImageFilter.SMOOTH_MORE)
        path = OUT / f"{item_id}.png"
        img.save(path)
        print("wrote", path)


if __name__ == "__main__":
    main()
