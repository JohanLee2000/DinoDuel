# Dino Duel

Godot 4.7 (GDScript) portrait mobile game for Android: collect dinosaur cards, battle rival AIs in a Party Battle. Design decisions live in [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md); Jo makes the design calls, so propose options for anything not decided there.

## Layout
- `core/`: pure game logic, no nodes or UI. `DinoDef`/`RivalDef`/`DinoCatalog` resources, `PartyRules`, `core/battle/` (engine, state, AI), and `core/collection/` (`PlayerProfile` save model, `Economy` numbers). Keep it deterministic and UI-free so it can run in sims, tests, and a future PvP server.
- `data/`: `.tres` resources (dinos, catalog, rivals). New dinos must be added to `data/dino_catalog.tres`.
- `app/session.gd`: `Session` autoload (profile, navigation, cross-scene state). `app/save_store.gd`: JSON save in `user://` with backup.
- `ui/`: `main/` (tab shell, new-player intro), `tabs/` (Battle, Party, Eggs, Dex, Goals; built in code with `UiKit`), `pre_battle/`, `battle/`, `eggs/` (egg + hatch view), shared `common/`.
- `tests/`: tiny custom test runner; files named `test_*.gd` extending `res://tests/test_case.gd`.
- `tools/balance_sim.gd`: AI-vs-AI balance report.

## Commands (Git Bash)
```bash
GODOT="/c/Users/johan/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import                                  # register new class_names
"$GODOT" --headless --path . --script res://tests/run_tests.gd         # tests (exit 1 on failure)
"$GODOT" --headless --path . --script res://tools/balance_sim.gd -- 600  # balance report (~50s)
"$GODOT" --path . --write-movie captures/frame.png --fixed-fps 5 --quit-after 600 -- --autoplay  # AI plays a battle + hatches, throwaway save
"$GODOT" --path . --write-movie captures/dex.png --fixed-fps 5 --quit-after 4 -- --sandbox --tab=3 --open-dex=t_rex  # screenshot a tab/popup
```
Dev flags (after `--`): `--autoplay`, `--sandbox` (reuse the autoplay save), `--tab=N` (0 Battle, 1 Party, 2 Eggs, 3 Dex, 4 Goals), `--open-dex=<id>`, `--open-card=<id>[:shiny]` (full-screen view of any card), `--open=settings|help|help:N|checkin` (N = page number), `--dex-era=N` (scroll the Dex to an era), `--rival=<id>` (who `--autoplay` fights), `--store-shots` (showcase save for store screenshots, no DEV button), `--tutorial` (throwaway new save; with `--autoplay` the first battle is coached and the AI follows the tips), `--uncapped` (turns off the 60/30 fps cap and screen-sleep handling in `app/power.gd`, for measuring), `--tab-timing` (opens every tab twice and writes the times to `user://tab_timing.txt`; read it with `adb shell run-as <pkg> cat files/tab_timing.txt`), `--no-thumbs` (full paintings on every card, to compare), `--fresh-save` (wipes the real save). Debug builds on the phone read the same flags from `user://dev_args.txt` (push with adb, `run-as <pkg> cp` into `files/`; delete it afterwards). Movie Maker can't render taller than the monitor, so take phone-sized screenshots on the phone with `adb exec-out screencap -p`. Movie Maker paths are relative to the project folder; keep them in `captures/` (it has a `.gdignore`).

Android: `"$GODOT" --headless --path . --export-debug "Android" build/android/dino_duel_debug.apk`, then `"$ANDROID_HOME/platform-tools/adb.exe" install -r --no-incremental build/android/dino_duel_debug.apk` (check it prints `Success`). Play build: `"$GODOT" --headless --path . --export-release "Google Play" build/play/dino_duel.aab` (Gradle; needs the `android/` build template, reinstall with `--install-android-build-template` alongside an export, and the release keystore entered in the editor; bump `version/code` every upload). The Google Play preset includes 32-bit `armeabi-v7a` (budget phones like the Redmi A3 run 32-bit Android); the USB debug preset is 64-bit only to keep installs fast. Sound effects: `python tools/prepare_sfx.py <file> <name> [--add]` (levels and converts into `assets/audio/sfx/`; volumes per sound in `app/sound.gd`); music loops: `tools/make_music_loop.py`. Store assets and listing text: `docs/store/`; feature graphic: `"$GODOT" --path . --resolution 1024x500 res://tools/feature_graphic.tscn`.
The Godot editor rewrites `export_presets.cfg` from memory whenever the Export window changes, so close the editor before editing that file by hand (or the edit is silently reverted). Package `com.dinoduelstudios.dinoduel` (changed from com.leejohan.dinoduel on 2026-10-08) becomes permanent once uploaded to Google Play.
Test failures that are script errors print `SCRIPT ERROR` rather than `FAIL`; check output for both.

## Conventions
- Battle rules change → update `docs/GAME_DESIGN.md`, add a test, rerun the balance sim and check the "AI vs one-note bots" lines stay well above 50%.
- Visual style follows Jo's concept sheet `docs/concept/card_concept_sheet.webp` (see docs/GAME_DESIGN.md). Cards are drawn in code by `ui/common/dino_card.gd` (layout in fractions of card width) with shaders in `ui/common/*.gdshader`; icons are SVG strings in `ui/common/icons.gd`, rendered at display size; fonts via `ui/common/fonts.gd`. Tiers are N/R/SR/SSR/UR (`DinoDef.Rarity` COMMON..LEGENDARY, stored as ints). Paintings are found by file name in `assets/dinos/` (`ui/common/dino_art.gd`); `tools/prepare_art.py` resizes ChatGPT output into place (docs/ART_BRIEF.md) and writes the 360 px thumbnail in `assets/dinos/thumbs/` that every card smaller than the full-screen view uses (`--thumbs` rebuilds them all). New thumbnails need mipmaps: run `--import` once, set `mipmaps/generate=true` in their `.import` files, and import again. Never load full paintings for grids of cards: decoding them made the Dex take 1.1-1.3 s to open on Jo's phone (2026-10-09); thumbnails, kept in memory once loaded, take ~0.1 s. Branding lives in `assets/branding/` (`tools/extract_branding.py`). Don't use images from Jo's DinosaurDatabase project.
- Labels created in code inside rows/grids need `wrap = false` (`UiKit.label`/`UiKit.title`), or they collapse to one letter per line.
- Keep it light on battery: `app/power.gd` caps frames (60 while touching, 30 after 8 s idle) and only keeps the screen awake in battles and hatching. Don't run per-frame full-screen procedural shaders for things that never change; bake them once (see `ui/common/backdrop.gd`). Measured 2026-10-09 on Jo's Galaxy A35 (120 Hz): before, ~105-120 fps and the GPU at 62-69% of full power even on an idle menu; after, 30 fps and ~16% (31% while scrolling), 0% in the background.
- Never commit keystores. Release keystore + password must be backed up by Jo.
- Before any production/release work, go through [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) with Jo (e.g. deleting the DEV unlock button in the Dex).
