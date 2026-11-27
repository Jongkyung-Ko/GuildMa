#!/usr/bin/env python3
"""Expand GuildMa items.json to ≥160 with subcategories + unique icons.

Preserves all existing item IDs and their price/stat fields.
Writes assets/items/<id>.png for newly generated icons.
"""
from __future__ import annotations

import hashlib
import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ITEMS_PATH = ROOT / "data" / "items.json"
OUT_DIR = ROOT / "assets" / "items"
SIZE = 64

# Existing catalog IDs that must keep prices/stats unchanged (subcategory may be added).
EXISTING_IDS = {
    "sword_basic", "sword_steel", "axe_battle", "dagger_swift", "staff_oak", "blade_rune",
    "armor_leather", "armor_chain", "shield_wood", "helm_iron", "boots_leather", "plate_guardian",
    "ring_copper", "ring_silver", "amulet_ward", "belt_power",
    "potion_hp_s", "potion_hp_m", "potion_mp_s", "potion_mp_m", "elixir_str",
    "ore_iron", "ore_mithril", "crystal_fire", "leather_scrap", "enhance_stone",
}

SUBCAT_LABELS = {
    "weapon_1h": "한손 무기",
    "weapon_2h": "양손 무기",
    "weapon_ranged": "원거리",
    "weapon_magic": "마법 무기",
    "body": "갑옷",
    "shield": "방패",
    "helm": "투구",
    "gloves": "장갑",
    "boots": "신발",
    "ring": "반지",
    "amulet": "부적",
    "belt": "벨트",
    "cloak": "망토",
    "potion": "물약",
    "elixir": "영약",
    "food": "음식",
    "scroll": "주문서",
    "ore": "광석",
    "crystal": "결정",
    "hide": "가죽/천",
    "part": "부품",
    "special": "특수",
}


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def new_canvas(seed: int, accent=(70, 48, 30)):
    rng = random.Random(seed)
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base = (42 + rng.randint(-4, 4), 28 + rng.randint(-3, 3), 18 + rng.randint(-2, 2), 230)
    fill = (58 + rng.randint(-6, 6), 40 + rng.randint(-4, 4), 26 + rng.randint(-3, 3), 255)
    d.rounded_rectangle((2, 2, 61, 61), radius=8, fill=base)
    d.rounded_rectangle((4, 4, 59, 59), radius=7, fill=fill)
    for y in range(8, 58, 7):
        d.line((8, y, 56, y), fill=(*accent, 90), width=1)
    return img, d


def save_icon(path: Path, img: Image.Image):
    img = img.filter(ImageFilter.SMOOTH_MORE)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


# --- drawers keyed by style family, parameterized by seed/colors ---

def draw_sword(d, tip_y, hilt_y, color, gem=None, guard=(180, 150, 70)):
    d.polygon([(32, tip_y), (38, hilt_y - 4), (26, hilt_y - 4)], fill=color)
    d.line([(32, tip_y + 2), (32, hilt_y - 6)], fill=shade(color, 1.25), width=1)
    d.rectangle((22, hilt_y - 4, 42, hilt_y), fill=guard)
    d.rectangle((29, hilt_y, 35, hilt_y + 12), fill=(90, 55, 35))
    d.rectangle((28, hilt_y + 12, 36, hilt_y + 16), fill=(200, 170, 80))
    if gem:
        d.ellipse((30, hilt_y + 3, 34, hilt_y + 7), fill=gem)


def draw_axe(d, double=False, blade=(170, 175, 185)):
    d.rectangle((30, 10, 34, 52), fill=(110, 70, 40))
    d.polygon([(34, 14), (52, 20), (52, 34), (34, 30)], fill=blade)
    d.polygon([(34, 16), (48, 22), (48, 30), (34, 28)], fill=shade(blade, 1.2))
    if double:
        d.polygon([(30, 14), (12, 20), (12, 34), (30, 30)], fill=blade)
        d.polygon([(30, 16), (16, 22), (16, 30), (30, 28)], fill=shade(blade, 1.2))
    d.ellipse((28, 50, 36, 56), fill=(80, 50, 30))


def draw_mace(d, spiked=False, head=(160, 165, 175)):
    d.rectangle((30, 22, 34, 54), fill=(100, 65, 35))
    d.ellipse((20, 10, 44, 34), fill=head)
    d.ellipse((24, 14, 40, 30), fill=shade(head, 1.15))
    if spiked:
        for ang in range(0, 360, 45):
            rad = math.radians(ang)
            x = 32 + int(math.cos(rad) * 16)
            y = 22 + int(math.sin(rad) * 16)
            d.polygon([(32, 22), (x, y), (32 + int(math.cos(rad + 0.2) * 10), 22 + int(math.sin(rad + 0.2) * 10))], fill=(200, 200, 210))


def draw_dagger(d, twin=False, blade=(200, 210, 230), grip=(70, 40, 90)):
    d.polygon([(32, 8), (36, 30), (28, 30)], fill=blade)
    d.rectangle((24, 30, 40, 34), fill=(160, 120, 50))
    d.rectangle((29, 34, 35, 48), fill=grip)
    d.ellipse((28, 48, 36, 54), fill=(180, 140, 60))
    if twin:
        d.polygon([(22, 12), (26, 32), (18, 32)], fill=shade(blade, 0.9))
        d.polygon([(42, 12), (46, 32), (38, 32)], fill=shade(blade, 0.9))


def draw_hammer(d, lion=False):
    d.rectangle((30, 24, 34, 54), fill=(110, 70, 40))
    d.rectangle((16, 10, 48, 28), fill=(150, 155, 165))
    d.rectangle((18, 12, 46, 26), fill=(180, 185, 195))
    if lion:
        d.ellipse((26, 14, 38, 26), fill=(200, 160, 60))
        d.ellipse((28, 16, 36, 24), fill=(120, 70, 30))


def draw_bow(d, color=(140, 95, 50)):
    d.arc((14, 8, 50, 56), 200, 340, fill=color, width=4)
    d.line([(20, 14), (20, 50)], fill=(220, 220, 230), width=1)
    d.line([(18, 32), (48, 32)], fill=(180, 180, 190), width=1)
    d.ellipse((46, 28, 52, 36), fill=(90, 90, 100))


def draw_crossbow(d):
    d.rectangle((14, 28, 50, 36), fill=(120, 80, 45))
    d.rectangle((28, 16, 36, 50), fill=(100, 65, 35))
    d.arc((10, 18, 34, 46), 90, 270, fill=(160, 160, 170), width=3)
    d.line([(34, 32), (52, 32)], fill=(200, 200, 210), width=2)


def draw_staff(d, orb=(90, 160, 210), shaft=(120, 80, 40)):
    d.rectangle((30, 18, 34, 56), fill=shaft)
    d.ellipse((24, 8, 40, 24), fill=orb)
    d.ellipse((27, 11, 37, 21), fill=shade(orb, 1.25))
    d.ellipse((30, 14, 34, 18), fill=(220, 250, 255))


def draw_wand(d, tip=(180, 100, 220)):
    d.polygon([(32, 10), (36, 48), (28, 48)], fill=(140, 100, 55))
    d.ellipse((26, 6, 38, 18), fill=tip)
    d.ellipse((29, 9, 35, 15), fill=shade(tip, 1.3))


def draw_tome(d, cover=(80, 50, 120)):
    d.rectangle((16, 12, 48, 52), fill=cover)
    d.rectangle((18, 14, 46, 50), fill=shade(cover, 1.2))
    d.rectangle((16, 12, 20, 52), fill=shade(cover, 0.7))
    d.ellipse((28, 24, 40, 36), fill=(200, 170, 80))
    d.line([(24, 42), (40, 42)], fill=(200, 170, 80), width=2)


