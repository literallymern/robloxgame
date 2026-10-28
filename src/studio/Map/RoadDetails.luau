--!strict
--!native
-- Everything along the roads besides the surface: markings (centre and edge lines, stop lines),
-- marker posts, guard rails, street lights, signs and power lines. Positions only; the builders
-- turn them into parts. Markings follow the straight road pieces (RoadInfo.runs), so they sit
-- exactly on the road parts. Pure Luau, tested offline.

local Hash = require(script.Parent.Hash)
local RoadNetwork = require(script.Parent.RoadNetwork)

-- A marking strip: its top surface runs from A to B (already lifted above the road).
export type Strip = {
	AX: number,
	AY: number,
	AZ: number,
	BX: number,
	BY: number,
	BZ: number,
	Width: number,
	Kind: string, -- Centre, Edge, Stop
}

export type Post = { X: number, Y: number, Z: number, DirX: number, DirZ: number }

-- A guard rail: straight pieces (rail centre line) and its posts (ground to rail).
export type Rail = {
	Pieces: { { number } }, -- { ax, ay, az, bx, by, bz }
	Posts: { { number } }, -- { x, groundY, z, topY }
}

-- A street light: foot position and the direction of its arm (towards the road).
export type Light = { X: number, Y: number, Z: number, ArmX: number, ArmZ: number }

export type Board = { Text: string, Road: string?, Arrow: string? } -- Arrow: Left, Right or nil

export type Sign = {
	Kind: string, -- Town, Facility, Speed, Direction, Stop, Chevron, Welcome
	X: number,
	Y: number, -- ground height
	Z: number,
	FaceX: number, -- the readable side looks this way (towards the traffic it is meant for)
	FaceZ: number,
	Text: string?,
	Limit: number?,
	Boards: { Board }?,
	Turn: string?, -- Chevron: Right or Left, the way the road bends for traffic reading the front
}

export type Pole = { X: number, Y: number, Z: number, DirX: number, DirZ: number, Line: number, Index: number }

export type RoadDetails = {
	markings: { Strip },
	delineators: { Post },
	rails: { Rail },
	lights: { Light },
	signs: { Sign },
	poles: { Pole },
	wires: { { number } }, -- pairs of pole indices (into `poles`) joined by wires
	wireGround: (number, number) -> number?,
}

local LIFT = 0.05 -- markings stand this far above the road surface
local STEP = 4 -- studs between checks when walking along a road
local DASH, DASH_PERIOD = 12, 40
local DELINEATOR_SPACING = 50
local POLE_SPACING = 120
local MAX_WIRE = 260
local LIGHT_SPACING = 45

local RoadDetails = {}

