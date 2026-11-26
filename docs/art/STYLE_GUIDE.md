# GuildMaster Art Style Guide

## Direction
Modern high-quality 2D top-down fantasy pixel art for a premium indie PC RPG.
Cohesive world: guild town (warm daylight, blue roofs) vs hunt/combat (cooler forest).

## Technical
- Base resolution: 1280×720
- Texture filter: Nearest
- Combat actor height ≈ 56px; buildings ≈ 130–160px
- Korean UI: embedded Noto Sans KR (Regular/Bold OTF)

## Character mapping (from sliced sheets)
| Job | Folder | Notes |
|-----|--------|-------|
| Guild Master / Lord | `assets/sprites/characters/lord` | Crown, red cape, lion shield |
| Tank | `tank` | Silver knight |
| DPS | `dps` | Dual daggers |
| Healer | `healer` | Staff, white/green robes |
| Mage | `mage` | Wizard hat, orb staff |

Animation: frames 0–3 idle/walk, 4–7 attack.

## Monsters
`wolf` / `slime` / `goblin` under `assets/sprites/monsters/` — 6 frames each.

## Do not
- Ship ColorRect / primitive shapes as final characters or buildings
- Mix unrelated art styles in one scene
- Rely on OS fonts
