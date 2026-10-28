--!nocheck
-- needs: roblox-mock
local M = load("StudioTools/Map/Builders/JunctionMarkings")
local U = load("StudioTools/Map/Builders/Util")
local passed = 0
local function check(ok, message)
	assert(ok, message)
	passed += 1
	print("PASS " .. message)
end
local a, b = Vector3.new(0, 50, 3300), Vector3.new(900, 50, 3300)
local function fixture()
	local root = Instance.new("Folder")
	local folder = U.folder(U.folder(root, "RoadDetails"), "Markings")
	local line = U.strip(folder, "Centre", a, b, 0.6, 0.1, { Decoration = true })
	local custom = U.strip(folder, "CustomPaint", a, b, 0.4, 0.1, { Decoration = true })
	return root, folder, line, custom
end
local data =
	{ markings = {
		{ AX = 0, AY = 50, AZ = 3300, BX = 900, BY = 50, BZ = 3300, Kind = "Centre", Width = 0.6 },
	} }
local staged = Instance.new("Folder")
local count, complete, coverage = M.build(data, staged, function(p)
	return Vector3.new(p.X, 55, p.Z)
end)
check(count == 32 and complete, "complete probes produce all bounded road paint")
for _, p in staged.Markings:GetChildren() do
	assert(math.abs(p.Position.Y + p.Size.Y / 2 - 55) < 1e-6 and not p.CanCollide)
end
check(true, "paint follows actual supplied road height without adding collision")
local root, folder, line, custom = fixture()
M.removeReplaced(root, coverage)
local length = 0
for _, p in folder:GetChildren() do
	if p ~= custom then
		length += p.Size.Z
	end
end
check(
	line.Parent == nil and custom.Parent == folder and #folder:GetChildren() == 3 and math.abs(length - 132) < 1e-6,
	"full replacement preserves outside line intervals and custom paint"
)
M.removeReplaced(root, coverage)
check(#folder:GetChildren() == 3, "repeated replacement does not fragment untouched paint")
local partial = Instance.new("Folder")
local n, okay, partialCoverage, skipped, examples = M.build(data, partial, function(p)
	return if p.X < 200 then p else nil
end)
check(
	n == 5 and not okay and skipped == 27 and #examples == 4,
	"failed probes keep five valid sections and report bounded missing coordinates"
)
local partialRoot, partialOld, _, partialCustom = fixture()
M.removeReplaced(partialRoot, partialCoverage)
length = 0
for _, p in partialOld:GetChildren() do
	if p ~= partialCustom then
		length += p.Size.Z
	end
end
check(math.abs(length - 780) < 1e-6, "partial replacement retains old paint across the failed 200-plus range")
local retained = M.retainPrevious(staged.Markings, partial.Markings, partialCoverage)
check(
	retained == 27 and #partial.Markings:GetChildren() == 32,
	"regional rerun preserves previous paint only where new probes failed"
)
local refreshed, refreshedPaint, _, refreshedCustom = fixture()
M.removeReplaced(refreshed, partialCoverage)
length = 0
for _, p in refreshedPaint:GetChildren() do
	if p ~= refreshedCustom then
		length += p.Size.Z
	end
end
check(math.abs(length - 132) < 1e-6, "global refresh cannot duplicate retained regional paint across failed probes")
local material, instance, hitY, missing = Enum.Material.Grass, workspace.Terrain, 58, false
local sampled = M.surface(root, function(origin, direction, params)
	assert(direction.Y == -128 and origin.Y == 114)
	assert(params.FilterDescendantsInstances[1] == workspace.Terrain)
	return if missing
		then nil
		else { Position = Vector3.new(origin.X, hitY, origin.Z), Instance = instance, Material = material }
end)
local p = Vector3.new(100, 50, 3300)
check(sampled(p) == nil, "visible grass is never treated as a paintable road")
material = Enum.Material.Asphalt
check(math.abs(sampled(p).Y - 58.065) < 1e-8, "visible terrain asphalt above the old parts supports markings")
instance, material, hitY = Instance.new("Part"), Enum.Material.Asphalt, 80
check(math.abs(sampled(p).Y - 80.065) < 1e-8, "saved carriageway outside the old twelve-stud probe range is found")
missing = true
check(sampled(p) == nil, "missing surfaces still skip paint rather than inventing a road")
print(`ALL CHECKS PASSED ({passed} junction marking checks)`)
