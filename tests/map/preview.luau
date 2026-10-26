--!strict
-- Prints the finished terrain on a coarse grid for tests/map/preview.py.
-- Output: a header line, then one line per grid row with "height,material,water" per column.

local MapLayout = load("ReplicatedStorage/Shared/Config/MapLayout")
local Heightfield = load("StudioTools/Map/Heightfield")
local RoadDetails = load("StudioTools/Map/RoadDetails")
local Vegetation = load("StudioTools/Map/Vegetation")

local step = 16
local half = MapLayout.Bounds.Half
local hf = Heightfield.new(MapLayout)
local n = math.floor(2 * half / step) + 1
local heights: { number } = table.create(n * n)
local materials: { number } = table.create(n * n)
local waters: { number } = table.create(n * n)
for iz = 0, n - 1 do
	for ix = 0, n - 1 do
		local h, m, w = hf.surface(-half + ix * step, -half + iz * step)
		local i = iz * n + ix + 1
		heights[i], materials[i], waters[i] = h, m, w or -1
	end
end
print(`GRID {n} {step} {half}`)
local rows = table.create(n)
for iz = 0, n - 1 do
	local cells = table.create(n)
	for ix = 0, n - 1 do
		local i = iz * n + ix + 1
		local m = materials[i]
		if m <= 0 then
			local e = heights[iz * n + math.min(ix + 1, n - 1) + 1]
			local w = heights[iz * n + math.max(ix - 1, 0) + 1]
			local s = heights[math.min(iz + 1, n - 1) * n + ix + 1]
			local no = heights[math.max(iz - 1, 0) * n + ix + 1]
			local slope = math.sqrt(((e - w) / (2 * step)) ^ 2 + ((s - no) / (2 * step)) ^ 2)
			m = hf.naturalMaterial(heights[i], slope, -half + ix * step, -half + iz * step, m)
		end
		cells[ix + 1] = string.format("%.1f,%d,%.1f", heights[i], m, waters[i])
	end
	rows[iz + 1] = table.concat(cells, " ")
end
print(table.concat(rows, "\n"))
-- Roads and bridges for the overlay.
for _, road in hf.roads.roads do
	local pts = {}
	for i = 1, #road.line.xs, 4 do
		table.insert(pts, string.format("%.0f,%.0f", road.line.xs[i], road.line.zs[i]))
	end
	table.insert(pts, string.format("%.0f,%.0f", road.line.xs[#road.line.xs], road.line.zs[#road.line.zs]))
	print(`ROAD {road.Id} {road.Class} {table.concat(pts, " ")}`)
end
for _, b in hf.roads.bridges do
	print(string.format("BRIDGE %s %.0f %.0f", b.Road, b.CrossX, b.CrossZ))
end
for _, place in MapLayout.Places do
	local r = place.Rect
	print(string.format("PLACE %s %.0f %.0f %s", place.Kind, (r.MinX + r.MaxX) / 2, (r.MinZ + r.MaxZ) / 2, place.Name))
end
local function rectLine(kind: string, r: any)
	print(string.format("RECT %s %.0f %.0f %.0f %.0f", kind, r.MinX, r.MaxX, r.MinZ, r.MaxZ))
end
rectLine("Runway", MapLayout.Airport.Runway)
rectLine("Runway", MapLayout.Airport.Taxiway)
rectLine("Apron", MapLayout.Airport.Apron)
for _, block in MapLayout.GundivillePlaceholders do
	rectLine("Block", block.Rect)
end
for _, property in MapLayout.Properties do
	rectLine("Plot", property.Rect)
end
-- Fields, barns and trees.
for _, field in hf.fields.list do
	print(string.format("FIELD %s %.0f %.0f %.0f %.0f", field.Crop, field.MinX, field.MaxX, field.MinZ, field.MaxZ))
end
for _, barn in hf.fields.barns do
	print(string.format("BARN %.0f %.0f", barn.X, barn.Z))
end
local plants = Vegetation.new(MapLayout, hf, RoadDetails.new(MapLayout, hf))
local trees = table.create(#plants.trees)
for _, t in plants.trees do
	table.insert(trees, string.format("%s,%.0f,%.0f,%.0f", string.sub(t.Kind, 1, 1), t.X, t.Z, t.Size))
end
print("TREES " .. table.concat(trees, " "))
