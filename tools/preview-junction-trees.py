#!/usr/bin/env python3
"""Inspect exact original tree primitives outside Roblox; never a game AFTER screenshot."""
import importlib.util
from pathlib import Path
import math
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("preview", ROOT / "tools/preview-canopies.py")
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)


def sphere():
    points, faces = [], []
    rings, sides = 6, 12
    for ring in range(rings + 1):
        latitude = math.pi * ring / rings
        for side in range(sides):
            angle = 2 * math.pi * side / sides
            points.append((math.sin(latitude) * math.cos(angle) / 2, math.cos(latitude) / 2, math.sin(latitude) * math.sin(angle) / 2))
    for ring in range(rings):
        for side in range(sides):
            a, b = ring * sides + side, ring * sides + (side + 1) % sides
            faces.extend([(a, b, b + sides), (a, b + sides, a + sides)])
    return np.array(points), faces


def main():
    output = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs/game/kagundali-tree-sources.png"
    result = subprocess.run([sys.executable, str(ROOT / "tests/map/run.py"), str(ROOT / "tests/map/preview-junction.luau")], check=True, capture_output=True, text=True)
    groups = {}
    palette = np.array([[82, 68, 51], [54, 80, 37], [68, 93, 43], [79, 103, 49]])
    for line in result.stdout.splitlines():
        tag, kind, group, form, *values = line.split()
        assert tag == "SOURCE"
        values = np.array(list(map(float, values)))
        p, faces = sphere() if form == "Ball" else preview.cylinder()
        frame = values[6:15].reshape(3, 3).T
        points = (p * values[3:6]) @ frame.T + values[:3]
        colour = palette[int(group) - 1]
        if kind == "Eucalyptus":
            colour = np.array([161, 153, 133]) if group == "1" else colour * .7 + np.array([105, 126, 96]) * .3
        groups.setdefault(kind, []).append((points, faces, colour))
    image = Image.new("RGB", (1680, 840), (244, 246, 239))
    draw = ImageDraw.Draw(image)
    draw.text((24, 18), "KAGUNDALI · NEUE ORIGINAL-BAUMVORLAGEN", fill=(30, 51, 35), font=preview.font(25, True))
    draw.text((24, 55), "Quellgeometrie: KEIN Roblox-Render und KEIN Nachher-Screenshot. CSG, Materialtexturen und Spielbeleuchtung sind nicht simuliert.", fill=(65, 79, 66), font=preview.font(15))
    for i, kind in enumerate(["Broadleaf", "Acacia", "Eucalyptus"]):
        image.paste(preview.render(groups[kind], 530, 420, 15), (24 + i * 552, 95))
        draw.text((36 + i * 552, 518), kind, fill=(30, 51, 35), font=preview.font(20, True))
    for i, kind in enumerate(["Shrub", "Fern"]):
        image.paste(preview.render(groups[kind], 530, 220, 15), (180 + i * 700, 570))
        draw.text((195 + i * 700, 793), kind, fill=(30, 51, 35), font=preview.font(19, True))
    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output)
    print(output)


if __name__ == "__main__":
    main()
