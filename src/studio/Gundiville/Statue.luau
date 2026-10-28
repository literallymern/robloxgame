--!strict
-- Statue of Dr. Justin Wachmann, Leader of the Revolution, on the ceremonial axis of the main
-- square, facing north towards the General People's Congress (map plan P4-P6, decision D3).
-- The figure is the Owner's Roblox avatar, scaled to about 30 studs, on a granite pedestal with
-- bronze plaques and floodlights that the environment controller switches on at night.
--
-- Where the figure comes from (first one that works):
--   1. Workspace.StatueSource: a character model placed by hand in Studio (keeps a chosen pose);
--   2. Players:CreateHumanoidModelFromUserId(UserId): the current avatar;
--   3. Players:GetHumanoidDescriptionFromUserId + CreateHumanoidModelFromDescription (R15);
--   4. otherwise a plain stone stand-in, and a warning in Output.
-- Finishes: "Original" (avatar colours and clothing, proposal P5), "Bronze" or "Stone".

local Players = game:GetService("Players")
local Kit = require(script.Parent.Kit)
local Util = require(script.Parent.Parent.Map.Builders.Util)

local Statue = {}

export type Options = { Finish: string?, Source: Model? }
export type Report = { Parts: number, Loaded: boolean, Source: string, Finish: string, Height: number }

local FINISHES: { [string]: Kit.Options? } = {
	Original = nil,
	Bronze = { Material = Enum.Material.Metal, Color = Color3.fromRGB(122, 88, 52) },
	Stone = { Material = Enum.Material.Marble, Color = Color3.fromRGB(214, 210, 200) },
}
Statue.Finishes = { "Original", "Bronze", "Stone" }

local NORTH = Vector3.new(0, 0, -1)

-- Loads the figure. Returns the model (not parented) and a description of its source.
function Statue.loadFigure(userId: number, source: Model?): (Model?, string)
	local manual = source or workspace:FindFirstChild("StatueSource")
	if manual and manual:IsA("Model") then
		return manual:Clone(), "Workspace.StatueSource"
	end
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromUserId(userId)
	end)
	if ok and result then
		return result, `avatar of user {userId}`
	end
	local problem = tostring(result)
	local described, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(userId)
	end)
	if described and description then
		local built, rig = pcall(function()
			return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		end)
		if built and rig then
			return rig, `avatar description of user {userId}`
		end
		problem = tostring(rig)
	end
	return nil, problem
end

-- Turns a character into a statue: no scripts, no name or health display, everything anchored
-- and without collision (an invisible block around the figure collides instead).
local function petrify(figure: Model, finish: string)
	for _, item in figure:GetDescendants() do
		if item:IsA("LuaSourceContainer") then
			item:Destroy()
		end
	end
	local humanoid = figure:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- The humanoid stays: Roblox only draws 2D clothing on a model that has one.
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.EvaluateStateMachine = false
	end
	local material = FINISHES[finish]
	for _, item in figure:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanTouch = false
			item.CastShadow = true
			if material then
				item.Material = material.Material or Enum.Material.Marble
				item.Color = material.Color or Color3.fromRGB(214, 210, 200)
				if item:IsA("MeshPart") then
					item.TextureID = ""
				end
			end
		elseif material then
			if
				item:IsA("Shirt")
				or item:IsA("Pants")
				or item:IsA("ShirtGraphic")
				or item:IsA("BodyColors")
				or item:IsA("SurfaceAppearance")
			then
				item:Destroy()
			elseif item:IsA("SpecialMesh") then
				item.TextureId = ""
			elseif item:IsA("Decal") then
				-- Keep the face, tinted like carved or cast features.
				item.Color3 = material.Color or Color3.fromRGB(214, 210, 200)
				item.Transparency = 0.35
			end
		end
	end
end

