--!strict
-- Deterministic math only: shared by server/client and exercised outside Roblox Studio.
local Model = {}

export type Weather = {
	Rain: number,
	Storm: number,
	Cover: number,
	Density: number,
	Dim: number,
	Haze: number,
}

Model.Keys = { "Rain", "Storm", "Cover", "Density", "Dim", "Haze" }

function Model.smoothstep(value: number): number
	local t = math.clamp(value, 0, 1)
	return t * t * (3 - 2 * t)
end

function Model.clockAt(clock: number, epoch: number, now: number, dayLength: number): number
	return (clock + (now - epoch) * 24 / math.max(1, dayLength)) % 24
end

-- Exponential response has the same result at different frame rates. Used for local camera
-- altitude and sound fades; a camera cut must not instantly change the atmosphere.
function Model.responseAlpha(dt: number, responseSeconds: number): number
	if dt <= 0 then
		return 0
	end
	if responseSeconds <= 0 then
		return 1
	end
	return 1 - math.exp(-dt / responseSeconds)
end

function Model.blend(from: Weather, to: Weather, alpha: number): Weather
	local t = Model.smoothstep(alpha)
	local result: any = {}
	for _, key in Model.Keys do
		result[key] = from[key] + (to[key] - from[key]) * t
	end
	return result
end

function Model.sample(from: Weather, to: Weather, start: number, duration: number, now: number): Weather
	return Model.blend(from, to, (now - start) / math.max(0.01, duration))
end

function Model.isWetMonth(month: number, wetMonths: { number }): boolean
	return table.find(wetMonths, month) ~= nil
end

-- Weighted Markov choice: large changes move through neighbouring states, keeping a bright
-- clear sky from becoming a thunderstorm at the next update. roll is in [0,1).
function Model.nextWeather(order: { string }, weights: { number }, current: string, roll: number): string
	local index = table.find(order, current) or 2
	local low, high = math.max(1, index - 1), math.min(#order, index + 1)
	local total = 0
	for i = low, high do
		total += weights[i]
	end
	local target = math.clamp(roll, 0, 0.999999) * total
	for i = low, high do
		target -= weights[i]
		if target < 0 then
			return order[i]
		end
	end
	return order[high]
end

function Model.lighting(clock: number, weather: Weather, altitude: number, altitudeConfig: any): any
	local hour = clock % 24
	local solar = math.sin((hour - 6) * math.pi / 12)
	local day = Model.smoothstep((solar + 0.1) / 0.38)
	local horizon = (1 - math.clamp(math.abs(solar) / 0.4, 0, 1)) * day
	local warm = horizon * (1 - weather.Dim) -- overcast evenings retain a grey cloud layer
	local height = math.clamp((altitude - altitudeConfig.Base) / altitudeConfig.Range, 0, 1)
	local dim = weather.Dim
	local morning = math.exp(-((hour - 7.1) / 1.55) ^ 2) * day
	local moisture = 0.35 + 0.65 * weather.Haze
	local valleyMist = morning * moisture * (1 - 0.55 * height)
	return {
		Day = day,
		Brightness = 0.35 + day * (2.05 - 1.25 * dim),
		Exposure = -0.12 - 0.08 * dim,
		Ambient = { 0.105 + day * 0.12, 0.12 + day * 0.12, 0.16 + day * 0.095 },
		OutdoorAmbient = {
			0.14 + day * (0.24 - 0.075 * dim),
			0.16 + day * (0.23 - 0.07 * dim),
			0.21 + day * (0.18 - 0.06 * dim),
		},
		SunTint = { warm * 0.09, warm * 0.035, 0 },
		Density = 0.21
			+ 0.105 * weather.Haze
			+ height * altitudeConfig.ExtraHaze
			+ valleyMist * (altitudeConfig.MorningMistDensity or 0.025),
		Haze = 0.65 + weather.Haze * 1.65 + horizon * 0.3 + valleyMist * (altitudeConfig.MorningMistHaze or 0.24),
		Glare = (0.08 + horizon * 0.08) * (1 - dim) * day,
		AtmosphereColor = { 0.72 + day * 0.08 + warm * 0.045, 0.77 + day * 0.06, 0.84 + day * 0.035 - warm * 0.06 },
		Decay = { 0.38 + warm * 0.08, 0.43, 0.51 - warm * 0.06 },
		CloudColor = {
			0.55 + day * (0.42 - 0.16 * dim),
			0.59 + day * (0.39 - 0.17 * dim),
			0.66 + day * (0.33 - 0.18 * dim),
		},
		Saturation = -0.065 - dim * 0.04,
		Contrast = 0.055 - dim * 0.025,
		Tint = { 1, 0.995 - warm * 0.012, 0.985 - warm * 0.025 },
		SunRays = 0.025 * day * (1 - dim),
		Rain = weather.Rain * (1 - height * altitudeConfig.RainScale),
		StreetLights = day < 0.24,
	}
end

return Model
