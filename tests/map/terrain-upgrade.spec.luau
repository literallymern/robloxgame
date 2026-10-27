--!strict
-- needs: roblox-mock
-- Actual patch writer against a stateful voxel backend, plus pure column classification.
-- This is not Roblox Studio. The fixture deliberately offers no Clear or FillBlock method.
local Upgrade = load("StudioTools/Map/Builders/TerrainUpgrade")
local failures, checks = 0, 0
local function check(name: string, ok: boolean, detail: string?)
	checks += 1
	if ok then
		print("PASS", name)
	else
		failures += 1
		print("FAIL", name, detail or "")
	end
end

local tokens = { Air = "Air", Water = "Water", Rock = "Rock" }
local old = { Height = 21, Material = "Grass", RockBelow = 8 }
local raised = { Height = 25, Material = "LeafyGrass", RockBelow = 8 }
local beforeMat, beforeOcc = Upgrade.voxelize(old, 0, 36, tokens)
local afterMat, afterOcc = Upgrade.voxelize(raised, 0, 36, tokens)
check(
	"patch voxelization retains deep rock and fractional grass surface",
	beforeMat[1] == "Rock" and beforeOcc[1] == 1 and beforeMat[6] == "Grass" and beforeOcc[6] == 0.25
)
check(
	"known old columns are eligible for upgrade",
	Upgrade.classify(beforeMat, beforeOcc, beforeMat, beforeOcc, afterMat, afterOcc) == "upgrade"
)
check(
	"already-upgraded columns are idempotent",
	Upgrade.classify(afterMat, afterOcc, beforeMat, beforeOcc, afterMat, afterOcc) == "current"
)
local painted = table.clone(beforeMat)
painted[5] = "Mud"
check(
	"custom material painting protects the whole column",
	Upgrade.classify(painted, beforeOcc, beforeMat, beforeOcc, afterMat, afterOcc) == "preserve"
)
local sculpted = table.clone(beforeOcc)
sculpted[6] = 0.5
check(
	"custom terrain sculpting protects the whole column",
	Upgrade.classify(beforeMat, sculpted, beforeMat, beforeOcc, afterMat, afterOcc) == "preserve"
)
local quantized = table.clone(beforeOcc)
quantized[6] += 0.003
check(
	"occupancy readback quantization is tolerated",
	Upgrade.classify(beforeMat, quantized, beforeMat, beforeOcc, afterMat, afterOcc) == "upgrade"
)
local submergedMat, submergedOcc =
	Upgrade.voxelize({ Height = 9, Material = "Mud", Water = 18, RockBelow = 0 }, 0, 24, tokens)
check(
	"water voxelization preserves the original builder rule without air pockets",
	submergedMat[3] == "Water" and submergedOcc[3] == 1 and submergedMat[5] == "Water" and submergedOcc[5] == 0.5
)
local waterEdited = table.clone(submergedOcc)
waterEdited[5] = 0.75
check(
	"edited water is not mistaken for generated terrain",
	Upgrade.classify(submergedMat, waterEdited, submergedMat, submergedOcc, submergedMat, submergedOcc) == "preserve"
)

local AIR, WATER, ROCK = Enum.Material.Air, Enum.Material.Water, Enum.Material.Rock
local fixture = {
	legacySurface = function(x: number, z: number)
		if x >= 32 and z >= 32 then
			return 20, 5, 28
		end
		return 40, 1, nil
	end,
	surface = function(x: number, z: number)
		if x >= 32 and z >= 32 then
			return 24, 5, 28
		end
		return 44, 2, nil
	end,
	legacyNaturalMaterial = function()
		return 1
	end,
	naturalMaterial = function()
		return 2
	end,
}
local function key(x: number, y: number, z: number): string
	return `{x}/{y}/{z}`
