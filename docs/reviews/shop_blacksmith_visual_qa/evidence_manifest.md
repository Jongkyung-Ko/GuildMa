# Shop / Blacksmith visual QA evidence manifest

| Field | Value |
|---|---|
| **PR** | https://github.com/Jongkyung-Ko/GuildMa/pull/20 |
| **Branch** | `cursor/item-catalog-160-3dd7` |
| **Base tip before evidence commit** | `4128b72b926925f80052f6726cc8475d2dc7cd92` |
| **Evidence PNG commit SHA** | `06a6e4a16891fc42ae048902a0f8534efcaf1f97` |
| **Branch tip SHA** | `dddc05beeac795d76ad43ceed15cf92c014546cf` |
| **Resolution** | **1366×768** (PC landscape) for all PNGs |
| **Engine** | Godot 4.3.stable.official · `DISPLAY=:1` · `--display-driver x11` · `--rendering-driver opengl3` |
| **Capture script** | `res://scripts/core/capture_shop_blacksmith_visual_qa.gd` |
| **Real-run flag** | **YES** — live Godot facility UI screenshots (not mocks/composites) |
| **Do not delete** | Keep evidence until ChatGPT confirms review complete |

## How to reproduce

```bash
DISPLAY=:1 godot4 --path . --display-driver x11 --rendering-driver opengl3 \
  -s res://scripts/core/capture_shop_blacksmith_visual_qa.gd
```

Optional: `STORE_DIR=/path/to/store/media/shop-blacksmith-visual-qa`

## Game state (seeded for capture)

- `GameState.new_game()` then gold forced to **50000**
- Bought: `sword_basic`×3, `armor_leather`×2, `ring_copper`×1, `potion_hp_s`×3
- Materials: `enhance_stone`×40 (+ more during fail path), `ore_iron`×10, `ore_mithril`×6, `crystal_fire`×4
- Converted one `sword_basic` to **+2**; added `sword_steel` **+9** for fail attempt

## Screens

### Shop

| Path | Screen name | In-game path | Checklist items | Notes |
|---|---|---|---|---|
| `docs/reviews/shop_blacksmith_visual_qa/evidence/shop_main.png` | Shop main | Town → Facility `shop` → buy mode, weapon category | Open shop; default category | Same visual state as `shop_weapon` (buy+weapon is the shop default). |
| `docs/reviews/shop_blacksmith_visual_qa/evidence/shop_weapon.png` | Shop · Weapons | Shop → category **무기** | All categories | 4-column item cards with painted icons + rarity chrome. |
| `docs/reviews/shop_blacksmith_visual_qa/evidence/shop_armor.png` | Shop · Armor | Shop → category **방어구** | All categories | |
| `docs/reviews/shop_blacksmith_visual_qa/evidence/shop_accessory.png` | Shop · Accessories | Shop → category **장신구** | All categories | |
| `docs/reviews/shop_blacksmith_visual_qa/evidence/shop_consumable.png` | Shop · Consumables | Shop → category **소모품** | All categories | |
| `docs/reviews/shop_blacksmith_visual_qa/evidence/shop_material.png` | Shop · Materials | Shop → category **재료** | All categories | |
| `docs/reviews/shop_blacksmith_visual_qa/evidence/shop_item_detail.png` | Shop · Item detail | Shop → weapon → select mid-list item | Select item; detail panel | Right panel shows large icon, rarity, subcategory, stats, qty, buy CTA. |
| `docs/reviews/shop_blacksmith_visual_qa/evidence/shop_purchase.png` | Shop · Purchase confirm | Shop → Buy → AcceptDialog | Buy flow | **Closest real state:** built-in `AcceptDialog` (“구매확인”), not a custom purchase-result screen. |
| `docs/reviews/shop_blacksmith_visual_qa/evidence/shop_sell.png` | Shop · Sell | Shop → mode **판매** → weapon inventory | Sell flow | Sell mode + owned cards + sell CTA. **No separate sell-result modal** (inline feedback only). |

### Blacksmith

| Path | Screen name | In-game path | Checklist items | Notes |
|---|---|---|---|---|
| `docs/reviews/shop_blacksmith_visual_qa/evidence/blacksmith_main.png` | Blacksmith main | Town → Facility `blacksmith` | Open blacksmith | UI **auto-selects** first enhanceable gear; no empty-selection state exists. |
| `docs/reviews/shop_blacksmith_visual_qa/evidence/blacksmith_target.png` | Blacksmith · Target selected | Blacksmith → select `sword_basic` **+2** | Select enhance target | Gold selection chrome on inventory card. |
| `docs/reviews/shop_blacksmith_visual_qa/evidence/blacksmith_upgrade_detail.png` | Blacksmith · Upgrade detail | Same panel as target | Enhance cost/rate/materials | Center panel: costs, success %, materials, enhance CTA. |
| `docs/reviews/shop_blacksmith_visual_qa/evidence/blacksmith_stat_compare.png` | Blacksmith · Stat compare (강화 전후) | Same panel as target | Before/after stats | **Same center UI** as upgrade_detail (before/after icons + delta lines). No separate compare screen. |
| `docs/reviews/shop_blacksmith_visual_qa/evidence/blacksmith_upgrade_success.png` | Blacksmith · Upgrade success | Enhance `sword_basic` +0→+1 (rate 100%) | Enhance success | Real `enhance_item` success + gold flash overlay + success feedback text. |
| `docs/reviews/shop_blacksmith_visual_qa/evidence/blacksmith_upgrade_fail.png` | Blacksmith · Upgrade fail | Enhance `sword_steel` +9 (seeded fail) | Enhance fail | Real `enhance_item` fail (`failure_rule=keep`) + red flash overlay. Spark VFX skipped only so RNG seed stays stable; hammer/furnace glow shown. |

## Honesty / gaps

1. **shop_main ≈ shop_weapon** — default shop lands on weapon buy.
2. **No dedicated purchase-result or sell-result modal** — purchase uses AcceptDialog confirm; sell is immediate with inline feedback.
3. **blacksmith_upgrade_detail ≈ blacksmith_stat_compare** — one center panel shows both compare and costs.
4. **blacksmith_main** always has a target once inventory has enhanceables.
5. Evidence must **not** be deleted until ChatGPT confirms the visual review is done.

## Post-review delete procedure

After ChatGPT confirms review complete:

```bash
git rm -r docs/reviews/shop_blacksmith_visual_qa/evidence
# optionally keep evidence_manifest.md as historical pointer or remove with folder
git commit -m "chore: remove shop/blacksmith visual QA evidence after ChatGPT review"
git push origin cursor/item-catalog-160-3dd7
```

Do **not** delete earlier. Do **not** merge to `main` unless explicitly requested.
