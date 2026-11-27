# PR16 — Guild Hall Landscape Layout & Character Composition

**Date:** 2026-11-27 (Asia/Seoul)  
**Branch:** `cursor/pr16-guild-hall-responsive-bcf8`

## Scope

GuildMaster is **landscape-only**. No dedicated portrait (390×844 / 430×932) layout.  
Verify only **844×390** and **1366×768**. Do not merge to `main` in this pass.

## 1. 변경 파일

| 파일 | 내용 |
|------|------|
| `scripts/ui/ui_style.gd` | 전역 `1280×720` + EXPAND 유지 (타운 핫스팟 보호). 세로 전용 스케일 없음 |
| `scripts/ui/guild_hall_screen.gd` | 가로 wide 분할만 사용; 세로 compact 비활성; short landscape dense packing |
| `scripts/core/capture_guild_hall_responsive.gd` | 844×390 / 1366×768만 캡처 |
| `scripts/core/capture_pr16_regression.gd` | 동일 두 해상도 회귀 |
| `docs/reviews/pr16_premerge_regression.md` | 가로 전용 검증 기준 |

## 2. 레이아웃 정책

1. **항상 wide:** 내비 | 길드홀+파티 | 상세 — 세로 스크롤 스택 제거/비활성
2. **Dense (844×390):** 상·하단 크롬 축소, 파티 카드 밀도 상향, 오버레이 가로 분할 유지
3. **PC (1366×768):** 기존 wide 여유 레이아웃 유지
4. **스테이지:** 길드마스터 중앙, 길드원 좌·우 균형

## 3. 필수 검증 해상도

| 해상도 | 기대 |
|--------|------|
| 844×390 가로 | dense wide, 홀/카드/상세가 한 화면에, CompactActions 숨김 |
| 1366×768 PC | 비-dense wide, 기존 PC 레이아웃 |

자동화: `capture_guild_hall_responsive.gd`, `capture_pr16_regression.gd`

## 4. 미검증 / 제외

- 세로형 화면 최적화 (작업 범위 제외)
- HTML5 / 실기기 브라우저 (선택)
