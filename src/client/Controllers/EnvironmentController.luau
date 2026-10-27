--!strict
-- Smooth synchronized sky/time and camera-local weather. No environmental geometry is built
-- during Play. Discovery follows streamed descendants; the server never processes visual rain.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Environment)
local Model = require(ReplicatedStorage.Shared.Environment.Model)
local Presentation = require(ReplicatedStorage.Shared.Environment.Presentation)
local WeatherEffects = require(script.Parent.WeatherEffects)

local Controller = {}
local started = false

type Snapshot = {
	From: Model.Weather,
	To: Model.Weather,
	Start: number,
	Duration: number,
	Clock: number,
	Epoch: number,
	DayLength: number,
}

local function numberAttribute(instance: Instance, name: string, fallback: number): number
	local value = instance:GetAttribute(name)
	return if type(value) == "number" then value else fallback
end

local function readSnapshot(state: Instance): Snapshot
	local raw = state:GetAttribute("Snapshot")
	local ok, data = pcall(function()
		return HttpService:JSONDecode(if type(raw) == "string" then raw else "")
	end)
	if ok and type(data) == "table" and type(data.From) == "table" and type(data.To) == "table" then
		local valid = true
		for _, key in Model.Keys do
			valid = valid and type(data.From[key]) == "number" and type(data.To[key]) == "number"
		end
		for _, key in { "Start", "Duration", "Clock", "Epoch", "DayLength" } do
			valid = valid and type(data[key]) == "number"
		end
		if valid then
			return data :: Snapshot
		end
	end
	return {
		From = Config.Profiles[Config.InitialWeather],
		To = Config.Profiles[Config.InitialWeather],
		Start = 0,
		Duration = Config.TransitionSeconds,
		Clock = Config.StartClockTime,
		Epoch = workspace:GetServerTimeNow(),
		DayLength = Config.DayLengthSeconds,
	}
end

local function quality(): number
	local override = Players.LocalPlayer:GetAttribute(Config.QualityAttribute)
	if type(override) == "number" and override == override then
		return math.clamp(override / 3, 0, 1)
	end
	local settings = UserSettings():GetService("UserGameSettings")
	local saved = settings.SavedQualityLevel.Value
	return if saved == 0 then 0.6 else math.clamp(saved / 10, 0.2, 1)
end

function Controller.start()
	if started then
		return
	end
	local player = Players.LocalPlayer
	player:SetAttribute("EnvironmentClientReady", false)
	if not Config.Enabled then
		player:SetAttribute("EnvironmentClientStatus", "disabled")
		return
	end
	started = true
	player:SetAttribute("EnvironmentClientStatus", "waiting for server state")
	-- Wait outside the bootstrap loop so an unavailable weather service never stalls UI startup.
	task.spawn(function()
		local state = ReplicatedStorage:WaitForChild(Config.StateName, 20)
		if not state or not state:IsA("Folder") or state:GetAttribute("ManagedBy") ~= "RoNationEnvironment" then
			player:SetAttribute("EnvironmentClientStatus", "server state unavailable")
			warn("[Ro-Nation:Environment] Server state unavailable; keeping the saved lighting preset.")
			return
		end
		local snapshot = readSnapshot(state)
		state:GetAttributeChangedSignal("Snapshot"):Connect(function()
			snapshot = readSnapshot(state)
		end)
		local handles = Presentation.new()
		local effects = WeatherEffects.new(Config.Effects)
		player:SetAttribute(
			"EnvironmentAudioConfigured",
			Config.Effects.Audio.Rain ~= "" and Config.Effects.Audio.Thunder ~= ""
		)
		local lights: { [Light]: boolean } = {}
		local lamps: { [BasePart]: boolean } = {}
		local function discover(instance: Instance)
			if instance:IsA("Light") and instance:GetAttribute(Config.StreetLightAttribute) == true then
				lights[instance] = true
			elseif instance:IsA("BasePart") and instance:GetAttribute(Config.LampAttribute) == true then
				lamps[instance] = true
			end
		end
		for _, instance in workspace:GetDescendants() do
			discover(instance)
		end
		workspace.DescendantAdded:Connect(discover)
		workspace.DescendantRemoving:Connect(function(instance)
			lights[instance :: any] = nil
			lamps[instance :: any] = nil
		end)
		local visual: any = nil
		local detail = quality()
		local elapsed = 1
		local lampElapsed = 1
		local visualAltitude = Config.Altitude.Base
		local altitudeInitialized = false
		player:SetAttribute("EnvironmentClientReady", true)
		player:SetAttribute(
			"EnvironmentClientStatus",
			if #handles.Skipped > 0 then "ready; custom lighting preserved" else "ready"
		)
		RunService.Heartbeat:Connect(function(dt)
			local now = workspace:GetServerTimeNow()
			local weather = Model.sample(snapshot.From, snapshot.To, snapshot.Start, snapshot.Duration, now)
			local camera = workspace.CurrentCamera
			local position = if camera then camera.CFrame.Position else Vector3.new(0, Config.Altitude.Base, 0)
			if camera and not altitudeInitialized then
				visualAltitude = position.Y
				altitudeInitialized = true
			else
				visualAltitude += (position.Y - visualAltitude) * Model.responseAlpha(
					dt,
					Config.Altitude.ResponseSeconds
				)
			end
			elapsed += dt
			lampElapsed += dt
			if elapsed >= 0.1 then
				elapsed = 0
				local clock = Model.clockAt(snapshot.Clock, snapshot.Epoch, now, snapshot.DayLength)
				visual = Presentation.apply(handles, weather, clock, visualAltitude)
			end
			if lampElapsed >= 0.5 then
				lampElapsed = 0
				detail = quality()
				local night = visual and visual.StreetLights == true
				for light in lights do
					local parent = light.Parent
					local part = if parent and parent:IsA("BasePart")
						then parent
						elseif parent and parent:IsA("Attachment") then parent.Parent
						else nil
					light.Enabled = night
						and part ~= nil
						and part:IsA("BasePart")
						and (part.Position - position).Magnitude < Config.StreetLightDistance
				end
				for lamp in lamps do
					lamp.Material = if night then Enum.Material.Neon else Enum.Material.SmoothPlastic
				end
			end
			effects:update(
				dt,
				if visual then visual.Rain else weather.Rain,
				weather.Storm,
				detail,
				now,
				numberAttribute(state, "LightningAt", 0),
				numberAttribute(state, "LightningSeed", 0)
			)
		end)
	end)
end

return Controller
