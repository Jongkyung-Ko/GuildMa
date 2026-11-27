# Autonomous visual review (how to run)

GuildMaster UI changes follow a **continuous self-review** loop. Development agents implement and capture; a **separate** independent QA agent judges PNGs by eye.

## What this is not

- Not CI-only green checks.
- Not the same chat claiming “looks good.”
- Not Godot spawning a second cloud agent (unsupported). Independent QA is always another agent/session that **Reads** the PNGs.

## Development steps

1. Branch from the current feature tip (do not push straight to `main`).
2. Implement the UI change.
3. Capture landscape PNGs:

```bash
# One-shot hall audit → /opt/cursor/artifacts/guild-hall-audit/
DISPLAY=:1 godot4 --path . --display-driver x11 \
  -s res://scripts/core/capture_guild_hall_audit.gd

# Cycle helper (before/after) → /opt/cursor/artifacts/autonomous-review/<phase>/
REVIEW_PHASE=before DISPLAY=:1 godot4 --path . --display-driver x11 \
  -s res://scripts/core/capture_autonomous_review.gd
```

4. Copy into the project store when required, e.g.:

- `media/autonomous-review/before/`
- `media/autonomous-review/after/`

5. Ask the coordinator to run **independent visual QA** on those paths (agent id may vary per Project).
6. Fix the numbered defect list; recapture `after/` (or overwrite the cycle folder); do not declare visual done while serious defects remain.
7. Open a PR when asked; **do not merge to `main`** unless explicitly requested.

## Independent QA steps

1. Open every required PNG with the vision/Read tool (not thumbnails alone).
2. Judge only the scoped sizes (Guild Hall: **844×390**, **1366×768**).
3. Write PASS/FAIL with numbered defects into the store (e.g. `docs/independent-guild-hall-qa.md`).
4. Developer self-PASS and automated suite PASS are **not** visual truth.

## Guild Hall checklist (eye)

Foot baseline · lord center · L/R balance · clear of party border · nameplates · spacing · selection · hall framing (no clipped outer actors) · scale · hall/party boundary · party card heights / 편성 not clipped · capture hygiene (distinct states).
