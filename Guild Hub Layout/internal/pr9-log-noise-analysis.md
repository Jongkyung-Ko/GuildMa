# PR #9 Log Noise Analysis (Parameter "t" / ObjectDB)

Godot **4.3.stable** · branch `cursor/combat-ai-map-travel-60e0`

## 1. `ERROR: Parameter "t" is null` (dungeon.log)

| Field | Detail |
|-------|--------|
| **Where** | Engine: `servers/rendering/dummy/storage/texture_storage.h:106` → `texture_2d_get` |
| **Caller** | `scripts/core/validate_dungeon.gd` → `_capture()` → `root.get_viewport().get_texture().get_image()` |
| **When** | Every screenshot attempt in **`--headless`** (hub_f1, combat_f*_spawn, mid/final boss win, …) |
| **Cause** | Headless Godot uses the **dummy** renderer. Viewport textures have no GPU RID; `get_image()` passes a null texture handle (`t`) into `texture_2d_get`. Followed by script `WARN: no viewport image for …`. |
| **Gameplay impact** | **None.** Suite still reached `=== RESULT: OK ===`. Not a dungeon combat bug. |
| **Action** | Test harness only: skip `_capture` when `DisplayServer.get_name() == "headless"`. No game feature code change. |

## 2. `ObjectDB instances leaked` / `resources still in use at exit`

| Suite | Verbose leak content |
|-------|----------------------|
| direction_travel | `AudioStreamWAV` `01_ui_button_click.wav` + playback |
| combat_ai | `03_combat_hit.wav`, `04_magic_cast.wav` + playbacks |
| dungeon | Same pattern (autoload audio still held at process exit) |

| Field | Detail |
|-------|--------|
| **Cause** | Autoload `AudioManager` loads SFX into `AudioStreamPlayer.stream` during the run. `-s` SceneTree validators call `quit()` while the autoload (and its stream refs) still exist. Godot then reports those as exit-time leaks. |
| **Gameplay impact** | **None** for shipped game / Web. Autoloads are meant to live for the process lifetime; normal scene flow does not abrupt-quit a SceneTree script the same way. |
| **Action** | **No feature-code change.** Clearing streams only in validators would be optional noise reduction, not a product fix. Leaving as-is to avoid touching AudioManager behavior. |

## Verdict

- PASS results remain valid.
- Parameter `"t"` = headless screenshot artifact → harness skip.
- ObjectDB / resource-at-exit = expected `-s` + AudioManager autoload noise → no product fix.
