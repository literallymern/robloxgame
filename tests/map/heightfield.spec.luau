--!strict
-- Offline checks for the map layout and the terrain calculations (run with tests/map/run.py).
-- Each check prints PASS or FAIL; the script fails if any check fails.

local MapLayout = load("ReplicatedStorage/Shared/Config/MapLayout")
local Geometry = load("StudioTools/Map/Geometry")
local Heightfield = load("StudioTools/Map/Heightfield")

local failures = 0
local function check(name: string, ok: boolean, detail: string?)
	if ok then
		print("PASS", name)
	else
		failures += 1
		print("FAIL", name, detail or "")
	end
end

local started = os.clock()
local hf = Heightfield.new(MapLayout)
print(string.format("INFO build time %.2f s", os.clock() - started))

local placeById = {}
for _, place in MapLayout.Places do
	placeById[place.Id] = place
end

-- Geometry helpers ---------------------------------------------------------------------------
do
	local d, t = Geometry.segmentDistance(0, 0, 10, 0, 5, 3)
	check("segmentDistance", math.abs(d - 3) < 1e-9 and math.abs(t - 0.5) < 1e-9)
	local a, b = Geometry.segmentIntersection(0, 0, 10, 0, 5, -5, 5, 5)
	check("segmentIntersection", a == 0.5 and b == 0.5)
	local xs, zs, r = Geometry.fillet({ { 0, 0 }, { 100, 0 }, { 100, 100 } }, 30, 2)
	check("fillet keeps radius", math.abs(r - 30) < 1e-9)
	local worst = 0
	for i = 1, #xs do
		-- every point of the rounded corner lies on the line or on the circle around (70, 30)
		local onLine = math.abs(zs[i]) < 1e-6 or math.abs(xs[i] - 100) < 1e-6
		local onArc = math.abs(math.sqrt((xs[i] - 70) ^ 2 + (zs[i] - 30) ^ 2) - 30) < 1e-6
		if not (onLine or onArc) then
			worst += 1
		end
	end
	check("fillet points on line or arc", worst == 0, `{worst} stray points`)
	local line = Geometry.resample({ 0, 100 }, { 0, 0 }, 8)
	check("resample keeps ends", line.xs[1] == 0 and line.xs[#line.xs] == 100 and line.length == 100)
end

-- Roads ----------------------------------------------------------------------------------------
for _, road in hf.roads.roads do
	local class = MapLayout.RoadClasses[road.Class]
	check(`{road.Id}: height plan possible`, road.feasible)
	local maxGrade = 0
	for i = 2, #road.profile do
		local g = math.abs(road.profile[i] - road.profile[i - 1]) / (road.line.s[i] - road.line.s[i - 1])
		maxGrade = math.max(maxGrade, g)
	end
	check(
		`{road.Id}: grade within {class.MaxGrade * 100} %`,
		maxGrade <= class.MaxGrade + 1e-9,
		string.format("%.4f", maxGrade)
	)
	check(
		`{road.Id}: curves not tighter than {class.MinRadius} studs`,
		road.MinRadius >= class.MinRadius,
		string.format("%.1f", road.MinRadius)
	)
	-- Flat where the road is inside a place.
	local worst = 0
	for i = 1, #road.profile do
		local x, z = road.line.xs[i], road.line.zs[i]
		for _, place in MapLayout.Places do
			if Geometry.inRect(place.Rect, x, z) then
				worst = math.max(worst, math.abs(road.profile[i] - hf.land.placeGround[place.Id]))
			end
		end
	end
	check(`{road.Id}: level with the places it enters`, worst < 0.05, string.format("off by %.2f", worst))
end

-- Every road end is on a place or on another road (no dead ends in the countryside).
for roadIndex, road in MapLayout.Roads do
	for _, point in { road.Points[1], road.Points[#road.Points] } do
		local x, z = point[1], point[2]
		local ok = false
		for _, place in MapLayout.Places do
			local r = place.Rect
			if x >= r.MinX - 0.01 and x <= r.MaxX + 0.01 and z >= r.MinZ - 0.01 and z <= r.MaxZ + 0.01 then
				ok = true
			end
		end
		for otherIndex, other in hf.roads.roads do
			if otherIndex ~= roadIndex then
				for i = 1, #other.line.xs - 1 do
					local d = Geometry.segmentDistance(
						other.line.xs[i],
						other.line.zs[i],
						other.line.xs[i + 1],
						other.line.zs[i + 1],
						x,
						z
					)
					if d <= other.Width / 2 then
						ok = true
					end
				end
			end
		end
		check(`{road.Id}: end ({x}, {z}) connects to a place or road`, ok)
	end
end

-- Bridges ----------------------------------------------------------------------------------------
do
	local found = {}
	for _, bridge in hf.roads.bridges do
		found[bridge.Road] = (found[bridge.Road] or 0) + 1
		local road = hf.roads.roads[bridge.RoadIndex]
		local lowest = math.huge
		for i = bridge.First, bridge.Last do
			lowest = math.min(lowest, road.profile[i])
		end
		check(
			`bridge {bridge.Road}: deck clears the water by {MapLayout.River.RoadClearance}`,
			lowest >= bridge.WaterY + MapLayout.River.RoadClearance - 1e-6,
			string.format("deck %.1f water %.1f", lowest, bridge.WaterY)
		)
		check(
			`bridge {bridge.Road}: crossing angle at least 45 degrees`,
			bridge.Angle >= 45,
			string.format("%.0f", bridge.Angle)
		)
	end
	local expected = { "N3", "N4", "N5", "R2", "R3" }
	local count = 0
	for _ in found do
		count += 1
	end
	local all = true
	for _, id in expected do
		all = all and found[id] == 1
	end
	check("exactly one bridge on each of R2, N3, N4, N5, R3", all and count == #expected)
end

-- Roads keep clear of the river except on bridges.
do
	local river = hf.river
	local worst, where = math.huge, ""
	for _, road in hf.roads.roads do
		for i = 1, #road.line.xs do
			if not road.onBridge[i] then
				-- Both edges of the road surface must stay outside the water and the banks.
				local j = math.min(i, #road.line.xs - 1)
				local dx, dz = road.line.xs[j + 1] - road.line.xs[j], road.line.zs[j + 1] - road.line.zs[j]
				local len = math.sqrt(dx * dx + dz * dz)
				for _, side in { -1, 1 } do
					local ex = road.line.xs[i] - dz / len * side * road.Width / 2
					local ez = road.line.zs[i] + dx / len * side * road.Width / 2
					local clear = river.nearest(ex, ez) - river.halfWidth - river.bankWidth
					if clear < worst then
						worst = clear
						where = `{road.Id} sample {i}`
					end
				end
			end
		end
	end
	check("roads stay clear of the river outside bridges", worst >= 0, string.format("%.1f at %s", worst, where))
end

-- River --------------------------------------------------------------------------------------------
do
	local water = hf.river.water
	local rising = 0
	for i = 2, #water do
		if water[i] > water[i - 1] + 1e-9 then
			rising += 1
		end
	end
	check("river never flows uphill", rising == 0, `{rising} rising samples`)
	local last = MapLayout.River.Points[#MapLayout.River.Points]
	check("river leaves the map at the edge", math.abs(last[2]) >= MapLayout.Bounds.Half)
	print(string.format("INFO river water level %.0f -> %.0f", water[1], water[#water]))
	-- The carve fades out before its reach, so the valley never ends in a step.
	local steps = 0
	local line = hf.river.line
	for i = 1, #line.xs - 1, 10 do
		local dx, dz = line.xs[i + 1] - line.xs[i], line.zs[i + 1] - line.zs[i]
		local len = math.sqrt(dx * dx + dz * dz)
		for _, side in { -1, 1 } do
			local px = line.xs[i] - dz / len * side * (hf.river.reach - 1)
			local pz = line.zs[i] + dx / len * side * (hf.river.reach - 1)
			local land = hf.land.height(px, pz)
			local carved = hf.river.carve(px, pz, land)
			if carved < land - 0.5 then
				steps += 1
			end
		end
	end
	check("river valley fades out within its reach", steps == 0, `{steps} places with a step`)
end

-- Places ---------------------------------------------------------------------------------------------
for _, place in MapLayout.Places do
	local ground = hf.land.placeGround[place.Id]
	local r = place.Rect
	local worst = 0
	for k = 0, 8 do
		for j = 0, 8 do
			local x = r.MinX + (r.MaxX - r.MinX) * k / 8
			local z = r.MinZ + (r.MaxZ - r.MinZ) * j / 8
			local e = hf.roads.nearest(x, z)
			local riverDistance = hf.river.nearest(x, z)
			if (e == nil or e > 4) and riverDistance > hf.river.reach then
				local h = hf.surface(x, z)
				worst = math.max(worst, math.abs(h - ground))
			end
		end
	end
	check(`{place.Id}: flat at Y {ground}`, worst < 0.05, string.format("off by %.2f", worst))
end

-- Inside the playable area, places do not overlap (except plots inside cities).
for i, a in MapLayout.Places do
	for j, b in MapLayout.Places do
		if j > i and a.Kind ~= "Plot" and b.Kind ~= "Plot" then
			local ra, rb = a.Rect, b.Rect
			local overlap = ra.MinX < rb.MaxX and rb.MinX < ra.MaxX and ra.MinZ < rb.MaxZ and rb.MinZ < ra.MaxZ
			check(`{a.Id} and {b.Id} do not overlap`, not overlap)
		end
	end
end

-- Properties, placeholders and spawn -----------------------------------------------------------------
do
	local names = {}
	for _, property in MapLayout.Properties do
		check(`property name unique: {property.Name}`, names[property.Name] == nil)
		names[property.Name] = true
		local city = placeById[property.Place or property.City]
		local r = property.Rect
		local inCity = city ~= nil
			and r.MinX >= city.Rect.MinX
			and r.MaxX <= city.Rect.MaxX
			and r.MinZ >= city.Rect.MinZ
			and r.MaxZ <= city.Rect.MaxZ
		local onPlot = false
		for _, place in MapLayout.Places do
			local p = place.Rect
			if
				place.Kind == "Plot"
				and p.MinX == r.MinX
				and p.MaxX == r.MaxX
				and p.MinZ == r.MinZ
				and p.MaxZ == r.MaxZ
			then
				onPlot = true
			end
		end
		check(`property placed in its city or on its own plot: {property.Name}`, inCity or onPlot)
		local cx, cz = Geometry.rectCentre(r)
		local e = hf.roads.nearest(cx, cz)
		check(`property not on a road: {property.Name}`, e == nil or e > 0)
	end
	check("16 properties", #MapLayout.Properties == 16)
	print("PROPERTIES " .. table.concat(
		(function()
			local list = {}
			for _, property in MapLayout.Properties do
				table.insert(list, `{property.Name};{property.City};{property.Type}`)
			end
			return list
		end)(),
		"|"
	))

	local blocks = MapLayout.GundivillePlaceholders
	local city = placeById.Gundiville.Rect
	for i, a in blocks do
		local r = a.Rect
		check(
			`placeholder inside Gundiville: {a.Id}`,
			r.MinX >= city.MinX and r.MaxX <= city.MaxX and r.MinZ >= city.MinZ and r.MaxZ <= city.MaxZ
		)
		for j, b in blocks do
			if j > i then
				local s = b.Rect
				local overlap = r.MinX < s.MaxX and s.MinX < r.MaxX and r.MinZ < s.MaxZ and s.MinZ < r.MaxZ
				check(`placeholders {a.Id} and {b.Id} do not overlap`, not overlap)
			end
		end
		if a.Height > 0 then
			for _, property in MapLayout.Properties do
				local s = property.Rect
				local overlap = r.MinX < s.MaxX and s.MinX < r.MaxX and r.MinZ < s.MaxZ and s.MinZ < r.MaxZ
				check(`placeholder {a.Id} leaves {property.Name} free`, not overlap)
			end
		end
	end

	local spawn = MapLayout.Spawn
	local sx, sz = spawn.Centre[1], spawn.Centre[2]
	local e = hf.roads.nearest(sx, sz)
	check("spawn not on a road", e == nil or e > spawn.Size)
	check("spawn on flat ground", math.abs(hf.surface(sx, sz) - spawn.GroundY) < 0.05)
end

-- Terrain smoothness inside the playable area ------------------------------------------------------
do
	local step = 8
	local limit = MapLayout.Bounds.Playable - MapLayout.Mountains.StartInside - 250
	local worst, wx, wz = 0, 0, 0
	local samples = 0
	local t0 = os.clock()
	for x = -limit, limit, step * 4 do
		local previous = hf.surface(x, -limit)
		for z = -limit + step, limit, step do
			local h = hf.surface(x, z)
			samples += 1
			local slope = math.abs(h - previous) / step
			if slope > worst then
				worst, wx, wz = slope, x, z
			end
			previous = h
		end
	end
	local perSample = (os.clock() - t0) / samples * 1e6
	print(string.format("INFO steepest step inside the ring: %.2f at (%d, %d)", worst, wx, wz))
	print(string.format("INFO surface() costs %.1f microseconds per column here", perSample))
	check("no cliffs inside the ring (slope below 2)", worst < 2, string.format("%.2f", worst))
end

print(string.format("INFO total time %.2f s", os.clock() - started))
if failures > 0 then
	error(`{failures} check(s) failed`)
end
print("ALL CHECKS PASSED")
