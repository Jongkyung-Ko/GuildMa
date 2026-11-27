# Agent guide — GuildMaster

## Role split

| Role | Responsibility |
|---|---|
| **Development** | Implement, run game, capture PNGs, fix from defect lists, open PRs. Never claim visual PASS alone. |
| **Independent visual QA** | Separate agent/session. Reads full-screen PNGs (vision). Owns PASS/FAIL. |

Cursor cannot auto-spawn a second cloud agent from Godot or capture scripts. Coordinators (or humans) launch the QA agent against store/artifact PNG paths.

## Permanent standards (read first)

| Doc / rule | Purpose |
|---|---|
| `.cursor/rules/00_guildmaster_core.mdc` | Core identity, honesty, design authority |
| `.cursor/rules/10_quality_standard.mdc` | Q1–Q5 pointer → canonical quality doc |
| `.cursor/rules/20_art_asset_standard.mdc` | Art/icon gates (glob-scoped) |
| `.cursor/rules/30_development_workflow.mdc` | Investigate→PR workflow + status vocabulary |
| `.cursor/rules/autonomous-visual-review.mdc` | Visual loop; no self-PASS; no silent main merge |
| `.cursor/rules/guild-hall-landscape.mdc` | Hall landscape sizes + capture criteria |
| `docs/standards/GUILDMASTER_QUALITY_STANDARD.md` | **Canonical Q1–Q5** |
| `docs/standards/GUILDMASTER_ART_BIBLE.md` | Art bible |
| `docs/standards/GUILDMASTER_DECISION_LOG.md` | Settled vs UNDECIDED |
| `docs/standards/GUILDMASTER_PROJECT_STATUS.md` | Phase / quality snapshot |

Statuses stay separate: **FEATURE PASS** · **QUALITY PASS** · **APPROVED**.

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
# Quality asset/data gates (IDs, paths, resolution, format, alpha, placeholders)
python3 tools/validate_quality_assets.py
godot4 --path . --headless -s res://scripts/core/validate_quality_assets.gd

# Full-screen hall audit (844 + 1366, distinct selection states)
DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_guild_hall_audit.gd

# Autonomous-review cycle (set REVIEW_PHASE=before|after; writes artifacts + optional STORE_DIR)
REVIEW_PHASE=before DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_autonomous_review.gd

# Landscape regression (town/facilities/hall)
DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/capture_pr16_regression.gd

# Functional hall validate (not visual PASS)
DISPLAY=:1 godot4 --path . --display-driver x11 -s res://scripts/core/validate_guild_hall.gd
```

## Cursor Tab / Inline Edit

Project `.cursor/rules` apply reliably to **Agent** sessions that load them. **Tab completions and Inline Edit are not assumed to load these rules.** Prefer Agent edits for standards-sensitive work, or paste the relevant standard into the prompt.

Human-oriented visual runbook: `docs/autonomous-visual-review.md`  
Rules setup report: `docs/reviews/permanent_project_rules_setup_report.md`
