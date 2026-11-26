# PR #10 — AudioManager null-safe vs BGM priority/shuffle

- **When:** 2026-11-27 (Asia/Seoul)  
- **Branch:** `cursor/post-merge-verification-60e0` (PR #10)  
- **Base BGM policy (shipped):** Combat BGM Pack v3 @ `73b2500` / docs `combat_bgm_v3_review.md`  
- **Null-safe delta:** only `_apply_stream` / `start_combat_ambience` load guards in `audio_manager.gd`  
- **PR #10 merge:** not performed (awaiting approval)

---

## Verdict

**Null-safe 수정은 구현된 BGM 우선순위·셔플·전환 로직을 깨지 않는다. PASS.**

우선순위 분기(`_detect_boss_combat` / `start_boss_combat_bgm` / `start_combat_playlist`)와 큐 셔플(`_rebuild_playlist_queue`)은 수정 범위 밖이며 호출 그래프도 동일하다. null 가드는 실패 시 `_switching = false`로 **풀어 주는** 쪽이라, 예전 `load()==null` 시 SCRIPT ERROR로 페이드 콜백이 중단되어 `_switching`이 true에 남을 수 있던 경우를 오히려 완화한다.

---

## Call graph (`_switch_to_track` ↔ `_apply_stream`)

| Path | Behavior after null-safe |
|------|---------------------------|
| `start_combat_playlist` / `start_boss_combat_bgm` / `play_bgm` / `_on_bgm_finished` → `_switch_to_track` | unchanged |
| `_switch_to_track` sets `_switching=true`, commits `_current_bgm`, optional fade-out | unchanged |
| fade callback / immediate → `_apply_stream(track, path, loop)` | load null-checked |
| success: `duplicate` → set loop → `play`; `_switching` cleared by `_fade_in` callback or non-fade branch | unchanged |
| fail: warning + `_switching=false` + return | **new** (prevents sticky lock) |

---

## Verification matrix

| Item | Result | Notes |
|------|--------|-------|
| `_switch_to_track` → `_apply_stream` relationship | **PASS** | Same call sites; guard only inside `_apply_stream` |
| BGM priority (implemented v3) | **PASS** | F5 mid + F10 final → `combat_boss`; F1 → playlist |
| Boss → normal music restore | **PASS** | F5 boss → F1 playlist; leaves `combat_boss` |
| Normal combat shuffle | **PASS** | 4-track rotation, no consecutive duplicate; `_switching` clears each step |
| `_switching` stuck after null-safe | **PASS** | Happy path clears; intentional missing-file probe clears |
| BGM + ambience simultaneous | **PASS** | Separate `BgmPlayer` + `AmbiencePlayer`; both `.playing` after start |
| Godot 4.3 headless errors from null-safe | **PASS** | `validate_audio.gd` PASS; focused probe PASS; no SCRIPT ERROR on real paths |
| Web Export packs audio + `audio_manager` | **PASS** | `savepack: end`; OGGs + `audio_manager.gdc` in pck |
| All BGM/SFX files exist + `load()` → AudioStream | **PASS** | See load matrix below |
| Ear / audible listening | **NOT VERIFIED** | Dummy/ALSA-less agent; not claimed PASS |
| Live Pages browser audio after PR #10 | **NOT VERIFIED** | PR not merged / not redeployed for this check |
| Stated table: mid→`combat_heroic`, elite→`combat_metal` | **FAIL (pre-existing policy gap)** | **Not caused by null-safe.** Shipped v3 + `validate_audio.gd` treat mid+final as `combat_boss`; no elite-tier BGM selector in `on_enter_combat`. Heroic/Metal are playlist members for normal fights only. |

---

## Load matrix (Godot 4.3 headless)

| Key | File | load_ok |
|-----|------|---------|
| town | `01_town_theme.ogg` | true (AudioStreamOggVorbis) |
| combat / combat_hunting | `02_hunting_grounds_rock.ogg` | true |
| combat_epic | `03_combat_epic_rock.ogg` | true |
| combat_metal | `04_combat_metal_drive.ogg` | true |
| combat_heroic | `05_combat_heroic_anthem.ogg` | true |
| combat_boss | `06_combat_boss_intensity.ogg` | true |
| ambience | `02_battle_ambience_loop.wav` | true |

---

## Commands run

```bash
godot --headless --path . -s res://scripts/core/validate_audio.gd
godot --headless --path . -s res://scripts/core/validate_audio_nullsafe_bgm.gd
godot --headless --path . --export-release "Web" /tmp/gm-web-audio-check/index.html
```

Logs: `Guild Hub Layout/internal/pr10-bgm-nullsafe-logs/`

---

## Code changes this verification

- Added probe script `scripts/core/validate_audio_nullsafe_bgm.gd` (test only).  
- **No BGM policy / OGG / playlist edits.**  
- **No further change to null-safe guards** (behavior correct).  
- **PR #10 not merged.**

---

## Recommendation

- Null-safe fix is safe to keep for merge when approved.  
- If product wants mid→`combat_heroic` and elite→`combat_metal`, that is a **separate feature change** vs shipped v3 — do not fold into the null-safe PR without explicit approval.
