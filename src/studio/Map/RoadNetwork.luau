--!strict
--!native
-- Roads as the builders need them: smooth centre lines (curves no tighter than the class allows),
-- height profiles no steeper than the class allows, flat where they enter places, joined at the
-- same height where one road meets another, and raised over the river where a bridge is needed.
-- Pure Luau, tested offline.

local Geometry = require(script.Parent.Geometry)
local SegmentGrid = require(script.Parent.SegmentGrid)

export type RoadInfo = {
	Id: string,
	Name: string,
	Class: string,
	Width: number,
	MaxGrade: number,
	MinRadius: number, -- smallest curve radius actually used
	line: Geometry.Polyline,
	profile: { number }, -- road surface height at every sample of `line`
	onBridge: { boolean }, -- true where the sample lies on a bridge deck
	lowerBound: { number }, -- the lowest the profile may be (bridge clearance, pins); for tests
	upperBound: { number },
	feasible: boolean, -- false when the pins and bridges cannot all be met within the grade
}

export type Bridge = {
	Road: string,
	RoadIndex: number,
	First: number, -- first and last sample index of the deck
	Last: number,
	CrossX: number,
	CrossZ: number,
	WaterY: number,
	MinDeckY: number,
	Angle: number, -- angle between road and river in degrees (90 = square crossing)
}

export type RoadNetwork = {
	roads: { RoadInfo },
	bridges: { Bridge },
	-- Nearest road edge: distance outside the road surface (negative = on it), surface height,
	-- road index and whether that spot is on a bridge. Nil when no road is near.
	nearest: (x: number, z: number) -> (number?, number, number, boolean),
	reach: number,
}

type Crossing = { s: number, x: number, z: number, water: number, sinA: number, cosA: number }

local SPACING = 8
local REACH = 200 -- how far beyond its edge a road can reshape the land
local TARGET_SMOOTHING = 15 -- samples on each side (about 120 studs)
local GRADE_SAFETY = 0.97

local RoadNetwork = {}

local function movingAverage(values: { number }, radius: number): { number }
	local count = #values
	local prefix: { number } = table.create(count + 1)
	prefix[1] = 0
	for i = 1, count do
		prefix[i + 1] = prefix[i] + values[i]
	end
	local out: { number } = table.create(count)
	for i = 1, count do
		local a, b = math.max(1, i - radius), math.min(count, i + radius)
		out[i] = (prefix[b + 1] - prefix[a]) / (b - a + 1)
	end
	return out
end

-- Forces |p[i+1] - p[i]| <= grade * distance in both directions.
local function limitGrade(p: { number }, s: { number }, grade: number)
	for i = 2, #p do
		local step = grade * (s[i] - s[i - 1])
		p[i] = math.clamp(p[i], p[i - 1] - step, p[i - 1] + step)
	end
	for i = #p - 1, 1, -1 do
		local step = grade * (s[i + 1] - s[i])
		p[i] = math.clamp(p[i], p[i + 1] - step, p[i + 1] + step)
	end
end

