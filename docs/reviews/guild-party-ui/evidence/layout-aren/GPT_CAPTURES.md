# GPT visual verification — layout redesign + Aren in-list

Keep until GPT / user approval. **Do not bulk-apply** ornate frame to other roster cards.

## Scope

- Remove floating/large hero preview feel — Aren kit card lives **inside** 길드원 목록 grid
- Compact formation chrome; fixed-width detail column; narrow nav while formation open
- Kit frames: `card_frame_default` UV-locked (selected PNG not used for UV); fringe clean on kit PNGs
- Pixel roster portrait NEAREST, capped ~96px (no COVER mush)
- Other guild cards keep prior style

## Captures

| File | What |
|---|---|
| `party_formation_main_844x390.png` | Full @ 844 |
| `party_formation_main_1280x720.png` | Full @ 1280 |
| `party_formation_main_1366x768.png` | Full @ 1366 |
| `party_formation_detail_*.png` | Focus/detail states |
| `aren_card_solo_1280x720.png` | Aren card crop |
| `detail_panel_solo_1280x720.png` | Detail crop |

Repo: `docs/reviews/guild-party-ui/evidence/layout-aren/`  
Store: `/cursor/stores/bc-e37588d2-6890-4fb7-945a-c6a1997eb0b9/media/guild-party-ui/evidence/layout-aren/`  
Artifacts: `/opt/cursor/artifacts/party-layout-aren/`

## Checklist

1. Aren card inside guild list (not a separate large preview outside the list)
2. No floating independent card
3. Right detail fully on-screen
4. Frame chrome does not cover name/stats text
5. Aren portrait not excessively blurry (96×96 NEAREST cap)
6. Card not mid-clipped on first paint
7. HP·ATK·DEF readable
8. 3 skill wells at bottom (filled/empty)
9. Party strip does not overlap list
10. Save / select / filter still work (auto validate)
