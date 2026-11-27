# GuildMaster Quality Standard (canonical)

**Single source of truth for Q1–Q5.** Cursor rule `10_quality_standard.mdc` points here — update this file when the scale changes.

Last updated: 2026-11-27 (Asia/Seoul). Derived from the permanent-rules setup request + settled project docs. Do not invent finer numeric weights than listed under UNDECIDED in `GUILDMASTER_DECISION_LOG.md`.

## Grades

| Grade | Meaning |
|---|---|
| **Q1** | Prototype / spike. Broken or missing UX acceptable for exploration only. **Never ship.** |
| **Q2** | Functional draft. Core path works; placeholders allowed; major visual/UX debt expected. **Not APPROVED.** |
| **Q3** | Feature-complete for testing. Auto tests may PASS; art/UI still provisional. **Human visual review required before APPROVED.** |
| **Q4** | **Default bar for final content.** Feature + UI + data + stability meet standard; art consistent enough for release candidates; **no undeclared placeholders**; **no missing image paths**; **no critical UI overlap**. Human visual review PASS required for APPROVED. |
| **Q5** | **Target for core graphics** (hero items, key characters, signature UI chrome, landmark environments). Hand-authored high detail, silhouette readable at 64×64, style-bible compliant, **independent visual QA PASS**. |

## Evaluation axes

Grade each axis Q1–Q5 or N/A:

| Axis | Focus |
|---|---|
| **Function** | Feature path works; regressions covered by validates / smoke where they exist |
| **Graphics** | Art/assets vs Art Bible; placeholders declared; technical gates |
| **UI/UX** | Layout, readability, overlap, landscape targets |
| **Data** | Unique IDs, valid refs, counts, save-safe fields |
| **Stability** | Crashes, soft locks, load failures |

## Hard rules

1. **Q4+** is the default goal for final content; **core graphics aim for Q5**.
2. Placeholders must **not** be treated as final assets.
3. For **APPROVED**: missing images = **0**, critical UI overlaps = **0**.
4. Keep three statuses separate:
   - **FEATURE PASS** — scoped behavior / automated functional checks
   - **QUALITY PASS** — graded bar including required visual review
   - **APPROVED** — owner/human sign-off
5. Automated tests ≠ visual PASS ≠ final APPROVED. Automation **never** auto-approves visual style.
6. Below-bar items must not be marked APPROVED.

## Technical gates (automatable)

These support Graphics/Data grades; passing them is **necessary but not sufficient** for APPROVED.

| Gate | Expectation |
|---|---|
| Unique IDs | No duplicate `id` in `data/items.json` (and other ID catalogs when validated) |
| Path existence | Every `icon` / referenced `res://` asset path resolves on disk |
| Resolution | Item icons **≥ 256×256** (goal ≥ 512 for new Q5-oriented art) |
| Format | PNG (prefer RGBA) |
| Transparency | Real alpha (not opaque rectangle pretending to be cutout) |
| Placeholder honesty | Declared list / heuristic candidates reported; count > 0 blocks “no placeholders” claims |
| Counts | Catalog size and category tallies reported |
| Bad refs | Broken `res://` strings, empty icon fields |

Commands:

```bash
python3 tools/validate_quality_assets.py
# optional Godot mirror (resource existence + catalog)
godot4 --path . --headless -s res://scripts/core/validate_quality_assets.gd
```

## Visual review (not automated)

- Independent agent/session Reads full-screen PNGs (see `.cursor/rules/autonomous-visual-review.mdc`).
- Guild Hall landscape sizes: **844×390**, **1366×768** only unless task reopens portrait.
- Developer self-PASS and pixel heuristics are not visual truth.

## Related docs

- Art: `docs/standards/GUILDMASTER_ART_BIBLE.md`, `docs/art/STYLE_GUIDE.md`, `docs/art/QUALITY_DIAGNOSIS.md`
- Decisions: `docs/standards/GUILDMASTER_DECISION_LOG.md`
- Status: `docs/standards/GUILDMASTER_PROJECT_STATUS.md`
- Agent loop: `AGENTS.md`, `docs/autonomous-visual-review.md`
