# GuildMaster 그래픽 품질 진단표 (Phase Art Upgrade)

작성 기준: 인게임 에셋 vs `02_Assets` 콘셉트/스프라이트시트 vs GDD 아트 방향.

## 1. 콘셉트 대비 차이

| 영역 | 콘셉트 / 레퍼런스 | 개선 전 인게임 | 판정 |
|------|-------------------|----------------|------|
| 마을 | 상세 탑다운 픽셀 마을, 청기와, 분수, 성벽 | 단색 바닥 + 원형 나무 + 도형 건물 | 전면 교체 필요 |
| 건물 | 시설별 독립 외형 | ~600B 사각형/삼각형 PNG | 전면 교체 필요 |
| 캐릭터 | 직업별 실루엣·장비 애니메이션 시트 | 전투 ColorRect 단색 박스 | 전면 교체 필요 |
| 몬스터 | (콘셉트 약함) | 단색 ColorRect 늑대 1종 | 신규 제작 |
| 전투 배경 | 숲 개활지 | ColorRect 녹색 면 | 전면 교체 |
| UI | 금테 패널, 아이콘, HUD | StyleBoxFlat + 한글 폰트만 양호 | 패널/아이콘 개선 |
| 폰트 | Noto Sans KR | 정적 OTF 임베드 완료 | 유지 |

## 2. 에셋 분류

### 사용 가능 (레퍼런스·소스)
- `02_Assets/Spritesheets/*` — 직업별 고품질 사이드뷰 애니메이션
- `02_Assets/References/*` — 마을/UI/전투 콘셉트
- `assets/fonts/NotoSansKR-*.otf` — 한글 폰트 (유지)

### 개선/교체 대상 (프로토타입)
- `assets/sprites/buildings/*` — 도형 건물
- `assets/backgrounds/*` — 저용량 임시 배경
- `assets/sprites/characters/portrait_*` — 저품질 초상
- `assets/ui/*` — 단순 패널/버튼
- 전투 `ColorRect` 비주얼

### 신규 제작
- 몬스터 3종 (wolf / slime / goblin) 프레임
- 전투 VFX (slash / hit / magic / heal)
- 시설 인테리어 배경 세트
- 타이틀·마을·전투 프리미엄 배경

### 기능 연결 에셋
- 마을 건물 클릭 → `SceneRouter.go_facility`
- 초상화 → 시설/파티 UI
- 전투 스프라이트 → `CombatCharacter` AI/데미지 로직 (비주얼만 교체)
- Gate → `hunt_select` 배경 + 전투 진입

### 그래픽만으로 해결 불가
- 길드 운영 우측 패널 풀 UI (콘셉트에 있으나 Phase 데이터/로직 미구현)
- 타운 내 NPC 내비/하루 리포트 등 GDD 후속 시스템
- Steam 데스크톱 전용 고해상도 아틀라스 파이프라인 (웹 PCK 용량 제약)

## 3. 아트 스타일 가이드 (적용 기준)

- **밀도**: 전투 캐릭터 ~56px 키, 건물 ~130–160px, 배경 1280×720
- **필터**: `TEXTURE_FILTER_NEAREST` (픽셀 아트)
- **팔레트**: 마을=청기와·따뜻한 낮; 전투=쿨톤 숲; UI=네이비+골드
- **애니메이션**: idle/walk 0–3, attack 4–7 (캐릭터 시트); 몬스터 0–5
- **금지**: ColorRect를 최종 캐릭터/건물로 사용, 스타일 혼용, OS 폰트 의존
