# GuildMaster Decision Log

Settled decisions only when backed by GDD, merged project behavior, or explicit owner/request text. Everything else stays **UNDECIDED**.

| ID | Decision | Date | Rationale | Systems | Changed? |
|---|---|---|---|---|---|
| D-001 | PC/Steam-first; early version single-player with AI guild competition concepts separated for later online | 2026-11-23 | GDD §1 | platform, net architecture (future) | No (docs) |
| D-002 | Core fantasy: recruit/train guild members, operate guild, compete for limited castles via sieges | 2026-11-23 | GDD §1–2 | design pillars | No |
| D-003 | Start with lord + ~4 members (5 total); default adventure party lord+4 | 2026-11-23 | GDD §3 | GameState party | Implemented in prototype |
| D-004 | Job set for members: Tank, DPS, Healer, Mage; lord is not locked to those four | 2026-11-23 | GDD §3–4 | characters, combat | Implemented |
| D-005 | Guild member wage model **C**: base upkeep + performance bonus; no loyalty/morale/quit systems in initial scope | 2026-11-23 | GDD §9 | economy (future full) | Partial / data TBD |
| D-006 | Raid defense model **C**: normal raids auto-resolve from defense placement; large raids optional lord participation; boss invasions special realtime | 2026-11-23 | GDD §10 | defense (future) | Not fully built |
| D-007 | No permanent character death — downed → recoverable incapacitation; no gear/XP loss on down in initial design | 2026-11-23 | GDD §12 | combat recovery | Partial |
| D-008 | Facilities support recruitment/gear/training/recovery/storage/admin; facility upgrades must not become the main growth axis | 2026-11-23 | GDD §14 | town facilities | Phase 1+ facilities exist |
| D-009 | Art: modern high-quality 2D; avoid shipping flat color shapes as finals; PC input first | 2026-11-23 | GDD §15 + style guide | art, UI | Ongoing upgrades |
| D-010 | Design resolution 1280×720; texture filter Nearest; embedded Noto Sans KR | 2026-11-27 | `project.godot`, `UIStyle`, style guide | rendering, UI | Yes |
| D-011 | Guild Hall visual QA landscape-only: **844×390** and **1366×768**; portrait out of scope unless reopened | 2026-11-27 | `.cursor/rules/guild-hall-landscape.mdc`, PR16/18 | guild hall UI | Yes |
| D-012 | Visual PASS owned by independent QA agent/session; automation is evidence only; no silent `main` merge | 2026-11-27 | `autonomous-visual-review.mdc`, `AGENTS.md` | process | Yes |
| D-013 | Renderer path: GL Compatibility (current `project.godot`) | 2026-11-27 | `project.godot` features + rendering_method | export, web | Yes (evolved from early Forward Plus notes) |
| D-014 | Shop categories (top-level filters): Weapons, Armor, Accessories, Consumables, Materials | 2026-11-27 | Shop/blacksmith feature (PR #19) | shop UI, items | Yes |
| D-015 | Item icon technical gate: ≥256 PNG with transparency; goal ≥512 for new core art; Q4 default / Q5 core graphics | 2026-11-27 | Permanent rules user request + art standard | items, validators | Docs/validators this PR |
| D-016 | Quality statuses FEATURE PASS / QUALITY PASS / APPROVED kept distinct; Q1–Q5 scale canonical in `GUILDMASTER_QUALITY_STANDARD.md` | 2026-11-27 | Permanent rules user request | process | Docs/rules this PR |

## UNDECIDED

Do **not** treat these as settled in rules or agent reports:

| Topic | Notes |
|---|---|
| Guild cap exactly 50 | GDD: initial target, adjustable after balance/UI tests |
| Time unit conversion (game day ↔ real time) | GDD: after prototype testing |
| Offline progress cap | Optional; needs anti-abuse rules |
| Fame ranks / gain tables | Direction only |
| Contract fee / upkeep formulas | Wage model C chosen; numbers open |
| Adventurer trait catalog size | Open |
| Auto-dispatch fail/injury rules | Open |
| Castle count / siege detail rules | Open |
| Exact Q-axis numeric weights | Not specified — qualitative grades only |
| Exact pixel metrics beyond ≥256 / goal ≥512 / ~64×64 readability | e.g. mandatory padding, outline width |
| Mandatory upscale of all legacy 256 icons to 512 | Goal for new core art only until batch approved |
| NPC sprite sheet size standard | Open |
| VFX frame counts / blend bible | Open |
| Final monster roster & boss silhouettes | Partial assets exist |
| Item catalog ≥160 expansion & subcategory scheme | On feature branch / PR #20 — **not** settled on `main` until merged |
| Painted-style sheet-split icons art-direction lock | Need human sign-off even when technical gates PASS |
| Rarity border exact palette beyond current UI | Open |
| Portrait / facility interior Q5 completion set | Diagnosis lists debt; no locked delivery order |

When a row above is decided, add a new `D-0xx` entry and remove it from UNDECIDED.
