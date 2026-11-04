"""The YouTube channel art: banner and profile pictures, in the trailer's style (tools/make_trailer.py).

Usage: python tools/youtube_art.py
Writes docs/store/youtube_banner.jpg (2560x1440), docs/store/youtube_profile.png (800x800, the
wordmark like the app icon) and docs/store/youtube_profile_trex.png (800x800, the T. rex's face),
plus captures/youtube_banner_check.png with what phones, computers and TVs show of the banner.
YouTube shows the whole banner only on TVs; computers show the middle 2560x423 strip and phones the
middle 1546x423, so the logo stays inside that. Requires Pillow.
"""
import importlib.util
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

PROJECT = Path(__file__).resolve().parent.parent
_spec = importlib.util.spec_from_file_location("make_trailer", PROJECT / "tools" / "make_trailer.py")
trailer = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(trailer)

OUT = PROJECT / "docs" / "store"
NAVY = (10, 17, 31)
BANNER = (2560, 1440)
SAFE = (1546, 423)  # shown on every device
DESKTOP_H = 423


def _glow(size: tuple, box: tuple, color: tuple, blur: int) -> Image.Image:
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(box, fill=color)
    return layer.filter(ImageFilter.GaussianBlur(blur))


def _logo(width: int) -> Image.Image:
    logo = Image.open(PROJECT / "assets" / "branding" / "logo.png").convert("RGBA")
    return logo.resize((width, logo.height * width // logo.width), Image.Resampling.LANCZOS)


def banner() -> Image.Image:
    w, h = BANNER
    art = Image.new("RGBA", BANNER, NAVY + (255,))
    # TVs show the whole banner: a dim, blurred wall of paintings behind everything.
    wall = Image.new("RGBA", BANNER, (0, 0, 0, 0))
    ids = ["mosasaurus", "quetzalcoatlus", "t_rex", "triceratops", "spinosaurus", "stegosaurus", "pteranodon",
           "velociraptor", "brachiosaurus", "ankylosaurus"]
    for i, dino_id in enumerate(ids):
        painting = Image.open(PROJECT / "assets" / "dinos" / f"{dino_id}.webp").convert("RGBA").resize((256, 384))
        wall.alpha_composite(painting, (i * 256, 0))
        wall.alpha_composite(painting.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (i * 256, 384 * 3 - 96))
    wall = wall.filter(ImageFilter.GaussianBlur(14))
    wall.putalpha(wall.getchannel("A").point(lambda a: a * 35 // 100))
    art.alpha_composite(wall)
    art.alpha_composite(_glow(BANNER, (w // 2 - 1100, h // 2 - 420, w // 2 + 1100, h // 2 + 420), (46, 79, 128, 170), 140))
    # Cards fanned out on both sides of the logo, inside the strip computers show.
    middle = h // 2
    fan = [("pteranodon", -1080, 10), ("mosasaurus", -830, 6), ("quetzalcoatlus", -580, 2),
           ("spinosaurus", 1080, -10), ("triceratops", 830, -6), ("t_rex", 580, -2)]
    for dino_id, dx, tilt in fan:
        card = trailer._card(dino_id, 222, tilt)
        drop = abs(dx) // 45 - 12
        art.alpha_composite(card, (w // 2 + dx - card.width // 2, middle - card.height // 2 + drop))
    logo = _logo(820)
    words = trailer._heading("Hatch. Collect. Duel.", 70, 1200)
    top = middle - (logo.height + words.height - 10) // 2
    art.alpha_composite(logo, ((w - logo.width) // 2, top))
    art.alpha_composite(words, ((w - words.width) // 2, top + logo.height - 10))
    return art


def check(art: Image.Image) -> Image.Image:
    """The banner with the phone (gold) and computer (blue) crops outlined."""
    w, h = BANNER
    view = art.copy()
    draw = ImageDraw.Draw(view)
    draw.rectangle((0, (h - DESKTOP_H) // 2, w - 1, (h + DESKTOP_H) // 2), outline=(80, 160, 255, 255), width=6)
    draw.rectangle(((w - SAFE[0]) // 2, (h - SAFE[1]) // 2, (w + SAFE[0]) // 2, (h + SAFE[1]) // 2),
                   outline=(255, 211, 77, 255), width=6)
    return view.resize((w // 2, h // 2), Image.Resampling.LANCZOS)


def profile_wordmark() -> Image.Image:
    size = 800
    art = Image.new("RGBA", (size, size), (6, 12, 26, 255))
    # Like the app icon: lighter navy in the middle, darker at the edges.
    art.alpha_composite(_glow((size, size), (60, 60, size - 60, size - 60), (30, 62, 120, 255), 170))
    logo = _logo(690)
    art.alpha_composite(logo, ((size - logo.width) // 2, (size - logo.height) // 2 + 8))
    return art


def profile_trex() -> Image.Image:
    """The T. rex's face from its full painting, framed like its avatar (Avatar.portrait_box)."""
    painting = Image.open(PROJECT / "assets" / "dinos" / "t_rex.webp").convert("RGB")
    x, y, s = json.loads((PROJECT / "assets" / "dinos" / "faces.json").read_text(encoding="utf-8"))["t_rex"]
    side = min(1.0, s * 1.65)
    x = min(max(x - (side - s) * 0.5, 0.0), 1.0 - side)
    y = min(max(y - (side - s) * 0.3, 0.0), 1.5 - side)
    w = painting.width
    return painting.crop((round(x * w), round(y * w), round((x + side) * w), round((y + side) * w))).resize(
        (800, 800), Image.Resampling.LANCZOS)


def main() -> None:
    art = banner()
    art.convert("RGB").save(OUT / "youtube_banner.jpg", quality=92)
    check(art).convert("RGB").save(PROJECT / "captures" / "youtube_banner_check.png")
    profile_wordmark().convert("RGB").save(OUT / "youtube_profile.png")
    profile_trex().save(OUT / "youtube_profile_trex.png")
    for name in ["youtube_banner.jpg", "youtube_profile.png", "youtube_profile_trex.png"]:
        print(f"Wrote docs/store/{name} ({(OUT / name).stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
