"""Runs tools/journey_sim.gd in parallel and sums up how hard each Journey stage is.

Usage:
    python tools/journey_report.py [players] [trials] [processes]     (defaults: 48 12 12)

For each stage: the chance a simulated player wins when it first gets there (with the collection it
has then), against the target for that spot in the chapter; how many tries it took; how many dinos
it owned; and the day it got there (6 battles a day). Targets: docs/GAME_DESIGN.md, "Difficulty".
"""
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
GODOT = os.environ.get("GODOT", r"C:\Users\johan\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe")
# Target win chance by position in a chapter (5 rivals, then Rory); the finale is its own.
TARGETS = [80, 72, 66, 60, 55, 45]
FINALE_TARGET = 40


def run(players: int, seed: int, trials: int) -> list:
    out = subprocess.run([GODOT, "--headless", "--path", str(PROJECT), "--script", "res://tools/journey_sim.gd", "--",
                          str(players), str(seed), str(trials)], capture_output=True, text=True, timeout=1800)
    return [json.loads(line) for line in out.stdout.splitlines() if line.startswith("{")]


def main() -> None:
    players = int(sys.argv[1]) if len(sys.argv) > 1 else 48
    trials = int(sys.argv[2]) if len(sys.argv) > 2 else 12
    procs = int(sys.argv[3]) if len(sys.argv) > 3 else 12
    per = max(1, players // procs)
    with ThreadPoolExecutor(procs) as pool:
        batches = list(pool.map(lambda i: run(per, 1 + i * 1000, trials), range(procs)))
    runs = [r for batch in batches for r in batch]
    if not runs:
        sys.exit("no results (does the sim script run?)")
    ids = [s["id"] for s in runs[0]["stages"]]
    print(f"{len(runs)} simulated players, {trials} practice battles per stage\n")
    print(f"{'stage':17s} {'win %':>6s} {'target':>6s} {'tries':>6s} {'owned':>6s} {'day':>5s}  stuck")
    for i, sid in enumerate(ids):
        rows = [r["stages"][i] for r in runs]
        p = 100 * sum(s["p"] for s in rows) / len(rows)
        target = FINALE_TARGET if i == len(ids) - 1 else TARGETS[i % 6]
        tries = sum(s["attempts"] for s in rows) / len(rows)
        owned = sum(s["owned"] for s in rows) / len(rows)
        day = sum(s["day"] for s in rows) / len(rows)
        stuck = sum(1 for s in rows if s.get("stuck"))
        flag = "  <-- low" if p < target - 10 else ("  <-- high" if p > target + 10 else "")
        print(f"{sid:17s} {p:6.0f} {target:6d} {tries:6.1f} {owned:6.1f} {day:5.1f}  {stuck or ''}{flag}")
    ledger = {}
    for r in runs:
        for source, (clutches, amber) in r.get("ledger", {}).items():
            total = ledger.setdefault(source, [0, 0])
            total[0] += clutches
            total[1] += amber
    print("\nWhere the first 30 battles' clutches and Amber come from (per player):")
    for source, (clutches, amber) in sorted(ledger.items(), key=lambda kv: -kv[1][0]):
        print(f"  {source:14s} {clutches / len(runs):6.1f} clutches  {amber / len(runs):7.0f} Amber")
    days = {}
    for r in runs:
        for d, n in r.get("owned_on", {}).items():
            days.setdefault(int(d), []).append(n)
    print("Dinos owned by day: " + ", ".join(f"day {d}: {sum(v) / len(v):.0f}" for d, v in sorted(days.items())))
    print(f"\nWhole Journey: {sum(r['battles'] for r in runs) / len(runs):.0f} battles, "
          f"{sum(r['days'] for r in runs) / len(runs):.0f} days, ends owning {sum(r['owned'] for r in runs) / len(runs):.0f} dinos")


if __name__ == "__main__":
    main()
