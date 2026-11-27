# Permanent project rules — setup report

**Branch:** `cursor/permanent-project-rules-8810`  
**Scope:** Docs / Cursor rules / quality validators only — **no** gameplay, data, or art asset edits.  
**Do not merge to `main`** unless explicitly requested.  
**Date:** 2026-11-27 (Asia/Seoul)

## Deliverables

| Deliverable | Path |
|---|---|
| Core rule | `.cursor/rules/00_guildmaster_core.mdc` |
| Quality rule (Q1–Q5 pointer) | `.cursor/rules/10_quality_standard.mdc` |
| Art rule (glob-scoped) | `.cursor/rules/20_art_asset_standard.mdc` |
| Workflow rule | `.cursor/rules/30_development_workflow.mdc` |
| Existing visual rules (cross-linked, kept) | `autonomous-visual-review.mdc`, `guild-hall-landscape.mdc` |
| Quality standard (canonical Q1–Q5) | `docs/standards/GUILDMASTER_QUALITY_STANDARD.md` |
| Art bible | `docs/standards/GUILDMASTER_ART_BIBLE.md` |
| Decision log + UNDECIDED | `docs/standards/GUILDMASTER_DECISION_LOG.md` |
| Project status | `docs/standards/GUILDMASTER_PROJECT_STATUS.md` |
| Placeholder manifesto | `docs/standards/placeholder_assets.manifest.json` |
| Python gates | `tools/validate_quality_assets.py` |
| Godot gates | `scripts/core/validate_quality_assets.gd` |
| Agent index | `AGENTS.md` (updated) |

## Dedup / conflict resolution

- Existing alwaysApply visual rules retained; short cross-links added so they do not contradict the new Q-scale or status vocabulary.
- Overlap (no self-PASS, no silent main merge, hall sizes) left authoritative in the visual rules; core/workflow **point to** them instead of restating conflicting sizes.
- Q1–Q5 defined once in `GUILDMASTER_QUALITY_STANDARD.md`; `10_quality_standard.mdc` is a pointer + summary only.
- Undecided design (fame tables, castle counts, exact pixel paddings, etc.) listed under **UNDECIDED** in the decision log — not invented as settled.

## Validator run (this environment)

### Python (executed)

```bash
python3 tools/validate_quality_assets.py
```

**RESULT: PASS** (exit 0) @ 2026-11-27 Asia/Seoul on `main` tip content (26 items):

- Unique IDs, all icon paths resolve, PNG ≥256, alpha present
- Category counts reported
- Soft: 3 very small PNGs under `assets/items/` (<1500B) — review only; default does not fail (`--strict` would)
- Explicit note: visual style never auto-approved

### Godot (authored, not executed here)

```bash
godot4 --path . --headless -s res://scripts/core/validate_quality_assets.gd
```

**Not run in this cloud VM:** `godot4` / `godot` binary absent from PATH (CI installs Godot via `chickensoft-games/setup-godot@v2`). Script is present for local/CI agents with Godot 4.3.

## New-agent applicability test (honesty)

| Surface | Rules expected to apply? | Notes |
|---|---|---|
| Cloud / Agent chat with repo rules | **Yes** | `.cursor/rules/*.mdc` with `alwaysApply` / globs |
| Fresh agent reading `AGENTS.md` + `docs/standards/*` | **Yes** | Documented entry points |
| Cursor **Tab** autocomplete | **Not assumed** | Tab may not load project rules |
| Cursor **Inline Edit** | **Not assumed** | Same limitation — paste standards or use Agent |
| Godot capture scripts spawning a second cloud QA agent | **Impossible** | Platform limit; independent QA is a separate session |

Applicability was verified by: (1) writing alwaysApply + glob frontmatter as Cursor expects, (2) indexing paths from `AGENTS.md`, (3) documenting Tab/Inline Edit limits rather than claiming universal enforcement.

## What this PR does *not* claim

- No project-wide APPROVED or Q5 graphics lock
- No visual PASS (no UI captures required for docs-only work)
- No merge of item-catalog PR #20 content
- No changes to `data/items.json`, scenes, or `assets/**` binaries

## Follow-ups (optional)

- Run Godot validator once Godot 4.3 is on the agent image / CI job
- Populate `placeholder_assets.manifest.json` when temporary art is intentionally shipped
- Refresh `GUILDMASTER_PROJECT_STATUS.md` after major merges
