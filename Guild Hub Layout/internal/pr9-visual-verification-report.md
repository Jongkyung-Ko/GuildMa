# PR #9 — Godot Graphic Visual Verification Report

- **Branch:** `cursor/combat-ai-map-travel-60e0`
- **PR:** https://github.com/Jongkyung-Ko/GuildMa/pull/9
- **When:** 2026-11-26 (Asia/Seoul)
- **Evidence dir:** `Guild Hub Layout/internal/pr9-visual-verification/`
- **Harness (docs/test only):** `scripts/core/capture_dungeon_visual.gd`  
  Reason: headless skips GPU capture; graphic X11 + OpenGL shots of real `dungeon_hub.tscn` / `combat.tscn` required. **No gameplay feature code changed.**

## 1. Execution environment

| Item | Value |
|------|--------|
| Godot | **4.3.stable.official** (`77dcf97d8`) |
| Entry | `project.godot` / `res://scenes/main/main.tscn` boots under same graphic stack (title boot observed) |
| DisplayServer | **X11** (via `xvfb-run`) — **not** `headless` |
| Renderer | **OpenGL API 4.5** — Mesa **llvmpipe** (software GL) |
| Capture command | `xvfb-run -a /tmp/godot --path . -s res://scripts/core/capture_dungeon_visual.gd` |
| Graphic run success | **YES** — all required PNGs written 1280×720 |

Audio ALSA open failed → dummy audio driver (environment only; does not block visuals).

## 2. Visual results (only items actually viewed)

| Screen | Verdict | Screenshot |
|--------|---------|------------|
| A. Dungeon hub | **PASS** | `pr9-visual-verification/01_dungeon_hub.png` |
| B. F1 combat | **PASS** (spawn / layout / UI) | `pr9-visual-verification/02_dungeon_f1_combat.png` |
| C. F5 mid-boss | **PASS** | `pr9-visual-verification/03_dungeon_f5_miniboss.png` |
| D. F10 final boss | **PASS** (UI / spawn) with note | `pr9-visual-verification/04_dungeon_f10_final_boss.png` |
| E. Victory | **PASS** | `pr9-visual-verification/05_dungeon_victory.png` |
| E. Next-floor control after clear | **PASS** (supplemental) | `pr9-visual-verification/05b_dungeon_hub_after_clear_next.png` |

### A. Hub — PASS
- Title **그림자 지하묘**, floor **1층 — 입구 회랑**, status uncleared (red).
- Buttons **이전 층 / 이 층 전투 / 다음 층 / 마을로 돌아가기** readable; no clipping.
- Left floor minimap **층** with 1F highlighted.

### B. F1 — PASS (logic UI + field + mid-fight still)
- Header **던전 전투 — 1층**; party 5 + enemies slime×2 + wolf; HP bars / log OK.
- Field positions party left / enemies right; Korean UI intact.
- After ~3.5s settle: wolf defeated, slime HP reduced, combat log hits, yellow impact VFX on slime — attack/damage feedback visible in still.

### C. F5 mid-boss — PASS
- Header **5층**; log **중층 보스**; single enemy **묘실 감시자** 220/220; 5F▲ highlighted.

### D. F10 final boss — PASS with observation
- Header **10층**; log **최종 보스**; enemy **지하묘 군주** 380/380.
- **Observation (not fixed):** boss uses wolf-like sprite (data `sprite` reuse). UI naming/HP OK; unique boss art **not** claimed.

### E. Victory / clear — PASS
- Combat: **승리! — 층 클리어**, enemies **처치**, log **그림자 지하묘 1층 클리어 기록**, **던전으로** CTA.
- Hub after clear: status **클리어** (green), **재도전**, **다음 층** enabled (`05b_…`).

## 3. Issues / suggestions (no code changes this task)

| Item | Severity | Notes |
|------|----------|--------|
| F10 boss visual = wolf sheet | Low / content | Expected if `enemies.json` maps final boss to wolf frames; suggest unique art later. |
| Attack VFX / frame animation | — | Still captures show combat state; full anim scrub / video **NOT VERIFIED**. |
| Full click-path from title → facility → dungeon | Partial | `main.tscn` graphic boot OK; end-to-end manual click tour **NOT VERIFIED** (scene-level load of production scenes used for dungeon shots). |
| Mobile / phone layout | **NOT VERIFIED** | Desktop 1280×720 only. |
| GitHub Pages browser look | **NOT VERIFIED** | Local graphic OpenGL only. |

## 4. Automation vs visual (do not conflate)

| Layer | Status |
|-------|--------|
| Headless suites (`validate_*`) | Prior **PASS/OK** — logic only; headless skips GPU shots |
| This graphic visual pass | Hub / F1 / F5 / F10 / victory / next-floor **PASS** with PNG evidence |
| Remaining visual gaps | Attack video scrub, title→dungeon click tour, mobile, Pages |

## 5. Merge recommendation

**Conditionally ready for merge on gameplay/logic + these dungeon graphic stills**, with documented residual notes (F10 sprite reuse; no Pages/mobile visual).  
**Do not merge** until the PR owner explicitly approves. This agent will not merge.
