# PR #9 Log Noise Analysis (Parameter "t" / ObjectDB)

Godot **4.3.stable** · branch `cursor/combat-ai-map-travel-60e0`

This note separates **(A) root-cause analysis** from **(B) what still appears in archived logs**.

## 1. `ERROR: Parameter "t" is null` (historical dungeon.log)

| Field | Detail |
|-------|--------|
| **Where** | Engine: `servers/rendering/dummy/storage/texture_storage.h` → `texture_2d_get` |
| **Caller** | `validate_dungeon.gd` → `_capture()` → `get_viewport().get_texture().get_image()` |
| **Cause** | `--headless` dummy renderer has no GPU texture RID; `get_image()` passed null `t`. |
| **Gameplay impact** | None. Suite still `RESULT: OK`. |
| **Harness change** | Skip `_capture` when `DisplayServer.get_name() == "headless"`. |
| **Current logs** | Refreshed `dungeon.log`: **0** Parameter-t lines; replaced by `SKIP capture under headless…`. |

**Important:** Skipping headless capture removes a false GPU error. It does **not** complete dungeon **visual** verification. Screenshots / UI look still need a non-headless or Web playtest.

## 2. `ObjectDB instances leaked` / `resources still in use at exit`

### A. Analysis (why it happens)

| Field | Detail |
|-------|--------|
| **Cause** | Autoload `AudioManager` keeps SFX `AudioStreamWAV` / playback objects alive. `-s` validators call `quit()` without tearing the autoload down. |
| **Verbose examples** | `01_ui_button_click.wav`, `03_combat_hit.wav`, `04_magic_cast.wav` |
| **Gameplay impact** | None for normal game / Web lifetime. |
| **Product fix** | None in this PR (intentionally). |

### B. Residual messages (still in current archived logs)

These lines are **still present** after the latest re-run:

| Log file | Residual lines |
|----------|----------------|
| `combat_ai.log` | `WARNING: ObjectDB instances leaked…` + `ERROR: 2 resources still in use at exit` |
| `direction_travel.log` | `WARNING: ObjectDB…` + `ERROR: 1 resources still in use at exit` |
| `dungeon.log` | `WARNING: ObjectDB…` + `ERROR: 1 resources still in use at exit` |

**Interpretation:** Analysis explains the noise; it does **not** claim the messages were scrubbed. Suite PASS/OK is independent of these exit warnings.

## Verdict

| Item | Status |
|------|--------|
| Parameter `"t"` under headless | Fixed in harness (skip); gone from refreshed dungeon.log |
| ObjectDB / resources-at-exit | **Still logged**; accepted as `-s` + AudioManager noise |
| direction_travel PASS count | **14/0** (latest log) |
| Dungeon visual QA | **Still needed separately** — headless SKIP ≠ visual complete |
