--!nocheck
-- needs: roblox-mock
-- Inspect actual diagnostics on missing, stale and structurally current saved-place fixtures.
local Config = load("ReplicatedStorage/Shared/Config/Environment")
local BuildMap = load("StudioTools/BuildMap")
local Canopies = load("StudioTools/Map/Builders/CanopyLibrary")
local Util = load("StudioTools/Map/Builders/Util")
local inspect = load("StudioTools/CheckEnvironment")
local lighting, storage = game:GetService("Lighting"), game:GetService("ServerStorage")
rawget(workspace, "__props").StreamingEnabled = true
local passed = 0
local function check(ok, message)
	assert(ok, message)
	passed += 1
	print("PASS " .. message)
end
local function status(report, id)
	for _, item in report.Checks do
		if item.Id == id then
			return item.Status
		end
	end
	error("Missing check: " .. id)
end
-- Any instance/property/attribute write by the inspector is a failure, including Decoration.
local function readOnlyInspect()
	local probe = Instance.new("Part")
	local api = getmetatable(probe)
	probe:Destroy()
	local oldNew, oldIndex, oldWrite = Instance.new, api.__index, api.__newindex
	Instance.new = function()
		error("Inspector must not allocate instances")
	end
	api.__newindex = function()
		error("Inspector must not write properties")
	end
	api.__index = function(self, key)
		if key == "Decoration" or key == "SetAttribute" or key == "Destroy" then
			error("Inspector must be read-only")
		end
		return oldIndex(self, key)
	end
	local okay, result = pcall(inspect)
	Instance.new, api.__index, api.__newindex = oldNew, oldIndex, oldWrite
	assert(okay, result)
	return result
end
local missing = readOnlyInspect()
check(
	status(missing, "map") == "FIX" and status(missing, "templates") == "FIX",
	"inspection diagnoses absent saved geometry without building it"
)
check(
	status(missing, "audioRain") == "FIX" and status(missing, "audioThunder") == "FIX",
	"blank weather audio is reported as incomplete"
)
local map = Instance.new("Folder")
map.Name, map.Parent = "Map", workspace
map:SetAttribute("EnvironmentGeometryRevision", "highland-3")
map:SetAttribute("EnvironmentTerrainRevision", "highland-3")
for _, name in { "Roads", "Bridges", "RoadDetails", "Vegetation" } do
	local group = Util.folder(map, name)
	Util.part(group, "Fixture", CFrame.new(), Vector3.new(1, 1, 1))
end
local stale = readOnlyInspect()
check(
	status(stale, "geometryRevision") == "FIX" and status(stale, "terrainRevision") == "FIX",
	"inspection distinguishes previous saved terrain and geometry from current code"
)
map:SetAttribute("EnvironmentGeometryRevision", BuildMap.EnvironmentRevision)
map:SetAttribute("EnvironmentTerrainRevision", BuildMap.EnvironmentRevision)
local markersOnly = readOnlyInspect()
check(
	status(markersOnly, "foliage") == "FIX" and status(markersOnly, "bridges") == "FIX",
	"revision markers cannot conceal missing canopies or bridge models"
)
for i = 1, 5 do
	local bridge = Instance.new("Model")
	bridge.Name, bridge.Parent = "Bridge" .. i, map.Bridges
	bridge:SetAttribute("Road", "Fixture")
	Util.part(bridge, "Fixture", CFrame.new(), Vector3.new(1, 1, 1))
end
local signs = Instance.new("Folder")
signs.Name, signs.Parent = "Signs", map.RoadDetails
Util.part(signs, "Fixture", CFrame.new(), Vector3.new(1, 1, 1))
Canopies.prepare()
local template = storage.RoNationCanopyLibrary:FindFirstChild("Broadleaf1")
assert(template, "Fixture needs an actual prepared canopy")
template:Clone().Parent = map.Vegetation
local handles = load("ReplicatedStorage/Shared/Environment/Presentation").new()
local current = readOnlyInspect()
check(
	current.Failed == 5 and current.Counts.CanopyTemplates == 20 and current.Counts.BridgeModels == 5,
	"old global fixture reports missing audio and all three unapplied benchmark components"
)
check(
	status(current, "grass") == "INFO" and status(current, "acceptance") == "INFO",
	"inspection keeps native grass and real Studio acceptance explicitly manual"
)
Config.Effects.Audio.Rain, Config.Effects.Audio.Thunder = "rbxassetid://123", "rbxassetid://456"
local configured = readOnlyInspect()
check(
	configured.Failed == 3 and status(configured, "audioRain") == "INFO",
	"configured audio IDs do not conceal an unapplied benchmark or claim verified playback"
)
local custom = Instance.new("BloomEffect")
custom.Name, custom.Enabled, custom.Intensity, custom.Parent = "CustomBloom", true, 0.5, lighting
local conflicted = readOnlyInspect()
check(
	status(conflicted, "lightingBloomEffect") == "FIX" and custom.Enabled and custom.Intensity == 0.5,
	"custom lighting conflicts are diagnosed without modification"
)
local runService = game:GetService("RunService")
rawset(runService, "__methods", {
	IsRunning = function()
		return true
	end,
})
local okay = pcall(inspect)
check(not okay, "saved-place inspection refuses Play mode")
print(`ALL CHECKS PASSED ({passed} inspection checks)`)
