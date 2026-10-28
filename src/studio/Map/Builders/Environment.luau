--!strict
-- The same natural highland preset is used in Studio and by the runtime weather controller.
-- This edits surface appearance only; it never clears terrain or rebuilds map objects.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.Environment)
local Presentation = require(ReplicatedStorage.Shared.Environment.Presentation)

local Environment = {}
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Environment.MaterialColours = {
	Grass = rgb(99, 117, 70),
	LeafyGrass = rgb(83, 105, 61),
	Ground = rgb(130, 88, 62), -- damp lateritic highland soil
	Mud = rgb(88, 68, 51),
	Rock = rgb(115, 112, 103),
	Slate = rgb(94, 96, 98),
	Basalt = rgb(65, 66, 64),
	Sand = rgb(170, 151, 116),
	Asphalt = rgb(64, 65, 66),
	Pavement = rgb(142, 140, 132),
}

function Environment.apply(log: (string) -> ())
	local terrain = workspace.Terrain
	for name, colour in Environment.MaterialColours do
		terrain:SetMaterialColor((Enum.Material :: any)[name], colour)
	end
	terrain.WaterColor = rgb(57, 84, 76)
	terrain.WaterTransparency = 0.32
	terrain.WaterReflectance = 0.22
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 5
	-- Decoration is NotScriptable, including from Rojo's plugin. Keep the saved setting;
	-- enable it once in Studio's Terrain Properties instead of attempting a forbidden write.
	local skipped: { string } = {}
	if Config.Enabled then
		-- A previously saved place may still contain the original project's strong bloom
		-- and saturation. Only exact old project presets are migrated; custom edits stay.
		Presentation.migrateLegacy(log)
		local handles = Presentation.new()
		skipped = handles.Skipped
		Presentation.apply(handles, Config.Profiles[Config.InitialWeather], Config.StartClockTime, Config.Altitude.Base)
	else
		table.insert(skipped, "Lighting disabled by Config.Environment.Enabled")
	end
	log("Terrain colours and river water set; natural lighting preset applied where available.")
	if #skipped > 0 then
		log(`Lighting controls skipped: {table.concat(skipped, ", ")}. See Output warnings for conflicts.`)
	end
	return skipped
end

return Environment
