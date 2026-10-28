--!strict
-- Shared Studio/runtime presentation. Reserved RoNation names identify our effects. Other
-- Atmosphere/Clouds instances take precedence and are left untouched instead of stacked.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.Environment)
local Model = require(script.Parent.Model)

local Presentation = {}

local function colour(values: { number }): Color3
	return Color3.new(values[1], values[2], values[3])
end

-- Exact pre-overhaul default.project.json values. Matching only a name is insufficient:
-- edited user effects must never be mistaken for the old project baseline.
type LegacyEffect = { Name: string, Class: string, Target: string, Properties: { [string]: any } }
local LEGACY: { LegacyEffect } = {
	{
		Name = "Atmosphere",
		Class = "Atmosphere",
		Target = "RoNationAtmosphere",
		Properties = {
			Density = 0.28,
			Offset = 0.25,
			Color = { 0.78, 0.83, 0.89 },
			Decay = { 0.42, 0.45, 0.5 },
			Glare = 0.15,
			Haze = 1.4,
		},
	},
	{
		Name = "Bloom",
		Class = "BloomEffect",
		Target = "RoNationBloom",
		Properties = {
			Intensity = 0.6,
			Size = 24,
			Threshold = 1.6,
		},
	},
	{
		Name = "SunRays",
		Class = "SunRaysEffect",
		Target = "RoNationSunRays",
		Properties = {
			Intensity = 0.06,
			Spread = 0.8,
		},
	},
	{
		Name = "ColorCorrection",
		Class = "ColorCorrectionEffect",
		Target = "RoNationColorCorrection",
		Properties = {
			Brightness = 0.01,
			Contrast = 0.06,
			Saturation = 0.08,
			TintColor = { 1, 0.99, 0.96 },
		},
	},
}

local function matchesLegacy(instance: any, specification: any): boolean
	if not instance:IsA(specification.Class) then
		return false
	end
	if instance:IsA("PostEffect") and instance.Enabled == false then
		return false -- preserve a user's decision to disable an effect
	end
	for property, expected in specification.Properties do
		local actual = instance[property]
		if type(expected) == "number" then
			if type(actual) ~= "number" or math.abs(actual - expected) > 0.0001 then
				return false
			end
		else
			if
				math.abs(actual.R - expected[1]) > 0.0001
				or math.abs(actual.G - expected[2]) > 0.0001
				or math.abs(actual.B - expected[3]) > 0.0001
			then
				return false
			end
		end
	end
	return true
end

-- Deliberate saved-place migration, called by the Studio environment tool, never the client.
-- Proven old duplicates are removed only when their new reserved counterpart already exists.
function Presentation.migrateLegacy(
	log: ((string) -> ())?
): { Adopted: number, RemovedDuplicates: number, KeptCustom: number }
	assert(not game:GetService("RunService"):IsRunning(), "Legacy lighting migration requires Studio edit mode")
	local report = { Adopted = 0, RemovedDuplicates = 0, KeptCustom = 0 }
	local write = log or function(_message: string) end
	for _, specification in LEGACY do
		for _, instance in Lighting:GetChildren() do
			if instance.Name ~= specification.Name then
				continue
			end
			if not matchesLegacy(instance, specification) then
				report.KeptCustom += 1
				write(
					`Kept custom/edited legacy lighting object {instance.Name}; automatic {specification.Class} changes may be skipped.`
				)
				continue
			end
			local counterpart = Lighting:FindFirstChild(specification.Target)
			if counterpart and not counterpart:IsA(specification.Class) then
				report.KeptCustom += 1
				write(`Could not adopt {instance.Name}: reserved name {specification.Target} is occupied.`)
			elseif counterpart then
				instance:Destroy()
				report.RemovedDuplicates += 1
				write(`Removed proven pre-overhaul duplicate {specification.Name}; using {specification.Target}.`)
			else
				instance.Name = specification.Target
				instance:SetAttribute("ManagedBy", "RoNationEnvironment")
				report.Adopted += 1
				write(`Adopted pre-overhaul {specification.Name} as {specification.Target}.`)
			end
		end
	end
	return report
end