end
local function backend()
	local data: { [string]: { any } } = {}
	for x = 0, 31 do
		for z = 0, 15 do
			local h, code, water = fixture.legacySurface(x * 4 + 2, z * 4 + 2)
			local mat = if code == 5 then Enum.Material.Mud else Enum.Material.Grass
			local mats, occ = Upgrade.voxelize({ Height = h, Material = mat, Water = water, RockBelow = 12 }, 0, 64)
			for y = 0, 15 do
				data[key(x, y, z)] = { mats[y + 1], occ[y + 1] }
			end
		end
	end
	-- Independent deliberate manual changes: soil paint, sculpted surface, edited water,
	-- and a buried cave detail below the surface-band read/write range.
	data[key(1, 9, 0)] = { Enum.Material.Grass, 0.4 }
	data[key(2, 9, 0)] = { Enum.Material.Slate, 1 }
	data[key(14, 6, 14)] = { WATER, 0.6 }
	data[key(0, 0, 0)] = { Enum.Material.Slate, 0.8 }
	local api: any = { Data = data, Reads = 0, Writes = 0, FailWriteAt = nil, BadRead = false }
	function api:ReadVoxels(region: any, resolution: number)
		assert(resolution == 4)
		self.Reads += 1
		local low, high = region.Min, region.Max
		local mats, occ = {}, {}
		for x = low.X // 4, high.X // 4 - 1 do
			local ix = (x * 4 - low.X) // 4 + 1
			mats[ix], occ[ix] = {}, {}
			for y = low.Y // 4, high.Y // 4 - 1 do
				local iy = (y * 4 - low.Y) // 4 + 1
				mats[ix][iy], occ[ix][iy] = {}, {}
				for z = low.Z // 4, high.Z // 4 - 1 do
					local iz = (z * 4 - low.Z) // 4 + 1
					local cell = self.Data[key(x, y, z)] or { AIR, 0 }
					mats[ix][iy][iz] = cell[1]
					occ[ix][iy][iz] = if self.BadRead then 2 else cell[2]
				end
			end
		end
		return mats, occ
	end
	function api:WriteVoxels(region: any, resolution: number, mats: any, occ: any)
		assert(resolution == 4)
		if self.FailWriteAt == self.Writes + 1 then
			error("simulated engine write failure")
		end
		self.Writes += 1
		local low, high = region.Min, region.Max
		for x = low.X // 4, high.X // 4 - 1 do
			for y = low.Y // 4, high.Y // 4 - 1 do
				for z = low.Z // 4, high.Z // 4 - 1 do
					local ix, iy, iz = x - low.X // 4 + 1, y - low.Y // 4 + 1, z - low.Z // 4 + 1
					self.Data[key(x, y, z)] = { mats[ix][iy][iz], occ[ix][iy][iz] }
				end
			end
		end
	end
	return api
end

local layout = { Bounds = { Half = 128, FloorY = 0 } }
local bounds = { MinX = 0, MaxX = 64, MinZ = 0, MaxZ = 64 }
local function options(api: any, dry: boolean?)
	return { Bounds = bounds, Terrain = api, DryRun = dry, Yield = function() end }
end
local messages = {}
local function log(message: string)
	table.insert(messages, message)
end
local api = backend()
local dry = Upgrade.apply(fixture, layout, log, options(api, true))
check(
	"dry run identifies matching columns without voxel writes",
	dry.Complete and dry.EligibleColumns == 253 and dry.ChangedColumns == 0 and api.Writes == 0
)
local protectedApi = backend()
local protectedOptions: any = options(protectedApi)
protectedOptions.Protected = function(x: number, z: number): boolean
	return x == 2 and z == 2
