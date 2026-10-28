--!strict
-- One weather schedule per server. Only small state attributes and the baseline clock replicate;
-- rain, light interpolation and distance-limited streetlights run on each client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config.Environment)
local Model = require(ReplicatedStorage.Shared.Environment.Model)

local Service = {}
local state: Folder? = nil
local random = Random.new()
local from: Model.Weather = Config.Profiles[Config.InitialWeather]
local target: Model.Weather = from
local targetName = Config.InitialWeather
local transitionStart = 0
local revision = 0
local nextChange = math.huge
local nextLightning = math.huge
local clock = Config.StartClockTime
local epoch = 0
local started = false

local function publish()
	local folder = state
	if not folder then
		return
	end
	for _, key in Model.Keys do
		folder:SetAttribute("From" .. key, (from :: any)[key])
		folder:SetAttribute("To" .. key, (target :: any)[key])
	end
	folder:SetAttribute("Weather", targetName)
	folder:SetAttribute("TransitionStart", transitionStart)
	folder:SetAttribute("TransitionSeconds", Config.TransitionSeconds)
	folder:SetAttribute("Clock", clock)
	folder:SetAttribute("ClockEpoch", epoch)
	folder:SetAttribute("DayLengthSeconds", Config.DayLengthSeconds)
	revision += 1
	folder:SetAttribute("Revision", revision)
	-- One serialized attribute is an atomic snapshot even if independent attributes replicate
	-- in a different order. Inspector attributes above are informational only.
	folder:SetAttribute(
		"Snapshot",
		HttpService:JSONEncode({
			From = from,
			To = target,
			Start = transitionStart,
			Duration = Config.TransitionSeconds,
			Clock = clock,
			Epoch = epoch,
			DayLength = Config.DayLengthSeconds,
		})
	)
end

-- Server/Studio console only; no client remote can force weather or time.
function Service.setWeather(name: string): boolean
	local profile = Config.Profiles[name]
	if not profile or not state then
		return false
	end
	local now = workspace:GetServerTimeNow()
	from = Model.sample(from, target, transitionStart, Config.TransitionSeconds, now)
	target = profile
	targetName = name
	transitionStart = now
	nextChange = now
		+ Config.TransitionSeconds
		+ random:NextNumber(Config.WeatherHoldSeconds[1], Config.WeatherHoldSeconds[2])
	publish()
	return true
end

function Service.setClockTime(hour: number): boolean
	if hour ~= hour or hour == math.huge or hour == -math.huge or not state then
		return false
	end
	clock = hour % 24
	epoch = workspace:GetServerTimeNow()
	publish()
	return true
end

function Service.init()
	if not Config.Enabled or state then
		return
	end
	local folder: Folder
	local existing = ReplicatedStorage:FindFirstChild(Config.StateName)
	if existing then
		assert(
			existing:IsA("Folder") and existing:GetAttribute("ManagedBy") == "RoNationEnvironment",
			"Environment state name is occupied by another system"
		)
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = Config.StateName
		folder:SetAttribute("ManagedBy", "RoNationEnvironment")
	end
	state = folder
	epoch = workspace:GetServerTimeNow()
	transitionStart = epoch - Config.TransitionSeconds
	nextChange = epoch + random:NextNumber(Config.WeatherHoldSeconds[1], Config.WeatherHoldSeconds[2])
	nextLightning = epoch + random:NextNumber(18, 35)
	publish()
	folder.Parent = ReplicatedStorage
	Lighting.GeographicLatitude = Config.Latitude
	Lighting.ClockTime = clock
end

function Service.start()
	if not state or started then
		return
	end
	started = true
	while started do
		local now = workspace:GetServerTimeNow()
		Lighting.ClockTime = Model.clockAt(clock, epoch, now, Config.DayLengthSeconds)
		if now >= nextChange then
			local month = Config.ClimateMonth or os.date("!*t").month
			local weights = if Model.isWetMonth(month, Config.WetMonths) then Config.WetWeights else Config.DryWeights
			Service.setWeather(Model.nextWeather(Config.WeatherOrder, weights, targetName, random:NextNumber()))
		end
		if now >= nextLightning then
			local weather = Model.sample(from, target, transitionStart, Config.TransitionSeconds, now)
			if weather.Storm > 0.55 then
				local folder = state :: Folder
				folder:SetAttribute("LightningSeed", random:NextInteger(1, 1000000))
				folder:SetAttribute("LightningAt", now + 0.75)
			end
			nextLightning = now + random:NextNumber(18, 40)
		end
		task.wait(Config.SyncInterval)
	end
end

return Service
