"""Builds Dino Duel's own battle sounds from synthesis plus a few CC0 Kenney impacts.

    python tools/synth_sfx.py <output folder>

Writes WAVs (bite_1..3, brace_1..2, charge_1..3) into the folder; put them in the game with
tools/prepare_sfx.py. Everything here is original or CC0 (tools/sfx_sources/KENNEY_LICENSE.txt),
so the results can ship. Each sound is a few layers, described in its function.

Timing contract with ui/battle/battle_screen.gd: bite and brace are hits that start at 0 s;
charge starts when the attacker lunges and its big impact lands at CHARGE_HIT_S.
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
from scipy import signal

SR = 44100
SOURCES = Path(__file__).resolve().parent / "sfx_sources"
CHARGE_HIT_S = 0.27


def seconds(n: int) -> np.ndarray:
    return np.arange(n) / SR


def load(name: str) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", str(SOURCES / name), "-f", "f32le", "-ac", "1",
                          "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def band(x: np.ndarray, lo: float, hi: float, order: int = 4) -> np.ndarray:
    sos = signal.butter(order, [lo, min(hi, SR / 2 - 100)], "bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lowpass(x: np.ndarray, hz: float, order: int = 4) -> np.ndarray:
    return signal.sosfilt(signal.butter(order, hz, "lowpass", fs=SR, output="sos"), x)


def place(out: np.ndarray, sound: np.ndarray, at_s: float, gain: float = 1.0, pan: float = 0.0) -> None:
    """Mixes a mono sound into the stereo buffer at a time, with equal-power panning (-1..1)."""
    start = int(at_s * SR)
    end = min(len(out), start + len(sound))
    if end <= start:
        return
    left, right = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    out[start:end, 0] += sound[:end - start] * gain * left * np.sqrt(2)
    out[start:end, 1] += sound[:end - start] * gain * right * np.sqrt(2)


def sweep(f_start: float, f_end: float, length_s: float, decay_s: float) -> np.ndarray:
    """A sine gliding exponentially in pitch with an exponential fade: thumps and booms."""
    n = int(length_s * SR)
    t = seconds(n)
    freq = f_start * (f_end / f_start) ** (t / length_s)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    return np.sin(phase) * np.exp(-t / decay_s) * np.minimum(1, t / 0.002)


def bell(f0: float, length_s: float, detune_cents: float = 0.0) -> np.ndarray:
    """A bright glassy 'ting': inharmonic partials, the higher ones dying faster."""
    n = int(length_s * SR)
    t = seconds(n)
    ratio = 2 ** (detune_cents / 1200)
    partials = [(1.0, 1.0, 0.32), (2.0, 0.45, 0.24), (2.76, 0.35, 0.18), (3.9, 0.22, 0.12),
                (5.4, 0.14, 0.08), (6.8, 0.08, 0.05)]
    tone = sum(a * np.sin(2 * np.pi * f0 * ratio * r * t) * np.exp(-t / d) for r, a, d in partials)
    release = np.clip((length_s - t) / (length_s * 0.4), 0, 1)
    return tone * np.minimum(1, t / 0.0015) * release


def finish(out: np.ndarray) -> np.ndarray:
    """Soft-clips, fades the tail, and normalises the peak."""
    out = np.tanh(out * 1.2) / np.tanh(1.2)
    fade = int(0.02 * SR)
    out[-fade:] *= np.linspace(1, 0, fade)[:, None]
    return out / (np.abs(out).max() + 1e-9) * 0.9


# --- Bite: two quick jaw snaps, then a crunch with some weight -----------------------------------

def bite(seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    out = np.zeros((int(0.42 * SR), 2))
    second = 0.07 + rng.uniform(-0.01, 0.015)
    for at, gain in [(0.0, 0.55), (second, 1.0)]:
        # The snap: a hard, bright click (teeth meeting) over a short woody tock.
        n = int(0.014 * SR)
        click = band(rng.normal(size=n), 1800, 9000) * np.exp(-seconds(n) / 0.0022)
        place(out, click, at, 1.4 * gain, rng.uniform(-0.2, 0.2))
        place(out, sweep(230 + rng.uniform(-30, 30), 150, 0.07, 0.022), at, 0.7 * gain)
    # The crunch: a burst of tiny cracks right after the second snap, thinning out.
    for i in range(24):
        at = second + 0.008 + rng.exponential(0.045)
        n = int(rng.uniform(0.002, 0.006) * SR)
        grain = band(rng.normal(size=n), 900, 5200) * np.hanning(n)
        place(out, grain, at, rng.uniform(0.25, 0.75) * np.exp(-(at - second) / 0.09), rng.uniform(-0.5, 0.5))
    # Weight: a CC0 punch and a low thump under the second snap.
    punch = load(f"impactPunch_medium_00{seed % 3}.ogg")
    place(out, lowpass(punch, 2500), second, 0.55)
    place(out, sweep(130, 50, 0.18, 0.06), second, 0.8)
    return finish(out)


# --- Brace: a shimmering barrier rushing up and snapping into place ------------------------------

def brace(seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    rise = 0.26
    out = np.zeros((int(1.0 * SR), 2))
    n = int(rise * SR)
    t = seconds(n)
    # Whoosh: noise through a band that sweeps upward, swelling until the snap.
    noise = rng.normal(size=n)
    f, frames, spec = signal.stft(noise, SR, nperseg=1024, noverlap=768)
    centre = 600 * (6500 / 600) ** (frames / rise)
    weights = np.exp(-0.5 * (np.log2(f[:, None] + 1) - np.log2(centre[None, :])) ** 2 / 0.35 ** 2)
    whoosh = signal.istft(spec * weights, SR, nperseg=1024, noverlap=768)[1][:n]
    whoosh *= (t / rise) ** 2
    place(out, whoosh / (np.abs(whoosh).max() + 1e-9), 0.0, 0.55, -0.15)
    # Shimmer: a gliding cluster of bright tones with a fast tremolo, like energy gathering.
    base = 650 * (1350 / 650) ** (t / rise)
    phase = 2 * np.pi * np.cumsum(base) / SR
    shimmer = sum(a * np.sin(phase * r) for r, a in [(1, 1.0), (1.5, 0.6), (2.01, 0.45), (3.0, 0.25)])
    shimmer *= (t / rise) ** 1.5 * (0.75 + 0.25 * np.sin(2 * np.pi * 19 * t))
    place(out, shimmer / np.abs(shimmer).max(), 0.0, 0.35, 0.15)
    # The snap into place: a glassy ting (slightly detuned left/right for width) and a soft thud.
    f0 = 1568 * 2 ** (rng.uniform(-1, 1) / 12)
    ting_l, ting_r = bell(f0, 0.7, -4), bell(f0, 0.7, 4)
    start = int(rise * SR)
    out[start:start + len(ting_l), 0] += ting_l * 0.55
    out[start:start + len(ting_r), 1] += ting_r * 0.55
    place(out, load("impactGlass_light_001.ogg"), rise, 0.35)
    place(out, sweep(160, 80, 0.12, 0.04), rise, 0.5)
    return finish(out)


# --- Charge: a roar building into pounding steps and a huge slam ---------------------------------

def roar(rng: np.random.Generator, length_s: float) -> np.ndarray:
    """A guttural roar: a low buzzy voice with a rough sub-octave and a fast growl flutter, shaped
    by throat-like resonances."""
    n = int(length_s * SR)
    t = seconds(n)
    wobble = np.cumsum(rng.normal(0, 0.003, n))
    wobble -= np.linspace(0, wobble[-1], n)
    f0 = (68 + 30 * (t / length_s)) * (1 + 0.05 * np.sin(2 * np.pi * 6 * t) + wobble)
    phase = np.cumsum(f0) / SR
    voice = (2 * (phase % 1) - 1) + 0.6 * (2 * ((phase / 2) % 1) - 1)
    voice *= 1 + 0.55 * np.sin(2 * np.pi * 27 * t + rng.uniform(0, 6))
    voice += 0.15 * rng.normal(size=n)
    throat = sum(g * band(voice, lo, hi, 2) for lo, hi, g in [(380, 720, 1.0), (900, 1400, 0.55), (2000, 2800, 0.2)])
    throat += 0.8 * lowpass(voice, 300)
    env = np.minimum(1, t / (length_s * 0.4)) * np.minimum(1, (length_s - t) / 0.12)
    return np.tanh(1.8 * throat / (np.abs(throat).max() + 1e-9)) * env


def charge(seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    out = np.zeros((int(1.15 * SR), 2))
    place(out, roar(rng, 0.62), 0.0, 0.5, rng.uniform(-0.2, 0.2))
    # Pounding footfalls speeding up into the hit.
    for at, gain in [(0.04, 0.45), (0.13, 0.6), (0.2, 0.75)]:
        place(out, sweep(95, 42, 0.16, 0.05), at, gain)
        n = int(0.02 * SR)
        place(out, lowpass(rng.normal(size=n), 900) * np.exp(-seconds(n) / 0.006), at, gain * 0.8)
    # The slam: a CC0 heavy punch, a sub boom and a crash of debris.
    hit = CHARGE_HIT_S
    place(out, load(f"impactPunch_heavy_00{seed % 3}.ogg"), hit, 0.9)
    place(out, sweep(75, 30, 0.7, 0.22), hit, 1.1)
    n = int(0.5 * SR)
    crash = lowpass(rng.normal(size=n), 2200) * np.exp(-seconds(n) / 0.11)
    place(out, crash, hit, 0.45, rng.uniform(-0.3, 0.3))
    return finish(out)


def write(audio: np.ndarray, path: Path) -> None:
    subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-f", "f64le", "-ar", str(SR), "-ac", "2", "-i", "-", str(path)],
                   input=audio.astype(np.float64).tobytes(), check=True)


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out_dir = Path(sys.argv[1])
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, make, seeds in [("bite", bite, [1, 2, 3]), ("brace", brace, [1, 2]), ("charge", charge, [1, 2, 3])]:
        for i, seed in enumerate(seeds, 1):
            path = out_dir / f"{name}_{i}.wav"
            write(make(seed), path)
            print("wrote", path)


if __name__ == "__main__":
    main()
