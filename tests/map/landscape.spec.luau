--!strict
-- Offline checks for the landscape pass (run with tests/map/run.py): river cascades, lakes,
-- fields, vegetation and the details along the roads (markings, posts, signs, lights, poles).
-- Each check prints PASS or FAIL; the script fails if any check fails.

local MapLayout = load("ReplicatedStorage/Shared/Config/MapLayout")
local Geometry = load("StudioTools/Map/Geometry")
local Heightfield = load("StudioTools/Map/Heightfield")
local RoadDetails = load("StudioTools/Map/RoadDetails")
local Vegetation = load("StudioTools/Map/Vegetation")

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
local roads, river, lakes, fields = hf.roads, hf.river, hf.lakes, hf.fields
print(string.format("INFO heightfield %.2f s", os.clock() - started))

local function inAnyPlace(x: number, z: number, margin: number): string?
	for _, place in MapLayout.Places do
		local r = place.Rect
		if x >= r.MinX - margin and x <= r.MaxX + margin and z >= r.MinZ - margin and z <= r.MaxZ + margin then
			return place.Id
		end
	end
	return nil
end

-- Distance outside the water's edge (river or lake); negative in the water.
local function waterEdge(x: number, z: number): number
	local d, _, _, halfWidth = river.nearest(x, z)
	return math.min(d - halfWidth, lakes.shoreDistance(x, z))
end

-- Collects the worst offender of a rule: check(name, worst.count == 0, worst.detail).
type Tally = { count: number, detail: string }
local function tally(): Tally
	return { count = 0, detail = "" }
end
local function fail(t: Tally, detail: string)
	t.count += 1
	if t.count == 1 then
		t.detail = detail
	end
end
local function report(name: string, t: Tally)
	check(name, t.count == 0, if t.count > 0 then `{t.count} times, first {t.detail}` else nil)
end

