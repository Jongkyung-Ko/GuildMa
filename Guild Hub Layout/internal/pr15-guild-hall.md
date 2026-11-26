# PR15 — Guild Hall UI & Guild Management System

**Date:** 2026-11-27 (Asia/Seoul)  
**Branch:** `cursor/pr15-guild-hall-bcf8`  
**Base:** `main` (post-PR14)

## 1. 새 씬 / 스크립트

| 경로 | 역할 |
|------|------|
| `scenes/facilities/guild_hall.tscn` | 길드 홀 전용 씬 |
| `scripts/ui/guild_hall_screen.gd` | 홀 UI · 선택 · 편성 오버레이 · 상세 능력치 |
| `scripts/core/validate_guild_hall.gd` | 파티/저장/레거시/씬 스모크 자동화 |

## 2. 수정한 기존 파일

| 경로 | 변경 |
|------|------|
| `scripts/core/game_state.gd` | `guild_parties`, 편성 API, 전투 파생 preview, save/load |
| `scripts/core/scene_router.gd` | `go_facility("guild")` → 길드 홀 씬 |

기존 시설 공유 화면(`facility_screen.gd`)의 `_build_guild`는 유지(다른 경로 호환). 마을 핫스팟 → `go_facility("guild")`는 새 홀로 진입.

## 3. 구현된 메뉴 / 기능

- **길드원:** 홀 중앙 군주 + 좌우 스프라이트, 우측 상세, 목록 선택
- **파티 편성:** 하단 사냥/훈련/수비 카드 + 편성 오버레이
- **능력치:** 선택 시 상세 패널 / 상세 능력치 창
- **시설:** 기존 시설로 이동하는 진입 패널
- **파티 저장 / 닫기**

미구현(의도적): 길드 XP 바(데이터 없음), 훈련 스탯 자동 증가, 수비 이벤트 — 배정·상태 표시만.

## 4. 캐릭터 데이터 연결

- `GameState.members`의 **id 참조**만 사용
- 초상화: `portrait_{job}.png`
- 홀 스프라이트: `SpriteFactory.ally_frames(job)` (전투보다 작은 스케일)

## 5. 파티 편성 / 저장

- `guild_parties = { hunt, train, defend }` → member id 배열
- **배타 배치** (한 길드원 = 한 임무 파티)
- 사냥 파티 ↔ `member.in_party` 동기화 (전투 `_spawn_party` 유지, 최대 5)
- 세이브 키 추가; 구세이브는 `in_party` → hunt 마이그레이션

## 6. 능력치 출처

| UI 표시 | 출처 |
|---------|------|
| STR/VIT/AGI/INT/WIS | `member.stats` (실데이터) |
| ATK/DEF/HP/SPD | `compute_combat_preview` = 전투 `setup_from_member` 동일 공식 |
| DEX/LUK | **표시하지 않음** (데이터 없음) |

## 7. 테스트

| 항목 | 결과 |
|------|------|
| `validate_guild_hall.gd` | **PASS** |
| `validate_phase2_1.gd` | **PASS** |
| `validate_hunt_maze.gd` | **PASS** |
| 길드 홀 씬 인스턴스 | **PASS** |
| 길드 홀 메인 UI 캡처 | **PASS** |
| 멤버 선택 패널 갱신 | **PASS** |
| 사냥 파티 편성 오버레이 | **PASS** |
| 상세 능력치 창 | **PASS** |
| 브라우저 Pages 실플레이 | **NOT VERIFIED** (미병합) |
| 타이틀 실클릭(자동화 에이전트) | **NOT VERIFIED** (환경 이슈; 캡처 스크립트로 홀 검증) |

## 8. 향후

- 길드 XP / 레벨업 규칙
- 훈련 파티 ↔ 훈련장 연계 실행
- 수비 이벤트
- 인원 많을 때 홀 페이징 UX 강화
