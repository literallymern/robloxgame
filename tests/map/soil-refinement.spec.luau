--!strict
-- Reference-driven material coverage and saved highland-3 baseline checks, outside Studio.
local Heightfield = load("StudioTools/Map/Heightfield")
local Layout = load("ReplicatedStorage/Shared/Config/MapLayout")
local hf = Heightfield.new(Layout)
local failures, checks = 0, 0
local function check(name: string, ok: boolean)
	checks += 1
	print(if ok then "PASS" else "FAIL", name)
	if not ok then
		failures += 1
	end
end
-- Executed independently from the exact d82b349 highland-3 Heightfield source.
-- X/Z, original height, central-difference slope, original natural material code.
local golden = {
	{ 1528, -4424, 499.32782399505192, 0.25607042186800411, 4 },
	{ -8, -4360, 363.63984784442459, 0.070402685534662862, 4 },
	{ 1720, -4360, 477.24791002489707, 0.27732356354523813, 4 },
	{ 1976, -4360, 408.04917820410128, 0.081635922307125852, 4 },
	{ 2168, -4360, 385.23866175825594, 0.22842169329224848, 4 },
	{ -520, -4296, 419.29059523265738, 0.27969384411701237, 4 },
	{ -4232, -4232, 157.50395040199771, 0.20286088578377331, 4 },
	{ -2120, -4232, 405.57327485630947, 0.22876704739636963, 4 },
	{ -648, -4232, 451.90363793367999, 0.09823247516720901, 4 },
	{ -200, -4232, 364.58605372027546, 0.2608221478453191, 4 },
	{ -136, -4232, 376.68440114784244, 0.13819334356029708, 4 },
	{ -3976, -4168, 148.60048487018329, 0.15549486445637442, 4 },
	{ -3720, -4168, 144.68378650117327, 0.16507524280746944, 4 },
	{ -2696, -4168, 126.93981740554798, 0.25376147638352309, 4 },
	{ -584, -4168, 457.97467179357284, 0.21507890057604298, 4 },
	{ 1464, -4168, 383.98634237702225, 0.041296655435682048, 4 },
}
local parity = true
for _, p in golden do
	local h, c = hf.previousSurface(p[1], p[2])
	parity = parity and math.abs(h - p[3]) < 1e-9 and hf.previousNaturalMaterial(h, p[4], p[1], p[2], c) == p[5]
end
check("soil: frozen highland-3 samples retain exact heights and soil decisions", parity)
local sampleCount, gentle, previousBare, newBare, changed, exposedSlopes = 0, 0, 0, 0, 0, 0
local protectedSame, mountainsSame, geometrySame = true, true, true
for z = -5000, 5000, 64 do
	for x = -5000, 5000, 64 do
		local h, c, w = hf.surface(x, z)
		local oldH, oldC, oldW = hf.previousSurface(x, z)
		geometrySame = geometrySame and h == oldH and c == oldC and w == oldW
		local dx = (hf.surface(x + 4, z) - hf.surface(x - 4, z)) / 8
		local dz = (hf.surface(x, z + 4) - hf.surface(x, z - 4)) / 8
		local slope = math.sqrt(dx * dx + dz * dz)
		local a = hf.previousNaturalMaterial(h, slope, x, z, c)
		local b = hf.naturalMaterial(h, slope, x, z, c)
		local mask = hf.reliefMask(x, z)
		sampleCount += 1
		if mask < 0.08 or c == -1 then
			protectedSame = protectedSame and a == b
		end
		if h > 520 or a == 3 or a == 9 or a == 10 then
			mountainsSame = mountainsSame and a == b
		end
		if c <= 0 and w == nil and mask > 0.45 and h < 520 then
			if a ~= b then
				changed += 1
			end
			if slope < 0.28 then
				gentle += 1
				if a == 4 or a == 5 then
					previousBare += 1
				end
				if b == 4 or b == 5 then
					newBare += 1
				end
			elseif b == 4 then
				exposedSlopes += 1
			end
		end
	end
end
check(
	"soil: every sampled elevation, material hint and water level remains unchanged",
	geometrySame and sampleCount > 24000
)
check("soil: settlement, field, road and bank protection retains existing materials", protectedSame)
check("soil: mountain and rock outcrops retain existing material decisions", mountainsSame)
check("soil: gentle open highland cover is predominantly green", gentle > 6000 and newBare / gentle < 0.05)
check(
	"soil: repetitive gentle-ground exposure drops materially from reference",
	previousBare > 2000 and newBare < previousBare * 0.2
)
check(
	"soil: eroding slopes retain bare earth instead of uniformly painting everything green",
	exposedSlopes > 100 and changed > 2000
)
print(
	`INFO soil: {sampleCount} surface samples; {gentle} gentle natural points; bare soil/mud {previousBare} -> {newBare}; {exposedSlopes} exposed slopes; {changed} material changes`
)
if failures > 0 then
	error(`{failures} soil refinement checks failed`)
end
print(`ALL CHECKS PASSED ({checks} soil refinement checks)`)
