--!strict
-- A bounded camera-local rain pool: no uploaded textures, global emitters or server parts.
-- Optional sound IDs must be supplied by the place owner in Config.Environment.Effects.Audio.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Model = require(ReplicatedStorage.Shared.Environment.Model)

local WeatherEffects = {}

type Drop = { part: Part, position: Vector3, column: number, speed: number }
type Limits = { low: number, high: number }

function WeatherEffects.new(config: any): any
	local settings = config or {}
	local count = math.clamp(math.floor(settings.MaxStreaks or 64), 8, 96)
	local random = Random.new()
	local drops: { Drop } = {}
	local columns: { Limits } = {}
	local folder: Folder? = nil
	local lastCamera: Camera? = nil
	local shelter = false
	local shelterClock = 1
	local gridPosition: Vector3? = nil
	local shelterPosition: Vector3? = nil
	local previousLightning = 0
	local thunderAt = math.huge
	local thunderVolume = 0
	local stopped = false
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = false
	local flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "RoNationLightning"
	flash:SetAttribute("RoNationEnvironment", true)
	flash.Brightness = 0
	flash.Enabled = false
	flash.Parent = Lighting
	local audio = settings.Audio or {}
	local rainSound = Instance.new("Sound")
	rainSound.Name = "RoNationRain"
	rainSound.SoundId = audio.Rain or ""
	rainSound.Looped = true
	rainSound.Volume = 0
	rainSound.Parent = SoundService
	local thunder = Instance.new("Sound")
	thunder.Name = "RoNationThunder"
	thunder.SoundId = audio.Thunder or ""
	thunder.Volume = 0
	thunder.Parent = SoundService

	local function createPool(camera: Camera)
		if folder then
			folder:Destroy()
		end
		local container = Instance.new("Folder")
		container.Name = "RoNationLocalRain"
		container.Parent = camera
		folder = container
		table.clear(drops)
		for i = 1, count do
			local part = Instance.new("Part")
			part.Name = "RainStreak"
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Color3.fromRGB(183, 202, 209)
			part.Transparency = 1
			part.Size = Vector3.new(0.045, 2, 0.045)
			part.Parent = container
			table.insert(drops, {
				part = part,
				position = camera.CFrame.Position + Vector3.new(0, 100, 0),
				column = ((i - 1) * 5) % 16 + 1,
				speed = random:NextNumber(58, 82),
			})
		end
		lastCamera = camera
		shelterClock = 1
		gridPosition = nil
		shelterPosition = nil
		table.clear(columns)
	end

	local function checkShelter(camera: Camera, drawRain: boolean)
		local ignore: { Instance } = {}
		if folder then
			table.insert(ignore, folder)
		end
		local character = Players.LocalPlayer.Character
		if character then
			table.insert(ignore, character)
		end
		params.FilterDescendantsInstances = ignore
		local position = camera.CFrame.Position
		shelter = workspace:Raycast(position, Vector3.new(0, 256, 0), params) ~= nil
		shelterPosition = position
		if not drawRain or shelter then
			table.clear(columns)
			gridPosition = nil
			return
		end
		-- Sixteen shared columns use at most 85 regular queries/second on high quality,
		-- fewer on lower settings. Camera teleports add one immediate shelter probe.
		gridPosition = position
		for i = 1, 16 do
			local x = ((i - 1) % 4 - 1.5) * 10
			local z = (math.floor((i - 1) / 4) - 1.5) * 10
			local origin = position + Vector3.new(x, 26, z)
			local hit = workspace:Raycast(origin, Vector3.new(0, -52, 0), params)
			columns[i] = { low = if hit then hit.Position.Y + 2 else position.Y - 26, high = position.Y + 26 }
		end
	end

	local effects = {}

	function effects:update(
		dt: number,
		rain: number,
		storm: number,
		quality: number,
		nowServer: number,
		lightningAt: number,
		seed: number
	)
		if stopped then
			return
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		if camera ~= lastCamera then
			createPool(camera)
		end
		local intensity = math.clamp(rain, 0, 1)
		local detail = math.clamp(quality, 0, 1)
		shelterClock += dt
		local position = camera.CFrame.Position
		if intensity > 0.005 and shelterPosition and (position - shelterPosition).Magnitude > 32 then
			-- Old terrain heights must not be reused around a teleported camera. Hide the
			-- old pool until the next scheduled grid refresh and check shelter immediately.
			checkShelter(camera, false)
		end
		local interval = if detail <= 0 then 0.6 else 0.2 / math.max(0.5, detail)
		if shelterClock >= interval and intensity > 0.005 then
			shelterClock = 0
			checkShelter(camera, detail > 0)
		end
		local active = if shelter or gridPosition == nil then 0 else math.floor(count * intensity * detail)
		for i, drop in drops do
			if i > active then
				drop.part.Transparency = 1
				continue
			end
			local limits = columns[drop.column]
			if not limits or limits.high - limits.low < 2 then
				drop.part.Transparency = 1
				continue
			end
			local p = drop.position + Vector3.new(-8, -drop.speed, 2) * math.min(dt, 0.1)
			if p.Y < limits.low or p.Y > limits.high or (p - position).Magnitude > 46 then
				local x = ((drop.column - 1) % 4 - 1.5) * 10 + random:NextNumber(-3, 3)
				local z = (math.floor((drop.column - 1) / 4) - 1.5) * 10 + random:NextNumber(-3, 3)
				-- The sampled heights belong to the last probe grid, rather than the moving
				-- camera. Keeping spawn positions on that grid reduces roof-edge leakage.
				local origin = gridPosition :: Vector3
				p = Vector3.new(origin.X + x, random:NextNumber(limits.low + 1, limits.high), origin.Z + z)
			end
			drop.position = p
			drop.part.CFrame = CFrame.new(p) * CFrame.Angles(0.03, 0, -0.1)
			drop.part.Size = Vector3.new(0.045, 1.7 + 1.6 * intensity, 0.045)
			drop.part.Transparency = 0.5 + 0.2 * (1 - intensity)
		end
		local targetVolume = intensity * (if shelter then 0.12 else 0.4)
		rainSound.Volume += (targetVolume - rainSound.Volume) * Model.responseAlpha(dt, 1 / 3)
		if rainSound.SoundId ~= "" then
			if rainSound.Volume > 0.005 and not rainSound.IsPlaying then
				rainSound:Play()
			elseif rainSound.Volume <= 0.005 and rainSound.IsPlaying then
				rainSound:Stop()
			end
		end

		local allowLightning = not settings.Lightning or settings.Lightning.Enabled ~= false
		if lightningAt > previousLightning then
			previousLightning = lightningAt
			-- A deterministic delay represents a distant strike, synchronized with its flash.
			local delaySeconds = 1.5 + math.abs(math.sin(seed * 12.9898)) * 3.5
			thunderAt = lightningAt + delaySeconds
			thunderVolume = math.clamp(storm, 0, 1) * (if shelter then 0.16 else 0.35)
		end
		local age = nowServer - lightningAt
		local flashValue = 0
		if allowLightning and storm > 0.1 and age >= 0 and age < 0.36 then
			flashValue = if age < 0.09
				then 0.13 * (1 - age / 0.09)
				elseif age > 0.17 then 0.07 * (1 - (age - 0.17) / 0.19)
				else 0
		end
		flash.Enabled = flashValue > 0
		flash.Brightness = flashValue
		if nowServer >= thunderAt then
			if nowServer - thunderAt < 1 and thunder.SoundId ~= "" and allowLightning then
				thunder.Volume = thunderVolume
				thunder:Play()
			end
			thunderAt = math.huge
		end
	end

	function effects:destroy()
		stopped = true
		if folder then
			folder:Destroy()
		end
		rainSound:Destroy()
		thunder:Destroy()
		flash:Destroy()
	end

	return effects
end

return WeatherEffects
