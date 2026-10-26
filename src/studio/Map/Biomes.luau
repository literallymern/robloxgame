--!strict
--!native
-- Where the countryside is wooded, which trees grow there and how dry the ground is.
-- Regions come from MapLayout.Vegetation; their edges are made ragged with noise, and a grove
-- pattern splits forests into stands and clearings. Used by the terrain materials (forest floor,
-- bare earth) and by the tree placement. Pure Luau, tested offline.

local Geometry = require(script.Parent.Geometry)

export type Region = {
	Id: string,
	Rect: Geometry.Rect?,
	Margin: number,
	Forest: number,
	Dry: number,
	Kinds: { string }, -- tree kinds, with cumulative shares in Weights (last = 1)
	Weights: { number },
}

export type Biomes = {
	regions: { Region }, -- the layout's regions in order, then Default and Mountains
	-- Region index at a point and how strongly it applies (1 inside, falling to 0 at the margin).
	regionAt: (x: number, z: number) -> (number, number),
	-- Share of the ground under trees (0..1), including the grove pattern.
	forest: (x: number, z: number) -> number,
	-- How dry the ground is (0..1): more bare red earth.
	dryness: (x: number, z: number) -> number,
	-- Picks a tree kind for region `index` from a random number in [0, 1).
	pickKind: (index: number, roll: number) -> string,
	defaultIndex: number,
	mountainIndex: number,
}

local Biomes = {}

local function resolve(id: string, config: any, rect: Geometry.Rect?, margin: number): Region
	local kinds: { string } = {}
	for kind in config.Mix do
		table.insert(kinds, kind)
	end
	table.sort(kinds) -- table order is not fixed; sorting keeps every build the same
	local total = 0
	for _, kind in kinds do
		total += config.Mix[kind]
	end
	local weights: { number } = {}
	local sum = 0
	for i, kind in kinds do
		sum += config.Mix[kind] / total
		weights[i] = sum
	end
	weights[#weights] = 1
	return {
		Id = id,
		Rect = rect,
		Margin = margin,
		Forest = config.Forest,
		Dry = config.Dry or 0.2,
		Kinds = kinds,
		Weights = weights,
	}
end

function Biomes.new(layout: any): Biomes
	local config = layout.Vegetation
	local density: number = config.Density or 1
	local regions: { Region } = {}
	for _, region in config.Regions do
		table.insert(regions, resolve(region.Id, region, region.Rect, region.Margin))
	end
	local regionCount = #regions
	table.insert(regions, resolve("Default", config.Default, nil, 0))
	local defaultIndex = #regions
	table.insert(regions, resolve("Mountains", config.Mountains, nil, 0))
	local mountainIndex = #regions

	local mountainStart: number = layout.Bounds.Playable - layout.Mountains.StartInside

	local function regionAt(x: number, z: number): (number, number)
		-- Ragged edges: look the region up at a position shifted by noise.
		local wx = x + 140 * math.noise(x / 520 + 0.37, z / 520 + 0.11, 41.3)
		local wz = z + 140 * math.noise(x / 520 + 2.71, z / 520 + 0.93, 42.7)
		local edge = math.max(math.abs(x), math.abs(z)) - mountainStart
		if edge > 0 then
			return mountainIndex, Geometry.smoothstep(edge / 300)
		end
		for i = 1, regionCount do
			local region = regions[i]
			local rect = region.Rect :: Geometry.Rect
			local d = Geometry.rectDistance(rect, wx, wz)
			if d < region.Margin then
				return i, 1 - Geometry.smoothstep(d / region.Margin)
			end
		end
		return defaultIndex, 1
	end

	local defaultForest = regions[defaultIndex].Forest
	local defaultDry = regions[defaultIndex].Dry

	local function forest(x: number, z: number): number
		local index, weight = regionAt(x, z)
		local base = defaultForest + (regions[index].Forest - defaultForest) * weight
		-- Groves: dense forests keep most of their cover, open land gets scattered stands.
		local grove = math.noise(x / 430 + 0.19, z / 430 + 0.83, 31.3)
			+ 0.45 * math.noise(x / 150 + 0.61, z / 150 + 0.07, 32.9)
		local cover = if base > 0.5 then 0.8 + 0.9 * grove else 0.45 + 1.4 * grove
		return Geometry.clamp01(base * Geometry.clamp01(cover) * density)
	end

	local function dryness(x: number, z: number): number
		local index, weight = regionAt(x, z)
		return defaultDry + (regions[index].Dry - defaultDry) * weight
	end

	local function pickKind(index: number, roll: number): string
		local region = regions[index]
		for i, w in region.Weights do
			if roll < w then
				return region.Kinds[i]
			end
		end
		return region.Kinds[#region.Kinds]
	end

	return {
		regions = regions,
		regionAt = regionAt,
		forest = forest,
		dryness = dryness,
		pickKind = pickKind,
		defaultIndex = defaultIndex,
		mountainIndex = mountainIndex,
	}
end

return Biomes
