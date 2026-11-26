# GuildMaster audio

## Layout

- `sfx/` — WAV one-shots / loops from SFX Pack v1
- `music/` — primary player-facing BGM (MP3)
- `bgm/` — legacy MIDI/OGG pack (boss intensity still uses OGG)

## Active BGM map (`AudioManager`)

| Key | File | When |
|-----|------|------|
| `title` | `music/sovereign_of_the_keep.mp3` | Game start / title screen |
| `town` | `music/morning_dew_on_stone.mp3` | Town + facilities |
| `combat` | `music/tobitate_aoi_sora.mp3` | Normal / elite / mid combat (loops) |
| `combat_boss` | `bgm/06_combat_boss_intensity.ogg` | Final boss floors |

Web browsers require a first click/key before audio starts.

## Legacy MIDI / OGG pack

Godot 4.3 HTML5 has **no GM synth**, so older authored `.mid` files were rendered to `.ogg` under `bgm/`. Those remain for boss intensity and as source archives.

Re-render (dev machine):

```bash
SF=/usr/share/sounds/sf2/FluidR3_GM.sf2
fluidsynth -ni "$SF" 01_town_theme.mid -F /tmp/01_town_theme.wav -r 44100
ffmpeg -y -i /tmp/01_town_theme.wav -c:a libvorbis -q:a 5 01_town_theme.ogg
```
