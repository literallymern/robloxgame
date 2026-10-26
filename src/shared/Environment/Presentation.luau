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

local function owned(parent: Instance, className: string, name: string, singleton: boolean): any
	local named = parent:FindFirstChild(name)
	if named then
		if named:IsA(className) then
			return named
		end
		warn(`[Ro-Nation:Environment] Reserved name {name} is occupied; leaving it unchanged.`)
		return nil
	end
	local existing = parent:FindFirstChildOfClass(className)
	if singleton and existing then
		if
			existing:GetAttribute("GeneratedBy") == "BuildMap"
			or existing:GetAttribute("ManagedBy") == "RoNationEnvironment"
		then
			existing.Name = name
			return existing
		end
		warn(`[Ro-Nation:Environment] Existing custom {className} kept; automatic {className} changes are skipped.`)
		return nil
	end
	local created = Instance.new(className)
	created.Name = name
	created:SetAttribute("ManagedBy", "RoNationEnvironment")
	created.Parent = parent
	return created
end

function Presentation.new(): any
	return {
		Atmosphere = owned(Lighting, "Atmosphere", "RoNationAtmosphere", true),
		Clouds = owned(workspace.Terrain, "Clouds", "RoNationClouds", true),
		Bloom = owned(Lighting, "BloomEffect", "RoNationBloom", false),
		Rays = owned(Lighting, "SunRaysEffect", "RoNationSunRays", false),
		Correction = owned(Lighting, "ColorCorrectionEffect", "RoNationColorCorrection", false),
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
	Lighting.ShadowSoftness = 0.35
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
