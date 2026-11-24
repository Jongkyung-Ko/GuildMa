# GuildMaster 기존 전투 프로토타입 원본 확보 조사 보고서

- **작성 목적:** 기존 실시간 전투 프로토타입의 원본 위치·확보 가능 여부 확인
- **관련 선행 문서:** `docs/reviews/phase1_environment_review.md`
- **조사 성격:** 읽기 전용 검색. 전투 시스템 신규 작성·GuildMa 게임 파일 수정·원본 이동/덮어쓰기 **없음**
- **표기:** **확인됨** = 실측 / **미확인** = 접근 권한·도구 한계로 확인 불가 / **추정 금지** = 원본 위치를 임의로 만들지 않음

---

## 종합 결론

**현재 이 에이전트가 접근 가능한 범위에서는 기존 전투 프로토타입 원본을 찾지 못했습니다.**

요청하신 핵심 파일(`battle.tscn`, `battle_scene.gd`, `combat_manager.gd`, `character_base.gd`, `role_stats.gd`, `EventBus`, `VirtualInput`, 기존 `project.godot`)은:

- GitHub `Jongkyung-Ko` 계정 하위 조사 대상 저장소
- 본 Cloud Agent VM 로컬 디스크
- 본 세션 Cursor Cloud Agent / 환경 목록

어디에서도 **실파일로 확인되지 않았습니다.**

따라서 **Godot 버전·기존 전투 Autoload/Input 설정·전투 시스템 구성**은 원본 부재로 **전부 미확인**입니다.  
GuildMa에 있는 `project.godot`는 Phase 1 허브용이며, 기존 전투 원본으로 취급하지 않습니다.

---

## 1. 조사한 범위

### 1-1. Cursor 작업공간·Cloud Agent

| 대상 | 결과 | 상태 |
|------|------|------|
| 현재 Cloud Agent | `bc-7aabb77e-9076-4243-b533-a681ca61e4aa` (본 세션만) | **확인됨** |
| `list-cloud-agents` (동일 환경/저장소 스코프) | 접근 가능 에이전트 **1건** (본 세션). 전투 프로토타입 전용 과거 런 **미발견** | **확인됨** |
| Named environments | `list-environments` → named environment **0건** | **확인됨** |
| 연결된 repo 후보 (환경/최근 에이전트/SCM) | 14개 GitHub 저장소 목록 확보 (아래 §2) | **확인됨** |
| 사용자 PC의 Cursor Desktop 로컬 워크스페이스 | 이 VM에서 접근 불가 | **미확인** |

### 1-2. Replit

| 대상 | 결과 | 상태 |
|------|------|------|
| 문서 언급 | `01_Documents/Cursor_Replit_개발프롬프트.txt`, `프로젝트_안내.md`에 “Cursor 또는 Replit에서 진행” 문구 **있음** | **확인됨** |
| Replit 프로젝트 URL / 계정 연동 | 문서·저장소·환경 변수·MCP에 Replit 프로젝트 주소 **없음** | **확인됨(부재)** |
| Replit 내 파일 실검 | Replit API/로그인 세션 없음. 웹 프로브만 가능(`replit.com` 응답). 프로젝트 파일 목록 **조회 불가** | **미확인** |

### 1-3. GitHub 저장소·브랜치

조사한 `Jongkyung-Ko` 저장소 (트리 재귀 검색, **확인됨**):

| 저장소 | URL | 브랜치 | `project.godot` / 전투 키파일 |
|--------|-----|--------|------------------------------|
| GuildMa | https://github.com/Jongkyung-Ko/GuildMa | `main`만 | Phase 1 `project.godot`만. 전투 키파일 **없음** |
| GuildMaster | https://github.com/Jongkyung-Ko/GuildMaster | `main`만 | 아트만. `project.godot`·전투 키파일 **없음** |
| Game1 | https://github.com/Jongkyung-Ko/Game1 | `main` 외 cursor/* 다수 | Kotlin/Android. `.gd`/전투 Godot 파일 **없음** (`main`, `cursor/walking-hero-sprites-6bcd` 표본 확인) |
| App_Navi, First, FirstWebApp, GapGapGap, Homework, Vegi-hunter, Digital-World, First-2026-07-02_00-33-12, sw-vibe-coding-course2 | 각 GitHub URL | default | 전투 키파일·`project.godot` **없음** |
| ROI, sw-vibe-coding-course | — | — | 커밋 없음 / 조회 불가에 가까움 |

추가:

