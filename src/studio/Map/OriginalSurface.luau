--!strict
--!native
-- Immutable migration baseline: the generated terrain shipped at d3edcc7, before the
-- environment overhaul. These formulas deliberately remain unchanged so the upgrader can
-- recognize saved original-map voxels and preserve manual sculpting/paint that differs.
-- Land, road grades, place heights, lake profiles and the river route/levels are shared with
-- the current map: none of those anchors changed during the environment overhaul.
local Geometry = require(script.Parent.Geometry)
local OriginalSurface = {}
local ORIGINAL_WATERSIDE = -1
local ROAD_PAD = 2 -- studs of road bed on each side beyond the road surface
local ROAD_BED = 0.6 -- terrain sits this far below the road surface (the road parts cover it)
local BRIDGE_BED = 3.6 -- under a bridge deck the terrain stays below the deck
local CUT_SLOPE = 0.75 -- steepness of cuttings and embankments beside a road
local SHOULDER = 4 -- studs of bare earth beside the road surface (the gravel shoulder)
local WATERSIDE = 40 -- studs beside the river and lakes with lush grass

function OriginalSurface.new(layout: any, context: any, materials: { string }): any
	local land, river, roads = context.land, context.river, context.roads
	local lakes, fields, biomes = context.lakes, context.fields, context.biomes
	local CODE: { [string]: number } = {}
	for i, name in materials do
		CODE[name] = i
	end
	local depths: { number } = {}
	local maxHalf: number = layout.River.Width / 2
	for i, halfWidth in river.halfWidths do
		depths[i] = layout.River.Depth * (0.45 + 0.55 * halfWidth / maxHalf)
	end
	local function originalCarve(x: number, z: number, height: number): (number, number?, number, number)
		local distance, water, index, halfWidth = river.nearest(x, z)
		local edge = distance - halfWidth
		if distance >= river.reach then
			return height, nil, 0, edge
		end
		local surface, zone
		if distance < halfWidth then
			local fraction = distance / halfWidth
			surface = water - depths[index] * (1 - fraction * fraction)
			zone = 1
		elseif distance < halfWidth + river.bankWidth then
			surface = water + river.drop * (distance - halfWidth) / river.bankWidth
			zone = 2
		else
			surface = water + river.drop + (distance - halfWidth - river.bankWidth) * river.wallSlope
			zone = 3
		end
		if surface >= height then
			return height, if zone == 1 and height < water then water else nil, 0, edge
		end
		return surface, if zone == 1 then water else nil, zone, edge
	end
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
	local carve = originalCarve
	local carveLakes = lakes.carve
	local cropAt = fields.cropAt
	local forestAt = biomes.forest
	local drynessAt = biomes.dryness

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
			material = if math.noise(x / 22 + 0.4, z / 22 + 0.5, 64.9) > -0.1 then CODE.Sand else CODE.Mud
		elseif material == 0 and (edge < WATERSIDE or shore < WATERSIDE) then
			material = ORIGINAL_WATERSIDE
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
		if height > 520 then
			-- The high mountains: cliffs of rock, slate and dark basalt, scree, green alpine slopes.
			local high = (height - 520) / 300 + 0.25 * n2
			if slope > 1.0 or (slope > 0.75 and high > 0.6) then
				return if n1 > 0.2 then CODE.Slate elseif n2 > 0.3 then CODE.Basalt else CODE.Rock
			elseif high > 0.9 then
				return if n1 > 0.25 then CODE.Slate elseif n1 < -0.3 then CODE.Ground else CODE.Rock
			elseif slope > 0.6 then
				return if n1 > 0.15 then CODE.Rock elseif n1 < -0.25 then CODE.Basalt else CODE.Ground
			end
			return if n1 > 0.35 then CODE.Ground elseif n2 > -0.1 then CODE.LeafyGrass else CODE.Grass
		end
		if slope > 1.0 then
			return if n1 > 0.3 then CODE.Slate else CODE.Rock
		elseif slope > 0.65 then
			return if n1 > 0.05 then CODE.Rock else CODE.Ground
		elseif slope > 0.42 then
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
		if hint == ORIGINAL_WATERSIDE then
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

	return { surface = surface, naturalMaterial = naturalMaterial }
end

return OriginalSurface
