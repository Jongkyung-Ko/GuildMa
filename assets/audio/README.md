# GuildMaster audio

## Layout

- `sfx/` — WAV one-shots / loops from SFX Pack v1
- `music/` — primary player-facing BGM (MP3)
- `bgm/` — legacy MIDI/OGG pack (elite/mid + playlist still use OGG)

## Active BGM map (`AudioManager`)

| Key | File | When |
|-----|------|------|
| `title` | `music/sovereign_of_the_keep.mp3` | Game start / title screen |
| `town` | `music/morning_dew_on_stone.mp3` | Town + facilities |
| `world_map` | `music/world_map_bgm.mp3` | World map screen |
| `hunt` / `combat` | `music/hunting_ground_bgm.mp3` | Hunt maze (`on_enter_combat` hunt path) |
| `boss` / `combat_boss` | `music/boss_battle_bgm.mp3` | Final boss intensity |
| `credits` | `music/ending_credits_bgm.mp3` | Hook only — **no credits screen yet** |
| `combat_epic` … `combat_hunting` | `bgm/03`…`02` OGG | Normal combat shuffle playlist |
| `combat_metal` / `combat_heroic` | OGG | Elite / mid-boss intensity loops |

Fade between tracks uses `FADE_SEC` (1.5s) on the single `BgmPlayer`. Town BGM is unchanged. Legacy `tobitate_aoi_sora.mp3` and `06_combat_boss_intensity.ogg` remain on disk but are no longer the active hunt/boss keys.

Normal combat still shuffles Epic → Heroic → Metal → Hunting (end-of-track fade, no consecutive repeat). Web browsers require a first click/key before audio starts.

## Legacy MIDI / OGG pack

Godot 4.3 HTML5 has **no GM synth**, so older authored `.mid` files were rendered to `.ogg` under `bgm/`. Those remain for combat intensity / playlist and as source archives.

Re-render (dev machine):

```bash
SF=/usr/share/sounds/sf2/FluidR3_GM.sf2
fluidsynth -ni "$SF" 01_town_theme.mid -F /tmp/01_town_theme.wav -r 44100
ffmpeg -y -i /tmp/01_town_theme.wav -c:a libvorbis -q:a 5 01_town_theme.ogg
```
