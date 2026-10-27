--!strict
--!native
-- Upgrades a SAVED generated landscape without clearing it. A whole surface column must
-- match the known previous generator before it may change. Sculpted/painted columns are
-- retained. Read/write batches are 64 x 64 studs, matching the original terrain builder.
-- Writes are incremental: an engine failure can leave earlier chunks upgraded. The report
-- says so, and a later run safely resumes because already-upgraded columns are recognized.

local Heightfield = require(script.Parent.Parent.Heightfield)
local Util = require(script.Parent.Util)

local Upgrade = {}
local RES = 4
local CHUNK = 64
local COLS = CHUNK // RES
local TOLERANCE = 0.006 -- permits 8-bit occupancy quantization, not visible sculpt changes

export type Column = {
	Height: number,
	Material: any,
	Water: number?,
	RockBelow: number,
}

export type Bounds = { MinX: number, MaxX: number, MinZ: number, MaxZ: number }
export type Options = {
	DryRun: boolean?,
	Bounds: Bounds?,
	Terrain: any?, -- backend injection for offline tests; normally Workspace.Terrain
	Yield: (() -> ())?,
	Protected: ((x: number, z: number) -> boolean)?, -- custom-building footprints, supplied by the Studio tool
}

export type Report = {
	Complete: boolean,
	DryRun: boolean,
	Error: string?,
	ChunksRead: number,
	ChunksWritten: number,
	EligibleColumns: number,
	ChangedColumns: number,
	ChangedVoxels: number,
	OriginalColumns: number, -- written columns matching the pre-overhaul generator, not v2
	PreservedColumns: number,
	AlreadyCurrentColumns: number,
	UnchangedColumns: number,
	WaterMismatches: number,
}

type Grid = { Heights: { number }, Codes: { number }, Waters: { number }, Width: number }

local function finite(value: number): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

-- The exact original TerrainBuilder voxelization, including its solid deep-rock fill.
-- Optional value tokens keep this useful in pure offline tests without Roblox globals.
function Upgrade.voxelize(column: Column, bottom: number, top: number, tokens: any?): ({ any }, { number })
	assert(bottom % RES == 0 and top % RES == 0 and top > bottom, "Voxel band must align to 4 studs")
	assert(finite(column.Height) and finite(column.RockBelow), "Invalid terrain height")
	assert(column.Water == nil or finite(column.Water), "Invalid water height")
	local material = tokens or { Air = Enum.Material.Air, Water = Enum.Material.Water, Rock = Enum.Material.Rock }
	local count = (top - bottom) // RES
	local mats: { any } = table.create(count, material.Air)
	local occ: { number } = table.create(count, 0)
	local water = column.Water or -math.huge
	for i = 1, count do
		local y = bottom + (i - 1) * RES
		local solid = (column.Height - y) / RES
		if y < column.RockBelow then
			mats[i], occ[i] = material.Rock, 1
		elseif water > y + RES / 2 then
			mats[i], occ[i] = if solid >= 0.5 then column.Material else material.Water, 1
		elseif solid > 0 then
			mats[i], occ[i] = column.Material, math.min(1, solid)
		elseif water > y then
			mats[i], occ[i] = material.Water, (water - y) / RES
		end
	end
	return mats, occ
end

local function sameVoxel(actualMat: any, actualOcc: number, expectedMat: any, expectedOcc: number): boolean
	return math.abs(actualOcc - expectedOcc) <= TOLERANCE and (expectedOcc <= TOLERANCE or actualMat == expectedMat)
end

