"""Prepares Jo's egg art for the hatch animation (ui/eggs/egg_view.gd).

    python tools/prepare_eggs.py <whole.png> <crack1.png> <crack2.png> <shards.png>

Inputs are the transparent ChatGPT renders (docs/ART_BRIEF.md, "Eggs"). Outputs, in assets/eggs/:
  egg_whole.webp            the intact egg
  egg_crack_N.webp          a cracked stage with its glowing light removed (the "shell")
  egg_crack_N_light.webp    that light as a white-on-transparent layer, which the game tints with
                            the rarity color and adds back on top (so N eggs glow grey, UR pink...)
  shard_N.webp              the broken shell pieces, one per file
All egg frames are cropped to the same box so they line up when the animation swaps between them.
Requires Pillow, numpy and scipy.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

OUT = Path(__file__).resolve().parent.parent / "assets" / "eggs"
FRAME_HEIGHT = 720
PAD = 24
DARK_CRACK = np.array([62.0, 42.0, 26.0])


def load(path: str) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float64) / 255.0


def luminance(a: np.ndarray) -> np.ndarray:
    return 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]


def smoothstep(lo: float, hi: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def light_mask(frame: np.ndarray, whole: np.ndarray | None) -> np.ndarray:
    """How much of each pixel is emitted light (0..1): white-hot cores and orange glow. If the frame
    lines up with the intact egg, only what got brighter counts (so the shell's sheen doesn't)."""
    lum = luminance(frame)
    red, blue = frame[..., 0], frame[..., 2]
    if whole is not None:
        hot = smoothstep(0.84, 0.96, lum)
        orange = smoothstep(0.28, 0.50, red - blue) * smoothstep(0.84, 0.97, red)
        mask = np.maximum(hot, orange) * smoothstep(0.04, 0.16, lum - luminance(whole))
    else:
        # A redrawn frame whose plates are as bright and warm as the glow: only the white-hot cores
        # are unambiguous, so take those and let the glow spread a few pixels around them.
        core = smoothstep(0.92, 0.985, lum) * smoothstep(0.16, 0.06, red - blue)
        near_core = np.clip(ndimage.gaussian_filter(core, 4.0) * 3.0, 0, 1)
        warm_bright = smoothstep(0.62, 0.85, lum) * smoothstep(0.84, 0.97, red)
        mask = np.maximum(core, near_core * warm_bright)
    # Keep away from the silhouette, where edge pixels blend with the background.
    inside = ndimage.binary_erosion(frame[..., 3] > 0.5, iterations=8)
    mask *= ndimage.gaussian_filter(inside.astype(float), 2.0)
    return np.clip(ndimage.gaussian_filter(mask, 0.8), 0, 1)


def split(frame: np.ndarray, mask: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Shell with the light painted out (cracks go dark), and the light as a white layer."""
    shell = frame.copy()
    halo = np.clip(ndimage.gaussian_filter(mask, 3.0) * 1.3, 0, 1)
    paint = np.maximum(mask, halo * 0.55)[..., None]
    # Inside the cracks: dark. In the glow around them: the shell's own colour, darkened a little.
    shell[..., :3] = shell[..., :3] * (1 - paint) + (DARK_CRACK / 255.0) * paint
    light = np.zeros_like(frame)
    light[..., :3] = 1.0
    light[..., 3] = np.clip(np.maximum(mask, halo * 0.7), 0, 1) * frame[..., 3].clip(0.0, 1.0) ** 0.5
    return shell, light


def crop_box(frames: list[np.ndarray]) -> tuple[int, int, int, int]:
    alpha = np.max([f[..., 3] for f in frames], axis=0)
    ys, xs = np.where(alpha > 0.02)
    h, w = alpha.shape
    return max(0, xs.min() - PAD), max(0, ys.min() - PAD), min(w, xs.max() + PAD + 1), min(h, ys.max() + PAD + 1)


def save(a: np.ndarray, path: Path, box: tuple[int, int, int, int]) -> None:
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA").crop(box)
    scale = FRAME_HEIGHT / img.height
    img = img.resize((round(img.width * scale), FRAME_HEIGHT), Image.LANCZOS)
    img.save(path, quality=90, method=6)
    print(f"wrote {path.name} {img.size}")


def shards(sheet: np.ndarray) -> None:
    alpha = sheet[..., 3] > 0.5
    labels, count = ndimage.label(alpha)
    sizes = ndimage.sum(alpha, labels, range(1, count + 1))
    keep = [i + 1 for i in np.argsort(sizes)[::-1] if sizes[i] > 2000]
    for n, label in enumerate(keep, 1):
        ys, xs = np.where(labels == label)
        box = (xs.min() - 4, ys.min() - 4, xs.max() + 5, ys.max() + 5)
        piece = sheet.copy()
        # Only this piece: keep soft edges that belong to it.
        near = ndimage.binary_dilation(labels == label, iterations=4)
        piece[..., 3] *= near
        img = Image.fromarray((np.clip(piece, 0, 1) * 255).astype(np.uint8), "RGBA").crop(box)
        img.thumbnail((220, 220), Image.LANCZOS)
        img.save(OUT / f"shard_{n}.webp", quality=90, method=6)
    print(f"wrote {len(keep)} shards")


def main() -> None:
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    OUT.mkdir(parents=True, exist_ok=True)
    whole, crack1, crack2, sheet = (load(p) for p in sys.argv[1:5])
    box = crop_box([whole, crack1, crack2])
    save(whole, OUT / "egg_whole.webp", box)
    for n, frame, ref in ((1, crack1, whole), (2, crack2, None)):
        shell, light = split(frame, light_mask(frame, ref))
        save(shell, OUT / f"egg_crack_{n}.webp", box)
        save(light, OUT / f"egg_crack_{n}_light.webp", box)
    shards(sheet)


if __name__ == "__main__":
    main()
