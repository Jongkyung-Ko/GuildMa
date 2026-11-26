# PR #11 — 최종 출시 전 오디오 검증 (그래픽 / 브라우저)

**Date:** 2026-11-27 01:38 KST (Asia/Seoul)  
**Branch:** `cursor/pr10-mp3-verify-bcf8` (PR https://github.com/Jongkyung-Ko/GuildMa/pull/11)  
**Constraint:** 기존 음악 정책·파일 변경 없음. PR #11 **병합하지 않음**.  
**환경:** X11 + llvmpipe; **ALSA 장치 없음** → Godot `dummy` audio driver. `/dev/snd` 미존재.

---

## 결과 표

| # | 검증 항목 | 결과 | 근거 |
|---|-----------|------|------|
| 1 | 타이틀 `sovereign_of_the_keep.mp3` | **PASS** (스트림/재생 플래그) · 청음 **NOT VERIFIED** | SNAP title → path/MP3/`playing=true` + `01_title_sovereign.png` |
| 2 | 마을 `morning_dew_on_stone.mp3` | **PASS** (스트림/재생 플래그) · 청음 **NOT VERIFIED** | SNAP town + `02_town_morning_dew.png` |
| 3 | 일반 전투 OGG 플레이리스트 셔플 | **PASS** (스트림/재생 플래그) · 청음 **NOT VERIFIED** | F1 `playlist` + hunting→epic advance; `03_combat_f1_playlist.png` |
| 4 | F5 `combat_heroic` | **PASS** (스트림/재생 플래그) · 청음 **NOT VERIFIED** | mid + `05_combat_heroic_anthem.ogg`; `04_combat_f5_heroic.png` |
| 5 | F10 `combat_boss` | **PASS** (스트림/재생 플래그) · 청음 **NOT VERIFIED** | final + `06_combat_boss_intensity.ogg`; `05_combat_f10_boss.png` |
| 6 | 전투 종료 후 마을 복귀 | **PASS** (스트림/재생 플래그) · 청음 **NOT VERIFIED** | town restore + ambience stop; `06_town_after_combat.png` |
| 7 | 씬 전환 중복/끊김(플레이어 수·switching) | **PASS** | 전 구간 BGM player=1, `_switching=false` |
| — | 실제 청음 (귀로 확인) | **NOT VERIFIED** | 출력 장치 없음; dummy driver |
| — | 브라우저 첫 클릭 후 오디오 시작 | **PASS** (브라우저 탭 인디케이터) · 청음 **NOT VERIFIED** | 클릭 전 무음 탭 → 클릭 후 “This tab is playing audio” |

**종합:** 런타임 트랙 선택·재생 플래그·웹 unlock은 PASS. **청음 PASS는 선언하지 않음.**

---

## 실행 방법

```bash
DISPLAY=:1 godot --path . -s res://scripts/core/capture_audio_pr11.gd
# Web
godot --headless --path . --export-release Web /tmp/gm-web-pr11/index.html
python3 -m http.server 8743 --bind 127.0.0.1   # cwd=/tmp/gm-web-pr11
```

---

## AudioManager 로그 (요약)

원본: `Guild Hub Layout/internal/pr11-audio-ear-verification/audiomanager_runtime.log`  
아티팩트: `/opt/cursor/artifacts/pr11-audio-ear-verification/audiomanager_runtime.log`

| SNAP | key | path | stream | playing |
|------|-----|------|--------|---------|
| title | title | `…/sovereign_of_the_keep.mp3` | AudioStreamMP3 | true |
| town | town | `…/morning_dew_on_stone.mp3` | AudioStreamMP3 | true |
| f1_normal | combat_hunting | `…/02_hunting_grounds_rock.ogg` | AudioStreamOggVorbis | true |
| f1_playlist_advance | combat_epic | `…/03_combat_epic_rock.ogg` | AudioStreamOggVorbis | true |
| f5_mid | combat_heroic | `…/05_combat_heroic_anthem.ogg` | AudioStreamOggVorbis | true |
| f10_final | combat_boss | `…/06_combat_boss_intensity.ogg` | AudioStreamOggVorbis | true |
| town_after_combat | town | Morning Dew MP3 | AudioStreamMP3 | true |

`=== SUMMARY pass=29 fail=0 ===`

Godot 부트 로그: `All audio drivers failed, falling back to the dummy driver` (ALSA card 0 없음).

---

## 스크린샷

| 파일 | 내용 |
|------|------|
| `01_title_sovereign.png` | 타이틀 UI |
| `02_town_morning_dew.png` | 마을 |
| `03_combat_f1_playlist.png` | F1 전투 |
| `04_combat_f5_heroic.png` | F5 미드보스 |
| `05_combat_f10_boss.png` | F10 최종보스 |
| `06_town_after_combat.png` | 전투 후 마을 |
| `web_before_click.png` | 웹 타이틀, 클릭 전 (탭 스피커 아이콘 없음) |
| `web_after_first_click.png` | 첫 클릭 후 |
| `web_audio_playing_confirmed.png` | 탭 툴팁 “This tab is playing audio” |
| `web_after_newgame_click.png` | 새 게임 클릭 시도 후 (컴퓨터 사용 에이전트는 씬 전환 미확인) |

동일 사본: `/opt/cursor/artifacts/pr11-audio-ear-verification/`

---

## 브라우저 첫 클릭

1. `http://127.0.0.1:8743/` 타이틀 로드 **확인**  
2. 클릭 전: 탭에 재생 표시 없음 (`web_before_click.png`)  
3. 실 UI 클릭 후: 탭 스피커 아이콘 + “This tab is playing audio” (`web_audio_playing_confirmed.png`) → unlock **PASS**  
4. CDP 합성 `MouseEvent`는 `navigator.userActivation.hasBeenActive=false` 유지 (제스처로 인정 안 됨) — 실클릭 증거와 구분  
5. computerUse의 “새 게임” 클릭은 마을 전환을 시각적으로 확인하지 못함 (알려진 캔버스 입력 한계). **데스크톱 스크립트 경로에서는 마을 전환·BGM 복귀 PASS.**

---

## 검증함 / 검증 못 함

**함**

- X11 그래픽에서 타이틀→마을→F1(셔플 전진)→F5→F10→마을 복귀의 AudioManager key/path/stream/`playing`  
- 단일 BGM 플레이어, `_switching` 해제  
- Web export 서빙 + 실클릭 후 브라우저 오디오 인디케이터  

**못 함**

- 실제 스피커/헤드폰으로 곡을 들음  
- dummy 드라이버 너머의 하드웨어 PCM 출력  
- 웹에서 어떤 MP3/OGG 파일이 흐르는지(브라우저가 파일명을 노출하지 않음; 탭 “playing”만 확인)  
- computerUse 경로의 타이틀→마을 클릭 전환  

---

## 정책/파일

- BGM 정책·MP3/OGG/WAV 바이너리 **변경 없음** (검증용 캡처 스크립트·보고서·스크린샷만 추가).  
- PR #11 **미병합**.
