"""Cut the logo and card back out of the concept sheet and build the app icon set.

Usage: python tools/extract_branding.py
Source: docs/concept/card_concept_sheet.webp (Jo's ChatGPT concept). Outputs to assets/branding/.
These are interim assets cut from a 1536x1024 sheet; replace them with full-resolution exports
(same file names) when available and the game picks them up automatically.
"""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

PROJECT = Path(__file__).resolve().parent.parent
SHEET = PROJECT / "docs" / "concept" / "card_concept_sheet.webp"
OUT = PROJECT / "assets" / "branding"
NAVY = (9, 15, 28)


def tight_box(image: Image.Image, region: tuple, threshold: int) -> tuple:
    """Bounding box (in sheet coordinates) of pixels brighter than the dark background."""
    crop = image.crop(region).convert("L").point(lambda v: 255 if v > threshold else 0)
    box = crop.getbbox()
    return (region[0] + box[0], region[1] + box[1], region[0] + box[2], region[1] + box[3])


def remove_dark_background(image: Image.Image, floor: int, ceiling: int) -> Image.Image:
    """Alpha from brightness: the near-black sheet background becomes transparent, the glow fades out."""
    rgb = image.convert("RGB")
    luma = rgb.convert("L")
    alpha = luma.point(lambda v: 0 if v <= floor else (255 if v >= ceiling else int((v - floor) * 255 / (ceiling - floor))))
    result = rgb.copy()
    result.putalpha(alpha)
    return result


def rounded_mask(size: tuple, radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SHEET).convert("RGB")

    # Logo: top-left wordmark.
    # Stop above y=114: the tops of the sample cards start just below the wordmark.
    logo_box = tight_box(sheet, (20, 10, 440, 114), 70)
    logo_box = (logo_box[0] - 6, logo_box[1] - 6, logo_box[2] + 6, min(logo_box[3] + 6, 114))
    logo = remove_dark_background(sheet.crop(logo_box), 38, 95)
    logo = logo.resize((logo.width * 2, logo.height * 2), Image.LANCZOS)
    logo.save(OUT / "logo.png")
    print("logo", logo_box, logo.size)

    # Card back: the framed card in the "Card back design" panel.
    back_box = tight_box(sheet, (870, 640, 1080, 965), 55)
    back = sheet.crop(back_box)
    back = back.resize((back.width * 2, back.height * 2), Image.LANCZOS)
    back.putalpha(rounded_mask(back.size, int(back.width * 0.05)))
    back.save(OUT / "card_back.png")
    print("card back", back_box, back.size)

    # App icon: logo on a navy tile with a soft blue glow.
    def icon_tile(size: int, logo_width: int, with_background: bool) -> Image.Image:
        tile = Image.new("RGBA", (size, size), NAVY + (255,) if with_background else (0, 0, 0, 0))
        if with_background:
            glow = Image.new("L", (size, size), 0)
            ImageDraw.Draw(glow).ellipse((size * 0.1, size * 0.2, size * 0.9, size * 0.8), fill=90)
            glow = glow.filter(ImageFilter.GaussianBlur(size * 0.12))
            tint = Image.new("RGBA", (size, size), (40, 110, 220, 255))
            tile = Image.composite(tint, tile, glow)
        scaled = logo.resize((logo_width, round(logo.height * logo_width / logo.width)), Image.LANCZOS)
        tile.alpha_composite(scaled, ((size - scaled.width) // 2, (size - scaled.height) // 2))
        return tile

    icon_tile(512, 470, True).save(OUT / "app_icon_512.png")
    icon_tile(192, 176, True).save(OUT / "app_icon_192.png")
    # Android adaptive icon: the launcher masks it to a circle/squircle, keeping the middle 66%.
    icon_tile(432, 300, False).save(OUT / "app_icon_foreground_432.png")
    Image.new("RGBA", (432, 432), NAVY + (255,)).save(OUT / "app_icon_background_432.png")
    print("icons written")


if __name__ == "__main__":
    main()