| 항목 | 결과 |
|------|------|
| GitHub Code Search (`battle.tscn`, `combat_manager`, `character_base`, `role_stats`, `VirtualInput`, `EventBus`, `filename:project.godot` + `user:Jongkyung-Ko`) | 각 **total 0** |
| Gists | **0건** |
| GuildMa / GuildMaster Releases | **0건** |
| GuildMa / GuildMaster Tags | **없음** |

> 참고: Code Search가 `GuildMa`의 `project.godot`도 0으로 나오는 것은 인덱싱 지연 가능성이 있으나, **Git Trees API로 GuildMa 파일을 직접 열거**하여 Phase 1 허브 파일만 있음을 별도 확인했습니다.

### 1-4. Origin

| 대상 | 결과 |
|------|------|
| `cursor-origin` namespace | `jongkyung-ko` 사용자 네임스페이스 존재 |
| Origin 저장소 목록에서 전투 Godot 원본 | 본 조사에서 전투 프로토타입으로 확인된 Origin 저장소 **없음** |
| 현재 에이전트 원격 | `origin.cursor.com/.../tmp-f1f78cb6fb37dd7c` (Phase 1 작업본) | **확인됨** |

### 1-5. 로컬 파일·백업 (본 Cloud Agent VM)

검색 루트: `/home`, `/tmp`, `/opt`, `/agent`, `/cursor`, `/workspace`

| 파일명 | 발견 위치 |
|--------|-----------|
| `battle.tscn` | **없음** |
| `battle_scene.gd` | **없음** |
| `combat_manager.gd` | **없음** |
| `character_base.gd` | **없음** |
| `role_stats.gd` | **없음** |
| `EventBus` / `event_bus*` | **없음** |
| `VirtualInput` / `virtual_input*` | **없음** |
| `project.godot` | Phase 1 사본만: `/agent/repos/tmp-f1f78cb6fb37dd7c/project.godot`, `/tmp/guildma-docs/project.godot`, `/tmp/guildma-push/project.godot` |

Godot 에디터 설정 (`~/.config/godot/editor_settings-4.3.tres`): 본 VM에서 Phase 1 실행 과정에서 생성된 설정. **다른 프로젝트 경로 기록 없음(확인됨).**

사용자 **로컬 PC**의 백업 ZIP·다른 드라이브·이전 Cursor 프로젝트 폴더: 이 환경에서 **접근 불가 → 미확인**.

---

## 2. 발견한 프로젝트 및 저장소 주소

전투 원본은 아니지만, GuildMaster 관련으로 확인된 저장소:

| 이름 | 주소 | 내용 (확인됨) |
|------|------|----------------|
| GuildMa | https://github.com/Jongkyung-Ko/GuildMa | 기획/아트 + Phase 1 허브 Godot |
| GuildMaster | https://github.com/Jongkyung-Ko/GuildMaster | 아트 참고 패키지 |
| Game1 | https://github.com/Jongkyung-Ko/Game1 | 별개 Kotlin 모바일 RPG 초안 |

**전투 프로토타입 전용 저장소 주소: 발견되지 않음.**

---

## 3. 요청 파일 존재 위치 표

| 대상 | GuildMa | GuildMaster | Game1 | 본 VM 로컬 | Replit | 사용자 PC |
|------|---------|-------------|-------|------------|--------|-----------|
| `battle.tscn` | 없음 | 없음 | 없음 | 없음 | 미확인 | 미확인 |
| `battle_scene.gd` | 없음 | 없음 | 없음 | 없음 | 미확인 | 미확인 |
| `combat_manager.gd` | 없음 | 없음 | 없음 | 없음 | 미확인 | 미확인 |
| `character_base.gd` | 없음 | 없음 | 없음 | 없음 | 미확인 | 미확인 |
| `role_stats.gd` | 없음 | 없음 | 없음 | 없음 | 미확인 | 미확인 |
| `EventBus` | 없음 | 없음 | 없음 | 없음 | 미확인 | 미확인 |
| `VirtualInput` | 없음 | 없음 | 없음 | 없음 | 미확인 | 미확인 |
| 기존 전투 `project.godot` | 없음 (허브용만 존재) | 없음 | 없음 | 허브용만 | 미확인 | 미확인 |

---

## 4. 기존 전투 시스템의 구성

**미확인** — 원본 소스가 없어 씬 그래프·스크립트 책임·파티/몬스터 구조를 기술할 수 없습니다.

문서상으로만 존재하는 언급 (코드 구성 확정 아님):

