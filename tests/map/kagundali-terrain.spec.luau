--!nocheck
-- needs: roblox-mock
-- Apply the actual bounded migration to a saved highland-4 chunk with deliberate edits.
local Layout = load("ReplicatedStorage/Shared/Config/MapLayout")
local Heightfield = load("StudioTools/Map/Heightfield")
local hf = Heightfield.new(Layout)
local feature = load("StudioTools/Map/JunctionLandscape").decorate(hf, Layout)
local Upgrade = load("StudioTools/Map/Builders/TerrainUpgrade")
local passed = 0
local function check(ok, label)
	assert(ok, label)
	passed += 1
	print("PASS " .. label)
end
local function exercise(baseline, bounds, editedX, editedZ, minimum)
	local hf = baseline
	local columns, lowest = {}, math.huge
	for x = 1, 16 do
		columns[x] = {}
		for z = 1, 16 do
			local px, pz = bounds.MinX + x * 4 - 2, bounds.MinZ + z * 4 - 2
			local y, code, water = hf.surface(px, pz)
			local dx, dz =
				(hf.surface(px + 4, pz) - hf.surface(px - 4, pz)) / 8,
				(hf.surface(px, pz + 4) - hf.surface(px, pz - 4)) / 8
			if code <= 0 then
				code = hf.naturalMaterial(y, math.sqrt(dx * dx + dz * dz), px, pz, code)
			end
			columns[x][z] = { Height = y, Material = Enum.Material[Heightfield.Materials[code]], Water = water }
			lowest = math.min(lowest, y)
		end
	end
	local saved = {}
	for x = 1, 16 do
		saved[x] = {}
		for z = 1, 16 do
			local column = columns[x][z]
			column.RockBelow = math.max(0, math.floor((lowest - 8) / 4) * 4)
			local materials, occupancy = Upgrade.voxelize(column, 0, 128)
			saved[x][z] = { materials, occupancy }
		end
	end
	local top = math.ceil(columns[editedX][editedZ].Height / 4)
	while saved[editedX][editedZ][2][top] < 0.05 do
		top -= 1
	end -- paint an occupied voxel, not quantized air
	saved[editedX][editedZ][1][top] = Enum.Material.Slate -- a manually painted surface must survive
	local writes = 0
	local backend = {}
	function backend:ReadVoxels(region, resolution)
		assert(resolution == 4 and region.Min.X == bounds.MinX and region.Max.Z == bounds.MaxZ)
		local materials, occupancy = {}, {}
		for x = 1, 16 do
			materials[x], occupancy[x] = {}, {}
			for y = region.Min.Y / 4 + 1, region.Max.Y / 4 do
				local iy = y - region.Min.Y / 4
				materials[x][iy], occupancy[x][iy] = {}, {}
				for z = 1, 16 do
					materials[x][iy][z], occupancy[x][iy][z] = saved[x][z][1][y], saved[x][z][2][y]
				end
			end
		end
		return materials, occupancy
	end
	function backend:WriteVoxels(region, resolution, materials, occupancy)
		writes += 1
		assert(
			resolution == 4
				and region.Min.X == bounds.MinX
				and region.Max.X == bounds.MaxX
				and region.Min.Z == bounds.MinZ
				and region.Max.Z == bounds.MaxZ
		)
		for x = 1, 16 do
			for y = region.Min.Y / 4 + 1, region.Max.Y / 4 do
				for z = 1, 16 do
					saved[x][z][1][y], saved[x][z][2][y] =
						materials[x][y - region.Min.Y / 4][z], occupancy[x][y - region.Min.Y / 4][z]
				end
			end
		end
	end
	local options = {
		Bounds = bounds,
		Terrain = backend,
		Yield = function() end,
		Protected = function(x, z)
			return x == bounds.MinX + (editedX + 1) * 4 - 2 and z == bounds.MinZ + editedZ * 4 - 2
		end,
	}
	local dryOptions = table.clone(options)
	dryOptions.DryRun = true
	local dry = Upgrade.apply(feature, Layout, function() end, dryOptions)
	check(
		dry.Complete and dry.EligibleColumns > minimum and writes == 0,
		"local dry run recognizes saved baseline columns without writing"
	)
	local applied = Upgrade.apply(feature, Layout, function() end, options)
	check(
		applied.Complete and applied.ChangedColumns > minimum and writes == 1,
		"regional terrain writes change the actual matched saved chunk"
	)
	check(
		applied.PreservedColumns == 2 and saved[editedX][editedZ][1][top] == Enum.Material.Slate,
		"painted ground and a protected building footprint survive the regional patch"
	)
	local repeated = Upgrade.apply(feature, Layout, function() end, options)
	check(
		repeated.Complete and repeated.ChangedColumns == 0 and repeated.AlreadyCurrentColumns > minimum and writes == 1,
		"reapplying the regional patch recognizes current terrain without new writes"
	)
end
exercise(hf, { MinX = 192, MaxX = 256, MinZ = 3392, MaxZ = 3456 }, 1, 1, 100)
exercise(
	load("StudioTools/Map/JunctionLandscape").decorateV1(hf.highland4, Layout),
	{ MinX = 192, MaxX = 256, MinZ = 3328, MaxZ = 3392 },
	14,
	3,
	20
)
exercise(
	load("StudioTools/Map/JunctionLandscape").decorateV2(hf.highland4, Layout),
	{ MinX = 320, MaxX = 384, MinZ = 3264, MaxZ = 3328 },
	6,
	15,
	10
)
exercise(
	load("StudioTools/Map/JunctionLandscape").decorateV4(hf.highland4, Layout),
	{ MinX = 128, MaxX = 192, MinZ = 3072, MaxZ = 3136 },
	6,
	8,
	10
)
print(`ALL CHECKS PASSED ({passed} Kagundali terrain checks)`)
