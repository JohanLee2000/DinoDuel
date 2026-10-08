"""Put a sound effect into the game: trims silence, evens out the volume, converts to .ogg.

Usage:
    python tools/prepare_sfx.py <input file> <sound name>          replace that sound
    python tools/prepare_sfx.py <input file> <sound name> --add    add another variant

<sound name> is a name from app/sound.gd SOUNDS (see docs/SFX_BRIEF.md), e.g. tap, bite, glow.
Replacing writes assets/audio/sfx/<name>.ogg and removes the old variants. --add keeps the old
ones and writes <name>_2.ogg, <name>_3.ogg, ... (the game picks a variant at random). Every file
is levelled to the same loudness, so the per-sound volumes in app/sound.gd stay right. Godot
imports the new file the next time the editor opens or a build runs.

Requires ffmpeg on PATH and numpy. Any input format ffmpeg reads works (.wav, .mp3, .ogg, ...).
"""
import re
import subprocess
import sys
from pathlib import Path

import numpy as np

SFX = Path(__file__).resolve().parent.parent / "assets" / "audio" / "sfx"
SOUND_GD = Path(__file__).resolve().parent.parent / "app" / "sound.gd"
SR = 44100
SILENCE_DB = -50.0
## Every file's loudest 50 ms is levelled to this; app/sound.gd sets each sound's volume from here.
TARGET_DB = -9.0
PEAK_LIMIT_DB = -1.0
PAD_S = 0.01


def known_sounds() -> set[str]:
    return set(re.findall(r'&"([a-z_]+)": -?\d', SOUND_GD.read_text(encoding="utf-8")))


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", str(path), "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def prepare(audio: np.ndarray) -> np.ndarray:
    mono = np.abs(audio).max(axis=1)
    loud = np.where(mono > 10 ** (SILENCE_DB / 20))[0]
    if len(loud) == 0:
        sys.exit("That file is silent.")
    pad = int(PAD_S * SR)
    audio = audio[max(0, loud[0] - pad):loud[-1] + pad]
    n = int(0.05 * SR)
    mix = audio.mean(axis=1)
    windows = [mix[i:i + n] for i in range(0, max(1, len(mix) - n + 1), n // 4)] or [mix]
    loudest = max(float(np.sqrt(np.mean(w ** 2))) for w in windows)
    gain_db = TARGET_DB - 20 * np.log10(loudest + 1e-12)
    peak_db = 20 * np.log10(float(np.abs(audio).max()) + 1e-12)
    gain_db = min(gain_db, PEAK_LIMIT_DB - peak_db)
    audio = audio * 10 ** (gain_db / 20)
    fade = min(len(audio), int(0.008 * SR))
    audio[-fade:] *= np.linspace(1, 0, fade)[:, None]
    print(f"  trimmed to {len(audio) / SR * 1000:.0f} ms, gain {gain_db:+.1f} dB")
    return audio


def encode(audio: np.ndarray, out: Path) -> None:
    subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "5", str(out)], input=audio.astype(np.float32).tobytes(), check=True)


def remove(path: Path) -> None:
    for p in (path, path.with_name(path.name + ".import")):
        if p.exists():
            p.unlink()


def main() -> None:
    args = [a for a in sys.argv[1:] if a != "--add"]
    if len(args) != 2:
        sys.exit(__doc__)
    source, name = Path(args[0]), args[1]
    if name not in known_sounds():
        sys.exit(f"Unknown sound '{name}'. Known: {', '.join(sorted(known_sounds()))}")
    variants = sorted(SFX.glob(f"{name}.ogg")) + sorted(SFX.glob(f"{name}_[0-9].ogg"))
    audio = prepare(decode(source))
    if "--add" in sys.argv and variants:
        single = SFX / f"{name}.ogg"
        if single.exists():
            data = single.read_bytes()
            remove(single)
            (SFX / f"{name}_1.ogg").write_bytes(data)
        number = 1
        while (SFX / f"{name}_{number}.ogg").exists():
            number += 1
        out = SFX / f"{name}_{number}.ogg"
    else:
        for old in variants:
            remove(old)
        out = SFX / f"{name}.ogg"
    encode(audio, out)
    print(f"  wrote {out.relative_to(SFX.parent.parent.parent)}")


if __name__ == "__main__":
    main()
