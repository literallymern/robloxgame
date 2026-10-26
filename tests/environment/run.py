#!/usr/bin/env python3
"""Run pure environment math and the actual service with an offline scheduler (no Studio)."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
LUAU = os.environ.get("LUAU", "luau")


def main():
    model_result = subprocess.run([LUAU, str(ROOT / "tests/environment/model.spec.luau")])
    if model_result.returncode:
        return model_result.returncode
    # Reuse the map harness's Roblox-style module loader, with a deliberately tiny runtime mock.
    loader_source = (ROOT / "tests/map/run.py").read_text()
    import ast
    tree = ast.parse(loader_source)
    prelude = next(
        ast.literal_eval(node.value)
        for node in tree.body
        if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "PRELUDE" for t in node.targets)
    )
    paths = {
        "ReplicatedStorage/Shared/Config/Environment": "src/shared/Config/Environment.luau",
        "ReplicatedStorage/Shared/Environment/Model": "src/shared/Environment/Model.luau",
        "Server/Services/EnvironmentService": "src/server/Services/EnvironmentService.luau",
    }
    chunks = [prelude]
    for name, path in paths.items():
        source = re.sub(r"^export type ", "type ", (ROOT / path).read_text(), flags=re.M)
        chunks.append(f'__sources["{name}"] = function(script, require)\n{source}\nend\n')
    chunks.append((ROOT / "tests/environment/service.spec.luau").read_text())
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as stream:
        stream.write("\n".join(chunks))
        bundle = stream.name
    try:
        return subprocess.run([LUAU, bundle]).returncode
    finally:
        os.unlink(bundle)


if __name__ == "__main__":
    raise SystemExit(main())
