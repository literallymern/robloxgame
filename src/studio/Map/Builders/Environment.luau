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
	Grass = rgb(91, 117, 65),
	LeafyGrass = rgb(67, 96, 55),
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
	local ok = pcall(function()
		(terrain :: any).Decoration = true
	end)
	if not ok then
		log("Could not switch on animated grass: select Workspace > Terrain and tick Decoration.")
	end
	if Config.Enabled then
		Presentation.apply(
			Presentation.new(),
			Config.Profiles[Config.InitialWeather],
			Config.StartClockTime,
			Config.Altitude.Base
		)
	end
	log("Natural highland lighting, terrain colours, river water, grass and clouds set.")
end

return Environment
