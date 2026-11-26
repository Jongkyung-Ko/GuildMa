# PR #9 — Final Pre-Release Quality Review

- **Repo:** Jongkyung-Ko/GuildMa  
- **PR:** https://github.com/Jongkyung-Ko/GuildMa/pull/9  
- **Branch:** `cursor/combat-ai-map-travel-60e0`  
- **When:** 2026-11-26 (Asia/Seoul)  
- **Godot:** 4.3.stable · graphic = X11/OpenGL (xvfb llvmpipe); headless suites separate  

**Merge:** not performed. Awaiting explicit user approval.

---

## 1. Files touched this review (docs / harness / evidence only)

| Path | Role |
|------|------|
| `scripts/core/capture_release_path.gd` | Graphic SceneRouter path captures (title/town/gate/hub/mobile) |
| `Guild Hub Layout/internal/pr9-final-release-review.md` | This report |
| `Guild Hub Layout/internal/pr9-visual-verification/` | PNG evidence (`06`–`11`, prior `01`–`05b`, `click_*`) |
| `Guild Hub Layout/internal/pr9-final-verify-logs/` | Re-run suite logs |
| `web/index.*` | Local Web Export refresh (if committed) |

**No gameplay feature code / art asset changes** in this review.

---

## 2. F10 final boss image review

### Current config (`data/combat/enemies.json`)

| Boss | id | sprite folder | notes |
|------|-----|---------------|--------|
| Mid F5 | `boss_crypt_warden` | **`goblin`** | `color` RGBA in JSON |
| Final F10 | `boss_crypt_lord` | **`wolf`** | `color` RGBA in JSON |

`SpriteFactory.enemy_frames(kind)` loads `assets/sprites/monsters/{kind}/` only. Available monster packs: **wolf, slime, goblin** — **no dedicated boss sheet**.

JSON `color` fields are **not applied** anywhere in combat scripts (no modulate from data). Mid/final bosses therefore look like normal goblin/wolf.

### Existing resources searchable

- `assets/sprites/monsters/{wolf,slime,goblin}/` only  
- No `boss*`, crypt-lord, or unique boss animation set found  

### Recommendation (needs user approval — **not applied**)

1. Prefer adding a dedicated `assets/sprites/monsters/crypt_lord/` (and optionally `crypt_warden/`) matching existing frame naming, then set `"sprite": "crypt_lord"`.  
2. Short-term (minimal): wire unused JSON `color` → sprite `modulate` for boss tiers only (files: `character_base.gd` / enemy setup). Still reuses wolf silhouette.  
3. Do **not** invent a new boss look by remapping to an unrelated monster without art review.

**Impacted files if approved later:** `enemies.json`, optional new PNGs under `assets/sprites/monsters/…`, possibly `sprite_factory.gd` / enemy setup for tint.

---

## 3. Full play-path verification

Two evidence layers (do not conflate):

### A. SceneRouter graphic stills (production scenes, not HTML emulator)

| Step | Verdict | Evidence |
|------|---------|----------|
| Title | PASS | `06_title_screen.png` |
| Town | PASS | `07_town_screen.png` |
| Gate / dungeon entry UI | PASS | `08_dungeon_entry.png` |
| Hub floor transition (F2 after F1 clear) | PASS | `09_dungeon_floor_transition.png` |

### B. Actual mouse click path (computer-use / xdotool on real Godot window)

Agent report: title → 새 게임 → town gate → 입장 → hub → F1 combat → victory → 던전으로 → 다음 층 through F10 final victory **completed**.

| Step | Click-path verdict | Evidence (examples) |
|------|--------------------|---------------------|
| 1 Title | PASS | `click_01_title.png` |
| 2 Town | PASS | `click_02_town.png` |
| 3 Gate facility | PASS | `click_03_gate_facility.png` |
| 4 Dungeon hub | PASS | `click_04_dungeon_hub.png` |
| 5 F1 start | PASS | `click_05_f1_combat_early.png` |
| 6 F1 victory | PASS | `click_06_f1_victory.png` |
| 7 Hub return | PASS | `click_07_hub_after_f1.png` (클리어 + 다음 층) |
| 8 Next floors | PASS | `click_08_hub_f2_selected.png` … F9 hubs |
| 9 F5 mid-boss | PASS | `click_13_f5_combat_early.png`, `click_14_f5_combat_result.png` |
| 10 F10 final | PASS | `click_18_f10_combat_early.png`, `click_19_f10_combat_result.png` |
| 11 Final clear hub | PASS | `click_20_hub_after_f10_final.png` |

