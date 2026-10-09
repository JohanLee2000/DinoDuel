"""Resize ChatGPT dino paintings for the game and save them into assets/dinos/ as WebP.

Usage:
    python tools/prepare_art.py "C:/path/to/downloads"
    python tools/prepare_art.py --thumbs        (rebuild every thumbnail from assets/dinos/)

Looks for files named like the dino ids (see docs/ART_BRIEF.md):
    t_rex.png, t_rex_shiny.png, velociraptor.png, ...
Any of .png, .jpg, .jpeg or .webp works. Paintings are 2:3 portraits; they're resized to
1000 px wide, which is sharper than any phone shows them, and saved as quality-88 WebP to keep
the app download small. Requires Pillow (pip install pillow).

Each painting also gets a 360 px thumbnail in assets/dinos/thumbs/, which every card smaller than
the full-screen view uses (ui/common/dino_art.gd): it loads about 8x faster, so tabs full of
cards open quickly.
"""
import sys
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parent.parent
OUT = PROJECT / "assets" / "dinos"
THUMBS = OUT / "thumbs"
THUMB_WIDTH = 360
# Every dino in the game has a data file named after its id.
IDS = sorted(p.stem for p in (PROJECT / "data" / "dinos").glob("*.tres"))
SUFFIXES = ["", "_shiny"]
EXTENSIONS = [".png", ".jpg", ".jpeg", ".webp"]


def save_thumb(image: Image.Image, name: str) -> None:
    THUMBS.mkdir(parents=True, exist_ok=True)
    height = round(image.height * THUMB_WIDTH / image.width)
    thumb = image.resize((THUMB_WIDTH, height), Image.LANCZOS)
    thumb.save(THUMBS / f"{name}.webp", "WEBP", quality=85, method=6)


def rebuild_thumbs() -> None:
    done = 0
    for painting in sorted(OUT.glob("*.webp")):
        save_thumb(Image.open(painting).convert("RGB"), painting.stem)
        done += 1
    print(f"{done} thumbnail(s) written to {THUMBS.relative_to(PROJECT)}")


def main() -> None:
    if len(sys.argv) == 2 and sys.argv[1] == "--thumbs":
        rebuild_thumbs()
        return
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    source = Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    done = 0
    for dino_id in IDS:
        for suffix in SUFFIXES:
            name = dino_id + suffix
            match = next((source / (name + ext) for ext in EXTENSIONS if (source / (name + ext)).exists()), None)
            if match is None:
                continue
            image = Image.open(match).convert("RGB")
            target_width = 1000
            if image.width > target_width:
                height = round(image.height * target_width / image.width)
                image = image.resize((target_width, height), Image.LANCZOS)
            out_path = OUT / f"{name}.webp"
            image.save(out_path, "WEBP", quality=88, method=6)
            save_thumb(image, name)
            print(f"{match.name} -> {out_path.relative_to(PROJECT)} ({image.width}x{image.height}, "
                  f"{out_path.stat().st_size // 1024} KB) + thumbnail")
            done += 1
    unknown = [p.name for p in source.iterdir()
               if p.suffix.lower() in EXTENSIONS and not any(p.stem == i + s for i in IDS for s in SUFFIXES)]
    print(f"\n{done} image(s) prepared.")
    if unknown:
        print("Skipped (name doesn't match a dino id):", ", ".join(unknown))


if __name__ == "__main__":
    main()
