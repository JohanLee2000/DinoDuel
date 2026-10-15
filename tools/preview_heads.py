"""Preview the round Journey map markers: each rival's head crop from assets/rivals/heads.json.

Usage:
    python tools/preview_heads.py            writes captures/heads_preview.png

heads.json holds one entry per sprite: [x, y, size], as fractions of the sprite's width.
    x     left edge of the square crop. Bigger x = the face moves LEFT in the circle.
    y     top edge of the crop.         Bigger y = the face moves UP in the circle.
    size  width of the square.          Smaller = zoomed in (bigger face).
Change a number by about 0.02 at a time, run this again, and look. The game reads the same file.
Requires Pillow.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

PROJECT = Path(__file__).resolve().parent.parent
RIVALS = PROJECT / "assets" / "rivals"
OUT = PROJECT / "captures" / "heads_preview.png"
SIZE = 150
COLS = 6


def main() -> None:
    heads = json.loads((RIVALS / "heads.json").read_text(encoding="utf-8"))
    ids = sorted(heads)
    rows = (len(ids) + COLS - 1) // COLS
    sheet = Image.new("RGB", (COLS * (SIZE + 30), rows * (SIZE + 60)), (19, 37, 74))
    draw = ImageDraw.Draw(sheet)
    for i, sprite_id in enumerate(ids):
        sprite = Image.open(RIVALS / f"{sprite_id}.webp").convert("RGBA")
        w = sprite.width
        x, y, s = heads[sprite_id]
        crop = sprite.crop((round(x * w), round(y * w), round((x + s) * w), round((y + s) * w)))
        crop = crop.resize((SIZE, SIZE), Image.LANCZOS)
        disc = Image.new("RGBA", (SIZE, SIZE), (27, 42, 71, 255))
        disc.alpha_composite(crop)
        mask = Image.new("L", (SIZE, SIZE), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, SIZE - 1, SIZE - 1), fill=255)
        ox = (i % COLS) * (SIZE + 30) + 15
        oy = (i // COLS) * (SIZE + 60) + 12
        sheet.paste(disc, (ox, oy), mask)
        draw.ellipse((ox - 3, oy - 3, ox + SIZE + 2, oy + SIZE + 2), outline=(255, 211, 77), width=4)
        # Faint crosshair: the middle of the circle.
        draw.line((ox + SIZE / 2, oy + 8, ox + SIZE / 2, oy + SIZE - 8), fill=(255, 255, 255, 60), width=1)
        draw.line((ox + 8, oy + SIZE / 2, ox + SIZE - 8, oy + SIZE / 2), fill=(255, 255, 255, 60), width=1)
        draw.text((ox, oy + SIZE + 8), f"{sprite_id}  {x:.2f} {y:.2f} {s:.2f}", fill=(230, 230, 230))
    OUT.parent.mkdir(exist_ok=True)
    sheet.save(OUT)
    print(f"Wrote {OUT.relative_to(PROJECT)}")


if __name__ == "__main__":
    main()