function RoadDetails.new(
	layout: any,
	hf: any,
	groundSampler: ((number, number, boolean?) -> (number?, number))?
): RoadDetails
	local roads = hf.roads
	local surface = hf.surface
	local river = hf.river
	local lakes = hf.lakes
	local classes = layout.RoadClasses
	local markings: { Strip } = {}
	local delineators: { Post } = {}
	local rails: { Rail } = {}
	local lights: { Light } = {}
	local signs: { Sign } = {}
	local poles: { Pole } = {}
	local wires: { { number } } = {}

	local places = layout.Places
	local function placeAt(x: number, z: number, margin: number): any?
		for _, place in places do
			local r = place.Rect
			if x >= r.MinX - margin and x <= r.MaxX + margin and z >= r.MinZ - margin and z <= r.MaxZ + margin then
				return place
			end
		end
		return nil
	end
	local function waterEdge(x: number, z: number): number
		local d, _, _, halfWidth = river.nearest(x, z)
		return math.min(d - halfWidth, lakes.shoreDistance(x, z))
	end
	local function groundY(x: number, z: number): number
		return (surface(x, z))
	end
	-- Keep authored signs and markings anchored to their original layout. Furniture feet
	-- follow the saved terrain during an upgrade; unknown/protected ground is never guessed.
	local function supportY(x: number, z: number): number?
		local y = if groundSampler then groundSampler(x, z, false) else groundY(x, z)
		return if y and y == y and math.abs(y) < math.huge then y else nil
	end

	-- Per road: sample positions along the line ---------------------------------------------
	type Frame = { x: number, y: number, z: number, dx: number, dz: number, i: number }

	-- Centre point, height and horizontal direction at distance s along road r.
	local function frameAt(road: any, s: number): Frame
		local line = road.line
		local lo, hi = 1, #line.s
		while hi - lo > 1 do
			local mid = (lo + hi) // 2
			if line.s[mid] <= s then
				lo = mid
			else
				hi = mid
			end
		end
		local span = line.s[hi] - line.s[lo]
		local t = if span > 0 then math.clamp((s - line.s[lo]) / span, 0, 1) else 0
		local dx, dz = line.xs[hi] - line.xs[lo], line.zs[hi] - line.zs[lo]
		local len = math.sqrt(dx * dx + dz * dz)
		return {
			x = line.xs[lo] + dx * t,
			y = road.profile[lo] + (road.profile[hi] - road.profile[lo]) * t,
			z = line.zs[lo] + dz * t,
			dx = dx / len,
			dz = dz / len,
			i = if t < 0.5 then lo else hi,
		}
	end

	-- Local curve radius at every sample (heading change over about 32 studs).
	local function radii(road: any): { number }
		local line = road.line
		local n = #line.xs
		local out: { number } = table.create(n, math.huge)
		for i = 3, n - 2 do
			local ax, az = line.xs[i] - line.xs[i - 2], line.zs[i] - line.zs[i - 2]
			local bx, bz = line.xs[i + 2] - line.xs[i], line.zs[i + 2] - line.zs[i]
			local cross = ax * bz - az * bx
			local dot = ax * bx + az * bz
			local angle = math.abs(math.atan2(cross, dot))
			if angle > 1e-6 then
				out[i] = (line.s[i + 2] - line.s[i - 2]) / angle
			end
		end
		return out
	end

	-- Distance along each road to the nearest junction on it (as minor end or major point).
	local junctionS: { { number } } = {}
	for r in roads.roads do
		junctionS[r] = {}
	end
	for _, j in roads.junctions do
		table.insert(junctionS[j.Minor], roads.roads[j.Minor].line.s[j.MinorSample])
		table.insert(junctionS[j.Major], roads.roads[j.Major].line.s[j.MajorSample])
	end
	local function nearJunction(r: number, s: number, distance: number): boolean
		for _, js in junctionS[r] do
			if math.abs(js - s) < distance then
				return true
			end
		end
		return false
	end
	local stops: { [number]: { S: number, Inward: number } } = {}
	for _, j in roads.junctions do
		local minor = roads.roads[j.Minor]
		local s = if j.AtStart then 0 else minor.line.length
		local inward = if j.AtStart then 1 else -1
		for _ = 1, 40 do
			local f = frameAt(minor, s)
			if roads.otherDistance(f.x, f.z, j.Minor) >= 2.5 then
				break
			end
			s += inward * 2
		end
		-- Roads can meet another road at either end; keep both approach limits.
		stops[j.Minor * 2 + (if j.AtStart then 0 else 1)] = { S = s, Inward = inward }
	end
	local function beforeStop(r: number, s: number): boolean
		for _, endIndex in { 0, 1 } do
			local stop = stops[r * 2 + endIndex]
			if stop and (s - stop.S) * stop.Inward < 2 then
				return false
			end
		end
		return true
	end

	-- Walks every straight run of road r and emits marking strips at lateral offset `offset`
	-- where include(s, x, z) holds, split wherever it changes.
	local function strips(
		r: number,
		offset: number,
		width: number,
		kind: string,
		include: (number, number, number) -> boolean
	)
		local road = roads.roads[r]
		local line = road.line
		for _, run in road.runs do
			local f, l = run.First, run.Last
			local s0, s1 = line.s[f], line.s[l]
			local ax, ay, az = line.xs[f], road.profile[f], line.zs[f]
			local bx, by, bz = line.xs[l], road.profile[l], line.zs[l]
			local hx, hz = bx - ax, bz - az
			local hl = math.sqrt(hx * hx + hz * hz)
			if hl < 0.5 then
				continue
			end
			local rx, rz = -hz / hl, hx / hl
			local function at(s: number): (number, number, number)
				local t = (s - s0) / (s1 - s0)
				return ax + (bx - ax) * t + rx * offset, ay + (by - ay) * t + LIFT, az + (bz - az) * t + rz * offset
			end
			local startS: number? = nil
			local s = s0
			while true do
				local sEnd = math.min(s + STEP, s1)
				local mid = (s + sEnd) / 2
				local mx, _, mz = at(mid)
				local on = include(mid, mx, mz)
				if on and not startS then
					startS = s
				elseif not on and startS then
					local x1, y1, z1 = at(startS)
					local x2, y2, z2 = at(s)
					table.insert(
						markings,
						{ AX = x1, AY = y1, AZ = z1, BX = x2, BY = y2, BZ = z2, Width = width, Kind = kind }
					)
					startS = nil
				end
				if sEnd >= s1 then
					if startS then
						local x1, y1, z1 = at(startS)
						local x2, y2, z2 = at(s1)
						table.insert(
							markings,
							{ AX = x1, AY = y1, AZ = z1, BX = x2, BY = y2, BZ = z2, Width = width, Kind = kind }
						)
					end
					break
				end
				s = sEnd
			end
		end
	end

	for r, road in roads.roads do
		local class = classes[road.Class]
		local halfWidth = road.Width / 2
		local length = road.line.length
		local radius = radii(road)

		if class.EdgeLines then
			for side = -1, 1, 2 do
				strips(r, side * (halfWidth - 1.2), 0.38, "Edge", function(s, x, z)
					return beforeStop(r, s) and roads.otherDistance(x, z, r) > 3.5 and placeAt(x, z, 0) == nil
				end)
			end
		end

		if class.CentreLine then
			strips(r, 0, 0.42, "Centre", function(s, x, z)
				if not beforeStop(r, s) or roads.otherDistance(x, z, r) < 1 or placeAt(x, z, 0) ~= nil then
					return false
				end
				local f = frameAt(road, s)
				-- No overtaking (solid line) on bridges, in tight curves, near junctions and ends.
				local solid = road.onBridge[f.i]
					or radius[f.i] < 300
					or nearJunction(r, s, 60)
					or s < 50
					or s > length - 50
				return solid or s % DASH_PERIOD < DASH
			end)
		end
	end

	-- Stop lines, stop signs and direction signs at junctions ----------------------------------
	for _, j in roads.junctions do
		local minor = roads.roads[j.Minor]
		local major = roads.roads[j.Major]
		-- Walk from the junction into the minor road until it leaves the major road's surface.
		local sStop = stops[j.Minor * 2 + (if j.AtStart then 0 else 1)].S
		local inward = if j.AtStart then 1 else -1
		-- Arriving traffic drives towards the junction.
		local f = frameAt(minor, sStop)
		local hx, hz = f.dx * -inward, f.dz * -inward
		local rx, rz = -hz, hx
		local halfWidth = minor.Width / 2
		local a1, a2 = 0.4, halfWidth - 1
		table.insert(markings, {
			AX = f.x + rx * a1,
			AY = f.y + LIFT + 0.01,
			AZ = f.z + rz * a1,
			BX = f.x + rx * a2,
			BY = f.y + LIFT + 0.01,
			BZ = f.z + rz * a2,
			Width = 0.85,
			Kind = "Stop",
		})
		-- The stop sign stands on the right, moved back where a slanted junction puts the major
		-- road in the way.
		local sx, sz = f.x + rx * (halfWidth + 3), f.z + rz * (halfWidth + 3)
		for back = 2, 40, 2 do
			if roads.otherDistance(sx, sz, j.Minor) >= 2 then
				break
			end
			local g = frameAt(minor, sStop + inward * back)
			local gx, gz = -g.dz * -inward, g.dx * -inward
			sx, sz = g.x + gx * (halfWidth + 3), g.z + gz * (halfWidth + 3)
		end
		table.insert(signs, { Kind = "Stop", X = sx, Y = groundY(sx, sz), Z = sz, FaceX = -hx, FaceZ = -hz })

		-- Direction sign before the stop line: where the major road leads to the left and right.
		local towardsEnd = frameAt(major, major.line.s[j.MajorSample])
		local endIsRight = towardsEnd.dx * rx + towardsEnd.dz * rz > 0
		local endBoard: Board = { Text = major.To, Road = major.Id, Arrow = if endIsRight then "Right" else "Left" }
		local startBoard: Board = { Text = major.From, Road = major.Id, Arrow = if endIsRight then "Left" else "Right" }
		local d = frameAt(minor, sStop + inward * 26)
		local dx, dz = d.x + rx * (halfWidth + 5), d.z + rz * (halfWidth + 5)
		if waterEdge(dx, dz) > 4 then
			table.insert(signs, {
				Kind = "Direction",
				X = dx,
				Y = groundY(dx, dz),
				Z = dz,
				FaceX = -hx,
				FaceZ = -hz,
				Boards = if endIsRight then { startBoard, endBoard } else { endBoard, startBoard },
			})
		end

		-- On the major road, before the junction from both directions: where the minor road leads.
		local minorTo = if j.AtStart then minor.To else minor.From
		local js = major.line.s[j.MajorSample]
		-- Which side of the major road the minor road leaves on (for traffic towards the major's end).
		local away = frameAt(minor, sStop + inward * 30)
		local side = (away.x - towardsEnd.x) * -towardsEnd.dz + (away.z - towardsEnd.z) * towardsEnd.dx
		for _, direction in { 1, -1 } do
			local s = js - direction * 90
			if s < 30 or s > major.line.length - 30 then
				continue
			end
			local m = frameAt(major, s)
			if major.onBridge[m.i] then
				continue
			end
			local mhx, mhz = m.dx * direction, m.dz * direction
			local mrx, mrz = -mhz, mhx
			local px, pz = m.x + mrx * (major.Width / 2 + 5), m.z + mrz * (major.Width / 2 + 5)
			if placeAt(px, pz, 5) or roads.otherDistance(px, pz, j.Major) < 6 or waterEdge(px, pz) < 4 then
				continue
			end
			-- Traffic heading towards the major's end sees the minor road on its right when side > 0.
			local onRight = (side > 0) == (direction == 1)
			table.insert(signs, {
				Kind = "Direction",
				X = px,
				Y = groundY(px, pz),
				Z = pz,
				FaceX = -mhx,
				FaceZ = -mhz,
				Boards = { { Text = minorTo, Road = minor.Id, Arrow = if onRight then "Right" else "Left" } },
			})
		end
	end

	-- Place signs, speed limits and street lights where roads leave places -------------------
	local function signSpot(road: any, s: number, direction: number, offset: number): (number, number, number, number)
		local f = frameAt(road, s)
		local hx, hz = f.dx * direction, f.dz * direction
		local rx, rz = -hz, hx
		return f.x + rx * offset, f.z + rz * offset, hx, hz
	end
	for r, road in roads.roads do
		local class = classes[road.Class]
		local count = #road.line.xs
		local length = road.line.length
		for _, atStart in { true, false } do
			local sample = if atStart then 1 else count
			local place = placeAt(road.line.xs[sample], road.line.zs[sample], 0.01)
			if not place or place.Kind == "Plot" then
				continue
			end
			-- Outbound traffic moves away from the place.
			local out = if atStart then 1 else -1
			local sEdge = if atStart then 0 else length
			-- Name sign for arriving traffic, on its right, just before the place.
			local x, z, hx, hz = signSpot(road, sEdge + out * 24, -out, road.Width / 2 + 5)
			table.insert(signs, {
				Kind = if place.Kind == "City" then "Town" else "Facility",
				X = x,
				Y = groundY(x, z),
				Z = z,
				FaceX = -hx,
				FaceZ = -hz,
				Text = place.Name,
			})
			if place.Kind == "City" and class.SpeedLimit then
				-- Leaving the city: the road's limit. Entering: the city limit, just after the town sign.
				local sx, sz, shx, shz = signSpot(road, sEdge + out * 70, out, road.Width / 2 + 4)
				table.insert(signs, {
					Kind = "Speed",
					X = sx,
					Y = groundY(sx, sz),
					Z = sz,
					FaceX = -shx,
					FaceZ = -shz,
					Limit = class.SpeedLimit,
				})
				local cityLimit = layout.RoadFurniture.CitySpeedLimit
				if cityLimit then
					local cx, cz, chx, chz = signSpot(road, sEdge + out * 10, -out, road.Width / 2 + 4)
					table.insert(signs, {
						Kind = "Speed",
						X = cx,
						Y = groundY(cx, cz),
						Z = cz,
						FaceX = -chx,
						FaceZ = -chz,
						Limit = cityLimit,
					})
				end
			end
			if place.Kind == "City" and road.Class == "National" then
				local s = 20
				while s <= layout.RoadFurniture.StreetLightsNearPlaces do
					local along = sEdge + out * s
					local f = frameAt(road, along)
					if not road.onBridge[f.i] then
						local lx, lz, lhx, lhz = signSpot(road, along, out, road.Width / 2 + 3)
						if roads.otherDistance(lx, lz, r) > 8 and waterEdge(lx, lz) > 4 then
							local y = supportY(lx, lz)
							if y then
								table.insert(lights, { X = lx, Y = y, Z = lz, ArmX = lhz, ArmZ = -lhx })
							end
						end
					end
					s += LIGHT_SPACING
				end
			end
		end
	end
	-- A light at every junction, across the major road from the minor road.
	for _, j in roads.junctions do
		local major = roads.roads[j.Major]
		local m = frameAt(major, major.line.s[j.MajorSample])
		local minorRoad = roads.roads[j.Minor]
		local inward = if j.AtStart then 1 else -1
		local away = frameAt(minorRoad, (if j.AtStart then 0 else minorRoad.line.length) + inward * 40)
		local side = (away.x - m.x) * -m.dz + (away.z - m.z) * m.dx
		local sign = if side > 0 then -1 else 1
		local rx, rz = -m.dz * sign, m.dx * sign
		local lx, lz = m.x + rx * (major.Width / 2 + 3), m.z + rz * (major.Width / 2 + 3)
		if roads.otherDistance(lx, lz, j.Major) > 6 and waterEdge(lx, lz) > 4 then
			local y = supportY(lx, lz)
			if y then
				table.insert(lights, { X = lx, Y = y, Z = lz, ArmX = -rx, ArmZ = -rz })
			end
		end
	end

	-- Guard rails and marker posts --------------------------------------------------------------
	for r, road in roads.roads do
		local class = classes[road.Class]
		if not class.Delineators then
			continue
		end
		local line = road.line
		local count = #line.xs
		local halfWidth = road.Width / 2
		local nearBridge: { boolean } = table.create(count, false)
		for i = 1, count do
			if road.onBridge[i] then
				for k = math.max(1, i - 5), math.min(count, i + 5) do
					nearBridge[k] = true
				end
			end
		end
		local railSides: { { boolean } } = {}
		for side = -1, 1, 2 do
			local flags: { boolean } = table.create(count, false)
			local supported: { boolean } = table.create(count, false)
			for i = 1, count do
				if road.onBridge[i] then
					continue
				end
				local f = frameAt(road, line.s[i])
				local rx, rz = -f.dz * side, f.dx * side
				local px, pz = f.x + rx * (halfWidth + 1.5), f.z + rz * (halfWidth + 1.5)
				if placeAt(px, pz, 2) or roads.otherDistance(px, pz, r) < 6 then
					continue
				end
				local ox, oz = f.x + rx * (halfWidth + 9), f.z + rz * (halfWidth + 9)
				local footY = supportY(px, pz)
				if footY == nil or (groundSampler and footY > road.profile[i] + 2.3) then
					continue
				end
				supported[i] = true
				local outside = supportY(ox, oz)
				local drop = if outside then road.profile[i] - outside else 0
				flags[i] = nearBridge[i] or drop > 3.5 or waterEdge(ox, oz) < 10
			end
			-- Close short gaps, then drop short pieces.
			local i = 1
			while i <= count do
				if not flags[i] then
					local j = i
					while j <= count and not flags[j] do
						j += 1
					end
					if i > 1 and j <= count and j - i <= 3 then
						for k = i, j - 1 do
							flags[k] = not road.onBridge[k] and (not groundSampler or supported[k])
						end
					end
					i = j
				else
					i += 1
				end
			end
			i = 1
			while i <= count do
				if flags[i] then
					local j = i
					while j <= count and flags[j] do
						j += 1
					end
					if j - i < 5 then
						for k = i, j - 1 do
							flags[k] = false
						end
					end
					i = j
				else
					i += 1
				end
			end
			railSides[side] = flags

			-- Build the rails: straight pieces along the samples, posts every 16 studs.
			i = 1
			while i <= count do
				if not flags[i] then
					i += 1
					continue
				end
				local j = i
				while j < count and flags[j + 1] do
					j += 1
				end
				local xs, ys, zs = {}, {}, {}
				for k = i, j do
					local f = frameAt(road, line.s[k])
					local rx, rz = -f.dz * side, f.dx * side
					table.insert(xs, f.x + rx * (halfWidth + 1.5))
					table.insert(ys, road.profile[k] + 2.3)
					table.insert(zs, f.z + rz * (halfWidth + 1.5))
				end
				local rail: Rail = { Pieces = {}, Posts = {} }
				for _, run in RoadNetwork.straightRuns(xs, zs, ys, 1, #xs) do
					local a, b = run[1], run[2]
					table.insert(rail.Pieces, { xs[a], ys[a], zs[a], xs[b], ys[b], zs[b] })
				end
				for k = 1, #xs, 2 do
					local y = supportY(xs[k], zs[k])
					if y then
						table.insert(rail.Posts, { xs[k], y, zs[k], ys[k] + 0.5 })
					end
				end
				if #rail.Pieces > 0 then
					table.insert(rails, rail)
				end
				i = j + 1
			end
		end

		-- Marker posts where there is no rail.
		local s = DELINEATOR_SPACING / 2
		while s < line.length do
			local f = frameAt(road, s)
			if not road.onBridge[f.i] then
				for side = -1, 1, 2 do
					if railSides[side][f.i] then
						continue
					end
					local rx, rz = -f.dz * side, f.dx * side
					local px, pz = f.x + rx * (halfWidth + 2.5), f.z + rz * (halfWidth + 2.5)
					if placeAt(px, pz, 5) or roads.otherDistance(px, pz, r) < 8 or waterEdge(px, pz) < 3 then
						continue
					end
					local y = supportY(px, pz)
					if y then
						table.insert(delineators, { X = px, Y = y, Z = pz, DirX = f.dx, DirZ = f.dz })
					end
				end
			end
			s += DELINEATOR_SPACING
		end
	end

	-- Chevron boards on the outside of tight curves ----------------------------------------------
	for r, road in roads.roads do
		if road.Class == "Access" then
			continue
		end
		local radius = radii(road)
		local line = road.line
		local count = #line.xs
		local i = 1
		while i <= count do
			if radius[i] >= 230 then
				i += 1
				continue
			end
			local j = i
			while j < count and radius[j + 1] < 230 do
				j += 1
			end
			-- Total turn of this curve.
			local a = math.max(1, i - 1)
			local b = math.min(count, j + 1)
			local d1x, d1z = line.xs[a + 1] - line.xs[a], line.zs[a + 1] - line.zs[a]
			local d2x, d2z = line.xs[b] - line.xs[b - 1], line.zs[b] - line.zs[b - 1]
			local turn = math.atan2(d1x * d2z - d1z * d2x, d1x * d2x + d1z * d2z)
			if math.abs(turn) > math.rad(30) then
				local apex = (i + j) // 2
				local turnsRight = turn > 0 -- for traffic towards the road's end
				for _, k in { apex - 4, apex, apex + 4 } do
					if k < 1 or k > count or road.onBridge[k] then
						continue
					end
					local f = frameAt(road, line.s[k])
					-- Outside of the bend: left of traffic when the road turns right.
					local side = if turnsRight then -1 else 1
					local rx, rz = -f.dz * side, f.dx * side
					local px, pz = f.x + rx * (road.Width / 2 + 3.5), f.z + rz * (road.Width / 2 + 3.5)
					if placeAt(px, pz, 5) or roads.otherDistance(px, pz, r) < 6 or waterEdge(px, pz) < 4 then
						continue
					end
					table.insert(signs, {
						Kind = "Chevron",
						X = px,
						Y = groundY(px, pz),
						Z = pz,
						FaceX = -f.dx,
						FaceZ = -f.dz,
						Turn = if turnsRight then "Right" else "Left",
					})
				end
			end
			i = j + 1
		end
	end

	-- Welcome signs at the border crossings, for traffic coming into the country ------------------
	local half: number = layout.Bounds.Half
	for _, crossing in layout.Crossings do
		local road: any = nil
		for _, candidate in roads.roads do
			if candidate.Id == crossing.Road then
				road = candidate
			end
		end
		if not road then
			continue
		end
		local along = half - 70
		-- Incoming traffic moves from the map edge inwards (towards -X or -Z here).
		local hx, hz = if crossing.Axis == "X" then -1 else 0, if crossing.Axis == "X" then 0 else -1
		local rx, rz = -hz, hx
		local offset = road.Width / 2 + 10
		local cx = if crossing.Axis == "X" then along else crossing.RoadCentre
		local cz = if crossing.Axis == "X" then crossing.RoadCentre else along
		local x, z = cx + rx * offset, cz + rz * offset
		table.insert(signs, { Kind = "Welcome", X = x, Y = groundY(x, z), Z = z, FaceX = -hx, FaceZ = -hz })
	end

	-- Power lines --------------------------------------------------------------------------------
	local roadIndex: { [string]: number } = {}
	for r, road in roads.roads do
		roadIndex[road.Id] = r
	end
	for lineId, powerLine in layout.RoadFurniture.PowerLines do
		local r = roadIndex[powerLine.Road]
		if not r then
			continue
		end
		local road = roads.roads[r]
		local side = if powerLine.Side == "Right" then 1 else -1
		local offset = road.Width / 2 + 16
		local previous: number? = nil
		local index = 0
		local s = 30
		while s < road.line.length - 30 do
			local f = frameAt(road, s)
			local rx, rz = -f.dz * side, f.dx * side
			local px, pz = f.x + rx * offset, f.z + rz * offset
			local ok = not road.onBridge[f.i]
				and placeAt(px, pz, 10) == nil
				and roads.otherDistance(px, pz, r) > 25
				and waterEdge(px, pz) > 8
			if ok then
				index += 1
				local y = supportY(px, pz)
				if y == nil then
					-- Advance using the same authored spacing even when a saved-ground sample
					-- is missing, and never wire across the missing support.
					previous = nil
					s += POLE_SPACING + Hash.range(lineId, index, 41, -10, 10)
					continue
				end
				table.insert(poles, {
					X = px,
					Y = y,
					Z = pz,
					DirX = f.dx,
					DirZ = f.dz,
					Line = lineId,
					Index = index,
				})
				local current = #poles
				if previous then
					local p = poles[previous]
					local span = math.sqrt((p.X - px) ^ 2 + (p.Z - pz) ^ 2)
					if span <= MAX_WIRE then
						table.insert(wires, { previous, current })
					end
				end
				previous = current
			end
			-- A little irregular, as real poles are.
			s += POLE_SPACING + Hash.range(lineId, index, 41, -10, 10)
		end
	end

	return {
		markings = markings,
		delineators = delineators,
		rails = rails,
		lights = lights,
		signs = signs,
		poles = poles,
		wires = wires,
		wireGround = supportY,
	}
end

return RoadDetails
