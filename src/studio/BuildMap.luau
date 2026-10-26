--!strict
-- Builds the map (Milestone 2) from src/shared/Config/MapLayout.luau: terrain, roads, bridges,
-- places, trees, signs and everything else along the roads.
--
-- Run it in Studio in EDIT mode (not while Play is running), from the command bar
-- (View > Command Bar):
--     require(game.ServerStorage.StudioTools.BuildMap).run()
-- Only the parts, keeping the terrain as it is:
--     require(game.ServerStorage.StudioTools.BuildMap).run({ Terrain = false })
-- Without trees, bushes and rocks (faster, for quick checks):
--     require(game.ServerStorage.StudioTools.BuildMap).run({ Vegetation = false })
--
-- It REPLACES all terrain and everything it generated earlier (marked with the attribute
-- GeneratedBy = "BuildMap"). Parts you built yourself are left alone, but hand edits to the
-- terrain are lost when the terrain is rebuilt. Save a backup of the place first.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Map = script.Parent:WaitForChild("Map")
local Builders = Map:WaitForChild("Builders")
local Heightfield = require(Map.Heightfield)
local RoadDetails = require(Map.RoadDetails)
local Vegetation = require(Map.Vegetation)
local Airport = require(Builders.Airport)
local Boundary = require(Builders.Boundary)
local Bridges = require(Builders.Bridges)
local Countryside = require(Builders.Countryside)
local Crossings = require(Builders.Crossings)
local Environment = require(Builders.Environment)
local Places = require(Builders.Places)
local Properties = require(Builders.Properties)
local RoadDetailsBuilder = require(Builders.RoadDetails)
local Roads = require(Builders.Roads)
local Spawn = require(Builders.Spawn)
local TerrainBuilder = require(Builders.Terrain)
local Util = require(Builders.Util)
local VegetationBuilder = require(Builders.Vegetation)

export type Options = {
	Terrain: boolean?, -- default true
	Parts: boolean?, -- default true
	Vegetation: boolean?, -- trees, bushes and rocks; default true (needs Parts)
}

local BuildMap = {}

local function log(text: string)
	print(`[Ro-Nation:BuildMap] {text}`)
end

function BuildMap.run(options: Options?)
	if RunService:IsRunning() then
		warn("[Ro-Nation:BuildMap] Stop Play first: the map must be built in edit mode to be saved.")
		return
	end
	local opts: Options = options or {}
	local MapLayout = require(ReplicatedStorage.Shared.Config.MapLayout) :: any
	local started = os.clock()

	log(`Map layout version {MapLayout.Version}. Calculating the landscape...`)
	local hf = Heightfield.new(MapLayout, Util.yield)
	log(`Landscape ready: {#hf.roads.roads} roads, {#hf.roads.bridges} bridges.`)
	for _, road in hf.roads.roads do
		if not road.feasible then
			warn(`[Ro-Nation:BuildMap] {road.Id}: the height plan could not meet every fixed point.`)
		end
	end

	if opts.Terrain ~= false then
		TerrainBuilder.build(hf, MapLayout, log)
	end
	Environment.apply(log)

	if opts.Parts ~= false then
		Spawn.removeTemplateObjects(log)
		local map = Util.container(workspace, "Map")
		local removed = Util.clearGenerated(map)
		if removed > 0 then
			log(`Removed {removed} generated folders from the last run.`)
		end
		local counts: { [string]: number } = {
			Roads = Roads.build(hf, MapLayout, map),
			Bridges = Bridges.build(hf, map),
			Places = Places.build(hf, MapLayout, map),
			Airport = Airport.build(hf, MapLayout, map),
			Crossings = Crossings.build(hf, MapLayout, map),
			Properties = Properties.build(hf, MapLayout, map),
			Boundary = Boundary.build(MapLayout, map),
		}
		Spawn.build(MapLayout)
		local summary = {}
		for name, count in counts do
			table.insert(summary, `{name} {count}`)
		end
		table.sort(summary)
		log(`Parts built: {table.concat(summary, ", ")}. Spawn at the Gundiville bus terminal.`)

		log("Placing markings, signs, rails, lights and power lines...")
		local details = RoadDetails.new(MapLayout, hf)
		local along = RoadDetailsBuilder.build(details, map)
		local farm = Countryside.build(hf, map)
		log(
			`Road details: {along.Markings} marking parts, {along.Signs} signs, {along.MarkerPosts} marker post parts, `
				.. `{along.GuardRails} guard rail parts, {along.StreetLights} street light parts, `
				.. `{along.PowerLines} power line parts. Farms: {farm.Fences} fence parts, {farm.Barns} barn parts.`
		)

		if opts.Vegetation ~= false then
			log("Placing trees, bushes and rocks...")
			local plants = Vegetation.new(MapLayout, hf, details, Util.yield)
			local parts = VegetationBuilder.build(plants, map)
			log(`Vegetation: {#plants.trees} trees, {#plants.bushes} bushes, {#plants.rocks} rocks ({parts} parts).`)
		end
	end

	log(
		string.format(
			"Done in %.0f s. Now save the place (File > Save to Roblox) and a backup file.",
			os.clock() - started
		)
	)
end

return BuildMap
