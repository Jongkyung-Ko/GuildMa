# Agent guide — GuildMaster

## Role split

| Role | Responsibility |
|---|---|
| **Development** | Implement, run game, capture PNGs, fix from defect lists, open PRs. Never claim visual PASS alone. |
| **Independent visual QA** | Separate agent/session. Reads full-screen PNGs (vision). Owns PASS/FAIL. |

Cursor cannot auto-spawn a second cloud agent from Godot or capture scripts. Coordinators (or humans) launch the QA agent against store/artifact PNG paths.

## Mandatory visual loop

1. Implement on a feature branch (`cursor/…`, never silent `main` merges).
2. Run Godot with a real display; capture full-screen PNGs.
3. Hand captures to **independent** visual QA; wait for a numbered defect list (or PASS).
4. Fix only listed defects without regressing prior PASS items; recapture; repeat.
5. Automated validates (`validate_*.gd`, regression captures) are **not** eye PASS.

## Guild Hall sizes

- **844×390** and **1366×768** only (landscape). Portrait out of scope.

## Key scripts

```bash
# Full-screen hall audit (844 + 1366, distinct selection states)
DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_guild_hall_audit.gd

# Autonomous-review cycle (set REVIEW_PHASE=before|after; writes artifacts + optional STORE_DIR)
REVIEW_PHASE=before DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_autonomous_review.gd

# Landscape regression (town/facilities/hall)
DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_pr16_regression.gd

# Functional hall validate (not visual PASS)
DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/validate_guild_hall.gd
```

## Project rules

Always-on Cursor rules live in `.cursor/rules/`:

- `autonomous-visual-review.mdc` — loop, no self-PASS, no main auto-merge, QA limit
- `guild-hall-landscape.mdc` — sizes and hall criteria

Human-oriented runbook: `docs/autonomous-visual-review.md`
