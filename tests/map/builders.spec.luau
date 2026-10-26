--!strict
-- needs: roblox-mock
-- Runs the real BuildMap entry point against the Roblox stand-in (tests/map/roblox-mock.luau):
-- full terrain and all parts, then a second run with Terrain = false. Checks what was created.

local MapLayout = load("ReplicatedStorage/Shared/Config/MapLayout")
local Heightfield = load("StudioTools/Map/Heightfield")

local failures = 0
local function check(name: string, ok: boolean, detail: string?)
	if ok then
		print("PASS", name)
	else
		failures += 1
		print("FAIL", name, detail or "")
	end
end

local mockWorkspace: any = workspace
local stats: any = MockStats
MockAddTemplate()

-- Probe columns (at column centres) whose height is rebuilt from the written voxels.
local probePoints = {
	{ "spawn", 195, 780 },
	{ "Gundiville centre", 0, 0 },
	{ "river at the N4 bridge", 1206, 185 },
	{ "Stokondo", -3000, -2300 },
	{ "Oberdueshuson", 2400, -2800 },
	{ "east crossing", 4900, 250 },
	{ "south crossing", 500, 4900 },
	{ "forested hills", -1600, -2000 },
	{ "north-east mountains", 4800, -4800 },
	{ "river source", 1000, -4380 },
	{ "river gap", -1450, 5000 },
	{ "N1 road", -1350, -850 },
}
for _, p in probePoints do
	local x = math.floor(p[2] / 4) * 4 + 2
	local z = math.floor(p[3] / 4) * 4 + 2
	table.insert(stats.probes, { name = p[1], x = x, z = z })
end

local BuildMap = load("StudioTools/BuildMap")
local started = os.clock()
BuildMap.run()
local elapsed = os.clock() - started
print(string.format("INFO full build took %.1f s here (Luau CLI interpreter)", elapsed))
print(
	string.format(
		"INFO %d WriteVoxels calls, %d FillBlock calls, %.1f million voxels, %d water voxels, %d parts",
		stats.writeVoxels,
		stats.fillBlocks,
		stats.cells / 1e6,
		stats.waterCells,
		stats.parts
	)
)
local used = {}
for name in stats.materialsUsed do
	table.insert(used, name)
end
table.sort(used)
print("INFO terrain materials: " .. table.concat(used, ", "))

local half = MapLayout.Bounds.Half
check("terrain cleared once", stats.clears == 1)
check("every chunk written", stats.writeVoxels == (2 * half / 64) ^ 2, tostring(stats.writeVoxels))
check("water written", stats.waterCells > 10000, tostring(stats.waterCells))
check("template Baseplate removed", mockWorkspace:FindFirstChild("Baseplate") == nil)
check("template SpawnLocation removed", mockWorkspace:FindFirstChild("SpawnLocation") == nil)

local hf = Heightfield.new(MapLayout)
for _, probe in stats.probes do
	local h, _, water = hf.surface(probe.x, probe.z)
	local solidTop = probe.solidTop
	check(
		`voxels match the heightfield: {probe.name}`,
		solidTop ~= nil and math.abs(solidTop - h) <= 2.5,
		string.format("voxels %s, heightfield %.1f", tostring(solidTop), h)
	)
	if water then
		check(
			`water surface written: {probe.name}`,
			probe.waterTop ~= nil and math.abs(probe.waterTop - water) <= 2.5,
			string.format("voxels %s, heightfield %.1f", tostring(probe.waterTop), water)
		)
	end
end

local map = mockWorkspace:FindFirstChild("Map")
check("Workspace.Map exists", map ~= nil)
local expected = {
	"Roads",
	"Bridges",
	"Places",
	"GundivillePlaceholders",
	"Airport",
	"Crossings",
	"Properties",
	"Boundary",
	"RoadDetails",
	"Countryside",
	"Vegetation",
}
for _, name in expected do
	local folder = map and map:FindFirstChild(name)
	check(`Map.{name} generated`, folder ~= nil and folder:GetAttribute("GeneratedBy") == "BuildMap")
