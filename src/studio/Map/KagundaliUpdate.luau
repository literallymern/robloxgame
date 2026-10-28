--!strict
-- Shared by the focused command and existing BuildMap paths. Never clear the whole terrain
-- or rebuild cities to apply the first visual benchmark. A revision is not visual acceptance.
local Junction = require(script.Parent.JunctionLandscape)
local Trees = require(script.Parent.Builders.JunctionTrees)
local CreatorAssets = require(script.Parent.CreatorAssets)
local Builder = require(script.Parent.Builders.Kagundali)
local Markings = require(script.Parent.Builders.JunctionMarkings)
local Upgrade = require(script.Parent.Builders.TerrainUpgrade)
local Existing = require(script.Parent.ExistingTerrain)
local Details = require(script.Parent.RoadDetails)
local Environment = require(script.Parent.Builders.Environment)
local Util = require(script.Parent.Builders.Util)
local Update = {}

function Update.apply(hf: any, layout: any, map: Instance, options: any?): any
	assert(not game:GetService("RunService"):IsRunning(), "Stop Play before applying the Kagundali benchmark")
	local model = require(game:GetService("ReplicatedStorage").Shared.Environment.Model)
	assert(
		model.VisualRevision == Junction.LightingRevision,
		"A cached lighting module is still loaded. Save, restart Studio and reconnect Rojo before applying Kagundali."
	)
	local opts = options or {}
	local previous: { Instance } = {}
	for _, child in map:GetChildren() do
		if child.Name == "KagundaliJunction" then
			assert(Util.isGenerated(child), "KagundaliJunction contains custom content; update stopped")
			table.insert(previous, child)
		end
	end
	local protected = Existing.protection()
	local feature = Junction.decorate(hf, layout)
	local log = function(message: string)
		print(`[Ro-Nation:Kagundali] {message}`)
	end
	if opts.DryRun then
		return Upgrade.apply(feature, layout, log, { DryRun = true, Bounds = Junction.Bounds, Protected = protected })
	end
	-- Native asset compilation must succeed before the first terrain write or old-model removal.
	local library = Trees.prepare()
	local terrain = nil
	if opts.Terrain ~= false then
		terrain = Upgrade.apply(feature, layout, log, { Bounds = Junction.Bounds, Protected = protected })
		assert(
			terrain.Complete,
			`Local terrain patch interrupted: {tostring(terrain.Error)}; earlier chunks may have changed. Rerun to resume.`
		)
	end
	local sample = Existing.groundSampler(protected)
	if opts.GeneratedTerrain then
		sample = function(x: number, z: number): (number?, number)
			if protected(x, z) then
				return nil, 0
			end
			local y, _, water = feature.surface(x, z)
			if water then
				return nil, 0
			end
			local dx, dz =
				(feature.surface(x + 4, z) - feature.surface(x - 4, z)) / 8,
				(feature.surface(x, z + 4) - feature.surface(x, z - 4)) / 8
			return y, math.sqrt(dx * dx + dz * dz)
		end
	end
	local staging = Util.detachedFolder("KagundaliStaging")
	local okay, report = pcall(function()
		local details = Details.new(layout, hf, sample)
		local built = Builder.build(feature, layout, staging, sample, library, details)
		local junction = staging:FindFirstChild("KagundaliJunction") :: Folder
		local paintSample: (Vector3) -> Vector3? = if opts.GeneratedTerrain
			then function(p: Vector3): Vector3
				return p
			end
			else Markings.surface(map)
		built.RestoredMarkings, built.MarkingsComplete, built.PaintCoverage, built.SkippedMarkings, built.MissingPaintSamples = Markings.build(
			details,
			junction,
			function(p: Vector3): Vector3?
				return if protected(p.X, p.Z) then nil else paintSample(p)
			end
		)
		built.RetainedMarkings = 0
		for _, old in previous do
			built.RetainedMarkings += Markings.retainPrevious(
				old:FindFirstChild("Markings"),
				junction:FindFirstChild("Markings") :: Folder,
				built.PaintCoverage
			)
		end
		built.ImportedTrees, built.NativeTrees = 0, 0
		local planting = junction:FindFirstChild("Planting") :: Folder
		for _, plant in planting:GetChildren() do
			if plant:IsA("Model") and plant:FindFirstChild("TrunkCollision") then
				if plant:GetAttribute("SourceAssetId") == CreatorAssets.Packs[1].Id then
					built.ImportedTrees += 1
				else
					built.NativeTrees += 1
				end
			end
		end
		built.Markings = built.RestoredMarkings + built.RetainedMarkings
		built.Parts += built.Markings
		assert(built.Parts <= Junction.MaxParts, "Junction markings exceeded the regional part budget")
		junction:SetAttribute("PartCount", built.Parts)
		return built
	end)
	if not okay then
		staging:Destroy()
		error(`Kagundali staging failed; previous geometry retained: {tostring(report)}`)
	end
	local replacement = staging:FindFirstChild("KagundaliJunction") :: Folder
	Markings.removeReplaced(map, report.PaintCoverage)
	if not report.MarkingsComplete then
		log(
			`Skipped {report.SkippedMarkings} marking sections; valid sections applied and unmatched old paint retained. Missing samples: {table.concat(
				report.MissingPaintSamples,
				"; "
			)}`
		)
	end
	report.RemovedOldPlants = Builder.removeOldVegetation(map)
	if report.ImportedLamps > 0 then
		Builder.removeOldLamps(map, report.ReplacedLampPositions)
	end
	for _, old in previous do
		old:Destroy()
	end
	report.ReplacedRegions = #previous
	replacement.Parent = map
	staging:Destroy()
	report.RefinedSigns = Builder.refineSigns(map)
	local places = map:FindFirstChild("Places")
	local placeList: { Instance } = if places and Util.isGenerated(places) then places:GetChildren() else {}
	for _, place in placeList do
		local marker = place:FindFirstChild("NameMarker")
		if marker then
			for _, gui in marker:GetChildren() do
				if gui:IsA("BillboardGui") then
					gui.Enabled = false
				end
			end
		end
	end
	Environment.apply(log)
	map:SetAttribute("EnvironmentLightingRevision", Junction.LightingRevision)
	map:SetAttribute("KagundaliGeometryRevision", Junction.Revision)
	replacement:SetAttribute("RestoredMarkings", report.RestoredMarkings)
	replacement:SetAttribute("SkippedMarkings", report.SkippedMarkings)
	if opts.GeneratedTerrain or (terrain and (terrain.ChangedColumns > 0 or terrain.AlreadyCurrentColumns > 0)) then
		map:SetAttribute("KagundaliTerrainRevision", Junction.Revision)
	end
	if terrain then
		map:SetAttribute("KagundaliPreservedColumns", terrain.PreservedColumns)
		map:SetAttribute("KagundaliChangedColumns", terrain.ChangedColumns)
	end
	report.Revision, report.Terrain = Junction.Revision, terrain
	log(
		`{Junction.Revision}: {report.Trees} new trees ({Trees.currentVersion()}), {report.Shrubs} shrubs, {report.Ferns} ferns; {report.Parts}/{Junction.MaxParts} parts. Workshop: {report.Workshop}; imported lamps: {report.ImportedLamps}.`
	)
	log(
		`Removed {report.RemovedOldPlants} old plants; refined {report.RefinedSigns} signs; restored {report.RestoredMarkings} marking parts, retained {report.RetainedMarkings}, skipped {report.SkippedMarkings}. Save the place. Visual acceptance remains a Studio comparison at R3/N5.`
	)
	log(
		`Actual tree models: {report.ImportedTrees} from Creator Store, {report.NativeTrees} native; replaced {report.ReplacedRegions} generated region folder(s).`
	)
	return report
end

return Update
