--!strict
--!native
-- The finished terrain surface: land, roads cut and filled into it, and the river carved last.
-- surface(x, z) is called for every 4-stud column of the map by the terrain builder.
-- Pure Luau, tested offline (tests/map).

local Biomes = require(script.Parent.Biomes)
local Fields = require(script.Parent.Fields)
local Geometry = require(script.Parent.Geometry)
local Lakes = require(script.Parent.Lakes)
local Land = require(script.Parent.Land)
local River = require(script.Parent.River)
local RoadNetwork = require(script.Parent.RoadNetwork)

export type Heightfield = {
	land: Land.Land,
	river: River.River,
	roads: RoadNetwork.RoadNetwork,
	lakes: Lakes.Lakes,
	fields: Fields.Fields,
	biomes: Biomes.Biomes,
	-- Terrain height, material code and water surface or nil. Material codes of 0 or below are
	-- natural ground, chosen later by naturalMaterial from the slope (-1 = beside water: lush).
	surface: (x: number, z: number) -> (number, number, number?),
	-- Material for natural ground, from height, slope (rise per stud), position and the code
	-- surface() returned there (0 or -1).
	naturalMaterial: (height: number, slope: number, x: number, z: number, hint: number?) -> number,
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
	"Basalt",
})

-- Material code meaning "natural ground beside the river or a lake" (lush grass).
Heightfield.WATERSIDE = -1

local CODE: { [string]: number } = {}
for i, name in Heightfield.Materials do
	CODE[name] = i
end

local ROAD_PAD = 2 -- studs of road bed on each side beyond the road surface
local ROAD_BED = 0.6 -- terrain sits this far below the road surface (the road parts cover it)
local BRIDGE_BED = 3.6 -- under a bridge deck the terrain stays below the deck
local CUT_SLOPE = 0.75 -- steepness of cuttings and embankments beside a road
local SHOULDER = 4 -- studs of bare earth beside the road surface (the gravel shoulder)
local WATERSIDE = 40 -- studs beside the river and lakes with lush grass

