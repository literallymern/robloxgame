--!strict
-- Kagundi: mild equatorial highlands. All durations are real seconds; visual time is unrelated
-- to the economy bot's Europe/Berlin economic day. No uploaded assets are required.
return {
	Enabled = true,
	StateName = "RoNationEnvironment",
	DayLengthSeconds = 3600,
	StartClockTime = 9.5,
	Latitude = -2,
	SyncInterval = 5,
	TransitionSeconds = 75,
	WeatherHoldSeconds = { 360, 660 },
	-- nil uses the server's real UTC month. March-May and September-December are wetter.
	ClimateMonth = nil,
	WetMonths = { 3, 4, 5, 9, 10, 11, 12 },
	InitialWeather = "PartlyCloudy",
	WeatherOrder = { "Clear", "PartlyCloudy", "Overcast", "Rain", "Thunderstorm" },
	Profiles = {
		Clear = { Rain = 0, Storm = 0, Cover = 0.22, Density = 0.38, Dim = 0, Haze = 0.15 },
		PartlyCloudy = { Rain = 0, Storm = 0, Cover = 0.5, Density = 0.54, Dim = 0.12, Haze = 0.24 },
		Overcast = { Rain = 0, Storm = 0, Cover = 0.91, Density = 0.78, Dim = 0.48, Haze = 0.48 },
		Rain = { Rain = 0.55, Storm = 0, Cover = 0.97, Density = 0.86, Dim = 0.62, Haze = 0.75 },
		Thunderstorm = { Rain = 1, Storm = 1, Cover = 1, Density = 0.94, Dim = 0.78, Haze = 1 },
	},
	DryWeights = { 32, 38, 19, 9, 2 },
	WetWeights = { 12, 28, 27, 26, 7 },
	Altitude = { Base = 140, Range = 600, ExtraHaze = 0.035, RainScale = 0.15 },
	Effects = {
		MaxStreaks = 64,
		Lightning = { Enabled = true },
		-- Optional owner-supplied, licensed SoundIds. Blank means deliberately silent.
		Audio = { Rain = "", Thunder = "" },
	},
	-- LocalPlayer.EnvironmentQuality: 0 (minimal), 1 (low), 2 (medium), 3 (high).
	-- Missing attribute follows Roblox's SavedQualityLevel, including automatic mode.
	QualityAttribute = "EnvironmentQuality",
	StreetLightAttribute = "RoNationStreetLight",
	LampAttribute = "RoNationLamp",
	StreetLightDistance = 260,
}
