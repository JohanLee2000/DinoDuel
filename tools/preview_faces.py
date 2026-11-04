"""Preview the round dino avatars (Fossil Hunter ID): each dino's face crop from assets/dinos/faces.json.

Usage:
    python tools/preview_faces.py            writes captures/faces_preview.png (every dino)
    python tools/preview_faces.py t_rex yi_qi    only these dinos, bigger, with the box drawn on the painting

faces.json holds one entry per dino: [x, y, size], as fractions of the painting's width
(the paintings are 2:3, so y runs from 0 to 1.5).
    x     left edge of the square crop. Bigger x = the face moves LEFT in the circle.
    y     top edge of the crop.         Bigger y = the face moves UP in the circle.
    size  width of the square.          Smaller = zoomed in (bigger face).
Change a number by about 0.02 at a time, run this again, and look. The game reads the same file
(ui/common/avatar.gd), from the thumbnails in assets/dinos/thumbs/ (Shiny paintings share the framing).
Requires Pillow.
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

PROJECT = Path(__file__).resolve().parent.parent
THUMBS = PROJECT / "assets" / "dinos" / "thumbs"
FACES = PROJECT / "assets" / "dinos" / "faces.json"
OUT = PROJECT / "captures" / "faces_preview.png"
SIZE = 120
COLS = 8


def disc(painting: Image.Image, box: list, size: int) -> tuple[Image.Image, Image.Image]:
    w = painting.width
    x, y, s = box
    crop = painting.crop((round(x * w), round(y * w), round((x + s) * w), round((y + s) * w)))
    crop = crop.resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    return crop, mask


def main() -> None:
    faces = json.loads(FACES.read_text(encoding="utf-8"))
    chosen = sys.argv[1:]
    if chosen:
        # A few dinos, big: the painting with the crop box, and the circle next to it.
        row_h = 400
        sheet = Image.new("RGB", (560, row_h * len(chosen)), (19, 37, 74))
        draw = ImageDraw.Draw(sheet)
        for i, dino_id in enumerate(chosen):
            painting = Image.open(THUMBS / f"{dino_id}.webp").convert("RGB")
            small = painting.resize((240, 360), Image.LANCZOS)
            x, y, s = faces[dino_id]
            frame = ImageDraw.Draw(small)
            frame.rectangle((x * 240, y * 240, (x + s) * 240, (y + s) * 240), outline=(255, 211, 77), width=3)
            oy = i * row_h + 20
            sheet.paste(small, (10, oy))
            crop, mask = disc(painting, faces[dino_id], 260)
            sheet.paste(crop, (280, oy + 30), mask)
            draw.ellipse((277, oy + 27, 543, oy + 293), outline=(255, 211, 77), width=5)
            draw.text((280, oy + 310), f"{dino_id}  {x:.2f} {y:.2f} {s:.2f}", fill=(230, 230, 230))
        out = OUT.with_name("faces_preview_some.png")
    else:
        ids = sorted(faces)
        missing = sorted(p.stem for p in THUMBS.glob("*.webp") if p.stem not in faces and not p.stem.endswith("_shiny"))
        if missing:
            print("No face box (the game uses its default crop):", ", ".join(missing))
        rows = (len(ids) + COLS - 1) // COLS
        sheet = Image.new("RGB", (COLS * (SIZE + 24), rows * (SIZE + 40)), (19, 37, 74))
        draw = ImageDraw.Draw(sheet)
        for i, dino_id in enumerate(ids):
            painting = Image.open(THUMBS / f"{dino_id}.webp").convert("RGB")
            crop, mask = disc(painting, faces[dino_id], SIZE)
            ox = (i % COLS) * (SIZE + 24) + 12
            oy = (i // COLS) * (SIZE + 40) + 10
            sheet.paste(crop, (ox, oy), mask)
            draw.ellipse((ox - 2, oy - 2, ox + SIZE + 1, oy + SIZE + 1), outline=(255, 211, 77), width=3)
            draw.text((ox, oy + SIZE + 6), dino_id, fill=(230, 230, 230))
        out = OUT
    out.parent.mkdir(exist_ok=True)
    sheet.save(out)
    print(f"Wrote {out.relative_to(PROJECT)}")


if __name__ == "__main__":
    main()
