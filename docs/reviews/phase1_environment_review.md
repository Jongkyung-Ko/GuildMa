# GuildMaster Phase 1 환경 설정 검토 보고서

- **대상 저장소:** [Jongkyung-Ko/GuildMa](https://github.com/Jongkyung-Ko/GuildMa)
- **검토 기준 브랜치:** `main`
- **검토 시점의 Phase 1 커밋 (GitHub):** `8b8f468` (`feat: GuildMaster Phase 1 Godot town hub`)
- **검토 성격:** 읽기 전용 설정·구조 확인 (게임 코드/씬/에셋/설정 파일 미변경)
- **표기 규칙:**
  - **확인됨** — 저장소 파일에서 직접 확인한 사실
  - **미확인** — 기존 전투 프로토타입 원본이 없어 대조 불가한 항목
  - **추정** — 문서 문구 기반이나 원본 `project.godot`로는 검증되지 않은 내용

---

## 1. Renderer: Forward Plus vs GL Compatibility

### 확인됨 (현재 Phase 1)

| 항목 | 값 | 출처 |
|------|-----|------|
| Godot 설정 버전 | `config_version=5` | `project.godot` |
| 기능/렌더러 플래그 | `PackedStringArray("4.3", "Forward Plus")` | `project.godot` → `[application] config/features` |
| `rendering/renderer/rendering_method` | **명시적 키 없음** | `project.godot` 전체 |
| GL Compatibility 관련 키 | **없음** | `project.godot` 전체 |

### Forward Plus와 GL Compatibility 차이 (일반 지식, 엔진 문서 기준)

| 구분 | Forward Plus | GL Compatibility |
|------|--------------|------------------|
| 대상 | 비교적 최신 GPU / 데스크톱 중심 | 구형 GPU, 일부 모바일/저사양, OpenGL 호환 경로 |
| Godot 4에서의 위치 | 기본에 가까운 고급 렌더 경로 | 호환성 우선 경로 |
| 프로젝트 표기 | `config/features`에 `"Forward Plus"` | 보통 `"GL Compatibility"` 및/또는 `rendering_method=gl_compatibility` |

### 기존 프로젝트와의 비교

| 항목 | 현재 Phase 1 | 기존 전투 프로토타입 |
|------|--------------|----------------------|
| Renderer | **Forward Plus** (`project.godot`) | **미확인** (원본 `project.godot` 부재) |
| GL Compatibility | 미사용 | 문서/검토 요청에서 언급만 있음. 실측값 **미확인** |

**의견:** 현재 저장소만 보면 렌더러는 Forward Plus로 고정되어 있습니다. 기존 프로토타입이 실제로 GL Compatibility였는지는 원본 프로젝트 없이는 확정할 수 없습니다.

---

## 2. Autoload

### 확인됨 (현재 Phase 1)

`project.godot` → `[autoload]`:

| Autoload 이름 | 스크립트 경로 |
|---------------|---------------|
| `GameState` | `*res://scripts/core/game_state.gd` |
| `SceneRouter` | `*res://scripts/core/scene_router.gd` |
| `UIStyle` | `*res://scripts/ui/ui_style.gd` |

현재 저장소에 **없는** 이름 (파일 검색 결과):

- `EventBus`
- `CombatManager`
- `CharacterBase` (보통 Autoload가 아니라 클래스/씬 스크립트이나, 저장소 내 `.gd`에도 없음)

### 기존 프로젝트에서 언급된 항목

| 출처 유형 | 언급 내용 | 상태 |
|-----------|-----------|------|
| 사용자 검토 요청 | `CharacterBase`, `CombatManager`, `GameState`, `EventBus` 보존·연결 | 요청 사항. 원본 파일 **미확인** |
| `01_Documents/Cursor_Replit_개발프롬프트.txt` | “기존 프로토타입 보존”, Phase 2 전투 안정화 | 문서상 요구. Autoload 목록 구체값 **미확인** |
| `01_Documents/GuildMaster_GDD_v0.1.md` §16 | “이미 존재하는 프로토타입의 구조·기능·입력 보존” | 문서상 요구. Autoload 목록 **미확인** |

### 비교표

| Autoload / 핵심 시스템 | 현재 Phase 1 | 기존 전투 프로토타입 |
|------------------------|--------------|----------------------|
| `GameState` | 있음 (허브/길드 데이터용, `scripts/core/game_state.gd`) | 존재 여부·스키마 **미확인** (이름 충돌 위험은 추정) |
| `SceneRouter` | 있음 | **미확인** |
| `UIStyle` | 있음 | **미확인** |
| `EventBus` | **없음** | 언급됨, 실파일 **미확인** |
| `CombatManager` | **없음** | 언급됨, 실파일 **미확인** |
| `CharacterBase` | **없음** | 언급됨, 실파일 **미확인** |

---

## 3. Input Map

### 확인됨 (현재 Phase 1)

`project.godot` → `[input]`:

| 액션 | 설정 | 비고 |
|------|------|------|
| `ui_cancel` | `deadzone=0.5`, `physical_keycode=4194305` (Esc) | Godot 기본 UI 취소에 해당하는 키만 명시 |
| 이동 (`ui_left`/`move_*` 등) | **프로젝트에 커스텀 정의 없음** | 엔진 기본 UI 액션에 의존할 수 있으나, 전투용 맵핑은 없음 |
| 공격 / 스킬 / 회피 | **없음** | — |
| 터치 / 조이스틱 전용 액션 | **없음** | — |

코드상 입력 사용 (확인됨):

- `scripts/ui/settings_screen.gd`, `scripts/ui/facility_screen.gd`에서 `ui_cancel`로 뒤로 가기
- 마을/시설 UI는 **마우스 클릭·호버** (`Button`, `TextureRect` 등 Control) 중심

### 비교표

| 입력 영역 | 현재 Phase 1 | 기존 전투 프로토타입 |
|-----------|--------------|----------------------|
| 키보드 | Esc(`ui_cancel`) 명시. 그 외 커스텀 맵 **없음** | PC 키보드 유지 권고(문서). 구체 액션 **미확인** |
| 마우스 | UI 클릭/호버 (Control 기반) | **미확인** |
| 모바일 터치 | 전용 InputMap **없음**. 터치→마우스 에뮬에 의존할 가능성만 있음 | “기존 모바일 터치 지원 유지” 문서 요구. 실구현 **미확인** |

---

## 4. Display: 해상도·Stretch

### 확인됨 (현재 Phase 1)

`project.godot` → `[display]`:

| 키 | 값 |
|----|-----|
| `window/size/viewport_width` | `1280` |
| `window/size/viewport_height` | `720` |
| `window/size/window_width_override` | `1280` |
| `window/size/window_height_override` | `720` |
| `window/stretch/mode` | `"canvas_items"` |
| `window/stretch/aspect` | `"expand"` |
| `window/handheld/orientation` | `0` |

문서 권고 (`02_Assets/에셋_안내.txt`, GDD 아트 절): **1280×720** — 현재 설정과 **일치(확인됨)**.

### 비교표

| 항목 | 현재 Phase 1 | 기존 전투 프로토타입 |
|------|--------------|----------------------|
| 기준 해상도 | 1280×720 | 문서상 1280×720 권고. 실측 **미확인** |
| Stretch mode | `canvas_items` | **미확인** |
| Stretch aspect | `expand` | **미확인** |

---

## 5. Texture: Nearest 필터

### 확인됨 (현재 Phase 1)

`project.godot` → `[rendering]`:

| 키 | 값 | 의미 |
|----|-----|------|
| `textures/canvas_textures/default_texture_filter` | `0` | Godot 4에서 **Nearest**에 해당 |
| `environment/defaults/default_clear_color` | `Color(0.08, 0.09, 0.14, 1)` | 클리어 컬러 |

문서 (`02_Assets/에셋_안내.txt`): “1280x720, nearest 필터, 픽셀아트 스타일 유지” — **방향 일치(확인됨)**.

### 비교표

| 항목 | 현재 Phase 1 | 기존 전투 프로토타입 |
|------|--------------|----------------------|
| 기본 텍스처 필터 | Nearest (`0`) | 문서상 Nearest 권고. 실측 **미확인** |

---

## 6. Main Scene / 시작 구조

### 확인됨 (현재 Phase 1)

| 항목 | 값 / 경로 |
|------|-----------|
| `run/main_scene` | `res://scenes/main/main.tscn` |
| 부트 스크립트 | `scripts/core/main.gd` → `SceneRouter.go_title()` |
| 타이틀 | `scenes/title/title.tscn` |
| 마을 | `scenes/town/town.tscn` |
| 시설 | `scenes/facilities/facility.tscn` |
| 설정 | `scenes/title/settings.tscn` |

시작 흐름 (확인됨):

`main.tscn` → 타이틀 → (새 게임/이어하기) → 마을 → 시설 / 사냥터 안내(전투 씬 전환 없음)

### 비교표

| 항목 | 현재 Phase 1 | 기존 전투 프로토타입 |
|------|--------------|----------------------|
| Main Scene | `scenes/main/main.tscn` | **미확인** |
| 첫 플레이 화면 | 타이틀 → 마을 허브 | 전투/필드 메인 가능성만 언급. **미확인** |
| 전투 씬 | **없음** | **미확인** (저장소에 파일 없음) |

---

## 7. 기존 전투 프로토타입 파일 존재 여부

### 확인됨

다음 경로·식별자는 **현재 GuildMa `main`에 존재하지 않음**:

- `CharacterBase` / `CombatManager` / `EventBus` 스크립트
- 전투/필드 전용 `.tscn` (예: battle, combat, hunting ground 실행 씬)
- 전투용 InputMap·Autoload

현재 Godot 스크립트/씬 목록 (확인됨, 허브만):

```
project.godot
scenes/main/main.tscn
scenes/title/title.tscn
scenes/title/settings.tscn
scenes/town/town.tscn
scenes/facilities/facility.tscn
scripts/core/game_state.gd
scripts/core/main.gd
scripts/core/scene_router.gd
scripts/core/smoke_test.gd
scripts/ui/facility_screen.gd
scripts/ui/settings_screen.gd
scripts/ui/title_screen.gd
scripts/ui/town_screen.gd
scripts/ui/ui_style.gd
```

전투 **참고 이미지만** 존재 (실행 코드 아님):

- `02_Assets/References/a_detailed_pixel_art_rpg_game_combat_ui_screenshot.png`
- `assets/art_reference/References/` 동일 계열 파일

연관 저장소 추가 확인:

| 저장소 | 결과 |
|--------|------|
| `Jongkyung-Ko/GuildMaster` | 아트·README만. 전투 소스 **없음(확인됨)** |
| `Jongkyung-Ko/Game1` | Kotlin/Android. Godot 전투 프로토타입 **아님(확인됨)** |
| GitHub 코드 검색 (`CombatManager`/`CharacterBase`/`EventBus`, user:Jongkyung-Ko) | **0건(확인됨)** |

**결론 (확인됨):** 현재 GitHub에서 접근 가능한 GuildMaster 관련 저장소에는 실시간 전투 프로토타입 소스가 없다.

---

## 8. 백업 커밋 / 태그

### 확인됨

| 대상 | 태그 | 비고 |
|------|------|------|
| `Jongkyung-Ko/GuildMa` | **태그 없음** (`git ls-remote --tags` 결과 공란) | — |
| `Jongkyung-Ko/GuildMaster` | **태그 없음** | — |

GuildMa `main` 주요 커밋 (확인됨):

| 커밋 | 메시지 | 성격 |
|------|--------|------|
| `64f6c8c` | Initial commit | README 초기 |
| `f22814e` ~ `2855b24` | first~4th upload | 기획/아트 자료 업로드 |
| `8b8f468` | feat: GuildMaster Phase 1 Godot town hub | Phase 1 허브 코드 추가 |

`backup/*` 또는 전투 프로토타입 전용 백업 태그/브랜치: **없음(확인됨)**.

`2855b24`(4th upload)는 자료 백업에 가깝고, **전투 소스 백업이 아님(확인됨)**.

---

## 9. 통합 위험과 권장 조치

### 예상 위험 (사실 기반 + 추정 구분)

| 위험 | 구분 | 설명 |
|------|------|------|
| 전투 소스 부재 | **확인됨** | 연결할 CharacterBase/CombatManager/EventBus/전투 씬이 저장소에 없음 |
| GameState 이름 충돌 | **추정** | 허브용 `GameState`가 이미 Autoload. 기존 동명 Autoload가 있으면 병합 시 충돌 가능 |
| Renderer 불일치 | **추정** | 현재 Forward Plus. 기존이 GL Compatibility였다면 임포트/셰이더/모바일 이슈 가능 |
| InputMap 공백 | **확인됨(현재 쪽)** / **미확인(기존)** | 전투용 이동·공격·터치 맵이 현재 프로젝트에 없음 |
| 시작 흐름 불일치 | **확인됨(현재)** / **미확인(기존)** | 현재는 타이틀→마을. 전투 메인과 합치면 부트 경로 재설계 필요 |
| 백업 태그 부재 | **확인됨** | 병합 전 롤백 포인트가 태그로 고정되어 있지 않음 |
| smoke_test 범위 | **확인됨** | 허브 데이터만 검증. 전투·씬 전환 회귀를 보장하지 않음 |

### 권장 조치 (코드 변경 없이, 승인 후 순서 제안)

1. **사용자 제공:** 기존 전투 프로토타입의 실제 경로(GitHub URL / 브랜치 / ZIP / 로컬 폴더)
2. **읽기 전용 대조:** 원본 `project.godot`의 renderer, autoload, input, main_scene을 본 보고서 표에 채워 확정
3. **백업 태그 생성(승인 후):** 예) `backup/phase1-hub-only`, 원본 전투 확보 시 `backup/combat-prototype`
4. **통합 원칙:** 전투 로직 재작성·삭제 금지. 허브 `사냥터 출구` → 기존 전투 씬 진입/복귀만 최소 연결
5. **GameState:** 병합 전 필드·시그널 스키마 대조. 필요 시 어댑터 레이어(승인 후)
6. **Renderer/Input:** 원본 확인 후 호환 모드를 명시적으로 선택(승인 후)

---

## 종합 의견

현재 `Jongkyung-Ko/GuildMa` Phase 1은 **길드 허브·시설 UI 중심의 신규 Godot 4.3 프로젝트**이며, 설정상 **Forward Plus / Autoload 3종 / 1280×720 / Nearest / 타이틀→마을 시작**이 확인됩니다.

문서와 검토 요청은 **기존 실시간 전투 프로토타입 보존·연결**을 전제로 하지만, **그 소스·설정·백업 태그는 현재 GitHub 저장소에서 확인되지 않습니다.**  
따라서 “설정 차이를 수치로 확정한 통합”은 원본 프로토타입을 확보하기 전에는 불가능하며, 지금 단계에서 병합을 진행하면 전투 시스템을 사실상 새로 만들게 되어 보존 원칙과 충돌합니다.

---

## 다음 단계 권고

1. 전투 프로토타입 **위치 확정** (최우선)
2. 원본 `project.godot` 기준으로 본 문서 §1–6 표의 **미확인** 칸을 실측값으로 갱신
3. 승인 후 **백업 태그** 생성 → 최소 연결 설계안 보고 → 구현

이 보고서는 검토 기록이며, 작성 과정에서 게임 코드·프로젝트 설정·씬·에셋을 수정하지 않았습니다.
