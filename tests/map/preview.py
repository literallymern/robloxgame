#!/usr/bin/env python3
"""Renders a preview image of the generated terrain (needs Pillow and numpy).

Usage: python3 tests/map/preview.py output.png
"""

import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
COLOURS = {  # material code -> RGB, codes as in Heightfield.Materials
    1: (106, 152, 74),  # Grass
    2: (88, 128, 62),  # LeafyGrass
    3: (128, 122, 114),  # Rock
    4: (140, 116, 88),  # Ground
    5: (92, 76, 60),  # Mud
    6: (176, 172, 164),  # Pavement
    7: (64, 64, 68),  # Asphalt
    8: (196, 180, 140),  # Sand
    9: (110, 110, 118),  # Slate
    10: (70, 68, 70),  # Basalt
}


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:  # older Pillow
        return ImageFont.load_default()


def annotate(img, half, scale, roads, places):
    """Names, road numbers, legend, scale bar and north arrow (scale = studs per pixel)."""
    draw = ImageDraw.Draw(img)

    def px(x, z):
        return ((x + half) / scale, (z + half) / scale)

    def text(xy, label, size, fill=(255, 255, 255)):
        f = font(size)
        width = draw.textlength(label, font=f)
        x = min(max(xy[0], width / 2 + 6), img.width - width / 2 - 6)
        draw.text((x, xy[1]), label, font=f, fill=fill, anchor="mm", stroke_width=3, stroke_fill=(20, 20, 20))

    for kind, x, z, name in places:
        if kind != "Plot":
            text(px(x, z), name, 22 if kind == "City" else 13)
    for road_id, cls, pts in roads:
        if cls != "Access":
            x, z = pts[len(pts) // 2]
            text(px(x, z), road_id, 15, (255, 230, 120))
    legend = [
        ((250, 210, 60), "National road (N)"),
        ((255, 255, 255), "Regional road (R)"),
        ((230, 160, 90), "Access road"),
        ((54, 110, 170), "River and lakes"),
        ((255, 40, 40), "Bridge"),
        ((176, 172, 164), "City (paved, flat)"),
        ((140, 116, 88), "Facility / mine yard"),
        ((80, 200, 120), "Property plot (bot)"),
        ((40, 76, 40), "Trees (dot per tree)"),
        ((214, 190, 90), "Field (outline)"),
    ]
    # Top left: the boundary mountains, where the legend hides nothing important.
    x0, y0 = 22, 22
    bottom = y0 + 26 * len(legend) + 40
    draw.rectangle([x0 - 10, y0 - 10, x0 + 250, bottom], fill=(20, 20, 20))
    for i, (colour, label) in enumerate(legend):
        y = y0 + i * 26
        draw.rectangle([x0, y + 4, x0 + 26, y + 18], fill=colour)
        draw.text((x0 + 36, y + 11), label, font=font(15), fill=(240, 240, 240), anchor="lm")
    bar = 1000 / scale
    y = bottom - 26
    draw.rectangle([x0, y, x0 + bar, y + 8], fill=(240, 240, 240))
    draw.text((x0 + bar + 10, y + 4), "1,000 studs", font=font(15), fill=(240, 240, 240), anchor="lm")
    nx, ny = img.width - 50, 60
    draw.polygon([(nx, ny - 30), (nx - 12, ny + 6), (nx + 12, ny + 6)], fill=(240, 240, 240))
    text((nx, ny + 22), "N", 20)


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else "map-preview.png"
    result = subprocess.run(
        [sys.executable, os.path.join(HERE, "run.py"), os.path.join(HERE, "preview.luau")],
        capture_output=True,
        text=True,
        check=True,
    )
    lines = result.stdout.splitlines()
    _, n, step, half = lines[0].split()
    n, step, half = int(n), int(step), int(half)
    heights = np.zeros((n, n))
    mats = np.zeros((n, n), dtype=int)
    water = np.zeros((n, n))
    for iz in range(n):
        for ix, cell in enumerate(lines[1 + iz].split(" ")):
            h, m, w = cell.split(",")
            heights[iz, ix], mats[iz, ix], water[iz, ix] = float(h), int(m), float(w)
    roads, bridges, places, rects, fields, barns, trees = [], [], [], [], [], [], []
    for line in lines[1 + n :]:
        parts = line.split(" ")
        if parts[0] == "ROAD":
            roads.append((parts[1], parts[2], [tuple(map(float, p.split(","))) for p in parts[3:]]))
        elif parts[0] == "BRIDGE":
            bridges.append((parts[1], float(parts[2]), float(parts[3])))
        elif parts[0] == "RECT":
            rects.append((parts[1], *map(float, parts[2:6])))
        elif parts[0] == "FIELD":
            fields.append((parts[1], *map(float, parts[2:6])))
        elif parts[0] == "BARN":
            barns.append((float(parts[1]), float(parts[2])))
        elif parts[0] == "TREES":
            for item in parts[1:]:
                kind, x, z, size = item.split(",")
                trees.append((kind, float(x), float(z), float(size)))
        elif parts[0] == "PLACE":
            kind, x, z = parts[1], float(parts[2]), float(parts[3])
            places.append((kind, x, z, " ".join(parts[4:])))

    # Hillshade from the north-west.
    gz, gx = np.gradient(heights, step)
    shade = np.clip(0.75 + (-gx * -0.7 + -gz * -0.7) * 0.9, 0.35, 1.25)
    rgb = np.zeros((n, n, 3))
    for code, colour in COLOURS.items():
        rgb[mats == code] = colour
    rgb *= shade[..., None]
    wet = water > heights
    rgb[wet] = (54, 110, 170)
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
    draw = ImageDraw.Draw(img)

    def px(x, z):
        return ((x + half) / step, (z + half) / step)

    rect_colours = {"Runway": (45, 45, 50), "Apron": (150, 148, 142), "Plot": (80, 200, 120), "Block": (214, 206, 190)}
    for kind, x0, x1, z0, z1 in rects:
        a, b = px(x0, z0), px(x1, z1)
        draw.rectangle([a[0], a[1], max(b[0], a[0] + 2), max(b[1], a[1] + 2)], fill=rect_colours[kind])
    for _, cls, pts in roads:
        colour = (250, 210, 60) if cls == "National" else (255, 255, 255) if cls == "Regional" else (230, 160, 90)
        draw.line([px(x, z) for x, z in pts], fill=colour, width=2 if cls != "Access" else 1)
    for _, x, z in bridges:
        cx, cz = px(x, z)
        draw.ellipse([cx - 4, cz - 4, cx + 4, cz + 4], outline=(255, 40, 40), width=2)
    img = img.resize((n * 2, n * 2), Image.LANCZOS)
    # Fields, barns and trees on the enlarged image (2 pixels per grid step).
    draw = ImageDraw.Draw(img)

    def px2(x, z):
        return ((x + half) / step * 2, (z + half) / step * 2)

    crop_colours = {
        "Tobacco": (120, 150, 60),
        "Maize": (214, 190, 90),
        "Fallow": (150, 104, 70),
        "Meadow": (150, 190, 100),
        "Pasture": (190, 210, 140),
    }
    for crop, x0, x1, z0, z1 in fields:
        a, b = px2(x0, z0), px2(x1, z1)
        draw.rectangle([a[0], a[1], b[0], b[1]], outline=crop_colours.get(crop, (214, 190, 90)), width=1)
    for x, z in barns:
        cx, cz = px2(x, z)
        draw.rectangle([cx - 3, cz - 2, cx + 3, cz + 2], fill=(116, 74, 52))
    tree_colours = {"B": (30, 62, 30), "P": (18, 42, 26), "E": (70, 92, 64), "A": (78, 86, 36)}
    for kind, x, z, size in trees:
        cx, cz = px2(x, z)
        r = max(1.6, size / step * 0.5)
        draw.ellipse([cx - r, cz - r, cx + r, cz + r], fill=tree_colours.get(kind, (40, 76, 40)))
    for _, cls, pts in roads:
        colour = (250, 210, 60) if cls == "National" else (255, 255, 255) if cls == "Regional" else (230, 160, 90)
        draw.line([px2(x, z) for x, z in pts], fill=colour, width=3 if cls != "Access" else 2)
    annotate(img, half, step / 2, roads, places)
    img.save(out_path)
    print(f"wrote {out_path}: {n}x{n} samples, heights {heights.min():.0f}..{heights.max():.0f}")


if __name__ == "__main__":
    main()
