"""Prepares the hatch reveal light layers (docs/ART_BRIEF.md, "Hatch reveal light effects").

    python tools/prepare_fx.py <rays> <halo> <ring> <sparkles> <sigil>

Inputs are white-on-black ChatGPT renders. Each is turned into greyscale (the game tints it with
the rarity color and adds it on top, so black is invisible), faded to black near the edges so
rotating or scaling never shows a border, and saved to assets/eggs/fx/. The sparkle sheet (4 x 2)
is cut into sparkle_1..8.webp. Requires Pillow and numpy.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "eggs" / "fx"
LAYER_SIZE = 1024


def grey(path: str) -> np.ndarray:
    return np.asarray(Image.open(path).convert("L")).astype(np.float64) / 255.0


def edge_fade(a: np.ndarray, start: float = 0.86, end: float = 0.99) -> np.ndarray:
    """Multiplies by a round falloff: 1 inside `start` of the half-size, 0 at `end`."""
    h, w = a.shape
    y, x = np.mgrid[0:h, 0:w]
    r = np.hypot((x - (w - 1) / 2) / (w / 2), (y - (h - 1) / 2) / (h / 2))
    t = np.clip((r - start) / (end - start), 0, 1)
    return a * (1 - t * t * (3 - 2 * t))


def save(a: np.ndarray, name: str, size: int | None = LAYER_SIZE) -> None:
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "L").convert("RGB")
    if size:
        img = img.resize((size, size), Image.LANCZOS)
    img.save(OUT / name, quality=90, method=6)
    print(f"wrote {name} {img.size}")


def main() -> None:
    if len(sys.argv) != 6:
        sys.exit(__doc__)
    OUT.mkdir(parents=True, exist_ok=True)
    rays, halo, ring, sheet, sigil = sys.argv[1:6]
    for path, name in ((rays, "rays.webp"), (halo, "halo.webp"), (ring, "ring.webp"), (sigil, "sigil.webp")):
        save(edge_fade(grey(path)), name)
    # Sparkle sheet: 4 columns x 2 rows; each cell cropped square around its brightest point.
    a = grey(sheet)
    h, w = a.shape
    cell_w, cell_h = w // 4, h // 2
    n = 0
    for row in range(2):
        for col in range(4):
            cell = a[row * cell_h:(row + 1) * cell_h, col * cell_w:(col + 1) * cell_w]
            weights = cell ** 4
            cy = int((weights.sum(axis=1) * np.arange(cell.shape[0])).sum() / weights.sum())
            cx = int((weights.sum(axis=0) * np.arange(cell.shape[1])).sum() / weights.sum())
            half = min(cell_w // 2, cell_h // 2, cx, cy, cell.shape[1] - cx, cell.shape[0] - cy)
            crop = cell[cy - half:cy + half, cx - half:cx + half]
            n += 1
            save(edge_fade(crop, 0.7, 0.98), f"sparkle_{n}.webp", 192)


if __name__ == "__main__":
    main()
