# PR #10 — 신규 MP3 BGM 3종 통합 검증 보고서

**Date:** 2026-11-27 01:27 KST (Asia/Seoul)  
**Branch:** `cursor/pr10-mp3-verify-bcf8`  
**Base:** `main` @ pre-fix `46af768` (playlist regression present) → post-fix this branch  
**Scope:** Verify three Gemini MP3 cues vs AudioManager / intensity / shuffle; restore policy if broken.  
**Constraint:** No delete/replace of existing MP3/OGG/WAV binaries; no music edit/convert; do not merge without explicit approval.

---

## Summary verdict

| 검증 항목 | 결과 |
|---|---|
| 오프닝 MP3 파일 및 연결 | **PASS** |
| 마을 MP3 파일 및 연결 | **PASS** |
| 전투 MP3 파일 및 연결 | **PASS** (키 `combat` → Tobitate; 일반 전투는 플레이리스트 정책) |
| 상황별 BGM 전환 | **PASS** (수정 후) |
| 기존 BGM 우선순위 유지 | **PASS** (수정 후) |
| 일반 전투 셔플 유지 | **PASS** (수정 후; 수정 전 **FAIL**) |
| AudioManager null-safe | **PASS** |
| Godot 4.3 호환성 | **PASS** |
| Web Export 호환성 | **PASS** (팩 포함·로드 가능; 브라우저 실청음은 NOT VERIFIED) |
| 실제 청음 | **NOT VERIFIED** |

---

## 1. 신규 MP3 파일 확인

프로젝트 전역 검색 결과 MP3는 아래 3개뿐이다 (`assets/audio/music/`).

| 역할 | 실제 파일명 · 경로 | 형식 · 크기 | `.import` 등록 | `AudioManager.BGM_PATHS` | 재생 연결 |
|------|-------------------|-------------|----------------|--------------------------|-----------|
| 오프닝 | `assets/audio/music/sovereign_of_the_keep.mp3` | MP3 / 4,287,545 bytes | Yes (`importer=mp3`, `AudioStreamMP3`) | `"title"` | `on_enter_title()` → `play_bgm("title")` via `SceneRouter.go_title()` / boot |
| 마을 | `assets/audio/music/morning_dew_on_stone.mp3` | MP3 / 4,295,351 bytes | Yes | `"town"` | `on_enter_town()` / `on_enter_facility()` |
| 전투 | `assets/audio/music/tobitate_aoi_sora.mp3` | MP3 / 4,044,575 bytes | Yes | `"combat"` | `play_bgm("combat")` 명시 호출. **일반 전투 진입은 셔플 플레이리스트(OGG)** |

기존 `assets/audio/bgm/*.ogg` / `*.mid` / `assets/audio/sfx/*.wav`는 유지됨 (삭제·교체 없음).

---

## 2. 게임 상황별 음악 재생 검증

| 게임 상황 | 기대 | 수정 전 (`46af768`) | 수정 후 (본 브랜치) |
|---|---|---|---|
| 최초 실행 / 타이틀 | 오프닝 MP3 | `title` → Sovereign | **일치 PASS** |
| 마을 진입 | 마을 MP3 | `town` → Morning Dew | **일치 PASS** |
| 일반 전투 (F1) | 전투 MP3 **또는** 기존 플레이리스트 | 단일 `combat` Tobitate **루프** (셔플 제거) | Epic→Heroic→Metal→Hunting **셔플 복구** — 기대표의 “플레이리스트 정책”에 **PASS** |
| 보스 전투 (F5 mid / F10 final) | 기존 보스 우선순위 | F5=`combat_heroic`, F10=`combat_boss` (키는 유지, mid/elite 파일은 Tobitate로 덮어씀) | F5 heroic OGG, F10 boss OGG — **PASS** |
| 전투 종료 → 마을 | 마을 BGM | town 복귀 OK | **PASS** |
| 재진입 | 상황별 BGM | title/town OK | **PASS** |

### 수정 전과의 차이 (PASS로 처리하지 않음)

`46af768`에서 일반 전투 정책이 단순화되어 있었다.

- `COMBAT_PLAYLIST` = `["combat"]` (기대: 4트랙)
- `combat_epic` / `metal` / `heroic` / `hunting` 경로가 모두 Tobitate MP3로 치환
- `start_combat_playlist()`가 셔플 없이 Tobitate 루프만 재생

`validate_audio.gd` 수정 전 결과: **FAIL (4)** — playlist order / start track / consecutive duplicate / diversity.

---

## 3. 기존 BGM 기능 회귀 검증

명령: `godot4 --headless --path . -s res://scripts/core/validate_audio.gd`

| 기능 | 수정 전 | 수정 후 |
|------|---------|---------|
| F5 mid → `combat_heroic` | PASS (키만; 파일은 Tobitate였음) | **PASS** (heroic OGG 복구) |
| F10 final → `combat_boss` | PASS | **PASS** |
| F1 일반 셔플 | **FAIL** | **PASS** (4트랙, 연속 중복 없음) |
| 보스 종료 후 일반/마을 복귀 | town restore PASS | **PASS** |
| 마을↔전투 전환 | PASS | **PASS** |
| BGM + ambience 동시 | 코드 경로 호출 PASS; headless에서 ambience `playing`은 종종 false | 스트림 할당·`start_combat_ambience` 호출 **PASS**; 실재생 플래그는 headless **NOT VERIFIED** |
| `_switching` 해제 | 시나리오에서 town 후 `false` | **PASS** |
| null-safe load / `.duplicate()` | `_apply_stream` duplicate + 미존재 키 warning | **PASS** (unknown track no crash) |

