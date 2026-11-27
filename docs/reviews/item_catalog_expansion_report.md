# Item catalog expansion report (≥160)

**Branch:** `cursor/item-catalog-160-3dd7`  
**PR:** https://github.com/Jongkyung-Ko/GuildMa/pull/20  
**Head SHA:** _(see latest commit on branch)_  
**Base:** `main` @ post PR #19 (shop/blacksmith)  
**Catalog validate:** 2026-11-27 20:11 KST (Asia/Seoul)  
**Painted-icon replace validate:** 2026-11-27 20:23 KST (Asia/Seoul)  
**Do not merge to main** unless explicitly requested.

## 1. Pre-expansion inventory (before)

| Metric | Value |
|---|---|
| Item count | **26** |
| Categories | weapon 6 · armor 6 · accessory 4 · consumable 5 · material 5 |
| Subcategories | none |
| `assets/items/*.png` | 43 files |
| Linked icons | all 26 resolved (no missing paths) |
| Duplicate icon *paths* | none |
| Identical *bytes* among assets | `enhance_stone.png` ≡ `magic_crystal.png`; `rusty_sword.png` ≡ `wooden_sword.png` |
| Unused painted assets | 17 (bow, crest_shield, double_axe, flanged_mace, gem_dagger, gold_pouch, hand_axe, iron_sword, leather_helmet, lion_hammer, magic_crystal, ornate_rapier, ritual_dagger, scimitar, spiked_flail, spiked_mace, wooden_sword) |

## 2. Post-expansion inventory

| Metric | Value |
|---|---|
| Item count | **160** |
| Top-level categories (shop filters unchanged) | weapon 48 · armor 48 · accessory 16 · consumable 16 · material 32 |
| New field | `subcategory` (filters still use `category` only) |
| New field | `balance_status`: `confirmed` (26 existing) / `proposed` (134 new) |

### Subcategory minima (brief targets)

| Target | Required | Actual |
|---|---:|---:|
| 1H weapons (`weapon_1h`) | 16 | 16 |
| 2H weapons (`weapon_2h`) | 16 | 16 |
| Ranged + magic | 16 | 16 (7+9) |
| Shields | 12 | 12 |
| Body armor | 20 | 20 |
| Helm + gloves + boots | 16 | 16 (6+5+5) |
| Accessories | 16 | 16 |
| Consumables | 16 | 16 |
| Craft mats (ore/crystal/hide/part) | 24 | 24 |
| Special | 8 | 8 |

## 3. Preservation

- All **26 existing item IDs** retained.
- Existing **prices / atk / def / heal / slots / icons / rarities / descriptions** unchanged (only additive: `subcategory`, `balance_status`).
- `data/balance.json` enhance rates/costs/materials **not modified**.
- Shop buy/sell, blacksmith enhance, `GameState` inventory APIs unchanged in behavior.
- Shop still filters by the same 5 top-level categories (`ItemUI.CATEGORY_ORDER`).

## 4. Icons / art honesty

| Class | Count | Notes |
|---|---:|---|
| Pre-existing painted `assets/items` (kept) | **41** | Untouched; paths still used by remaps + confirmed items |
| Sheet-split painted-style replacements | **119** | Overwrote former Pillow placeholders at same `<id>.png` paths |
| Remaining Pillow procedural placeholders | **0** | All 119 replaced |
| Missing path / iron_sword fallback | **0** | No silent default-fallback claims |

### Placeholder replace progress (2026-11-27 20:23 KST)

- Method: category sprite sheets (referenced to existing painted icons) → `tools/split_item_category_sheet.py` → 256×256 RGBA PNGs with transparent corners.
- `data/items.json` **unchanged** this pass (IDs, counts, categories, stats, prices, icon paths).
- Pre-expand painted originals: **0 files modified**.
- Resolution/alpha gate: all 119 are **256×256 RGBA**, corner alpha **0**, unique content hashes.
- ID ↔ file map: `docs/reviews/item-catalog-art/placeholder_replace_id_map.md`
- Source sheets: `tools/item_sheets/painted_v2/`

### Honesty caveat (not claiming final art sign-off)

These 119 are **painted-style** replacements matching lighting/materials of the existing set, **not** Pillow shapes. They still await **human art-direction sign-off**; do not treat as locked final production art until reviewed. Thin weapons (bows/spears) are readable but lower fill-area than chunky armor icons.

## 5. Code / tooling touched

- `data/items.json` — expanded to 160 + `meta.subcategory_labels` (**not modified** in icon-replace pass)
- `assets/items/*.png` — catalog expand + later painted-style overwrite of 119 placeholders
- `scripts/ui/item_ui.gd` — subcategory labels (non-breaking)
- `scripts/ui/shop_panel.gd` / `blacksmith_panel.gd` — detail shows subcategory + proposed badge
- `scripts/core/validate_shop_blacksmith.gd` — requires ≥160, subcategory minima, filter non-empty, price preserve
- `tools/expand_item_catalog_160.py` — catalog generator
- `tools/split_item_category_sheet.py` — sheet → transparent icon splitter
- `tools/item_sheets/painted_v2/` — category sheets used for replace pass

**Not touched:** combat, town layout, hall, enhance balance table.

## 6. Real Godot test results

Command:

```bash
DISPLAY=:1 godot4 --path . --headless -s res://scripts/core/validate_shop_blacksmith.gd
```

Engine: Godot 4.3.stable.official  

**RESULT: PASS (0 fails)** — excerpt:

```
OK: item catalog count=160
OK: shop filter weapon count=48
OK: shop filter armor count=48
OK: shop filter accessory count=16
OK: shop filter consumable count=16
OK: shop filter material count=32
OK: item ids unique
OK: subcategory weapon_1h=16
OK: subcategory weapon_2h=16
OK: subcategory shield=12
OK: subcategory body=20
OK: subcategory special=8
OK: ranged/magic=16
OK: helm/gloves/boots=16
OK: accessory subs=16
OK: consumable subs=16
OK: craft mat subs=24
OK: sword_basic price preserved
OK: all item icons resolve
OK: buy sword + gold deduct
OK: insufficient gold blocked
OK: sell sword + gold credit
OK: enhance rate +0 = 100%
OK: enhance reached +1
OK: max +10 enhance blocked
OK: equip enhanced gear
OK: facility scene shop loads
OK: facility scene blacksmith loads
OK: facility scene warehouse loads
OK: facility scene guild loads
OK: facility scene gate loads
OK: town loads
=== RESULT: PASS (0 fails) ===
```

Re-run confirmed same PASS after painted-icon replace (2026-11-27 20:23 KST). Excerpt identical functional checks; `OK: all item icons resolve` still holds.

## 7. Proposed / unconfirmed balance

All **134** new items have `"balance_status": "proposed"`. Prices/stats are aligned to the existing ladder but **not finalized**. Shop detail UI labels them `가격/스탯: 제안(미확정)`. Specials with price `0` are explicitly quest/utility stubs.

## 8. Visual QA note

This task is **data/catalog** expansion, not a Guild Hall visual layout change. No independent visual PASS is claimed. Shop grid will be denser (more scroll); functional validate covers buy/sell/enhance + facility loads only.
