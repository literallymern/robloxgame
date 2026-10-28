--!nocheck
-- needs: roblox-mock
-- Executes the real full-upgrade entry point with injected builder backends. TerrainUpgrade
-- and CSG geometry have their own numerical/geometry tests; this checks ordering and safety.
local Util = load("StudioTools/Map/Builders/Util")
local Existing = load("StudioTools/Map/ExistingTerrain")
local Heightfield = load("StudioTools/Map/Heightfield")
local TerrainUpgrade = load("StudioTools/Map/Builders/TerrainUpgrade")
local Canopies = load("StudioTools/Map/Builders/CanopyLibrary")
local failures = 0
local function check(name, value)
	print(if value then "PASS" else "FAIL", name)
	if not value then
		failures += 1
	end
end
local map = Instance.new("Folder")
map.Name, map.Parent = "Map", workspace
for _, name in { "Roads", "Bridges", "RoadDetails", "Vegetation", "Places", "Properties" } do
	Util.folder(map, name)
end
local oldSigns = Instance.new("Folder")
oldSigns.Name, oldSigns.Parent = "Signs", map.RoadDetails
local custom = Util.part(map, "CustomHouse", CFrame.new(120, 12, 120), Vector3.new(20, 24, 20))
local generatedPart = Util.part(map.Roads, "ExistingRoad", CFrame.new(300, 1, 300), Vector3.new(20, 1, 20))
local protect, protectedCount = Existing.protection()
check("terrain protection includes custom building footprints and padding", protectedCount == 1 and protect(135, 120))
check(
	"terrain protection ignores generated road parts and distant land",
	not protect(300, 300) and not protect(-500, -500)
)

RaycastParams = {
	new = function()
		return {}
	end,
}
local underWater = false
rawset(workspace, "__methods", {
	Raycast = function(_, origin, direction, params)
		assert(
			params.FilterType == Enum.RaycastFilterType.Include
				and params.FilterDescendantsInstances[1] == workspace.Terrain
		)
		assert(origin.Y == 2048 and direction.Y == -8192)
		return {
			Position = Vector3.new(origin.X, if params.IgnoreWater then 12 else 37, origin.Z),
			Normal = Vector3.new(0, 1, 0),
			Material = if underWater and not params.IgnoreWater then Enum.Material.Water else Enum.Material.Grass,
		}
	end,
})
local sampler = Existing.groundSampler()
local dryY = sampler(120, 120)
underWater = true
local wetY = sampler(120, 120)
local bedY = sampler(120, 120, true)
underWater = false
check("saved-terrain sampler uses real height and excludes water for plants", dryY == 37 and wetY == nil and bedY == 12)

local order = {}
local failCanopy, failTerrain, failBridge, actualSampled = false, false, false, false
local bridgeSampled, roadsideSampled = false, false
Heightfield.new = function()
	return {}
end
Canopies.prepare = function()
	table.insert(order, "canopy")
	assert(not failCanopy, "Simulated native CSG failure")
	return { Created = false, Templates = 20 }
end
TerrainUpgrade.apply = function(_, _, _, options)
	table.insert(order, if options.DryRun then "dry" else "terrain")
	assert(options.Protected(120, 120), "custom construction protection was not passed to terrain upgrade")
	return {
		Complete = not failTerrain,
		Error = if failTerrain then "Simulated engine write failure" else nil,
		DryRun = options.DryRun == true,
		ChangedColumns = if options.DryRun then 0 else 7,
		PreservedColumns = 2,
		AlreadyCurrentColumns = 0,
	}
end
load("StudioTools/Map/Builders/Roads").build = function(_, _, parent)
	table.insert(order, "geometry")
	Util.folder(parent, "Roads")
	return 9
end
load("StudioTools/Map/Builders/Bridges").build = function(_, parent, sample)
	Util.folder(parent, "Bridges")
	bridgeSampled = sample(220, 220, true) == 12 and sample(120, 120, true) == nil
	assert(not failBridge, "Simulated missing bridge foundation")
	return 8
end
load("StudioTools/Map/Builders/RoadDetails").build = function(_, parent)
	local root = Util.folder(parent, "RoadDetails")
	local signs = Instance.new("Folder")
	signs.Name, signs.Parent = "Signs", root
	return {}
