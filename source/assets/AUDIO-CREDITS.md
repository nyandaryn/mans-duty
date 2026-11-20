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
| SVD runtime alias of `audio/ak74.wav` | Same AK-47 single shot | Temporary acoustic stand-in, NOT an SVD recording |
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

## Tactical callout

`audio/cover.wav`: Ukrainian "Крию!", locally synthesized using eSpeak NG's
Ukrainian voice (`espeak-ng -v uk -s 190 -p 38 -a 180`), high-pass/low-pass,
compressed and loudness-normalized to mono 44.1 kHz PCM. Synthetic placeholder,
not a recording of a soldier or an actor. No real person's voice was cloned.
Generator: https://github.com/espeak-ng/espeak-ng (GPL-3.0 software; executable
is not bundled). Generated speech output is supplied as a project audio asset.

## BM-21 «Grad» (0.21)

Real recordings of BM-21 launchers. Two of the three sources are **CC BY 4.0**
and require the attribution below; the DVIDS footage is a US government work
in the **public domain**. The clips were cut from the soundtracks of the
videos, converted to mono 16-bit PCM 44.1 kHz, high-pass filtered and faded;
nothing was synthesized into them. No speech or music is in the cut ranges.

| In-game file | Source | Range | License and author |
|---|---|---|---|
| `audio/grad/launch_close.wav` | DVIDS 516356 «JMTG-U Ukrainian BM-21 Rocket Launcher B-Roll» — https://www.dvidshub.net/video/516356/jmtg-u-ukrainian-bm-21-rocket-launcher-b-roll | 9.25–13.25 s, +4 dB, fade-out | Public domain (https://www.dvidshub.net/about/copyright). Kayla Christopher, 45th IBCT, Oklahoma Army National Guard; Ukrainian BM-21 on the Ural-375D, Yavoriv, 2017-03-29 |
| `audio/grad/launch_tail.wav` | same DVIDS video | 9.25–19.45 s | same |
| `audio/grad/launch_far.wav` | Wikimedia Commons «Ukr bm-21 hrad firing.webm» — https://commons.wikimedia.org/wiki/File:Ukr_bm-21_hrad_firing.webm | 12.02–14.74 s | **CC BY 4.0** — Operational Command West, Armed Forces of Ukraine (156th Mechanized Brigade), 2025-04-14 |
| `audio/grad/engine_idle.wav` | Wikimedia Commons «BM-21-1 Grad MLRS.webm» — https://commons.wikimedia.org/wiki/File:BM-21-1_Grad_MLRS.webm | 20.30–24.95 s, crossfaded loop | **CC BY 4.0** — Ministry of Defence of the Russian Federation, 2020-02-17 |

CC BY 4.0: https://creativecommons.org/licenses/by/4.0/ — changes: cut,
mono, filtered, faded, looped. Attribution is not an endorsement by the
authors. The engine loop is a real Grad engine, but of a BM-21-1 on the
Ural-4320 diesel chassis, not the petrol ZIL-375 of the Ural-375D modelled in
the game; its pitch follows the simulated crankshaft. The starter, gear grind,
air valve and the distant burst thump are procedural.

## BM-21 cab receiver

| In-game file | Source | Usage | License |
|---|---|---|---|
| `audio/radio/zalizna_zgraya.mp3` | «Залізна зграя», supplied by the project owner on 2026-11-18 (file `Залізна_зграя.mp3`, MP3 192 kbit/s, 71 s) | Played unchanged by the receiver on the BM-21 dashboard (R) | Published with the game by permission of the project owner (confirmed 2026-11-18) |
| `audio/radio/radio_200.mp3` | «200», supplied by the project owner on 2026-11-19 (file `200.mp3`, MP3 126 kbit/s, 48 kHz, 2:37, no title tag) | Played unchanged by the receiver of the BMP-2 driver (R) | Published with the game by permission of the project owner (confirmed 2026-11-19) |

## BMP-2 engine (0.26)

| In-game file | Source | Range | License and author |
|---|---|---|---|
| `audio/bmp/engine.wav` | DVIDS 589068 «Section Blank Fire» — https://www.dvidshub.net/video/589068/section-blank-fire | 468.00–473.96 s (crossfade material to 474.76 s), crossfaded 0.8 s loop | Public domain (https://www.dvidshub.net/about/copyright). 1st Lt. Derrick Garner, New York Army National Guard, Yavoriv, 2018-03-09; a Ukrainian BMP-1 of the 3-14th Mechanized Brigade, camera mounted on the moving vehicle |

The appearance of U.S. Department of War (DoW) visual information does not
imply or constitute DoW endorsement. The recording is the UTD-20 diesel of a
BMP-1, the same engine as in the BMP-2, at a steady ≈1190 rpm: high-passed at
30 Hz, resampled to mono 44.1 kHz 16-bit, normalized to −3 dBFS. Its pitch
follows the simulated crankshaft (smoothed like the flywheel). No recording
of the starter was found: while cranking the same loop plays slowed down.

## Commander's radio orders (great assault)

| In-game files | Source | License |
|---|---|---|
| `audio/radio_voice/*.ogg` (10 orders: `hold`, `grad_fire`, `mount_up`, `column`, `dismount`, `file`, `assault`, `mount`, `strongpoint`, `cleared`) | Synthesized for the game with **Piper** TTS (https://github.com/OHF-Voice/piper1-gpl, `piper-tts`), voice `uk_UA-ukrainian_tts-medium` (https://huggingface.co/rhasspy/piper-voices/tree/main/uk/uk_UA/ukrainian_tts/medium), speaker 1 «mykyta» | Voice dataset **CC0** (https://github.com/OHF-Voice/voice-datasets, per the voice's model card). The engine and the model are not shipped with the game; only the generated recordings are |

Generated by `tools/radio_voice.py` (the texts and the whole chain are in the
script). The voice is passed through a field-radio chain with sox: −6 dB,
resampled through 8 kHz, high-passed at 350 Hz and low-passed at 3 kHz (two
poles each), compressed, slightly overdriven, with a carrier hiss (pink noise
−31 dB). Each transmission starts with a press-to-talk click (12 ms 1.4 kHz
square) and a squelch burst (0.16 s of band-limited noise at 1.9 kHz) and
ends with a squelch tail (0.20 s). Mono OGG Vorbis 22.05 kHz.

The tablet's speaker in the great assault replays `audio/grad/launch_close.wav`,
`audio/grad/launch_tail.wav` and `audio/grad/engine_idle.wav` (above) through
an in-game filter (high-pass 380 Hz, low-pass 4.3 kHz, overdrive, compressor);
no new recordings.
