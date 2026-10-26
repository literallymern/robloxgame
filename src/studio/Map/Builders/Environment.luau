--!strict
-- The look of the terrain: material colours of the African highlands (red laterite earth, lush
-- green grass), river and lake water, animated grass and clouds. The light itself (sun,
-- atmosphere, bloom, colour correction) is set in default.project.json under Lighting.

local Util = require(script.Parent.Util)

local Environment = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Environment.MaterialColours = {
	Grass = rgb(104, 140, 60),
	LeafyGrass = rgb(80, 112, 48),
	Ground = rgb(150, 92, 58), -- red laterite earth
	Mud = rgb(96, 66, 46),
	Rock = rgb(122, 116, 108),
	Slate = rgb(98, 98, 102),
	Basalt = rgb(66, 64, 66),
	Sand = rgb(190, 164, 122),
	Asphalt = rgb(64, 64, 68),
	Pavement = rgb(150, 146, 138),
}

function Environment.apply(log: (string) -> ())
	local terrain = workspace.Terrain
	for name, colour in Environment.MaterialColours do
		terrain:SetMaterialColor((Enum.Material :: any)[name], colour)
	end
	-- Greenish-brown highland river water, a little murky.
	terrain.WaterColor = rgb(52, 90, 84)
	terrain.WaterTransparency = 0.35
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 6

	-- Animated grass on Grass terrain. Not every Studio version lets scripts set this.
	local ok = pcall(function()
		(terrain :: any).Decoration = true
	end)
	if not ok then
		log("Could not switch on animated grass: select Workspace > Terrain and tick Decoration.")
	end

	-- Clouds: only ours are changed; clouds you set up yourself stay as they are.
	local clouds = terrain:FindFirstChildOfClass("Clouds")
	if clouds == nil then
		local created = Instance.new("Clouds")
		Util.mark(created)
		created.Parent = terrain
		clouds = created
	end
	if clouds and Util.isGenerated(clouds) then
		clouds.Cover = 0.55
		clouds.Density = 0.7
		clouds.Color = rgb(255, 255, 255)
	end
	log("Terrain colours, water, grass and clouds set.")
end

return Environment
