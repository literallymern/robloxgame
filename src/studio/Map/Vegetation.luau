--!strict
--!native
-- Where the trees, bushes and rocks stand. Trees follow the forest cover of Biomes (forests,
-- groves, scattered trees), a belt along the river and the lakes, hedgerows between fields and
-- tree rows along some roads. Nothing grows on roads and their verges, in water, in fields, in
-- places, on cliffs or above the tree line. Rocks lie on steep ground, in the mountains and at
-- the river's cascades. Repeatable: the same layout always gives the same plants.
-- Pure Luau, tested offline.

local Geometry = require(script.Parent.Geometry)
local Hash = require(script.Parent.Hash)
local SegmentGrid = require(script.Parent.SegmentGrid)

export type Plant = {
	Kind: string, -- Broadleaf, Acacia, Eucalyptus, Pine, Bush or Rock
	X: number,
	Y: number, -- ground height at the plant (the builder sinks trunks and rocks into it)
	Z: number,
	Size: number, -- tree height, bush width or rock size in studs
	Yaw: number, -- rotation around the vertical axis in radians
	Seed: number, -- 0..1, for shape variation
	Slope: number, -- ground slope at the plant (rise per stud)
}

export type Vegetation = {
	trees: { Plant },
	bushes: { Plant },
	rocks: { Plant },
}

local TREE_CELL = 18 -- studs; at most one tree per cell
local TREE_SCALE = 0.28 -- fewer fuller crowns: keep the five-part trees within the geometry budget
local BUSH_CELL = 15
local ROCK_CELL = 30
local HEDGE_STEP = 9 -- studs between hedge bushes
local PLACE_CLEARANCE = 15
local MAX_TREE_SLOPE = 0.85
local MAX_BUSH_SLOPE = 1.0
local WIRE_CORRIDOR = 12 -- studs on each side of a power line kept free of trees

-- Height ranges in studs (tree height).
local TREE_SIZES: { [string]: { number } } = {
	Broadleaf = { 16, 36 },
	Acacia = { 15, 28 },
	Eucalyptus = { 30, 56 },
	Pine = { 24, 44 },
}

local Vegetation = {}

Vegetation.TreeKinds = table.freeze({ "Acacia", "Broadleaf", "Eucalyptus", "Pine" })

