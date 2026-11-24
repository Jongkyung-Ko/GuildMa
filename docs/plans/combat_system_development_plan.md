# GuildMaster 신규 전투 시스템 개발 계획서

- **문서 유형:** 설계·개발 계획 (코드/씬/에셋/설정 **미변경**)
- **대상 저장소:** [Jongkyung-Ko/GuildMa](https://github.com/Jongkyung-Ko/GuildMa) `main`
- **선행 확인:** `01_Documents/GuildMaster_GDD_v0.1.md`, `docs/reviews/phase1_environment_review.md`, `docs/reviews/combat_prototype_source_search.md`, 현재 `project.godot`·허브 코드·에셋
- **전제:** 기존 전투 프로토타입 원본은 확보되지 않음 → **신규 설계**. 길드 마을·시설은 **보존**하고 전투를 **독립 모듈**로 붙인 뒤 연결한다.
- **표기:** **GDD 확정** / **제안** / **추가 결정 필요** / **현재 프로젝트 확인됨**

---

## 1. 현재 프로젝트 구조 분석

### 1-1. 디렉터리·실행 구조 (확인됨)

```
GuildMa/
├── project.godot
├── data/                 # balance, items, adventurers, quests (JSON)
├── scenes/
│   ├── main/main.tscn
│   ├── title/title.tscn, settings.tscn
│   ├── town/town.tscn
│   └── facilities/facility.tscn
├── scripts/
│   ├── core/game_state.gd, scene_router.gd, main.gd, smoke_test.gd
│   └── ui/*.gd
└── assets/               # backgrounds, sprites, ui, art_reference
```

| 항목 | 현재 값 (확인됨) |
|------|------------------|
| Godot | 4.3, `Forward Plus` |
| Autoload | `GameState`, `SceneRouter`, `UIStyle` |
| Main Scene | `res://scenes/main/main.tscn` → 타이틀 |
| 해상도 | 1280×720, stretch `canvas_items` / `expand`, Nearest |
| InputMap | `ui_cancel`(Esc)만 명시. 전투용 이동/공격 맵 **없음** |
| 전투 씬·CombatManager 등 | **없음** |

### 1-2. GameState (확인됨) — 전투 연결에 쓸 수 있는 부분

| 필드/기능 | 내용 | 전투 연동 시사점 |
|-----------|------|------------------|
| `members[]` | `id, name, job, level, exp, stats{str,vit,agi,int,wis}, skills, traits, upkeep, injured, equipment, in_party` | 파티·스탯·부상 상태 소스 |
| `gold` / `reputation` | 경제·명성 | 보상 지급 |
| `inventory` | `{id, qty}` | 드롭 아이템 |
| `active_quests` | 수락 의뢰 | 전투 후 진척 **제안** |
| `save_game` / `load_game` | `user://guildmaster_save.json` | 전투 중 세이브 정책 **추가 결정 필요** |
| `train_member` | EXP +100당 레벨업 | 전투 EXP와 동일 규칙 재사용 **제안** |
| `heal_member` / `injured` | 의무실 회복 | 전투불능 → `injured=true` 연동 **제안** |

시작 파티 (확인됨): 군주 `lord` + `tank`/`dps`/`healer`/`mage` 각 1, 전원 `in_party: true`.

### 1-3. SceneRouter (확인됨)

현재: `go_title`, `go_town`, `go_settings`, `go_facility`만 존재.  
전투용 `go_combat` / `go_hunt_select` **없음** → **추가 예정(구현 시)**, 기존 메서드는 유지.

### 1-4. 마을·사냥터 연결 지점 (확인됨)

- 마을 건물 `gate` (`scripts/ui/town_screen.gd`) → `SceneRouter.go_facility("gate")`
- `facility_screen.gd` `_build_gate()`: 지역 목록(바람의 숲, 푸른 초원, 고대 폐허 입구) + “이동” 시 **메시지뿐**, 씬 전환 없음
- 주석: “전투는 추후 구현”

### 1-5. 에셋 현황 (확인됨)

| 종류 | 상태 | 전투 활용 |
|------|------|-----------|
| 직업 초상 `portrait_*.png` | 있음 | UI 초상 재사용 **제안** |
| 스프라이트 시트 (art_reference) | 원본 보존, 런타임 미슬라이스 | 검증 후 `assets/sprites/characters/` 복사본만 사용 **제안** |
| 전투 참고 UI PNG | art_reference에 존재 | 레이아웃 참고만 (통째로 배경 금지 — 에셋 안내와 동일) |
| 몬스터 스프라이트 | **없음** | 신규 제작/외부 확보 **추가 결정 필요** |
| 전투 필드 타일/배경 | `hunt_select.png`만 (메뉴용) | 필드 배경 **신규 필요** |
| 이펙트/SFX | **없음** | Phase 후반 **제안** |

### 1-6. 모바일 터치

GDD: “기존 프로토타입의 모바일 터치 지원이 있다면 유지”.  
현재 프로젝트: 전용 터치 InputMap **없음** (확인됨). → Phase 2는 **PC 키보드·마우스 우선**. 터치는 **추가 결정 필요**(가상 패드 재도입 여부).

---

## 2. GDD 기반 전투 시스템 요구사항

### 2-1. GDD 확정 (임의 변경 금지)

| ID | 요구사항 | 출처 |
|----|----------|------|
| R1 | 기본 파티 = 군주 1 + 길드원 4 (탱커/DPS/힐러/마법사) | GDD §3 |
| R2 | 군주는 고정 직업 아님. 능력치 분배 + 스킬 트리(공격/마법/방어/지원) | GDD §4 |
| R3 | 일반 길드원 직업군: 탱커, DPS, 힐러, 마법사 | GDD §3, §11 |
| R4 | 같은 직업이라도 능력치·특성·스킬로 전투 스타일 차이 | GDD §6 |
| R5 | 일반 사냥 = 자동 사냥 중심 / 군주 참여 = 실시간 전투 화면 | GDD §11 |
| R6 | 기본 공격·스킬 자동 실행 + 전술 명령(집중 공격, 공/방 태세, 치유 우선, 후퇴) | GDD §11 |
| R7 | 승리: EXP·골드·아이템·의뢰 진척·명성 가능 | GDD §11 |
| R8 | 패배·전투불능 = 영구 사망 아님. 장비·EXP 손실 없음 | GDD §12 |
| R9 | 회복: 골드 또는 시간. HP 일부 회복 복귀는 **기본 제안** | GDD §12 |
| R10 | 아트: 2D 탑다운 고품질 픽셀. 최종 아트로 단순 색 도형 지양 | GDD §15 |
| R11 | PC(Steam) 우선, 키보드/마우스 우선 | GDD §1, §15 |
| R12 | Phase 2 범위: 사냥·몬스터≥3종·전투·EXP/골드·레벨업·HP/UI·패배. 공성전 일괄 구현 금지 | GDD §16 |
| R13 | 확정 안 된 수치(시간 단위, 명성 공식 등)는 설정값으로 분리 | GDD §17 |

### 2-2. 이번 Phase 2 범위에서 의도적으로 제외 (GDD)

- 공성전, AI 경쟁 길드 전투, 온라인
- 충성도/사기/탈퇴
- 마을 무한 확장형 건설

### 2-3. 추가 결정 필요 (GDD §17 및 전투 설계 공백)

- 전투 필드 카메라: 군주 고정 추적 vs 파티 중심
- 자동 사냥만 있는 “파견 사냥”과 “군주 실시간 출정”의 UI 분리 방식
- 보스전을 일반 사냥터 내 이벤트로 둘지, 별도 씬으로 둘지
- 군주 스킬 트리 UI를 Phase 2에 넣을지 (데이터만 먼저 / UI 포함)
- 터치 가상 패드 재도입 여부

---

## 3. 신규 전투 시스템 전체 구조

### 3-1. 설계 원칙

1. **허브 보존:** 기존 `scenes/town`, `scenes/facilities`, 시설 로직 삭제·대체 금지  
2. **전투 독립 모듈:** `scenes/combat/`, `scripts/combat/` 아래에만 신규 전투 코드 배치 **제안**  
3. **단일 보상 파이프라인:** `CombatRewardService`(가칭) 한곳에서만 gold/exp/item/rep/quest 반영 → 중복 지급 방지  
4. **데이터 구동:** 스탯·스킬·몬스터·드롭은 JSON (`data/combat/` **제안**)  
5. **기존 GameState 확장:** 신규 Autoload로 GameState를 대체하지 않음. 전투 런타임은 씬 로컬 + 결과만 GameState에 커밋 **제안**

### 3-2. 런타임 레이어

```
[Town / Gate UI]
      │ SceneRouter.go_hunt_select / go_combat  (신규 제안)
      ▼
[HuntSelect] 지역·난이도 선택
      ▼
[PartyConfirm] in_party 멤버 확인 (최대 5, 군주 필수 — 제안)
      ▼
[CombatScene]
  ├─ CombatDirector (흐름: intro→fight→resolve)
  ├─ Battlefield (배치·네비게이션)
  ├─ PartyController + AutoCombatAI
  ├─ EnemySpawner + EnemyAI
  ├─ SkillSystem
  ├─ CombatUI (HUD·전술·로그)
  └─ CombatRewardService → GameState 커밋 (1회)
      ▼
[ResultOverlay] → SceneRouter.go_town()
```

### 3-3. 전술 명령 모델 (GDD R6)

| 명령 | 효과 (제안) |
|------|-------------|
| 집중 공격 | 파티 전원의 우선 타깃 = 지정 적 |
| 공격 태세 | 공격 우선, 힐 임계↑(덜 보수적) |
| 방어 태세 | 탱커 도발 가중, DPS 사거리 유지, 이동 소극 |
| 치유 우선 | 힐러가 최저 HP% 아군 우선, 공격 스킬 억제 |
| 후퇴 | 출구 방향 이동 + 전투 포기 판정 타이머 → 패배/철수 결과 |

명령은 전투 중 언제든 변경 가능 **제안**. 기본값은 공격 태세 **제안**.

---

## 4. 전투 화면 및 UI 설계

해상도 1280×720, `UIStyle` 패널·버튼 스타일 재사용 **제안**.  
참고: `assets/art_reference/...combat_ui...png` (레이아웃만, 통째 배경 사용 금지).

### 4-1. 레이아웃 (제안)

```
┌────────────────────────────────────────────────────────────┐
│ [지역명]  [추천전투력]     [대상 HP바]      [골드] [설정]   │  ← Top HUD
├────────┬─────────────────────────────────────────┬─────────┤
│미니맵  │                                         │ 파티    │
│(선택)  │           전투 필드 (탑다운)              │ 상태    │
│        │     아군 ◇◇◇◇◇     적 ◆◆◆              │ HP/MP   │
│        │                                         │ 버프    │
├────────┴─────────────────────────────────────────┴─────────┤
│ [군주 초상 HP/MP] [스킬1..5 CD]  │ 전술: 집중/공/방/힐/후퇴 │
│ [전투 로그 스크롤]               │ [자동전투 ON] [일시정지] │
└────────────────────────────────────────────────────────────┘
```

### 4-2. 화면 요소

| 요소 | 설명 |
|------|------|
| 배경 | 지역별 필드 타일/패럴랙스 (신규). 콘셉트 콜라주 금지 |
| 배치 | 아군 하단~중앙, 적 상단~중앙. 스폰 포인트 마커 |
| HP | 머리 위 바 + 우측 파티 리스트 |
| EXP | 전투 중에는 군주/파티 요약 바 **제안**. 상세는 결과 화면 |
| 스킬 CD | 군주 스킬 슬롯 5 **제안**(데이터로 조절) |
| 전술 UI | 하단 우측 토글/버튼, 활성 테두리 `UIStyle.GOLD_BRIGHT` |
| 로그 | 피해·힐·스킬·처치 한 줄 로그 |
| 승리/패배 | 모달: 보상 목록 / 전투불능자 / [마을로] |
| 복귀 | `SceneRouter.go_town()`, 시설 상태 유지 |

### 4-3. 조작 (PC 우선, 제안)

| 입력 | 동작 |
|------|------|
| WASD / 방향키 | 군주 이동 |
| 마우스 좌클릭 적 | 집중 공격 대상 |
| 1–5 | 군주 스킬 수동 발동(자동 모드여도 수동 가능 **제안**) |
| Q/E 또는 UI | 전술 태세 순환 |
| Esc | 일시정지 메뉴 (마을 복귀 확인) |
| Space | 자동전투 토글 **제안** |

InputMap은 `project.godot`에 신규 액션 추가가 **구현 단계**에서 필요 (이번 문서는 계획만).

---

## 5. 캐릭터와 몬스터 데이터 구조

### 5-1. 기존 members 레코드와의 관계 (확인됨 + 제안)

현재 `GameState._member`에 전투 런타임 필드(`hp`, `mp`, `atk` 파생 등)가 없음.  

**제안:**  
- **영속 데이터**는 `GameState.members`에 유지·최소 확장  
- **전투 인스턴스**는 `CombatantRuntime`으로 복사해 사용 후, 결과만 영속에 반영  

영속 확장 필드 **제안** (세이브 호환: 로드 시 기본값 채움):

```text
hp_max, mp_max          # 레벨·VIT/WIS 파생 캐시 또는 재계산
skill_points / tree     # 군주만 (스킬 트리) — 상세 UI는 추가 결정 필요
combat_power            # 표시용 캐시 선택
```

### 5-2. 스탯 → 전투 파생 (제안식, 밸런스 조정 가능)

| 파생치 | 제안 공식 |
|--------|-----------|
| HP_max | `80 + vit*12 + level*8` (군주는 `+20`) |
| MP_max | `30 + wis*8 + int*4 + level*3` |
| ATK | `5 + str*2 + level` (+ 장비 atk) |
| MATK | `5 + int*2 + level` |
| DEF | `2 + vit + level/2` (+ 장비 def) |
| ASPD | `1.0 + agi*0.02` (공격/초, 상한 제안 2.0) |
| Move | `80 + agi*2` px/s (상한 제안 160) |

장비 보너스는 기존 `equipment` + `data/items.json`의 `atk`/`def` 사용 **제안**.

### 5-3. 직업 역할 (GDD 확정 + 스킬 제안)

| job | 역할 | 기본 스킬 (제안 ID) | AI 요약 |
|-----|------|---------------------|---------|
| lord | 플레이어 중심, 하이브리드 | `cmd_strike`, 트리 스킬 | 자동 기본공격 + 수동/자동 스킬 |
| tank | 어그로·생존 | `taunt`, `guard` | 최근접/최고위협 적 접근, 도발 |
| dps | 단일 딜 | `double_slash` | 집중 타깃 우선, 후방 유지 |
| healer | 회복 | `heal`, `cleanse`(후순위) | HP% 최저 아군 힐 |
| mage | 마법/광역 | `mana_bolt`, `arc_burst` | 거리 유지, 다수 적 시 광역 |

동일 job이라도 `skills[]`·`traits[]`·스탯 분배로 차별화 (GDD R4).

### 5-4. 몬스터 데이터 JSON 스키마 (제안) — `data/combat/enemies.json`

```json
{
  "enemies": [
    {
      "id": "wolf",
      "name": "늑대",
      "tier": "normal",
      "hp": 60, "atk": 8, "def": 2, "move": 110, "aspd": 0.9,
      "aggro_range": 220, "attack_range": 28,
      "behavior": "chase_melee",
      "exp": 12, "gold_min": 3, "gold_max": 8,
      "drops": [{"item_id": "ore_iron", "chance": 0.08}]
    }
  ]
}
```

**초기 3종 + 보스 (제안, 수치 조정 가능):**

| id | 차별점 |
|----|--------|
| `wolf` | 빠른 근접, 낮은 DEF |
| `goblin` | 중간 속도, 소형 원거리 투척 **제안** |
| `slime` | 느림, 높은 HP, 분열 없음(초기 단순) |
| `boss_forest` | 바람의 숲 보스: 다단 패턴, HP 높음 **제안** |

### 5-5. 군주 성장 (GDD R2)

- 레벨업 시 스탯 포인트 분배 UI: Phase 2-3 **제안** (포인트 수 **추가 결정 필요**, 예: 레벨당 3)
- 스킬 트리 4계열: 데이터만 Phase 2-2, UI는 Phase 2-3 이후 **추가 결정 필요**

---

## 6. 직업별 전투 AI

공통 틱 **제안:** 0.1–0.2s AI 업데이트. 타깃 무효(사망) 시 재선정.

### 6-1. 타깃 선정 규칙 (제안)

1. 전술 “집중 공격” 대상이 생존하면 최우선  
2. 없으면 사거리 내 최근접  
3. 동률이면 현재 HP 낮은 적  
4. 힐러는 아군 HP% < 임계(방어 태세 40% / 공격 태세 25% **제안**) 시 힐 우선

### 6-2. 역할 AI

| 역할 | 이동 | 공격 | 스킬 |
|------|------|------|------|
| 군주 | 플레이어 입력 우선. 자동모드 시 DPS형 | 기본공격 자동 | CD 완료 시 조건 스킬 또는 수동 |
| 탱커 | 적 쪽으로 접근, 아군과 적 사이 | 근접 | HP 여유 시 도발 |
| DPS | 집중 타깃 추격, 아군 뒤로 살짝 | 단일 | CD마다 딜 스킬 |
| 힐러 | 아군 중심 유지, 적과 거리 | 필요 시 약공격 | 힐 우선 |
| 마법사 | 사거리 유지(카이팅) | MATK | 적 ≥3 근접 시 광역 |

### 6-3. 몬스터 AI (제안)

| behavior | 동작 |
|----------|------|
| `chase_melee` | 어그로 범위 내 최근접 아군 추격·공격 |
| `ranged_kite` | 사거리 유지, 도주 스트래핑 |
| `boss_phase` | HP 50% 이하 패턴 강화 **제안** |

피격: 플래시/넉백만(짧은). HP≤0 → 전투불능(아군) 또는 사망 처리(적). 아군은 영구 삭제하지 않음 (GDD R8).

---

## 7. 전투 계산 및 보상 시스템

### 7-1. 피해·회복 (제안식)

```
raw = ATK(or MATK) * skill_mul + skill_flat
mitigated = max(1, raw - DEF * 0.5)
crit = random < (agi*0.002) ? mitigated * 1.5 : mitigated   # 크리 공식·확률 추가 결정 필요
heal = skill_power + WIS * 1.5
```

모든 상수는 `data/combat/balance_combat.json` **제안**.

### 7-2. 경험치·레벨 (제안)

- 적 처치 EXP는 파티 생존 인원에게 균등 분배 **제안** (전투불능 제외 여부 **추가 결정 필요**)
- 레벨업: 기존 훈련과 동일하게 `exp >= 100` 차감·level+1 **제안** (곡선 변경은 balance로)

### 7-3. 골드·드롭

- 골드: `gold_min..gold_max` 합산 후 `GameState.add_gold` 1회  
- 아이템: 드롭 테이블 롤 → `GameState.add_item`  
- 명성: 보스/의뢰 연동만 **제안** (일반 잡몹 명성은 **추가 결정 필요**)

### 7-4. 단일 보상 커밋 (중복 방지)

```
CombatRewardService.commit_once(result):
  if result.committed: return
  apply gold, exp, items, reputation, quest flags
  set injured flags for downed allies
  result.committed = true
  GameState.save_game()  # 제안: 전투 종료 시 자동 저장
```

승리/패배 UI 버튼 연타·시그널 중복에 대비해 `committed` 플래그 필수.

### 7-5. 전투불능

- HP 0 → `downed` 런타임 상태, 전투 종료 후 `member.injured = true`  
- 장비·level·exp 감소 없음 (GDD R8)  
- 마을 의무실 `heal_member`로 회복 (기존 기능 유지)

### 7-6. 승리·패배 조건 (제안)

| 결과 | 조건 |
|------|------|
| 승리 | 스폰된 적(및 웨이브) 전멸 |
| 패배 | 군주 전투불능 **또는** 파티 전원 전투불능 **또는** 후퇴 완료 |
| 패배 보상 | EXP/골드 없음 또는 소량 위로 보상 **추가 결정 필요**. 아이템 손실 없음 |

---

## 8. 마을과 전투 연결 구조

### 8-1. 플레이 흐름 (목표)

```
길드 마을
  → 사냥터 출구(gate) 클릭
  → 사냥터 선택 (기존 _build_gate UI 확장 또는 전용 씬)
  → 파티 확인 (in_party, 부상 멤버 경고)
  → 전투 시작
  → 전투 진행
  → 승리/패배 결과 + 보상
  → 마을 복귀
```

### 8-2. 연결 방식 (제안, 기존 보존)

| 단계 | 기존 | 변경 계획(구현 시) |
|------|------|-------------------|
| 마을 gate 핫스팟 | 유지 | 유지 |
| `go_facility("gate")` | 유지 | 유지하되 `_build_gate`의 “이동”이 `SceneRouter.go_combat(area_id)` 호출 |
| 시설 셸/좌측 내비 | 유지 | 유지 |
| 여관/상점 등 | 유지 | 회귀 테스트만 |

**대안(추가 결정 필요):** gate에서 바로 `HuntSelect.tscn`으로 보내고 facility 경유를 줄이기.  
권장: **기존 gate UI를 살리되 이동 버튼만 전투 진입에 연결** (변경 최소화).

### 8-3. 파티 편성

- 초기: 전원 `in_party` (확인됨)  
- 길드 본부 UI에 이미 파티 표시 있음 → Phase 2에서 `in_party` 토글 강화 **제안**  
- 전투 시작 조건 **제안:** 군주 포함, 1–5명, 부상자는 출정 불가 또는 경고 후 제외 **추가 결정 필요**

### 8-4. 의뢰 연동 (제안)

- `active_quests`와 사냥터/처치 카운터 매핑  
- 보상 명성·골드는 `CombatRewardService`에서만 지급

---

## 9. 신규 생성 예정 파일 목록

> 구현 승인 전까지 **생성하지 않음**. 이름 충돌 검수: 현재 저장소에 동명 파일 없음(확인됨).

### 9-1. 씬

| 경로 | 역할 |
|------|------|
| `scenes/combat/combat.tscn` | 메인 전투 씬 |
| `scenes/combat/hunt_select.tscn` | (선택) 전용 사냥터 선택. gate UI 확장 시 생략 가능 |
| `scenes/combat/result_overlay.tscn` | 또는 combat 씬 내 Control |

### 9-2. 스크립트

| 경로 | 역할 |
|------|------|
| `scripts/combat/combat_director.gd` | 전투 상태머신 |
| `scripts/combat/combat_manager.gd` | 스폰·승패·일시정지 (씬 노드, Autoload 아님 **제안**) |
| `scripts/combat/character_base.gd` | 아군/적 공통 전투 유닛트 |
| `scripts/combat/party_member_actor.gd` | 길드원 액터 |
| `scripts/combat/player_lord_actor.gd` | 군주 입력+자동 |
| `scripts/combat/enemy_base.gd` | 적 액터 |
| `scripts/combat/enemy_ai.gd` | 적 AI |
| `scripts/combat/party_ai.gd` | 아군 자동 AI |
| `scripts/combat/skill_system.gd` | 스킬 실행·CD |
| `scripts/combat/combat_ui.gd` | HUD·전술·로그 |
| `scripts/combat/combat_reward_service.gd` | 단일 보상 커밋 |
| `scripts/combat/combatant_runtime.gd` | 런타임 스탯 |

### 9-3. 데이터

| 경로 | 역할 |
|------|------|
| `data/combat/balance_combat.json` | 공식 계수·레벨 곡선 |
| `data/combat/enemies.json` | 몬스터 |
| `data/combat/skills.json` | 스킬 |
| `data/combat/hunts.json` | 사냥터→웨이브/보스 |

### 9-4. 에셋 (신규 필요, 원본 art_reference 비파괴)

| 경로 | 역할 |
|------|------|
| `assets/sprites/characters/runtime/` | 검증·슬라이스된 시트 복사본 |
| `assets/sprites/enemies/` | 몬스터 |
| `assets/backgrounds/combat/` | 필드 |
| `assets/fx/` | 타격/스킬 (후순위) |

### 9-5. SceneRouter 확장 (구현 시)

- `go_combat(hunt_id: String)` 추가 **제안**  
- 기존 `TITLE/TOWN/SETTINGS/FACILITY` 상수·메서드 **유지**

### 9-6. Autoload

- 신규 Autoload **최소화 제안**. `CombatManager`는 씬 로컬.  
- `EventBus` 도입은 **추가 결정 필요**(시그널을 GameState/CombatDirector로도 가능).

---

## 10. 단계별 개발 계획

### Phase 2-1: 전투 기본 구조

| | |
|--|--|
| **작업** | `combat.tscn`, CharacterBase 이동/기본공격, 적 1종 스폰, HP·피해, 임시 스프라이트(개발 중만 도형 허용·최종 교체) |
| **파일** | §9 핵심 씬/베이스 + enemies.json 일부 |
| **선행** | 본 계획 승인. 군주 이동 InputMap 추가 승인 |
| **완료 기준** | 전투 씬 진입→이동→타격→적 HP 감소→처치 가능 |
| **테스트** | 이동/공격/HP, 일시정지, Esc |

### Phase 2-2: 파티 전투

| | |
|--|--|
| **작업** | 5인 스폰, 직업 AI, 전술 명령 UI, 타깃 선정 |
| **선행** | 2-1 완료. `in_party` 멤버 소스 = GameState |
| **완료 기준** | 자동전투로 소규모 전투 클리어. 전술 전환 시 행동 변화 관찰 가능 |
| **테스트** | 직업별 행동, 집중 공격, 후퇴 |

### Phase 2-3: 전투 성장

| | |
|--|--|
| **작업** | EXP/레벨/골드/드롭, CombatRewardService, 전투불능→injured, 결과 UI |
| **선행** | 2-2. 기존 `add_gold`/`add_item`/`save_game` 재사용 |
| **완료 기준** | 보상 1회만 지급. 부상자가 의무실에 표시 |
| **테스트** | 중복 지급 방지, 세이브 후 골드/EXP/부상 유지 |

### Phase 2-4: 전투 콘텐츠

| | |
|--|--|
| **작업** | 몬스터 ≥3종, 보스 1, 웨이브/난이도, 승패 처리 완결 |
| **선행** | 적 아트 확보 또는 임시 고품질 시트 |
| **완료 기준** | GDD Phase 2 몬스터 차별화 충족 |
| **테스트** | 종별 AI/스탯 차이, 보스 클리어/전멸 |

### Phase 2-5: 마을 연동

| | |
|--|--|
| **작업** | gate “이동” → 전투, 복귀, 시설 회귀, Windows 내보내기 체크리스트 |
| **선행** | 2-3 이상 |
| **완료 기준** | 마을↔전투 왕복. 상점/여관/훈련/의무실 smoke+수동 회귀 |
| **테스트** | §11 전체 + 해상도 변경 |

**권장 구현 순서:** 2-1 → 2-2 → 2-3 → 2-5(최소 연동) → 2-4 콘텐츠 확장.  
(연동을 늦추면 허브 회귀를 늦게 발견하므로 2-3 직후 얇은 2-5를 넣는 **제안**)

---

## 11. 테스트 계획 및 완료 기준

### 11-1. 테스트 항목

| ID | 항목 | 단계 |
|----|------|------|
| T1 | 캐릭터 이동·공격 | 2-1 |
| T2 | 파티 자동 전투 | 2-2 |
| T3 | 직업별 행동 차별 | 2-2 |
| T4 | 몬스터 AI | 2-1/2-4 |
| T5 | 스킬·쿨다운 | 2-2 |
| T6 | 승리·패배 | 2-3 |
| T7 | 보상 중복 지급 방지 | 2-3 |
| T8 | EXP·레벨업 | 2-3 |
| T9 | 저장·불러오기 (전투 후) | 2-3/2-5 |
| T10 | 마을 복귀 | 2-5 |
| T11 | 기존 시설 회귀 (여관/상점/훈련/의무실/의뢰) | 2-5 |
| T12 | 화면 크기 stretch | 2-5 |
| T13 | Windows 실행·빌드 | 2-5 |

### 11-2. 완료 표시 규칙

- **실제 실행 테스트 전에는 완료로 표시하지 않음** (본 문서 작성 시점에 전투 코드 없음 → 전부 **미실행**)  
- 기존 `smoke_test.gd`는 허브 전용. 전투용 `smoke_combat.gd` **제안**(구현 후)

### 11-3. Phase 2 전체 완료 기준 (요약)

1. 마을에서 사냥터로 들어가 실시간 5인 전투 가능  
2. 몬스터 ≥3종 + 보스 1  
3. 자동전투 + 전술 명령  
4. EXP/골드/아이템/부상 연동, 보상 1회  
5. 패배 시 영구 사망·장비 손실 없음  
6. 시설 기능 회귀 통과  
7. 1280×720 Nearest 유지  

---

## 12. 위험 요소 및 기존 시스템 충돌 가능성

| 위험 | 심각도 | 설명 | 완화 |
|------|--------|------|------|
| GameState 스키마 확장 | 중 | 세이브 구버전 호환 | 로드 시 기본값 마이그레이션 |
| `facility_screen.gd` 비대화 | 중 | gate 로직 추가 시 충돌 | 전투 진입만 위임, UI 대량 이관 자제 |
| SceneRouter API 추가 | 저 | 기존 호출부 영향 적음 | 메서드 추가만, 기존 유지 |
| Autoload CombatManager | 중 | 허브와 수명 충돌 | 씬 로컬 권장 |
| 아트 공백(몬스터/필드) | 고 | 최종 아트 도형 금지(GDD) | 시트 검증·복사본, 임시 도형은 개발 한정 |
| 스프라이트 시트 비균일 | 중 | 이전 분석에서 셀 폭 불균일 | 수동 슬라이스·메타데이터 |
| EXP 100 단위 단순 곡선 | 저 | 후반 밸런스 | balance JSON |
| Forward Plus vs 저사양 | 저~중 | GL Compatibility **추가 결정 필요** | 빌드 프로파일 분리 검토 |
| 훈련 EXP vs 전투 EXP | 저 | 이중 성장 | 동일 레벨 규칙 공유 |
| 터치 미지원 | 중 | GDD “있으면 유지”이나 현재 없음 | PC 우선 명시, 터치는 후속 |

---

## 13. 추가 결정이 필요한 기획 항목

구현 승인 전에 사용자 확인을 권장하는 목록:

1. **게이트 UX:** 기존 facility gate UI 확장 vs 전용 `HuntSelect` 씬  
2. **패배 시 보상:** 완전 무보상 vs 소량 위로  
3. **전투불능 출정:** 부상자 출정 금지 vs 허용  
4. **군주 스킬 트리 UI**를 Phase 2에 포함할지  
5. **크리티컬·MP 소모** 공식 채택 여부  
6. **일반 잡몹 명성** 지급 여부  
7. **자동 저장** 시점 (전투 종료만 / 마을 복귀 시)  
8. **GL Compatibility** 빌드 지원 여부  
9. **모바일 가상 패드** 재도입 여부  
10. **몬스터·필드 아트** 제작 방식 (시트 가공 / 신규 외주 / AI 생성 후 검수)  
11. **보스 배치:** 지역당 1보스 고정 vs 랜덤 이벤트  
12. **파견 자동사냥**(군주 미참여)을 Phase 2에 넣을지 — GDD상 장기 시스템, Phase 2에서는 **제외 제안**

---

## 부록 A. 분석한 현재 프로젝트 파일 목록

```
project.godot
data/balance.json
data/items.json
data/adventurers.json
data/quests.json
scenes/main/main.tscn
scenes/title/title.tscn
scenes/title/settings.tscn
scenes/town/town.tscn
scenes/facilities/facility.tscn
scripts/core/game_state.gd
scripts/core/scene_router.gd
scripts/core/main.gd
scripts/core/smoke_test.gd
scripts/ui/ui_style.gd
scripts/ui/title_screen.gd
scripts/ui/town_screen.gd
scripts/ui/facility_screen.gd
scripts/ui/settings_screen.gd
01_Documents/GuildMaster_GDD_v0.1.md
docs/reviews/phase1_environment_review.md
docs/reviews/combat_prototype_source_search.md
assets/sprites/characters/portrait_*.png
assets/art_reference/** (참고용, .gdignore)
assets/backgrounds/hunt_select.png
assets/sprites/buildings/gate.png
```

## 부록 B. 문서 작성 시 준수 확인

- 게임 코드·씬·에셋·`project.godot`·시설 기능·세이브 스키마: **수정하지 않음**  
- 전투 시스템: **구현하지 않음** (본 계획서만 작성)  
- 사용자 승인 전 코딩 시작: **하지 않음**

---

*다음 단계: 본 계획서 검토·§13 항목 결정 후 Phase 2-1 구현 승인.*
