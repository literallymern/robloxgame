--!strict
-- Frozen highland-3/4 relief remains exact for saved-map migration. The active rework is
-- covered by realism.spec.luau. Neither suite establishes Roblox Studio visual acceptance.
local Heightfield = load("StudioTools/Map/Heightfield")
local Layout = load("ReplicatedStorage/Shared/Config/MapLayout")
local Config = load("StudioTools/Map/LandscapeConfig")
local hf = Heightfield.new(Layout).highland4
local failures = 0
local function check(name: string, ok: boolean, detail: string?)
	print(if ok then "PASS" else "FAIL", name, detail or "")
	if not ok then
		failures += 1
	end
end
local function sameSurface(x: number, z: number): boolean
	local h, code, water = hf.surface(x, z)
	local oldH, oldCode, oldWater = hf.legacySurface(x, z)
	return h == oldH and code == oldCode and water == oldWater
end

check(
	"highland: exact legacy surface and material models remain available",
	type(hf.legacySurface) == "function" and type(hf.legacyNaturalMaterial) == "function"
)
local roadsUnchanged, roadSamples = true, 0
for _, road in hf.roads.roads do
	for i = 1, #road.line.xs, 17 do
		local x, z = road.line.xs[i], road.line.zs[i]
		roadsUnchanged = roadsUnchanged and sameSurface(x, z) and hf.reliefMask(x, z) == 0
		roadSamples += 1
	end
end
check(
	"highland: every sampled carriageway and bridge profile is unchanged",
	roadsUnchanged and roadSamples > 100,
	tostring(roadSamples)
)

local placesUnchanged = true
for _, place in Layout.Places do
	local r = place.Rect
	for _, p in { { r.MinX, r.MinZ }, { r.MaxX, r.MaxZ }, { (r.MinX + r.MaxX) / 2, (r.MinZ + r.MaxZ) / 2 } } do
		placesUnchanged = placesUnchanged and sameSurface(p[1], p[2]) and hf.reliefMask(p[1], p[2]) == 0
	end
end
check("highland: all settlement, property and airport place anchors stay unchanged", placesUnchanged)

local fieldsUnchanged = true
for _, field in hf.fields.list do
	for _, p in
		{
			{ field.MinX, field.MinZ },
			{ field.MaxX, field.MaxZ },
			{ (field.MinX + field.MaxX) / 2, (field.MinZ + field.MaxZ) / 2 },
		}
	do
		fieldsUnchanged = fieldsUnchanged and sameSurface(p[1], p[2]) and hf.reliefMask(p[1], p[2]) == 0
	end
end
check("highland: crop fields, barn yards and fence edges stay unchanged", fieldsUnchanged and #hf.fields.list > 100)

local changed, materialChanges, waterSamples = 0, 0, 0
local positive, negative, maxDelta, worstGradient = 0, 0, 0, 0
local worstAt = ""
local finite, waterUnchanged, masksValid, floorValid = true, true, true, true
local sameProtection = true
for z = -Layout.Bounds.Half + 2, Layout.Bounds.Half - 2, 64 do
	for x = -Layout.Bounds.Half + 2, Layout.Bounds.Half - 2, 64 do
		local h, code, water = hf.surface(x, z)
		local old, oldCode, oldWater = hf.legacySurface(x, z)
		local delta = h - old
		local mask = hf.reliefMask(x, z)
		masksValid = masksValid and mask >= 0 and mask <= 1
		finite = finite and h == h and math.abs(h) < math.huge
		floorValid = floorValid and h >= Layout.Bounds.FloorY
		maxDelta = math.max(maxDelta, math.abs(delta))
		if math.abs(delta) > 1 then
			changed += 1
		end
		if delta > 3 then
			positive += 1
		end
		if delta < -3 then
			negative += 1
		end
		if mask == 0 then
			sameProtection = sameProtection and h == old
		end
		waterUnchanged = waterUnchanged and water == oldWater
		if oldWater ~= nil then
			waterSamples += 1
			waterUnchanged = waterUnchanged and h == old and code == oldCode
		end
		-- The added relief itself must remain smooth at the actual terrain voxel spacing.
		local newX = hf.surface(x + 4, z)
		local oldX = hf.legacySurface(x + 4, z)
		local newZ = hf.surface(x, z + 4)
		local oldZ = hf.legacySurface(x, z + 4)
		local gradient = math.max(math.abs((newX - oldX) - delta) / 4, math.abs((newZ - oldZ) - delta) / 4)
		if gradient > worstGradient then
			worstGradient, worstAt = gradient, `{x},{z}`
		end
		if code <= 0 and oldCode <= 0 and mask > 0.2 then
			local slope = math.sqrt(((newX - h) / 4) ^ 2 + ((newZ - h) / 4) ^ 2)
			local oldSlope = math.sqrt(((oldX - old) / 4) ^ 2 + ((oldZ - old) / 4) ^ 2)
			if hf.naturalMaterial(h, slope, x, z, code) ~= hf.legacyNaturalMaterial(old, oldSlope, x, z, oldCode) then
				materialChanges += 1
			end
		end
	end
end
check(
	"highland: new relief contains both ridges and drainage folds at meaningful scale",
	changed > 2500 and positive > 500 and negative > 100,
	`{changed} changed, {positive} ridges, {negative} folds`
)
check(
	"highland: relief never exceeds the configured height budget",
	maxDelta <= Config.ReliefAmplitude + 1e-8,
	tostring(maxDelta)
)
check(
	"highland: added relief is smooth across four-stud terrain columns",
	worstGradient < 0.55,
	`{worstGradient} at {worstAt}`
)
check("highland: protected corridor samples retain the exact old surface", sameProtection)
check(
	"highland: river and lake levels and submerged beds remain unchanged",
	waterUnchanged and waterSamples > 100,
	tostring(waterSamples)
)
check(
	"highland: finite heights, valid masks and no terrain below the world floor",
	finite and masksValid and floorValid
)
check(
	"highland: natural ground gains actual material variation outside protected works",
	materialChanges > 500,
	tostring(materialChanges)
)

local again = Heightfield.new(Layout).highland4
local deterministic = true
for _, p in { { -2110, -1700 }, { 1450, 2210 }, { 3900, -3710 }, { 4000, 3900 }, { -3700, 2800 } } do
	local a, m, w = hf.surface(p[1], p[2])
	local b, n, v = again.surface(p[1], p[2])
	deterministic = deterministic and a == b and m == n and w == v
end
check("highland: repeated builds produce the same revised surface", deterministic)
print(
	`INFO {changed} changed terrain samples; {materialChanges} material changes; maximum relief {maxDelta}; four-stud gradient {worstGradient}`
)
if failures > 0 then
	error(`{failures} highland check(s) failed`)
end
print("ALL CHECKS PASSED")
