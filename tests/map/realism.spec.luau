--!nocheck
-- needs: roblox-mock
-- Quantitative checks of the ACTIVE surface and infrastructure, not a renderer/performance test.
local Layout = load("ReplicatedStorage/Shared/Config/MapLayout")
local hf = load("StudioTools/Map/Heightfield").new(Layout)
local old = hf.highland4
local Junction = load("StudioTools/Map/JunctionLandscape")
local feature = Junction.decorate(hf, Layout)
local Details = load("StudioTools/Map/RoadDetails").new(Layout, hf)
local passed = 0
local function check(ok, name)
	assert(ok, name)
	passed += 1
	print("PASS " .. name)
end
local function slope(surface, x, z)
	local dx, dz = (surface(x + 4, z) - surface(x - 4, z)) / 8, (surface(x, z + 4) - surface(x, z - 4)) / 8
	return math.sqrt(dx * dx + dz * dz)
end
local function same(x, z)
	local h, c, w = hf.surface(x, z)
	local a, b, v = old.surface(x, z)
	return h == a and c == b and w == v
end
for _, road in hf.roads.roads do
	for i = 1, #road.line.xs, 7 do
		assert(same(road.line.xs[i], road.line.zs[i]), "road or bridge profile changed: " .. road.Id)
	end
end
check(true, "all sampled carriageways, bridge decks and mountain passes keep their saved elevation")
for _, place in Layout.Places do
	for _, x in { place.Rect.MinX, place.Rect.MaxX } do
		for _, z in { place.Rect.MinZ, place.Rect.MaxZ } do
			assert(same(x, z))
		end
	end
end
for _, field in hf.fields.list do
	assert(same(field.MinX, field.MinZ) and same(field.MaxX, field.MaxZ))
end
check(true, "settlement anchors, property plots, agricultural fields and entrances keep their elevation")
for _, place in Layout.GundivillePlaceholders do
	if table.find({ "Congress", "Hausali", "CentralBank", "Residence" }, place.Id) then
		for x = place.Rect.MinX, place.Rect.MaxX, 8 do
			for z = place.Rect.MinZ, place.Rect.MaxZ, 8 do
				assert(same(x, z), place.Id)
			end
		end
	end
end
check(true, "the complete four government building footprints retain their terrain")
local oldCliffs, newCliffs, oldRock, newRock, changed = 0, 0, 0, 0, 0
local woods, tallWoods, meadows, tallMeadows, water = 0, 0, 0, 0, 0
local peak = 0
for z = -5050, 5050, 64 do
	for x = -5050, 5050, 64 do
		local h, c, w = hf.surface(x, z)
		local a, b, v = old.surface(x, z)
		assert(h == h and h >= Layout.Bounds.FloorY and w == v)
		if w then
			assert(h == a and c == b, "water bed changed")
			water += 1
		elseif c <= 0 then
			local s, os = slope(hf.surface, x, z), slope(old.surface, x, z)
			local material = hf.naturalMaterial(h, s, x, z, c)
			peak = math.max(peak, h)
			if hf.reliefMask(x, z) > 0.5 then
				if hf.biomes.forest(x, z) > 0.24 then
					woods += 1
					if material == 1 then
						tallWoods += 1
					end
				elseif s < 0.3 then
					meadows += 1
					if material == 1 then
						tallMeadows += 1
					end
				end
			end
			if math.max(math.abs(x), math.abs(z)) > 3800 then
				if os > 1 then
					oldCliffs += 1
				end
				if s > 1 then
					newCliffs += 1
				end
				local before = old.naturalMaterial(a, os, x, z, b)
				if before == 3 or before == 9 or before == 10 then
					oldRock += 1
				end
				if material == 3 or material == 9 or material == 10 then
					newRock += 1
				end
				if math.abs(h - a) > 30 then
					changed += 1
				end
			end
		end
	end
end
check(oldCliffs > 3000 and newCliffs < oldCliffs * 0.35, "steep mountain samples fall by at least 65 percent")
check(
	newRock < oldRock * 0.4 and newRock > 100,
	"vegetated slopes replace the continuous rock ring while local cliffs remain"
)
check(changed > 5000 and peak > 550, "mountain reconstruction changes the whole boundary at a meaningful scale")
check(water > 100, "river and lake beds and levels remain exact across the map")
check(woods > 2000 and tallWoods / woods < 0.05, "woodland floor no longer emits a continuous tall-grass carpet")
check(
	meadows > 4000 and tallMeadows / meadows > 0.08 and tallMeadows / meadows < 0.4,
	"meadows mix low cover with connected taller patches instead of identical long grass"
)
local woodland, tallRegional = 0, 0
for z = 3000, 3600, 8 do
	for x = 100, 800, 8 do
		local h, c = feature.surface(x, z)
		if Junction.forest(x, z) > 0.4 and c <= 0 and (hf.roads.nearest(x, z) or 999) > 25 then
			woodland += 1
			if feature.naturalMaterial(h, slope(feature.surface, x, z), x, z, c) == 1 then
				tallRegional += 1
			end
		end
	end
end
check(
	woodland > 500 and tallRegional == 0,
	"the regional updater retains the same low woodland cover after regeneration"
)
check(
	#Junction.engineeredDrains(hf) < #Junction.drains(hf) / 2,
	"less than half the former continuous drainage requires concrete lining"
)
local stopCount, separated = 0, true
for _, marking in Details.markings do
	if marking.Kind == "Stop" then
		stopCount += 1
		local mid = Vector3.new((marking.AX + marking.BX) / 2, 0, (marking.AZ + marking.BZ) / 2)
		for _, line in Details.markings do
			if line.Kind ~= "Stop" then
				local d =
					load("StudioTools/Map/Geometry").segmentDistance(line.AX, line.AZ, line.BX, line.BZ, mid.X, mid.Z)
				if d < 0.5 then
					separated = false
				end
			end
		end
	end
end
check(stopCount > 5 and separated, "junction stop bars do not cross centre or edge lines")
print(
	`INFO rework: cliffs {oldCliffs} -> {newCliffs}; rock {oldRock} -> {newRock}; {changed} large mountain changes; woods tall grass {tallWoods}/{woods}, meadows {tallMeadows}/{meadows}; concrete paths {#Junction.engineeredDrains(
		hf
	)}/{#Junction.drains(hf)}`
)
print(`ALL CHECKS PASSED ({passed} realism checks)`)
