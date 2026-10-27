--!strict
-- Pure math checks, not a Roblox Studio rendering/physics test.
local Config = require("../../src/shared/Config/Environment")
local Model = require("../../src/shared/Environment/Model")
local passed = 0
local function check(value: boolean, message: string)
	assert(value, message)
	passed += 1
	print("PASS " .. message)
end
local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-8
end

check(near(Model.clockAt(23, 100, 400, 3600), 1), "clock wraps through midnight")
check(near(Model.clockAt(9.5, 200, 200, 3600), 9.5), "late client reconstructs the epoch clock")
check(near(Model.clockAt(9.5, 200, 3800, 3600), 9.5), "full day cycle returns to initial time")
local clear = Config.Profiles.Clear
local rain = Config.Profiles.Rain
local storm = Config.Profiles.Thunderstorm
check(near(Model.sample(clear, rain, 100, 75, 25).Rain, 0), "transition clamps before its start")
check(near(Model.sample(clear, rain, 100, 75, 175).Rain, rain.Rain), "transition reaches its target")
check(
	near(Model.sample(clear, rain, 100, 75, 137.5).Rain, rain.Rain / 2),
	"rain blends gradually at the transition midpoint"
)
local interrupted = Model.sample(clear, rain, 100, 75, 122)
check(
	near(Model.sample(interrupted, storm, 122, 75, 122).Rain, interrupted.Rain),
	"manual weather interruption is continuous"
)
check(Model.sample(clear, rain, 0, 75, 0.01).Rain < 0.00001, "transition starts without an abrupt slope")
local noon = Model.lighting(12, clear, 140, Config.Altitude)
local night = Model.lighting(0, clear, 140, Config.Altitude)
local cloudy = Model.lighting(12, Config.Profiles.Overcast, 140, Config.Altitude)
local cloudyEvening = Model.lighting(18, Config.Profiles.Overcast, 140, Config.Altitude)
check(
	noon.Brightness > cloudy.Brightness and cloudy.Brightness > night.Brightness,
	"overcast softens daylight while night remains darker"
)
check(night.StreetLights and not noon.StreetLights, "streetlights follow the day/night cycle")
check(night.Ambient[3] > 0.1 and night.Brightness > 0, "night retains navigable ambient and moonlight")
check(near(Config.Profiles.Overcast.Cover, 0.91) and cloudyEvening.Haze > noon.Haze, "overcast is retained at sunset")
local high = Model.lighting(12, rain, 740, Config.Altitude)
local low = Model.lighting(12, rain, 140, Config.Altitude)
check(high.Density > low.Density and high.Rain < low.Rain, "altitude changes local mist and precipitation intensity")
local morning = Model.lighting(7.5, clear, 140, Config.Altitude)
local afternoon = Model.lighting(16.5, clear, 140, Config.Altitude)
check(
	morning.Density > afternoon.Density and morning.Haze > afternoon.Haze,
	"morning valley mist clears instead of persisting through the afternoon"
)
local withoutMist = table.clone(Config.Altitude)
withoutMist.MorningMistDensity = 0
withoutMist.MorningMistHaze = 0
local dryBoost = morning.Density - Model.lighting(7.5, clear, 140, withoutMist).Density
local wetBoost = Model.lighting(7.5, rain, 140, Config.Altitude).Density
	- Model.lighting(7.5, rain, 140, withoutMist).Density
check(wetBoost > dryBoost and dryBoost > 0, "morning mist responds to humidity without replacing weather")
check(
	near(night.Density, Model.lighting(0, clear, 140, withoutMist).Density),
	"morning mist does not brighten or fog the night"
)
local function altitudeResponse(steps: number): number
	local value = 140
	for _ = 1, steps do
		value += (740 - value) * Model.responseAlpha(2 / steps, 2.5)
	end
	return value
end
check(near(altitudeResponse(30), altitudeResponse(120)), "altitude response is independent of rendering frame rate")
check(
	Model.responseAlpha(0, 2.5) == 0 and Model.responseAlpha(1 / 60, 2.5) > 0 and Model.responseAlpha(1 / 60, 2.5) < 1,
	"altitude smoothing starts continuously and remains bounded"
)
check(
	Model.isWetMonth(4, Config.WetMonths) and not Model.isWetMonth(7, Config.WetMonths),
	"highland rainy seasons use the configured months"
)
for i, name in Config.WeatherOrder do
	for n = 0, 100 do
		local nextName = Model.nextWeather(Config.WeatherOrder, Config.WetWeights, name, n / 101)
		local nextIndex = table.find(Config.WeatherOrder, nextName) :: number
		assert(math.abs(i - nextIndex) <= 1, "weather skipped a neighbouring state")
	end
end
check(true, "weather schedule moves only between neighbouring conditions")
for _, profile in Config.Profiles do
	for step = 0, 240 do
		local value = Model.lighting(step / 10, profile, 740, Config.Altitude)
		assert(value.Density >= 0 and value.Density <= 1)
		assert(value.Brightness > 0 and value.Brightness < 4)
		assert(value.Rain >= 0 and value.Rain <= 1)
		assert(value.Day >= 0 and value.Day <= 1)
		for _, rgb in { value.Ambient, value.OutdoorAmbient, value.AtmosphereColor, value.CloudColor, value.Tint } do
			for _, channel in rgb do
				assert(channel == channel and channel >= 0 and channel <= 1, "invalid colour channel")
			end
		end
	end
end
check(true, "all five weather profiles stay finite and within valid rendering ranges across 24 hours")
print(`ALL CHECKS PASSED ({passed} environment checks)`)
