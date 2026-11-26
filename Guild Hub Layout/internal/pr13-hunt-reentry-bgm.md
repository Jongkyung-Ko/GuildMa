# 사냥터 재진입 위치 초기화 + 마을↔사냥터 BGM 재시작

**Date:** 2026-11-27 (Asia/Seoul)  
**Branch:** `cursor/hunt-reentry-bgm-bcf8`

## 변경 요약

| 파일 | 내용 |
|------|------|
| `scripts/core/game_state.gd` | `leave_hunt_session()`, `get_hunt_start_room_id()`, `_reset_map_to_start_room()` — 이탈 시 입구로 스폰 리셋, 클리어 진행 유지 |
| `scripts/combat/combat_manager.gd` | `return_to_town()` 시 hunt면 `leave_hunt_session()` |
| `scripts/core/scene_router.gd` | `go_town`/`go_title` 세션 정리; `go_hunt`/`go_combat`/`go_dungeon_combat` → `on_enter_combat(true)` |
| `scripts/core/audio_manager.gd` | 마을 진입 `play_bgm("town", true)`; combat `restart_bgm` 플래그; `_switch_to_track(..., restart)` |
| `scripts/core/validate_hunt_reentry.gd` | 회귀 자동화 |

## 정책

- 사냥터 **내부** 이동: BGM 위치 유지 (기존)  
- 사냥터→마을 / 마을→사냥터 / 재진입: BGM **처음부터**  
- F5/F10·OGG 셔플·MP3 맵: **변경 없음**  
- 던전 층/보스 플래그: **부작용 없음** (`validate_hunt_maze` PASS)

## 테스트 결과

| # | 시나리오 | 결과 |
|---|----------|------|
| 1 | 마을 BGM 재생 | **PASS** (자동화) |
| 2 | 사냥터 진입 | **PASS** |
| 3 | 사냥터 내 이동 | **PASS** |
| 4 | 마을 귀환 | **PASS** |
| 5 | 같은 사냥터 재진입 | **PASS** |
| 6 | 기본 시작 위치 스폰 | **PASS** |
| 7 | 사냥터 BGM 처음부터 | **PASS** (재생 위치) |
| 8 | 인접 지역 이동 | **PASS** |
| 9 | 동일 BGM 연속 | **PASS** |
| 10 | 마을 귀환 | **PASS** |
| 11 | 마을 BGM 처음부터 | **PASS** (재생 위치) |
| — | 실제 청음 | **NOT VERIFIED** |
| — | GUI/Pages 실플레이 | **NOT VERIFIED** |

```
validate_hunt_reentry.gd → PASS
validate_hunt_maze.gd → PASS (22/0)
validate_audio.gd → PASS
```