def draw_armor(d, colors, style="leather"):
    c0, c1 = colors
    d.polygon([(20, 18), (44, 18), (48, 50), (16, 50)], fill=c0)
    d.polygon([(24, 22), (40, 22), (42, 46), (22, 46)], fill=c1)
    if style == "chain":
        for y in range(24, 46, 5):
            for x in range(24, 42, 6):
                d.ellipse((x, y, x + 4, y + 4), outline=shade(c1, 1.2))
    elif style == "plate":
        d.polygon([(32, 26), (38, 36), (32, 42), (26, 36)], fill=(90, 140, 200))
        d.rectangle((28, 18, 36, 24), fill=(220, 180, 70))
    else:
        d.line([(32, 22), (32, 46)], fill=shade(c0, 0.7), width=2)


def draw_shield(d, face=(150, 100, 50), emblem=(90, 140, 80), kite=False):
    if kite:
        d.polygon([(32, 8), (50, 22), (44, 52), (20, 52), (14, 22)], fill=face)
        d.polygon([(32, 14), (44, 24), (40, 46), (24, 46), (20, 24)], fill=shade(face, 1.15))
    else:
        d.ellipse((14, 12, 50, 54), fill=face)
        d.ellipse((18, 16, 46, 50), fill=shade(face, 1.15))
    d.ellipse((26, 24, 38, 42), fill=emblem)
    d.line([(32, 16), (32, 50)], fill=shade(face, 0.7), width=2)


def draw_helm(d, metal=(150, 155, 165), crest=False):
    d.ellipse((16, 14, 48, 44), fill=metal)
    d.rectangle((16, 30, 48, 46), fill=shade(metal, 0.9))
    d.rectangle((22, 32, 42, 40), fill=(30, 30, 40))
    d.rectangle((28, 10, 36, 16), fill=(200, 170, 80))
    if crest:
        d.polygon([(32, 4), (36, 14), (28, 14)], fill=(180, 40, 40))


def draw_gloves(d, color=(140, 100, 60)):
    d.ellipse((18, 20, 34, 48), fill=color)
    d.ellipse((30, 18, 48, 46), fill=shade(color, 1.1))
    for x in (22, 28, 36, 42):
        d.rectangle((x, 14, x + 4, 24), fill=shade(color, 0.85))
    d.rectangle((20, 40, 46, 50), fill=shade(color, 0.7))


def draw_boots(d, color=(120, 75, 45)):
    d.polygon([(18, 24), (34, 24), (36, 48), (14, 48)], fill=color)
    d.polygon([(34, 34), (52, 38), (50, 50), (34, 48)], fill=shade(color, 0.85))
    d.rectangle((16, 44, 36, 50), fill=shade(color, 0.6))


def draw_ring(d, metal, gem=None):
    d.ellipse((16, 16, 48, 48), outline=metal, width=6)
    d.ellipse((22, 22, 42, 42), outline=shade(metal, 0.7), width=2)
    if gem:
        d.ellipse((28, 12, 36, 22), fill=gem)


def draw_amulet(d, gem=(70, 120, 180)):
    d.arc((18, 8, 46, 28), 200, 340, fill=(200, 180, 80), width=3)
    d.polygon([(32, 24), (44, 42), (32, 52), (20, 42)], fill=gem)
    d.ellipse((29, 36, 35, 42), fill=(240, 220, 120))


def draw_belt(d, buckle=(190, 160, 70)):
    d.rectangle((10, 26, 54, 42), fill=(110, 70, 40))
    d.rectangle((12, 28, 52, 40), fill=(140, 90, 50))
    d.rectangle((26, 22, 38, 46), fill=buckle)


def draw_cloak(d, color=(70, 90, 140)):
    d.polygon([(32, 10), (50, 20), (46, 54), (18, 54), (14, 20)], fill=color)
    d.polygon([(32, 14), (44, 22), (40, 50), (24, 50), (20, 22)], fill=shade(color, 1.2))
    d.arc((22, 8, 42, 22), 0, 180, fill=(200, 170, 80), width=3)


def draw_potion(d, liquid, tall=False, round_flask=False):
    top = 10 if tall else 14
    d.rectangle((28, top, 36, top + 8), fill=(180, 170, 150))
    d.rectangle((26, top + 6, 38, top + 10), fill=(140, 100, 60))
    body_top = top + 10
    if round_flask:
        d.ellipse((16, body_top, 48, 56), fill=(210, 220, 230, 220))
        d.ellipse((20, body_top + 6, 44, 52), fill=liquid)
    else:
        d.ellipse((18, body_top, 46, 54), fill=(210, 220, 230, 220))
        d.ellipse((22, body_top + 6, 42, 50), fill=liquid)


def draw_elixir(d, liquid=(220, 90, 50)):
    d.polygon([(32, 8), (40, 20), (38, 50), (26, 50), (24, 20)], fill=(200, 210, 220))
    d.polygon([(32, 16), (36, 22), (34, 46), (30, 46), (28, 22)], fill=liquid)
    d.ellipse((28, 6, 36, 14), fill=(180, 150, 60))


def draw_food(d, kind="bread"):
    if kind == "bread":
        d.ellipse((14, 24, 50, 48), fill=(200, 160, 90))
        d.ellipse((18, 26, 46, 42), fill=(230, 190, 120))
    elif kind == "meat":
        d.ellipse((16, 20, 48, 44), fill=(180, 70, 60))
        d.rectangle((28, 40, 36, 54), fill=(200, 180, 140))
    elif kind == "cheese":
        d.polygon([(14, 40), (32, 12), (50, 40)], fill=(230, 200, 80))
        d.ellipse((24, 28, 30, 34), fill=(210, 180, 60))
        d.ellipse((34, 30, 40, 36), fill=(210, 180, 60))
    else:
        d.ellipse((18, 18, 46, 46), fill=(80, 160, 70))
        d.ellipse((24, 22, 32, 30), fill=(200, 60, 60))


def draw_scroll(d, seal=(180, 40, 40)):
    d.rectangle((14, 16, 50, 48), fill=(220, 200, 150))
    d.rectangle((14, 16, 50, 22), fill=(200, 175, 120))
    d.rectangle((14, 42, 50, 48), fill=(200, 175, 120))
    for y in (26, 32, 38):
        d.line([(20, y), (44, y)], fill=(160, 140, 100), width=1)
    d.ellipse((28, 28, 36, 36), fill=seal)


def draw_ore(d, colors):
    pts = [(18, 40), (12, 28), (22, 14), (36, 10), (50, 20), (52, 36), (40, 50), (24, 48)]
    d.polygon(pts, fill=colors[0])
    d.polygon([(22, 28), (30, 16), (40, 22), (36, 34)], fill=colors[1])
    d.polygon([(28, 34), (38, 28), (46, 36), (34, 44)], fill=colors[2])


def draw_crystal(d, colors):
    d.polygon([(32, 8), (48, 28), (40, 54), (24, 54), (16, 28)], fill=colors[0])
    d.polygon([(32, 12), (42, 28), (36, 48), (28, 48), (22, 28)], fill=colors[1])
    d.line([(32, 14), (32, 48)], fill=colors[2], width=2)


def draw_hide(d, color=(150, 95, 55)):
    d.polygon([(14, 20), (40, 12), (52, 30), (44, 50), (18, 46)], fill=color)
    d.polygon([(20, 24), (36, 18), (46, 30), (38, 44), (22, 40)], fill=shade(color, 1.15))