Video (artifacts, not forced into git): `/opt/cursor/artifacts/pr9-click-path/pr9_click_path_title_to_f10.webm`

**Observations (not fixed this pass):** dungeon floor minimap overlays top-left of combat field; F11 appears in floor list after deep progress (not clicked).

---

## 4. Web / GitHub Pages

| Check | Result |
|-------|--------|
| https://jongkyung-ko.github.io/GuildMa/ HTTP | **200** (`index.html`, `index.wasm`, `index.pck`) |
| Actions `web-preview` on **main** | Recent runs **success** (Pages tracks **main**, not this PR branch) |
| Browser load | Title screen rendered after WASM load — `10_web_preview.png` |
| Fonts on title | Korean subtitle readable |
| Aspect | Desktop 1280×720 capture OK |
| Deep dungeon / combat on **live Pages** | **NOT VERIFIED** for PR #9 content — live site is **main @ ~680dd6f** (pre–PR #9). Local Web Export of this branch was re-run (**PASS** `savepack: end`). |
| Console fatal errors | No hard failure observed in load path; WebGL software fallback warnings in headless Chrome only |

---

## 5. Mobile layout

| Check | Result | Evidence |
|-------|--------|----------|
| Portrait 720×1280 hub resize | Emulation **PASS with caveat** | `11_mobile_preview.png` |
| Letterbox / KEEP | UI centered with large black bars (display adapt) — readable but sparse |
| Touch target size | Buttons look adequate in panel; **real device NOT VERIFIED** |
| Landscape mobile | **NOT VERIFIED** |
| Combat + minimap overlap on phone | **NOT VERIFIED** on device (desktop combat still shows floor list overlay) |

---

## 6. Automation re-run (this session)

| Suite | Result | Residual exit noise |
|-------|--------|---------------------|
| validate_combat_ai.gd | **PASS** (11/0) | ObjectDB + **2** resources still in use — **still in log** |
| validate_direction_travel.gd | **PASS** (**13**/0 this run) | ObjectDB + **1** resource — **still in log** |
| validate_korean_font.gd | **PASS** (16/0) | none noted |
| validate_hunt_maze.gd | **PASS** (22/0) | none noted |
| validate_dungeon.gd | **OK** | ObjectDB + **1** resource — **still in log**; headless SKIP capture |
| Web Export | **PASS** | — |

**Analysis vs residual:** ObjectDB/resources-at-exit remain expected `-s` + AudioManager SFX hold; explained in `pr9-log-noise-analysis.md`. Messages were **not** scrubbed from logs. direction_travel pass count can vary slightly with map connectivity assertions (13 vs earlier 14) — both **0 fail**.

---

## 7. Issues found / fixed this pass

| Issue | Action |
|-------|--------|
| F10 wolf sprite reuse | **Documented only** — no art change without approval |
| Boss JSON `color` unused | Documented recommendation |
| Combat floor-list overlay | Noted; no code change |
| Live Pages ≠ PR #9 | Documented |

---

## 8. NOT VERIFIED

- Unique F10 boss art  
- Real phone hardware  
- Live Pages playthrough of **PR #9** dungeon/combat AI (until merge + Actions deploy)  
- Browser console deep dive during full web dungeon climb  

---

## 9. Release readiness

| Area | Status |
|------|--------|
| Combat AI / hunt travel / Korean fonts (auto) | Ready |
| Graphic dungeon stills + click-path climb F1→F10 | Ready (evidence on branch) |
| F10 visual identity | Acceptable for merge **only if** wolf reuse is accepted as known placeholder |
| Pages reflecting this PR | After merge + successful `web-preview` |

---

## 10. Merge recommendation

**Recommend merge after owner accepts F10 placeholder sprite (or schedules art follow-up).**  
Logic + graphic play-path evidence are in good shape; Pages will pick up changes only post-merge.  

**This agent will not merge without an explicit ask.**
