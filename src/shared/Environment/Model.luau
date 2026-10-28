--!strict
-- Deterministic math only: shared by server/client and exercised outside Roblox Studio.
local Model = {}
Model.VisualRevision = "neutral-highland-2"

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
		Brightness = 0.35 + day * (1.95 - 1.15 * dim),
		Exposure = -0.12 + day * 0.06 - 0.08 * dim,
		Ambient = { 0.105 + day * 0.135, 0.12 + day * 0.13, 0.16 + day * 0.11 },
		OutdoorAmbient = {
			0.14 + day * (0.21 - 0.055 * dim),
			0.16 + day * (0.20 - 0.05 * dim),
			0.21 + day * (0.16 - 0.045 * dim),
		},
		SunTint = { warm * 0.09, warm * 0.035, 0 },
		Density = 0.105
			+ 0.12 * weather.Haze
			+ height * altitudeConfig.ExtraHaze
			+ valleyMist * (altitudeConfig.MorningMistDensity or 0.025),
		Haze = 0.14 + weather.Haze * 1.05 + horizon * 0.2 + valleyMist * (altitudeConfig.MorningMistHaze or 0.24),
		Glare = (0.08 + horizon * 0.08) * (1 - dim) * day,
		AtmosphereColor = { 0.76 + day * 0.12 + warm * 0.04, 0.78 + day * 0.1, 0.82 + day * 0.045 - warm * 0.06 },
		Decay = { 0.54 + warm * 0.08, 0.56, 0.58 - warm * 0.06 },
		CloudColor = {
			0.55 + day * (0.42 - 0.16 * dim),
			0.59 + day * (0.39 - 0.17 * dim),
			0.66 + day * (0.33 - 0.18 * dim),
		},
		Saturation = -0.065 - dim * 0.04,
		Contrast = 0.03 - dim * 0.015,
		Tint = { 1, 0.995 - warm * 0.012, 0.985 - warm * 0.025 },
		SunRays = 0.025 * day * (1 - dim),
		Rain = weather.Rain * (1 - height * altitudeConfig.RainScale),
		StreetLights = day < 0.24,
	}
end

return Model
