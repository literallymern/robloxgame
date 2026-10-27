#!/usr/bin/env python3
"""Render actual canopy source wedges and tree transforms; this is NOT a Studio render.

Requires NumPy and Pillow. Run from any directory:
  LUAU=... python3 tools/preview-canopies.py [output.png]
"""
from pathlib import Path
import math
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs/game/canopy-geometry-preview.png"
WEDGE = np.array([[-.5, -.5, -.5], [.5, -.5, -.5], [-.5, -.5, .5], [.5, -.5, .5], [-.5, .5, .5], [.5, .5, .5]])
WEDGE_FACES = [(0, 1, 3), (0, 3, 2), (2, 3, 5), (2, 5, 4), (0, 4, 5), (0, 5, 1), (0, 2, 4), (1, 5, 3)]
KINDS = ["Broadleaf", "Acacia", "Eucalyptus", "Pine", "Bush"]
COLOURS = {"Broadleaf": (68, 110, 56), "Acacia": (98, 123, 62), "Eucalyptus": (103, 129, 93), "Pine": (44, 83, 53), "Bush": (75, 109, 52)}


def rotation(rx, ry, rz):
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    return np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]]) @ np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]) @ np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])


def sources():
    result = subprocess.run([sys.executable, str(ROOT / "tests/map/run.py"), str(ROOT / "tests/map/preview-canopies.luau")], check=True, capture_output=True, text=True, cwd=ROOT)
    crowns, trees = {}, {}
    for line in result.stdout.splitlines():
        fields = line.split()
        if not fields:
            continue
        if fields[0] == "BLADE":
            key = fields[1], int(fields[2])
            geometry = fields[3]
            values = np.array(list(map(float, fields[4:])))
            if geometry == "Cylinder":
                raw_points, triangles = cylinder()
            else:
                raw_points, triangles = WEDGE, WEDGE_FACES
            transform = values[6:15].reshape(3, 3).T
            vertices = (raw_points * values[3:6]) @ transform.T + values[:3]
            crowns.setdefault(key, []).append((vertices, triangles))
        elif fields[0] == "TREE":
            kind, name, species, variant = fields[1], fields[2], fields[3], int(fields[4])
            values = np.array(list(map(float, fields[5:])))
            assert len(values) == 18, (line, len(values))
            trees.setdefault(kind, []).append((name, species, variant, values))
    return crowns, trees


def combined(primitives):
    vertices, faces = [], []
    for points, triangles in primitives:
        offset = len(vertices)
        vertices.extend(points)
        faces.extend(tuple(offset + x for x in tri) for tri in triangles)
    return np.array(vertices), faces


def cylinder():
    points, triangles = [], []
    sides = 12
    for x in (-.5, .5):
        for side in range(sides):
            a = side * 2 * math.pi / sides
            points.append((x, math.cos(a) / 2, math.sin(a) / 2))
    points.extend([(-.5, 0, 0), (.5, 0, 0)])
    for side in range(sides):
        nxt = (side + 1) % sides
        triangles.extend([(side, nxt, nxt + sides), (side, nxt + sides, side + sides), (2 * sides, nxt, side), (2 * sides + 1, side + sides, nxt + sides)])
    return np.array(points), triangles


def mesh_tree(kind, data, crowns):
    pieces = []
    for _name, species, variant, values in data:
        position, size = values[:3], values[3:6]
        transform = values[6:15].reshape(3, 3).T
        colour = values[15:18] * 255
        # Export has 3 position +3 size +9 axes +3 colour =18 values.
        if species == "Stem":
            points, triangles = cylinder()
        else:
            points, triangles = combined(crowns[(species, variant)])
            low, high = points.min(axis=0), points.max(axis=0)
            points = (points - (low + high) / 2) / (high - low)
        pieces.append(((points * size) @ transform.T + position, triangles, colour))
    return pieces


