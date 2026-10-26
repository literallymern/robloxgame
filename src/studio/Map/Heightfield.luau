--!strict
--!native
-- The finished terrain surface: land, roads cut and filled into it, and the river carved last.
-- surface(x, z) is called for every 4-stud column of the map by the terrain builder.
-- Pure Luau, tested offline (tests/map).

local Geometry = require(script.Parent.Geometry)
local Land = require(script.Parent.Land)
local River = require(script.Parent.River)
local RoadNetwork = require(script.Parent.RoadNetwork)

export type Heightfield = {
	land: Land.Land,
	river: River.River,
	roads: RoadNetwork.RoadNetwork,
	-- Terrain height, material code (0 = natural, chosen by slope later) and water surface or nil.
	surface: (x: number, z: number) -> (number, number, number?),
	-- Material for natural ground, from height, slope (rise per stud) and position.
	naturalMaterial: (height: number, slope: number, x: number, z: number) -> number,
}

local Heightfield = {}

-- Material codes used by surface() and naturalMaterial(); the terrain builder maps them to
-- Enum.Material by name.
Heightfield.Materials = table.freeze({
	"Grass",
	"LeafyGrass",
	"Rock",
	"Ground",
	"Mud",
	"Pavement",
	"Asphalt",
	"Sand",
	"Slate",
})

local CODE: { [string]: number } = {}
for i, name in Heightfield.Materials do
	CODE[name] = i
end

local ROAD_PAD = 2 -- studs of road bed on each side beyond the road surface
local ROAD_BED = 0.6 -- terrain sits this far below the road surface (the road parts cover it)
local BRIDGE_BED = 3.6 -- under a bridge deck the terrain stays below the deck
local CUT_SLOPE = 0.75 -- steepness of cuttings and embankments beside a road

function Heightfield.new(layout: any, yieldEvery: (() -> ())?): Heightfield
	local land = Land.new(layout, yieldEvery)
	local river = River.new(layout, land.height)
	local roads = RoadNetwork.new(layout, land, river)

	local places = layout.Places
	local placeCount = #places
	local placeCode: { number } = table.create(placeCount)
	for i, place in places do
		placeCode[i] = CODE[place.Material] or CODE.Ground
	end
	local roadCode: { number } = {}
	for i, road in roads.roads do
		roadCode[i] = CODE[layout.RoadClasses[road.Class].Material] or CODE.Ground
	end
	local zones = layout.Zones
	local zoneCode: { number } = {}
	for i, zone in zones do
		zoneCode[i] = CODE[zone.Material] or CODE.Grass
	end
	local forest: Geometry.Rect? = nil
	for _, hill in layout.Hills do
		if hill.Id == "ForestedHills" then
			forest = hill.Rect
		end
	end

	local landHeight = land.height
	local nearestRoad = roads.nearest
	local carve = river.carve

	local function surface(x: number, z: number): (number, number, number?)
		local h = landHeight(x, z)
		local material = 0
		for i = placeCount, 1, -1 do
			local r = places[i].Rect
			if x >= r.MinX and x <= r.MaxX and z >= r.MinZ and z <= r.MaxZ then
				material = placeCode[i]
				break
			end
		end

		local e, roadY, roadIndex, onBridge = nearestRoad(x, z)
		if e then
			local bed = roadY - (if onBridge then BRIDGE_BED else ROAD_BED)
			if e <= ROAD_PAD then
				h = bed
				material = if onBridge then CODE.Ground else roadCode[roadIndex]
			else
				local k = CUT_SLOPE * (e - ROAD_PAD)
				if h > bed + k then
					h = bed + k
				elseif h < bed - k then
					h = bed - k
				end
			end
		end

		local carved, water, zone = carve(x, z, h)
		if zone == 1 then
			material = CODE.Mud
		elseif zone == 2 then
			material = CODE.Sand
		end
		return carved, material, water
	end

	local function naturalMaterial(height: number, slope: number, x: number, z: number): number
		if slope > 1.1 then
			return CODE.Rock
		elseif height > 520 then
			return if slope > 0.35 or height > 700 then CODE.Rock else CODE.Ground
		elseif slope > 0.7 then
			return if height > 300 then CODE.Rock else CODE.Ground
		end
		for i, zone in zones do
			if Geometry.inRect(zone.Rect, x, z) then
				return zoneCode[i]
			end
		end
		if forest then
			-- The forested hills get leafy ground with a ragged edge (trees follow in a later milestone).
			local wx = x + 160 * math.noise(x / 400 + 0.41, z / 400 + 0.93, 13.7)
			local wz = z + 160 * math.noise(x / 400 + 3.17, z / 400 + 0.29, 14.9)
			if Geometry.rectDistance(forest, wx, wz) < 120 then
				return CODE.LeafyGrass
			end
		end
		if math.noise(x / 340 + 0.21, z / 340 + 0.63, 11.3) > 0.22 then
			return CODE.LeafyGrass
		end
		return CODE.Grass
	end

	return {
		land = land,
		river = river,
		roads = roads,
		surface = surface,
		naturalMaterial = naturalMaterial,
	}
end

return Heightfield