end
local protectedReport = Upgrade.apply(fixture, layout, log, protectedOptions)
check(
	"custom-building footprints protect matching generated ground",
	protectedReport.Complete
		and protectedReport.ChangedColumns == 252
		and protectedReport.PreservedColumns == 4
		and protectedApi.Data[key(0, 10, 0)][2] == 0
)
local applied = Upgrade.apply(fixture, layout, log, options(api))
check(
	"writer upgrades only matched columns in a bounded chunk",
	applied.Complete and applied.ChangedColumns == 253 and applied.PreservedColumns == 3 and applied.ChunksWritten == 1
)
check(
	"dry generated surface receives the new elevation and material",
	api.Data[key(0, 10, 0)][1] == Enum.Material.LeafyGrass and api.Data[key(0, 10, 0)][2] == 1
)
check(
	"sculpted and painted columns remain unchanged",
	api.Data[key(1, 9, 0)][2] == 0.4
		and api.Data[key(2, 9, 0)][1] == Enum.Material.Slate
		and api.Data[key(1, 10, 0)][2] == 0
)
check(
	"water level remains fixed while matching submerged sediment changes",
	api.Data[key(12, 5, 12)][1] == Enum.Material.Mud
		and api.Data[key(12, 6, 12)][1] == WATER
		and api.Data[key(12, 7, 12)][2] == 0
)
check(
	"custom water and deep cave detail survive",
	api.Data[key(14, 6, 14)][2] == 0.6
		and api.Data[key(0, 0, 0)][1] == Enum.Material.Slate
		and api.Data[key(0, 0, 0)][2] == 0.8
)
local again = Upgrade.apply(fixture, layout, log, options(api))
check(
	"a second application performs no writes",
	again.Complete and again.AlreadyCurrentColumns == 253 and again.ChangedColumns == 0 and api.Writes == 1
)

local changedWater = table.clone(fixture)
changedWater.surface = function(x: number, z: number)
	local h, code, water = fixture.surface(x, z)
	return h, code, if x == 34 and z == 34 then 30 else water
end
local waterReport = Upgrade.apply(changedWater, layout, log, options(api))
check(
	"a model water-level change is preserved and reported rather than applied",
	waterReport.Complete and waterReport.WaterMismatches == 1 and waterReport.ChangedColumns == 0
)

local broken = backend()
broken.BadRead = true
local invalid = Upgrade.apply(fixture, layout, log, options(broken))
check(
	"malformed engine data stops before writing the chunk",
	not invalid.Complete and invalid.Error ~= nil and invalid.ChunksWritten == 0 and broken.Writes == 0
)
local partial = backend()
partial.FailWriteAt = 2
local wide = options(partial)
wide.Bounds = { MinX = 0, MaxX = 128, MinZ = 0, MaxZ = 64 }
local stopped = Upgrade.apply(fixture, layout, log, wide)
check(
	"mid-upgrade failure honestly reports earlier committed chunks",
	not stopped.Complete
		and stopped.ChunksWritten == 1
		and stopped.ChangedColumns == 253
		and string.find(stopped.Error or "", "simulated engine") ~= nil
)
partial.FailWriteAt = nil
local resumed = Upgrade.apply(fixture, layout, log, wide)
check(
	"an interrupted upgrade resumes without reapplying completed columns",
	resumed.Complete and resumed.AlreadyCurrentColumns == 253 and resumed.ChangedColumns == 256
)
local safe = backend()
local invalidBounds = pcall(function()
	Upgrade.apply(fixture, layout, log, { Terrain = safe, Bounds = { MinX = 1, MaxX = 64, MinZ = 0, MaxZ = 64 } })
end)
check(
	"invalid bounds fail preflight without touching terrain",
	not invalidBounds and safe.Reads == 0 and safe.Writes == 0
)
check("successful patching never needs destructive terrain methods", api.Reads > 0 and api.Writes == 1)

-- Establish compatibility with the ACTUAL previous terrain writer, rather than initializing
-- all fixtures through the upgrade's own voxelizer. This exercises old deep FillBlock bands
-- and original array ordering through the production TerrainBuilder implementation.
local TerrainBuilder = load("StudioTools/Map/Builders/Terrain")
local generated = backend()
generated.Clears = 0
function generated:Clear()
	table.clear(self.Data)
	self.Clears += 1
end
function generated:FillBlock(frame: any, size: any, material: any)
	local low, high = frame.Position - size / 2, frame.Position + size / 2
	for x = low.X // 4, high.X // 4 - 1 do
		for y = low.Y // 4, high.Y // 4 - 1 do
			for z = low.Z // 4, high.Z // 4 - 1 do
				self.Data[key(x, y, z)] = { material, 1 }
			end
		end
	end
