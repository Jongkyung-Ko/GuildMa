# Shop / Blacksmith visual upgrade report

Branch: `cursor/shop-blacksmith-system-4a41` · PR #19  
Scope: graphics + UI only. Buy/sell/enhance prices, rates, materials, and other facilities unchanged.

## Source art

| File | Role |
|---|---|
| `tools/item_sheets/weapons_4x4_sheet.png` (from store `media/shop-item-sheets/`) | **Production** — split into 16 transparent 256×256 icons |
| `tools/item_sheets/item_catalog_sheet.png` | **Style reference only** — sheet is 655×436 with ~15×16 tiny cells (~25px). **Not cropped/upscaled** into production icons |

## Asset pipeline

- Finals live under `assets/items/` (underscore lowercase names).
- Split tool: `tools/split_weapons_sheet.py` (black-key + trim + pad → 256² RGBA).
- Non-weapon categories: painted-style originals at 256² (not catalog crops). Documented below as style-matched.
- `data/items.json` `icon` paths remapped to `res://assets/items/…`.
- `ItemUI.load_icon` fallbacks: `assets/items` → legacy `assets/sprites/items` → default.

### Weapon sheet → filenames (4×4 row-major)

| Cell | File |
|---|---|
| 0,0–0,3 | `rusty_sword`, `iron_sword`, `steel_arming_sword`, `ornate_sword` |
| 1,0–1,3 | `scimitar`, `twin_daggers`, `gem_dagger`, `hand_axe` |
| 2,0–2,3 | `battle_axe`, `double_axe`, `spiked_mace`, `flanged_mace` |
| 3,0–3,3 | `lion_hammer`, `spiked_flail`, `ornate_rapier`, `ritual_dagger` |

Also present (non-sheet / style-matched): `wooden_shield`, `crest_shield`, `leather_armor`, `chain_armor`, `plate_armor`, `leather_helmet`, `iron_helmet`, `leather_boots`, `bow`, `magic_staff`, potions, ores, `enhance_stone`, rings, `ward_amulet`, `power_belt`, `gold_pouch`, `wooden_sword` (alias of rusty).

### Item id → icon mapping

| Item id | Icon file | Source |
|---|---|---|
| `sword_basic` | `rusty_sword.png` | weapons sheet |
| `sword_steel` | `steel_arming_sword.png` | weapons sheet |
| `axe_battle` | `battle_axe.png` | weapons sheet |
| `dagger_swift` | `twin_daggers.png` | weapons sheet |
| `staff_oak` | `magic_staff.png` | style-matched (no staff on weapons sheet) |
| `blade_rune` | `ornate_sword.png` | weapons sheet |
| `armor_leather` | `leather_armor.png` | style-matched |
| `armor_chain` | `chain_armor.png` | style-matched |
| `shield_wood` | `wooden_shield.png` | style-matched |
| `helm_iron` | `iron_helmet.png` | style-matched |
| `boots_leather` | `leather_boots.png` | style-matched |
| `plate_guardian` | `plate_armor.png` | style-matched |
| accessories / consumables / materials | matching `assets/items/*` | style-matched |

**Missing from weapons sheet (called out):** staff, all armor/accessories/consumables/materials — filled with style-matched 256px art; catalog cells too small to crop.

## UI notes

### Shop
- Larger atmosphere portrait; gold-pressed category + buy/sell mode.
- Center **item cards**: icon, name, rarity chrome, price, equippable/qty subtitle.
- Right detail: large icon, rarity/type, desc, stats, qty, unit+total, buy; disabled buy + **shortfall gold** text.

### Blacksmith
- Larger smith atmosphere + short enhance guide (levels, failure rule).
- Center before/after icons; stats as `공격력 13 → 14 (+1)` (green); success % / gold / materials panel; enhance CTA.
- Right: enhanceable gear cards only, `+N`, gold select border.
- Existing success/fail VFX retained (furnace / sparks / gold-red flash). Logic untouched.

### Design tokens
Deep navy/brown cards (`ItemUI.CARD_BG`), antique gold accents, rarity borders gray→green→blue→purple→gold-orange, thicker border on selection.

## Tests (real runs)

```
godot4 --headless --path . -s res://scripts/core/validate_shop_blacksmith.gd  → PASS
godot4 --headless --path . -s res://scripts/core/smoke_test.gd               → PASS
DISPLAY=:1 godot4 --display-driver x11 -s res://scripts/core/capture_shop_blacksmith.gd  → 6 PNGs
```

Balance/logic: prices, sell ratio, enhance rates/costs/materials/`failure_rule` unchanged from prior PR commit.

## Captures

Store: `media/shop-blacksmith-upgrade/` (Project store)  
Repo: `docs/reviews/shop-blacksmith/upgrade_captures/`

- `landscape_844x390_shop_main.png`
- `landscape_844x390_blacksmith_main.png`
- `landscape_844x390_warehouse.png`
- `pc_1366x768_shop_main.png`
- `pc_1366x768_blacksmith_main.png`
- `pc_1366x768_warehouse.png`

Before (prior feature): `docs/reviews/shop-blacksmith/captures/` and store `media/shop-blacksmith/`.

Independent visual eye PASS is not claimed here; functional validates + captures are evidence only.
