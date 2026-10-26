--!strict
--!native
-- Writes the terrain of the whole map from the heightfield, in chunks of 64 x 64 studs.
-- For each chunk only a band around the surface is written voxel by voxel; everything below
-- the band is filled as solid rock in one call. Water is written where the river runs.

local Heightfield = require(script.Parent.Parent.Heightfield)
local Util = require(script.Parent.Util)

local TerrainBuilder = {}

local RES = 4 -- voxel size in studs
local CHUNK = 64
local COLS = CHUNK // RES -- columns per chunk side

function TerrainBuilder.build(hf: Heightfield.Heightfield, layout: any, log: (string) -> ())
	local terrain = workspace.Terrain
	local half: number = layout.Bounds.Half
	local floorY: number = layout.Bounds.FloorY
	local surface = hf.surface
	local naturalMaterial = hf.naturalMaterial

	local enumByCode: { Enum.Material } = {}
	for code, name in Heightfield.Materials do
		enumByCode[code] = (Enum.Material :: any)[name]
	end
	local AIR = Enum.Material.Air
	local WATER = Enum.Material.Water

	terrain:Clear()
	log("Old terrain cleared. Writing new terrain...")

	local columns = math.floor(2 * half / RES) -- per strip, plus one border column on each side
	local width = columns + 2
	local rows = COLS + 2
	local heights: { number } = table.create(width * rows, 0)
	local codes: { number } = table.create(width * rows, 0)
	local waters: { number } = table.create(width * rows, -1)
	local strips = math.floor(2 * half / CHUNK)
	local started = os.clock()

	for strip = 0, strips - 1 do
		local z0 = -half + strip * CHUNK
		-- Sample the strip plus one border row/column for slopes.
		for r = 0, rows - 1 do
			local z = z0 + (r - 1) * RES + RES / 2
			local base = r * width
			for c = 0, width - 1 do
				local h, code, water = surface(-half + (c - 1) * RES + RES / 2, z)
				local i = base + c + 1
				heights[i] = h
				codes[i] = code
				waters[i] = water or -1
			end
			Util.yield()
		end

		for chunk = 0, strips - 1 do
			local x0 = -half + chunk * CHUNK
			local c0 = chunk * COLS + 1 -- first column of the chunk (border column is 0)
			local lowest, highest = math.huge, -math.huge
			for r = 1, COLS do
				local base = r * width
				for c = c0, c0 + COLS - 1 do
					local i = base + c + 1
					local h = heights[i]
					local top = math.max(h, waters[i])
					if h < lowest then
						lowest = h
					end
					if top > highest then
						highest = top
					end
				end
			end
			local bottom = math.max(floorY, math.floor((lowest - 8) / RES) * RES)
			local top = math.ceil((highest + 2) / RES) * RES
			if bottom > floorY then
				terrain:FillBlock(
					CFrame.new(x0 + CHUNK / 2, (floorY + bottom) / 2, z0 + CHUNK / 2),
					Vector3.new(CHUNK, bottom - floorY, CHUNK),
					Enum.Material.Rock
				)
			end
			local cells = (top - bottom) // RES
			local materials = table.create(COLS)
			local occupancy = table.create(COLS)
			for cx = 1, COLS do
				local matX = table.create(cells)
				local occX = table.create(cells)
				for cy = 1, cells do
					matX[cy] = table.create(COLS, AIR)
					occX[cy] = table.create(COLS, 0)
				end
				materials[cx] = matX
				occupancy[cx] = occX
			end
			for cz = 1, COLS do
				local r = cz
				local base = r * width
				for cx = 1, COLS do
					local c = c0 + cx - 1
					local i = base + c + 1
					local h = heights[i]
					local code = codes[i]
					if code == 0 then
						local dx = (heights[i + 1] - heights[i - 1]) / (2 * RES)
						local dz = (heights[i + width] - heights[i - width]) / (2 * RES)
						code =
							naturalMaterial(h, math.sqrt(dx * dx + dz * dz), x0 + (cx - 1) * RES, z0 + (cz - 1) * RES)
					end
					local material = enumByCode[code]
					local water = waters[i]
					local matX, occX = materials[cx], occupancy[cx]
					for cy = 1, cells do
						local yb = bottom + (cy - 1) * RES
						local solid = (h - yb) / RES
						if water > yb + RES / 2 then
							-- Below the water surface: solid or water, no air pockets.
							if solid >= 0.5 then
								matX[cy][cz] = material
								occX[cy][cz] = 1
							else
								matX[cy][cz] = WATER
								occX[cy][cz] = 1
							end
						elseif solid > 0 then
							matX[cy][cz] = material
							occX[cy][cz] = if solid > 1 then 1 else solid
						elseif water > yb then
							matX[cy][cz] = WATER
							occX[cy][cz] = (water - yb) / RES
						else
							break
						end
					end
				end
			end
			terrain:WriteVoxels(
				Region3.new(Vector3.new(x0, bottom, z0), Vector3.new(x0 + CHUNK, top, z0 + CHUNK)),
				RES,
				materials,
				occupancy
			)
			Util.yield()
		end

		if strip % 16 == 15 then
			local done = (strip + 1) / strips
			local elapsed = os.clock() - started
			log(
				string.format(
					"Terrain %d %% (%.0f s, about %.0f s left)",
					done * 100,
					elapsed,
					elapsed / done - elapsed
				)
			)
		end
	end
end

return TerrainBuilder
