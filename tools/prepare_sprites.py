"""Prepare ChatGPT pixel-art rival sprites for the game (docs/JOURNEY_ART.md).

Usage:
    python tools/prepare_sprites.py <image> <id>              one sprite, e.g. rory.png rory
    python tools/prepare_sprites.py <sheet> <id1,id2,...>     a sprite sheet, cut into a grid
                                                              (4 x 4 for 16 ids, 4 x 2 for 8;
                                                              "-" skips a cell)

Each sprite is trimmed to the character (transparent background; a flat light background is
removed if the image has none), padded a little, capped at 1024 px and saved as lossless WebP in
assets/rivals/<id>.webp. AI pixel art isn't on an even pixel grid, so it isn't snapped to one:
the game draws it scaled down, where the "pixels" still read as crisp blocks.

It also records where the head is, as fractions of the sprite (x, y, size of a square), in
assets/rivals/heads.json; the round Journey map markers show that crop.
A sheet is cut along its emptiest columns and, per column, its emptiest rows near the grid lines
(sprites can reach across a straight cut), and stray bits of neighbours are dropped.
Requires Pillow, numpy and scipy.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

PROJECT = Path(__file__).resolve().parent.parent
OUT = PROJECT / "assets" / "rivals"
HEADS = OUT / "heads.json"
MAX_SIZE = 1024
PAD = 0.04
# A light background counts as background within this distance of its color (0-441).
BG_TOLERANCE = 40


def remove_flat_background(im: Image.Image) -> Image.Image:
    """Makes a flat background transparent, flood-filling from the edges so light colors inside
    the outlined character (teeth, shoe soles) stay."""
    a = np.asarray(im.convert("RGBA")).copy()
    if (a[..., 3] < 10).mean() > 0.2:
        return Image.fromarray(a)  # already transparent
    rgb = a[..., :3].astype(int)
    edge = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bg = np.median(edge, axis=0)
    close = np.sqrt(((rgb - bg) ** 2).sum(axis=2)) < BG_TOLERANCE
    h, w = close.shape
    seen = np.zeros_like(close)
    stack = [(y, x) for y in range(h) for x in (0, w - 1) if close[y, x]] + \
            [(y, x) for x in range(w) for y in (0, h - 1) if close[y, x]]
    while stack:
        y, x = stack.pop()
        if seen[y, x] or not close[y, x]:
            continue
        seen[y, x] = True
        if y > 0: stack.append((y - 1, x))
        if y < h - 1: stack.append((y + 1, x))
        if x > 0: stack.append((y, x - 1))
        if x < w - 1: stack.append((y, x + 1))
    a[seen, 3] = 0
    return Image.fromarray(a)


def keep_main_figure(im: Image.Image) -> Image.Image:
    """Drops small detached bits (pieces of a neighbouring sprite that crossed into the cell)."""
    a = np.asarray(im).copy()
    labels, count = ndimage.label(a[..., 3] > 40)
    if count <= 1:
        return im
    sizes = ndimage.sum(np.ones_like(labels), labels, range(1, count + 1))
    keep = [i + 1 for i, size in enumerate(sizes) if size >= sizes.max() * 0.03]
    a[~np.isin(labels, keep) & (labels > 0), 3] = 0
    return Image.fromarray(a)


def emptiest(profile: np.ndarray, near: float, span: int) -> int:
    """The index near `near` whose opaque-pixel count is lowest (the middle of the emptiest run)."""
    lo, hi = max(0, int(near - span)), min(len(profile), int(near + span))
    window = profile[lo:hi]
    best = window.min()
    hits = np.where(window == best)[0]
    return lo + int(hits[len(hits) // 2])


def trim(im: Image.Image) -> Image.Image:
    alpha = np.asarray(im)[..., 3]
    ys, xs = np.where(alpha > 40)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    im = im.crop(box)
    w, h = im.size
    side = int(max(w, h) * (1 + 2 * PAD))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im, ((side - w) // 2, side - h - int(side * PAD)))
    if side > MAX_SIZE:
        canvas = canvas.resize((MAX_SIZE, MAX_SIZE), Image.LANCZOS)
    return canvas


def head_box(im: Image.Image) -> list:
    """A square around the head and shoulders, as fractions of the sprite: [x, y, size]."""
    alpha = np.asarray(im)[..., 3] > 40
    ys, xs = np.where(alpha)
    top, bottom = ys.min(), ys.max()
    height = bottom - top
    # The face is a little below the top of the hair; its middle is the head's x.
    band = alpha[top + int(height * 0.06): top + int(height * 0.16)]
    cols = np.where(band.any(axis=0))[0]
    weights = band.sum(axis=0)[cols]
    center_x = float((cols * weights).sum() / weights.sum())
    size = height * 0.34
    x = min(max(center_x - size / 2, 0), im.width - size)
    y = max(top - height * 0.03, 0)
    return [round(float(x) / im.width, 4), round(float(y) / im.height, 4), round(float(size) / im.width, 4)]


def save(im: Image.Image, sprite_id: str, heads: dict) -> None:
    sprite = trim(keep_main_figure(remove_flat_background(im)))
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{sprite_id}.webp"
    sprite.save(path, "WEBP", lossless=True, quality=100, method=6)
    heads[sprite_id] = head_box(sprite)
    print(f"{sprite_id}: {sprite.size[0]} px, {path.stat().st_size // 1024} KB, head {heads[sprite_id]}")


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    source = Image.open(sys.argv[1]).convert("RGBA")
    ids = [i.strip() for i in sys.argv[2].split(",") if i.strip()]
    heads = json.loads(HEADS.read_text()) if HEADS.exists() else {}
    if len(ids) == 1:
        save(source, ids[0], heads)
    else:
        cols = 4
        rows = (len(ids) + cols - 1) // cols
        clean = remove_flat_background(source)
        opaque = np.asarray(clean)[..., 3] > 40
        w, h = source.width / cols, source.height / rows
        xs = [0] + [emptiest(opaque.sum(axis=0), c * w, w * 0.2) for c in range(1, cols)] + [source.width]
        for i, sprite_id in enumerate(ids):
            if sprite_id in ("-", "skip"):
                continue
            r, c = divmod(i, cols)
            column = opaque[:, xs[c]:xs[c + 1]].sum(axis=1)
            ys = [0] + [emptiest(column, k * h, h * 0.15) for k in range(1, rows)] + [source.height]
            cell = clean.crop((xs[c], ys[r], xs[c + 1], ys[r + 1]))
            save(cell, sprite_id, heads)
    HEADS.write_text(json.dumps(dict(sorted(heads.items())), indent=1))


if __name__ == "__main__":
    main()
