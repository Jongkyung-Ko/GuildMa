# PR16 Pre-merge Regression Review

Branch: `cursor/pr16-guild-hall-responsive-bcf8`  
Date: 2026-11-27 (Asia/Seoul)

## Verdict

**Conditional approve for merge from a layout/regression standpoint**, with **HTML5 browser deep-dive still NOT VERIFIED**.

Global `content_scale_size = 720×1280` on portrait was **reverted**. Design size stays **1280×720** with **EXPAND** on all orientations. Town absolute hotspots require the 1280 design width; Guild Hall continues to reflow via its own compact layout.

## Global scale change

| Setting | Before this review pass | After |
|---|---|---|
| Portrait `content_scale_size` | `720×1280` (broke town hotspots) | always `1280×720` |
| Aspect | `EXPAND` | `EXPAND` (unchanged) |
| Per-screen | Guild Hall compact | + TownWorld 1280×720 plate; facility nav height stretch |

## Method

1. Godot headless capture suite: `scripts/core/capture_pr16_regression.gd`  
   Orientations: `390×844`, `844×390`, `1366×768`  
   Artifacts: `/opt/cursor/artifacts/pr16-regression/`
2. Visual inspection of those PNGs (not browser).
3. HTML5 local serve attempt at `127.0.0.1:8765` — **blocked at title** (clicks do not start a game; pre-existing web audio/input unlock behaviour). **No in-game browser PASS.**

## Result matrix

Legend: **PASS** = verified in Godot capture + PNG review. **NOT VERIFIED** = not confirmed in a real browser session. **FAIL** = broken.

### 1) Mobile portrait (~390×844) — screen display

| Screen | Result | Notes |
|---|---|---|
| Town (마을) | **PASS** (Godot) / **NOT VERIFIED** (browser) | Hotspots within 1280; TownWorld plate keeps 1280×720 aspect (no isometric stretch). Extra empty band below plate is expected under EXPAND. |
| Inn (여관) | **PASS** (Godot) / **NOT VERIFIED** (browser) | Shell builds; nav/content visible; tall empty area reduced via nav stretch. |
| Shop (상점) | **PASS** (Godot) / **NOT VERIFIED** (browser) | Same as inn. |
| Training (훈련장) | **PASS** (Godot) / **NOT VERIFIED** (browser) | Same. |
| Blacksmith (대장간) | **PASS** (Godot) / **NOT VERIFIED** (browser) | Same. |
| Combat (사냥) | **PASS** (Godot) / **NOT VERIFIED** (browser) | Scene builds; UI chrome visible in capture. |
| Guild Hall | see §4 | |

### 2) 720×1280 + EXPAND impact on anchors / buttons / scroll / popups

| Check | Result | Notes |
|---|---|---|
| Global portrait 720×1280 | **FAIL → fixed** | Confirmed town facility hotspots left design width under 720-wide scale. **Removed.** |
| Global 1280×720 + EXPAND | **PASS** (Godot) | `content_scale_size` stable; HUD/toast expand with viewport; facility/guild anchors OK. |
| Absolute town hotspots | **PASS** (Godot) | Protected by keeping design width 1280 + TownWorld plate. |
| Browser popup/scroll feel | **NOT VERIFIED** | Title input block prevented in-browser interaction. |

### 3) After scene transitions — resolution / layout

| Orientation | Result | Notes |
|---|---|---|
| Portrait town↔guild | **PASS** (Godot) | `content_scale_size` unchanged after transition. |
| Landscape town↔guild | **PASS** (Godot) | Same. |
| PC town↔guild | **PASS** (Godot) | Same. |
| Browser multi-hop | **NOT VERIFIED** | — |

### 4) Portrait Guild Hall — characters / party cards / save·close

| Check | Result | Notes |
|---|---|---|
| Compact stack layout | **PASS** (Godot) | `CompactActions` present; hall + parties stacked. |
| Character stage | **PASS** (Godot) | Members visible in hall interior capture. |
| Party cards | **PASS** (Godot) | Hunt / train / defend cards stacked. |
| 파티 저장 / 닫기 | **PASS** (Godot) | Reachable at end of scroll (`*_guild_hall_actions.png`). Top `마을로` also present. |
| Browser | **NOT VERIFIED** | — |

### 5) PC + mobile landscape regression

| Screen | Landscape 844×390 | PC 1366×768 |
|---|---|---|
| Town | **PASS** (Godot) / **NOT VERIFIED** (browser) | **PASS** (Godot) / **NOT VERIFIED** (browser) |
| Facilities (inn/shop/train/smith) | **PASS** (Godot) / **NOT VERIFIED** (browser) | **PASS** (Godot) / **NOT VERIFIED** (browser) |
| Combat | **PASS** (Godot) / **NOT VERIFIED** (browser) | **PASS** (Godot) / **NOT VERIFIED** (browser) |
| Guild Hall wide footer 저장/닫기 | **PASS** (Godot) / **NOT VERIFIED** (browser) | **PASS** (Godot) / **NOT VERIFIED** (browser) |

## Fixes landed in this review pass

1. `scripts/ui/ui_style.gd` — drop portrait `720×1280`; always `1280×720` + EXPAND.
2. `scripts/ui/town_screen.gd` — `TownWorld` 1280×720 plate so EXPAND does not stretch town art; named hotspots.
3. `scripts/ui/facility_screen.gd` — left nav anchors to viewport bottom on tall EXPAND heights.
4. `scripts/core/capture_pr16_regression.gd` — automated multi-orientation regression + captures.

## Follow-ups (non-blocking for PR16 layout intent)

- HTML5 title click / audio unlock still blocks browser QA of in-game screens.
- Portrait town leaves empty space under the 1280×720 plate (same scale as KEEP letterbox for the art; empty is inside the game viewport). Optional later: town-only reflow.
- Facility portrait still top-weighted content inside the stretched main panel.
