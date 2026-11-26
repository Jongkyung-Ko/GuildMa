# PR — 사냥터 BGM 연속 재생 + SFX/BGM 격리 수정

**Date:** 2026-11-27 (Asia/Seoul)  
**Branch:** `cursor/audio-continuity-bcf8`  
**Policy:** 타이틀/마을 MP3, OGG 4곡 셔플, F5 heroic, F10 boss, `combat`→Tobitate 키 **변경 없음**. 음원 파일 삭제·교체 없음.

---

## 원인

1. **사냥터 이동 시 BGM 재시작**  
   `combat_manager._reload_room_encounter()` → `AudioManager.on_enter_combat()` 호출.  
   동일 intensity여도 `start_combat_ambience()`가 **매번 `_ambience.stop()` + 새 스트림 play**를 수행해 전투 앰비언스가 처음부터 다시 들렸고, BGM early-return 조건도 `_bgm.playing`만 봐 mid-fade(`_switching`) 중엔 플레이리스트를 다시 켤 수 있었다.

2. **SFX 시 BGM 끊김/잡음**  
   - BGM과 SFX는 이미 별도 `AudioStreamPlayer` + BGM/SFX 버스였으나  
   - SFX가 **동일 `AudioStream` 리소스를 공유**한 채 `stop()` 라운드로빈  
   - 전 채널 `PLAYBACK_TYPE_STREAM`으로 짧은 히트마다 버퍼 재기동  
   - 앰비언스·히트 피크가 Master에서 겹치며 클리핑 가능  
   → BGM 플레이어를 직접 pause/stop 하지 않아도 믹스 글리치로 “끊김”처럼 들릴 수 있음.

---

## 수정

| 파일 | 내용 |
|------|------|
| `scripts/core/audio_manager.gd` | 동일 track/mode 시 stop/seek/restart 금지; `ensure_combat_ambience()`; SFX 캐시+duplicate; idle voice 우선; SFX=`SAMPLE`; SFX 버스 headroom −3 dB; 히트 볼륨 소폭 하향 |
| `scripts/combat/combat_manager.gd` | 주석만 (호출은 동일, AudioManager가 연속성 보장) |
| `scripts/core/validate_audio.gd` | 사냥터 hop 연속성 / ambience ensure / SFX≠BGM 버스·seek 테스트 추가 |

---

## 검증

```bash
godot --headless --path . -s res://scripts/core/validate_audio.gd
# === AUDIO VALIDATE: PASS ===
```

| 항목 | 결과 | 구분 |
|------|------|------|
| 사냥터 A→B→C 동일 BGM 위치 유지 | **PASS** | 자동화 (playback position) |
| 다른 intensity(elite) 전환 | **PASS** | 자동화 |
| SFX 연타 시 BGM track/pause/seek 불변 | **PASS** | 자동화 |
| BGM vs SFX 버스·플레이어 분리 | **PASS** | 자동화 |
| F5/F10·셔플 정책 | **PASS** | 기존 validate 유지 |
| 마을 복귀 | **PASS** | 기존 validate 유지 |
| Web Export 실기 | **NOT VERIFIED** (이번 PR에서 재배포·클릭 미실시; 코드 경로는 동일 AudioManager) | — |
| 실제 스피커 청음 | **NOT VERIFIED** | — |

---

## 유지된 BGM 정책

- title → `sovereign_of_the_keep.mp3`  
- town → `morning_dew_on_stone.mp3`  
- normal → epic/heroic/metal/hunting shuffle  
- F5 → `combat_heroic`  
- F10 → `combat_boss`  
- `combat` → `tobitate_aoi_sora.mp3`
