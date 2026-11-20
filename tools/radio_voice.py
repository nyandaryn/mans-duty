#!/usr/bin/env python3
"""Commander's radio commands for the great assault: Ukrainian TTS through a
field-radio chain, written to source/assets/audio/radio_voice/<id>.ogg.

Voice: Piper (https://github.com/OHF-Voice/piper1-gpl) with the voice
uk_UA-ukrainian_tts-medium, speaker «mykyta» (dataset CC0). The output audio
is ours; the model is not shipped with the game.

Radio chain (sox): the voice is resampled through 8 kHz, band-limited to
350-3000 Hz, compressed and slightly overdriven; a carrier hiss runs under it.
Before it: the click of the press-to-talk switch and the squelch opening
burst; after it: the squelch tail when the transmitter drops.

Setup once (Python 3.12, the voice is ~77 MB):
  uv venv -p 3.12 .build/tts/venv
  VIRTUAL_ENV=.build/tts/venv uv pip install piper-tts
  .build/tts/venv/bin/python -m piper.download_voices --data-dir .build/tts/voices uk_UA-ukrainian_tts-medium
Run from the repository root:
  .build/tts/venv/bin/python tools/radio_voice.py [id ...]
Then import in Godot (godot --headless --path source --import).

The TTS text is lower case (the voice has no capital letters in its
alphabet: a capital is dropped), stress is the combining acute U+0301, and
abbreviations are spelled out («бе-ем-пе» for БМП). The subtitles shown in
the game are in scripts/radio_voice.gd.
"""
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VOICE = os.path.join(ROOT, ".build/tts/voices/uk_UA-ukrainian_tts-medium.onnx")
SPEAKER = "1"  # mykyta
OUT = os.path.join(ROOT, "source/assets/audio/radio_voice")
RATE = 22050

LINES = {
    "hold": "ува́га всім! стої́мо на мі́сці, чека́ємо робо́ту гра́дів.",
    "grad_fire": "гра́ди, вого́нь!",
    "mount_up": "по маши́нах!",
    "column": "коло́на — впере́д!",
    "dismount": "деса́нт, до маши́ни!",
    "file": "за бе-ем-пе́, коло́ною по одному́!",
    "assault": "відді́лення — на штурм! ро́зсипом, впере́д!",
    "mount": "по місцях!",
    "strongpoint": "опо́рний пункт зни́щено! впере́д, до насту́пного!",
    "cleared": "село́ зачи́щено! закріпи́тися!",
}


def run(args, **kw):
    subprocess.run(args, check=True, **kw)


def speak(text: str, path: str) -> None:
    run([sys.executable, "-m", "piper", "-m", VOICE, "-s", SPEAKER,
         "--length-scale", "1.05", "-f", path], input=text.encode(),
        stderr=subprocess.DEVNULL)


def duration(path: str) -> float:
    return float(subprocess.run(["soxi", "-D", path], check=True,
                                capture_output=True, text=True).stdout)


def transmission(raw: str, out: str, work: str) -> None:
    fmt = ["-r", str(RATE), "-c", "1", "-b", "16"]
    voice = os.path.join(work, "voice.wav")
    # Narrow band, a codec's 8 kHz, compressed and slightly driven.
    run(["sox", raw, *fmt, voice, "gain", "-6", "rate", "8000", "rate", str(RATE),
         "highpass", "350", "highpass", "350", "lowpass", "3000", "lowpass", "3000",
         "compand", "0.005,0.12", "6:-60,-60,-34,-14,0,-6", "-4", "-60", "0.02",
         "overdrive", "6", "8", "gain", "-n", "-2", "pad", "0.05", "0.08"])
    length = duration(voice)
    hiss = os.path.join(work, "hiss.wav")
    run(["sox", "-n", *fmt, hiss, "synth", f"{length:.3f}", "pinknoise",
         "highpass", "400", "lowpass", "3200", "gain", "-n", "-31"])
    body = os.path.join(work, "body.wav")
    run(["sox", "-m", voice, hiss, *fmt, body])
    # Key-up: the click of the switch, then the squelch opening.
    click = os.path.join(work, "click.wav")
    run(["sox", "-n", *fmt, click, "synth", "0.012", "square", "1400", "gain", "-6",
         "lowpass", "4000", "fade", "0", "0.012", "0.009", "gain", "-n", "-5"])
    burst = os.path.join(work, "burst.wav")
    run(["sox", "-n", *fmt, burst, "synth", "0.16", "whitenoise",
         "band", "1900", "1400", "fade", "0.004", "0.16", "0.07", "gain", "-n", "-9"])
    # Key-down: the receiver's squelch tail.
    tail = os.path.join(work, "tail.wav")
    run(["sox", "-n", *fmt, tail, "synth", "0.20", "whitenoise",
         "band", "2100", "1600", "fade", "0.002", "0.20", "0.14", "gain", "-n", "-8"])
    gap = os.path.join(work, "gap.wav")
    run(["sox", "-n", *fmt, gap, "trim", "0", "0.03"])
    run(["sox", click, gap, burst, body, tail, "-C", "4", out])


def main() -> None:
    if not os.path.exists(VOICE):
        sys.exit("No voice model: see the setup in the header of this script.")
    os.makedirs(OUT, exist_ok=True)
    ids = sys.argv[1:] or list(LINES)
    with tempfile.TemporaryDirectory() as work:
        for key in ids:
            raw = os.path.join(work, key + ".raw.wav")
            speak(LINES[key], raw)
            out = os.path.join(OUT, key + ".ogg")
            transmission(raw, out, work)
            print(f"{key}: {duration(out):.2f} s -> {os.path.relpath(out, ROOT)}")


if __name__ == "__main__":
    main()
