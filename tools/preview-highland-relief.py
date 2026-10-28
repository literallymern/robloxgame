#!/usr/bin/env python3
"""Plot actual generator profiles; this is a geometry diagnostic, never a Studio screenshot.

Usage: LUAU=luau python3 tools/preview-highland-relief.py [output.png]
Requires matplotlib and the project's existing map test runner.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
SOURCE = '''local L = load("ReplicatedStorage/Shared/Config/MapLayout")
local hf = load("StudioTools/Map/Heightfield").new(L)
local cuts = { {1, 1, 2000}, {1, -1, -2000}, {2, 1, 700}, {2, -1, 2000} }
for index, cut in cuts do
    for distance = 3400, 5100, 8 do
        local x = if cut[1] == 1 then distance * cut[2] else cut[3]
        local z = if cut[1] == 2 then distance * cut[2] else cut[3]
        print(index, distance, hf.highland4.surface(x,z), (hf.surface(x,z)))
    end
end
'''


def main():
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as handle:
        handle.write(SOURCE)
        source = Path(handle.name)
    try:
        run = subprocess.run([sys.executable, str(ROOT / "tests/map/run.py"), str(source)],
                             cwd=ROOT, check=True, capture_output=True, text=True)
    finally:
        source.unlink(missing_ok=True)
    profiles = [[] for _ in range(4)]
    for line in run.stdout.splitlines():
        index, distance, before, after = line.split()
        profiles[int(index)-1].append(tuple(map(float, (distance, before, after))))
    fig, axes = plt.subplots(2, 2, figsize=(12, 7), sharey=True, layout="constrained")
    for ax, rows, title in zip(axes.flat, profiles, ["East highlands", "West highlands", "South of Kagundali", "Northern highlands"]):
        distance, before, after = zip(*rows)
        ax.plot(distance, before, color="#899094", lw=1.8, label="Saved highland-4 generator")
        ax.plot(distance, after, color="#34734b", lw=2.2, label="Active highland-5 generator")
        ax.fill_between(distance, after, color="#34734b", alpha=.08)
        ax.set(title=title, xlabel="Distance from map centre (studs)", ylabel="Elevation (studs)", ylim=(0, 1050))
        ax.grid(alpha=.16)
        ax.spines[["right", "top"]].set_visible(False)
    axes[0, 0].legend(frameon=False, fontsize=8)
    fig.suptitle("Terrain generator profiles — mathematical diagnostic, not Roblox Studio rendering", fontsize=13)
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs/game/highland-5-profiles.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(target, dpi=150)
    print(target.resolve())


if __name__ == "__main__":
    main()
