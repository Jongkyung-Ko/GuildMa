# GuildMaster Phase 2-1 검증 보고서

- **대상 커밋(구현):** `7843c637ff7eb9c4573044b3a38dbf31178288fd` (`feat: Phase 2-1 자동전투 프로토타입 추가`)
- **검증 일시:** 2026-11-25 (Asia/Seoul) / 실행 머신 UTC 2026-11-24 22:41–22:45
- **엔진:** Godot 4.3.stable.official (`godot4` `/home/ubuntu/.local/bin/godot4`)
- **렌더:** Vulkan은 이 환경의 Xvfb에서 실패 → **OpenGL3 (`--rendering-driver opengl3`, Mesa llvmpipe)** 로 GUI/캡처 수행
- **오디오:** ALSA 장치 없음 → dummy driver (전투 로직에 영향 없음)
- **기획 기준:** `docs/plans/combat_system_development_plan.md` Phase 2-1

---

## 1. 검증 환경

| 항목 | 결과 |
|------|------|
| Godot 4.3 바이너리 | **있음** — 실행 가능 |
| headless 스크립트 테스트 | **수행함** |
| DISPLAY=:1 + OpenGL3 GUI | **수행함** |
| 수동 클릭 Town→Gate→Combat | **수행함** (desktop computer-use) |
| Windows 네이티브 빌드/실행 | **미검증** |
| Steam Deck / 실기 성능 | **미검증** |

---

## 2. 수행한 테스트와 로그

| 테스트 | 명령 | 로그 경로 | 결과 |
|--------|------|-----------|------|
| 허브 회귀 | `godot4 --headless --path . -s res://scripts/core/smoke_test.gd` | `docs/reviews/phase2_1_artifacts/smoke_test.log` | **PASS** |
| 전투 스모크 | `godot4 --headless --path . -s res://scripts/core/smoke_combat.gd` | `docs/reviews/phase2_1_artifacts/smoke_combat.log` | **PASS** (승리) |
| 통합 검증+캡처 | `DISPLAY=:1 godot4 --rendering-driver opengl3 --path . -s res://scripts/core/validate_phase2_1.gd` | `docs/reviews/phase2_1_artifacts/validate_phase2_1.log` / `validation_run.log` | **PASS** |
| 일시정지 | `godot4 --headless --path . -s res://scripts/core/validate_pause.gd` | `docs/reviews/phase2_1_artifacts/validate_pause.log` | **PASS** |
| GUI 수동 조작 | `DISPLAY=:1 godot4 --rendering-driver opengl3 --path .` | `docs/reviews/phase2_1_artifacts/godot_gui.log` | Town→Gate→출정→승리→마을 **성공** |

스크립트 캡처: `01_title.png` … `06_combat_end.png`  
GUI 수동 캡처: `gui_title.png`, `gui_town.png`, `gui_gate.png`, `gui_combat_*.png`, `gui_town_after.png`, `gui_combat.webm`

---

## 3. Phase 2-1 요구사항 체크리스트

| 요구 | 판정 | 근거 |
|------|------|------|
| Combat Scene 존재·로드 | **검증됨** | `combat.tscn` 로드, GUI 진입 |
| 파티 5인(군주 포함) 스폰 | **검증됨** | 로그 allies=5, UI에 아렌/가렌/리사/세이라/카이 |
| 몬스터 1종 | **검증됨** | `늑대` 2마리 (동일 종) |
| 자동 이동 | **검증됨** | validate: 아렌 이동 관측; GUI: 파티가 적에게 접근 |
| 자동 기본 공격 | **검증됨** | 전투 로그 `카이 → 늑대 10` 등 |
| 적 HP 감소 | **검증됨** | 120→110.5→0; GUI mid에서 50/60 |
| 몬스터 사망 | **검증됨** | `is_dead`, UI `(처치) 0/60` |
| 전투 종료(승리) 표시 | **검증됨** | `승리! (보상은 후속 Phase)` |
| WASD/가상 패드 없음 | **검증됨** | 입력 없이 전투 완주 (GUI 수동 확인) |
| 전술 명령 없음 (의도) | **확인** | Phase 2-1 범위 외 — UI에 전술 버튼 없음 |
| Esc 일시정지 | **검증됨** (스크립트) | `validate_pause.gd` PASS. GUI 중전투 Esc는 **미검증**(전투가 수 초 내 종료) |
| 마을 복귀 | **검증됨** | GUI `마을로` → Town |
| Town 화면 유지 | **검증됨** | 캡처 `02_town.png` / `gui_town.png` |
| Facility(Gate) 유지 | **검증됨** | `출정` 버튼 + 시설 내비 유지 |
| 아군이 피격당해 HP 감소 | **미검증** | 이번 런에서 아군 전원 풀피 유지(적 먼저 전멸). 피격 코드 경로는 존재하나 실측 없음 |
| 패배 경로(전원 전투불능) | **미검증** | 의도적 패배 시나리오 미실행 |
| Windows 빌드 | **미검증** | |
| 최종 픽셀 스프라이트 | **해당 없음(후속)** | Phase 2-1 임시 색 사각형 사용 |

---

## 4. 관측된 이슈와 조치

검증 중 발견한 UI 문제와, 이번 커밋에서 반영한 수정:

| 이슈 | 심각도 | 조치 |
|------|--------|------|
| 타이틀 메뉴가 고정 `position`이라 창 크기/최대화 시 우측·하단으로 밀림 | 중 | `title_screen.gd` — 중앙 앵커로 변경 |
| Gate 우측 패널 가로 스크롤·출정/이동 버튼 잘림 | 중 | `facility_screen.gd` — 문구 축약, 메인 패널 앵커화, 행 레이아웃 정리 |
| 전투 HUD 로그·HP 숫자 겹침/하단 잘림 | 중 | `combat_ui.gd` — 우측 패널·하단 로그 앵커/스크롤, HP 행 세로 배치 |

수정 후 `validate_phase2_1.gd` / smoke 재실행 **PASS**.  
**참고:** GUI 레이아웃 수정 후 수동 재클릭 검증은 시간상 **부분 미재검증**(스크립트 캡처·스모크로 회귀 확인). 최대화 창에서의 타이틀/게이트 픽셀 퍼펙트는 **추가 육안 확인 권장**.

---

## 5. Phase 2-1 범위 밖 (구현하지 않음 — 정상)

- 전술 명령, EXP/레벨업, 승·패 보상, 부상, HuntSelect 연결
- 다수 몬스터 종·보스, 던전, 공성전

---

## 6. 결론

Phase 2-1 **최소 자동전투 프로토타입은 Godot 4.3에서 실행·검증되었고**, 파티 5·늑대·자동 이동/공격·적 HP/사망·승리·마을 복귀·Town/Gate 보존이 로그와 화면 증거로 확인되었다.

남은 위험/미검증: 아군 피격 실측, 패배 시나리오, Windows 빌드, 수정 후 GUI 재육안 한 바퀴.

---

## 7. 산출물 목록

```
docs/reviews/phase2_1_validation_report.md
docs/reviews/phase2_1_artifacts/
  01_title.png … 06_combat_end.png
  gui_*.png / gui_combat.webm
  smoke_test.log / smoke_combat.log
  validate_phase2_1.log / validation_run.log / validate_pause.log
  godot_gui.log
scripts/core/validate_phase2_1.gd
scripts/core/validate_pause.gd
```