- `01_Documents/GuildMaster_GDD_v0.1.md` — 실시간 사냥/전술 명령, 기존 프로토타입 보존
- `01_Documents/Cursor_Replit_개발프롬프트.txt` — Phase 2 전투 루프 안정화, 기존 구조 보존
- 사용자 검토 요청에 등장한 이름: `CharacterBase`, `CombatManager`, `GameState`, `EventBus`, `VirtualInput`

위 이름은 **요청·문서 수준의 식별자**이며, 저장소에서 구현 파일로 검증되지 않았습니다.

---

## 5. 원본 프로젝트의 Godot 버전과 설정

| 항목 | 결과 |
|------|------|
| Godot 버전 | **미확인** |
| Renderer (Forward Plus / GL Compatibility) | **미확인** |
| Autoload 목록 | **미확인** |
| InputMap (키보드/마우스/터치) | **미확인** |
| Main Scene | **미확인** |

비교용으로, **현재 GuildMa Phase 1**만 확인됨:

- Godot 4.3 / `Forward Plus`
- Autoload: `GameState`, `SceneRouter`, `UIStyle`
- Display: 1280×720, stretch `canvas_items` / `expand`
- Texture filter: Nearest (`0`)
- Main: `res://scenes/main/main.tscn`

이는 **원본 전투 설정이 아닙니다.**

---

## 6. GitHub 업로드 가능 상태

| 대상 | 업로드 가능 여부 |
|------|------------------|
| 이미 GitHub에 있는 전투 원본 | **해당 원본을 찾지 못함** |
| GuildMa / GuildMaster에 전투 소스 푸시 여부 | 전투 원본 **미포함(확인됨)** |
| 사용자가 로컬/Replit에서 ZIP·폴더를 제공하는 경우 | GitHub 업로드·GuildMa 통합 **가능(절차상)**. 단 원본 확보가 선행 조건 |

---

## 7. GuildMa와 통합 시 필요한 작업 (원본 확보 후)

원본이 아직 없으므로 **실행하지 않음**. 확보 후 권장 순서만 기술:

1. 원본을 별도 브랜치/태그에 백업 (`backup/combat-prototype` 등) — 덮어쓰기 금지
2. 원본 `project.godot`와 GuildMa Phase 1 설정을 항목별 대조 (Renderer, Autoload, Input, Main Scene)
3. `GameState` 이름/스키마 충돌 분석 (`EventBus` 유무 포함)
4. 허브 `사냥터 출구` → 기존 `battle.tscn`(또는 실제 메인 전투 씬) 진입/복귀만 최소 연결
5. 전투 로직·`CombatManager`·`CharacterBase` **재작성 금지**

---

## 8. 원본을 찾지 못한 이유와 미확인 사항

### 조사에서 확인된 사실

- 접근 가능한 GitHub 저장소·브랜치·Gist·Release·Tag에 요청 파일이 없다.
- 본 Cloud Agent VM 디스크에 요청 파일이 없다.
- Cursor Cloud에서 접근 가능한 과거 전투 전용 에이전트/환경이 목록에 없다.
- 문서는 Replit/기존 프로토타입을 언급하지만, 연결 가능한 Replit URL·인증이 없다.

### 미확인 (추가 협조 필요)

1. **사용자 로컬 PC**의 Godot 프로젝트 폴더 / ZIP / 외장 백업
2. **Replit** 계정 내 GuildMaster 관련 Repl (URL·초대 필요)
3. **다른 GitHub 계정** 또는 조직에 있는 private 저장소
4. **다른 Cursor Cloud 팀/환경**에만 존재하는 과거 런 산출물 (본 스코프 밖)
5. 채팅 첨부·이메일·드라이브에만 있는 압축본

### 사용자께 요청드리는 정보

원본 확보를 위해 아래 중 하나면 충분합니다.

- GitHub/Origin 저장소 URL + 브랜치
- Replit 프로젝트 URL
- 로컬 폴더를 ZIP으로 업로드
- Cursor에서 해당 프로젝트가 열린 상태로 새 에이전트 실행

---

## 9. 확보 가능 여부 요약

| 질문 | 답 |
|------|----|
| 지금 당장 원본을 GuildMa에 통합할 수 있나? | **아니오** (원본 미확보) |
| GitHub에서 이미 받을 수 있나? | **아니오** (조사 범위 내 부재) |
| 사용자가 파일을 제공하면 확보·백업·대조 가능한가? | **예** (제공 후 읽기 전용 분석부터) |

---

*본 문서는 조사 결과만 기록합니다. 전투 시스템 신규 구현 및 GuildMa 게임 코드/설정/씬/에셋 변경은 수행하지 않았습니다.*