def draw_part(d, kind="gear"):
    if kind == "gear":
        d.ellipse((16, 16, 48, 48), fill=(160, 165, 175))
        d.ellipse((24, 24, 40, 40), fill=(80, 85, 95))
        for ang in range(0, 360, 45):
            rad = math.radians(ang)
            x = 32 + int(math.cos(rad) * 20)
            y = 32 + int(math.sin(rad) * 20)
            d.rectangle((x - 3, y - 3, x + 3, y + 3), fill=(160, 165, 175))
    elif kind == "nail":
        d.polygon([(32, 10), (38, 40), (32, 52), (26, 40)], fill=(140, 145, 155))
    else:
        d.rectangle((18, 20, 46, 44), fill=(120, 90, 50))
        d.rectangle((22, 24, 42, 40), fill=(90, 90, 100))


def draw_special(d, kind="pouch"):
    if kind == "pouch":
        d.ellipse((16, 22, 48, 52), fill=(180, 140, 50))
        d.ellipse((20, 26, 44, 48), fill=(220, 180, 70))
        d.arc((22, 14, 42, 30), 200, 340, fill=(140, 100, 40), width=3)
    elif kind == "key":
        d.ellipse((18, 14, 36, 32), outline=(200, 170, 60), width=4)
        d.rectangle((32, 20, 50, 26), fill=(200, 170, 60))
        d.rectangle((44, 26, 50, 36), fill=(200, 170, 60))
        d.rectangle((40, 26, 44, 32), fill=(200, 170, 60))
    elif kind == "token":
        d.ellipse((14, 14, 50, 50), fill=(200, 160, 50))
        d.ellipse((20, 20, 44, 44), fill=(240, 200, 80))
        d.polygon([(32, 22), (36, 30), (44, 30), (38, 36), (40, 44), (32, 40), (24, 44), (26, 36), (20, 30), (28, 30)], fill=(180, 100, 40))
    elif kind == "map":
        d.polygon([(12, 18), (50, 14), (52, 48), (14, 50)], fill=(210, 190, 140))
        d.line([(20, 24), (40, 22), (36, 40), (24, 42)], fill=(80, 120, 80), width=2)
        d.ellipse((34, 28, 40, 34), fill=(180, 40, 40))
    else:
        d.ellipse((16, 16, 48, 48), fill=(90, 60, 140))
        d.ellipse((22, 22, 42, 42), fill=(140, 100, 200))
        d.ellipse((28, 28, 36, 36), fill=(240, 220, 120))


def icon_for_spec(spec: dict) -> Image.Image:
    seed = int(hashlib.md5(spec["id"].encode()).hexdigest()[:8], 16)
    img, d = new_canvas(seed)
    kind = spec["icon_style"]
    p = spec.get("icon_params", {})
    if kind == "sword":
        draw_sword(d, p.get("tip", 8), p.get("hilt", 40), tuple(p["color"]), gem=tuple(p["gem"]) if p.get("gem") else None, guard=tuple(p.get("guard", (180, 150, 70))))
    elif kind == "axe":
        draw_axe(d, double=p.get("double", False), blade=tuple(p.get("blade", (170, 175, 185))))
    elif kind == "mace":
        draw_mace(d, spiked=p.get("spiked", False), head=tuple(p.get("head", (160, 165, 175))))
    elif kind == "dagger":
        draw_dagger(d, twin=p.get("twin", False), blade=tuple(p.get("blade", (200, 210, 230))), grip=tuple(p.get("grip", (70, 40, 90))))
    elif kind == "hammer":
        draw_hammer(d, lion=p.get("lion", False))
    elif kind == "bow":
        draw_bow(d, tuple(p.get("color", (140, 95, 50))))
    elif kind == "crossbow":
        draw_crossbow(d)
    elif kind == "staff":
        draw_staff(d, orb=tuple(p.get("orb", (90, 160, 210))), shaft=tuple(p.get("shaft", (120, 80, 40))))
    elif kind == "wand":
        draw_wand(d, tip=tuple(p.get("tip", (180, 100, 220))))
    elif kind == "tome":
        draw_tome(d, cover=tuple(p.get("cover", (80, 50, 120))))
    elif kind == "armor":
        draw_armor(d, [tuple(p["c0"]), tuple(p["c1"])], style=p.get("style", "leather"))
    elif kind == "shield":
        draw_shield(d, face=tuple(p.get("face", (150, 100, 50))), emblem=tuple(p.get("emblem", (90, 140, 80))), kite=p.get("kite", False))
    elif kind == "helm":
        draw_helm(d, metal=tuple(p.get("metal", (150, 155, 165))), crest=p.get("crest", False))
    elif kind == "gloves":
        draw_gloves(d, tuple(p.get("color", (140, 100, 60))))
    elif kind == "boots":
        draw_boots(d, tuple(p.get("color", (120, 75, 45))))
    elif kind == "ring":
        draw_ring(d, tuple(p["metal"]), gem=tuple(p["gem"]) if p.get("gem") else None)
    elif kind == "amulet":
        draw_amulet(d, gem=tuple(p.get("gem", (70, 120, 180))))
    elif kind == "belt":
        draw_belt(d, buckle=tuple(p.get("buckle", (190, 160, 70))))
    elif kind == "cloak":
        draw_cloak(d, tuple(p.get("color", (70, 90, 140))))
    elif kind == "potion":
        draw_potion(d, tuple(p["liquid"]), tall=p.get("tall", False), round_flask=p.get("round", False))
    elif kind == "elixir":
        draw_elixir(d, liquid=tuple(p.get("liquid", (220, 90, 50))))
    elif kind == "food":
        draw_food(d, p.get("kind", "bread"))
    elif kind == "scroll":
        draw_scroll(d, seal=tuple(p.get("seal", (180, 40, 40))))
    elif kind == "ore":
        draw_ore(d, [tuple(c) for c in p["colors"]])
    elif kind == "crystal":
        draw_crystal(d, [tuple(c) for c in p["colors"]])
    elif kind == "hide":
        draw_hide(d, tuple(p.get("color", (150, 95, 55))))
    elif kind == "part":
        draw_part(d, p.get("kind", "gear"))
    elif kind == "special":
        draw_special(d, p.get("kind", "pouch"))
    else:
        d.ellipse((16, 16, 48, 48), fill=(120, 120, 120))
    # uniqueness stamp: tiny corner mark from seed
    rng = random.Random(seed)
    mark = (rng.randint(40, 220), rng.randint(40, 220), rng.randint(40, 220), 180)
    d.rectangle((54, 54, 58, 58), fill=mark)
    return img


def item(id_, name, category, subcategory, rarity, price, desc, icon, slot="", balance_status="proposed", **stats):
    out = {
        "id": id_,
        "name": name,
        "category": category,
        "subcategory": subcategory,
        "rarity": rarity,
        "price": price,
        "desc": desc,
        "slot": slot,
        "icon": icon,
        "balance_status": balance_status,
    }
    out.update(stats)
    return out


def existing_with_subcats(raw: list[dict]) -> list[dict]:
    """Preserve existing fields; only add subcategory (+ balance_status confirmed)."""
    mapping = {
        "sword_basic": "weapon_1h",
        "sword_steel": "weapon_1h",
        "axe_battle": "weapon_2h",
        "dagger_swift": "weapon_1h",
        "staff_oak": "weapon_magic",
        "blade_rune": "weapon_1h",
        "armor_leather": "body",
        "armor_chain": "body",
        "shield_wood": "shield",
        "helm_iron": "helm",
        "boots_leather": "boots",
        "plate_guardian": "body",
        "ring_copper": "ring",
        "ring_silver": "ring",
        "amulet_ward": "amulet",
        "belt_power": "belt",
        "potion_hp_s": "potion",
        "potion_hp_m": "potion",
        "potion_mp_s": "potion",
        "potion_mp_m": "potion",
        "elixir_str": "elixir",
        "ore_iron": "ore",
        "ore_mithril": "ore",
        "crystal_fire": "crystal",
        "leather_scrap": "hide",
        "enhance_stone": "part",
    }
    out = []
    for it in raw:
        e = dict(it)
        eid = e["id"]
        if "subcategory" not in e:
            e["subcategory"] = mapping.get(eid, "special")
        e["balance_status"] = "confirmed"
        out.append(e)
    return out


