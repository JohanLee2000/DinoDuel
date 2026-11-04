"""Records and edits the Google Play preview video (a ~30 s landscape trailer).

Usage:
    python tools/make_trailer.py record          records the gameplay clips (Movie Maker, ~3 min)
    python tools/make_trailer.py sheet <clip>    a contact sheet of a clip, one frame a second, to pick cuts
    python tools/make_trailer.py build           edits captures/trailer/dino_duel_trailer.mp4

Clips are recorded at 720x1280, 30 fps, with the debug-only showcase save (--store-shots) and
sound effects only (--no-music); the edit adds one music track over the top. Battles are random,
so after `record`, check the run's sheet and update the times in SHOTS.
The video goes on YouTube (public or unlisted, ads off), then its URL into Play Console's
"Preview video" field. Google autoplays the first 30 seconds muted, hence the captions.
Requires Pillow and ffmpeg.
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

PROJECT = Path(__file__).resolve().parent.parent
OUT = PROJECT / "captures" / "trailer"
CLIPS_DIR = OUT / "clips"
GODOT = os.environ.get("GODOT", "C:/Users/johan/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")
FFMPEG = shutil.which("ffmpeg") or "C:/ffmpeg/bin/ffmpeg.exe"
FPS = 30

# name: (game flags, frames to record)
CLIPS = {
    "run": (["--store-shots", "--autoplay", "--rival=sela"], 2700),
    # Straight to the Eggs tab: the showcase save's first egg is a new UR (Cymbospondylus).
    "hatch": (["--store-shots", "--autoplay", "--tab=2"], 600),
    "journey": (["--store-shots", "--tab=0"], 150),
    "card": (["--store-shots", "--open-card=t_rex:shiny"], 150),
    "dex": (["--store-shots", "--tab=3"], 150),
    "share": (["--store-shots", "--open=shareparty"], 150),
}

OVERRIDE = """[display]
window/size/window_width_override=720
window/size/window_height_override=1280
[editor]
movie_writer/mjpeg_quality=0.95
"""


def record() -> None:
    CLIPS_DIR.mkdir(parents=True, exist_ok=True)
    override = PROJECT / "override.cfg"
    if override.exists():
        sys.exit("override.cfg already exists; move it away first.")
    override.write_text(OVERRIDE, encoding="utf-8")
    try:
        for name, (flags, frames) in CLIPS.items():
            print(f"Recording {name} ({frames / FPS:.0f} s)...", flush=True)
            subprocess.run([GODOT, "--path", str(PROJECT), "--write-movie", f"captures/trailer/clips/{name}.avi",
                            "--fixed-fps", str(FPS), "--quit-after", str(frames), "--", *flags, "--no-music"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    finally:
        override.unlink()
    print("Done. Check the run with: python tools/make_trailer.py sheet run")


def sheet(name: str) -> None:
    out = OUT / f"sheet_{name}.png"
    subprocess.run([FFMPEG, "-v", "error", "-y", "-i", str(CLIPS_DIR / f"{name}.avi"), "-vf",
                    "fps=1,scale=144:256,drawtext=fontfile=assets/fonts/Barlow-Bold.ttf:text='%{pts\\:hms}'"
                    ":x=4:y=4:fontsize=18:fontcolor=yellow:box=1:boxcolor=black@0.6,tile=10x9",
                    "-frames:v", "1", str(out)], cwd=PROJECT, check=True)
    print(f"Wrote {out.relative_to(PROJECT)}")


# --- The edit -----------------------------------------------------------------------------------

W, H = 1920, 1080
PHONE_H = 1008
PHONE_W = PHONE_H * 9 // 16
PHONE_X = (W - PHONE_W) // 2
PHONE_Y = (H - PHONE_H) // 2
FONTS = PROJECT / "assets" / "fonts"
GOLD = (255, 211, 77)
TEXT = (234, 242, 255)
TEXT_DIM = (170, 187, 210)
OUTLINE = (5, 8, 15)
# Palette.RARITY_COLORS: N, R, SR, SSR, UR.
RARITY = [(157, 176, 200), (61, 220, 132), (176, 92, 255), (255, 178, 46), (255, 79, 176)]
MUSIC = PROJECT / "assets" / "audio" / "music" / "battle.ogg"
XFADE = 0.25
END_SECONDS = 3.5

# (clip, start in s, seconds, heading, line under it, dino painting on the right or "").
# The first 30 seconds autoplay muted on Google Play, so the captions carry it.
SHOTS = [
    ("hatch", 1.6, 5.6, "Hatch fossil eggs", "The glow shows how rare it is", "quetzalcoatlus"),
    ("card", 0.5, 3.0, "Collect 68 dinos", "Common to Legendary\nPlus rare Shiny cards", "mosasaurus"),
    ("journey", 0.5, 3.0, "A journey through time", "15 rivals, from the Triassic to the meteor", "stegosaurus"),
    ("run", 0.9, 3.6, "Bring 6, pick 3", "See your rival's party, then pick in secret", "triceratops"),
    ("run", 20.5, 6.0, "Mind games, not luck", "Bite beats Charge\nCharge beats Brace\nBrace beats Bite", "t_rex"),
    ("run", 42.5, 5.5, "Outsmart your rival", "Land beats Sky\nSky beats Sea\nSea beats Land", "spinosaurus"),
    ("share", 0.5, 3.0, "Duel your friends", "Share your party as a code", "pteranodon"),
]


def _font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS / name), size)


def _wrap(text: str, font: ImageFont.FreeTypeFont, width: int) -> list[str]:
    """Words into lines `width` wide; a newline in `text` always starts a new line."""
    lines = []
    for part in text.split("\n"):
        line = ""
        for word in part.split():
            trial = f"{line} {word}".strip()
            if font.getlength(trial) <= width or not line:
                line = trial
            else:
                lines.append(line)
                line = word
        if line:
            lines.append(line)
    return lines


def _heading(text: str, size: int, width: int) -> Image.Image:
    """Capitals in the game's title style: bold condensed, slanted, with a dark outline."""
    font = _font("BarlowCondensed-Bold.ttf", size)
    stroke = max(4, size // 14)
    shear = 0.14
    rows = []
    for line in _wrap(text.upper(), font, width):
        # Each line on its own, slanted like Fonts.title(), so stacked lines stay left-aligned.
        left, top, right, bottom = font.getbbox(line, stroke_width=stroke)
        pad = int(shear * size) + stroke
        row = Image.new("RGBA", (right + 2 * pad, int(size * 1.1) + stroke * 2), (0, 0, 0, 0))
        ImageDraw.Draw(row).text((pad, stroke), line, font=font, fill=GOLD, stroke_width=stroke, stroke_fill=OUTLINE)
        rows.append(row.transform(row.size, Image.Transform.AFFINE, (1, shear, -shear * row.height, 0, 1, 0),
                                  resample=Image.Resampling.BICUBIC))
    step = int(size * 0.98)
    image = Image.new("RGBA", (max(r.width for r in rows), step * (len(rows) - 1) + rows[-1].height), (0, 0, 0, 0))
    for i, row in enumerate(rows):
        image.alpha_composite(row, (0, i * step))
    return image


def _rarity(dino_id: str) -> int:
    for line in (PROJECT / "data" / "dinos" / f"{dino_id}.tres").read_text(encoding="utf-8").splitlines():
        if line.startswith("rarity = "):
            return int(line.split("=")[1])
    return 0


def _card(dino_id: str, width: int, tilt: float) -> Image.Image:
    """A dino's painting as a tilted card in its tier color, with a soft shadow."""
    painting = Image.open(PROJECT / "assets" / "dinos" / f"{dino_id}.webp").convert("RGB")
    height = width * 3 // 2
    painting = painting.resize((width, height), Image.Resampling.LANCZOS)
    radius, border = width // 14, max(6, width // 45)
    card = Image.new("RGBA", (width + 2 * border, height + 2 * border), (0, 0, 0, 0))
    ImageDraw.Draw(card).rounded_rectangle((0, 0, card.width - 1, card.height - 1), radius + border, fill=RARITY[_rarity(dino_id)])
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1), radius, fill=255)
    card.paste(painting, (border, border), mask)
    margin = 60
    out = Image.new("RGBA", (card.width + 2 * margin, card.height + 2 * margin), (0, 0, 0, 0))
    shadow = Image.new("RGBA", out.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((margin + 10, margin + 18, margin + card.width + 10, margin + card.height + 18),
                                             radius, fill=(0, 0, 0, 170))
    out.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)))
    out.alpha_composite(card, (margin, margin))
    return out.rotate(tilt, resample=Image.Resampling.BICUBIC, expand=True)


