# Avatar portraits

Fossil Hunter ID avatars (`ui/common/avatar.gd`, rules in `core/collection/hunter_id.gd`):

- **Dinos**: any dino you own. Drawn as rounded squares, framed in the dino's tier color (`Palette.RARITY_COLORS`: N grey, R green, SR purple, SSR gold, UR pink). Never Shiny (Jo, 2026-11-04).
- **Rivals and the Professaur**: circles. The picker lists every Journey rival. The ones you haven't beaten yet show as dark shapes with a lock until you clear their stage.

## Dino portraits

Each dino has a 256 px portrait in `assets/dinos/avatars/<id>.webp`. Each one is cropped from the full painting around its face box in `assets/dinos/faces.json` (checked with `python tools/preview_faces.py`). The crop is widened 1.65 times and shifted down a little to keep the neck, crest and shoulders. The same framing lives in `Avatar.portrait_box` and in the build tool, so change both together. New art without a portrait falls back to cropping the card thumbnail the same way. The avatar grid never loads full paintings.

After changing a painting or `faces.json`, rebuild:

```bash
"$GODOT" --headless --path . --script res://tools/build_avatar_portraits.gd
"$GODOT" --headless --path . --import
python tools/prepare_art.py --fix-imports
"$GODOT" --headless --path . --import
```

The portraits are saved as lossy WebP at quality 0.9, about 25 KB each (lossless was about 90 KB). `--fix-imports` turns on mipmaps, so they stay smooth when drawn small (66 px in the top bar).