-- "preserve" includes paint changes, missing ground, extra ground and changed water.
function Upgrade.classify(
	actualMat: { any },
	actualOcc: { number },
	oldMat: { any },
	oldOcc: { number },
	newMat: { any },
	newOcc: { number },
	originalMat: { any }?,
	originalOcc: { number }?
): string
	assert(
		#actualMat == #oldMat and #actualOcc == #oldOcc and #newMat == #oldMat and #newOcc == #oldOcc,
		"Column lengths differ"
	)
	assert(
		(originalMat == nil and originalOcc == nil)
			or (originalMat ~= nil and originalOcc ~= nil and #originalMat == #oldMat and #originalOcc == #oldOcc),
		"Original column lengths differ"
	)
	local previous, current, original = true, true, originalMat ~= nil
	for i = 1, #oldMat do
		previous = previous and sameVoxel(actualMat[i], actualOcc[i], oldMat[i], oldOcc[i])
		current = current and sameVoxel(actualMat[i], actualOcc[i], newMat[i], newOcc[i])
		if originalMat and originalOcc then
			original = original and sameVoxel(actualMat[i], actualOcc[i], originalMat[i], originalOcc[i])
		end
	end
	return if current then "current" elseif previous then "upgrade" elseif original then "original" else "preserve"
end

local function strip(surface: any, minX: number, maxX: number, z0: number, yieldEvery: () -> ()): Grid
	local width = (maxX - minX) // RES + 2
	local heights, codes, waters =
		table.create(width * (COLS + 2)), table.create(width * (COLS + 2)), table.create(width * (COLS + 2))
	for row = 0, COLS + 1 do
		local z = z0 + (row - 1) * RES + RES / 2
		for col = 0, width - 1 do
			local x = minX + (col - 1) * RES + RES / 2
			local h, code, water = surface(x, z)
			assert(
				finite(h) and finite(code) and code % 1 == 0 and (water == nil or finite(water)),
				"Heightfield returned invalid terrain data"
			)
			local i = row * width + col + 1
			heights[i], codes[i], waters[i] = h, code, water or -math.huge
		end
		yieldEvery()
	end
	return { Heights = heights, Codes = codes, Waters = waters, Width = width }
end

local function sample(
	grid: Grid,
	i: number,
	x: number,
	z: number,
	choose: any,
	enumByCode: { any },
	rockBelow: number
): Column
	local h, code = grid.Heights[i], grid.Codes[i]
	if code <= 0 then
		local dx = (grid.Heights[i + 1] - grid.Heights[i - 1]) / (2 * RES)
		local dz = (grid.Heights[i + grid.Width] - grid.Heights[i - grid.Width]) / (2 * RES)
		code = choose(h, math.sqrt(dx * dx + dz * dz), x, z, code)
	end
	local material = enumByCode[code]
	assert(material ~= nil, `Unknown terrain material code {tostring(code)}`)
	return {
		Height = h,
		Material = material,
		Water = if grid.Waters[i] == -math.huge then nil else grid.Waters[i],
		RockBelow = rockBelow,
	}
end

function Upgrade.apply(hf: any, layout: any, log: (string) -> (), options: Options?): Report
	local opts: Options = options or {}
	if opts.Terrain == nil then
		assert(not game:GetService("RunService"):IsRunning(), "Saved terrain upgrades require Studio edit mode")
	end
	assert(type(hf.surface) == "function" and type(hf.naturalMaterial) == "function", "New terrain surface is missing")
	assert(
		type(hf.legacySurface) == "function" and type(hf.legacyNaturalMaterial) == "function",
		"Known previous terrain surface is missing; saved terrain was not touched"
	)
	local hasOriginal = hf.originalSurface ~= nil or hf.originalNaturalMaterial ~= nil
	assert(
		not hasOriginal or (type(hf.originalSurface) == "function" and type(hf.originalNaturalMaterial) == "function"),
		"Original terrain matching requires both surface and material functions"
	)
	local half, floor = layout.Bounds.Half, layout.Bounds.FloorY
	assert(
		finite(half) and half > 0 and half % CHUNK == 0 and finite(floor) and floor % RES == 0,
		"Invalid landscape bounds"
	)
	local bounds: Bounds = opts.Bounds or { MinX = -half, MaxX = half, MinZ = -half, MaxZ = half }
	for _, edge in { bounds.MinX, bounds.MaxX, bounds.MinZ, bounds.MaxZ } do
		assert(
			finite(edge) and edge % CHUNK == 0 and math.abs(edge) <= half,
			"Upgrade bounds must align to 64 studs inside the map"
		)
	end
	assert(bounds.MaxX > bounds.MinX and bounds.MaxZ > bounds.MinZ, "Empty terrain upgrade bounds")
	local terrain = opts.Terrain or workspace.Terrain
	local yieldEvery = opts.Yield or Util.yield
	local report: Report = {
		Complete = false,
		DryRun = opts.DryRun == true,
		Error = nil,
		ChunksRead = 0,
		ChunksWritten = 0,
		EligibleColumns = 0,
		ChangedColumns = 0,
		ChangedVoxels = 0,
		OriginalColumns = 0,
		PreservedColumns = 0,
		AlreadyCurrentColumns = 0,
		UnchangedColumns = 0,
		WaterMismatches = 0,
	}
	local enumByCode: { any } = {}
	for code, name in Heightfield.Materials do
		enumByCode[code] = (Enum.Material :: any)[name]
	end
	local chunkRows = (bounds.MaxZ - bounds.MinZ) // CHUNK
	local chunkColumns = (bounds.MaxX - bounds.MinX) // CHUNK
	log(
		if report.DryRun
			then "Checking saved terrain (dry run; no voxel writes)..."
			else "Upgrading matching generated terrain columns; custom terrain is preserved..."
	)
	local ok, failure = pcall(function()
		for row = 0, chunkRows - 1 do
			local z0 = bounds.MinZ + row * CHUNK
			local old = strip(hf.legacySurface, bounds.MinX, bounds.MaxX, z0, yieldEvery)
			local new = strip(hf.surface, bounds.MinX, bounds.MaxX, z0, yieldEvery)
			local original = if hasOriginal
				then strip(hf.originalSurface, bounds.MinX, bounds.MaxX, z0, yieldEvery)
				else nil
			for chunk = 0, chunkColumns - 1 do
				local x0 = bounds.MinX + chunk * CHUNK
				local oldLow, newLow, originalLow, highest = math.huge, math.huge, math.huge, -math.huge
				for z = 1, COLS do
					for x = 1, COLS do
						local i = z * old.Width + chunk * COLS + x + 1
						oldLow, newLow = math.min(oldLow, old.Heights[i]), math.min(newLow, new.Heights[i])
						highest = math.max(highest, old.Heights[i], new.Heights[i], old.Waters[i], new.Waters[i])
						if original then
							originalLow = math.min(originalLow, original.Heights[i])
							highest = math.max(highest, original.Heights[i], original.Waters[i])
						end
					end
				end
				local oldBottom = math.max(floor, math.floor((oldLow - 8) / RES) * RES)
				local newBottom = math.max(floor, math.floor((newLow - 8) / RES) * RES)
				local originalBottom = if original
					then math.max(floor, math.floor((originalLow - 8) / RES) * RES)
					else oldBottom
				local bottom, top = math.min(oldBottom, newBottom, originalBottom), math.ceil((highest + 8) / RES) * RES
				assert(
					top > bottom and top - bottom <= 2048,
					"Terrain patch band is too large; stopped without replacing this chunk"
				)
				local changes = {}
				for z = 1, COLS do
					for x = 1, COLS do
						local i = z * old.Width + chunk * COLS + x + 1
						local px, pz = x0 + (x - 1) * RES + RES / 2, z0 + (z - 1) * RES + RES / 2
						local before = sample(old, i, px, pz, hf.legacyNaturalMaterial, enumByCode, oldBottom)
						local after = sample(new, i, px, pz, hf.naturalMaterial, enumByCode, newBottom)
						local first = if original
							then sample(original, i, px, pz, hf.originalNaturalMaterial, enumByCode, originalBottom)
							else nil
						if opts.Protected and opts.Protected(px, pz) then
							report.PreservedColumns += 1
						elseif before.Water ~= after.Water or (first and first.Water ~= after.Water) then
							report.WaterMismatches += 1
							report.PreservedColumns += 1
						elseif
							math.abs(before.Height - after.Height) < 1e-7
							and before.Material == after.Material
							and (
								first == nil
								or (math.abs(first.Height - after.Height) < 1e-7 and first.Material == after.Material)
							)
						then
							report.UnchangedColumns += 1
						else
							table.insert(changes, { X = x, Z = z, Before = before, After = after, Original = first })
						end
					end
				end
				if #changes == 0 then
					continue
				end
				local region = Region3.new(Vector3.new(x0, bottom, z0), Vector3.new(x0 + CHUNK, top, z0 + CHUNK))
				local mats, occupancy = terrain:ReadVoxels(region, RES)
				report.ChunksRead += 1
				local eligible, voxels, originalEligible = 0, 0, 0
				for _, change in changes do
					local x, z = change.X, change.Z
					local oldMat, oldOcc = Upgrade.voxelize(change.Before, bottom, top)
					local newMat, newOcc = Upgrade.voxelize(change.After, bottom, top)
					local originalMat: { any }? = nil
					local originalOcc: { number }? = nil
					if change.Original then
						originalMat, originalOcc = Upgrade.voxelize(change.Original, bottom, top)
					end
					local wasOld, isNew, wasOriginal = true, true, originalMat ~= nil
					for y = 1, #oldMat do
						local actualMat, actualOcc = mats[x][y][z], occupancy[x][y][z]
						assert(
							finite(actualOcc) and actualOcc >= 0 and actualOcc <= 1,
							"Terrain returned invalid voxel occupancy"
						)
						wasOld = wasOld and sameVoxel(actualMat, actualOcc, oldMat[y], oldOcc[y])
						isNew = isNew and sameVoxel(actualMat, actualOcc, newMat[y], newOcc[y])
						if originalMat and originalOcc then
							wasOriginal = wasOriginal
								and sameVoxel(actualMat, actualOcc, originalMat[y], originalOcc[y])
						end
					end
					if isNew then
						report.AlreadyCurrentColumns += 1
					elseif not wasOld and not wasOriginal then
						report.PreservedColumns += 1
					else
						eligible += 1
						if wasOriginal and not wasOld then
							originalEligible += 1
						end
						for y = 1, #oldMat do
							if not sameVoxel(mats[x][y][z], occupancy[x][y][z], newMat[y], newOcc[y]) then
								voxels += 1
							end
							mats[x][y][z], occupancy[x][y][z] = newMat[y], newOcc[y]
						end
					end
				end
				if eligible > 0 then
					report.EligibleColumns += eligible
					if not report.DryRun then
						terrain:WriteVoxels(region, RES, mats, occupancy)
						report.ChunksWritten += 1
						report.ChangedColumns += eligible
						report.ChangedVoxels += voxels
						report.OriginalColumns += originalEligible
					end
				end
				yieldEvery()
			end
			if (row + 1) % 16 == 0 or row + 1 == chunkRows then
				log(
					`Terrain upgrade {math.floor((row + 1) * 100 / chunkRows)}%: {report.EligibleColumns} eligible, {report.PreservedColumns} custom/unknown columns preserved.`
				)
			end
		end
	end)
	if not ok then
		report.Error = tostring(failure)
		log(
			`Terrain upgrade stopped: {report.Error}. {report.ChunksWritten} earlier chunks were written; rerun to resume safely.`
		)
	else
		report.Complete = true
		log(
			`Terrain upgrade complete: {report.ChangedColumns} columns written, {report.AlreadyCurrentColumns} already current, {report.PreservedColumns} preserved.`
		)
	end
	return report
end

return Upgrade
