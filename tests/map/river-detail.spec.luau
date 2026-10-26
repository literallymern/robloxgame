--!strict
-- Pure geometry checks: run with tests/map/run.py, no Studio claims.
local River = load("StudioTools/Map/River")
local Heightfield = load("StudioTools/Map/Heightfield")
local MapLayout = load("ReplicatedStorage/Shared/Config/MapLayout")
local failures = 0
local function check(name: string, ok: boolean)
	print(if ok then "PASS" else "FAIL", name)
	if not ok then
		failures += 1
	end
end

-- A straight fixture isolates the channel profile from neighbouring bends and land clamps.
local river = River.new({
	River = {
		Points = { { 0, 0 }, { 1000, 0 } },
		Width = 40,
		BankWidth = 20,
		Depth = 8,
		DropBelowLand = 20,
		WallSlope = 0.75,
		RoadClearance = 14,
	},
}, function()
	return 100
end)
local previous = -math.huge
local monotonic, dryBank, wetBed = true, true, true
for i = 1, 399 do
	local z = i / 10
	local h, water = river.carve(500, z, 1000)
	monotonic = monotonic and h >= previous
	previous = h
	if z < 20 then
		wetBed = wetBed and water == 80 and h < 80
	elseif z > 20 then
		dryBank = dryBank and water == nil and h > 80
	end
end
check("river detail: monotonic cross section without holes or raised sediment dams", monotonic)
check("river detail: bed stays submerged and bank stays above unchanged water level", wetBed and dryBank)
local upperBank = river.carve(500, 40, 1000)
check("river detail: upper bank meets the original valley profile", math.abs(upperBank - 100) < 1e-6)
local far = river.carve(500, 261, 177)
check("river detail: terrain outside the channel reach stays unchanged", far == 177)

local hf = Heightfield.new(MapLayout)
local checked = 0
local valid = true
local function insidePlace(x: number, z: number): boolean
	for _, place in MapLayout.Places do
		local r = place.Rect
		if x >= r.MinX and x <= r.MaxX and z >= r.MinZ and z <= r.MaxZ then
			return true
		end
	end
	return false
end
for _, road in hf.roads.roads do
	for i = 2, #road.line.xs - 1, 45 do
		local line = road.line
		local dx, dz = line.xs[i + 1] - line.xs[i], line.zs[i + 1] - line.zs[i]
		local len = math.sqrt(dx * dx + dz * dz)
		for _, edge in { 5.1, 7.5, 9.9 } do
			local offset = road.Width / 2 + edge
			local x, z = line.xs[i] - dz / len * offset, line.zs[i] + dx / len * offset
			local e, roadY, index, bridge = hf.roads.nearest(x, z)
			if
				e == nil
				or e <= 5
				or e >= 10
				or bridge
				or insidePlace(x, z)
				or hf.roads.otherDistance(x, z, index) <= 12
				or hf.river.nearest(x, z) < hf.river.reach
				or hf.lakes.shoreDistance(x, z) < 160
			then
				continue
			end
			local bed = roadY - 0.6
			local k = 0.75 * (e - 2)
			local uncut = math.clamp(hf.land.height(x, z), bed - k, bed + k)
			local h = hf.surface(x, z)
			local depth = 0.65 * math.sin(math.pi * (e - 5) / 5) ^ 2
			valid = valid and math.abs(h - (uncut - depth)) < 1e-6 and depth <= 0.65
			checked += 1
		end
	end
end
check("drainage: sampled rural swales stay smooth and at most 0.65 studs deep", valid and checked > 100)
print(`INFO checked {checked} rural drainage points`)
if failures > 0 then
	error(`{failures} check(s) failed`)
end
print("ALL CHECKS PASSED")
