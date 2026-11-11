# Audio sources — Квартал 0.2

All redistributed recordings below are published under **CC0 1.0**:
https://creativecommons.org/publicdomain/zero/1.0/

## Gunshots

**The Free Firearm Sound Library — Ben Jaszczak et al.**
Original publication and license: https://opengameart.org/content/the-free-firearm-sound-library
Download mirror: https://github.com/petroulacl/fps-asset-kit/tree/main/sfx/firearm_sfx

| In-game file | Source recording | Usage |
|---|---|---|
| `audio/ak74.wav` | AK-47 / C_27P.wav | Acoustic stand-in for AK-74, NOT an AK-74 recording |
| `audio/m16.wav` | AR-15 / D_24P.wav | Related-platform stand-in for M16A2 |
| `audio/pm.wav` | Bersa / F_41P.wav | Pistol stand-in, NOT a PM recording |
| `audio/m9.wav` | Walther PPQ / X_31P.wav | Pistol stand-in, NOT an M9 recording |

These are recorded firearm sounds, not synthesized gunshots. Exact model, microphone location and ammunition differ from the in-game weapons. For AK-47, the last shot of the first recorded burst was isolated (source offset 1.085 s), so one game shot never triggers a recorded burst. Each sample was converted from 24-bit stereo to 16-bit mono 44.1 kHz, trimmed to one onset and up to 2.4 seconds of decay, high-pass filtered at 55 Hz, gain-adjusted with headroom, and faded over its final 120 ms. The runtime uses spatial distance attenuation for bots and small (±1%) pitch variation. This is not a physical acoustic simulator.

## Magazine and bolt handling

**Gun Reload Sound Effects — BMacZero / Brian MacIntosh**
https://opengameart.org/content/gun-reload-sound-effects

- `audio/mag_in.wav` from `clipload1.wav`.
- `audio/mag_out.wav` from `clipload2.wav`.
- `audio/bolt.wav` from `singlebullet1.wav`.

**Gun reload sounds — SpringySpringo**
https://opengameart.org/content/gun-reload-sounds

- `audio/bolt_pull.wav` from the initial handling of `assaultriflereload1_0.wav`. This source was recorded with an airsoft gun; it is not a recording of an actual AK-74/M16 mechanism.

Handling files were converted to mono 44.1 kHz PCM, trimmed, high-pass filtered, gain-adjusted and faded. They play at specific animation events. UI clicks and impact thumps remain procedural.

`audio-sources.json` records the retrieved source URLs and mirror blob hashes, and `audio-processing.json` records trim times. No attribution is required by CC0; these notices preserve provenance and distinguish exact recordings from substitutes.

## Wounded voices

HaelDB — Male Grunt/Yelling sounds: https://opengameart.org/content/male-gruntyelling-sounds
Redistributed under the offered **CC0 1.0** license. Download: https://opengameart.org/sites/default/files/yelling%20sounds.zip
`pain_1/2.wav` use `3grunt1/2.wav`; `pain_3/4.wav` use `3yell3/4.wav`. Leading silence removed, high-pass 90 Hz, loudness normalized to -19 LUFS with -3 dBTP ceiling, mono PCM 44.1 kHz, maximum 1.9 seconds and tail fade.
Temporary tinnitus is a low-level procedural two-tone loop, not a medical simulation.
