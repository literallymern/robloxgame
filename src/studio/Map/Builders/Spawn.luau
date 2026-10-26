--!strict
-- The spawn for new players at the Gundiville bus terminal. Also removes the template's
-- Baseplate and SpawnLocation, which would end up buried inside the new terrain.

local Util = require(script.Parent.Util)

local Spawn = {}

function Spawn.removeTemplateObjects(log: (string) -> ())
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") and not Util.isGenerated(baseplate) then
		baseplate:Destroy()
		log("Removed the template Baseplate (it would sit inside the terrain).")
	end
	local oldSpawn = workspace:FindFirstChild("SpawnLocation")
	if oldSpawn and oldSpawn:IsA("SpawnLocation") and not Util.isGenerated(oldSpawn) then
		oldSpawn:Destroy()
		log("Removed the template SpawnLocation at the origin (it would sit inside the terrain).")
	end
end

function Spawn.build(layout: any): SpawnLocation
	local spawns = Util.container(workspace, "Spawns")
	Util.clearGenerated(spawns)
	local config = layout.Spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = config.Name
	spawn.Anchored = true
	spawn.Size = Vector3.new(config.Size, 1, config.Size)
	-- On top of the bus terminal slab, whose surface is 0.2 above the ground.
	spawn.CFrame = CFrame.new(config.Centre[1], config.GroundY + 0.2 + 0.5, config.Centre[2])
	spawn.Neutral = true
	spawn.Duration = 0 -- no spawn force field in a roleplay game
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = Color3.fromRGB(70, 110, 160)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	Util.mark(spawn)
	spawn.Parent = spawns
	return spawn
end

return Spawn