-- Scales the figure to `height`, turns it to face `facing` and stands it on `base`.
local function place(figure: Model, base: Vector3, height: number, facing: Vector3)
	local _, size = figure:GetBoundingBox()
	if size.Y > 0 then
		figure:ScaleTo(figure:GetScale() * height / size.Y)
	end
	local root = figure:FindFirstChild("HumanoidRootPart") or figure.PrimaryPart
	if root and root:IsA("BasePart") then
		local current = root.CFrame
		local wanted = CFrame.lookAt(current.Position, current.Position + facing)
		figure:PivotTo(wanted * current:Inverse() * figure:GetPivot())
	else
		local pivot = figure:GetPivot()
		figure:PivotTo(CFrame.lookAt(pivot.Position, pivot.Position + facing))
	end
	local box, extents = figure:GetBoundingBox()
	local centre = if root and root:IsA("BasePart") then root.Position else box.Position
	local bottom = box.Position.Y - extents.Y / 2
	figure:PivotTo(figure:GetPivot() + Vector3.new(base.X - centre.X, base.Y - bottom, base.Z - centre.Z))
end

-- A plain stone stand-in when no avatar could be loaded (rebuild with BuildGundiville.statue()).
local function standIn(parent: Instance, base: Vector3, height: number): Model
	local figure = Instance.new("Model")
	figure.Name = "StatueStandIn"
	figure:SetAttribute("StandIn", true)
	figure.Parent = parent
	local u = height / 6 -- one head height
	local stone = FINISHES.Stone :: Kit.Options
	local x, y, z = base.X, base.Y, base.Z
	Kit.box(figure, "Leg", x - u * 0.9, y, z - u * 0.4, x - u * 0.1, y + u * 2.8, z + u * 0.4, stone)
	Kit.box(figure, "Leg", x + u * 0.1, y, z - u * 0.4, x + u * 0.9, y + u * 2.8, z + u * 0.4, stone)
	Kit.box(figure, "Torso", x - u, y + u * 2.8, z - u * 0.5, x + u, y + u * 4.9, z + u * 0.5, stone)
	Kit.box(figure, "Arm", x - u * 1.8, y + u * 2.6, z - u * 0.4, x - u, y + u * 4.9, z + u * 0.4, stone)
	Kit.box(figure, "Arm", x + u, y + u * 2.6, z - u * 0.4, x + u * 1.8, y + u * 4.9, z + u * 0.4, stone)
	Kit.box(figure, "Head", x - u * 0.5, y + u * 4.95, z - u * 0.5, x + u * 0.5, y + u * 6, z + u * 0.5, stone)
	return figure
end

local function floodlight(parent: Instance, position: Vector3, target: Vector3)
	local frame = CFrame.lookAt(position, target)
	Util.part(parent, "FloodlightHousing", frame * CFrame.new(0, 0, 0.6), Vector3.new(1.8, 1.4, 1.2), Kit.Style.Iron)
	local lens = Util.part(
		parent,
		"FloodlightLens",
		frame,
		Vector3.new(1.5, 1.1, 0.2),
		{ Material = Enum.Material.Glass, Color = Color3.fromRGB(250, 238, 210), CastShadow = false }
	)
	lens:SetAttribute("RoNationLamp", true)
	local light = Instance.new("SpotLight")
	light:SetAttribute("RoNationStreetLight", true)
	light.Enabled = false -- switched by the environment controller at dusk
	light.Face = Enum.NormalId.Front
	light.Angle = 45
	light.Range = 60
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 236, 206)
	light.Shadows = false
	light.Parent = lens
	Kit.add(2)
end