def build_new_items() -> list[dict]:
    """Create the remaining items to hit target subcategory minima."""
    items: list[dict] = []

    def add(it, style, params=None):
        it = dict(it)
        it["_gen"] = {"icon_style": style, "icon_params": params or {}, "id": it["id"]}
        # prefer dedicated icon path under assets/items/<id>.png
        it["icon"] = f"res://assets/items/{it['id']}.png"
        items.append(it)

    # --- 1H weapons: need 16 total; existing: sword_basic, sword_steel, dagger_swift, blade_rune = 4 → +12 ---
    one_hand = [
        ("sword_iron", "철검", "common", 3200, "단단한 철로 벼린 한손검.", 16, 2, 0, 2),
        ("sword_rapier", "레이피어", "uncommon", 5400, "가늘고 예리한 찌르기 검.", 18, 7, 3, 7),
        ("sword_scimitar", "시미터", "uncommon", 5000, "곡선 날의 빠른 한손검.", 20, 4, 5, 6),
        ("sword_ornate", "장식 장검", "rare", 8800, "귀족 의례용 화려한 검.", 28, 4, 4, 10),
        ("mace_spiked", "가시 메이스", "uncommon", 4600, "가시 돋친 타격 무기.", 24, 1, 2, 5),
        ("mace_flanged", "플랜지 메이스", "rare", 7200, "금속 돌기가 박힌 메이스.", 30, 2, 3, 9),
        ("axe_hand", "손도끼", "common", 2600, "짧은 자루의 한손 도끼.", 15, 2, 2, 2),
        ("dagger_gem", "보석 단검", "rare", 6900, "자루에 보석이 박힌 단검.", 17, 6, 8, 9),
        ("dagger_ritual", "의식용 단검", "epic", 11200, "암흑 의식에 쓰이던 단검.", 22, 5, 10, 14),
        ("sword_bronze", "청동 검", "common", 1800, "녹슬지 않는 청동 한손검.", 10, 1, 0, 1),
        ("sword_knight", "기사 검", "rare", 9600, "기사단이 지급하는 제식 검.", 32, 5, 3, 12),
        ("club_oak", "참나무 곤봉", "common", 900, "무딘 타격용 나무 곤봉.", 8, 0, 0, 1),
    ]
    styles_1h = [
        ("sword", {"color": (170, 175, 185)}),
        ("sword", {"color": (210, 215, 225), "gem": (180, 40, 40), "guard": (160, 140, 60)}),
        ("sword", {"color": (190, 160, 120), "guard": (140, 100, 50)}),
        ("sword", {"color": (200, 190, 140), "gem": (80, 160, 220)}),
        ("mace", {"spiked": True, "head": (150, 150, 160)}),
        ("mace", {"spiked": False, "head": (130, 140, 160)}),
        ("axe", {"double": False, "blade": (160, 165, 170)}),
        ("dagger", {"blade": (180, 200, 230), "grip": (40, 100, 140)}),
        ("dagger", {"blade": (160, 80, 180), "grip": (40, 20, 50)}),
        ("sword", {"color": (180, 120, 70)}),
        ("sword", {"color": (185, 190, 200), "gem": (200, 170, 60)}),
        ("mace", {"spiked": False, "head": (120, 90, 50)}),
    ]
    for (spec, (style, params)) in zip(one_hand, styles_1h):
        iid, name, rar, price, desc, atk, acc, crit, lvl = spec
        add(item(iid, name, "weapon", "weapon_1h", rar, price, desc, "", slot="weapon",
                 atk=atk, acc=acc, crit=crit, req_level=lvl), style, params)

    # --- 2H: existing axe_battle = 1 → +15 ---
    two_hand = [
        ("axe_double", "양날 도끼", "uncommon", 5800, "양쪽으로 날이 선 대형 도끼.", 30, 3, 7),
        ("axe_great", "대형 전투 도끼", "rare", 9800, "양손으로 휘두르는 거대 도끼.", 40, 5, 12),
        ("hammer_war", "전쟁 망치", "uncommon", 6200, "갑옷을 찌그러뜨리는 망치.", 32, 2, 7),
        ("hammer_lion", "사자 망치", "epic", 14200, "사자 문양이 새겨진 성전사 망치.", 44, 4, 15),
        ("flail_spike", "가시 플레일", "rare", 8600, "사슬에 달린 가시 철구.", 34, 6, 10),
        ("sword_claymore", "클레이모어", "rare", 10200, "길게 뻗은 양손 대검.", 38, 3, 11),
        ("sword_great", "대검", "uncommon", 7000, "묵직한 양손 검.", 34, 2, 8),
        ("halberd_iron", "철 할버드", "uncommon", 6400, "창과 도끼가 결합된 병기.", 31, 4, 8),
        ("spear_long", "장창", "common", 2800, "긴 자루의 기본 창.", 18, 1, 3),
        ("spear_knight", "기사 창", "rare", 9000, "기병용으로 벼린 창.", 33, 4, 11),
        ("glaive_steel", "강철 글레이브", "rare", 9500, "넓은 날의 장병기.", 36, 5, 12),
        ("maul_stone", "돌 망치", "common", 2200, "돌머리를 얹은 양손 망치.", 20, 0, 2),
        ("scythe_iron", "철 낫", "uncommon", 5600, "전투용으로 개조된 낫.", 27, 5, 7),
        ("blade_zwei", "츠바이핸더", "epic", 15500, "양손으로만 다룰 수 있는 거대 검.", 48, 6, 16),
        ("pike_militia", "민병 파이크", "common", 2400, "민병대가 쓰는 긴 파이크.", 17, 1, 2),
    ]
    styles_2h = [
        ("axe", {"double": True, "blade": (175, 180, 190)}),
        ("axe", {"double": False, "blade": (140, 145, 155)}),
        ("hammer", {"lion": False}),
        ("hammer", {"lion": True}),
        ("mace", {"spiked": True, "head": (100, 100, 110)}),
        ("sword", {"color": (160, 165, 180), "tip": 6, "hilt": 42}),
        ("sword", {"color": (150, 155, 165), "tip": 6, "hilt": 44}),
        ("axe", {"double": False, "blade": (155, 160, 170)}),
        ("staff", {"orb": (180, 180, 190), "shaft": (100, 70, 40)}),  # spear-like
        ("staff", {"orb": (200, 200, 210), "shaft": (90, 60, 35)}),
        ("axe", {"double": False, "blade": (170, 175, 200)}),
        ("hammer", {"lion": False}),
        ("axe", {"double": False, "blade": (130, 140, 150)}),
        ("sword", {"color": (140, 150, 200), "gem": (100, 80, 200), "tip": 5, "hilt": 44}),
        ("staff", {"orb": (160, 160, 170), "shaft": (110, 80, 45)}),
    ]
    for (spec, (style, params)) in zip(two_hand, styles_2h):
        iid, name, rar, price, desc, atk, crit, lvl = spec
        add(item(iid, name, "weapon", "weapon_2h", rar, price, desc, "", slot="weapon",
                 atk=atk, crit=crit, req_level=lvl), style, params)

    # --- ranged/magic: existing staff_oak = 1 → +15 (mix ranged + magic) ---
    ranged_magic = [
        ("bow_short", "단궁", "common", 2100, "가벼운 단궁. 초보 궁수용.", "weapon_ranged", 14, 0, 3, 1, "bow", {"color": (150, 100, 55)}),
        ("bow_long", "장궁", "uncommon", 5200, "사거리가 긴 장궁.", "weapon_ranged", 24, 0, 4, 6, "bow", {"color": (120, 80, 40)}),
        ("bow_hunter", "사냥꾼의 활", "rare", 8400, "야생을 아는 자의 활.", "weapon_ranged", 30, 0, 7, 10, "bow", {"color": (100, 130, 70)}),
        ("crossbow_light", "경석궁", "uncommon", 4800, "다루기 쉬운 석궁.", "weapon_ranged", 22, 0, 3, 5, "crossbow", {}),
        ("crossbow_heavy", "중석궁", "rare", 9100, "관통력이 뛰어난 중석궁.", "weapon_ranged", 34, 0, 5, 11, "crossbow", {}),
        ("bow_elf", "엘프 활", "epic", 13800, "숲의 정령이 깃든 활.", "weapon_ranged", 36, 8, 8, 15, "bow", {"color": (80, 160, 100)}),
        ("staff_pine", "소나무 지팡이", "common", 2500, "가벼운 소나무 지팡이.", "weapon_magic", 8, 12, 0, 1, "staff", {"orb": (100, 180, 140), "shaft": (130, 100, 50)}),
        ("staff_crystal", "수정 지팡이", "rare", 9800, "푸른 수정이 박힌 지팡이.", "weapon_magic", 12, 28, 2, 11, "staff", {"orb": (80, 160, 240), "shaft": (100, 80, 120)}),
        ("wand_spark", "불꽃 완드", "uncommon", 4500, "작은 불꽃을 일으키는 완드.", "weapon_magic", 6, 18, 3, 5, "wand", {"tip": (240, 120, 40)}),
        ("wand_frost", "서리 완드", "rare", 7800, "서리를 머금은 완드.", "weapon_magic", 8, 24, 4, 9, "wand", {"tip": (120, 200, 255)}),
        ("tome_ember", "잿불 마도서", "rare", 8600, "불의 주문이 적힌 마도서.", "weapon_magic", 5, 26, 3, 10, "tome", {"cover": (140, 40, 30)}),
        ("tome_tide", "해일 마도서", "epic", 13200, "물의 정수가 담긴 마도서.", "weapon_magic", 6, 34, 4, 14, "tome", {"cover": (30, 70, 140)}),
        ("staff_archmage", "대마법사 지팡이", "legendary", 22000, "전설의 대마법사가 쓰던 지팡이.", "weapon_magic", 15, 45, 6, 20, "staff", {"orb": (200, 120, 255), "shaft": (60, 40, 80)}),
        ("orb_mana", "마나 오브", "uncommon", 5100, "마나를 응축한 구체 촉매.", "weapon_magic", 4, 20, 2, 6, "crystal", {"colors": [(60, 80, 180), (100, 140, 240), (200, 220, 255)]}),
        ("sling_leather", "가죽 투석구", "common", 800, "돌멩이를 날리는 투석구.", "weapon_ranged", 7, 0, 1, 1, "bow", {"color": (160, 120, 80)}),
    ]
    for row in ranged_magic:
        iid, name, rar, price, desc, sub, atk, matk, crit, lvl, style, params = row
        kwargs = {"atk": atk, "req_level": lvl, "crit": crit}
        if matk:
            kwargs["matk"] = matk
        if sub == "weapon_ranged":
            kwargs["acc"] = max(2, crit + 2)
        add(item(iid, name, "weapon", sub, rar, price, desc, "", slot="weapon", **kwargs), style, params)

    # --- shields: existing shield_wood = 1 → +11 ---
    shields = [
        ("shield_iron", "철 방패", "uncommon", 3400, "철판을 덧댄 원형 방패.", 12, 4, False, (130, 135, 145), (80, 90, 110)),
        ("shield_crest", "문장 방패", "rare", 7200, "가문 문장이 새겨진 방패.", 18, 8, False, (160, 120, 60), (180, 40, 40)),
        ("shield_kite", "카이트 방패", "uncommon", 4100, "몸을 길게 가리는 방패.", 14, 5, True, (140, 100, 55), (60, 100, 160)),
        ("shield_tower", "타워 실드", "rare", 8800, "전신을 가리는 대형 방패.", 24, 11, True, (120, 125, 140), (90, 90, 100)),
        ("shield_bronze", "청동 방패", "common", 2200, "청동으로 만든 기본 방패.", 9, 2, False, (160, 110, 50), (120, 80, 40)),
        ("shield_bone", "뼈 방패", "uncommon", 3900, "몬스터 뼈로 엮은 방패.", 13, 6, False, (220, 210, 190), (100, 80, 70)),
        ("shield_rune", "룬 방패", "epic", 12600, "방어 룬이 빛나는 방패.", 26, 14, False, (100, 120, 180), (160, 100, 255)),
        ("shield_scale", "비늘 방패", "rare", 7600, "드래곤 비늘을 붙인 방패.", 20, 10, False, (80, 140, 90), (40, 100, 50)),
        ("shield_buckler", "버클러", "common", 1400, "작은 원형 보조 방패.", 5, 1, False, (150, 105, 60), (180, 150, 80)),
        ("shield_guard", "근위대 방패", "rare", 8400, "왕실 근위대가 쓰는 방패.", 22, 12, False, (170, 170, 185), (200, 170, 60)),
        ("shield_obsidian", "흑요석 방패", "epic", 11800, "검은 돌로 깎은 방패.", 25, 13, True, (40, 40, 50), (120, 40, 160)),
    ]
    for iid, name, rar, price, desc, deff, lvl, kite, face, emblem in shields:
        add(item(iid, name, "armor", "shield", rar, price, desc, "", slot="armor",
                 **{"def": deff, "req_level": lvl}),
            "shield", {"face": face, "emblem": emblem, "kite": kite})

    # --- body armor: existing leather, chain, plate = 3 → +17 ---
    bodies = [
        ("armor_cloth", "천 로브", "common", 1200, "마법수용 가벼운 천옷.", 4, 1, "leather", (120, 100, 160), (150, 130, 190)),
        ("armor_hide", "짐승 가죽옷", "common", 2000, "거친 짐승 가죽 갑옷.", 7, 2, "leather", (110, 70, 40), (140, 90, 55)),
        ("armor_studded", "징 박힌 가죽", "uncommon", 4200, "금속 징이 박힌 가죽 갑옷.", 12, 5, "leather", (100, 70, 45), (160, 160, 170)),
        ("armor_scale", "비늘 갑옷", "uncommon", 6000, "금속 비늘을 겹친 갑옷.", 18, 7, "chain", (100, 140, 110), (140, 180, 150)),
        ("armor_brig", "브리건딘", "rare", 7800, "천 안에 철판을 넣은 갑옷.", 22, 9, "plate", (90, 90, 110), (140, 140, 160)),
        ("armor_knight", "기사 판금", "rare", 11000, "전신 판금 갑옷.", 30, 13, "plate", (170, 175, 190), (200, 205, 220)),
        ("armor_mithril", "미스릴 사슬", "epic", 16000, "가벼운 미스릴 사슬 갑옷.", 34, 16, "chain", (160, 190, 210), (200, 230, 245)),
        ("armor_shadow", "그림자 로브", "epic", 14800, "어둠에 녹아드는 로브.", 16, 15, "leather", (40, 40, 60), (70, 70, 100)),
        ("armor_ranger", "레인저 코트", "uncommon", 4800, "숲 사냥꾼의 코트.", 11, 6, "leather", (70, 110, 60), (100, 140, 90)),
        ("armor_battle", "전투 흉갑", "rare", 8600, "가슴을 집중 보호하는 흉갑.", 24, 10, "plate", (140, 145, 155), (180, 185, 195)),
        ("armor_apprentice", "견습 로브", "common", 1600, "견습 마법사의 로브.", 5, 1, "leather", (90, 90, 140), (120, 120, 180)),
        ("armor_mercenary", "용병 갑옷", "uncommon", 5200, "실전에서 닳은 용병 갑옷.", 15, 6, "chain", (110, 100, 90), (140, 130, 120)),
        ("armor_royal", "왕실 예복 갑옷", "legendary", 24000, "왕실 의전용 화려한 갑옷.", 40, 20, "plate", (180, 150, 80), (220, 190, 100)),
        ("armor_bone", "뼈 갑옷", "rare", 7400, "몬스터 뼈로 짠 갑옷.", 19, 9, "leather", (220, 210, 195), (180, 170, 150)),
        ("armor_dragon", "용린 갑옷", "legendary", 28000, "드래곤 비늘로 만든 갑옷.", 45, 22, "scale" if False else "plate", (80, 140, 90), (40, 180, 100)),
        ("armor_padded", "누빔 갑옷", "common", 1500, "천을 여러 겹 누빈 갑옷.", 6, 1, "leather", (140, 120, 90), (170, 150, 110)),
        ("armor_gladiator", "검투사 갑옷", "rare", 9200, "투기장에서 쓰던 갑옷.", 23, 11, "leather", (160, 80, 50), (190, 110, 70)),
    ]
    for iid, name, rar, price, desc, deff, lvl, style, c0, c1 in bodies:
        add(item(iid, name, "armor", "body", rar, price, desc, "", slot="armor",
                 **{"def": deff, "req_level": lvl}),
            "armor", {"c0": c0, "c1": c1, "style": style})

    # --- helm/gloves/boots: existing helm_iron, boots_leather = 2 → +14 to reach 16 ---
    # Split into helms, gloves, boots
    hgb = [
        ("helm_leather", "가죽 투구", "common", 1100, "가벼운 가죽 투구.", "helm", 4, 1, "helm", {"metal": (120, 85, 50)}),
        ("helm_steel", "강철 투구", "uncommon", 4200, "시야가 넓은 강철 투구.", "helm", 9, 5, "helm", {"metal": (160, 165, 175)}),
        ("helm_knight", "기사 투구", "rare", 7800, "안면 보호가 되는 기사 투구.", "helm", 14, 10, "helm", {"metal": (170, 175, 190), "crest": True}),
        ("helm_mage", "마법사 후드", "uncommon", 3600, "마력을 모으는 후드.", "helm", 5, 4, "helm", {"metal": (90, 70, 140)}),
        ("helm_horned", "뿔 투구", "rare", 7000, "뿔이 달린 야만 투구.", "helm", 12, 9, "helm", {"metal": (140, 120, 90), "crest": True}),
        ("gloves_leather", "가죽 장갑", "common", 900, "손놀림이 편한 가죽 장갑.", "gloves", 3, 1, "gloves", {"color": (140, 100, 60)}),
        ("gloves_iron", "철 건틀릿", "uncommon", 3200, "철로 된 전투 장갑.", "gloves", 7, 4, "gloves", {"color": (140, 145, 155)}),
        ("gloves_thief", "도적 장갑", "rare", 5600, "소매치기에 쓰이던 장갑.", "gloves", 5, 7, "gloves", {"color": (50, 50, 60)}),
        ("gloves_mage", "마법 장갑", "uncommon", 3800, "주문 시전에 맞는 장갑.", "gloves", 4, 5, "gloves", {"color": (90, 80, 160)}),
        ("gloves_plate", "판금 건틀릿", "rare", 7200, "두꺼운 판금 장갑.", "gloves", 11, 10, "gloves", {"color": (170, 175, 185)}),
        ("boots_iron", "철 장화", "uncommon", 3000, "발목을 보호하는 철 장화.", "boots", 6, 4, "boots", {"color": (130, 135, 145)}),
        ("boots_swift", "신속의 장화", "rare", 6400, "발걸음을 빠르게 하는 장화.", "boots", 5, 8, "boots", {"color": (80, 120, 160)}),
        ("boots_plate", "판금 장화", "rare", 7000, "무거운 판금 장화.", "boots", 10, 10, "boots", {"color": (160, 165, 175)}),
        ("boots_mage", "마법사 신발", "uncommon", 3400, "조용히 걷는 마법사 신발.", "boots", 4, 5, "boots", {"color": (100, 80, 140)}),
    ]
    for iid, name, rar, price, desc, sub, deff, lvl, style, params in hgb:
        stats = {"def": deff, "req_level": lvl}
        if iid == "boots_swift":
            stats["agi"] = 4
        if iid == "gloves_thief":
            stats["agi"] = 3
        if iid == "helm_mage":
            stats["matk"] = 3
        add(item(iid, name, "armor", sub, rar, price, desc, "", slot="armor", **stats), style, params)

    # --- accessories: existing 4 → +12 ---
    accs = [
        ("ring_gold", "금 반지", "rare", 5200, "순금으로 만든 반지.", "ring", {"atk": 6, "matk": 3}, 8, "ring", {"metal": (220, 180, 60), "gem": (200, 40, 40)}),
        ("ring_ruby", "루비 반지", "epic", 9800, "루비가 박힌 힘의 반지.", "ring", {"atk": 10, "str": 3}, 14, "ring", {"metal": (200, 160, 50), "gem": (220, 40, 60)}),
        ("ring_sapphire", "사파이어 반지", "epic", 9800, "사파이어가 박힌 지혜의 반지.", "ring", {"matk": 10, "acc": 3}, 14, "ring", {"metal": (180, 190, 210), "gem": (40, 100, 220)}),
        ("amulet_flame", "화염 부적", "rare", 6100, "화염의 가호가 깃든 부적.", "amulet", {"atk": 5, "crit": 3}, 9, "amulet", {"gem": (220, 80, 30)}),
        ("amulet_tide", "파도 부적", "rare", 6100, "물의 가호가 깃든 부적.", "amulet", {"def": 6, "vit": 2}, 9, "amulet", {"gem": (40, 120, 200)}),
        ("amulet_sun", "태양 부적", "epic", 12000, "태양의 축복이 깃든 부적.", "amulet", {"atk": 8, "matk": 8}, 16, "amulet", {"gem": (240, 200, 60)}),
        ("belt_guard", "수호의 허리띠", "rare", 5400, "방어력을 높이는 벨트.", "belt", {"def": 8, "vit": 2}, 8, "belt", {"buckle": (160, 170, 190)}),
        ("belt_mage", "마력 허리띠", "uncommon", 3600, "마나 순환을 돕는 벨트.", "belt", {"matk": 6}, 6, "belt", {"buckle": (120, 80, 180)}),
        ("cloak_travel", "여행자 망토", "common", 1600, "먼지와 비를 막아 주는 망토.", "cloak", {"def": 3, "agi": 1}, 1, "cloak", {"color": (100, 90, 70)}),
        ("cloak_shadow", "그림자 망토", "rare", 7800, "그림자에 숨기 쉬운 망토.", "cloak", {"def": 6, "agi": 4}, 11, "cloak", {"color": (40, 40, 55)}),
        ("cloak_royal", "왕실 망토", "epic", 14000, "왕실 문양이 수놓인 망토.", "cloak", {"def": 10, "vit": 3}, 16, "cloak", {"color": (140, 40, 50)}),
        ("ring_iron", "철 반지", "common", 600, "투박한 철 반지.", "ring", {"atk": 1}, 1, "ring", {"metal": (140, 145, 150)}),
    ]
    for iid, name, rar, price, desc, sub, stats, lvl, style, params in accs:
        add(item(iid, name, "accessory", sub, rar, price, desc, "", slot="accessory",
                 req_level=lvl, **stats), style, params)

    # --- consumables: existing 5 → +11 ---
    cons = [
        ("potion_hp_l", "체력 물약(대)", "rare", 900, "HP를 크게 회복한다.", "potion", {"heal": 180}, "potion", {"liquid": (200, 30, 40), "tall": True, "round": True}),
        ("potion_mp_l", "마나 물약(대)", "rare", 900, "MP를 크게 회복한다.", "potion", {"heal_mp": 120}, "potion", {"liquid": (40, 70, 220), "tall": True, "round": True}),
        ("potion_mixed", "혼합 물약", "uncommon", 600, "HP와 MP를 조금 회복한다.", "potion", {"heal": 40, "heal_mp": 30}, "potion", {"liquid": (160, 60, 180), "round": True}),
        ("elixir_def", "수호의 영약", "rare", 950, "일시적으로 방어력을 높인다.", "elixir", {"buff_atk": 0, "def": 0}, "elixir", {"liquid": (60, 120, 220)}),
        ("elixir_agi", "신속의 영약", "rare", 950, "일시적으로 민첩을 높인다.", "elixir", {"buff_atk": 0}, "elixir", {"liquid": (60, 200, 120)}),
        ("food_bread", "단단한 빵", "common", 40, "허기를 달래는 여행용 빵.", "food", {"heal": 10}, "food", {"kind": "bread"}),
        ("food_meat", "구운 고기", "common", 80, "체력을 채우는 고기 요리.", "food", {"heal": 25}, "food", {"kind": "meat"}),
        ("food_cheese", "숙성 치즈", "uncommon", 120, "고소하고 든든한 치즈.", "food", {"heal": 20, "heal_mp": 10}, "food", {"kind": "cheese"}),
        ("food_apple", "붉은 사과", "common", 30, "아삭한 사과. 기운을 북돋운다.", "food", {"heal": 8}, "food", {"kind": "apple"}),
        ("scroll_escape", "귀환 주문서", "uncommon", 500, "마을로 즉시 귀환한다.", "scroll", {}, "scroll", {"seal": (40, 120, 200)}),
        ("scroll_identify", "감정 주문서", "uncommon", 350, "아이템의 성질을 감정한다.", "scroll", {}, "scroll", {"seal": (180, 140, 40)}),
    ]
    # fix elixir_def - use a custom field note; keep buff via buff_atk unused — use heal 0. Better: store as desc-only buff items with buff_atk for str-like; for def elixir use a placeholder buff_atk=0 removed
    for row in cons:
        iid, name, rar, price, desc, sub, stats, style, params = row
        clean = {k: v for k, v in stats.items() if v}
        # elixir_def / elixir_agi need a visible effect field for UI — use buff_atk for agi elixir as temporary atk proxy is wrong.
        # ItemUI shows buff_atk; for def elixir add nothing special beyond desc — add buff_atk only for combat-related.
        if iid == "elixir_def":
            clean = {"def": 5}  # shown as permanent-looking in shop stats; proposed
        if iid == "elixir_agi":
            clean = {"agi": 5}
        add(item(iid, name, "consumable", sub, rar, price, desc, "", slot="", **clean), style, params)

    # --- craft mats: existing ore_iron, ore_mithril, crystal_fire, leather_scrap, enhance_stone = 5 → +19 ---
    mats = [
        ("ore_copper", "구리 광석", "common", 40, "흔한 구리 광석.", "ore", "ore", {"colors": [(140, 90, 50), (180, 120, 70), (100, 60, 30)]}),
        ("ore_silver", "은 광석", "uncommon", 180, "은빛이 도는 광석.", "ore", "ore", {"colors": [(160, 170, 180), (210, 220, 230), (120, 130, 140)]}),
        ("ore_gold", "금 광석", "rare", 400, "노란빛이 선명한 금광석.", "ore", "ore", {"colors": [(180, 150, 40), (230, 200, 70), (140, 110, 30)]}),
        ("ore_coal", "석탄", "common", 30, "대장간 연료로 쓰인다.", "ore", "ore", {"colors": [(40, 40, 45), (70, 70, 75), (20, 20, 25)]}),
        ("crystal_ice", "빙결 결정", "uncommon", 240, "차가운 마력이 응축된 결정.", "crystal", "crystal", {"colors": [(120, 180, 230), (180, 220, 255), (240, 250, 255)]}),
        ("crystal_nature", "자연 결정", "uncommon", 220, "숲의 기운이 담긴 초록 결정.", "crystal", "crystal", {"colors": [(40, 140, 70), (80, 200, 110), (180, 255, 200)]}),
        ("crystal_shadow", "암영 결정", "rare", 420, "그림자가 서린 보라 결정.", "crystal", "crystal", {"colors": [(60, 30, 90), (120, 60, 180), (200, 160, 255)]}),
        ("crystal_light", "광휘 결정", "rare", 420, "눈부신 빛의 결정.", "crystal", "crystal", {"colors": [(220, 200, 100), (255, 240, 160), (255, 255, 220)]}),
        ("hide_wolf", "늑대 가죽", "common", 70, "질긴 늑대 가죽.", "hide", "hide", {"color": (90, 90, 100)}),
        ("hide_boar", "멧돼지 가죽", "common", 65, "두꺼운 멧돼지 가죽.", "hide", "hide", {"color": (120, 90, 60)}),
        ("cloth_linen", "아마포", "common", 45, "방어구 안감용 아마포.", "hide", "hide", {"color": (200, 190, 160)}),
        ("cloth_silk", "실크 천", "rare", 300, "고급 로브에 쓰는 실크.", "hide", "hide", {"color": (180, 160, 200)}),
        ("part_nail", "철 못", "common", 20, "장비 수선용 철 못.", "part", "part", {"kind": "nail"}),
        ("part_gear", "청동 톱니", "uncommon", 110, "장치 제작용 톱니바퀴.", "part", "part", {"kind": "gear"}),
        ("part_core", "마력 코어", "rare", 500, "마도구의 중심 부품.", "part", "part", {"kind": "box"}),
        ("wood_oak", "참나무 목재", "common", 35, "무기 자루용 참나무.", "part", "hide", {"color": (140, 100, 50)}),
        ("wood_pine", "소나무 목재", "common", 25, "가벼운 소나무 목재.", "part", "hide", {"color": (180, 150, 90)}),
        ("powder_grind", "연마 가루", "common", 55, "날을 세우는 연마 가루.", "part", "ore", {"colors": [(180, 180, 190), (210, 210, 220), (140, 140, 150)]}),
        ("thread_sinew", "힘줄 실", "uncommon", 90, "활시위용 질긴 힘줄.", "hide", "hide", {"color": (200, 180, 140)}),
    ]
    for iid, name, rar, price, desc, sub, style, params in mats:
        add(item(iid, name, "material", sub, rar, price, desc, "", slot=""), style, params)

    # --- special: 8 (category material, subcategory special) ---
    specials = [
        ("special_gold_pouch", "금화 주머니", "uncommon", 0, "소량의 금화가 든 주머니. (제안: 사용 시 골드 획득)", "special", {"kind": "pouch"}),
        ("special_guild_token", "길드 토큰", "rare", 0, "길드 공적 증명 토큰. (제안: 평판/교환)", "special", {"kind": "token"}),
        ("special_dungeon_key", "던전 열쇠", "rare", 0, "봉인된 문을 여는 열쇠. (제안: 던전 해금)", "special", {"kind": "key"}),
        ("special_old_map", "낡은 지도", "uncommon", 200, "보물 위치가 흐릿하게 표시된 지도.", "special", {"kind": "map"}),
        ("special_seal_royal", "왕실 인장", "epic", 0, "왕실 공인의 인장. (제안: 퀘스트)", "special", {"kind": "orb"}),
        ("special_memory_shard", "기억의 파편", "epic", 0, "누군가의 기억이 담긴 파편. (제안: 스토리)", "special", {"kind": "orb"}),
        ("special_contract", "모집 계약서", "uncommon", 150, "모험가 고용에 쓰는 계약서.", "special", {"kind": "map"}),
        ("special_blessing", "축복의 문장", "legendary", 0, "길드에 축복을 내리는 문장. (제안: 버프)", "special", {"kind": "token"}),
    ]
    for iid, name, rar, price, desc, style, params in specials:
        add(item(iid, name, "material", "special", rar, price, desc + " [proposed/unconfirmed]", "", slot=""), style, params)

    return items


