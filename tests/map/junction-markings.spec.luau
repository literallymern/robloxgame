--!nocheck
-- needs: roblox-mock
local M = load("StudioTools/Map/Builders/JunctionMarkings")
local U = load("StudioTools/Map/Builders/Util")
local root = Instance.new("Folder")
local details = U.folder(root, "RoadDetails")
local folder = U.folder(details, "Markings")
local a, b = Vector3.new(0, 50, 3300), Vector3.new(900, 50, 3300)
local line = U.strip(folder, "Centre", a, b, 0.6, 0.1, { Decoration = true })
local custom = U.strip(folder, "CustomPaint", a, b, 0.4, 0.1, { Decoration = true })
M.removeReplaced(root)
assert(line.Parent == nil and custom.Parent == folder and #folder:GetChildren() == 3)
local length = 0
for _, p in folder:GetChildren() do
	if p ~= custom then
		length += p.Size.Z
		assert(p.Position.X < 64 or p.Position.X > 832)
	end
end
assert(math.abs(length - (64 + 900 - 832)) < 1e-6)
print("PASS crossing markings keep both outside segments and custom paint")
M.removeReplaced(root)
assert(#folder:GetChildren() == 3)
print("PASS repeated clipping does not duplicate or trim outside paint")
local staged = Instance.new("Folder")
local data =
	{ markings = {
		{ AX = 0, AY = 50, AZ = 3300, BX = 900, BY = 50, BZ = 3300, Kind = "Centre", Width = 0.6 },
	} }
local count, complete = M.build(data, staged, function(p)
	return Vector3.new(p.X, 55, p.Z)
end)
assert(count == 32 and complete)
for _, p in staged.Markings:GetChildren() do
	assert(math.abs(p.Position.Y + p.Size.Y / 2 - 55) < 1e-6 and not p.CanCollide)
end
print("PASS restored paint follows supplied saved road height inside the bounded area")
local failed = Instance.new("Folder")
local n, okay = M.build(data, failed, function(p)
	return if p.X < 200 then p else nil
end)
assert(n == 0 and not okay and failed:FindFirstChild("Markings") == nil)
print("PASS missing road samples discard incomplete paint before replacing existing markings")
local noRoad = M.surface(Instance.new("Folder"))
assert(noRoad(Vector3.new(100, 50, 3300)) == nil)
print("PASS missing saved road folders cannot silently use terrain as the paint surface")
print("ALL CHECKS PASSED (5 junction marking checks)")