local function owned(parent: Instance, className: string, name: string, skipped: { string }): any
	local function skip(reason: string): any
		table.insert(skipped, reason)
		warn(`[Ro-Nation:Environment] {reason}`)
		return nil
	end
	local named: any = parent:FindFirstChild(name)
	if named and not named:IsA(className) then
		return skip(`Reserved name {name} is occupied; leaving it unchanged.`)
	end
	local managed = nil
	for _, existing in parent:GetChildren() do
		if existing == named or not existing:IsA(className) then
			continue
		end
		-- The separate transient lightning flash is intentionally additive, owned by our
		-- local WeatherEffects module and never a competing baseline colour correction.
		if existing:GetAttribute("RoNationEnvironment") == true then
			continue
		end
		local ours = existing:GetAttribute("GeneratedBy") == "BuildMap"
			or existing:GetAttribute("ManagedBy") == "RoNationEnvironment"
		if ours then
			if managed then
				return skip(
					`Multiple managed {className} instances exist; repair them in Studio before automatic changes.`
				)
			end
			managed = existing
		elseif not existing:IsA("PostEffect") or (existing :: any).Enabled ~= false then
			-- A custom singleton can shadow the named handle; a custom post effect stacks
			-- with it. Avoid both cases and never change the user's object.
			if named and named:IsA("PostEffect") then
				named.Enabled = false
			end
			return skip(`Custom {className} \"{existing.Name}\" kept; automatic {className} changes are skipped.`)
		end
	end
	if named and managed then
		return skip(`Duplicate managed {className} instances exist; run the edit-mode legacy lighting migration.`)
	end
	local result: any = named or managed
	if not result then
		result = Instance.new(className)
		result.Parent = parent
	end
	result.Name = name
	result:SetAttribute("ManagedBy", "RoNationEnvironment")
	if result:IsA("PostEffect") then
		result.Enabled = true
	end
	return result
end

function Presentation.new(): any
	local skipped: { string } = {}
	return {
		Atmosphere = owned(Lighting, "Atmosphere", "RoNationAtmosphere", skipped),
		Clouds = owned(workspace.Terrain, "Clouds", "RoNationClouds", skipped),
		Bloom = owned(Lighting, "BloomEffect", "RoNationBloom", skipped),
		Rays = owned(Lighting, "SunRaysEffect", "RoNationSunRays", skipped),
		Correction = owned(Lighting, "ColorCorrectionEffect", "RoNationColorCorrection", skipped),
		Skipped = skipped,
	}
end

function Presentation.apply(handles: any, weather: Model.Weather, clock: number, altitude: number): any
	local visual = Model.lighting(clock, weather, altitude, Config.Altitude)
	Lighting.ClockTime = clock
	Lighting.GeographicLatitude = Config.Latitude
	Lighting.Brightness = visual.Brightness
	Lighting.ExposureCompensation = visual.Exposure
	Lighting.Ambient = colour(visual.Ambient)
	Lighting.OutdoorAmbient = colour(visual.OutdoorAmbient)
	Lighting.ColorShift_Top = colour(visual.SunTint)
	Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.24
	Lighting.EnvironmentDiffuseScale = 0.85
	Lighting.EnvironmentSpecularScale = 0.8
	if handles.Atmosphere then
		handles.Atmosphere.Density = visual.Density
		handles.Atmosphere.Offset = 0.15
		handles.Atmosphere.Color = colour(visual.AtmosphereColor)
		handles.Atmosphere.Decay = colour(visual.Decay)
		handles.Atmosphere.Glare = visual.Glare
		handles.Atmosphere.Haze = visual.Haze
	end
	if handles.Clouds then
		handles.Clouds.Cover = weather.Cover
		handles.Clouds.Density = weather.Density
		handles.Clouds.Color = colour(visual.CloudColor)
	end
	if handles.Bloom then
		handles.Bloom.Intensity = 0.08
		handles.Bloom.Size = 18
		handles.Bloom.Threshold = 1.8
	end
	if handles.Rays then
		handles.Rays.Intensity = visual.SunRays
		handles.Rays.Spread = 0.7
	end
	if handles.Correction then
		handles.Correction.Brightness = 0
		handles.Correction.Contrast = visual.Contrast
		handles.Correction.Saturation = visual.Saturation
		handles.Correction.TintColor = colour(visual.Tint)
	end
	-- GlobalWind drives Roblox's dynamic clouds and terrain grass without per-cloud geometry.
	workspace.GlobalWind = Vector3.new(3 + weather.Rain * 8, 0, 1.5 + weather.Storm * 3)
	return visual
end

return Presentation
