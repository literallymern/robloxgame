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
	From: string, -- sign destination towards the first point
	To: string, -- sign destination towards the last point
	Width: number,
	MaxGrade: number,
	MinRadius: number, -- smallest curve radius actually used
	line: Geometry.Polyline,
	profile: { number }, -- road surface height at every sample of `line`
	onBridge: { boolean }, -- true where the sample lies on a bridge deck
	lowerBound: { number }, -- the lowest the profile may be (bridge clearance, pins); for tests
	upperBound: { number },
	feasible: boolean, -- false when the pins and bridges cannot all be met within the grade
	-- Straight pieces of the road surface (sample ranges), split where bridges start and end.
	-- Every builder uses these, so markings sit exactly on the road parts.
	runs: { Run },
}

export type Run = { First: number, Last: number, Bridge: boolean }

-- Where the end of one road meets another road (outside places).
export type Junction = {
	Minor: number, -- index of the road that ends here
	MinorSample: number, -- its end sample (1 or the last)
	AtStart: boolean, -- the minor road starts here (false: it ends here)
	Major: number, -- index of the road it joins
	MajorSample: number, -- nearest sample of the major road
	X: number,
	Z: number,
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
	junctions: { Junction },
	-- Nearest road edge: distance outside the road surface (negative = on it), surface height,
	-- road index and whether that spot is on a bridge. Nil when no road is near.
	nearest: (x: number, z: number) -> (number?, number, number, boolean),
	-- Like nearest, but ignores road `exclude`: distance outside the nearest other road surface
	-- (math.huge when no other road is near).
	otherDistance: (x: number, z: number, exclude: number) -> number,
	reach: number,
}

type Crossing = { s: number, x: number, z: number, water: number, sinA: number, cosA: number, riverHalf: number }

local SPACING = 8
local REACH = 200 -- how far beyond its edge a road can reshape the land
local TARGET_SMOOTHING = 15 -- samples on each side (about 120 studs)
local GRADE_SAFETY = 0.97
local MAX_PIECE = 400 -- longest straight road piece in studs
local STRAIGHT_TOLERANCE = 0.12 -- how far a sample may sit off a straight piece

local RoadNetwork = {}

-- Splits samples first..last of a road into runs that are straight in 3D (within the tolerance).
function RoadNetwork.straightRuns(
	xs: { number },
	zs: { number },
	ys: { number },
	first: number,
	last: number
): { { number } }
	local runs = {}
	local i = first
	while i < last do
		local j = i + 1
		while j < last do
			local ax, ay, az = xs[i], ys[i], zs[i]
			local dx, dy, dz = xs[j + 1] - ax, ys[j + 1] - ay, zs[j + 1] - az
			local length = math.sqrt(dx * dx + dy * dy + dz * dz)
			if length > MAX_PIECE then
				break
			end
			dx, dy, dz = dx / length, dy / length, dz / length
			local straight = true
			for k = i + 1, j do
				local px, py, pz = xs[k] - ax, ys[k] - ay, zs[k] - az
				local along = px * dx + py * dy + pz * dz
				local ox, oy, oz = px - dx * along, py - dy * along, pz - dz * along
				if ox * ox + oy * oy + oz * oz > STRAIGHT_TOLERANCE * STRAIGHT_TOLERANCE then
					straight = false
					break
				end
			end
			if not straight then
				break
			end
			j += 1
		end
		table.insert(runs, { i, j })
		i = j
	end
	return runs
end

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

	local function otherDistance(x: number, z: number, exclude: number): number
		local ids = SegmentGrid.query(grid, x, z)
		local best = math.huge
		if ids then
			for _, id in ids do
				local r = segRoad[id]
				if r ~= exclude then
					local d = Geometry.segmentDistance(segAx[id], segAz[id], segBx[id], segBz[id], x, z)
					best = math.min(best, d - halfWidths[r])
				end
			end
		end
		return best
	end

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
							-- The upper of the two pools, in case a cascade is right at the crossing.
							local water = math.max(river.water[k], river.water[k + 1])
							local riverHalf = river.halfWidths[k] + (river.halfWidths[k + 1] - river.halfWidths[k]) * u
							table.insert(crossings, {
								s = crossS,
								x = xs[i] + rdx * t,
								z = zs[i] + rdz * t,
								water = water,
								sinA = sinA,
								cosA = cosA,
								riverHalf = riverHalf,
							})
						end
					end
				end
			end
		end
		for _, c in crossings do
			local minDeck = c.water + river.clearance
			local wall = math.max(0, river.clearance - river.drop) / river.wallSlope
			local halfSpan = (c.riverHalf + river.bankWidth + wall + 6) / c.sinA + halfWidth * c.cosA / c.sinA
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

		-- Straight runs of the surface, split where a bridge starts or ends.
		local runs: { Run } = {}
		local first = 1
		while first < count do
			local bridge = onBridge[first] and onBridge[first + 1]
			local last = first
			while last < count and (onBridge[last] and onBridge[last + 1]) == bridge do
				last += 1
			end
			for _, run in RoadNetwork.straightRuns(xs, zs, profile, first, last) do
				table.insert(runs, { First = run[1], Last = run[2], Bridge = bridge })
			end
			first = last
		end

		local info: RoadInfo = {
			Id = road.Id,
			Name = road.Name,
			Class = road.Class,
			From = road.From,
			To = road.To,
			Width = class.Width,
			MaxGrade = class.MaxGrade,
			MinRadius = minRadius,
			line = line,
			profile = profile,
			onBridge = onBridge,
			lowerBound = low,
			upperBound = upper,
			feasible = feasible,
			runs = runs,
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

	-- Junctions: road ends that lie on another road rather than in a place.
	local junctions: { Junction } = {}
	for minorIndex, road in roads do
		local count = #road.line.xs
		for _, atStart in { true, false } do
			local sample = if atStart then 1 else count
			local x, z = road.line.xs[sample], road.line.zs[sample]
			if placeGroundAt(x, z) ~= nil then
				continue
			end
			local bestRoad, bestSample, bestD = 0, 0, math.huge
			for majorIndex, major in roads do
				if majorIndex ~= minorIndex then
					local mx, mz = major.line.xs, major.line.zs
					for k = 1, #mx - 1 do
						local d, t = Geometry.segmentDistance(mx[k], mz[k], mx[k + 1], mz[k + 1], x, z)
						if d <= major.Width / 2 + 1 and d < bestD then
							bestRoad, bestD = majorIndex, d
							bestSample = if t < 0.5 then k else k + 1
						end
					end
				end
			end
			if bestRoad > 0 then
				table.insert(junctions, {
					Minor = minorIndex,
					MinorSample = sample,
					AtStart = atStart,
					Major = bestRoad,
					MajorSample = bestSample,
					X = x,
					Z = z,
				})
			end
		end
	end

	return {
		roads = roads,
		bridges = bridges,
		junctions = junctions,
		nearest = nearest,
		otherDistance = otherDistance,
		reach = REACH,
	}
end

return RoadNetwork