---

## 4. 기술적 호환성

| 항목 | 결과 | 근거 |
|------|------|------|
| Godot 4.3 MP3 로드/재생 | **PASS** | `load()` → `AudioStreamMP3`; title/town/combat headless `playing=true` |
| 경로 / import | **PASS** | `.import` + `.godot/imported/*.mp3str` |
| 씬 전환 중복 재생 | **PASS** | BGM player 1개 (`BgmPlayer`) |
| 동일 트랙 재진입 | **PASS** | mid same-state re-enter 테스트 |
| 이전 스트림 정리 | **PASS** | `_apply_stream` stop → duplicate → assign; fade tween |
| Web Export MP3 포함 | **PASS** | `--export-release Web` pack에 3 MP3 + `.mp3str` 포함 (65MB pck) |
| 브라우저 autoplay | 코드 **PASS** / 실청음 **NOT VERIFIED** | `unlock_audio()` on first click/key; pending BGM flush |
| OGG/WAV + MP3 혼용 | **PASS** | title/town MP3 ↔ combat playlist OGG ↔ sfx WAV |

---

## 5. 실제 실행 테스트

| 단계 | 방법 | 트랙 선택 | 스트림 재생 | 청음 |
|------|------|-----------|-------------|------|
| 타이틀 → 마을 → F1 → F5 → F10 → 마을 → 타이틀 → `play_bgm("combat")` | headless scenario script | 코드상 PASS | title/town/combat MP3 `playing=true`; F1 OGG playlist | **NOT VERIFIED** |
| GUI / 브라우저 클릭 플로우 | 이번 세션 미실행 | — | — | **NOT VERIFIED** |

헤드리스에서는 더미 오디오 드라이버로 스트림 할당·`playing` 플래그까지 확인 가능하나, 스피커 청음은 수행하지 않았다.

---

## 6. 발견된 문제와 최소 수정

### 문제

일반 전투 셔플이 Tobitate 단일 루프로 대체되어 기존 정책·`validate_audio`와 충돌.

### 재현

1. `main` @ `46af768` 체크아웃  
2. `godot4 --headless --path . -s res://scripts/core/validate_audio.gd`  
3. `FAIL: COMBAT_PLAYLIST order ["combat"] != [...]` 등 4건

### 수정 (전 → 후)

| 항목 | 전 | 후 |
|------|----|----|
| `COMBAT_PLAYLIST` | `["combat"]` | `["combat_epic","combat_heroic","combat_metal","combat_hunting"]` |
| `combat_epic` 등 | Tobitate MP3 | 기존 OGG 경로 복구 |
| `start_combat_playlist` | Tobitate loop | 셔플 + end-of-track fade (`loop=false`) |
| `title` / `town` | Sovereign / Morning Dew MP3 | **유지** |
| `combat` | Tobitate MP3 | **유지** (명시 `play_bgm("combat")`용; 일반 전투 진입은 플레이리스트) |
| MP3/OGG/WAV 파일 | — | **삭제·변환 없음** |

### 정책 메모 (의도적 차이)

- **마을 BGM**은 레거시 `01_town_theme.ogg` 대신 Morning Dew MP3 (사용자 요청). OGG 파일은 디스크에 잔존.  
- **Tobitate**는 `BGM_PATHS["combat"]`로 연결되나, `on_enter_combat()`의 normal intensity는 **기존 4곡 셔플**을 사용한다. 일반 전투마다 Tobitate만 틀리도록 하려면 별도 승인 후 정책 변경이 필요하다.

---

## 7. 검증 명령 로그 (요약)

```text
# Before fix
=== AUDIO VALIDATE: FAIL (4) ===

# After fix
=== AUDIO VALIDATE: PASS ===   # includes MP3 load + title entry checks

# Web export
savepack includes:
  res://assets/audio/music/sovereign_of_the_keep.mp3
  res://assets/audio/music/morning_dew_on_stone.mp3
  res://assets/audio/music/tobitate_aoi_sora.mp3
  + corresponding .mp3str imports
```

---

## 8. 검증한 것 / 검증하지 못한 것

**Verified (code + headless runtime):**

- 3 MP3 존재·크기·import·BGM_PATHS 연결  
- title / town / explicit combat MP3 재생 상태  
- F1 셔플, F5 mid, F10 final, town 복귀, `_switching` 해제, 단일 BGM 플레이어  
- Web export 팩에 MP3 포함  
- validate_audio PASS

**Not verified:**

- 실제 귀로 듣는 품질·루프 지점·볼륨 밸런스  
- 브라우저에서의 첫 클릭 후 자동재생 UX  
- GUI computer-use 클릭 플로우 (타이틀 UI → 던전)  
- Pages 배포 후 프로덕션 URL 청음

---

## 9. Git / PR

- Branch: `cursor/pr10-mp3-verify-bcf8`  
- Do **not** merge without explicit user approval.  
- Touched: `scripts/core/audio_manager.gd`, `scripts/core/validate_audio.gd`, `assets/audio/README.md`, this report.