def assign_reuse_icons(items: list[dict], existing_assets: set[str]) -> None:
    """Optionally remap a few new items onto unused painted assets when silhouette matches."""
    reuse = {
        "sword_iron": "iron_sword.png",
        "sword_rapier": "ornate_rapier.png",
        "sword_scimitar": "scimitar.png",
        "axe_hand": "hand_axe.png",
        "axe_double": "double_axe.png",
        "hammer_lion": "lion_hammer.png",
        "flail_spike": "spiked_flail.png",
        "mace_spiked": "spiked_mace.png",
        "mace_flanged": "flanged_mace.png",
        "dagger_gem": "gem_dagger.png",
        "dagger_ritual": "ritual_dagger.png",
        "bow_short": "bow.png",
        "shield_crest": "crest_shield.png",
        "helm_leather": "leather_helmet.png",
        "special_gold_pouch": "gold_pouch.png",
        "crystal_ice": "magic_crystal.png",  # will regenerate distinct file below if duplicate hash
    }
    for it in items:
        fname = reuse.get(it["id"])
        if fname and fname in existing_assets:
            it["icon"] = f"res://assets/items/{fname}"
            it.pop("_gen", None)


def main() -> None:
    raw = json.loads(ITEMS_PATH.read_text(encoding="utf-8"))
    existing = existing_with_subcats(raw["items"])
    assert len(existing) == 26, len(existing)
    for e in existing:
        assert e["id"] in EXISTING_IDS

    # Snapshot original fields for preservation check
    original_by_id = {e["id"]: json.loads(json.dumps(e)) for e in raw["items"]}

    new_items = build_new_items()
    assets = {p.name for p in OUT_DIR.glob("*.png")}
    assign_reuse_icons(new_items, assets)

    # Generate icons for items that still need them
    generated = []
    missing_art = []
    for it in new_items:
        gen = it.pop("_gen", None)
        icon_path = Path(str(it["icon"]).replace("res://", ""))
        abs_icon = ROOT / icon_path
        if gen is not None:
            # Always write per-id icon for uniqueness tracking; if reusing painted asset, skip gen
            if it["icon"].endswith(f"{it['id']}.png") or not abs_icon.exists():
                img = icon_for_spec(gen)
                dest = OUT_DIR / f"{it['id']}.png"
                save_icon(dest, img)
                it["icon"] = f"res://assets/items/{it['id']}.png"
                generated.append(it["id"])
            else:
                # reused painted
                pass
        elif not abs_icon.exists():
            missing_art.append(it["id"])
            it["icon"] = "res://assets/items/iron_sword.png"
            it["icon_fallback"] = True

    # Fix known duplicate painted assets by regenerating distinct alternate files when referenced
    # magic_crystal identical to enhance_stone — if crystal_ice uses it, generate unique crystal_ice instead
    def file_md5(p: Path) -> str:
        return hashlib.md5(p.read_bytes()).hexdigest() if p.exists() else ""

    enhance_h = file_md5(OUT_DIR / "enhance_stone.png")
    for it in new_items:
        p = ROOT / str(it["icon"]).replace("res://", "")
        if p.name == "magic_crystal.png" and file_md5(p) == enhance_h:
            img = icon_for_spec({"id": it["id"], "icon_style": "crystal", "icon_params": {"colors": [(120, 180, 230), (180, 220, 255), (240, 250, 255)]}})
            dest = OUT_DIR / f"{it['id']}.png"
            save_icon(dest, img)
            it["icon"] = f"res://assets/items/{it['id']}.png"
            generated.append(it["id"])

    # Mark proposed on new items
    for it in new_items:
        it.setdefault("balance_status", "proposed")

    all_items = existing + new_items

    # Preserve check: existing price/stats unchanged
    for e in existing:
        orig = original_by_id[e["id"]]
        for k, v in orig.items():
            if k in ("subcategory", "balance_status"):
                continue
            assert e.get(k) == v, (e["id"], k, e.get(k), v)

    # Count targets
    from collections import Counter
    sub_counts = Counter(i["subcategory"] for i in all_items)
    targets = {
        "weapon_1h": 16,
        "weapon_2h": 16,
        # ranged+magic combined target 16
        "shield": 12,
        "body": 20,
        # helm+gloves+boots = 16
        "ring+amulet+belt+cloak": 16,
        "potion+elixir+food+scroll": 16,
        "ore+crystal+hide+part": 24,
        "special": 8,
    }
    ranged_magic = sub_counts.get("weapon_ranged", 0) + sub_counts.get("weapon_magic", 0)
    hgb = sub_counts.get("helm", 0) + sub_counts.get("gloves", 0) + sub_counts.get("boots", 0)
    acc = sum(sub_counts.get(s, 0) for s in ("ring", "amulet", "belt", "cloak"))
    cons = sum(sub_counts.get(s, 0) for s in ("potion", "elixir", "food", "scroll"))
    craft = sum(sub_counts.get(s, 0) for s in ("ore", "crystal", "hide", "part"))
    print("TOTAL", len(all_items))
    print("subcounts", dict(sub_counts))
    print("weapon_1h", sub_counts["weapon_1h"], "weapon_2h", sub_counts["weapon_2h"], "ranged/magic", ranged_magic)
    print("shield", sub_counts["shield"], "body", sub_counts["body"], "hgb", hgb)
    print("acc", acc, "cons", cons, "craft", craft, "special", sub_counts["special"])
    assert len(all_items) >= 160
    assert sub_counts["weapon_1h"] >= 16
    assert sub_counts["weapon_2h"] >= 16
    assert ranged_magic >= 16
    assert sub_counts["shield"] >= 12
    assert sub_counts["body"] >= 20
    assert hgb >= 16
    assert acc >= 16
    assert cons >= 16
    assert craft >= 24
    assert sub_counts["special"] >= 8

    # Unique icons check among non-fallback
    icons = [i["icon"] for i in all_items]
    # Allow related variants? Brief: no duplicate across unrelated. We aim for all unique paths.
    dup = [i for i, c in Counter(icons).items() if c > 1]
    if dup:
        print("WARN duplicate icon paths", dup)

    # Content hashes uniqueness
    hashes = {}
    shared = []
    for i in all_items:
        p = ROOT / str(i["icon"]).replace("res://", "")
        if not p.exists():
            missing_art.append(i["id"])
            continue
        h = file_md5(p)
        if h in hashes and hashes[h] != i["id"]:
            shared.append((hashes[h], i["id"], p.name))
        else:
            hashes[h] = i["id"]
    if shared:
        print("WARN identical image bytes", shared)

    payload = {"items": all_items, "meta": {
        "version": 2,
        "subcategory_labels": SUBCAT_LABELS,
        "note": "New items marked balance_status=proposed are unconfirmed.",
    }}
    ITEMS_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("wrote", ITEMS_PATH)
    print("generated_icons", len(generated))
    print("missing_art", sorted(set(missing_art)))

    report = ROOT / "docs" / "reviews" / "_catalog160_gen_stats.json"
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps({
        "total": len(all_items),
        "sub_counts": dict(sub_counts),
        "generated_icons": generated,
        "missing_art": sorted(set(missing_art)),
        "identical_pairs": shared,
        "duplicate_paths": dup,
    }, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
