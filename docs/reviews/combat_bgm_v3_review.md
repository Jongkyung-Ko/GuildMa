# Combat BGM Pack v3 — review

**Date:** 2026-11-27 (Asia/Seoul)  
**Repo:** Jongkyung-Ko/GuildMa `main` @ `73b2500`  
**Pack:** `GuildMaster_Combat_Music_Pack_v3.zip`

## Summary

Added four combat MIDI sources + FluidSynth/FluidR3_GM OGG renders. `AudioManager` now rotates a normal-combat playlist with end-of-track fade, and plays a dedicated looping boss track on mid/final dungeon floors. Town music, SFX buses, combat logic/UI/balance unchanged.

## Assets

| Source MIDI | Playback OGG | Role |
|-------------|--------------|------|
| `03_combat_epic_rock.mid` | `.ogg` (~59s) | Playlist #1 Epic |
| `05_combat_heroic_anthem.mid` | `.ogg` (~63s) | Playlist #2 Heroic |
| `04_combat_metal_drive.mid` | `.ogg` (~55s) | Playlist #3 Metal |
| `06_combat_boss_intensity.mid` | `.ogg` (~54s) | Boss only (loop) |
| `02_hunting_grounds_rock.mid` | `.ogg` (retained) | Playlist #4 |

Render command (per `assets/audio/README.md`):

```bash
SF=/usr/share/sounds/sf2/FluidR3_GM.sf2
fluidsynth -ni "$SF" <track>.mid -F /tmp/<track>.wav -r 44100
ffmpeg -y -i /tmp/<track>.wav -c:a libvorbis -q:a 5 <track>.ogg
```

## Behaviour

- **Normal combat:** shuffled queue over Epic → Heroic → Metal → Hunting; no immediate consecutive repeat; full cycle then reshuffle; `loop=false` per track; on `finished` → ~1.5s fade out/in to next.
- **Boss combat:** floor `boss` mid/final (or `boss_*` enemy id) → `combat_boss` looping only; no playlist overlap.
- **Pause:** `combat_manager.toggle_pause` → `pause_bgm` / `resume_bgm`.
- **Leave combat:** `on_enter_town` / `on_enter_facility` clears combat mode, stops ambience, plays town.
- **Volumes:** BGM / SFX buses remain independent.

## Automated tests (`validate_audio.gd`)

Command: `godot4 --headless --path . -s res://scripts/core/validate_audio.gd`  
**Result: PASS** (wiring / assets / playlist / boss detect / town restore).

| Check | Result |
|-------|--------|
| New MIDI 4 registered in `assets/audio/bgm/` | PASS |
| New OGG 4 load via ResourceLoader | PASS |
| `02_hunting_grounds_rock.ogg` retained | PASS |
| Playlist order Epic→Heroic→Metal→Hunting | PASS |
| Playlist rotation without consecutive duplicate | PASS |
| All 4 playlist tracks appear in rotation | PASS |
| F5 mid / F10 final → `combat_boss` | PASS |
| F1 → playlist (not boss) | PASS |
| Town restore + ambience stop | PASS |
| Single BGM player (no duplicate nodes) | PASS |
| BGM/SFX volume independence | PASS |
| Pause / resume API | PASS |
| **Ear / audible listening (speakers or Pages)** | **NOT DONE** — not marked PASS |
| Seamless musical bar-level loop edit | N/A (file end + fade; no DAW trim) |

## Not changed

Combat spawn/AI/VFX, party, UI layout (except audio pause hook), balance JSON, town theme.

## Web export

- **Local headless:** `godot4 --headless --path . --export-release "Web"` → **PASS** (`savepack` completed; templates 4.3.stable present).
- **Pages CI:**
  - Direct runs on `73b2500` / `67c4daa` were **cancelled** by `web-preview` concurrency when a newer `main` push arrived.
  - Tip `0da5e2b` (ancestor chain includes `73b2500`) → **success** — Export & validate Web build ✅, Deploy to GitHub Pages ✅ ([run 45846033257](https://github.com/Jongkyung-Ko/GuildMa/actions/runs/45846033257), Asia/Seoul 2026-11-27 00:09).
  - Local audible listening on Pages: **not done** (not PASS).