-- `details` (from RoadDetails, optional): power lines get a corridor free of trees.
function Vegetation.new(
	layout: any,
	hf: any,
	details: any?,
	yieldEvery: (() -> ())?,
	groundSampler: ((number, number, boolean?) -> (number?, number))?
): Vegetation
	local config = layout.Vegetation
	local half: number = layout.Bounds.Half
	local treeLine: number = config.TreeLine
	local biomes = hf.biomes
	local roads = hf.roads
	local river = hf.river
	local lakes = hf.lakes
	local cropAt = hf.fields.cropAt
	local surface = hf.surface
	local riverside = config.Riverside
	local density: number = config.Density or 1 -- biomes.forest already includes it

	local verges: { number } = {}
	for i, road in roads.roads do
		verges[i] = layout.RoadClasses[road.Class].Verge
	end

	local places = layout.Places
	local function inPlace(x: number, z: number, margin: number): boolean
		for _, place in places do
			local r = place.Rect
			if x >= r.MinX - margin and x <= r.MaxX + margin and z >= r.MinZ - margin and z <= r.MaxZ + margin then
				return true
			end
		end
		return false
	end

	-- Ground height and slope at a point, or nil where nothing may grow (water).
	local function ground(x: number, z: number, allowWater: boolean?): (number?, number)
		if groundSampler then
			return groundSampler(x, z, allowWater)
		end
		local h, _, water = surface(x, z)
		if water and not allowWater then
			return nil, 0
		end
		local e = surface(x + 3, z)
		local w = surface(x - 3, z)
		local s = surface(x, z + 3)
		local n = surface(x, z - 3)
		local dx, dz = (e - w) / 6, (s - n) / 6
		return h, math.sqrt(dx * dx + dz * dz)
	end

	-- Distance outside the water's edge of the river or a lake.
	local function waterEdge(x: number, z: number): number
		local d, _, _, halfWidth = river.nearest(x, z)
		return math.min(d - halfWidth, lakes.shoreDistance(x, z))
	end

	-- Clear of places, fields and roads: at least `minEdge` studs from a road's edge, or outside
	-- the road's whole verge when minEdge is nil.
	local function clearOfWorks(x: number, z: number, minEdge: number?): boolean
		if inPlace(x, z, PLACE_CLEARANCE) then
			return false
		end
		local e, _, roadIndex = roads.nearest(x, z)
		if e and e < (minEdge or verges[roadIndex]) then
			return false
		end
		return cropAt(x, z) == nil
	end

	local wireGrid = SegmentGrid.new(64)
	local wires: { { number } } = {}
	if details then
		for _, pair in details.wires do
			local a, b = details.poles[pair[1]], details.poles[pair[2]]
			table.insert(wires, { a.X, a.Z, b.X, b.Z })
			SegmentGrid.insert(wireGrid, #wires, a.X, a.Z, b.X, b.Z, WIRE_CORRIDOR)
		end
	end
	local function underWires(x: number, z: number): boolean
		local ids = SegmentGrid.query(wireGrid, x, z)
		if ids then
			for _, id in ids do
				local w = wires[id]
				if Geometry.segmentDistance(w[1], w[2], w[3], w[4], x, z) < WIRE_CORRIDOR then
					return true
				end
			end
		end
		return false
	end

	local trees: { Plant } = {}
	local bushes: { Plant } = {}
	local rocks: { Plant } = {}

	local function addTree(kind: string, x: number, z: number, y: number, slope: number, seed: number, scale: number)
		if underWires(x, z) then
			return
		end
		local range = TREE_SIZES[kind]
		local size = (range[1] + (range[2] - range[1]) * seed) * scale
		table.insert(trees, {
			Kind = kind,
			X = x,
			Y = y,
			Z = z,
			Size = size,
			Yaw = Hash.unit(math.floor(x), math.floor(z), 57) * 2 * math.pi,
			Seed = seed,
			Slope = slope,
		})
	end

	-- Trees ------------------------------------------------------------------------------------
	local edge = half - 30
	local cells = math.floor(2 * half / TREE_CELL)
	for iz = 0, cells - 1 do
		for ix = 0, cells - 1 do
			local x = -half + (ix + Hash.range(ix, iz, 1, 0.1, 0.9)) * TREE_CELL
			local z = -half + (iz + Hash.range(ix, iz, 2, 0.1, 0.9)) * TREE_CELL
			if math.abs(x) > edge or math.abs(z) > edge then
				continue
			end
			local roll = Hash.unit(ix, iz, 3)
			local cover = biomes.forest(x, z)
			local riverDistance = waterEdge(x, z)
			local isRiverside = false
			if riverDistance < riverside.Width then
				local belt = riverside.Forest * density * (1 - riverDistance / riverside.Width)
				if belt > cover then
					cover = belt
					isRiverside = true
				end
			end
			if roll >= cover * TREE_SCALE then
				continue
			end
			if riverDistance < river.bankWidth + 3 or not clearOfWorks(x, z, nil) then
				continue
			end
			local y, slope = ground(x, z)
			if y == nil or slope > MAX_TREE_SLOPE or y > treeLine then
				continue
			end
			if y > treeLine - 160 and roll >= cover * TREE_SCALE * (treeLine - y) / 160 then
				continue
			end
			local kindRoll = Hash.unit(ix, iz, 4)
			local kind
			if isRiverside then
				kind = if kindRoll < (riverside.Mix.Broadleaf or 1) then "Broadleaf" else "Eucalyptus"
			else
				local region = biomes.regionAt(x, z)
				kind = biomes.pickKind(region, kindRoll)
			end
			-- Trees grow a little smaller high up.
			local scale = 1 - 0.25 * math.clamp((y - 300) / 340, 0, 1)
			addTree(kind, x, z, y, slope, Hash.unit(ix, iz, 5), scale)
		end
		if yieldEvery and iz % 8 == 0 then
			yieldEvery()
		end
	end

	-- Tree rows along roads (avenues) --------------------------------------------------------
	local roadById: { [string]: number } = {}
	for i, road in roads.roads do
		roadById[road.Id] = i
	end
	for k, avenue in config.Avenues or {} do
		local index = roadById[avenue.Road]
		if not index then
			continue
		end
		local road = roads.roads[index]
		local line = road.line
		local offset = road.Width / 2 + 6
		local station = 0
		local s = avenue.From
		local i = 1
		while s <= math.min(avenue.To, line.length) do
			while i < #line.s - 1 and line.s[i + 1] < s do
				i += 1
			end
			local t = (s - line.s[i]) / (line.s[i + 1] - line.s[i])
			local cx = line.xs[i] + (line.xs[i + 1] - line.xs[i]) * t
			local cz = line.zs[i] + (line.zs[i + 1] - line.zs[i]) * t
			local dx, dz = line.xs[i + 1] - line.xs[i], line.zs[i + 1] - line.zs[i]
			local len = math.sqrt(dx * dx + dz * dz)
			local rx, rz = -dz / len, dx / len
			for side = -1, 1, 2 do
				-- Preserve the authored avenue, with gaps and unequal setbacks as in a maintained
				-- roadside planting. The position is checked again after jitter, including fields.
				local seed = Hash.unit(k, station, 6 + side)
				local setback = offset + 4 * Hash.unit(k, station, 14 + side)
				local along = (Hash.unit(k, station, 17 + side) - 0.5) * avenue.Spacing * 0.22
				local x = cx + rx * setback * side + dx / len * along
				local z = cz + rz * setback * side + dz / len * along
				if
					seed > 0.1
					and not road.onBridge[i]
					and not inPlace(x, z, 4)
					and roads.otherDistance(x, z, index) > 12
					and waterEdge(x, z) > river.bankWidth + 3
					and cropAt(x, z) == nil
				then
					local e, _, _, onBridge = roads.nearest(x, z)
					local y, slope = ground(x, z)
					if y and y <= treeLine and slope < MAX_TREE_SLOPE and e and e >= 5.5 and not onBridge then
						addTree(avenue.Kind, x, z, y, slope, 0.15 + 0.8 * seed, 1)
					end
				end
			end
			s += avenue.Spacing * Hash.range(k, station, 58, 0.78, 1.25)
			station += 1
		end
	end

	-- Hedgerows and windbreaks between fields --------------------------------------------------
	local used: { [number]: boolean } = {}
	local gap: number = hf.fields.gap
	for _, field in hf.fields.list do
		if field.Fence then
			continue -- pastures are fenced instead
		end
		local sides = {
			{ field.MinX, field.MinZ - gap / 2, field.MaxX, field.MinZ - gap / 2 }, -- north
			{ field.MinX, field.MaxZ + gap / 2, field.MaxX, field.MaxZ + gap / 2 }, -- south
			{ field.MinX - gap / 2, field.MinZ, field.MinX - gap / 2, field.MaxZ }, -- west
			{ field.MaxX + gap / 2, field.MinZ, field.MaxX + gap / 2, field.MaxZ }, -- east
		}
		for sideIndex, side in sides do
			local windbreak = sideIndex == 1 and field.Crop == "Tobacco" and Hash.unit(field.Id, 0, 7) < 0.45
			if not windbreak and Hash.unit(field.Id, sideIndex, 10) > 0.3 then
				continue -- about a third of the field sides have a hedge
			end
			local length = math.max(math.abs(side[3] - side[1]), math.abs(side[4] - side[2]))
			local step = if windbreak then 22 else HEDGE_STEP
			for k = 0, math.floor(length / step) do
				local t = (k * step + step / 2) / length
				if t > 1 then
					break
				end
				local x = side[1] + (side[3] - side[1]) * t
				local z = side[2] + (side[4] - side[2]) * t
				local key = math.floor(x / 6) * 100003 + math.floor(z / 6)
				if used[key] then
					continue
				end
				used[key] = true
				local roll = Hash.unit(math.floor(x), math.floor(z), 8)
				if roll > (if windbreak then 0.75 else 0.85) then
					continue
				end
				if inPlace(x, z, 6) or waterEdge(x, z) < river.bankWidth + 3 then
					continue
				end
				local e, _, roadIndex = roads.nearest(x, z)
				if e and e < (if windbreak then verges[roadIndex] else 5) then
					continue
				end
				local y, slope = ground(x, z)
				if y == nil or slope > MAX_BUSH_SLOPE then
					continue
				end
				local seed = Hash.unit(math.floor(x), math.floor(z), 9)
				if windbreak then
					addTree("Eucalyptus", x, z, y, slope, seed, 0.9)
				else
					table.insert(bushes, {
						Kind = "Bush",
						X = x,
						Y = y,
						Z = z,
						Size = 6 + 6 * seed,
						Yaw = seed * 6151 % (2 * math.pi),
						Seed = seed,
						Slope = slope,
					})
				end
			end
		end
	end

	-- Bushes: forest edges and undergrowth, the river belt, scattered on open land ---------------
	cells = math.floor(2 * half / BUSH_CELL)
	for iz = 0, cells - 1 do
		for ix = 0, cells - 1 do
			local x = -half + (ix + Hash.range(ix, iz, 21, 0.1, 0.9)) * BUSH_CELL
			local z = -half + (iz + Hash.range(ix, iz, 22, 0.1, 0.9)) * BUSH_CELL
			if math.abs(x) > edge or math.abs(z) > edge then
				continue
			end
			local cover = biomes.forest(x, z)
			-- Most bushes grow where the forest is thin (edges, clearings), few in open fields.
			local chance = 0.0015 + 0.06 * cover * (1.3 - cover)
			local riverDistance = waterEdge(x, z)
			if riverDistance < riverside.Width then
				chance = math.max(chance, 0.12 * density * (1 - riverDistance / riverside.Width))
			end
			if Hash.unit(ix, iz, 23) >= chance then
				continue
			end
			if riverDistance < river.bankWidth or not clearOfWorks(x, z, 8) then
				continue
			end
			local y, slope = ground(x, z)
			if y == nil or slope > MAX_BUSH_SLOPE or y > treeLine + 40 then
				continue
			end
			local seed = Hash.unit(ix, iz, 24)
			table.insert(bushes, {
				Kind = "Bush",
				X = x,
				Y = y,
				Z = z,
				Size = 5 + 7 * seed,
				Yaw = seed * 6151 % (2 * math.pi),
				Seed = seed,
				Slope = slope,
			})
		end
		if yieldEvery and iz % 8 == 0 then
			yieldEvery()
		end
	end

	-- Rocks: steep ground, mountains, dry land ----------------------------------------------------
	local function addRock(x: number, z: number, y: number, slope: number, size: number, seed: number)
		table.insert(rocks, {
			Kind = "Rock",
			X = x,
			Y = y,
			Z = z,
			Size = size,
			Yaw = seed * 4231 % (2 * math.pi),
			Seed = seed,
			Slope = slope,
		})
	end
	cells = math.floor(2 * half / ROCK_CELL)
	for iz = 0, cells - 1 do
		for ix = 0, cells - 1 do
			local x = -half + (ix + Hash.range(ix, iz, 31, 0.1, 0.9)) * ROCK_CELL
			local z = -half + (iz + Hash.range(ix, iz, 32, 0.1, 0.9)) * ROCK_CELL
			if math.abs(x) > edge or math.abs(z) > edge then
				continue
			end
			local roll = Hash.unit(ix, iz, 33)
			if roll > 0.3 then
				continue -- cheap early exit: at most 30 % of cells are looked at
			end
			if not clearOfWorks(x, z, 4) or waterEdge(x, z) < 2 then
				continue
			end
			local y, slope = ground(x, z, true)
			if y == nil then
				continue
			end
			local chance = 0.002 + 0.02 * biomes.dryness(x, z)
			if slope > 0.55 then
				chance += math.min(0.07, (slope - 0.55) * 0.14)
			end
			if y > 520 then
				chance += 0.008
			end
			if roll >= chance then
				continue
			end
			local seed = Hash.unit(ix, iz, 34)
			local size = 3 + seed * seed * (if y > 520 or slope > 0.7 then 16 else 8)
			addRock(x, z, y, slope, size, seed)
		end
		if yieldEvery and iz % 8 == 0 then
			yieldEvery()
		end
	end

	-- Boulders at the river's cascades, on both sides of the channel.
	local line = river.line
	for n, i in river.steps do
		local a, b = math.max(1, i - 1), math.min(#line.xs, i + 1)
		local dx, dz = line.xs[b] - line.xs[a], line.zs[b] - line.zs[a]
		local len = math.sqrt(dx * dx + dz * dz)
		local rx, rz = -dz / len, dx / len
		local halfWidth = river.halfWidths[i]
		for k = 1, 3 do
			local seed = Hash.unit(n, k, 35)
			local side = if k % 2 == 0 then 1 else -1
			local across = halfWidth * (0.55 + 0.5 * seed) * side
			local x = line.xs[i] + rx * across + dx / len * (seed - 0.5) * 6
			local z = line.zs[i] + rz * across + dz / len * (seed - 0.5) * 6
			local e = roads.nearest(x, z)
			if e and e < 6 then
				continue
			end
			local y, slope = ground(x, z, true)
			if y then
				addRock(x, z, y, slope, 4 + 5 * seed, seed)
			end
		end
	end

	return {
		trees = trees,
		bushes = bushes,
		rocks = rocks,
	}
end

return Vegetation
