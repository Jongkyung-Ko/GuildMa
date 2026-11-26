# PR16 — Guild Hall Responsive Layout & Character Composition

**Date:** 2026-11-27 (Asia/Seoul)  
**Branch:** `cursor/pr16-guild-hall-responsive-bcf8`

## 1. 변경 파일

| 파일 | 내용 |
|------|------|
| `scripts/ui/ui_style.gd` | 모바일 KEEP 레터박스 제거 → EXPAND; 세로 시 `720×1280` 디자인 사이즈 |
| `scripts/ui/guild_hall_screen.gd` | 반응형 레이아웃(세로 스크롤 / 가로 분할), 스테이지 배치, 오버레이 z |
| `scripts/core/capture_guild_hall_responsive.gd` | 4해상도 캡처 스크립트 |
| `Guild Hub Layout/internal/pr16-guild-hall-responsive.md` | 본 리포트 |

## 2. 화면 잘림 근본 원인

1. **거대한 상하 검정 여백:** `UIStyle`이 모바일에서 `content_scale_aspect = KEEP` + 고정 `1280×720`을 강제해, 세로 폰에서 16:9 캔버스를 가운데만 축소 표시함.
2. **하단 파티/버튼 접근 실패:** 길드 홀 UI가 1280×720 가로 고정 오프셋(절대 좌표)이라 세로·좁은 뷰포트에서 파티 카드·푸터가 잘리거나 닿기 어려움.
3. **캐릭터 겹침/오버레이 관통:** 홀 배우라이트 `z_index`가 높아 편성 모달 위로 그려짐. 배치도 홀 레이어 실측 전에 fallback 크기로 몰림.

## 3. 캐릭터 배치 수정

- 군주: 중앙 난로/단상 쪽, 더 큰 스케일, 높은 로컬 z
- 길드원: 좌/우 균등 분배, 군주 클리어런스 확보, 깊이(y)로 원근
- 이름표는 스프라이트 **위**에 배치
- `clip_contents` + 오버레이 시 홀 레이어 숨김 + 오버레이 `z_index=80`

## 4. 해상도별 테스트 (Godot 실실행 캡처)

| 해상도 | 결과 | 산출물 |
|--------|------|--------|
| 390×844 세로 | **PASS** (스크롤 스택, 인라인 저장/닫기) | `mobile_portrait_390x844_*.png` |
| 430×932 세로 | **PASS** | `mobile_portrait_430x932_*.png` |
| 844×390 가로 | **PASS** (와이드 분할 유지) | `mobile_landscape_844x390_*.png` |
| 1366×768 PC | **PASS** (데스크톱 레이아웃 유지) | `pc_1366x768_*.png` |

자동화: `validate_guild_hall` **PASS**, `validate_phase2_1` **PASS**, `validate_hunt_maze` **PASS**

## 5. 브라우저 확인

| 항목 | 결과 |
|------|------|
| Godot 데스크톱 멀티 해상도 캡처 | **PASS** |
| HTML5 / 실기기 브라우저 | **NOT VERIFIED** (미병합 · Pages 미배포) |

## 6. 미검증

- 실기기 Safari/Chrome 터치 스크롤 체감
- 노치·홈 인디케이터 안전 영역
- 다른 시설 화면의 세로 720폭 디자인 미세 회귀 (EXPAND+720폭은 의도된 전역 변경)