end
local savedWorkspace: any = workspace
workspace = { Terrain = generated } :: any
TerrainBuilder.build(
	{ surface = fixture.legacySurface, naturalMaterial = fixture.legacyNaturalMaterial } :: any,
	{ Bounds = { Half = 64, FloorY = 0 } },
	log
)
workspace = savedWorkspace
local previousClears = generated.Clears
local productionPatch = Upgrade.apply(fixture, layout, log, options(generated))
check(
	"actual previous TerrainBuilder output matches the upgrade without false custom skips",
	productionPatch.Complete and productionPatch.ChangedColumns == 256 and productionPatch.PreservedColumns == 0,
	`{productionPatch.ChangedColumns} changed; {productionPatch.PreservedColumns} skipped`
)
check("production-writer compatibility does not clear saved terrain during upgrade", generated.Clears == previousClears)

check(
	"pure matching recognizes the original generator as a distinct known baseline",
	Upgrade.classify(beforeMat, beforeOcc, afterMat, afterOcc, afterMat, afterOcc, beforeMat, beforeOcc) == "original"
)
check(
	"adding an original baseline does not accept arbitrary custom terrain",
	Upgrade.classify(painted, beforeOcc, afterMat, afterOcc, afterMat, afterOcc, beforeMat, beforeOcc) == "preserve"
)

-- The v2 landscape already equals the new surface here. The updater must still consider
-- original saved terrain; checking only v2-v3 differences would skip every old river bank.
local originalFixture: any = table.clone(fixture)
originalFixture.originalSurface = fixture.legacySurface
originalFixture.originalNaturalMaterial = fixture.legacyNaturalMaterial
originalFixture.legacySurface = fixture.surface
originalFixture.legacyNaturalMaterial = fixture.naturalMaterial
local originalApi = backend()
local originalDry = Upgrade.apply(originalFixture, layout, log, options(originalApi, true))
check(
	"original-only differences remain candidates when v2 already equals v3",
	originalDry.Complete
		and originalDry.EligibleColumns == 253
		and originalDry.OriginalColumns == 0
		and originalApi.Writes == 0
)
local originalApplied = Upgrade.apply(originalFixture, layout, log, options(originalApi))
check(
	"original saved banks and materials migrate directly to v3 while edits survive",
	originalApplied.Complete
		and originalApplied.ChangedColumns == 253
		and originalApplied.OriginalColumns == 253
		and originalApplied.PreservedColumns == 3
)
local originalAgain = Upgrade.apply(originalFixture, layout, log, options(originalApi))
check(
	"original-baseline upgrade remains idempotent",
	originalAgain.Complete
		and originalAgain.AlreadyCurrentColumns == 253
		and originalAgain.ChangedColumns == 0
		and originalApi.Writes == 1
)

local mixedFixture: any = table.clone(originalFixture)
mixedFixture.surface = function(x: number, z: number)
	if x >= 32 and z >= 32 then
		return 24, 5, 28
	end
	return 48, 4, nil
end
local mixedApi = backend()
local v2Mat, v2Occ = Upgrade.voxelize({ Height = 44, Material = Enum.Material.LeafyGrass, RockBelow = 16 }, 12, 56)
for y = 1, #v2Mat do
	mixedApi.Data[key(0, y + 2, 0)] = { v2Mat[y], v2Occ[y] }
end
local mixed = Upgrade.apply(mixedFixture, layout, log, options(mixedApi))
check(
	"one patch accepts both original and v2 columns without blending unknown edits",
	mixed.Complete and mixed.ChangedColumns == 253 and mixed.OriginalColumns == 252 and mixed.PreservedColumns == 3,
	`{mixed.ChangedColumns} changed; {mixed.OriginalColumns} original; {mixed.PreservedColumns} preserved`
)
local missingOriginal: any = table.clone(fixture)
missingOriginal.originalSurface = fixture.legacySurface
local missingBackend = backend()
local originalPreflight = pcall(function()
	Upgrade.apply(missingOriginal, layout, log, options(missingBackend))
end)
check(
	"an incomplete original baseline fails preflight without reading or writing terrain",
	not originalPreflight and missingBackend.Reads == 0 and missingBackend.Writes == 0
)
print(
	`INFO {checks} terrain-upgrade checks; {applied.ChangedColumns} changed and {applied.PreservedColumns} custom columns preserved in the fixture`
)
if failures > 0 then
	error(`{failures} terrain-upgrade check(s) failed`)
end
print("ALL CHECKS PASSED")
