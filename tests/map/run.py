#!/usr/bin/env python3
"""Runs a Luau test script against the pure map modules, outside Roblox Studio.

The map modules use Roblox-style requires (require(script.Parent.Geometry)). This runner
bundles them into one file with a tiny stand-in for `script` and `require`, then runs it with
the Luau command line tool (https://github.com/luau-lang/luau, `luau` on PATH or $LUAU).

Usage: python3 tests/map/run.py tests/map/heightfield.spec.luau [arguments for the script]
"""

import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# Module path as Roblox sees it (after Rojo) -> file in the repository.
MODULES = {
    "ReplicatedStorage/Shared/Config/MapLayout": "src/shared/Config/MapLayout.luau",
    "ReplicatedStorage/Shared/Config/Assets": "src/shared/Config/Assets.luau",
    "ReplicatedStorage/Shared/Config/Environment": "src/shared/Config/Environment.luau",
    "StudioTools/BuildMap": "src/studio/BuildMap.luau",
    "StudioTools/CheckEnvironment": "src/studio/CheckEnvironment.luau",
    "StudioTools/UpgradeKagundali": "src/studio/UpgradeKagundali.luau",
    "StudioTools/UseCreatorStoreAssets": "src/studio/UseCreatorStoreAssets.luau",
}
for folder, prefix in (
    ("src/studio/Map", "StudioTools/Map"),
    ("src/studio/Map/Builders", "StudioTools/Map/Builders"),
    ("src/shared/Environment", "ReplicatedStorage/Shared/Environment"),
):
    for file in sorted(os.listdir(os.path.join(ROOT, folder))):
        if file.endswith(".luau"):
            MODULES[f"{prefix}/{file[:-5]}"] = f"{folder}/{file}"

PRELUDE = r"""
local __sources = {}
local __cache = {}
local function __node(path)
	return setmetatable({ __path = path }, {
		__index = function(_, key)
			if key == "Parent" then
				return __node(string.match(path, "^(.*)/[^/]+$") or "")
			elseif key == "WaitForChild" or key == "FindFirstChild" then
				return function(_, name)
					return __node(path .. "/" .. name)
				end
			end
			return __node(if path == "" then key else path .. "/" .. key)
		end,
	})
end
local function __require(node)
	local path = rawget(node, "__path")
	if __cache[path] == nil then
		local loader = __sources[path]
		assert(loader, "module not bundled: " .. tostring(path))
		__cache[path] = loader(__node(path), __require)
	end
	return __cache[path]
end
-- For test scripts: load("StudioTools/Map/Heightfield")
function load(path)
	return __require(__node(path))
end
__requireNode = __node
"""


def module_source(name, path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        text = f.read()
    # `export type` is only allowed at the top of a file; inside the wrapper it becomes `type`.
    text = re.sub(r"^export type ", "type ", text, flags=re.M)
    return f'__sources["{name}"] = function(script, require)\n{text}\nend\n'


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    spec = sys.argv[1]
    parts = [PRELUDE]
    with open(spec, encoding="utf-8") as f:
        spec_text = f.read()
    if "needs: roblox-mock" in spec_text:
        with open(os.path.join(ROOT, "tests", "map", "roblox-mock.luau"), encoding="utf-8") as f:
            parts.append("do\n" + re.sub(r"^--!\w+.*$", "", f.read(), flags=re.M) + "\nend\n")
    for name, path in MODULES.items():
        parts.append(module_source(name, path))
    parts.append("do\n" + re.sub(r"^--!\w+.*$", "", spec_text, flags=re.M) + "\nend\n")
    luau = os.environ.get("LUAU", "luau")
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as out:
        out.write("".join(parts))
        bundle = out.name
    try:
        args = [luau, "-O2", bundle]
        if len(sys.argv) > 2:
            args += ["-a"] + sys.argv[2:]
        return subprocess.call(args)
    finally:
        os.unlink(bundle)


if __name__ == "__main__":
    sys.exit(main())
