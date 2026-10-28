--!strict
-- Read-only saved-place inspection. Run in Studio EDIT mode:
-- require(game.ServerStorage.StudioTools.CheckEnvironment)()
-- A passing structural report does not establish visual quality or runtime performance.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config.Environment)
local BuildMap = require(script.Parent.BuildMap)
local Canopies = require(script.Parent.Map.Builders.CanopyLibrary)
local Junction = require(script.Parent.Map.JunctionLandscape)
local JunctionTrees = require(script.Parent.Map.Builders.JunctionTrees)

type Check = { Id: string, Status: string, Message: string }
type Report = { Revision: string, Checks: { Check }, Counts: { [string]: number }, Passed: number, Failed: number }

local function countParts(folder: Instance?): number
	local count = 0
	if folder then
		for _, child in folder:GetDescendants() do
			if child:IsA("BasePart") then
				count += 1
			end
		end
	end
	return count
end

return function(): Report
	assert(not RunService:IsRunning(), "Stop Play: CheckEnvironment inspects the saved map in edit mode")
	local report: Report = { Revision = BuildMap.EnvironmentRevision, Checks = {}, Counts = {}, Passed = 0, Failed = 0 }
	local function check(id: string, ok: boolean?, message: string)
		local status = if ok == nil then "INFO" elseif ok then "OK" else "FIX"
		if ok == true then
			report.Passed += 1
		elseif ok == false then
			report.Failed += 1
		end
		table.insert(report.Checks, { Id = id, Status = status, Message = message })
		print(`[CheckEnvironment] {status} {message}`)
	end
	local map = workspace:FindFirstChild("Map")
	check("map", map ~= nil, "Saved Workspace.Map must exist before an environment upgrade.")
	if map then
		local area = map:FindFirstChild("KagundaliJunction")
		local trees = 0
		for _, child in if area then area:GetDescendants() else {} do
			if
				child:IsA("Model")
				and child:GetAttribute("AssetVersion") == JunctionTrees.Version
				and child:FindFirstChild("TrunkCollision")
			then
				trees += 1
			end
		end
		report.Counts.KagundaliTrees = trees
		check(
			"kagundaliGeometry",
			area ~= nil and area:GetAttribute("Revision") == Junction.Revision and trees >= 20,
			`Kagundali R3/N5: {trees} new branching trees. If missing, run require(game.ServerStorage.StudioTools.UpgradeKagundali)(); the camera then moves to the benchmark.`
		)
		check(
			"kagundaliTerrain",
			map:GetAttribute("KagundaliTerrainRevision") == Junction.Revision,
			`Kagundali terrain: {tostring(map:GetAttribute("KagundaliTerrainRevision"))}; expected {Junction.Revision}. Preserved custom columns still need visual inspection.`
		)
		check(
			"lightingRevision",
			map:GetAttribute("EnvironmentLightingRevision") == Junction.LightingRevision,
			`Saved natural atmosphere: {tostring(map:GetAttribute("EnvironmentLightingRevision"))}; expected {Junction.LightingRevision}.`
		)
		for _, kind in { "Geometry", "Terrain" } do
			local revision = map:GetAttribute(`Environment{kind}Revision`)
			check(
				string.lower(kind) .. "Revision",
				revision == report.Revision,
				`{kind} revision: {tostring(revision)}; expected {report.Revision}. Use BuildMap.upgradeEnvironment() for the saved-map update.`
			)
		end
		for _, name in { "Roads", "Bridges", "RoadDetails", "Vegetation" } do
			local group = map:FindFirstChild(name)
			report.Counts[name] = countParts(group)
			check(
				"group" .. name,
				group ~= nil and group:GetAttribute("GeneratedBy") == "BuildMap" and report.Counts[name] > 0,
				`Map.{name}: {report.Counts[name]} parts; requires a populated generated folder.`
			)
		end
		local bridges = map:FindFirstChild("Bridges")
		local bridgeCount = 0
		for _, child in if bridges then bridges:GetChildren() else {} do
			if child:IsA("Model") and child:GetAttribute("Road") ~= nil and countParts(child) > 0 then
				bridgeCount += 1
			end
		end
		report.Counts.BridgeModels = bridgeCount
		check("bridges", bridgeCount == 5, `Saved bridge models: {bridgeCount}; this layout has five crossings.`)
		local details = map:FindFirstChild("RoadDetails")
		local signs = if details then details:FindFirstChild("Signs") else nil
		report.Counts.SignParts = countParts(signs)
		check(
			"signs",
			report.Counts.SignParts > 0,
			`Retained sign parts: {report.Counts.SignParts}. Inspect their text and placement in Studio.`
		)
		local foliage = 0
		local vegetation = map:FindFirstChild("Vegetation")
		for _, child in if vegetation then vegetation:GetDescendants() else {} do
			if child:IsA("PartOperation") and child:GetAttribute("CanopyVersion") == Canopies.Version then
				foliage += 1
			end
		end
		report.Counts.CanopyParts = foliage
		check(
			"foliage",
			foliage > 0,
			`Current native canopy parts on the map: {foliage}; version markers alone do not establish a rebuilt map.`
		)
		check(
			"terrainCounters",
			nil,
			`Last patch: {tostring(map:GetAttribute("EnvironmentTerrainChangedColumns"))} changed columns, {tostring(
				map:GetAttribute("EnvironmentTerrainPreservedColumns")
			)} preserved. Preserved columns require visual inspection; a revision is not proof that every column changed.`
		)
	end
	local library = ServerStorage:FindFirstChild("RoNationCanopyLibrary")
	local templates = 0
	for _, kind in Canopies.Kinds do
		for variant = 1, Canopies.Variants do
			local template = if library then library:FindFirstChild(`{kind}{variant}`) else nil
			if
				template
				and template:IsA("PartOperation")
				and template:GetAttribute("CanopyVersion") == Canopies.Version
			then
				templates += 1
			end
		end
	end
	report.Counts.CanopyTemplates = templates
	check(
		"templates",
		templates == #Canopies.Kinds * Canopies.Variants,
		`Reusable canopy templates: {templates}/{#Canopies.Kinds * Canopies.Variants}. Save the prepared library with the place.`
	)
	check("streaming", workspace.StreamingEnabled, "Workspace.StreamingEnabled must be enabled for the large map.")
	check("weather", Config.Enabled, "Environment runtime is enabled in Config.Environment.")
	local profiles = true
	for _, name in { "Clear", "PartlyCloudy", "Overcast", "Rain", "Thunderstorm" } do
		profiles = profiles and type(Config.Profiles[name]) == "table"
	end
	check("profiles", profiles, "All five weather profiles must be configured.")
	check(
		"cycle",
		Config.DayLengthSeconds > 0 and Config.TransitionSeconds > 0,
		"Day length and gradual weather transition duration must be positive."
	)
	for _, name in { "Rain", "Thunder" } do
		local id = Config.Effects.Audio[name]
		local configured = type(id) == "string" and string.match(id, "^rbxassetid://[1-9]%d*$") ~= nil
		check(
			"audio" .. name,
			if configured then nil else false,
			if configured
				then `{name} audio ID configured; upload permissions and audible playback still need a Play test.`
				else `{name} audio is missing. Upload the supplied WAV and configure its permitted Roblox audio ID.`
		)
	end
	for _, spec in
		{
			{ Lighting, "Atmosphere", "RoNationAtmosphere" },
			{ Lighting, "BloomEffect", "RoNationBloom" },
			{ Lighting, "SunRaysEffect", "RoNationSunRays" },
			{ Lighting, "ColorCorrectionEffect", "RoNationColorCorrection" },
			{ workspace.Terrain, "Clouds", "RoNationClouds" },
		}
	do
		local parent, className, name = spec[1] :: Instance, spec[2] :: string, spec[3] :: string
		local active, managed = 0, false
		for _, child in parent:GetChildren() do
			if child:IsA(className) and (not child:IsA("PostEffect") or (child :: any).Enabled) then
				active += 1
				managed = managed or child.Name == name or child:GetAttribute("ManagedBy") == "RoNationEnvironment"
			end
		end
		check(
			"lighting" .. className,
			active == 1 and managed,
			`{className}: {active} active instance(s). Custom/duplicate effects can override the natural preset; this inspection leaves them untouched.`
		)
	end
	check(
		"grass",
		nil,
		"Manually check Workspace > Terrain > Decoration in Properties and save. Roblox does not expose this setting to scripts."
	)
	check(
		"acceptance",
		nil,
		"Still required: Play tests for weather/audio/lamps, visual comparison, bridge collisions, streaming, and profiling on lower-end hardware with 20–25 players. This report performs none of those tests."
	)
	print(
		`[CheckEnvironment] {report.Passed} checks passed; {report.Failed} need attention. No place settings were changed.`
	)
	return report
end
