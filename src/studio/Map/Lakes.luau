--!strict
--!native
-- Lakes: an irregular ellipse of water with a sandy or muddy shore, carved into the land with
-- gentle slopes. Each lake's water level is set just below the lowest land around its shore,
-- so the water never stands above the surrounding ground. Pure Luau, tested offline.

local Geometry = require(script.Parent.Geometry)

export type Lake = {
	Id: string,
	X: number,
	Z: number,
	Rx: number,
	Rz: number,
	Cos: number,
	Sin: number,
	Depth: number,
	WaterY: number,
	Seed: number,
	Reach: number, -- largest distance from the centre at which the land changes
}

export type Lakes = {
	list: { Lake },
	-- Carves lakes into land height h: new height, water surface or nil, zone (0 untouched,
	-- 1 under water, 2 shore, 3 slope) and the distance from the shore line (negative in water).
	carve: (x: number, z: number, h: number) -> (number, number?, number, number),
	-- Distance from the nearest shore line (negative inside the water), or a large number.
	shoreDistance: (x: number, z: number) -> number,
}

local SHORE = 14 -- studs of shore beyond the water line
local SHORE_RISE = 1.5 -- the shore rises this far above the water
local SLOPE = 0.45 -- steepness of the basin beyond the shore
local OUTER = 110 -- studs beyond the shore over which the basin slope can reach
local FREEBOARD = 1.5 -- water level below the lowest land around the shore

local Lakes = {}

-- Radius scale of the shore in direction (c, s) (unit vector in lake coordinates).
local function wobble(lake: Lake, c: number, s: number): number
	return 1
		+ 0.16 * math.noise(c * 1.4 + lake.Seed, s * 1.4 + 0.37, 5.5)
		+ 0.07 * math.noise(c * 3.1 + 0.71, s * 3.1 + lake.Seed, 6.5)
end

-- Distance from the shore line of a lake (negative inside), measured roughly in studs.
local function shoreDistance(lake: Lake, x: number, z: number): number
	local dx, dz = x - lake.X, z - lake.Z
	local u = dx * lake.Cos + dz * lake.Sin
	local v = -dx * lake.Sin + dz * lake.Cos
	local eu, ev = u / lake.Rx, v / lake.Rz
	local r = math.sqrt(eu * eu + ev * ev)
	if r < 1e-6 then
		return -math.min(lake.Rx, lake.Rz)
	end
	local scale = wobble(lake, eu / r, ev / r)
	-- Convert the normalised distance back to studs with the radius in that direction.
	local radius = math.sqrt((eu / r * lake.Rx) ^ 2 + (ev / r * lake.Rz) ^ 2) * scale
	return (r / scale - 1) * radius
end

function Lakes.new(layout: any, landHeight: (number, number) -> number): Lakes
	local list: { Lake } = {}
	for i, config in layout.Lakes or {} do
		local angle = math.rad(config.Angle or 0)
		local lake: Lake = {
			Id = config.Id,
			X = config.Centre[1],
			Z = config.Centre[2],
			Rx = config.Radius[1],
			Rz = config.Radius[2],
			Cos = math.cos(angle),
			Sin = math.sin(angle),
			Depth = config.Depth,
			WaterY = 0,
			Seed = 3.17 * i,
			Reach = 0,
		}
		-- Lowest land on rings around the shore decides the water level.
		local lowest = math.huge
		local maxRadius = 0
		for k = 0, 179 do
			local a = k * math.pi / 90
			local c, s = math.cos(a), math.sin(a)
			local scale = wobble(lake, c, s)
			for _, extra in { 0, SHORE / 2, SHORE, SHORE + 20, SHORE + 45 } do
				local u = (c * lake.Rx * scale) + c * extra
				local v = (s * lake.Rz * scale) + s * extra
				local x = lake.X + u * lake.Cos - v * lake.Sin
				local z = lake.Z + u * lake.Sin + v * lake.Cos
				lowest = math.min(lowest, landHeight(x, z))
			end
			maxRadius = math.max(maxRadius, math.max(lake.Rx, lake.Rz) * scale)
		end
		lake.WaterY = math.floor(lowest - FREEBOARD)
		lake.Reach = maxRadius + SHORE + OUTER + 10
		table.insert(list, lake)
	end

	local function nearestLake(x: number, z: number): (Lake?, number)
		local best: Lake? = nil
		local bestD = math.huge
		for _, lake in list do
			local dx, dz = x - lake.X, z - lake.Z
			if dx * dx + dz * dz < lake.Reach * lake.Reach then
				local d = shoreDistance(lake, x, z)
				if d < bestD then
					best, bestD = lake, d
				end
			end
		end
		return best, bestD
	end

	local function carve(x: number, z: number, h: number): (number, number?, number, number)
		local lake, d = nearestLake(x, z)
		if not lake then
			return h, nil, 0, math.huge
		end
		local w = lake.WaterY
		local surface, zone
		if d < 0 then
			-- Bed: deepest in the middle, rising to the water line.
			local radius = math.min(lake.Rx, lake.Rz)
			local f = Geometry.clamp01(1 + d / radius)
			surface = w - lake.Depth * (1 - f * f) - 0.6
			zone = 1
		elseif d < SHORE then
			surface = w + SHORE_RISE * d / SHORE
			zone = 2
		elseif d < SHORE + OUTER then
			surface = w + SHORE_RISE + (d - SHORE) * SLOPE
			zone = 3
		else
			return h, nil, 0, d
		end
		if surface >= h then
			return h, if zone == 1 and h < w then w else nil, if zone == 3 then 0 else zone, d
		end
		return surface, if zone == 1 then w else nil, zone, d
	end

	local function distance(x: number, z: number): number
		local _, d = nearestLake(x, z)
		return d
	end

	return {
		list = list,
		carve = carve,
		shoreDistance = distance,
	}
end

return Lakes
