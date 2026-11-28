# GuildMaster Fenrir Animation Pack

## Included
- Fenrir attack: 4 frames
- Fenrir hit: 4 frames
- Fenrir death: 4 frames
- Each frame: 512x512 RGBA PNG
- Original generated sprite sheet for reference

## Suggested project destination
`assets/sprites/monsters/bosses/fenrir/`

## Integration
Use `SpriteFactory` to build SpriteFrames from these sequences.
Keep existing `idle.png` as the idle animation.
Suggested timing:
- attack: 8 FPS, non-looping
- hit: 10 FPS, non-looping
- death: 6 FPS, non-looping

Do not change boss stats, skills, phase thresholds, rewards, or HUD.
Ensure the actual attack hit/damage timing is synchronized with the attack frame.
Death reward must still be granted exactly once after the death animation completes or a safe timeout occurs.

## Important visual QA
The source sheet was generated with a checkerboard-like background. The exported frames have an automated near-neutral background removal pass.
Inspect alpha edges, especially pale ice highlights, before treating this pack as final art.
