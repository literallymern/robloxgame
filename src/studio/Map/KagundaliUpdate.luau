--!strict
-- Shared by the focused command and existing BuildMap paths. Never clear the whole terrain
-- or rebuild cities to apply the first visual benchmark. A revision is not visual acceptance.
local Junction = require(script.Parent.JunctionLandscape)
local Trees = require(script.Parent.Builders.JunctionTrees)
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
	local old = map:FindFirstChild("KagundaliJunction")
	assert(not old or Util.isGenerated(old), "KagundaliJunction contains custom content; update stopped")
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
		local paintSample = if opts.GeneratedTerrain
			then function(p: Vector3): Vector3
				return p
			end
			else Markings.surface(map)
		built.Markings, built.MarkingsComplete = Markings.build(details, staging.KagundaliJunction, paintSample)
		if not built.MarkingsComplete and old and old:FindFirstChild("Markings") then
			local retained = old.Markings:Clone()
			retained.Parent = staging.KagundaliJunction
			built.Markings = #retained:GetChildren()
		end
		built.Parts += built.Markings
		assert(built.Parts <= Junction.MaxParts, "Junction markings exceeded the regional part budget")
		staging.KagundaliJunction:SetAttribute("PartCount", built.Parts)
		return built
	end)
	if not okay then
		staging:Destroy()
		error(`Kagundali staging failed; previous geometry retained: {tostring(report)}`)
	end
	local replacement = staging:FindFirstChild("KagundaliJunction") :: Folder
	if report.MarkingsComplete then
		Markings.removeReplaced(map)
	else
		log("Road marking probes incomplete: existing paint retained. Inspect the saved Roads/Bridges surfaces.")
	end
	report.RemovedOldPlants = Builder.removeOldVegetation(map)
	if old then
		old:Destroy()
	end
	replacement.Parent = map
	staging:Destroy()
	report.RefinedSigns = Builder.refineSigns(map)
	local places = map:FindFirstChild("Places")
	for _, place in if places and Util.isGenerated(places) then places:GetChildren() else {} do
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
	if opts.GeneratedTerrain or (terrain and (terrain.ChangedColumns > 0 or terrain.AlreadyCurrentColumns > 0)) then
		map:SetAttribute("KagundaliTerrainRevision", Junction.Revision)
	end
	if terrain then
		map:SetAttribute("KagundaliPreservedColumns", terrain.PreservedColumns)
		map:SetAttribute("KagundaliChangedColumns", terrain.ChangedColumns)
	end
	report.Revision, report.Terrain = Junction.Revision, terrain
	log(
		`{Junction.Revision}: {report.Trees} new trees, {report.Shrubs} shrubs, {report.Ferns} ferns; {report.Parts}/{Junction.MaxParts} parts. Workshop: {report.Workshop}.`
	)
	log(
		`Removed {report.RemovedOldPlants} old plants; refined {report.RefinedSigns} signs; restored {report.Markings} marking parts. Save the place. Visual acceptance remains a Studio comparison at R3/N5.`
	)
	return report
end

return Update