def _base_layer() -> Image.Image:
    """Darker sides so the words read, and a glow around the phone."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shade = Image.new("L", (W, 1))
    for x in range(W):
        middle = abs(x - W / 2) / (W / 2)
        shade.putpixel((x, 0), int(110 + 90 * middle))
    layer.putalpha(shade.resize((W, H)))
    layer = Image.composite(Image.new("RGBA", (W, H), (6, 10, 20, 255)), Image.new("RGBA", (W, H), (0, 0, 0, 0)), layer.getchannel("A"))
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).rounded_rectangle((PHONE_X - 10, PHONE_Y - 10, PHONE_X + PHONE_W + 10, PHONE_Y + PHONE_H + 10), 44,
                                           fill=(255, 211, 77, 120))
    layer.alpha_composite(glow.filter(ImageFilter.GaussianBlur(22)))
    ImageDraw.Draw(layer).rounded_rectangle((PHONE_X - 4, PHONE_Y - 4, PHONE_X + PHONE_W + 4, PHONE_Y + PHONE_H + 4), 38,
                                            outline=(46, 79, 128, 255), width=4)
    return layer


def _text_layer(heading: str, line: str, dino_id: str, index: int) -> Image.Image:
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    logo = Image.open(PROJECT / "assets" / "branding" / "logo.png").convert("RGBA")
    logo = logo.resize((330, logo.height * 330 // logo.width), Image.Resampling.LANCZOS)
    layer.alpha_composite(logo, (88, 64))
    words = _heading(heading, 104, 580)
    body = _font("Barlow-Medium.ttf", 42)
    lines = _wrap(line, body, 540)
    block = words.height + 10 + len(lines) * 54
    top = (H - block) // 2 + 30
    layer.alpha_composite(words, (40, top))
    draw = ImageDraw.Draw(layer)
    for i, text in enumerate(lines):
        draw.text((92, top + words.height + 4 + i * 54), text, font=body, fill=TEXT, stroke_width=2, stroke_fill=OUTLINE)
    if dino_id:
        card = _card(dino_id, 400, 5 if index % 2 == 0 else -5)
        layer.alpha_composite(card, (PHONE_X + PHONE_W + (W - PHONE_X - PHONE_W - card.width) // 2, (H - card.height) // 2))
    return layer


def _end_card() -> Image.Image:
    card = Image.new("RGBA", (W, H), (10, 17, 31, 255))
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((W // 2 - 700, 80, W // 2 + 700, 760), fill=(46, 79, 128, 160))
    card.alpha_composite(glow.filter(ImageFilter.GaussianBlur(120)))
    for i, (dino_id, tilt) in enumerate([("mosasaurus", 14), ("quetzalcoatlus", 7), ("t_rex", 0), ("triceratops", -7), ("spinosaurus", -14)]):
        art = _card(dino_id, 250, tilt)
        x = W // 2 - art.width // 2 + (i - 2) * 230
        y = 420 - art.height // 2 + abs(i - 2) * 34
        card.alpha_composite(art, (x, y))
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shade).rectangle((0, 560, W, H), fill=(10, 17, 31, 235))
    card.alpha_composite(shade.filter(ImageFilter.GaussianBlur(40)))
    logo = Image.open(PROJECT / "assets" / "branding" / "logo.png").convert("RGBA")
    logo = logo.resize((900, logo.height * 900 // logo.width), Image.Resampling.LANCZOS)
    card.alpha_composite(logo, ((W - logo.width) // 2, 560))
    words = _heading("Hatch. Collect. Duel.", 84, 1400)
    card.alpha_composite(words, ((W - words.width) // 2, 560 + logo.height))
    small = _font("Barlow-Medium.ttf", 42)
    line = "Offline  ·  No ads  ·  No account needed"
    ImageDraw.Draw(card).text(((W - small.getlength(line)) / 2, 560 + logo.height + words.height + 6), line, font=small,
                              fill=TEXT_DIM)
    return card


def _run(args: list[str]) -> None:
    subprocess.run([FFMPEG, "-v", "error", "-y", *args], cwd=PROJECT, check=True)


def build() -> None:
    work = OUT / "build"
    work.mkdir(parents=True, exist_ok=True)
    _base_layer().save(work / "base.png")
    mask = Image.new("L", (PHONE_W, PHONE_H), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, PHONE_W - 1, PHONE_H - 1), 34, fill=255)
    mask.save(work / "mask.png")
    _end_card().save(work / "end.png")
    parts = []
    for i, (clip, start, seconds, heading, line, dino_id) in enumerate(SHOTS):
        _text_layer(heading, line, dino_id, i).save(work / f"text_{i}.png")
        part = work / f"shot_{i}.mp4"
        blur = f"scale=480:854,crop=480:270:0:292,boxblur=10:3,scale={W}:{H},eq=brightness=-0.1:saturation=1.15"
        _run(["-ss", str(start), "-t", str(seconds), "-i", str(CLIPS_DIR / f"{clip}.avi"),
              "-loop", "1", "-t", str(seconds), "-i", str(work / "base.png"),
              "-loop", "1", "-t", str(seconds), "-i", str(work / f"text_{i}.png"),
              "-loop", "1", "-t", str(seconds), "-i", str(work / "mask.png"),
              "-filter_complex",
              f"[0:v]fps={FPS},split=2[a][b];[a]{blur}[bg];"
              f"[b]scale={PHONE_W}:{PHONE_H}:flags=lanczos,format=rgba[p];[3:v]format=gray[m];[p][m]alphamerge[phone];"
              f"[bg][1:v]overlay=0:0[l1];[l1][phone]overlay={PHONE_X}:{PHONE_Y}[l2];"
              f"[2:v]format=rgba,fade=t=in:st=0:d=0.35:alpha=1[t];[l2][t]overlay=0:0,format=yuv420p[v];"
              f"[0:a]aresample=48000,aformat=channel_layouts=stereo[s]",
              "-map", "[v]", "-map", "[s]", "-t", str(seconds), "-r", str(FPS),
              "-c:v", "libx264", "-crf", "15", "-preset", "medium", "-c:a", "pcm_s16le", str(part.with_suffix(".mkv"))])
        parts.append((part.with_suffix(".mkv"), seconds))
    end = work / "end.mkv"
    _run(["-loop", "1", "-t", str(END_SECONDS), "-i", str(work / "end.png"),
          "-f", "lavfi", "-t", str(END_SECONDS), "-i", "anullsrc=r=48000:cl=stereo",
          "-filter_complex", f"[0:v]fps={FPS},format=yuv420p[v]", "-map", "[v]", "-map", "1:a",
          "-c:v", "libx264", "-crf", "15", "-c:a", "pcm_s16le", str(end)])
    parts.append((end, END_SECONDS))

    # Cross-fade the shots together, then lay the music under the game's sound effects.
    inputs, chain, offset = [], [], 0.0
    for path, _ in parts:
        inputs += ["-i", str(path)]
    video, audio = "[0:v]", "[0:a]"
    for i in range(1, len(parts)):
        offset += parts[i - 1][1] - XFADE
        chain.append(f"{video}[{i}:v]xfade=transition=fade:duration={XFADE}:offset={offset:.3f}[v{i}]")
        chain.append(f"{audio}[{i}:a]acrossfade=d={XFADE}[a{i}]")
        video, audio = f"[v{i}]", f"[a{i}]"
    total = sum(seconds for _, seconds in parts) - XFADE * (len(parts) - 1)
    music = len(parts)
    chain.append(f"[{music}:a]atrim=0:{total:.3f},volume=0.55,afade=t=in:d=0.3,afade=t=out:st={total - 2:.3f}:d=2[m]")
    chain.append(f"{audio}volume=1.0[fx];[fx][m]amix=inputs=2:normalize=0:duration=longest,loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000[mix]")
    out = OUT / "dino_duel_trailer.mp4"
    _run([*inputs, "-stream_loop", "-1", "-i", str(MUSIC), "-filter_complex", ";".join(chain),
          "-map", video, "-map", "[mix]", "-t", f"{total:.3f}",
          "-c:v", "libx264", "-crf", "16", "-preset", "slow", "-profile:v", "high", "-pix_fmt", "yuv420p",
          "-r", str(FPS), "-c:a", "aac", "-b:a", "256k", "-ar", "48000", "-movflags", "+faststart", str(out)])
    print(f"Wrote {out.relative_to(PROJECT)} ({total:.1f} s)")


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "record":
        record()
    elif len(sys.argv) >= 3 and sys.argv[1] == "sheet":
        sheet(sys.argv[2])
    elif len(sys.argv) >= 2 and sys.argv[1] == "build":
        build()
    else:
        print(__doc__)
