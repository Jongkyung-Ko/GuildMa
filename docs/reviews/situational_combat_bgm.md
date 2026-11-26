# Situational combat BGM

**Date:** 2026-11-27 (Asia/Seoul)  
**Repo:** Jongkyung-Ko/GuildMa `main`  
**Constraint:** Reused existing OGGs only — no delete/replace/re-upload/duplicate of music files.

## Files touched

| Path | Change |
|------|--------|
| `scripts/core/audio_manager.gd` | Intensity resolve + elite/mid/final loops; keep normal shuffle/fade/buses |
| `scripts/combat/combat_manager.gd` | Refresh BGM on hunt room reload (same-state safe) |
| `scripts/core/validate_audio.gd` | Situational tests (mid/final/elite/false-elite/goal) |

**Unchanged:** all `assets/audio/bgm/*` binaries, UI, balance, enemy stats.

## Detection (priority final > mid > elite > normal)

| Source | Rule |
|--------|------|
| Dungeon floor | `floors[n].boss == "final"` / `"mid"`; else highest `enemies.json` `tier` among floor enemy ids |
| Hunt room | `boss_flag` / `room_type=="boss"` / `boss_kind=="hunt_goal"` → **final**; `room_type=="elite"` → **elite** |
| Enemy tier | Only explicit catalog tiers (`elite`, `boss_mid`, `boss_final`) — never invent elite from `elite_pool` wolf/goblin alone |
| Fallback | `normal` |

## Track mapping (existing OGGs)

| Intensity | Mode | Track | Behavior |
|-----------|------|-------|----------|
| normal | `playlist` | Epic→Heroic→Metal→Hunting shuffle | End-of-track fade; no consecutive repeat |
| elite | `elite` | `combat_metal` | Loop for fight |
| mid | `mid` | `combat_heroic` | Loop for fight |
| final | `final` | `combat_boss` | Loop only; no normal shuffle |

Same intensity re-enter does not restart. Town/facility clears combat mode + restores town BGM. Pause/resume unchanged. Hunt room travel calls `on_enter_combat()` so elite/goal updates apply.

## Validation

Command: `godot4 --headless --path . -s res://scripts/core/validate_audio.gd`

| Check | Result |
|-------|--------|
| Normal shuffle / track change / no consecutive repeat | **PASS** |
| Elite → metal; normal hunt room not false-elite | **PASS** |
| Mid F5 → heroic | **PASS** |
| Final F10 → boss loop | **PASS** |
| Hunt goal → final/boss | **PASS** |
| Same-state mid re-enter | **PASS** |
| Victory path town restore + ambience stop | **PASS** |
| Pause / resume | **PASS** |
| BGM/SFX volume independence | **PASS** |
| Ear / audible listening | **FAIL (not tested)** |
| Local Web export | **PASS** (`--export-release Web`, savepack OK) |
| Pages CI | After push to `main` (see follow-up) |
| Ear / audible listening | **FAIL (not tested)** |

## More tracks needed?

**Not required for this priority mapping.** Existing four combat OGGs cover normal diversity + metal/heroic/boss situational roles. Optional later: a dedicated mid-boss MIDI distinct from Heroic Anthem, or a true `tier:"elite"` enemy catalog entry (detection already supports it).
