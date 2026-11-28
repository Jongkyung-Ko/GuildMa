# GPT visual verification — namecard clip-fix

Keep until GPT verification finishes. Do **not** delete concept reference or game assets.

## Captures (844 / 1280 / 1366)

| File | State |
|---|---|
| `party_formation_main_844x390.png` | Opening hunt formation |
| `party_formation_detail_844x390.png` | Focus member + detail |
| `party_formation_filter_dps_844x390.png` | DPS filter |
| `party_formation_main_1280x720.png` | Opening hunt formation |
| `party_formation_detail_1280x720.png` | Focus member + detail |
| `party_formation_filter_dps_1280x720.png` | DPS filter |
| `party_formation_main_1366x768.png` | Opening hunt formation |
| `party_formation_detail_1366x768.png` | Focus member + detail |
| `party_formation_filter_dps_1366x768.png` | DPS filter |

Repo: `docs/reviews/guild-party-ui/evidence/namecard-clip-fix/`  
Store: `/cursor/stores/bc-e37588d2-6890-4fb7-945a-c6a1997eb0b9/media/guild-party-ui/evidence/namecard-clip-fix/`  
Artifacts: `/opt/cursor/artifacts/party-namecard-clip-fix/`

## GPT checklist

1. First screen: at least one full namecard row (portrait → name/job/lv → HP·ATK·DEF → 3 skill wells)
2. Skill row not mid-clipped on first paint (scroll is for more cards, not card bottoms)
3. HP / ATK / DEF numbers readable
4. Portraits not mushy beyond 96×96 pixel source limit (NEAREST)
5. Detail panel: **one** character visual (no portrait + idle side-by-side duplicate)
6. Scroll: cards do not overlap; second row may be partial until scrolled

## Layout measurements (dev evidence, not visual PASS)

| Size | scroll_h | card_h | room after 1st row |
|---|---|---|---|
| 844×390 | 350 | 148 | +202 |
| 1280×720 | 325 | 188 | +137 |
| 1366×768 | 325 | 188 | +137 |
