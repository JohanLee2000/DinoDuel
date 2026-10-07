# Dino Duel

Godot 4.7 (GDScript) portrait mobile game for Android: collect dinosaur cards, battle rival AIs in a Herd Battle. Design decisions live in [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md); Jo makes the design calls, so propose options for anything not decided there.

## Layout
- `core/`: pure game logic, no nodes or UI. `DinoDef`/`RivalDef`/`DinoCatalog` resources, `HerdRules`, and `core/battle/` (engine, state, AI). Keep it deterministic and UI-free so it can run in sims, tests, and a future PvP server.
- `data/`: `.tres` resources (dinos, catalog, rivals). New dinos must be added to `data/dino_catalog.tres`.
- `app/session.gd`: `Session` autoload (cross-scene state).
- `ui/`: scenes and their scripts (`herd_select/`, `battle/`, shared `common/`).
- `tests/`: tiny custom test runner; files named `test_*.gd` extending `res://tests/test_case.gd`.
- `tools/balance_sim.gd`: AI-vs-AI balance report.

## Commands (Git Bash)
```bash
GODOT="/c/Users/johan/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import                                  # register new class_names
"$GODOT" --headless --path . --script res://tests/run_tests.gd         # tests (exit 1 on failure)
"$GODOT" --headless --path . --script res://tools/balance_sim.gd -- 600  # balance report (~50s)
"$GODOT" --path . --write-movie captures/frame.png --fixed-fps 5 --quit-after 900 -- --autoplay  # AI plays both sides, frames to captures/
```
Test failures that are script errors print `SCRIPT ERROR` rather than `FAIL`; check output for both.

## Conventions
- Battle rules change → update `docs/GAME_DESIGN.md`, add a test, rerun the balance sim and check the "AI vs one-note bots" lines stay well above 50%.
- Placeholder art only (colored panels + initials) until the Blender pipeline exists. Don't use images from Jo's DinosaurDatabase project.
- Never commit keystores. Release keystore + password must be backed up by Jo.