function Heightfield.new(layout: any, yieldEvery: (() -> ())?): Heightfield
	local land = Land.new(layout, yieldEvery)
	local river = River.new(layout, land.height)
	local roads = RoadNetwork.new(layout, land, river)
	local lakes = Lakes.new(layout, land.height)
	local fields = Fields.new(layout, land, roads, river, lakes)
	local biomes = Biomes.new(layout)

	local places = layout.Places
	local placeCount = #places
	local placeCode: { number } = table.create(placeCount)
	for i, place in places do
		-- Places that are fields get their crop rows from naturalMaterial.
		placeCode[i] = if place.Crop then 0 else CODE[place.Material] or CODE.Ground
	end
	local roadCode: { number } = {}
	for i, road in roads.roads do
		roadCode[i] = CODE[layout.RoadClasses[road.Class].Material] or CODE.Ground
	end
	-- Zones with a fixed material (the others are farmland, see Fields).
	local materialZones: { { rect: Geometry.Rect, code: number } } = {}
	for _, zone in layout.Zones do
		if zone.Material then
			table.insert(materialZones, { rect = zone.Rect, code = CODE[zone.Material] or CODE.Grass })
		end
	end
	-- Crop row materials.
	local cropCodes: { [string]: { number } } = {}
	if layout.Farming then
		for name, crop in layout.Farming.Crops do
			if crop.Rows then
				cropCodes[name] = { CODE[crop.Rows[1]], CODE[crop.Rows[2]] }
			else
				cropCodes[name] = { CODE[crop.Material], CODE[crop.Material] }
			end
		end
	end

	local landHeight = land.height
	local nearestRoad = roads.nearest
	local carve = river.carve
	local carveLakes = lakes.carve
	local cropAt = fields.cropAt
	local forestAt = biomes.forest
	local drynessAt = biomes.dryness

	local function surface(x: number, z: number): (number, number, number?)
		local h = landHeight(x, z)
		local material = 0
		local inPlace = false
		for i = placeCount, 1, -1 do
			local r = places[i].Rect
			if x >= r.MinX and x <= r.MaxX and z >= r.MinZ and z <= r.MaxZ then
				material = placeCode[i]
				inPlace = true
				break
			end
		end

		local e, roadY, roadIndex, onBridge = nearestRoad(x, z)
		if e then
			local bed = roadY - (if onBridge then BRIDGE_BED else ROAD_BED)
			if e <= ROAD_PAD then
				h = bed
				material = if onBridge or e > 0 then CODE.Ground else roadCode[roadIndex]
			else
				local k = CUT_SLOPE * (e - ROAD_PAD)
				if h > bed + k then
					h = bed + k
				elseif h < bed - k then
					h = bed - k
				end
				if e <= SHOULDER and material == 0 then
					material = CODE.Ground
				end
				-- A broad, shallow roadside swale drains rural verges. Preserve junctions,
				-- bridge approaches and every fixed place, including cultivated property plots.
				if e > 5 and e < 10 and not onBridge and not inPlace and roads.otherDistance(x, z, roadIndex) > 12 then
					local t = (e - 5) / 5
					h -= 0.65 * math.sin(math.pi * t) ^ 2
				end
				-- Broken soil/grass edges follow broad patches rather than a solid stripe.
				if e > SHOULDER and e < 7 and material == 0 and not inPlace then
					local fringe = math.noise(x / 31 + 0.17, z / 31 + 0.53, 65.3)
					if e < 5.2 + 2 * fringe then
						material = CODE.Ground
					end
				end
			end
		end

		local lakeH, lakeWater, lakeZone, shore = carveLakes(x, z, h)
		if lakeZone ~= 0 or lakeWater then
			h = lakeH
			if lakeZone == 1 then
				material = if math.noise(x / 30 + 0.3, z / 30 + 0.8, 61.1) > 0.15 then CODE.Sand else CODE.Mud
			elseif lakeZone == 2 then
				material = if math.noise(x / 24 + 0.9, z / 24 + 0.2, 62.3) > -0.2 then CODE.Sand else CODE.Mud
			end
			if lakeWater then
				return h, material, lakeWater
			end
		end

		local carved, water, zone, edge = carve(x, z, h)
		if zone == 1 then
			-- River bed: mud with patches of sand and gravel.
			local n = math.noise(x / 28 + 0.6, z / 28 + 0.1, 63.7)
			material = if n > 0.3 then CODE.Sand elseif n < -0.35 then CODE.Slate else CODE.Mud
		elseif zone == 2 then
			-- Damp sediment stays near the water; the upper bank recovers vegetation in
			-- irregular patches. This avoids the continuous bright sand ribbon.
			local deposit = math.noise(x / 38 + 0.4, z / 38 + 0.5, 64.9)
			local wetToe = edge / river.bankWidth < 0.3 + 0.18 * deposit
			material = if wetToe
				then (if deposit > 0.22 then CODE.Sand else CODE.Mud)
				elseif deposit < -0.27 then CODE.Ground
				else Heightfield.WATERSIDE
		elseif material == 0 and (edge < WATERSIDE or shore < WATERSIDE) then
			material = Heightfield.WATERSIDE
		end
		return carved, material, water
	end

	local function naturalMaterial(height: number, slope: number, x: number, z: number, hint: number?): number
		-- Fields: crop rows across the field, a bare yard around the barns.
		if slope < 0.45 then
			local field, onRow = cropAt(x, z)
			if field then
				if onRow == nil then
					return CODE.Ground
				end
				local codes = cropCodes[field.Crop]
				return if onRow then codes[1] else codes[2]
			end
		end
		local n1 = math.noise(x / 37 + 0.13, z / 37 + 0.57, 51.1) -- small patches
		local n2 = math.noise(x / 160 + 0.71, z / 160 + 0.29, 52.3) -- larger patches
		-- Vary erosion thresholds across connected patches so material changes do not
		-- trace identical elevation/slope contour lines over the entire district.
		local erosionSlope = slope + 0.12 * n2 + 0.04 * n1
		if height > 520 then
			-- The high mountains: cliffs of rock, slate and dark basalt, scree, green alpine slopes.
			local high = (height - 520) / 300 + 0.25 * n2
			if erosionSlope > 1.0 or (erosionSlope > 0.75 and high > 0.6) then
				return if n1 > 0.2 then CODE.Slate elseif n2 > 0.3 then CODE.Basalt else CODE.Rock
			elseif high > 0.9 then
				return if n1 > 0.25 then CODE.Slate elseif n1 < -0.3 then CODE.Ground else CODE.Rock
			elseif erosionSlope > 0.6 then
				return if n1 > 0.15 then CODE.Rock elseif n1 < -0.25 then CODE.Basalt else CODE.Ground
			end
			return if n1 > 0.35 then CODE.Ground elseif n2 > -0.1 then CODE.LeafyGrass else CODE.Grass
		end
		if erosionSlope > 1.0 then
			return if n1 > 0.3 then CODE.Slate else CODE.Rock
		elseif erosionSlope > 0.65 then
			return if n1 > 0.05 then CODE.Rock else CODE.Ground
		elseif erosionSlope > 0.42 then
			-- Steeper banks show red earth.
			return if n2 + 0.3 * n1 > 0.15 then CODE.Ground else CODE.LeafyGrass
		end
		for _, zone in materialZones do
			local wx = x + 90 * math.noise(x / 300 + 0.41, z / 300 + 0.93, 13.7)
			local wz = z + 90 * math.noise(x / 300 + 3.17, z / 300 + 0.29, 14.9)
			if Geometry.inRect(zone.rect, wx, wz) then
				return if n1 > 0.35 then CODE.Grass else zone.code
			end
		end
		if hint == Heightfield.WATERSIDE then
			return if n1 > 0.25 then CODE.Grass else CODE.LeafyGrass
		end
		local forest = forestAt(x, z)
		if forest > 0.5 then
			-- Forest floor.
			return if n1 > 0.4 then CODE.Ground else CODE.LeafyGrass
		end
		local dry = drynessAt(x, z)
		if n1 + 0.35 * n2 > 0.55 - 0.45 * dry then
			return CODE.Ground -- bare red earth
		end
		if n2 > 0.18 or forest > 0.3 then
			return CODE.LeafyGrass
		end
		return CODE.Grass
	end

	return {
		land = land,
		river = river,
		roads = roads,
		lakes = lakes,
		fields = fields,
		biomes = biomes,
		surface = surface,
		naturalMaterial = naturalMaterial,
	}
end

return Heightfield
