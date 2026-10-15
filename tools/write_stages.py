"""Writes the Journey stages (data/rivals/*.tres) from tools/journey_stages.json.

Usage:
    python tools/write_stages.py                         rewrite every stage from the JSON
    python tools/write_stages.py '{"pip": {"temp": 0.05}}'   change fields first (saved back to the JSON)

Fields per stage: id, name, chapter, character, boss, brings (6 dino ids), alphas, cap (point cap),
meteor (meteor turn, 0 = usual), temp (AI temperature), biases, habits, habit_strength, learns, intro.
Tune difficulty with python tools/journey_report.py (docs/GAME_DESIGN.md, "Difficulty").
"""
import json, random, string, sys
from pathlib import Path
spec_path = Path(__file__).parent / "journey_stages.json"
spec = json.loads(spec_path.read_text(encoding="utf-8"))
overrides = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}
by_id = {s["id"]: s for s in spec}
for sid, fields in overrides.items():
    by_id[sid].update(fields)
spec_path.write_text(json.dumps(spec, indent=1), encoding="utf-8")
rng = random.Random(1015)
key = lambda: "".join(rng.choice(string.ascii_lowercase + string.digits) for _ in range(5))
OUT = Path(__file__).resolve().parent.parent / "data" / "rivals"
for old in OUT.glob("*.tres"):
    old.unlink()
for st in spec:
    assert len(st["brings"]) == 6 and len(set(st["brings"])) == 6, st["id"]
    for d in st["brings"]:
        assert (OUT.parent / "dinos" / f"{d}.tres").exists(), d
    for a in st["alphas"]:
        assert a in st["brings"], (st["id"], a)
    k = key()
    lines = ['[gd_resource type="Resource" script_class="RivalDef" format=3]', "",
             f'[ext_resource type="Script" path="res://core/dino_def.gd" id="1_{k}"]']
    refs = []
    for i, d in enumerate(st["brings"]):
        rid = f"{i + 2}_{key()}"
        lines.append(f'[ext_resource type="Resource" path="res://data/dinos/{d}.tres" id="{rid}"]')
        refs.append(rid)
    lines.append(f'[ext_resource type="Script" path="res://core/rival_def.gd" id="9_{k}"]')
    lines += ["", "[resource]", f'script = ExtResource("9_{k}")', f'id = &"{st["id"]}"', f'display_name = "{st["name"]}"',
              f'intro = "{st["intro"]}"',
              f'brings = Array[ExtResource("1_{k}")]([' + ", ".join(f'ExtResource("{r}")' for r in refs) + "])"]
    if st["cap"] != 10:
        lines.append(f'point_cap = {st["cap"]}')
    lines.append(f'chapter = {st["chapter"]}')
    if st["boss"]:
        lines.append("is_boss = true")
    lines.append(f'character = &"{st["character"]}"')
    if st["alphas"]:
        lines.append("alphas = Array[StringName]([" + ", ".join(f'&"{a}"' for a in st["alphas"]) + "])")
    if st["meteor"]:
        lines.append(f'meteor_turn = {st["meteor"]}')
    lines.append(f'temperature = {st["temp"]}')
    for b, v in st["biases"].items():
        lines.append(f"{b} = {v}")
    if st["habits"]:
        lines.append("habits = Array[StringName]([" + ", ".join(f'&"{h}"' for h in st["habits"]) + "])")
    if st["habit_strength"] != 1.0:
        lines.append(f'habit_strength = {st["habit_strength"]}')
    if not st["learns"]:
        lines.append("learns_habits = false")
    (OUT / f'{st["id"]}.tres').write_bytes(("\n".join(lines) + "\n").encode("utf-8"))
print(len(spec), "stages written")
