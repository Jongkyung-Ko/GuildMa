# GuildMaster audio

## Layout

- `sfx/` — WAV one-shots / loops from SFX Pack v1
- `bgm/` — source `.mid` (MIDI Pack v2) **and** playback `.ogg` renders

## MIDI note

Godot 4.3 (and the HTML5 export) has **no built-in General MIDI synthesizer**.
Shipping a SoundFont + GDExtension is unreliable on web without COOP/COEP.

So BGM is:

1. Keep the authored `.mid` files in-repo as the source of truth.
2. Offline-render them with FluidSynth + FluidR3_GM to loopable `.ogg`.
3. `AudioManager` plays the `.ogg` streams (looping).

Re-render (dev machine):

```bash
SF=/usr/share/sounds/sf2/FluidR3_GM.sf2
fluidsynth -ni "$SF" 01_town_theme.mid -F /tmp/01_town_theme.wav -r 44100
ffmpeg -y -i /tmp/01_town_theme.wav -c:a libvorbis -q:a 5 01_town_theme.ogg
```
