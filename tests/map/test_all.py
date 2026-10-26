#!/usr/bin/env python3
"""Runs all offline map checks:

1. tests/map/heightfield.spec.luau (layout, roads, bridges, river, places, spawn) with the Luau CLI.
2. The property plots in MapLayout match the economy bot's GENESIS_PROPERTIES (name, city, type).
3. tests/map/landscape.spec.luau (river cascades, lakes, fields, road details, vegetation).
4. tests/map/builders.spec.luau: the real BuildMap script against a Roblox stand-in (about a minute).

Usage: python3 tests/map/test_all.py [--quick]     (needs `luau` on PATH or $LUAU; --quick skips 4)
"""

import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
BOT_CONSTANTS = os.path.join(ROOT, "discord", "bot", "src", "economy", "constants.js")


def bot_properties():
    with open(BOT_CONSTANTS, encoding="utf-8") as f:
        text = f.read()
    block = text[text.index("GENESIS_PROPERTIES") :]
    block = block[: block.index("];")]
    found = []
    for name, city, kind in re.findall(r"name: '((?:[^'\\]|\\.)*)', city: '([^']*)', type: '([^']*)'", block):
        found.append(f"{name.replace(chr(92), '')};{city};{kind}")
    return found


def main():
    result = subprocess.run(
        [sys.executable, os.path.join(HERE, "run.py"), os.path.join(HERE, "heightfield.spec.luau")],
        capture_output=True,
        text=True,
    )
    output = result.stdout + result.stderr
    failed = result.returncode != 0 or "ALL CHECKS PASSED" not in output
    layout = []
    for line in output.splitlines():
        if line.startswith("PROPERTIES "):
            layout = line[len("PROPERTIES ") :].split("|")
        elif not line.startswith("PASS"):
            print(line)
    passes = sum(1 for line in output.splitlines() if line.startswith("PASS"))
    print(f"{passes} Luau checks passed")

    bot = bot_properties()
    if sorted(bot) != sorted(layout) or len(bot) != 16:
        failed = True
        print("FAIL property plots differ from the bot's GENESIS_PROPERTIES")
        for entry in sorted(set(bot) - set(layout)):
            print("  only in the bot:", entry)
        for entry in sorted(set(layout) - set(bot)):
            print("  only in MapLayout:", entry)
    else:
        print(f"PASS property plots match the bot's {len(bot)} GENESIS_PROPERTIES (name, city, type)")

    result = subprocess.run(
        [sys.executable, os.path.join(HERE, "run.py"), os.path.join(HERE, "landscape.spec.luau")],
        capture_output=True,
        text=True,
    )
    output = result.stdout + result.stderr
    for line in output.splitlines():
        if not line.startswith("PASS"):
            print(line)
    passes = sum(1 for line in output.splitlines() if line.startswith("PASS"))
    print(f"{passes} landscape checks passed")
    if result.returncode != 0 or "ALL CHECKS PASSED" not in output:
        failed = True

    for spec in ("river-detail", "roads-realism", "vegetation-builders"):
        result = subprocess.run(
            [sys.executable, os.path.join(HERE, "run.py"), os.path.join(HERE, spec + ".spec.luau")],
            capture_output=True,
            text=True,
        )
        output = result.stdout + result.stderr
        for line in output.splitlines():
            if not line.startswith("PASS"):
                print(line)
        passes = sum(1 for line in output.splitlines() if line.startswith("PASS"))
        print(f"{passes} {spec} checks passed")
        if result.returncode != 0 or "ALL CHECKS PASSED" not in output:
            failed = True

    if "--quick" not in sys.argv:
        result = subprocess.run(
            [sys.executable, os.path.join(HERE, "run.py"), os.path.join(HERE, "builders.spec.luau")],
            capture_output=True,
            text=True,
        )
        output = result.stdout + result.stderr
        for line in output.splitlines():
            if line.startswith(("FAIL", "INFO")) or "error" in line.lower():
                print(line)
        passes = sum(1 for line in output.splitlines() if line.startswith("PASS"))
        print(f"{passes} builder checks passed")
        if result.returncode != 0 or "ALL CHECKS PASSED" not in output:
            failed = True

    print("RESULT:", "FAILED" if failed else "ALL PASSED")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
