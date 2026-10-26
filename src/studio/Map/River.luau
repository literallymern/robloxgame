--!strict
--!native
-- The river: its course, a water level that only ever falls downstream, and the channel
-- it carves into the land (bed, banks and, where it cuts through higher ground, valley walls).
-- Pure Luau, tested offline.

local Geometry = require(script.Parent.Geometry)
local SegmentGrid = require(script.Parent.SegmentGrid)

export type River = {
	line: Geometry.Polyline,
	water: { number }, -- water surface height at every sample of `line`
	halfWidth: number,
	bankWidth: number,
	drop: number,
	wallSlope: number,
	clearance: number,
	reach: number, -- how far from the centre line the river can change the land
	-- Nearest point of the river: distance from the centre line, water level there, sample index.
	nearest: (x: number, z: number) -> (number, number, number),
	-- Carves the channel into land height h. Returns the new height, the water surface (nil where
	-- there is no water) and the zone: 0 untouched, 1 under water, 2 bank, 3 valley wall.
	carve: (x: number, z: number, h: number) -> (number, number?, number),
	grid: SegmentGrid.SegmentGrid,
}

local SPACING = 8
local BEND_RADIUS = 220
local REACH = 260

local River = {}

function River.new(layout: any, landHeight: (number, number) -> number): River
	local config = layout.River
	local xs, zs = Geometry.fillet(config.Points, BEND_RADIUS, SPACING)
	local line = Geometry.resample(xs, zs, SPACING)
	local count = #line.xs
	local halfWidth: number = config.Width / 2
	local bankWidth: number = config.BankWidth
	local depth: number = config.Depth
	local drop: number = config.DropBelowLand
	local wallSlope: number = config.WallSlope

	-- Land height along the river, smoothed over about 100 studs.
	local alongLand: { number } = table.create(count)
	for i = 1, count do
		alongLand[i] = landHeight(line.xs[i], line.zs[i])
	end
	local window = 6
	local water: { number } = table.create(count)
	local level = math.huge
	for i = 1, count do
		local sum, n = 0, 0
		for j = math.max(1, i - window), math.min(count, i + window) do
			sum += alongLand[j]
			n += 1
		end
		level = math.min(level, sum / n - drop)
		water[i] = level
	end

	local grid = SegmentGrid.new(64)
	for i = 1, count - 1 do
		SegmentGrid.insert(grid, i, line.xs[i], line.zs[i], line.xs[i + 1], line.zs[i + 1], REACH)
	end
	local lx, lz = line.xs, line.zs

	local function nearest(x: number, z: number): (number, number, number)
		local ids = SegmentGrid.query(grid, x, z)
		local best, bestWater, bestIndex = math.huge, 0, 0
		if ids then
			for _, i in ids do
				local d, t = Geometry.segmentDistance(lx[i], lz[i], lx[i + 1], lz[i + 1], x, z)
				if d < best then
					best = d
					bestWater = water[i] + (water[i + 1] - water[i]) * t
					bestIndex = if t < 0.5 then i else i + 1
				end
			end
		end
		return best, bestWater, bestIndex
	end

	local function carve(x: number, z: number, h: number): (number, number?, number)
		local d, w = nearest(x, z)
		if d >= REACH then
			return h, nil, 0
		end
		local surface, zone
		if d < halfWidth then
			local f = d / halfWidth
			surface = w - depth * (1 - f * f)
			zone = 1
		elseif d < halfWidth + bankWidth then
			surface = w + drop * (d - halfWidth) / bankWidth
			zone = 2
		else
			surface = w + drop + (d - halfWidth - bankWidth) * wallSlope
			zone = 3
		end
		if surface >= h then
			-- Only the water itself is added where the land is already low enough.
			return h, if zone == 1 and h < w then w else nil, 0
		end
		return surface, if zone == 1 then w else nil, zone
	end

	return {
		line = line,
		water = water,
		halfWidth = halfWidth,
		bankWidth = bankWidth,
		drop = drop,
		wallSlope = wallSlope,
		clearance = config.RoadClearance,
		reach = REACH,
		nearest = nearest,
		carve = carve,
		grid = grid,
	}
end

return River
