--!strict
-- Builds the map blockout (Milestone 2) from src/shared/Config/MapLayout.luau.
--
-- Run it in Studio in EDIT mode (not while Play is running), from the command bar
-- (View > Command Bar):
--     require(game.ServerStorage.StudioTools.BuildMap).run()
-- Only the parts, keeping the terrain as it is:
--     require(game.ServerStorage.StudioTools.BuildMap).run({ Terrain = false })
--
-- It REPLACES all terrain and everything it generated earlier (marked with the attribute
-- GeneratedBy = "BuildMap"). Parts you built yourself are left alone, but hand edits to the
-- terrain are lost when the terrain is rebuilt. Save a backup of the place first.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Map = script.Parent:WaitForChild("Map")
local Builders = Map:WaitForChild("Builders")
local Heightfield = require(Map.Heightfield)
local Airport = require(Builders.Airport)
local Boundary = require(Builders.Boundary)
local Bridges = require(Builders.Bridges)
local Crossings = require(Builders.Crossings)
local Places = require(Builders.Places)
local Properties = require(Builders.Properties)
local Roads = require(Builders.Roads)
local Spawn = require(Builders.Spawn)
local TerrainBuilder = require(Builders.Terrain)
local Util = require(Builders.Util)

export type Options = {
	Terrain: boolean?, -- default true
	Parts: boolean?, -- default true
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

	if opts.Parts ~= false then
		Spawn.removeTemplateObjects(log)
		local map = Util.container(workspace, "Map")
		local removed = Util.clearGenerated(map)
		if removed > 0 then
			log(`Removed {removed} generated folders from the last run.`)
		end
		local counts = {
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
	end

	log(
		string.format(
			"Done in %.0f s. Now save the place (File > Save to Roblox) and a backup file.",
			os.clock() - started
		)
	)
end

return BuildMap
