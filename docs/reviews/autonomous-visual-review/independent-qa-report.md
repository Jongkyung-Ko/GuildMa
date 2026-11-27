# Independent QA — Autonomous visual review (PR #18)

## Agent role separation (proof)

| Role | Agent id | Session |
|---|---|---|
| **Development** (rules + dense 844 hunt roster fix) | `bc-7aabb77e-9076-4243-b533-a681ca61e4aa` | Separate Project session that authored tip `870ced8` on `cursor/autonomous-visual-review-e4aa` |
| **Independent visual QA** | `bc-eab724be-228e-51fa-8bf7-43b8a682bb96` | Separate Cursor agent (“Independent visual QA”) — judged PNGs by eye; never the development session |
| **Merge-readiness** (this PR mergeability work) | `bc-ef921ec7-d5f6-500d-8802-7dbfbc048b98` | Regenerated GitHub-visible captures + re-ran automation; does **not** claim visual truth |

Independent QA is a different agent id / session from development. Developer self-PASS and green `validate_guild_hall` are **not** visual truth.

## SHAs

| Label | SHA | Notes |
|---|---|---|
| BEFORE tip (pre roster fix) | `67b0e2c` | Parent of roster fix; same hunt-card bug as hall tip `57ffb8b` |
| Hall / PR #17 tip | `57ffb8b` | Even flank gaps + outer actors in frame |
| AFTER tip (roster fix) | `870ced8` | `fix: show all five hunt roster icons on dense 844 landscape` |
| Merge tip (main integrated) | `2fa6bc5de123bc8e61db2d2b2f6752c68e7d3154` | `origin/main` `@2ad7a3e` merged; conflicts resolved **ours** |

## Captures (GitHub-visible)

Repo paths (also mirrored under `/opt/cursor/artifacts/autonomous-review/{before,after}/` on the merge-readiness VM):

- `docs/reviews/autonomous-visual-review/captures/before/` — 8 PNGs @ `67b0e2c`
- `docs/reviews/autonomous-visual-review/captures/after/` — 8 PNGs @ post-fix tip
- `docs/reviews/autonomous-visual-review/captures/crops/` — hunt-card / party-strip crops for P0 evidence

Filenames per phase: `mobile_landscape_844x390_{main,lord_selected,member_selected,assign_hunt}.png`, `pc_1366x768_{main,lord_selected,member_selected,assign_hunt}.png`.

## Verdict (Independent QA session `bc-eab724be-…`)

### BEFORE — **FAIL**

- **[P0][844]** Hunting-party card (`사냥 파티`) left-clumps tiny portraits; independent eye read **2 of 5** as present / empty green row. PC 1366 shows all 5.
- Hall Round-3 placement (baseline, lord center, L/R balance, 카이 in-frame, nameplates, 편성) still held on before PNGs — that prior hall PASS is **not** inherited for the roster defect.

### AFTER — **PASS**

- P0 cleared: dense **844** hunt card shows readable **5/5** portraits (spread across the card; larger dense slots).
- Round-3 hall checks hold on 844 + 1366.
- No remaining serious defects in scope.

## Automation (merge-readiness re-run)

| Check | Result | Log |
|---|---|---|
| `validate_guild_hall.gd` | **PASS** | `docs/reviews/autonomous-visual-review/logs/validate_guild_hall.log` |
| `capture_pr16_regression.gd` | **PASS** | `docs/reviews/autonomous-visual-review/logs/capture_pr16_regression.log` |
| Regression PNGs | saved | `docs/reviews/autonomous-visual-review/captures/pr16-regression/` |

## Scope notes

- Combat balance / attack cadence / mage damage unchanged.
- Do **not** merge this PR to `main` unless explicitly requested.
