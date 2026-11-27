# GuildMaster Project Status

Snapshot for agents. Update when phase boundaries or major merges change. Times in **Asia/Seoul**.

**As of:** 2026-11-27 · tip reference: `main` (post PR #19 shop/blacksmith) · permanent rules PR may be open in parallel.

## Phase

| Phase | State |
|---|---|
| Phase 1 — Title, town hub, facilities UI, save/load | **Done** (baseline) |
| Phase 2 / 2-1 — Hunt, combat prototype, dungeon floors, BGM | **In progress / largely playable** |
| Guild Hall responsive landscape + visual-review process | **Landed** (PR #16–#18) |
| Shop buy/sell + blacksmith enhance | **Landed** (PR #19) |
| Item catalog ≥160 + placeholder art replace | **Open on branch** (PR #20) — not main until merged |
| Permanent Cursor rules + standards + quality validators | **This docs PR** |
| Full guild ops / fame / wages / raids / sieges (GDD later systems) | **Not started** as complete systems |

## Done (high level)

- Godot 4.3 project; GL Compatibility; 1280×720; Nearest; Noto Sans KR embedded
- Town hub + facility shell; guild hall landscape composition
- Combat / hunt / dungeon flows with validates and capture scripts
- AudioManager BGM/SFX wiring (title/town/combat/hunt paths)
- Shop + blacksmith functional systems + item icons under `assets/items/`
- Autonomous visual-review rules + Guild Hall landscape rules

## Open / in flight

- PR #20 item catalog expansion (if still open): larger catalog, subcategory fields, art honesty
- Remaining art upgrades called out in `docs/art/QUALITY_DIAGNOSIS.md` (portraits, some UI panels, VFX depth, etc.)
- GDD systems not yet built (see Decision Log UNDECIDED + GDD §16–17)
- Independent visual QA required for any new UI/layout work before visual QUALITY PASS

## Quality state (honest)

| Area | Rough grade | Notes |
|---|---|---|
| Function (town/hall/combat/shop paths) | ~Q3–Q4 | Many `validate_*.gd` scripts exist; not every path covered |
| Graphics (items on main ~26 painted icons) | ~Q3 | Technical ≥256 often met; Q5/sign-off not claimed |
| Graphics (characters/monsters/VFX) | ~Q2–Q3 | Playable sprites; diagnosis still lists debt |
| UI/UX (hall landscape) | ~Q3–Q4 | Independent QA loop established; portrait out of scope |
| Data (items on main) | ~Q3 | 26 items with icons; expansion not on main |
| Stability | ~Q3 | Smoke/validates help; not a full QA matrix |

**Do not mark project-wide APPROVED.** Per-feature APPROVED only after explicit owner sign-off.

## Next (suggested order — not a commitment)

1. Land permanent rules/standards/validators (this work) without merging game content PRs prematurely.
2. Resolve item catalog PR (#20) art honesty + validate gates when ready for review.
3. Continue facility/art upgrades against Art Bible; keep placeholder lists honest.
4. Only then expand GDD systems (fame, wages automation, raids, sieges) with decision-log updates.

## Key commands

```bash
# Quality asset/data gates (docs PR)
python3 tools/validate_quality_assets.py
godot4 --path . --headless -s res://scripts/core/validate_quality_assets.gd

# Guild hall visual captures (needs display)
DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_guild_hall_audit.gd

# Functional hall validate (not visual PASS)
DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/validate_guild_hall.gd
```

## Related

- `GUILDMASTER_QUALITY_STANDARD.md` · `GUILDMASTER_ART_BIBLE.md` · `GUILDMASTER_DECISION_LOG.md`
- `AGENTS.md` · `docs/autonomous-visual-review.md`
