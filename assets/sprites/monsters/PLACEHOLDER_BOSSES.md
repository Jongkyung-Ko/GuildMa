# Boss / elite art placeholders

`3020.jpg` (boss concept sheet) was **not available** when this content shipped.

Until real splits are imported:

| Boss | Runtime sprite fallback | Tint |
|---|---|---|
| Fenrir | `wolf` | blue |
| Malkav | `goblin` | purple |
| Malachi | `goblin` | gold |
| Gorgon | `slime` | green |
| Lilith | `wolf` | crimson |
| Bone Golem | `goblin` | bone |
| Behemoth | `wolf` | brown |
| Vorak | `slime` | blue-void |
| Morgana | `goblin` | violet |

Elites / new normals (`boar`, `skeleton`, `wraith`, `demonling`) also reuse wolf/goblin/slime frames with tints (`placeholder_art: true` in `enemies.json` / `bosses.json`).

Do **not** claim painted boss animations exist until `3020.jpg` (or dedicated frames) are wired under `assets/sprites/monsters/<boss_id>/`.
