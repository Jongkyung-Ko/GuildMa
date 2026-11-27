# PR16 Pre-merge Regression Review (Landscape-only)

Branch: `cursor/pr16-guild-hall-responsive-bcf8`  
Date: 2026-11-27 (Asia/Seoul)

## Scope change

**GuildMaster is landscape-only.** Portrait (390×844 / 430×932) responsive work is **out of scope**.  
Required verification targets only:

1. **844×390** mobile landscape (priority)
2. **1366×768** PC

Do **not** merge to `main` from this pass.

## Verdict

Layout/regression checks target landscape windows only. Global design size stays **1280×720** + **EXPAND**. Guild Hall always uses the **wide** split; portrait stacked-scroll (`_layout_compact` / `CompactActions`) is **disabled**.

## Global scale

| Setting | Value |
|---|---|
| `content_scale_size` | always `1280×720` |
| Aspect | `EXPAND` |
| Guild Hall | wide split only; dense packing when window is short landscape (`y≤420` or aspect≥2) |

## Method

1. `scripts/core/capture_pr16_regression.gd` — `844×390`, `1366×768`
2. `scripts/core/capture_guild_hall_responsive.gd` — same two sizes
3. Artifacts under `/opt/cursor/artifacts/pr16-regression/` and `guild-hall-responsive/`

## Checks (Godot X11 capture — this pass)

| Check | 844×390 | 1366×768 |
|---|---|---|
| Design scale 1280×720 stable | **PASS** | **PASS** |
| Town TownWorld 1280×720 + hotspots | **PASS** | **PASS** |
| Facilities / combat build | **PASS** | **PASS** |
| Guild Hall wide footer 저장/닫기 | **PASS** | **PASS** |
| Dense packing on short landscape | **PASS** (ON) | **PASS** (OFF) |
| CompactActions hidden | **PASS** | **PASS** |
| Scale stable after town↔guild | **PASS** | **PASS** |
| Suite result | `=== PR16 REGRESSION CAPTURE: PASS ===` | |

Artifacts: `/opt/cursor/artifacts/pr16-regression/`, `/opt/cursor/artifacts/guild-hall-responsive/`

## Follow-ups

- HTML5 browser deep-dive still optional / may be blocked at title unlock.
- Portrait layouts intentionally not optimized.
- **Do not merge to `main`** from this landscape-scope pass unless requested.