function Statue.build(district: any, parent: Instance, options: Options?): Report
	local opts: Options = options or {}
	local s = district.Statue
	local finish = opts.Finish or s.Finish
	assert(table.find(Statue.Finishes, finish), `Unknown statue finish {finish}; use Original, Bronze or Stone`)
	local model = Kit.model(parent, "LeaderStatue", "Statue of Dr. Justin Wachmann")
	model:SetAttribute("Finish", finish)
	local before = Kit.partCount()
	local W = district.GroundY + district.WalkTop
	local platform = district.Square.StatuePlatform
	local x, z = s.Position[1], s.Position[2]
	local granite, dark = Kit.Style.Granite, Kit.Style.DarkGranite

	-- Platform with two steps, pedestal with base, die and cornice.
	Kit.slab(model, "Platform", platform, W - 0.2, W + 0.8, dark)
	Kit.slab(model, "Platform", Kit.inset(platform, 5), W + 0.8, W + 1.6, granite)
	local p0 = W + 1.6
	local p1 = p0 + s.PedestalHeight
	-- About as wide as the figure's shoulders, so the statue does not look top-heavy.
	Kit.box(model, "PedestalBase", x - 13, p0, z - 13, x + 13, p0 + 2.4, z + 13, dark)
	Kit.box(model, "Pedestal", x - 9.5, p0 + 2.4, z - 9.5, x + 9.5, p1 - 2, z + 9.5, granite)
	Kit.box(model, "PedestalCornice", x - 11, p1 - 2, z - 11, x + 11, p1, z + 11, dark)
	-- Bronze plaques on the north face (below the figure's gaze) and the south face (avenue).
	for _, side in { -1, 1 } do
		local face = z + side * 9.5
		local plaque =
			Kit.box(model, "Plaque", x - 5.5, p0 + 4, face, x + 5.5, p0 + 9.5, face + side * 0.2, Kit.Style.Bronze)
		Kit.inscription(
			plaque,
			s.Inscription,
			Color3.fromRGB(240, 220, 170),
			if side < 0 then Enum.NormalId.Front else Enum.NormalId.Back
		)
	end

	-- The figure.
	local base = Vector3.new(x, p1, z)
	local figure, source = Statue.loadFigure(s.UserId, opts.Source)
	local loaded = figure ~= nil
	if figure then
		figure.Name = "Figure"
		petrify(figure, finish)
		figure.Parent = model
		place(figure, base, s.FigureHeight, NORTH)
		local n = 0
		for _, item in figure:GetDescendants() do
			if item:IsA("BasePart") then
				n += 1
			end
		end
		Kit.add(n)
	else
		warn(
			`[Ro-Nation:BuildGundiville] Statue avatar could not be loaded ({source}). A stone stand-in was placed. `
				.. "Fix: insert the avatar as Workspace.StatueSource (see the Milestone 3 guide), then run BuildGundiville.statue()."
		)
		figure = standIn(model, base, s.FigureHeight)
		source = "stand-in"
	end
	local fig = figure :: Model
	local box, extents = fig:GetBoundingBox()
	-- One invisible block collides instead of the many figure parts.
	Util.part(
		model,
		"Collider",
		box,
		Vector3.new(math.max(2, extents.X * 0.7), extents.Y, math.max(2, extents.Z * 0.7)),
		{
			Transparency = 1,
			CastShadow = false,
		}
	)
	Kit.add(1)
	model:SetAttribute("Source", source)
	model:SetAttribute("FigureHeight", extents.Y)

	-- Floodlights on the corners of the upper platform step, aimed at the chest of the figure.
	local chest = base + Vector3.new(0, s.FigureHeight * 0.6, 0)
	for _, dx in { -1, 1 } do
		for _, dz in { -1, 1 } do
			local p = Vector3.new(x + dx * 22, W + 2.4, z + dz * 22)
			Kit.box(model, "FloodlightBase", p.X - 0.8, W + 1.6, p.Z - 0.8, p.X + 0.8, W + 1.8, p.Z + 0.8, dark)
			floodlight(model, p, chest)
		end
	end
	return {
		Parts = Kit.partCount() - before,
		Loaded = loaded,
		Source = source,
		Finish = finish,
		Height = extents.Y,
	}
end

return Statue