end
load("StudioTools/Map/RoadDetails").new = function(_, _, sample)
	roadsideSampled = sample(220, 220) == 37 and sample(120, 120) == nil
	return {}
end
load("StudioTools/Map/Vegetation").new = function(_, _, _, _, sample)
	actualSampled = sample(220, 220) == 37 and sample(120, 120) == nil
	return { trees = { {} }, bushes = {}, rocks = {} }
end
load("StudioTools/Map/Builders/Vegetation").build = function(_, parent)
	Util.folder(parent, "Vegetation")
	return 4
end
load("StudioTools/Map/Builders/Environment").apply = function()
	return {}
end
local benchmarkApplied = false
load("StudioTools/Map/KagundaliUpdate").apply = function(_, _, _, options)
	benchmarkApplied = options.Terrain == true
	return { Revision = "kagundali-junction-1" }
end
local BuildMap = load("StudioTools/BuildMap")

local beforeRoads = map.Roads
local dry = BuildMap.upgradeEnvironment({ DryRun = true })
check(
	"dry run performs no CSG compilation or geometry replacement",
	dry.DryRun and #order == 1 and order[1] == "dry" and map.Roads == beforeRoads
)
table.clear(order)
local report = BuildMap.upgradeEnvironment()
check("full environment upgrade includes the bounded Kagundali benchmark", benchmarkApplied)
check(
	"full upgrade prepares native foliage before terrain, then geometry",
	order[1] == "canopy" and order[2] == "terrain" and order[3] == "geometry"
)
check("full upgrade grounds vegetation on patched saved terrain", actualSampled)
check(
	"full upgrade grounds bridge foundations and roadside furniture on saved terrain",
	bridgeSampled and roadsideSampled
)
check(
	"full upgrade preserves signs and custom construction",
	map.RoadDetails.Signs == oldSigns and custom.Parent == map
)
check(
	"full upgrade reports applied revision and actual terrain counters",
	report.Geometry.Revision == BuildMap.EnvironmentRevision
		and report.Geometry.TerrainRebuilt
		and report.Terrain.ChangedColumns == 7
		and map:GetAttribute("EnvironmentTerrainChangedColumns") == 7
)
actualSampled, bridgeSampled, roadsideSampled = false, false, false
BuildMap.refreshEnvironment()
check("geometry-only refresh also samples saved ground and avoids custom buildings", actualSampled)
check("geometry-only refresh also grounds bridges and roadside furniture", bridgeSampled and roadsideSampled)
map:SetAttribute("EnvironmentGeometryRevision", "old")
BuildMap.refreshEnvironment({ Roads = false, Vegetation = false })
check(
	"partial refresh cannot advertise the complete geometry upgrade",
	map:GetAttribute("EnvironmentGeometryRevision") == "old"
)

beforeRoads = map.Roads
failBridge = true
local bridgeOkay = pcall(BuildMap.refreshEnvironment)
check(
	"missing structural ground leaves saved geometry and signs intact",
	not bridgeOkay and map.Roads == beforeRoads and map.RoadDetails.Signs == oldSigns
)
failBridge = false

beforeRoads = map.Roads
table.clear(order)
failCanopy = true
local okay = pcall(BuildMap.upgradeEnvironment)
check(
	"CSG failure stops before any terrain write or map replacement",
	not okay and #order == 1 and map.Roads == beforeRoads
)
failCanopy, failTerrain = false, true
table.clear(order)
okay = pcall(BuildMap.upgradeEnvironment)
check(
	"interrupted terrain patch retains saved geometry and reports failure",
	not okay and #order == 2 and map.Roads == beforeRoads
)
failTerrain = false
map.Roads:SetAttribute("GeneratedBy", nil)
table.clear(order)
okay = pcall(BuildMap.upgradeEnvironment)
check(
	"custom map groups block the upgrade before all side effects",
	not okay and #order == 0 and map.Roads == beforeRoads
)
if failures > 0 then
	error(`{failures} full-upgrade entry checks failed`)
end
print("ALL CHECKS PASSED")
