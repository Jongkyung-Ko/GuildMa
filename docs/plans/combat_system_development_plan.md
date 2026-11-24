# GuildMaster 신규 전투 시스템 개발 계획서

- **문서 유형:** 설계·개발 계획 (코드/씬/에셋/설정 **미변경**)
- **대상 저장소:** [Jongkyung-Ko/GuildMa](https://github.com/Jongkyung-Ko/GuildMa) `main`
- **선행 확인:** `01_Documents/GuildMaster_GDD_v0.1.md`, `docs/reviews/phase1_environment_review.md`, `docs/reviews/combat_prototype_source_search.md`, 현재 `project.godot`·허브 코드·에셋
- **전제:** 기존 전투 프로토타입 원본은 확보되지 않음 → **신규 설계**. 길드 마을·시설은 **보존**하고 전투를 **독립 모듈**로 붙인 뒤 연결한다.
- **표기:** **GDD 확정** / **사용자 확정** / **제안** / **추가 결정 필요** / **현재 프로젝트 확인됨**
- **개정:** 사용자 확정 결정 3건(HuntSelect 전용 화면, 패배 위로 보상, 군주 포함 완전 자동전투) 반영

---

## 0. 사용자 확정 결정 (구현 시 준수)

| ID | 결정 | 요약 |
|----|------|------|
| D1 | 사냥터 진입 | 전용 `HuntSelect.tscn` 신설. 흐름: **Town → Gate → HuntSelect → PartyConfirm → Combat → Result → Town**. 기존 Gate·마을 구조 보존. 시설 UI에 전투 UI 과다 추가 금지 |
| D2 | 패배 보상 | 패배 시 **소량** EXP 및/또는 골드 위로 보상. 승리보다 현저히 적음. 설정 파일로 조정. 승리·패배 보상 **상호 배타·단일 커밋**. 패배 반복이 효율 성장이 되지 않도록 설계. **아이템은 기본적으로 승리만**. 장비·기존 EXP 손실 없음. 전투불능 → 부상 복귀 |
| D3 | 군주 조작 | **완전 자동전투**. WASD·가상 패드로 군주 직접 이동 **하지 않음**. 5인 모두 자동 이동·공격·스킬. 플레이어는 **전술 지휘만**. 군주 성장(스탯·장비·스킬 트리·직업 제한 없음)은 GDD 유지 |

전술 명령 (**사용자 확정·유지**): 집중 공격 / 공격 태세 / 방어 태세 / 치유 우선 / 후퇴 — 전투 중 변경 가능.

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
| InputMap | `ui_cancel`(Esc)만 명시. 전투용 이동 맵 **없음** (D3에 부합: 캐릭터 이동 입력 불필요) |
| 전투 씬·CombatManager 등 | **없음** |

### 1-2. GameState (확인됨) — 전투 연결에 쓸 수 있는 부분

| 필드/기능 | 내용 | 전투 연동 시사점 |
|-----------|------|------------------|
| `members[]` | `id, name, job, level, exp, stats{str,vit,agi,int,wis}, skills, traits, upkeep, injured, equipment, in_party` | 파티·스탯·부상 상태 소스 |
| `gold` / `reputation` | 경제·명성 | 승리/패배 보상 지급 |
| `inventory` | `{id, qty}` | 드롭(승리만, D2) |
| `active_quests` | 수락 의뢰 | 전투 후 진척 **제안** |
| `save_game` / `load_game` | `user://guildmaster_save.json` | 전투 중 세이브 정책 **추가 결정 필요** |
| `train_member` | EXP +100당 레벨업 | 전투 EXP와 동일 규칙 재사용 **제안** |
| `heal_member` / `injured` | 의무실 회복 | 전투불능 → `injured=true` 연동 **제안** |

시작 파티 (확인됨): 군주 `lord` + `tank`/`dps`/`healer`/`mage` 각 1, 전원 `in_party: true`.

### 1-3. SceneRouter (확인됨)

현재: `go_title`, `go_town`, `go_settings`, `go_facility`만 존재.  
**구현 시 추가 예정 (D1):** `go_hunt_select`, `go_party_confirm`(또는 HuntSelect 내 단계), `go_combat`. 기존 메서드는 유지.

### 1-4. 마을·사냥터 연결 지점 (확인됨)

- 마을 건물 `gate` (`scripts/ui/town_screen.gd`) → `SceneRouter.go_facility("gate")`
- `facility_screen.gd` `_build_gate()`: 지역 목록 + “이동” 시 **메시지뿐**
- **D1:** Gate는 유지하되, 전투 UI를 시설에 늘리지 않고 **“사냥터 선택으로”** 한 버튼으로 `HuntSelect`만 연결 **제안**

### 1-5. 에셋 현황 (확인됨)

| 종류 | 상태 | 전투 활용 |
|------|------|-----------|
| 직업 초상 `portrait_*.png` | 있음 | UI·HuntSelect·파티 확인 재사용 **제안** |
| 스프라이트 시트 (art_reference) | 원본 보존, 런타임 미슬라이스 | 검증 후 복사본만 사용 **제안** |
| 전투 참고 UI PNG | art_reference에 존재 | 레이아웃 참고만 |
| `hunt_select.png` | 메뉴용 배경 | HuntSelect 배경 후보 **제안** |
| 몬스터 스프라이트 | **없음** | 신규 확보 **추가 결정 필요** |
| 전투 필드 | **없음** | 신규 필요 |
| 이펙트/SFX | **없음** | Phase 후반 **제안** |

### 1-6. 입력·터치 (D3 반영)

- Phase 2 전투: **캐릭터 직접 이동(WASD)·가상 패드 제외** (**사용자 확정** D3)
- 플레이어 입력은 **전술 명령·타깃 지정·일시정지·결과 확인** 중심
- 모바일 전용 터치 패드 재도입: **추가 결정 필요** (이동 패드가 아닌 UI 버튼 터치는 PC 마우스와 동일 경로로 가능 **제안**)

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
| R6 | 기본 공격·스킬 자동 실행 + 전술 명령 | GDD §11 |
| R7 | 승리: EXP·골드·아이템·의뢰 진척·명성 가능 | GDD §11 |
| R8 | 패배·전투불능 = 영구 사망 아님. 장비·EXP 손실 없음 | GDD §12 |
| R9 | 회복: 골드 또는 시간. HP 일부 회복 복귀는 **기본 제안** | GDD §12 |
| R10 | 아트: 2D 탑다운 고품질 픽셀. 최종 아트로 단순 색 도형 지양 | GDD §15 |
| R11 | PC(Steam) 우선 | GDD §1, §15 |
| R12 | Phase 2: 사냥·몬스터≥3종·전투·EXP/골드·레벨업·HP/UI·패배. 공성전 금지 | GDD §16 |
| R13 | 미확정 수치는 설정값으로 분리 | GDD §17 |

### 2-2. 사용자 확정으로 구체화된 운영 규칙

| ID | 규칙 | 근거 |
|----|------|------|
| U1 | 전용 HuntSelect 화면 + PartyConfirm 후 Combat | D1 |
| U2 | 패배 시 소량 위로 보상(EXP/골드). 아이템은 원칙상 승리만. 단일 커밋 | D2 |
| U3 | 군주 포함 5인 **완전 자동전투**. 플레이어는 전술 지휘 | D3 |
| U4 | 자동전투 = 기본 동작. 전술 명령 = AI 우선순위 변조 | D3 + R6 |

R5의 “군주 참여 = 실시간 전투 화면”은 **실시간으로 전투를 관전·지휘하는 화면**으로 해석한다. 군주 WASD 직접 조작은 **채택하지 않음**(D3).

### 2-3. 이번 Phase 2 범위에서 의도적으로 제외 (GDD)

- 공성전, AI 경쟁 길드 전투, 온라인
- 충성도/사기/탈퇴
- 마을 무한 확장형 건설
- 군주 직접 이동 조작 / 이동용 가상 패드 (D3)

### 2-4. 추가 결정 필요 (미결만 유지)

- 전투 필드 카메라: 파티 중심 vs 전장 고정 (**제안:** 파티 중심 또는 전장 개요 — 군주 추적 전용은 D3와 덜 맞음)
- 보스전: 사냥터 내 이벤트 vs 별도 씬
- 군주 스킬 트리 UI를 Phase 2에 포함할지 (데이터만 / UI 포함)
- 부상자 출정 금지 vs 허용
- 크리티컬·MP 소모 세부
- 일반 잡몹 명성
- 자동 저장 시점
- GL Compatibility
- 모바일 UI 터치 최적화(이동 패드 제외)
- 몬스터·필드 아트 확보 방식
- 보스 배치 방식
- 파견 자동사냥(군주 미참여) Phase 2 포함 여부 — **제외 제안**

---

## 3. 신규 전투 시스템 전체 구조

### 3-1. 설계 원칙

1. **허브 보존:** 기존 `scenes/town`, `scenes/facilities`, 시설 로직 삭제·대체 금지  
2. **전투 독립 모듈:** `scenes/combat/`, `scripts/combat/` (및 HuntSelect·PartyConfirm) **제안**  
3. **단일 보상 파이프라인:** `CombatRewardService` — outcome=`victory`|`defeat` 중 하나만 적용 (D2)  
4. **데이터 구동:** JSON (`data/combat/` **제안**), 패배 보상 계수도 설정화 (D2)  
5. **완전 자동전투 + 전술 레이어:** 5인 AI 기본 / 전술은 우선순위만 변경 (D3, U4)  
6. **기존 GameState 유지:** Autoload 대체 금지. 결과는 GameState에 1회 커밋 **제안**

### 3-2. 런타임 레이어 (D1 확정 흐름)

```
[Town]
  → Gate (기존 facility, 최소 변경: HuntSelect 진입만)
      │ SceneRouter.go_hunt_select()
      ▼
[HuntSelect]  지역 목록 · 몬스터 미리보기 · 난이도 · 예상 보상
      ▼
[PartyConfirm]  in_party · 부상/출정 가능 · 확정
      ▼
[CombatScene]   5인 자동전투 + 전술 지휘
  ├─ CombatDirector
  ├─ Battlefield
  ├─ PartyAutoAI (군주 포함 전원)
  ├─ EnemySpawner + EnemyAI
  ├─ SkillSystem
  ├─ CombatUI (전술·HP·자동전투 상태·로그)
  └─ CombatRewardService → GameState (victory XOR defeat, 1회)
      ▼
[ResultOverlay]  승리 보상 또는 패배 위로 보상 표시
      ▼
[Town]
```

### 3-3. 전술 명령 ↔ 자동전투 (D3)

| 명령 | AI 우선순위 변조 (**제안**) |
|------|---------------------------|
| 집중 공격 | 공격 역할(군주·DPS·메이지 등)이 지정 적을 최우선 타깃 |
| 공격 태세 | 공격 스킬·딜 행동 가중, 힐 임계 완화 |
| 방어 태세 | 탱커 도발·아군 보호 가중, DPS 과접근 억제 |
| 치유 우선 | 힐러 회복 최우선, 공격 스킬 억제 |
| 후퇴 | 전원 출구 방향 이동 → 철수/패배 판정 |

- 자동전투는 **항상 ON** (토글로 끄는 설계는 **채택하지 않음** — D3).  
- 플레이어는 전술·집중 타깃·일시정지만 조작.  
- 기본 태세: 공격 태세 **제안**.

---

## 4. 전투 화면 및 UI 설계

해상도 1280×720, `UIStyle` 재사용 **제안**.

### 4-1. HuntSelect 화면 (D1, **사용자 확정**)

```
┌────────────────────────────────────────────────────────────┐
│ 사냥터 선택                          [골드] [마을로]        │
├──────────────────┬─────────────────────────────────────────┤
│ 지역 목록         │ 선택 지역 상세                           │
│ · 바람의 숲       │ 이름 / 추천 Lv / 난이도                  │
│ · 푸른 초원       │ 출현 몬스터 미리보기(초상·이름)           │
│ · 고대 폐허 입구  │ 예상 보상(골드·EXP·드롭 요약)             │
│                   │ 보스 유무 / 잠금 사유                     │
│                   │ [출정 준비] → PartyConfirm               │
└──────────────────┴─────────────────────────────────────────┘
```

- 데이터 소스: `data/combat/hunts.json` **제안**  
- 기존 `_build_gate`의 긴 지역 리스트 UI는 **HuntSelect로 이관**. Gate는 안내 + 진입만.

### 4-2. PartyConfirm (D1)

- `in_party` 멤버 초상·직업·레벨·부상 여부  
- 출정 불가 사유 표시 (부상 등 — 규칙 **추가 결정 필요**)  
- [전투 시작] / [뒤로]

### 4-3. 전투 HUD (D3: 자동전투·지휘 UI)

```
┌────────────────────────────────────────────────────────────┐
│ [지역] [난이도]  [집중 대상 HP]     [자동전투] [일시정지]   │
├────────┬─────────────────────────────────────────┬─────────┤
│(선택)  │           전투 필드 (탑다운)              │ 파티    │
│로그    │     아군 5인 자동 배치·전투               │ HP/상태 │
│요약    │     적 배치                               │ 버프    │
├────────┴─────────────────────────────────────────┴─────────┤
│ 전술: [집중] [공격] [방어] [치유우선] [후퇴]                │
│ 활성 태세 표시 · 군주 스킬 CD(자동 사용 표시)               │
└────────────────────────────────────────────────────────────┘
```

| 요소 | 설명 |
|------|------|
| 자동전투 상태 | 상시 표시(예: “자동전투”). ON/OFF 토글 **없음**(D3) |
| 전술 버튼 | 전투 중 변경. 활성 테두리 `UIStyle.GOLD_BRIGHT` |
| 집중 타깃 | 적 클릭 또는 목록 선택 **제안** |
| 스킬 CD | 군주·파티 스킬 **자동 사용** 진행 표시 (수동 발동 슬롯은 **추가 결정 필요**, 기본은 자동만 **제안**) |
| WASD / 가상 패드 | **계획에서 제외**(D3) |
| 결과 | 승리: 풀 보상. 패배: **위로 보상** 별도 표기(D2) |

### 4-4. 조작 (PC 우선, D3)

| 입력 | 동작 |
|------|------|
| 마우스 좌클릭 적 / UI | 집중 공격 대상 지정 |
| 전술 UI 버튼 (또는 단축키 1–5 **제안**) | 전술 전환 |
| Esc | 일시정지 · 마을 복귀 확인 |
| WASD / 방향키 / 이동 패드 | **사용하지 않음** |

InputMap (구현 시): 전술·일시정지·타깃 관련만 추가 **제안**. 이동 액션 불필요.

---

## 5. 캐릭터와 몬스터 데이터 구조

### 5-1. 기존 members와의 관계 (확인됨 + 제안)

영속 = `GameState.members`. 전투 = `CombatantRuntime` 복사 후 결과만 커밋.

### 5-2. 스탯 → 전투 파생 (**제안**, 밸런스 조정 가능)

| 파생치 | 제안 공식 |
|--------|-----------|
| HP_max | `80 + vit*12 + level*8` (군주 `+20`) |
| MP_max | `30 + wis*8 + int*4 + level*3` |
| ATK | `5 + str*2 + level` (+ 장비) |
| MATK | `5 + int*2 + level` |
| DEF | `2 + vit + level/2` (+ 장비) |
| ASPD | `1.0 + agi*0.02` (상한 제안 2.0) |
| Move | `80 + agi*2` px/s (상한 제안 160) |

### 5-3. 직업·군주 AI 역할 (GDD + D3)

| job | 역할 | 기본 스킬 (**제안**) | 자동 AI |
|-----|------|----------------------|---------|
| lord | 하이브리드. 스탯·장착 스킬에 따라 근접/원거리/지원 가중 | 트리/장착 스킬 | **완전 자동**. ATK vs MATK·스킬 태그로 행동 프로파일 선택 **제안** |
| tank | 어그로·보호 | `taunt`, `guard` | 적 유인, 아군과 적 사이 |
| dps | 단일 딜 | `double_slash` | 집중 타깃 우선 |
| healer | 회복 | `heal` | HP% 최저 아군 |
| mage | 마법/광역 | `mana_bolt`, `arc_burst` | 거리 유지 |

군주 성장(R2)은 유지. 전투 중 직접 조작이 아니라 **빌드가 AI 행동을 결정**.

### 5-4. 몬스터 JSON (**제안**) — `data/combat/enemies.json`

초기 3종 + 보스: `wolf`, `goblin`, `slime`, `boss_forest` (**제안** 수치).

### 5-5. 군주 성장 (GDD R2)

- 스탯 포인트·스킬 트리: 비전투 UI. Phase 포함 범위 **추가 결정 필요**

---

## 6. 직업별 전투 AI

공통: 군주·길드원 **모두** 자동 이동·자동 공격·자동 스킬 (D3).  
틱 **제안:** 0.1–0.2s. 전술 레이어가 우선순위를 덮어씀.

### 6-1. 타깃 선정 (**제안**)

1. 집중 공격 대상 생존 시 공격 역할 최우선  
2. 아니면 사거리 내 최근접  
3. 동률 시 현재 HP 낮은 적  
4. 힐러: HP% < 임계(방어 40% / 공격 25% **제안**)면 힐 우선 — “치유 우선” 시 임계 상향

### 6-2. 역할 AI (D3)

| 역할 | 이동 | 공격 | 스킬 |
|------|------|------|------|
| 군주 | 빌드 기반(근접형 전방 / 마법형 후방 등) **제안** | 파생 ATK/MATK | 장착 스킬 CD·조건 자동 |
| 탱커 | 적 접근, 아군 보호 위치 | 근접 | 도발·가드 |
| DPS | 집중 타깃 추격 | 단일 | 딜 스킬 |
| 힐러 | 아군 중심 | 약공격(여유 시) | 회복 우선 |
| 마법사 | 카이팅 | MATK | 다수 시 광역 |

### 6-3. 전술과 AI 관계 (요약)

자동전투 = 기본. 전술 = 우선순위·가중치만 변경. 캐릭터 수동 이동 없음.

### 6-4. 몬스터 AI (**제안**)

`chase_melee` / `ranged_kite` / `boss_phase`.  
아군 HP≤0 → 전투불능(영구 삭제 없음, R8).

---

## 7. 전투 계산 및 보상 시스템

### 7-1. 피해·회복 (**제안식**)

```
raw = ATK(or MATK) * skill_mul + skill_flat
mitigated = max(1, raw - DEF * 0.5)
crit = ...   # 채택 여부 추가 결정 필요
heal = skill_power + WIS * 1.5
```

상수 → `data/combat/balance_combat.json`.

### 7-2. 승리 보상 (**제안**)

- EXP: 처치·클리어 EXP를 생존 인원 균등 (**전투불능 제외 여부 추가 결정 필요**)  
- 골드: `gold_min..gold_max` 합산  
- 아이템: 드롭 테이블 (**승리만**, D2)  
- 명성: 보스/의뢰 **제안**

### 7-3. 패배 위로 보상 (D2, **사용자 확정**)

원칙:

- 패배 시에도 **소량** EXP 및/또는 골드  
- 승리 대비 **현저히 적음**  
- `balance_combat.json` 등으로 **조정 가능**  
- `CombatRewardService`에서 `outcome`에 따라 **승리 XOR 패배**만 적용 (중복 금지)  
- 패배 파밍이 최적 성장이 되지 않도록 설계  
- **아이템 드롭 없음**(기본)  
- 장비·기존 EXP 손실 없음  
- 전투불능 → `injured=true`로 마을 복귀  

**제안값 (확정 수치 아님, 밸런스 테스트 대상):**

| 항목 | 제안 |
|------|------|
| 패배 EXP | `floor(예상_승리_파티_총EXP * defeat_exp_ratio)` — 예: `defeat_exp_ratio = 0.10`~`0.15`. 생존 멤버에게만 분배 **제안** |
| 패배 골드 | `floor(예상_승리_골드 * defeat_gold_ratio)` 또는 `defeat_gold_flat` — 예: ratio `0.05`~`0.10` |
| 진행도 보정 | 처치한 적 비율 `progress`를 곱해 중도 패배 시 더 적게 **제안** (`reward *= max(progress, progress_floor)`) |
| 아이템 | 없음 |
| 상한 | 패배 EXP/골드에 soft cap **제안** (같은 사냥터 연속 패배 감쇠는 **추가 결정 필요**) |

설정 키 예시 (**제안**):

```json
"defeat_rewards": {
  "exp_ratio": 0.12,
  "gold_ratio": 0.08,
  "use_progress_scale": true,
  "progress_floor": 0.25,
  "allow_item_drops": false
}
```

### 7-4. 단일 보상 커밋

```
CombatRewardService.commit_once(result):
  if result.committed: return
  match result.outcome:
    victory: apply_victory_rewards(...)
    defeat:  apply_defeat_consolation(...)   # items 스킵
  apply_injured_flags(...)
  result.committed = true
  GameState.save_game()  # 시점: 추가 결정 필요
```

### 7-5. 전투불능

- 장비·level·누적 EXP 감소 없음 (R8, D2)  
- 의무실 `heal_member` 유지

### 7-6. 승패 조건 (**제안**)

| 결과 | 조건 | 보상 경로 |
|------|------|-----------|
| 승리 | 적(웨이브) 전멸 | 승리 보상 |
| 패배 | 군주 전투불능 **또는** 전원 전투불능 **또는** 후퇴 완료 | 위로 보상만 |

---

## 8. 마을과 전투 연결 구조

### 8-1. 확정 흐름 (D1)

```
Town → Gate → HuntSelect → PartyConfirm → Combat → Result → Town
```

### 8-2. 연결 방식 (기존 보존 + D1)

| 단계 | 기존 | 계획 |
|------|------|------|
| 마을 gate 핫스팟 | 유지 | 유지 |
| Gate facility | 유지 | **최소 변경**: 안내 문구 + `HuntSelect` 진입 버튼만. 지역 상세·전투 UI는 넣지 않음 |
| HuntSelect | 없음 | **신규 필수** (`scenes/combat/hunt_select.tscn`) |
| PartyConfirm | 없음 | 신규 씬 또는 HuntSelect 하위 단계 **제안** |
| 여관/상점 등 | 유지 | 회귀만 |

### 8-3. 파티 편성

- `in_party` 기반. 군주 포함 1–5 **제안**  
- 부상자 출정: **추가 결정 필요**

### 8-4. 의뢰 연동 (**제안**)

보상·진척은 `CombatRewardService`에서만.

---

## 9. 신규 생성 예정 파일 목록

> 구현 승인 전까지 **생성하지 않음**.

### 9-1. 씬

| 경로 | 역할 |
|------|------|
| `scenes/combat/hunt_select.tscn` | **필수**(D1). 사냥터 선택 |
| `scenes/combat/party_confirm.tscn` | 파티 확인 (HuntSelect 내 통합 시 생략 가능 **제안**) |
| `scenes/combat/combat.tscn` | 메인 전투 |
| `scenes/combat/result_overlay.tscn` | 결과·위로 보상 표시 (또는 combat 내 Control) |

### 9-2. 스크립트

| 경로 | 역할 |
|------|------|
| `scripts/combat/hunt_select_screen.gd` | HuntSelect UI |
| `scripts/combat/party_confirm_screen.gd` | 출정 확인 |
| `scripts/combat/combat_director.gd` | 상태머신 |
| `scripts/combat/combat_manager.gd` | 스폰·승패 (씬 로컬 **제안**) |
| `scripts/combat/character_base.gd` | 공통 액터 |
| `scripts/combat/party_member_actor.gd` | 길드원 |
| `scripts/combat/player_lord_actor.gd` | 군주 **자동 AI** (직접 입력 없음) |
| `scripts/combat/enemy_base.gd` | 적 |
| `scripts/combat/enemy_ai.gd` | 적 AI |
| `scripts/combat/party_ai.gd` | 파티·군주 공통 자동 AI / 전술 가중 |
| `scripts/combat/skill_system.gd` | 스킬·CD |
| `scripts/combat/combat_ui.gd` | HUD·전술·상태 (이동 패드 없음) |
| `scripts/combat/combat_reward_service.gd` | 승리/패배 단일 커밋 |
| `scripts/combat/combatant_runtime.gd` | 런타임 스탯 |

### 9-3. 데이터

| 경로 | 역할 |
|------|------|
| `data/combat/balance_combat.json` | 전투 계수 + **defeat_rewards** |
| `data/combat/enemies.json` | 몬스터 |
| `data/combat/skills.json` | 스킬 |
| `data/combat/hunts.json` | 사냥터 메타(난이도·예상 보상·몬스터 목록) |

### 9-4. 에셋 (원본 art_reference 비파괴)

| 경로 | 역할 |
|------|------|
| `assets/sprites/characters/runtime/` | 슬라이스 복사본 |
| `assets/sprites/enemies/` | 몬스터 |
| `assets/backgrounds/combat/` | 필드 |
| `assets/fx/` | 후순위 |

### 9-5. SceneRouter (구현 시)

- `go_hunt_select()`, `go_party_confirm()`, `go_combat(hunt_id)` **제안**  
- 기존 API **유지**

### 9-6. Autoload

- 신규 Autoload 최소화. `CombatManager` 씬 로컬.  
- `EventBus`: **추가 결정 필요**

---

## 10. 단계별 개발 계획

### Phase 2-1: 전투 기본 구조

| | |
|--|--|
| **작업** | `combat.tscn`, CharacterBase **AI 이동**(직접 조작 없음), 기본 자동 공격, 적 1종, HP·피해. 개발용 임시 스프라이트만 허용·최종 교체 |
| **파일** | combat 핵심 + enemies.json 일부 |
| **선행** | 본 개정 계획 승인. **WASD 이동 InputMap 불필요** |
| **완료 기준** | 전투 씬에서 아군 1+적이 자동으로 접근·타격·HP 감소·처치 |
| **테스트** | 자동 이동/공격/HP, Esc 일시정지. **직접 이동 입력 없음 확인** |

### Phase 2-2: 파티 전투·전술

| | |
|--|--|
| **작업** | 5인(군주 포함) 자동 AI, 직업 차별, 전술 명령 UI·우선순위 |
| **선행** | 2-1. GameState `in_party` |
| **완료 기준** | 전술 변경 시 행동 변화 관찰. 군주 WASD 없음 |
| **테스트** | 직업별 AI, 집중/공/방/힐/후퇴 |

### Phase 2-3: 전투 성장·패배 위로

| | |
|--|--|
| **작업** | 승리 보상, **패배 위로 보상**(D2), CombatRewardService 단일 커밋, injured, 결과 UI |
| **선행** | 2-2 |
| **완료 기준** | 승/패 보상 상호 배타·1회. 패배 시 아이템 없음. 부상자 의무실 표시 |
| **테스트** | 중복 지급 방지, 패배 파밍이 승리보다 이득 아닌지 수치 스팟 체크 |

### Phase 2-4: 전투 콘텐츠

| | |
|--|--|
| **작업** | 몬스터 ≥3종, 보스, 난이도, 승패 완결 |
| **선행** | 적 아트 확보 |
| **완료 기준** | GDD Phase 2 몬스터 차별화 |
| **테스트** | 종별 AI, 보스 |

### Phase 2-5: 마을·HuntSelect 연동

| | |
|--|--|
| **작업** | Gate → **HuntSelect** → PartyConfirm → Combat → Result → Town. 시설 회귀. Windows 체크 |
| **선행** | 2-3 이상. HuntSelect·hunts.json |
| **완료 기준** | D1 흐름 왕복. 시설 회귀 통과 |
| **테스트** | §11 + HuntSelect 정보 표시 |

**권장 순서:** 2-1 → 2-2 → 2-3 → 2-5(HuntSelect 연동) → 2-4.  
HuntSelect 골격은 2-5 본구현 전 **얇은 스텁**을 2-1 직후 둘지 **추가 결정 필요**(연동 리스크 조기 발견용 **제안**).

---

## 11. 테스트 계획 및 완료 기준

### 11-1. 테스트 항목

| ID | 항목 | 단계 |
|----|------|------|
| T1 | 아군 **자동** 이동·공격 (직접 조작 없음) | 2-1 |
| T2 | 5인 자동 전투 | 2-2 |
| T3 | 직업·군주 빌드별 행동 | 2-2 |
| T4 | 몬스터 AI | 2-1/2-4 |
| T5 | 스킬·쿨다운(자동) | 2-2 |
| T6 | 승리·패배 | 2-3 |
| T7 | 보상 중복 방지 + **승/패 상호 배타** | 2-3 |
| T7b | 패배 위로 보상만·아이템 없음·손실 없음 | 2-3 |
| T8 | EXP·레벨업 | 2-3 |
| T9 | 저장·불러오기 | 2-3/2-5 |
| T10 | 마을 복귀 | 2-5 |
| T10b | HuntSelect → PartyConfirm → Combat 흐름 | 2-5 |
| T11 | 시설 회귀 | 2-5 |
| T12 | 화면 크기 | 2-5 |
| T13 | Windows 빌드 | 2-5 |
| T14 | 전술 명령 중 변경 | 2-2 |

### 11-2. 완료 표시 규칙

실제 실행 전 **완료로 표시하지 않음**. 현재 전투 코드 없음 → 전부 **미실행**.

### 11-3. Phase 2 전체 완료 기준

1. D1 흐름으로 실시간 5인 **자동** 전투 가능  
2. 몬스터 ≥3종 + 보스 1  
3. 전술 지휘 (직접 이동 없음)  
4. 승리 보상 + 패배 위로 보상, 각각 1회·상호 배타  
5. 영구 사망·장비/EXP 손실 없음  
6. 시설 회귀 통과  
7. 1280×720 Nearest 유지  

---

## 12. 위험 요소 및 기존 시스템 충돌 가능성

| 위험 | 심각도 | 설명 | 완화 |
|------|--------|------|------|
| Gate에 UI 과다 | 중 | 시설 비대화 | D1: HuntSelect 분리, Gate 최소 연결 |
| 패배 파밍 | 중 | 위로 보상이 승리보다 효율적 | 낮은 ratio·진행도 스케일·아이템 없음·필요 시 감쇠 |
| GameState 스키마 | 중 | 세이브 호환 | 로드 시 기본값 |
| Autoload CombatManager | 중 | 수명 충돌 | 씬 로컬 |
| 아트 공백 | 고 | GDD 도형 금지 | 시트 검증·임시는 개발 한정 |
| 군주 AI 빌드 분기 | 중 | 스탯 조합 다양 | 프로파일 테이블·스킬 태그 |
| Forward Plus | 저~중 | GL Compatibility **추가 결정 필요** | 빌드 분리 검토 |

---

## 13. 추가 결정이 필요한 기획 항목

### 13-1. 이미 확정 (미결 목록에서 제거)

1. ~~게이트 UX~~ → **전용 HuntSelect** (D1)  
2. ~~패배 보상~~ → **소량 위로 보상** (D2)  
3. ~~군주 WASD/직접 조작~~ → **완전 자동전투 + 전술 지휘** (D3)

### 13-2. 아직 결정 필요

1. **부상자 출정:** 금지 vs 허용  
2. **군주 스킬 트리 UI** Phase 2 포함 여부  
3. **크리티컬·MP 소모** 공식  
4. **일반 잡몹 명성**  
5. **자동 저장** 시점  
6. **GL Compatibility**  
7. **모바일 UI** (이동 패드 제외한 터치 최적화)  
8. **몬스터·필드 아트** 확보 방식  
9. **보스 배치**  
10. **파견 자동사냥** Phase 2 — **제외 제안**  
11. **카메라** 모드 (파티 중심 등)  
12. **패배 연속 감쇠** 적용 여부  
13. **군주 스킬 수동 발동** 슬롯 제공 여부 (기본은 자동만 **제안**)  
14. **전투불능 멤버의 승리 EXP** 분배 제외 여부  

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

## 부록 B. 문서 작성·개정 시 준수 확인

- 게임 코드·씬·에셋·`project.godot`·시설 기능·세이브 스키마: **수정하지 않음**  
- 전투 시스템: **구현하지 않음** (계획서만)  
- 사용자 승인 전 Phase 2-1 코딩: **하지 않음**

---

*다음 단계: §13-2 잔여 항목 검토 후 Phase 2-1 구현 승인. 승인 전 코딩 시작 금지.*