function RoadNetwork.new(layout: any, land: any, river: any): RoadNetwork
	local classes = layout.RoadClasses
	local places = layout.Places
	local roads: { RoadInfo } = {}
	local bridges: { Bridge } = {}
	local grid = SegmentGrid.new(64)
	local segAx: { number }, segAz: { number }, segBx: { number }, segBz: { number } = {}, {}, {}, {}
	local segRoad: { number }, segIndex: { number } = {}, {}
	local halfWidths: { number } = {}

	local function nearest(x: number, z: number): (number?, number, number, boolean)
		local ids = SegmentGrid.query(grid, x, z)
		if not ids then
			return nil, 0, 0, false
		end
		local bestE, bestY, bestRoad, bestBridge = math.huge, 0, 0, false
		for _, id in ids do
			local d, t = Geometry.segmentDistance(segAx[id], segAz[id], segBx[id], segBz[id], x, z)
			local r = segRoad[id]
			local e = d - halfWidths[r]
			if e < bestE then
				local road = roads[r]
				local i = segIndex[id]
				bestE = e
				bestY = road.profile[i] + (road.profile[i + 1] - road.profile[i]) * t
				bestRoad = r
				bestBridge = road.onBridge[i] and road.onBridge[i + 1]
			end
		end
		if bestE > REACH then
			return nil, 0, 0, false
		end
		return bestE, bestY, bestRoad, bestBridge
	end

	-- The flat place that contains a point (the last one in the list wins, as in Land).
	local function placeGroundAt(x: number, z: number): number?
		local ground: number? = nil
		for _, place in places do
			local r = place.Rect
			if x >= r.MinX - 0.01 and x <= r.MaxX + 0.01 and z >= r.MinZ - 0.01 and z <= r.MaxZ + 0.01 then
				ground = land.placeGround[place.Id]
			end
		end
		return ground
	end

	for roadIndex, road in layout.Roads do
		local class = classes[road.Class]
		local halfWidth = class.Width / 2
		local grade = class.MaxGrade * GRADE_SAFETY
		local fx, fz, minRadius = Geometry.fillet(road.Points, class.MinRadius * 1.02, 4)
		local line = Geometry.resample(fx, fz, SPACING)
		local xs, zs, s = line.xs, line.zs, line.s
		local count = #xs

		-- Pins (fixed heights) and lower bounds.
		local pin: { number? } = table.create(count)
		local lower: { number } = table.create(count, -math.huge)
		for i = 1, count do
			pin[i] = placeGroundAt(xs[i], zs[i])
		end
		for i = 1, count do
			local e, y = nearest(xs[i], zs[i])
			if e and e <= 1 then
				pin[i] = y -- joins an earlier road: level with it where the surfaces overlap
			end
		end

		-- Bridges: where the road crosses the river.
		local onBridge: { boolean } = table.create(count, false)
		local crossings: { Crossing } = {}
		for i = 1, count - 1 do
			local mx, mz = (xs[i] + xs[i + 1]) / 2, (zs[i] + zs[i + 1]) / 2
			local ids = SegmentGrid.query(river.grid, mx, mz)
			if ids then
				for _, k in ids do
					local t, u = Geometry.segmentIntersection(
						xs[i],
						zs[i],
						xs[i + 1],
						zs[i + 1],
						river.line.xs[k],
						river.line.zs[k],
						river.line.xs[k + 1],
						river.line.zs[k + 1]
					)
					if t and u then
						local crossS = s[i] + (s[i + 1] - s[i]) * t
						local duplicate = false
						for _, c in crossings do
							if math.abs(c.s - crossS) < 50 then
								duplicate = true
							end
						end
						if not duplicate then
							local rdx, rdz = xs[i + 1] - xs[i], zs[i + 1] - zs[i]
							local vdx, vdz =
								river.line.xs[k + 1] - river.line.xs[k], river.line.zs[k + 1] - river.line.zs[k]
							local cosA = math.abs(rdx * vdx + rdz * vdz)
								/ (math.sqrt(rdx * rdx + rdz * rdz) * math.sqrt(vdx * vdx + vdz * vdz))
							local sinA = math.sqrt(math.max(1e-6, 1 - cosA * cosA))
							local water = river.water[k] + (river.water[k + 1] - river.water[k]) * u
							table.insert(crossings, {
								s = crossS,
								x = xs[i] + rdx * t,
								z = zs[i] + rdz * t,
								water = water,
								sinA = sinA,
								cosA = cosA,
							})
						end
					end
				end
			end
		end
		for _, c in crossings do
			local minDeck = c.water + river.clearance
			local wall = math.max(0, river.clearance - river.drop) / river.wallSlope
			local halfSpan = (river.halfWidth + river.bankWidth + wall + 6) / c.sinA + halfWidth * c.cosA / c.sinA
			local first, last = count, 1
			for i = 1, count do
				if math.abs(s[i] - c.s) <= halfSpan then
					lower[i] = math.max(lower[i], minDeck)
					onBridge[i] = true
					first = math.min(first, i)
					last = math.max(last, i)
				end
			end
			table.insert(bridges, {
				Road = road.Id,
				RoadIndex = roadIndex,
				First = first,
				Last = last,
				CrossX = c.x,
				CrossZ = c.z,
				WaterY = c.water,
				MinDeckY = minDeck,
				Angle = math.deg(math.asin(c.sinA)),
			})
		end

		-- Envelopes: the highest and lowest the profile may be while meeting every pin and bound.
		local upper: { number } = table.create(count, math.huge)
		local low: { number } = table.create(count, -math.huge)
		for i = 1, count do
			local p = pin[i]
			if p then
				upper[i] = p
				low[i] = p
			end
			low[i] = math.max(low[i], lower[i])
		end
		for i = 2, count do
			local step = grade * (s[i] - s[i - 1])
			upper[i] = math.min(upper[i], upper[i - 1] + step)
			low[i] = math.max(low[i], low[i - 1] - step)
		end
		for i = count - 1, 1, -1 do
			local step = grade * (s[i + 1] - s[i])
			upper[i] = math.min(upper[i], upper[i + 1] + step)
			low[i] = math.max(low[i], low[i + 1] - step)
		end
		local feasible = true
		for i = 1, count do
			if low[i] > upper[i] + 1e-6 then
				feasible = false
				upper[i] = low[i]
			end
		end

		-- Profile: the smoothed land, kept inside the envelopes and within the grade.
		local target: { number } = table.create(count)
		for i = 1, count do
			target[i] = land.height(xs[i], zs[i])
		end
		local profile = movingAverage(target, TARGET_SMOOTHING)
		for i = 1, count do
			profile[i] = math.clamp(profile[i], low[i], upper[i])
		end
		limitGrade(profile, s, grade)
		profile = movingAverage(profile, 3)
		for i = 1, count do
			profile[i] = math.clamp(profile[i], low[i], upper[i])
		end
		limitGrade(profile, s, grade)

		local info: RoadInfo = {
			Id = road.Id,
			Name = road.Name,
			Class = road.Class,
			Width = class.Width,
			MaxGrade = class.MaxGrade,
			MinRadius = minRadius,
			line = line,
			profile = profile,
			onBridge = onBridge,
			lowerBound = low,
			upperBound = upper,
			feasible = feasible,
		}
		table.insert(roads, info)
		halfWidths[roadIndex] = halfWidth
		for i = 1, count - 1 do
			local id = #segAx + 1
			segAx[id], segAz[id], segBx[id], segBz[id] = xs[i], zs[i], xs[i + 1], zs[i + 1]
			segRoad[id], segIndex[id] = roadIndex, i
			SegmentGrid.insert(grid, id, xs[i], zs[i], xs[i + 1], zs[i + 1], halfWidth + REACH)
		end
	end

	return {
		roads = roads,
		bridges = bridges,
		nearest = nearest,
		reach = REACH,
	}
end

return RoadNetwork
