--!strict
--!native
-- The finished terrain surface: land, roads cut and filled into it, and the river carved last.
-- surface(x, z) is called for every 4-stud column of the map by the terrain builder.
-- Pure Luau, tested offline (tests/map).

local Biomes = require(script.Parent.Biomes)
local Fields = require(script.Parent.Fields)
local Geometry = require(script.Parent.Geometry)
local GroundCover = require(script.Parent.GroundCover)
local Lakes = require(script.Parent.Lakes)
local Land = require(script.Parent.Land)
local LandscapeConfig = require(script.Parent.LandscapeConfig)
local OriginalSurface = require(script.Parent.OriginalSurface)
local River = require(script.Parent.River)
local RoadNetwork = require(script.Parent.RoadNetwork)
local SegmentGrid = require(script.Parent.SegmentGrid)

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
	previousSurface: (x: number, z: number) -> (number, number, number?),
	previousNaturalMaterial: (height: number, slope: number, x: number, z: number, hint: number?) -> number,
	naturalMaterial: (height: number, slope: number, x: number, z: number, hint: number?) -> number,
	-- Exact pre-highland-3 surface/material model, retained for conservative saved-voxel upgrades.
	legacySurface: (x: number, z: number) -> (number, number, number?),
	legacyNaturalMaterial: (height: number, slope: number, x: number, z: number, hint: number?) -> number,
	-- The original pre-overhaul generated map (d3edcc7), including its straight banks/soil.
	originalSurface: (x: number, z: number) -> (number, number, number?),
	originalNaturalMaterial: (height: number, slope: number, x: number, z: number, hint: number?) -> number,
	-- Editor diagnostics: spatial weight and proposed relief before the world-floor taper.
	reliefMask: (x: number, z: number) -> number,
	relief: (x: number, z: number) -> number,
	highland4: any, -- exact saved pre-rework generator, including its material model
	additionalBaselines: { any },
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

	local function legacySurface(x: number, z: number): (number, number, number?)
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

	local function legacyNaturalMaterial(height: number, slope: number, x: number, z: number, hint: number?): number
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

	-- Protect complete field/settlement blends, not just a few centre points. A spatial grid
	-- keeps the per-voxel cost independent of the number of fields on the whole map.
	local config = LandscapeConfig
	local CELL = 256
	type ProtectedRect = { Rect: Geometry.Rect, Clear: number, Fade: number }
	local protected: { [number]: { ProtectedRect } } = {}
	local function key(cx: number, cz: number): number
		return (cx + 1024) * 4096 + cz + 1024
	end
	local function protect(rect: Geometry.Rect, clear: number, fade: number)
		local item = { Rect = rect, Clear = clear, Fade = fade }
		local reach = clear + fade * 4 -- include the wider mountain reconstruction transition
		for cx = math.floor((rect.MinX - reach) / CELL), math.floor((rect.MaxX + reach) / CELL) do
			for cz = math.floor((rect.MinZ - reach) / CELL), math.floor((rect.MaxZ + reach) / CELL) do
				local cell = key(cx, cz)
				local list = protected[cell]
				if not list then
					list = {}
					protected[cell] = list
				end
				table.insert(list, item)
			end
		end
	end
	for _, place in places do
		protect(place.Rect, place.Margin + config.PlaceProtection, config.PlaceFade)
	end
	for _, field in fields.list do
		protect(field, config.FieldProtection, config.FieldFade)
	end
	for _, zone in materialZones do
		protect(zone.rect, config.FieldProtection, config.FieldFade)
	end
	-- RoadNetwork.nearest intentionally stops at 200 studs. Reusing it for a wider
	-- mountain fade would jump abruptly from partial protection to no protection there.
	local mountainRoadGrid = SegmentGrid.new(256)
	local mountainRoadSegments: { any } = {}
	for _, road in roads.roads do
		for _, run in road.runs do
			local i, j = run.First, run.Last
			local segment = { road.line.xs[i], road.line.zs[i], road.line.xs[j], road.line.zs[j], road.Width / 2 }
			local id = #mountainRoadSegments + 1
			mountainRoadSegments[id] = segment
			SegmentGrid.insert(
				mountainRoadGrid,
				id,
				segment[1],
				segment[2],
				segment[3],
				segment[4],
				segment[5] + config.RoadProtection + config.RoadFade * 4
			)
		end
	end
	local function mountainRoadDistance(x: number, z: number): number
		local best = math.huge
		local ids = SegmentGrid.query(mountainRoadGrid, x, z)
		if ids then
			for _, id in ids do
				local s = mountainRoadSegments[id]
				best = math.min(best, Geometry.segmentDistance(s[1], s[2], s[3], s[4], x, z) - s[5])
			end
		end
		return best
	end
	-- River.nearest() is intentionally indexed only through its 260-stud carving reach.
	-- Relief fades farther out, so it needs its own expanded index: using the carving
	-- index there would make a discontinuity where an adjacent spatial cell has no ids.
	local riverLine = river.line
	local riverProtectionGrid = SegmentGrid.new(128)
	local riverProtectionReach = river.reach + config.RiverProtection + config.RiverFade * 4
	for i = 1, #riverLine.xs - 1 do
		SegmentGrid.insert(
			riverProtectionGrid,
			i,
			riverLine.xs[i],
			riverLine.zs[i],
			riverLine.xs[i + 1],
			riverLine.zs[i + 1],
			riverProtectionReach
		)
	end
	local function riverProtectionDistance(x: number, z: number): number
		local ids = SegmentGrid.query(riverProtectionGrid, x, z)
		local best = math.huge
		if ids then
			for _, i in ids do
				local distance = Geometry.segmentDistance(
					riverLine.xs[i],
					riverLine.zs[i],
					riverLine.xs[i + 1],
					riverLine.zs[i + 1],
					x,
					z
				)
				best = math.min(best, distance)
			end
		end
		return best
	end
	local function lakeProtectionMask(x: number, z: number, fadeScale: number?): number
		-- Lake.shoreDistance is also reach-limited. Protect each complete existing basin,
		-- then fade outside its conservative circular bound instead of jumping to infinity
		-- when the old shoreline query leaves its search radius.
		local mask = 1
		local fade = config.LakeFade * (fadeScale or 1)
		for _, lake in lakes.list do
			local radius = math.max(lake.Reach, math.max(lake.Rx, lake.Rz) + config.LakeProtection)
			local dx, dz = x - lake.X, z - lake.Z
			if math.abs(dx) < radius + fade and math.abs(dz) < radius + fade then
				local distance = math.sqrt(dx * dx + dz * dz) - radius
				mask = math.min(mask, Geometry.smoothstep(distance / fade))
			end
		end
		return mask
	end

	local function reliefMask(x: number, z: number, includeBoundary: boolean?): number
		if not config.Enabled then
			return 0
		end
		local mask = if includeBoundary
			then 1
			else Geometry.smoothstep(
				(layout.Bounds.Half - math.max(math.abs(x), math.abs(z)) - config.EdgeProtection) / config.EdgeFade
			)
		if mask == 0 then
			return 0
		end
		local fadeScale = if includeBoundary then 4 else 1
		local list = protected[key(math.floor(x / CELL), math.floor(z / CELL))]
		if list then
			for _, item in list do
				local distance = Geometry.rectDistance(item.Rect, x, z)
				mask = math.min(mask, Geometry.smoothstep((distance - item.Clear) / (item.Fade * fadeScale)))
				if mask == 0 then
					return 0
				end
			end
		end
		local edge = if includeBoundary then mountainRoadDistance(x, z) else nearestRoad(x, z)
		if edge then
			mask = math.min(mask, Geometry.smoothstep((edge - config.RoadProtection) / (config.RoadFade * fadeScale)))
			if mask == 0 then
				return 0
			end
		end
		local riverDistance = riverProtectionDistance(x, z)
		mask = math.min(
			mask,
			Geometry.smoothstep((riverDistance - river.reach - config.RiverProtection) / (config.RiverFade * fadeScale)),
			lakeProtectionMask(x, z, fadeScale)
		)
		return mask
	end

	local function reliefShape(x: number, z: number): number
		-- Shared domain warping bends continuous ridges and drainage folds. The rotated,
		-- anisotropic octaves form connected landforms rather than isolated decorative bumps.
		local wx = x + config.DomainWarp * math.noise(x / 1100 + 0.19, z / 1100 + 0.71, 71.3)
		local wz = z + config.DomainWarp * math.noise(x / 1100 + 2.17, z / 1100 + 0.23, 72.7)
		local u, v = 0.82 * wx + 0.57 * wz, -0.57 * wx + 0.82 * wz
		local broad = math.noise(u / config.RidgeWavelength + 0.43, v / (config.RidgeWavelength * 1.3) + 0.13, 73.1)
		local fold = 1
			- math.abs(
				2 * math.noise(u / config.FoldWavelength + 0.37, v / (config.FoldWavelength * 1.65) + 0.61, 74.9)
			)
		local detail = math.noise(wx / config.DetailWavelength + 0.29, wz / config.DetailWavelength + 0.83, 75.7)
		return math.clamp(1.2 * broad + 0.45 * (fold * fold - 0.45) + 0.16 * detail, -1, 1)
	end

	local function relief(x: number, z: number): number
		local mask = reliefMask(x, z)
		if mask == 0 then
			return 0
		end
		return config.ReliefAmplitude * mask * reliefShape(x, z)
	end

	local function surface(x: number, z: number): (number, number, number?)
		local height, material, water = legacySurface(x, z)
		if water ~= nil then
			return height, material, water
		end
		local floorWeight =
			Geometry.smoothstep((height - layout.Bounds.FloorY - config.FloorProtection) / config.FloorFade)
		return height + relief(x, z) * floorWeight, material, nil
	end

	local function previousNaturalMaterial(height: number, slope: number, x: number, z: number, hint: number?): number
		local original = legacyNaturalMaterial(height, slope, x, z, hint)
		local mask = reliefMask(x, z)
		if mask < 0.08 or original == CODE.Rock or original == CODE.Slate or original == CODE.Basalt then
			return original
		end
		-- Damp folds expose dark lateritic soil; ridges recover grass in connected patches.
		-- Native terrain blends these material boundaries without extra ground-cover parts.
		local shape = reliefShape(x, z)
		local damp = math.noise(x / 160 + 0.53, z / 310 + 0.37, 76.3)
		if mask > 0.45 and shape < -0.24 and damp > 0.09 and slope < 0.35 then
			return CODE.Mud
		end
		local patches = math.noise(x / 31 + 0.41, z / 31 + 0.73, 77.9)
			+ 0.45 * math.noise(x / 145 + 0.23, z / 145 + 0.59, 78.7)
		if patches > 0.38 - 0.22 * mask and forestAt(x, z) < 0.55 then
			return CODE.Ground
		end
		if original == CODE.Grass or original == CODE.LeafyGrass or original == CODE.Ground then
			return if patches < -0.08 or forestAt(x, z) > 0.3 then CODE.LeafyGrass else CODE.Grass
		end
		return original
	end

	local function naturalMaterial(height: number, slope: number, x: number, z: number, hint: number?): number
		local previous = previousNaturalMaterial(height, slope, x, z, hint)
		local mask = reliefMask(x, z)
		-- Settlements, authored fields, banks and mountain rock keep their existing materials.
		-- The old lowland model added small bare patches even on gentle, wet grassland; at
		-- map scale these read as camouflage. Soil exposure now follows connected dry,
		-- eroding slopes, while gentle highland ground maintains a continuous green cover.
		if
			mask < 0.08
			or height > 520
			or hint == Heightfield.WATERSIDE
			or previous == CODE.Rock
			or previous == CODE.Slate
			or previous == CODE.Basalt
		then
			return previous
		end
		local forest, dry = forestAt(x, z), drynessAt(x, z)
		local drainage = math.noise(x / 160 + 0.53, z / 310 + 0.37, 76.3)
		local shape = reliefShape(x, z)
		if mask > 0.8 and slope < 0.14 and shape < -0.35 and drainage > 0.25 then
			return CODE.Mud
		end
		local erosion = math.clamp((slope - config.SoilSlopeStart) / 0.4, 0, 1)
		local exposure = math.noise(x / config.SoilPatchScale + 0.23, z / (config.SoilPatchScale * 1.6) + 0.59, 78.7)
		if slope > config.SoilSlopeStart and exposure > 0.26 - 0.14 * dry - 0.2 * erosion + (1 - mask) * 0.2 then
			return CODE.Ground
		end
		return if forest > 0.3 or drainage < -0.1 then CODE.LeafyGrass else CODE.Grass
	end

	local original = OriginalSurface.new(layout, {
		land = land,
		river = river,
		roads = roads,
		lakes = lakes,
		fields = fields,
		biomes = biomes,
	}, Heightfield.Materials)
	local result: any = {
		land = land,
		river = river,
		roads = roads,
		lakes = lakes,
		fields = fields,
		biomes = biomes,
		surface = surface,
		naturalMaterial = naturalMaterial,
		previousSurface = surface,
		previousNaturalMaterial = previousNaturalMaterial,
		legacySurface = legacySurface,
		legacyNaturalMaterial = legacyNaturalMaterial,
		originalSurface = original.surface,
		originalNaturalMaterial = original.naturalMaterial,
		reliefMask = reliefMask,
		relief = relief,
	}
	-- Freeze all historical closures before replacing the active surface. In particular,
	-- neither a road's original vertical profile nor a saved terrain baseline is recalculated.
	result.highland4 = table.clone(result)
	result.additionalBaselines = { { Surface = surface, Material = naturalMaterial } }
	local weathered = Land.new(layout, yieldEvery, true)
	local mountainStart = layout.Bounds.Playable - layout.Mountains.StartInside - 620
	result.surface = function(x: number, z: number): (number, number, number?)
		local h, code, water = surface(x, z)
		if water ~= nil or code > 0 then
			return h, code, water
		end
		local mountain = 0
		if math.max(math.abs(x), math.abs(z)) > mountainStart then
			local mask = reliefMask(x, z, true)
			if mask > 0 then
				mountain = (weathered.height(x, z) - landHeight(x, z)) * mask
			end
		end
		local folds = 8 * reliefShape(x, z) * reliefMask(x, z)
		local floor = Geometry.smoothstep((h - layout.Bounds.FloorY - config.FloorProtection) / config.FloorFade)
		return math.max(layout.Bounds.FloorY, h + (mountain + folds) * floor), code, nil
	end
	result.naturalMaterial = function(h: number, slope: number, x: number, z: number, hint: number?): number
		-- Crop rows, fixed settlements and engineered road beds retain their authored surfaces.
		if reliefMask(x, z) < 0.08 or fields.cropAt(x, z) ~= nil then
			return naturalMaterial(h, slope, x, z, hint)
		end
		return GroundCover.material(forestAt(x, z), drynessAt(x, z), slope, x, z, hint == Heightfield.WATERSIDE)
	end
	return result
end

return Heightfield
