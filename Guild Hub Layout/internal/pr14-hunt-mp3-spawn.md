# PR14 — 사냥터 Tobitate MP3 복원 + 재진입 스폰 초기화

**Date:** 2026-11-27 (Asia/Seoul)  
**Branch:** `cursor/pr14-hunt-mp3-spawn-bcf8`  
**Base:** `main` @ `89c04ca` (PR13 merged)

## 1. 사냥터 BGM rollback 원인

PR11에서 일반 전투 OGG 셔플을 복구하면서 `on_enter_combat()`가 **항상** `resolve_combat_intensity()` → OGG playlist / F5 / F10 경로로 진입하도록 바뀌었다.  
`BGM_PATHS["combat"]` / Tobitate MP3는 `play_bgm("combat")` 별칭으로만 남았고, 마을→사냥터 진입 경로(`SceneRouter.go_hunt` → `AudioManager.on_enter_combat`)는 그 키를 쓰지 않았다.

결과적으로 배포 빌드에서 사냥터에 들어가면 사용자가 지정한 `tobitate_aoi_sora.mp3`가 아니라 **던전용 OGG 셔플**(예: `02_hunting_grounds_rock.ogg`)이 재생되었다. 파일이 삭제된 것이 아니라 **선택 경로가 덮어쓰인 것**이다.

## 2. 복원한 MP3

| 항목 | 값 |
|------|-----|
| 파일명 | `tobitate_aoi_sora.mp3` |
| 경로 | `res://assets/audio/music/tobitate_aoi_sora.mp3` |
| BGM 키 | `hunt` (신규 전용) |
| 레거시 별칭 | `combat` → 동일 MP3 (`play_bgm("combat")` 호환) |

MP3→OGG 변환·파일 삭제·이름 변경 없음.

## 3. 사냥터 진입 시 실제 선택

로그 예:

```
AudioManager: hunt BGM key=hunt path=res://assets/audio/music/tobitate_aoi_sora.mp3 restart=true
LOG: after hunt enter key=hunt mode=hunt path=res://assets/audio/music/tobitate_aoi_sora.mp3
```

- 컨텍스트: `hunt_id != ""` && `dungeon_id == ""` → `_play_hunt_bgm()`
- 모드: `hunt` (playlist / elite / mid / final과 분리)
- 던전 F1: OGG playlist 유지 / F5 `combat_heroic` / F10 `combat_boss` 유지

## 4. 재진입 위치가 초기화되지 않던 원인 (PR13 보강)

PR13의 `leave_hunt_session()`만으로는 다음 엣지가 남을 수 있었다.

1. `return_to_town()`이 `active_hunt_id`에만 의존하면, 이미 비워진 뒤 leave가 스킵될 수 있음 → **로컬 `hunt_id` override**로 leave 강제.
2. leave 직후 저장 맵이 입구로 리셋되어도, 재진입 `start_hunt_run(..., spawn_at_start=false)`만 호출되면 과거 코드 경로에서 mid-room resume이 가능 → **`pending_spawn_at_start` 플래그** + **`go_hunt`가 `hunt_spawn_at_start=true` meta**를 항상 설정.
3. 전투 씬 `_ready`는 meta를 읽어 `start_hunt_run(hunt_id, force_new, spawn_at_start)` 호출.

내부 방 이동(`travel_hunt_room` → `on_enter_combat(false)`)은 `go_hunt`/`spawn_at_start`를 타지 않으므로 위치·BGM 유지.

## 5. 수정 파일 / 함수

| 파일 | 함수·변경 |
|------|-----------|
| `scripts/core/audio_manager.gd` | `BGM_PATHS.hunt`; `_is_hunt_context()`; `_play_hunt_bgm()`; `on_enter_combat` hunt 분기; `unlock_audio` hunt pending |
| `scripts/core/game_state.gd` | `start_hunt_run(..., spawn_at_start)`; `leave_hunt_session(hunt_id_override)`; `pending_spawn_at_start` |
| `scripts/combat/combat_manager.gd` | `_ready` spawn meta; `return_to_town` → `leave_hunt_session(hunt_id)` |
| `scripts/core/scene_router.gd` | `go_hunt` → `hunt_spawn_at_start=true` |
| `scripts/core/validate_audio.gd` | hunt=Tobitate 기대값 / elite·goal OGG 덮어쓰기 금지 |
| `scripts/core/validate_hunt_reentry.gd` | hunt 키·경로 로그 |
| `scripts/core/validate_hunt_mp3_spawn.gd` | **신규** MP3+스폰 좌표+세이브 회귀 |

## 6. 캐릭터 스폰 좌표 검증

`validate_hunt_mp3_spawn.gd` — 재진입 후 combat 씬 ally 좌표:

| slot | expected | actual | 결과 |
|------|----------|--------|------|
| 0 | (220, 280) | (220, 280) | PASS |
| 1 | (180, 360) | (180, 360) | PASS |
| 2 | (260, 420) | (260, 420) | PASS |
| 3 | (160, 220) | (160, 220) | PASS |
| 4 | (300, 340) | (300, 340) | PASS |

`current_room_id` = start + `room_type=start` 동시 확인.

## 7. 기존 세이브 데이터 검증

leave → `save_game` → `load_game` → 재진입:

- `current_room_id` = start **PASS**
- 클리어 플래그 유지 **PASS**
- mid room 복원 안 됨 **PASS**

## 8. 테스트 결과

| 테스트 | 결과 |
|--------|------|
| `validate_hunt_mp3_spawn.gd` | **PASS** |
| `validate_audio.gd` | **PASS** |
| `validate_hunt_reentry.gd` | **PASS** |
| `validate_hunt_maze.gd` | **PASS** (22/0) |
| Godot headless | **PASS** |
| 웹 export PCK에 Tobitate 포함 | **PASS** (`tobitate_aoi_sora.mp3` / `.mp3str` in `build/web/index.pck`) |
| 브라우저 실청음 | **NOT VERIFIED** |
| GitHub Pages 실배포 플레이 | **NOT VERIFIED** (feature branch; Pages는 main만) |

## 9. 웹 export MP3 포함

`godot --export-release Web` 후 `index.pck` strings:

- `res://assets/audio/music/tobitate_aoi_sora.mp3`
- `res://.godot/imported/tobitate_aoi_sora.mp3-….mp3str`

## 10. 정책 보존

| 구역 | 트랙 |
|------|------|
| 타이틀 | `sovereign_of_the_keep.mp3` |
| 마을 | `morning_dew_on_stone.mp3` |
| **사냥터** | **`tobitate_aoi_sora.mp3` (`hunt`)** |
| 던전 일반 | OGG 4곡 셔플 |
| F5 | `combat_heroic` |
| F10 | `combat_boss` |
