# Post-Merge Verification Report (PR #9 → main)

- **When:** 2026-11-27 (Asia/Seoul)  
- **Main SHA:** `0da5e2b9fa2cb14cb4ebcfa3ca10a1f8366e70ec`  
  (`fix: combat AI loops, Korean map fonts, hunt direction travel (#9)` squash)  
- **Working branch for this report:** `cursor/post-merge-verification-60e0` (from `origin/main`)  
- **Evidence:** `Guild Hub Layout/internal/post-merge-verification/`  
- **Godot:** 4.3.stable · graphic play = X11 + OpenGL llvmpipe (xvfb), **not** headless  

---

## 1. Main sync

| Check | Result |
|-------|--------|
| `origin/main` == `0da5e2b…` | **PASS** |
| PR #9 artifacts present (`hunt_direction_pad.gd`, `damage_hits`, `was_dead`, Noto `draw_font`) | **PASS** |
| F10 still `sprite: wolf` (approved placeholder) | **PASS** (unchanged) |

---

## 2. GitHub Pages deploy

| Check | Result |
|-------|--------|
| Actions `web-preview` run for `0da5e2b` | **PASS** — [run #19](https://github.com/Jongkyung-Ko/GuildMa/actions/runs/45846033257) `completed/success` |
| https://jongkyung-ko.github.io/GuildMa/ | **PASS** HTTP 200 |
| `index.wasm` / `index.pck` | **PASS** 200 (pck ~54.7 MB, wasm ~35.4 MB); `last-modified` aligned with deploy |
| Browser title load + Korean subtitle | **PASS** — `10_web_pages.png` |
| Full web dungeon climb in browser | **NOT VERIFIED** (title load only in Chrome headless; deep path verified in desktop Godot) |

---

## 3. Actual Godot play path (mouse clicks)

DisplayServer **X11**, OpenGL Mesa llvmpipe. Auto-combat used; pauses not required.

| Step | Result | Evidence |
|------|--------|----------|
| Title → 새 게임 | **PASS** | `01_title.png` |
| Town | **PASS** | `02_town.png` |
| Gate → 그림자 지하묘 입장 | **PASS** | (via click path) |
| Dungeon hub | **PASS** | `03_dungeon_hub.png` |
| F1 combat start / AI fighting | **PASS** | `04_f1_combat.png` (wolf HP dropping, hit log) |
| F1 victory | **PASS** | `05_f1_victory.png` |
| Hub return | **PASS** | (click path) |
| Next floor | **PASS** | `06_next_floor.png` |
| F5 mid-boss | **PASS** | `07_f5_boss.png` |
| F10 final boss (wolf sprite OK) | **PASS** | `08_f10_boss.png` |
| Final clear hub | **PASS** | `09_final_victory.png` |
| Return town | **PASS** | `10_return_town.png` (bonus) |

Video (artifacts): `/opt/cursor/artifacts/post-merge-verification/post_merge_click_path_title_to_f10.webm`

---

## 4. PR #9 regression focus

| Item | Result |
|------|--------|
| Monster `preferred_radius` ≤ `attack_range` / repeat attacks | **PASS** (suite + F1 log shows monster→ally damage) |
| Mage soft-lock / fireball loop | **PASS** (`validate_combat_ai` mage started/fired/hits) |
| Korean fonts | **PASS** (suite + UI stills + Pages title) |
| Revive `was_dead` before reset | **PASS** (suite revive 35% / +15%) |
| Direction travel | **PASS** (`validate_direction_travel`) |
| Dungeon floor / victory | **PASS** (click path F1–F10) |
| F5 / F10 bosses | **PASS** |
| Combat UI vs floor-list overlay | **PASS with note** — floor list sits top-left over field (pre-existing; not blocking) |

---

## 5. Automation (merged main)

| Suite | Result | Residual log noise |
|-------|--------|--------------------|
| validate_combat_ai | **PASS** 11/0 | ObjectDB + 2 resources — **still present** |
| validate_direction_travel | **PASS** 13/0 | ObjectDB + 1 resource — **still present** |
| validate_korean_font | **PASS** 16/0 | — |
| validate_hunt_maze | **PASS** 22/0 | — |
| validate_dungeon | **OK** | ObjectDB + 1 resource; headless SKIP capture |
| Web Export | **PASS** | `savepack: end` |

ObjectDB noise = Autoload AudioManager SFX held at `-s` quit (analysis unchanged; not treated as gameplay fail).

---

## 6. Screenshots checklist

| File | Present |
|------|---------|
| `01_title.png` … `09_final_victory.png` | **PASS** |
| `10_web_pages.png` | **PASS** |
| `10_return_town.png` | bonus |

---

## 7. Fixes this pass

| File | Why |
|------|-----|
| `scripts/core/audio_manager.gd` | During click-path, `_apply_stream` threw `Cannot call method 'duplicate' on a null value` when BGM `load()` returned null (import race / missing stream). Added null-safe load/duplicate guards + warning. **Minimal; no playlist/behavior change when assets load.** |

F10 wolf art: **not changed** (approved placeholder).

---

## 8. NOT VERIFIED

- Full in-browser dungeon climb on Pages (beyond title)  
- Real mobile device  
- Direction-pad UX on live Pages build  

---

## 9. Remaining warnings

- ObjectDB / resources-at-exit on headless `-s` validators (expected)  
- Combat floor-list overlay on battlefield (cosmetic)  
- F10 wolf sprite (accepted)  
- ALSA missing in CI/agent VM → dummy audio driver  

---

## 10. Conclusion

Merged main `0da5e2b` is **deployed to Pages** and **playable** through title→F10 clear in graphic Godot. Automation green. One defensive audio null-guard landed on this verification branch for push.

**Recommendation:** merge this small verification/fix branch when ready; product main already contains PR #9.