def font(size, bold=False):
    path = "/usr/share/fonts/truetype/dejavu/DejaVuSans" + ("-Bold.ttf" if bold else ".ttf")
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def render(pieces, width, height, padding=15):
    forward = np.array([-3., -1.8, -4.])
    forward /= np.linalg.norm(forward)
    right = np.cross(forward, [0, 1, 0]); right /= np.linalg.norm(right)
    up = np.cross(right, forward)
    basis = np.array([right, up, forward]).T
    all_points = np.concatenate([p @ basis for p, _, _ in pieces])
    low, high = all_points[:, :2].min(axis=0), all_points[:, :2].max(axis=0)
    scale = min((width - 2 * padding) / (high[0] - low[0]), (height - 2 * padding) / (high[1] - low[1]))
    centre = (low + high) / 2
    colour_buffer = np.full((height, width, 3), (234, 239, 229), dtype=np.uint8)
    depth = np.full((height, width), np.inf)
    sun = np.array([-.45, .85, .3]); sun /= np.linalg.norm(sun)
    for points, faces, base_colour in pieces:
        camera = points @ basis
        xy = (camera[:, :2] - centre) * [scale, -scale] + [width / 2, height / 2]
        for indices in faces:
            tri = xy[list(indices)]
            minx, miny = np.maximum(np.floor(tri.min(axis=0)).astype(int), 0)
            maxx, maxy = np.minimum(np.ceil(tri.max(axis=0)).astype(int), [width - 1, height - 1])
            if maxx < minx or maxy < miny:
                continue
            a, b, c = tri
            denominator = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(denominator) < 1e-9:
                continue
            xx, yy = np.meshgrid(np.arange(minx, maxx + 1) + .5, np.arange(miny, maxy + 1) + .5)
            wa = ((b[1] - c[1]) * (xx - c[0]) + (c[0] - b[0]) * (yy - c[1])) / denominator
            wb = ((c[1] - a[1]) * (xx - c[0]) + (a[0] - c[0]) * (yy - c[1])) / denominator
            wc = 1 - wa - wb
            z = wa * camera[indices[0], 2] + wb * camera[indices[1], 2] + wc * camera[indices[2], 2]
            target_depth = depth[miny:maxy + 1, minx:maxx + 1]
            visible = (wa >= 0) & (wb >= 0) & (wc >= 0) & (z < target_depth)
            target_depth[visible] = z[visible]
            normal = np.cross(points[indices[1]] - points[indices[0]], points[indices[2]] - points[indices[0]])
            norm = np.linalg.norm(normal)
            shade = .55 + .45 * abs(float(np.dot(normal / norm, sun))) if norm else .7
            target = colour_buffer[miny:maxy + 1, minx:maxx + 1]
            target[visible] = np.clip(np.asarray(base_colour) * shade, 0, 255).astype(np.uint8)
    return Image.fromarray(colour_buffer)


def main():
    crowns, trees = sources()
    image = Image.new("RGB", (1600, 1120), (244, 246, 239))
    draw = ImageDraw.Draw(image)
    draw.text((28, 18), "RO-NATION · OPEN CANOPY GEOMETRY", fill=(30, 51, 35), font=font(27, True))
    draw.text((28, 55), "Offline source-triangle preview — NOT a Roblox Studio render. Native material textures and engine CSG are not simulated.", fill=(65, 79, 66), font=font(16))
    for index, kind in enumerate(KINDS[:4]):
        pieces = mesh_tree(kind, trees[kind], crowns)
        image.paste(render(pieces, 380, 310, 22), (22 + index * 395, 94))
        draw.text((36 + index * 395, 406), kind, fill=(30, 51, 35), font=font(20, True))
    draw.text((28, 451), "Saved source-library silhouettes · four deterministic variants per species", fill=(30, 51, 35), font=font(19, True))
    for row in range(4):
        for col, kind in enumerate(KINDS):
            points, faces = combined(crowns[(kind, row + 1)])
            image.paste(render([(points, faces, COLOURS[kind])], 294, 124, 12), (27 + col * 315, 488 + row * 151))
            draw.text((35 + col * 315, 614 + row * 151), f"{kind} {row + 1}", fill=(46, 65, 47), font=font(14))
    draw.text((28, 1095), "Each crown reuses one native CSG part compiled from 151–184 tapered leaf/twig primitives; trees stay at 4–5 streamed parts.", fill=(65, 79, 66), font=font(14))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    main()