end
local roads = map:FindFirstChild("Roads")
check("a folder per road", #roads:GetChildren() == #MapLayout.Roads)
check("5 bridges", #map:FindFirstChild("Bridges"):GetChildren() == 5)
check("16 property plots tagged", stats.tags.PropertyPlot == 16, tostring(stats.tags.PropertyPlot))
local spawns = mockWorkspace:FindFirstChild("Spawns")
local spawn = spawns and spawns:FindFirstChild("BusTerminal")
check("spawn at the bus terminal", spawn ~= nil and spawn:IsA("SpawnLocation"))
if spawn then
	local p = spawn.CFrame.Position
	check("spawn stands on the ground", math.abs(p.Y - 0.5 - 0.2 - hf.surface(p.X, p.Z)) < 0.05)
end

-- All parts inside the map and above the floor.
local outside = 0
local partCount = 0
for _, item in map:GetDescendants() do
	if item:IsA("BasePart") then
		partCount += 1
		local p = item.CFrame.Position
		if math.abs(p.X) > half + 1 or math.abs(p.Z) > half + 1 or p.Y < 0 or p.Y > 1400 then
			outside += 1
		end
	end
end
print(`INFO {partCount} parts under Workspace.Map`)
check("all parts inside the map", outside == 0, `{outside} outside`)
check("part count within the budget (under 45000)", partCount < 45000, tostring(partCount))

-- Road surfaces sit on the calculated profile.
local worst, worstWhere = 0, ""
for _, road in hf.roads.roads do
	local folder = roads:FindFirstChild(road.Id)
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "Line" and not string.find(part.Name, "joint") then
			local frame = part.CFrame
			local topCentre = frame.Position + frame.UpVector * (part.Size.Y / 2)
			local e, y = hf.roads.nearest(topCentre.X, topCentre.Z)
			if e and e < 0 and math.abs(topCentre.Y - y) > worst then
				worst = math.abs(topCentre.Y - y)
				worstWhere = `{road.Id} {part.Name}`
			end
		end
	end
end
check("road parts follow the height profile", worst < 0.3, string.format("off by up to %.2f at %s", worst, worstWhere))

-- A second run with Terrain = false replaces the generated parts and keeps hand-built ones.
local own = Instance.new("Part")
own.Name = "JustinsOwnPart"
own.Parent = map
local before = #map:GetChildren()
local clearsBefore = stats.clears
BuildMap.run({ Terrain = false })
check("rerun keeps the terrain", stats.clears == clearsBefore)
check("rerun does not duplicate folders", #map:GetChildren() == before, `{before} -> {#map:GetChildren()}`)
check("rerun keeps hand-built parts", map:FindFirstChild("JustinsOwnPart") ~= nil)
check("rerun keeps one spawn", #spawns:GetChildren() == 1)

-- In-place environment upgrade retains geography, gameplay objects and authored signs.
local retainedPlaces = map:FindFirstChild("Places")
local retainedProperties = map:FindFirstChild("Properties")
local retainedSpawn = spawns:FindFirstChild("BusTerminal")
local retainedSigns = map:FindFirstChild("RoadDetails"):FindFirstChild("Signs")
local originalRoads = map:FindFirstChild("Roads")
local originalVegetation = map:FindFirstChild("Vegetation")
local savedCount = #map:GetChildren()
local savedClears = stats.clears
local customSign = Instance.new("Part")
customSign.Name = "AuthoredSign"
customSign.Parent = retainedSigns
BuildMap.refreshEnvironment()
check("refresh keeps terrain voxels", stats.clears == savedClears)
check(
	"refresh keeps places and property instances",
	map:FindFirstChild("Places") == retainedPlaces and map:FindFirstChild("Properties") == retainedProperties
)
check("refresh keeps spawn instance", spawns:FindFirstChild("BusTerminal") == retainedSpawn)
check(
	"refresh retains sign instances and manual edits",
	map:FindFirstChild("RoadDetails"):FindFirstChild("Signs") == retainedSigns and customSign.Parent == retainedSigns
)
check(
	"refresh replaces selected environment groups",
	map:FindFirstChild("Roads") ~= originalRoads and map:FindFirstChild("Vegetation") ~= originalVegetation
)
check("refresh preserves hand-built map content", own.Parent == map)
check("refresh adds no duplicate groups", #map:GetChildren() == savedCount)
local retainedRoads = map:FindFirstChild("Roads")
local retainedVegetation = map:FindFirstChild("Vegetation")
BuildMap.refreshEnvironment({ Roads = false, Vegetation = false })
check(
	"refresh options retain unselected groups",
	map:FindFirstChild("Roads") == retainedRoads and map:FindFirstChild("Vegetation") == retainedVegetation
)
retainedRoads:SetAttribute("GeneratedBy", nil)
local retainedDetails = map:FindFirstChild("RoadDetails")
BuildMap.refreshEnvironment()
check(
	"refresh refuses to replace authored folders",
	map:FindFirstChild("RoadDetails") == retainedDetails and map:FindFirstChild("Roads") == retainedRoads
)
retainedRoads:SetAttribute("GeneratedBy", "BuildMap")

if failures > 0 then
	error(`{failures} check(s) failed`)
end
print("ALL CHECKS PASSED")
