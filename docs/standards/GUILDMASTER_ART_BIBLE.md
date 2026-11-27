# GuildMaster Art Bible

Canonical art direction for agents. Settled facts come from GDD §15, `docs/art/STYLE_GUIDE.md`, `docs/art/QUALITY_DIAGNOSIS.md`, `project.godot`, and `scripts/ui/ui_style.gd`. Anything not settled is marked **UNDECIDED** (also mirrored in the decision log).

## Global direction (settled)

- Modern high-quality **2D** fantasy for a premium indie **PC** RPG.
- World cohesion: guild town = warm daylight, blue roofs; hunt/combat = cooler forest.
- Prefer painted / detailed sprites over primitive shapes. **Do not ship ColorRect / emoji / plain colored squares as final characters, buildings, or item icons.**
- Base design resolution: **1280×720**. Texture filter: **Nearest** (`project.godot`).
- Korean UI: embedded **Noto Sans KR** Regular/Bold OTF — no OS font reliance.
- UI chrome palette (from `UIStyle`): navy panels + gold accents (`GOLD` / `GOLD_BRIGHT`), warm off-white text.

## Technical gates (settled for item/icon automation)

| Rule | Value |
|---|---|
| Min icon resolution | **≥ 256×256** |
| Goal for new core/hero icons | **≥ 512×512** |
| Format | Transparent **PNG** (RGBA preferred) |
| UI readability | Silhouette readable at **~64×64** |
| Uniqueness | Unrelated items must not share identical-byte icons unless explicitly shared-asset |

Automation: `tools/validate_quality_assets.py`. Style approval is **never** automatic-only.

## By asset class

### Items / weapons / armor / accessories / consumables / materials

- Illustrated icons under `assets/items/` (runtime). Data maps via `data/items.json` → `icon` (`res://…`).
- Rarity framing in UI may use border colors (shop system); keep icon art itself style-consistent.
- No undeclared placeholders for APPROVED / Q4+ claims.
- **UNDECIDED:** exact rarity border hex beyond current UI code; mandatory 512px for every legacy icon (legacy 256 is acceptable until a batch upscale is approved).

### Characters (lord + jobs)

| Job | Folder / notes (settled mapping) |
|---|---|
| Guild Master / Lord | `assets/sprites/characters/lord` — crown, red cape, lion shield |
| Tank | `tank` — silver knight |
| DPS | `dps` — dual daggers |
| Healer | `healer` — staff, white/green robes |
| Mage | `mage` — wizard hat, orb staff |

- Animation convention (sheets): frames **0–3** idle/walk, **4–7** attack.
- Combat actor height guide ≈ **56px** (style guide).
- Portraits exist under `assets/sprites/characters/portrait_*.png` — treat low-quality portraits as upgrade candidates per `QUALITY_DIAGNOSIS.md`, not as Q5 finals without review.

### Monsters

- Runtime folders under `assets/sprites/monsters/` (e.g. wolf / slime / goblin as available).
- Sheet convention: typically **6 frames** where sliced sheets exist.
- **UNDECIDED:** final monster roster beyond currently shipped species; boss-only silhouette bible.

### NPCs

- Facility NPCs appear in shop/blacksmith/etc. UIs.
- **UNDECIDED:** dedicated NPC sprite sheet standard sizes and idle cycles (not locked in GDD).

### Buildings / town props

- Town building sprites: `assets/sprites/buildings/*`.
- Building height guide ≈ **130–160px** (style guide).
- Replace geometric prototypes when upgrading; do not mix unrelated styles in one scene.

### Backgrounds / interiors

- Runtime: `assets/backgrounds/*` (title, town, combat, facility interiors, hunt select).
- Prefer cohesive painted environments matching warm-town / cool-hunt split.
- Concept references may live under `02_Assets/` and `assets/art_reference/` — **do not** use raw reference sheets as whole-scene game backgrounds without intentional adaptation.

### Skill / combat VFX

- Runtime folder: `assets/sprites/vfx/`.
- Slash / hit / magic / heal sets are expected for combat readability.
- **UNDECIDED:** exact frame counts and blend modes for each VFX family.

### UI chrome

- Panels/buttons: `assets/ui/*` + `UIStyle` StyleBoxes.
- Gold-frame / navy panel language; readable Hangul at default 16px theme size.
- Guild Hall and facility layouts follow landscape rules — see `guild-hall-landscape.mdc`.

## Do not

- Claim procedural / Pillow / shape placeholders as finished art.
- Mix unrelated art styles in one scene.
- Rely on OS fonts.
- Treat “asset file exists” as visual APPROVED.

## Related

- Quality grades: `GUILDMASTER_QUALITY_STANDARD.md`
- Older diagnosis snapshot: `docs/art/QUALITY_DIAGNOSIS.md`
- Short style guide: `docs/art/STYLE_GUIDE.md`
