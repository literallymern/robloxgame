--!strict
-- Frozen reference samples taken by executing the exact Heightfield and River sources at
-- d3edcc7836d478960b26f74f8afde6709a50baed, before the environment overhaul. This prevents a
-- saved original-map baseline from accidentally drifting into the newer terrain model.
local Heightfield = load("StudioTools/Map/Heightfield")
local Layout = load("ReplicatedStorage/Shared/Config/MapLayout")
local hf = Heightfield.new(Layout)
local failures = 0
local function check(name: string, ok: boolean, detail: string?)
	print(if ok then "PASS" else "FAIL", name, detail or "")
	if not ok then
		failures += 1
	end
end
local golden: { { any } } = {
	-- X, Z, original height, material hint, original water level or false, resolved material.
	{ 195, 780, 60, 6, false, 6 },
	{ 0, 0, 60, 6, false, 6 },
	{ 1206, 185, 39.006585879873548, 9, 48, 9 },
	{ -3000, -2300, 100, 6, false, 6 },
	{ 2400, -2800, 180, 6, false, 6 },
	{ 4900, 250, 59.399999999999999, 7, false, 7 },
	{ 500, 4900, 49.399999999999999, 7, false, 7 },
	{ -1600, -2000, 298.29620533364726, 0, false, 4 },
	{ 4800, -4800, 804.61350045671713, 0, false, 9 },
	{ 1000, -4380, 494.54011729538831, 9, 500, 9 },
	-- Negative waterside hints exercise the original material dispatch, beside the lake.
	{ 977, -4425, 496.69542379947751, -1, false, 2 },
	{ 1014, -4425, 504.18361764317558, -1, false, 1 },
	{ 977, -4388, 497.53250719569536, -1, false, 2 },
	{ 977, -4351, 498.05137456179023, -1, false, 2 },
	{ -1450, 5000, 25.975304968759271, 8, 32, 8 },
	{ -1350, -850, 79.190738733183011, 7, false, 7 },
	{ -2200, 340, 77.84018234977512, 0, false, 2 },
	{ 1780, 1380, 62.056790591758634, 0, false, 1 },
	{ -3900, 4000, 132.67185080606657, 0, false, 4 },
	{ 4000, 3900, 66.808236247897526, 0, false, 1 },
}
check(
	"original terrain: independent pre-overhaul samplers are exposed",
	type(hf.originalSurface) == "function" and type(hf.originalNaturalMaterial) == "function"
)
local heights, materials = true, true
for _, p in golden do
	local h, code, water = hf.originalSurface(p[1], p[2])
	local expectedWater = if p[5] == false then nil else p[5]
	heights = heights and math.abs(h - p[3]) < 1e-9 and code == p[4] and water == expectedWater
	local hx = hf.originalSurface(p[1] + 4, p[2])
	local hz = hf.originalSurface(p[1], p[2] + 4)
	local slope = math.sqrt(((hx - h) / 4) ^ 2 + ((hz - h) / 4) ^ 2)
	local material = if code <= 0 then hf.originalNaturalMaterial(h, slope, p[1], p[2], code) else code
	materials = materials and material == p[6]
end
check("original terrain: historical heights, hints and water match golden references", heights)
check("original terrain: historical voxel-slope materials match golden references", materials)

local swales, correctSwales = 0, true
for _, road in hf.roads.roads do
	local line = road.line
	for i = 2, #line.xs - 1, 45 do
		local dx, dz = line.xs[i + 1] - line.xs[i], line.zs[i + 1] - line.zs[i]
		local length = math.sqrt(dx * dx + dz * dz)
		local offset = road.Width / 2 + 7.5
		local x, z = line.xs[i] - dz / length * offset, line.zs[i] + dx / length * offset
		local original, _, oldWater = hf.originalSurface(x, z)
		local middle, _, middleWater = hf.legacySurface(x, z)
		local current, _, currentWater = hf.surface(x, z)
		if oldWater == nil and middleWater == nil and hf.reliefMask(x, z) == 0 and original - middle > 0.1 then
			swales += 1
			correctSwales = correctSwales
				and math.abs(current - middle) < 1e-9
				and currentWater == nil
				and original - current <= 0.650001
		end
	end
end
check(
	"original terrain: original saved roadsides expose previously unapplied drainage changes",
	correctSwales and swales > 30,
	tostring(swales)
)

local river = hf.river
local changedBanks, changedBeds = 0, 0
local waterUnchanged = true
for i = 2, #river.line.xs - 1, 9 do
	local dx, dz = river.line.xs[i + 1] - river.line.xs[i], river.line.zs[i + 1] - river.line.zs[i]
	local length = math.sqrt(dx * dx + dz * dz)
	for _, across in { 0.25, 0.8, 1.15, 1.5, 2.1 } do
		local offset = river.halfWidths[i] * across
		local x = river.line.xs[i] - dz / length * offset
		local z = river.line.zs[i] + dx / length * offset
		local old, oldCode, oldWater = hf.originalSurface(x, z)
		local current, code, water = hf.surface(x, z)
		waterUnchanged = waterUnchanged and oldWater == water
		if oldWater ~= nil and math.abs(current - old) > 0.001 then
			changedBeds += 1
		end
		if oldWater == nil and (math.abs(current - old) > 0.001 or oldCode ~= code) then
			changedBanks += 1
		end
	end
end
check(
	"original terrain: original river beds and banks differ from the revised profiles",
	changedBeds > 100 and changedBanks > 100,
	`{changedBeds} beds, {changedBanks} banks`
)
check("original terrain: historical and revised river models retain the same water levels", waterUnchanged)

local changedSoil = 0
for z = -4000, 4000, 160 do
	for x = -4000, 4000, 160 do
		if hf.originalNaturalMaterial(300, 0.65, x, z, 0) ~= hf.legacyNaturalMaterial(300, 0.65, x, z, 0) then
			changedSoil += 1
		end
	end
end
check(
	"original terrain: original erosion/soil thresholds are distinct migration inputs",
	changedSoil > 100,
	tostring(changedSoil)
)
print(
	`INFO original baseline: {#golden} independent reference points; {swales} drainage changes; {changedBeds} bed changes; {changedBanks} bank changes; {changedSoil} soil changes`
)
if failures > 0 then
	error(`{failures} original baseline check(s) failed`)
end
print("ALL CHECKS PASSED")
