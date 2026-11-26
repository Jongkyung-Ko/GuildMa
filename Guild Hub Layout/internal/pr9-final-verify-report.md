# PR #9 Final Pre-Merge Verification

- **When:** 2026-11-26 (Asia/Seoul)
- **Godot:** 4.3.stable.official.77dcf97d8
- **Branch:** `cursor/combat-ai-map-travel-60e0`
- **Logs:** `Guild Hub Layout/internal/pr9-final-verify-logs/`
- **Log noise notes:** `Guild Hub Layout/internal/pr9-log-noise-analysis.md`

## Suite results

| Suite | Exit | Result |
|-------|------|--------|
| validate_combat_ai.gd | 0 | **PASS** (11 pass / 0 fail) |
| validate_direction_travel.gd | 0 | **PASS** (14 pass / 0 fail) |
| validate_korean_font.gd | 0 | **PASS** (16 pass / 0 fail) |
| validate_hunt_maze.gd | 0 | **PASS** (22 pass / 0 fail) |
| validate_dungeon.gd | 0 | **OK** (logic / progression) |
| Web Export | 0 | **OK** (`savepack: end`) |

## Checklist vs logs

| Item | Verdict | Evidence |
|------|---------|----------|
| Monster repeat attack + real HP damage | PASS | `ENEMY 고블린 started=4 … hits=4`; `PASS: enemies started=4 damage_hits=4` |
| Mage repeat projectile + real damage | PASS | `mage started=3 fired=3 hits=3` |
| Dead ally revive 35% HP | PASS | `revive dead ally hp=51.8 (~35% of 148.0)` |
| Living ally +15% heal | PASS | `living ally healed +15% → hp=124.8` |
| CollisionShape2D re-enabled | PASS | `revive CollisionShape2D re-enabled` |
| Victory: only connected dir buttons | PASS | connected dirs shown; null dir hidden |
| Button click → next room | PASS | `button click travelled N → …` |
| Cleared room: no re-fight | PASS | `cleared revisit via button stays victory (no fight)` |
| Dungeon blocks pad travel | PASS | `dungeon mode blocks hunt direction travel` |
| Korean minimap / modal **string metrics** (Noto) | PASS | 미니맵/현재 위치/… widths OK in korean_font.log |
| Dungeon **on-screen / visual** verification | **NOT DONE in headless** | See below — separate confirmation required |

## Key log excerpts (latest archived logs)

### combat_ai SUMMARY
```
SUMMARY mage started=3 fired=3 hits=3 | enemy started=4 hits=4 | dps hits=6
=== COMBAT AI RESULT: PASS (11 pass / 0 fail) ===
WARNING: ObjectDB instances leaked at exit (run with --verbose for details).
ERROR: 2 resources still in use at exit (run with --verbose for details).
```

### direction_travel
```
=== DIRECTION TRAVEL RESULT: PASS (14 pass / 0 fail) ===
WARNING: ObjectDB instances leaked at exit (run with --verbose for details).
ERROR: 1 resources still in use at exit (run with --verbose for details).
```

### dungeon (headless)
```
SKIP capture under headless (no GPU texture): hub_f1
… (same SKIP for combat spawn / boss win captures)
=== RESULT: OK ===
WARNING: ObjectDB instances leaked at exit (run with --verbose for details).
ERROR: 1 resources still in use at exit (run with --verbose for details).
```

## Residual exit messages vs analysis

| Topic | Still present in logs? | Analysis conclusion |
|-------|------------------------|---------------------|
| `ObjectDB instances leaked at exit` | **Yes** — combat_ai, direction_travel, dungeon | Expected `-s` quit while Autoload `AudioManager` still holds SFX streams. **Not treated as a gameplay failure.** No product fix in this PR. |
| `resources still in use at exit` | **Yes** — same suites (counts 1–2) | Same root cause (WAV resources held by AudioManager). Analysis ≠ “messages removed.” |
| `ERROR: Parameter "t" is null` | **No** in refreshed dungeon.log (0 hits) | Was headless `get_image()` on dummy textures. Harness now skips capture; Parameter-t spam cleared. |

Cause write-up: `pr9-log-noise-analysis.md`. Do not confuse “explained / accepted noise” with “lines deleted from logs.”

## Headless capture skip ≠ visual test complete

Skipping `_capture` under headless only avoids invalid GPU texture reads. It does **not** mean dungeon hub / combat floors were visually verified.

**Still required separately (e.g. xvfb / desktop / Web Pages playtest):**

- Dungeon hub layout and floor UI
- Combat spawn visuals (F1 / mid-boss F5 / final-boss F10)
- Victory / floor-clear screenshots if evidence is needed for UI

Headless dungeon suite **OK** covers progression & spawn **logic** only.

## Merge status

Logic suites green; exit-leak lines remain as documented noise; dungeon **visual** check still outstanding. **Do not merge** until explicit user approval.
