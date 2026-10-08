"""Turn a generated music track into a seamless loop for Godot.

Finds a cut point near the end (before the fade-out) whose lead-in sounds most like the lead-in
to some point early in the track, ends the file there with a short blend, and reports that early
point as the loop offset (the intro plays once, then the body loops). Also evens out loudness.

Usage: python tools/make_music_loop.py <in.mp3> <out.ogg> <target LUFS, e.g. -15>
Then put the printed LOOP_OFFSET into the .ogg.import file (loop=true, loop_offset=...) and reimport.
Requires ffmpeg on PATH and numpy.
"""
import subprocess
import sys

import numpy as np

SR = 44100
FEAT_SR = 22050
HOP = 1024
WINDOW_S = 3.0
BLEND_S = 0.12


def decode(path, sr, channels):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-f", "f32le", "-ac", str(channels),
                          "-ar", str(sr), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, channels)


def features(mono):
    """Log band energies per hop: a rough picture of what's playing at each moment."""
    n = 2048
    frames = np.lib.stride_tricks.sliding_window_view(mono, n)[::HOP] * np.hanning(n)
    spec = np.abs(np.fft.rfft(frames, axis=1))
    freqs = np.fft.rfftfreq(n, 1 / FEAT_SR)
    edges = np.geomspace(40, 10000, 49)
    bands = np.stack([spec[:, (freqs >= lo) & (freqs < hi)].sum(axis=1) for lo, hi in zip(edges[:-1], edges[1:])], axis=1)
    return np.log1p(bands * 10)


def main():
    src, dst, target_lufs = sys.argv[1], sys.argv[2], float(sys.argv[3])
    audio = decode(src, SR, 2).copy()
    mono = decode(src, FEAT_SR, 1)[:, 0]
    feat = features(mono)
    fps = FEAT_SR / HOP
    k = FEAT_SR // 2
    power = np.concatenate([[0.0], np.cumsum(mono.astype(np.float64) ** 2)])
    mean_power = (power[k:] - power[:-k]) / k
    level = 20 * np.log10(np.sqrt(np.maximum(mean_power, 0)) + 1e-9)
    typical = np.median(level)
    loud = np.where(level > typical - 6)[0]
    end_s = loud[-1] / FEAT_SR          # where the fade-out has gone quiet
    start_s = loud[0] / FEAT_SR
    # A quiet intro shouldn't be looped back into; start the loop where the full arrangement is in.
    body_start = np.where(level > typical - 3)[0][0] / FEAT_SR

    w = int(WINDOW_S * fps)
    def windows(lo_s, hi_s):
        idx = np.arange(max(w, int(lo_s * fps)), min(len(feat), int(hi_s * fps)))
        mats = np.stack([feat[i - w:i].ravel() for i in idx])
        mats = mats - mats.mean(axis=1, keepdims=True)
        mats /= np.linalg.norm(mats, axis=1, keepdims=True) + 1e-9
        return idx, mats

    cut_idx, cut_m = windows(end_s - 35, end_s - 2.5)
    loop_idx, loop_m = windows(max(body_start, WINDOW_S) + 1, body_start + 45)
    sim = cut_m @ loop_m.T
    # Prefer long loops: a tiny penalty for loop points far into the track.
    best = np.unravel_index(np.argmax(sim), sim.shape)
    cut_s, loop_s = cut_idx[best[0]] / fps, loop_idx[best[1]] / fps

    # Sample-accurate alignment: nudge the loop point so the waveforms line up.
    c, s = int(cut_s * SR), int(loop_s * SR)
    ref = audio[c - 4096:c, 0]
    best_d, best_v = 0, -1e9
    for d in range(-1500, 1501, 3):
        cand = audio[s + d - 4096:s + d, 0]
        v = float(np.dot(ref, cand))
        if v > best_v:
            best_d, best_v = d, v
    s += best_d

    # End the file with a short blend into what precedes the loop point, so the jump is seamless.
    blend = int(BLEND_S * SR)
    out = audio[:c].copy()
    fade = np.linspace(0, 1, blend)[:, None]
    out[c - blend:c] = audio[c - blend:c] * (1 - fade) + audio[s - blend:s] * fade

    tmp = dst + ".wav"
    subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-", tmp],
                   input=out.astype(np.float32).tobytes(), check=True)
    stats = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", tmp, "-af", "loudnorm=print_format=summary",
                            "-f", "null", "-"], capture_output=True, text=True).stderr
    measured = float([l for l in stats.splitlines() if "Input Integrated" in l][0].split()[2])
    gain = target_lufs - measured
    subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-i", tmp, "-af", f"volume={gain:.2f}dB,alimiter=limit=0.95",
                    "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
    print(f"{src}: sound from {start_s:.1f}s, full from {body_start:.1f}s, fade done by {end_s:.1f}s")
    print(f"  cut at {c / SR:.3f}s, loop back to {s / SR:.3f}s (similarity {sim[best]:.3f}), "
          f"loop length {(c - s) / SR:.1f}s, gain {gain:+.1f} dB")
    print(f"LOOP_OFFSET {s / SR:.6f} SAMPLE {s}")


main()