-- River cascades and width ------------------------------------------------------------------------
do
	local water = river.water
	local isStep: { [number]: boolean } = {}
	for _, i in river.steps do
		isStep[i] = true
	end
	local wrong = tally()
	for i = 2, #water do
		local drops = water[i] < water[i - 1] - 1e-6
		if drops ~= (isStep[i] == true) then
			fail(wrong, `sample {i}`)
		end
	end
	report("river: the water level only drops at the listed cascades (flat pools between)", wrong)
	local step: number = MapLayout.River.CascadeStep
	local unaligned = tally()
	for i, w in water do
		if math.abs(w / step - math.floor(w / step + 0.5)) > 1e-6 then
			fail(unaligned, string.format("sample %d at %.2f", i, w))
		end
	end
	report(`river: pool surfaces are whole multiples of {step} studs`, unaligned)
	local shrinking = tally()
	for i = 2, #river.halfWidths do
		if river.halfWidths[i] < river.halfWidths[i - 1] - 1e-9 then
			fail(shrinking, `sample {i}`)
		end
	end
	report("river: never gets narrower downstream", shrinking)
	local first, last = river.halfWidths[1] * 2, river.halfWidths[#river.halfWidths] * 2
	check(
		`river: {MapLayout.River.SourceWidth} studs wide at the source, {MapLayout.River.Width} at the border`,
		math.abs(first - MapLayout.River.SourceWidth) < 0.5 and math.abs(last - MapLayout.River.Width) < 0.5,
		string.format("%.1f -> %.1f", first, last)
	)
	print(string.format("INFO river: %d cascades", #river.steps))
end

-- Lakes ----------------------------------------------------------------------------------------------
-- Points around a lake at distance d from its shore line (found by bisection along rays).
local function ring(lake: any, d: number, count: number): { { number } }
	local points = {}
	for k = 0, count - 1 do
		local a = k * 2 * math.pi / count
		local c, s = math.cos(a), math.sin(a)
		local lo, hi = 0, math.max(lake.Rx, lake.Rz) * 2 + d + 50
		for _ = 1, 40 do
			local mid = (lo + hi) / 2
			if lakes.shoreDistance(lake.X + c * mid, lake.Z + s * mid) < d then
				lo = mid
			else
				hi = mid
			end
		end
		table.insert(points, { lake.X + c * lo, lake.Z + s * lo })
	end
	return points
end

for _, lake in lakes.list do
	local wet = tally()
	for _, d in { -40, -15, -4 } do
		for _, p in ring(lake, d, 72) do
			local h, _, w = hf.surface(p[1], p[2])
			if w ~= lake.WaterY or h >= lake.WaterY then
				fail(wet, string.format("(%.0f, %.0f) bed %.1f water %s", p[1], p[2], h, tostring(w)))
			end
		end
	end
	report(`{lake.Id}: water over a bed below the water line`, wet)
	local dry = tally()
	for _, d in { 1, 6, 12, 30 } do
		for _, p in ring(lake, d, 72) do
			local h, _, w = hf.surface(p[1], p[2])
			if w ~= nil or h < lake.WaterY then
				fail(dry, string.format("(%.0f, %.0f) ground %.1f water %.1f", p[1], p[2], h, lake.WaterY))
			end
		end
	end
	report(`{lake.Id}: the shore stays above the water (no water walls)`, dry)
	-- The basin slope meets the land without a step.
	local stepped = tally()
	for _, p in ring(lake, 14 + 110 - 1, 120) do
		local land = hf.land.height(p[1], p[2])
		local carved = lakes.carve(p[1], p[2], land)
		if land - carved > 1 then
			fail(stepped, string.format("(%.0f, %.0f) %.1f studs", p[1], p[2], land - carved))
		end
	end
	report(`{lake.Id}: basin fades into the land without a step`, stepped)
	local nearRoad = math.huge
	for _, road in roads.roads do
		for i = 1, #road.line.xs do
			nearRoad = math.min(nearRoad, lakes.shoreDistance(road.line.xs[i], road.line.zs[i]) - road.Width / 2)
		end
	end
	check(`{lake.Id}: at least 20 studs from every road`, nearRoad >= 20, string.format("%.1f", nearRoad))
	print(string.format("INFO %s: water at Y %d, %.0f x %.0f studs", lake.Id, lake.WaterY, lake.Rx * 2, lake.Rz * 2))
end

-- Fields and barns ------------------------------------------------------------------------------------
do
	local list = fields.list
	check("fields: at least 100", #list >= 100, `{#list}`)
	local overlap = tally()
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			if a.MinX < b.MaxX and b.MinX < a.MaxX and a.MinZ < b.MaxZ and b.MinZ < a.MaxZ then
				fail(overlap, `{a.Id} and {b.Id}`)
			end
		end
	end
	report("fields: do not overlap", overlap)
	local clearance: number = MapLayout.Farming.RoadClearance
	local placeIds: { [string]: boolean } = {}
	for _, place in MapLayout.Places do
		placeIds[place.Id] = true
	end
	local onRoad, inWater, inPlace, wrongCrop = tally(), tally(), tally(), tally()
	for _, field in list do
		-- A plot with a crop (the tobacco fields property) is itself a field.
		local isPlot = placeIds[field.Zone] == true
		local w, d = field.MaxX - field.MinX, field.MaxZ - field.MinZ
		local nx, nz = math.ceil(w / 8), math.ceil(d / 8)
		for k = 0, nx do
			for j = 0, nz do
				local x, z = field.MinX + w * k / nx, field.MinZ + d * j / nz
				local e = roads.nearest(x, z)
				if e and e < clearance - 1 and not isPlot then
					fail(onRoad, string.format("field %d at (%.0f, %.0f): %.1f", field.Id, x, z, e))
				end
				if waterEdge(x, z) < river.bankWidth then
					fail(inWater, string.format("field %d at (%.0f, %.0f)", field.Id, x, z))
				end
				if inAnyPlace(x, z, 0) and not isPlot then
					fail(inPlace, `field {field.Id} in {inAnyPlace(x, z, 0)}`)
				end
			end
		end
		local found = fields.cropAt((field.MinX + field.MaxX) / 2 + 1, (field.MinZ + field.MaxZ) / 2 + 1)
		if found ~= field and not (found and found.Id == field.Id) then
			-- The middle can be a barn yard of the same field; anything else is wrong.
			fail(wrongCrop, `field {field.Id}`)
		end
	end
	report(`fields: at least {clearance} studs from the roads`, onRoad)
	report("fields: clear of the river, its banks and the lakes", inWater)
	report("fields: outside places (except plots that are fields)", inPlace)
	report("fields: cropAt finds each field", wrongCrop)
	local crops: { [string]: number } = {}
	for _, field in list do
		crops[field.Crop] = (crops[field.Crop] or 0) + 1
	end
	local summary = {}
	for crop, n in crops do
		table.insert(summary, `{crop} {n}`)
	end
	table.sort(summary)
	print("INFO fields: " .. table.concat(summary, ", "))
	check("fields: tobacco grows somewhere", (crops.Tobacco or 0) >= 10, `{crops.Tobacco or 0}`)

	local barnProblem = tally()
	for _, barn in fields.barns do
		local field = list[barn.Field]
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local hx = if barn.AlongX then barn.Width / 2 else barn.Depth / 2
				local hz = if barn.AlongX then barn.Depth / 2 else barn.Width / 2
				local x, z = barn.X + sx * hx, barn.Z + sz * hz
				local e = roads.nearest(x, z)
				if (e and e < 4) or waterEdge(x, z) < river.bankWidth or inAnyPlace(x, z, 0) then
					fail(barnProblem, string.format("barn at (%.0f, %.0f)", barn.X, barn.Z))
				end
			end
		end
		if field == nil or field.Crop ~= "Tobacco" then
			fail(barnProblem, string.format("barn at (%.0f, %.0f) not beside tobacco", barn.X, barn.Z))
		end
	end
	report("barns: beside tobacco fields, off roads and water", barnProblem)
	check(`barns: {MapLayout.Farming.Barns} placed`, #fields.barns == MapLayout.Farming.Barns, `{#fields.barns}`)
end

-- Road details --------------------------------------------------------------------------------------
started = os.clock()
local details = RoadDetails.new(MapLayout, hf)
print(string.format("INFO road details %.2f s", os.clock() - started))

do
	local offRoad, height = tally(), tally()
	local worstLift = 0
	for _, m in details.markings do
		for _, t in { 0, 0.5, 1 } do
			local x = m.AX + (m.BX - m.AX) * t
			local y = m.AY + (m.BY - m.AY) * t
			local z = m.AZ + (m.BZ - m.AZ) * t
			local e, roadY = roads.nearest(x, z)
			if e == nil or e > -m.Width / 2 + 0.01 then
				fail(offRoad, string.format("%s at (%.1f, %.1f) edge %s", m.Kind, x, z, tostring(e)))
			elseif math.abs(y - roadY) > 0.4 then
				-- Where two roads meet, the nearest edge can belong to the other road.
				local _, _, r = roads.nearest(x, z)
				if roads.otherDistance(x, z, r) > 0 then
					fail(height, string.format("%s at (%.1f, %.1f): %.2f above the road", m.Kind, x, z, y - roadY))
				end
			end
			worstLift = math.max(worstLift, math.abs(y - roadY))
		end
	end
	report("markings: lie inside the road surface", offRoad)
	report("markings: sit on the road (within 0.4 studs)", height)
	print(string.format("INFO markings: %d strips", #details.markings))

	local function standsBeside(name: string, items: { any }, minEdge: number)
		local onRoad, wet, floating = tally(), tally(), tally()
		for _, p in items do
			local e = roads.nearest(p.X, p.Z)
			if e and e < minEdge then
				fail(onRoad, string.format("(%.1f, %.1f) %.1f from the road edge", p.X, p.Z, e))
			end
			local h, _, w = hf.surface(p.X, p.Z)
			if w ~= nil then
				fail(wet, string.format("(%.1f, %.1f)", p.X, p.Z))
			end
			if math.abs(h - p.Y) > 0.01 then
				fail(floating, string.format("(%.1f, %.1f) Y %.2f ground %.2f", p.X, p.Z, p.Y, h))
			end
		end
		report(`{name}: beside the road, not on it`, onRoad)
		report(`{name}: on dry land`, wet)
		report(`{name}: stand on the ground`, floating)
	end
	standsBeside("marker posts", details.delineators, 0.5)
	standsBeside("signs", details.signs, 1)
	standsBeside("street lights", details.lights, 1)
	standsBeside("power poles", details.poles, 2)

	local kinds: { [string]: number } = {}
	local badSpeed = tally()
	for _, sign in details.signs do
		kinds[sign.Kind] = (kinds[sign.Kind] or 0) + 1
		if sign.Kind == "Speed" and sign.Limit ~= 50 and sign.Limit ~= 80 and sign.Limit ~= 100 then
			fail(badSpeed, `{sign.Limit}`)
		end
		local len = math.sqrt(sign.FaceX ^ 2 + sign.FaceZ ^ 2)
		if math.abs(len - 1) > 1e-6 then
			fail(badSpeed, `{sign.Kind} faces nowhere`)
		end
	end
	report("signs: speed limits are 50, 80 or 100 and every sign faces a direction", badSpeed)
	check(
		"signs: a stop sign at every junction",
		(kinds.Stop or 0) == #roads.junctions,
		`{kinds.Stop or 0} stop signs, {#roads.junctions} junctions`
	)
	check("signs: two welcome signs at the border crossings", (kinds.Welcome or 0) == 2, `{kinds.Welcome or 0}`)
	-- Every city has a name sign on each road that enters it.
	local missing = tally()
	for _, place in MapLayout.Places do
		if place.Kind ~= "City" then
			continue
		end
		local entries = 0
		for _, road in roads.roads do
			for _, sample in { 1, #road.line.xs } do
				if Geometry.inRect(place.Rect, road.line.xs[sample], road.line.zs[sample]) then
					entries += 1
				end
			end
		end
		local named = 0
		for _, sign in details.signs do
			if sign.Kind == "Town" and sign.Text == place.Name then
				named += 1
			end
		end
		if named ~= entries then
			fail(missing, `{place.Name}: {named} signs for {entries} roads`)
		end
	end
	report("signs: a town sign on every road into a city", missing)
	local summary = {}
	for kind, n in kinds do
		table.insert(summary, `{kind} {n}`)
	end
	table.sort(summary)
	print("INFO signs: " .. table.concat(summary, ", "))

	local longWire = tally()
	for _, pair in details.wires do
		local a, b = details.poles[pair[1]], details.poles[pair[2]]
		local span = math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
		if span > 260 or span < 20 then
			fail(longWire, string.format("%.0f studs", span))
		end
	end
	report("power lines: spans between 20 and 260 studs", longWire)

	local railProblem = tally()
	for _, rail in details.rails do
		for _, piece in rail.Pieces do
			local e = roads.nearest((piece[1] + piece[4]) / 2, (piece[3] + piece[6]) / 2)
			if e == nil or e < 0.5 or e > 3 then
				fail(railProblem, string.format("(%.0f, %.0f) %s", piece[1], piece[3], tostring(e)))
			end
		end
	end
	report("guard rails: run just outside the road edge", railProblem)
end

-- Vegetation -----------------------------------------------------------------------------------------
started = os.clock()
local plants = Vegetation.new(MapLayout, hf, details)
print(string.format("INFO vegetation %.2f s", os.clock() - started))

do
	local treeLine: number = MapLayout.Vegetation.TreeLine
	local onRoad, wet, inField, inPlace, tooHigh, floating = tally(), tally(), tally(), tally(), tally(), tally()
	local kinds: { [string]: number } = {}
	for _, t in plants.trees do
		kinds[t.Kind] = (kinds[t.Kind] or 0) + 1
		local e = roads.nearest(t.X, t.Z)
		-- Avenue trees stand 6 studs from the edge; all others outside the verge.
		if e and e < 5 then
			fail(onRoad, string.format("%s at (%.0f, %.0f) %.1f from the edge", t.Kind, t.X, t.Z, e))
		end
		local h, _, w = hf.surface(t.X, t.Z)
		if w ~= nil or waterEdge(t.X, t.Z) < 0 then
			fail(wet, string.format("(%.0f, %.0f)", t.X, t.Z))
		end
		if fields.cropAt(t.X, t.Z) ~= nil then
			fail(inField, string.format("(%.0f, %.0f)", t.X, t.Z))
		end
		if inAnyPlace(t.X, t.Z, 0) then
			fail(inPlace, `{inAnyPlace(t.X, t.Z, 0)}`)
		end
		if t.Y > treeLine then
			fail(tooHigh, string.format("Y %.0f", t.Y))
		end
		if math.abs(h - t.Y) > 0.01 then
			fail(floating, string.format("(%.0f, %.0f)", t.X, t.Z))
		end
	end
	report("trees: off roads and verges", onRoad)
	report("trees: not in water", wet)
	report("trees: not in fields", inField)
	report("trees: not in places", inPlace)
	report(`trees: below the tree line (Y {treeLine})`, tooHigh)
	report("trees: stand on the ground", floating)
	for _, kind in Vegetation.TreeKinds do
		check(`trees: some {kind}`, (kinds[kind] or 0) >= 100, `{kinds[kind] or 0}`)
	end

	-- No trees under the power lines.
	local underWire = tally()
	for _, pair in details.wires do
		local a, b = details.poles[pair[1]], details.poles[pair[2]]
		for _, t in plants.trees do
			if math.abs(t.X - a.X) < 300 and math.abs(t.Z - a.Z) < 300 then
				if Geometry.segmentDistance(a.X, a.Z, b.X, b.Z, t.X, t.Z) < 11.9 then
					fail(underWire, string.format("(%.0f, %.0f)", t.X, t.Z))
				end
			end
		end
	end
	report("trees: none under the power lines", underWire)

	local bushProblem, rockProblem = tally(), tally()
	for _, b in plants.bushes do
		local e = roads.nearest(b.X, b.Z)
		local _, _, w = hf.surface(b.X, b.Z)
		if (e and e < 4) or w ~= nil or fields.cropAt(b.X, b.Z) ~= nil or inAnyPlace(b.X, b.Z, 0) then
			fail(bushProblem, string.format("(%.0f, %.0f)", b.X, b.Z))
		end
	end
	for _, r in plants.rocks do
		local e = roads.nearest(r.X, r.Z)
		if (e and e < 3) or fields.cropAt(r.X, r.Z) ~= nil or inAnyPlace(r.X, r.Z, 0) then
			fail(rockProblem, string.format("(%.0f, %.0f)", r.X, r.Z))
		end
	end
	report("bushes: off roads, water, fields and places", bushProblem)
	report("rocks: off roads, fields and places", rockProblem)

	-- Part budget: trees 2-3 parts, bushes 1-2, rocks 1 (the builder spec counts exactly).
	local estimate = #plants.trees * 3 + #plants.bushes * 2 + #plants.rocks
	print(
		string.format(
			"INFO vegetation: %d trees (%s), %d bushes, %d rocks, at most %d parts",
			#plants.trees,
			(function()
				local list = {}
				for kind, n in kinds do
					table.insert(list, `{kind} {n}`)
				end
				table.sort(list)
				return table.concat(list, ", ")
			end)(),
			#plants.bushes,
			#plants.rocks,
			estimate
		)
	)
	check("vegetation: at most 36000 parts", estimate <= 36000, `{estimate}`)
	check("vegetation: lively (at least 4000 trees)", #plants.trees >= 4000, `{#plants.trees}`)

	-- Same layout, same plants.
	local again = Vegetation.new(MapLayout, hf, details)
	local same = #again.trees == #plants.trees and #again.bushes == #plants.bushes and #again.rocks == #plants.rocks
	if same then
		for i = 1, #plants.trees, 97 do
			local a, b = plants.trees[i], again.trees[i]
			same = same and a.X == b.X and a.Z == b.Z and a.Kind == b.Kind and a.Size == b.Size
		end
	end
	check("vegetation: repeatable (same layout gives the same plants)", same)
end

if failures > 0 then
	error(`{failures} check(s) failed`)
end
print("ALL CHECKS PASSED")
