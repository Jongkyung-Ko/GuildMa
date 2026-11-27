# Shop / Blacksmith visual QA evidence manifest

| Field | Value |
|---|---|
| **PR** | https://github.com/Jongkyung-Ko/GuildMa/pull/20 |
| **Branch** | `cursor/item-catalog-160-3dd7` |
| **Prior FAIL cycle tip** | ChatGPT visual QA **FAIL** on first evidence set (`06a6e4a`) |
| **Fix cycle** | P1 card/scroll + local enhance FX + P2 sell feedback; evidence PNGs **overwritten in place** (not deleted) |
| **Prior UI fix commit** | `deee2504c01056658de99f693d2abac8e9c20550` |
| **Category-scroll fix commit** | _(this push)_ |
| **Resolution** | **1366×768** + short mobile landscape **844×390** proof |
| **Engine** | Godot 4.3.stable.official · `DISPLAY=:1` · x11 · opengl3 |
| **Capture scripts** | `capture_shop_blacksmith_visual_qa.gd`, `capture_shop_category_scroll.gd` |
| **Validate** | `validate_shop_blacksmith.gd` → **PASS (0 fails)** after category-scroll fix |
| **Real-run flag** | **YES** |
| **Visual PASS claim** | **No** — fix + proof only; ChatGPT owns re-review |
| **Do not delete** | Keep evidence until ChatGPT confirms review complete |

## Fixes addressed (ChatGPT FAIL → this cycle)

### P1A — Shop grid / categories
- Taller cards (`min_h` ~188), larger `v_separation` (14), autowrap name/subtype — no clipped subtype text
- Subcategory line on cards
- Desktop: **no outer body scroll**; catalog ScrollContainer independent; left category column has its own scroll so all 5 cats + buy/sell reachable
- Shorter atmosphere portrait so categories fit at 1366×768 / short landscape

### Follow-up — left category panel clip (live FAIL)
- Category column height tracks **available height** (window-aware; resize-safe)
- Independent `CategoryScroll` (SHOW_ALWAYS) with **right pad** so scrollbar does not cover buttons
- Buy/sell **pinned under** the scroll (not clipped at panel bottom)
- Short landscape clamps left host height so content cannot grow past the viewport
- **Did not** change card size/gaps, catalog scroll, detail panel, buy/sell logic, colors/borders/fonts/icons

### P1B — Blacksmith success/fail FX
- Removed full-screen `ColorRect` wash
- Local gold/red border pulse + shadow on compare icons + soft wash **only on compare row** + particles
- Stats/materials remain readable during FX
- **No enhance logic / rates / costs changed**

### P2 — Sell inline feedback
- Post-sell message: success, **gold gained**, **remaining qty**, **current gold**
- Dialogue + gold chip update via existing `state_changed`

## How to reproduce

```bash
DISPLAY=:1 godot4 --path . --display-driver x11 --rendering-driver opengl3 \
  -s res://scripts/core/capture_shop_blacksmith_visual_qa.gd

DISPLAY=:1 godot4 --path . --headless -s res://scripts/core/validate_shop_blacksmith.gd
```

## Game state (seeded for capture)

- `new_game()` + gold **50000**
- Bought: `sword_basic`×3, `armor_leather`×2, `ring_copper`×1, `potion_hp_s`×3
- Materials: stones/ores/crystal; one `sword_basic` **+2**; `sword_steel` **+9** for fail

## Screens (1366×768 — recaptured this cycle)

| Path | Screen | Notes |
|---|---|---|
| `evidence/shop_main.png` | Shop main | ≈ shop_weapon default |
| `evidence/shop_weapon.png` | Weapons | taller cards + subtype + catalog scroll |
| `evidence/shop_armor.png` | Armor | |
| `evidence/shop_accessory.png` | Accessories | |
| `evidence/shop_consumable.png` | Consumables | |
| `evidence/shop_material.png` | Materials | |
| `evidence/shop_item_detail.png` | Item detail | |
| `evidence/shop_purchase.png` | Purchase confirm | AcceptDialog (unchanged honesty) |
| `evidence/shop_sell.png` | **Post-sell** | inline: +G, remain qty, current gold |
| `evidence/blacksmith_main.png` | Blacksmith main | auto-select first gear |
| `evidence/blacksmith_target.png` | Target selected | |
| `evidence/blacksmith_upgrade_detail.png` | Upgrade detail | current vs next panels |
| `evidence/blacksmith_stat_compare.png` | Stat compare | same center panel |
| `evidence/blacksmith_upgrade_success.png` | Success | **local** gold FX, no full-screen wash |
| `evidence/blacksmith_upgrade_fail.png` | Fail | **local** red FX; steel +9 keep |

## Category-scroll proof (added; prior evidence kept)

| Path | Size | Notes |
|---|---|---|
| `evidence/shop_category_scroll_before_ref_1366x768.png` | 1366×768 | Before-ref copy of prior `shop_weapon` |
| `evidence/shop_category_scroll_844x390.png` | 844×390 | Short landscape; category scroll top |
| `evidence/shop_category_scroll_bottom_844x390.png` | 844×390 | Scrolled to last category |
| `evidence/shop_category_scroll_1366x768.png` | 1366×768 | Desktop; category scrollbar + pinned buy/sell |
| `evidence/shop_category_scroll_bottom_1366x768.png` | 1366×768 | Category list scrolled to bottom |

```bash
DISPLAY=:1 godot4 --path . --display-driver x11 --rendering-driver opengl3 \
  -s res://scripts/core/capture_shop_category_scroll.gd
```

## Post-review delete (only after ChatGPT confirms)

```bash
git rm -r docs/reviews/shop_blacksmith_visual_qa/evidence
git commit -m "chore: remove shop/blacksmith visual QA evidence after ChatGPT review"
git push origin cursor/item-catalog-160-3dd7
```
