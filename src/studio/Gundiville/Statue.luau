--!strict
-- Statue of Dr. Justin Wachmann, Leader of the Revolution, on the ceremonial axis of the main
-- square, facing north towards the General People's Congress (map plan P4-P6, decision D3).
-- The figure is the Owner's Roblox avatar, cast in gold and scaled to about 50 studs, on a
-- granite pedestal with bronze plaques and floodlights that the environment controller switches
-- on at night.
--
-- Where the figure comes from (first one that works):
--   1. Workspace.StatueSource: a character model placed by hand in Studio (keeps a chosen pose);
--   2. Players:CreateHumanoidModelFromUserId(UserId): the current avatar;
--   3. Players:GetHumanoidDescriptionFromUserId + CreateHumanoidModelFromDescription (R15);
--   4. otherwise a plain stone stand-in, and a warning in Output.
-- Finishes: "Gold" (decision D3, the default), "Original" (avatar colours and clothing),
-- "Bronze" or "Stone".
--
-- A character from CreateHumanoidModelFromUserId is made outside the world: its parts only line
-- up when the physics engine solves the joints, which never happens in edit mode, and each
-- accessory waits for the Humanoid to weld it on. Before the figure is anchored, `pose` puts
-- every part where its joints and attachments say; accessories that fit nowhere are removed.
-- The size is measured on the body alone, so a stray accessory cannot shrink the figure.

local Players = game:GetService("Players")
local Kit = require(script.Parent.Kit)
local Util = require(script.Parent.Parent.Map.Builders.Util)

local Statue = {}

export type Options = { Finish: string?, Source: Model? }
export type Report = { Parts: number, Loaded: boolean, Source: string, Finish: string, Height: number }

type Finish = { Material: Enum.Material, Color: Color3, Reflectance: number, Face: Color3 }

local FINISHES: { [string]: Finish? } = {
	Original = nil,
	-- Polished gold leaf: warm yellow metal that still shows the shape in shade.
	Gold = {
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(214, 170, 64),
		Reflectance = 0.12,
		Face = Color3.fromRGB(96, 66, 20),
	},
	Bronze = {
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(122, 88, 52),
		Reflectance = 0,
		Face = Color3.fromRGB(122, 88, 52),
	},
	Stone = {
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(214, 210, 200),
		Reflectance = 0,
		Face = Color3.fromRGB(214, 210, 200),
	},
}
Statue.Finishes = { "Gold", "Original", "Bronze", "Stone" }

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
				item.Material = material.Material
				item.Color = material.Color
				item.Reflectance = material.Reflectance
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
				item.Color3 = material.Face
				item.Transparency = 0.35
			end
		end
	end
end

-- Joints and accessories ----------------------------------------------------------------------

local function inAccessory(item: Instance): boolean
	return item:FindFirstAncestorWhichIsA("Accoutrement") ~= nil
end

-- Moves the parts of `figure` to where its joints say, starting at the root part:
-- Part0.CFrame * C0 = Part1.CFrame * C1 for Motor6Ds and welds. `placed` holds the parts that
-- are already in place and gains the ones the joints reach.
local function solveJoints(figure: Model, placed: { [BasePart]: boolean })
	local joints: { JointInstance } = {}
	for _, item in figure:GetDescendants() do
		if item:IsA("JointInstance") then
			table.insert(joints, item)
		end
	end
	local progress = true
	while progress do
		progress = false
		for _, joint in joints do
			local p0, p1 = joint.Part0, joint.Part1
			if not p0 or not p1 then
				continue
			end
			if placed[p0] and not placed[p1] then
				p1.CFrame = p0.CFrame * joint.C0 * joint.C1:Inverse()
				placed[p1] = true
				progress = true
			elseif placed[p1] and not placed[p0] then
				p0.CFrame = p1.CFrame * joint.C1 * joint.C0:Inverse()
				placed[p0] = true
				progress = true
			end
		end
	end
end

-- Lines the figure up and fits each accessory onto the body attachment with the same name (as
-- Humanoid:AddAccessory does). Returns the number of accessories removed because they fit nowhere.
local function pose(figure: Model): number
	local root = figure:FindFirstChild("HumanoidRootPart") or figure.PrimaryPart
	if not root or not root:IsA("BasePart") then
		return 0
	end
	local placed: { [BasePart]: boolean } = { [root] = true }
	solveJoints(figure, placed)
	local body: { [string]: Attachment } = {}
	for _, item in figure:GetDescendants() do
		local part = item.Parent
		if item:IsA("Attachment") and part and part:IsA("BasePart") and not inAccessory(item) then
			body[item.Name] = item
		end
	end
	local removed = 0
	for _, accessory in figure:GetDescendants() do
		if not accessory:IsA("Accoutrement") or accessory.Parent == nil then
			continue
		end
		local handle = accessory:FindFirstChild("Handle")
		if not handle or not handle:IsA("BasePart") then
			accessory:Destroy()
			removed += 1
			continue
		end
		if placed[handle] then
			continue -- already welded to the body
		end
		local fitted = false
		for _, own in handle:GetChildren() do
			if own:IsA("Attachment") then
				local target = body[own.Name]
				local part = target and target.Parent
				if target and part and part:IsA("BasePart") then
					handle.CFrame = part.CFrame * target.CFrame * own.CFrame:Inverse()
					placed[handle] = true
					fitted = true
					break
				end
			end
		end
		if not fitted then
			accessory:Destroy()
			removed += 1
		end
	end
	solveJoints(figure, placed) -- parts welded to the accessory handles
	return removed
end

-- The world-aligned box around the body parts (accessories left out): lowest and highest corner.
local function bodyBox(figure: Model): (Vector3, Vector3)
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	for _, part in figure:GetDescendants() do
		if not part:IsA("BasePart") or inAccessory(part) then
			continue
		end
		local frame, half = part.CFrame, part.Size / 2
		local r, u, b = frame.RightVector, frame.UpVector, -frame.LookVector
		local p = frame.Position
		local reach = {
			math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(b.X) * half.Z,
			math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(b.Y) * half.Z,
			math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(b.Z) * half.Z,
		}
		for i, centre in { p.X, p.Y, p.Z } do
			lo[i] = math.min(lo[i], centre - reach[i])
			hi[i] = math.max(hi[i], centre + reach[i])
		end
	end
	assert(lo[1] < math.huge, "Statue figure has no body parts")
	return Vector3.new(lo[1], lo[2], lo[3]), Vector3.new(hi[1], hi[2], hi[3])
end

-- Removes accessories that still float far from the body (a broken or unknown attachment).
local function pruneStrays(figure: Model): number
	local lo, hi = bodyBox(figure)
	local margin = (hi.Y - lo.Y) * 0.5
	local removed = 0
	for _, accessory in figure:GetDescendants() do
		if not accessory:IsA("Accoutrement") or accessory.Parent == nil then
			continue
		end
		local handle = accessory:FindFirstChild("Handle")
		local p = if handle and handle:IsA("BasePart") then handle.Position else nil
		if
			not p
			or p.X < lo.X - margin
			or p.X > hi.X + margin
			or p.Y < lo.Y - margin
			or p.Y > hi.Y + margin
			or p.Z < lo.Z - margin
			or p.Z > hi.Z + margin
		then
			accessory:Destroy()
			removed += 1
		end
	end
	return removed
end

-- Scales the figure so the body is `height` tall, turns it to face `facing` and stands its
-- feet on `base`. Returns the body height.
local function place(figure: Model, base: Vector3, height: number, facing: Vector3): number
	local lo, hi = bodyBox(figure)
	if hi.Y - lo.Y > 0 then
		figure:ScaleTo(figure:GetScale() * height / (hi.Y - lo.Y))
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
	lo, hi = bodyBox(figure)
	local centre = if root and root:IsA("BasePart") then root.Position else (lo + hi) / 2
	figure:PivotTo(figure:GetPivot() + Vector3.new(base.X - centre.X, base.Y - lo.Y, base.Z - centre.Z))
	return hi.Y - lo.Y
end

-- A plain stand-in when no avatar could be loaded (rebuild with BuildGundiville.statue()), in
-- the chosen finish (stone for "Original").
local function standIn(parent: Instance, base: Vector3, height: number, finish: string): Model
	local figure = Instance.new("Model")
	figure.Name = "StatueStandIn"
	figure:SetAttribute("StandIn", true)
	figure.Parent = parent
	local u = height / 6 -- one head height
	local material = FINISHES[finish] or FINISHES.Stone :: Finish
	local stone: Kit.Options =
		{ Material = material.Material, Color = material.Color, Reflectance = material.Reflectance }
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
	light.Angle = 40
	light.Range = 90
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
	assert(
		table.find(Statue.Finishes, finish),
		`Unknown statue finish {finish}; use {table.concat(Statue.Finishes, ", ")}`
	)
	local model = Kit.model(parent, "LeaderStatue", "Statue of Dr. Justin Wachmann")
	model:SetAttribute("Finish", finish)
	local before = Kit.partCount()
	local W = district.GroundY + district.WalkTop
	local platform = district.Square.StatuePlatform
	local x, z = s.Position[1], s.Position[2]
	local granite, dark = Kit.Style.Granite, Kit.Style.DarkGranite

	-- Platform with two steps, pedestal with a stepped base, die, cornice and a gold band. The
	-- pedestal scales with the figure: its die is about half as wide as the figure is tall
	-- (a standing avatar is about three quarters as wide as it is tall, arms included).
	Kit.slab(model, "Platform", platform, W - 0.2, W + 0.8, dark)
	Kit.slab(model, "Platform", Kit.inset(platform, 5), W + 0.8, W + 1.6, granite)
	local p0 = W + 1.6
	local p1 = p0 + s.PedestalHeight
	local die = math.max(9.5, s.FigureHeight * 0.26) -- half the width of the die
	Kit.box(model, "PedestalBase", x - die - 4.5, p0, z - die - 4.5, x + die + 4.5, p0 + 1.6, z + die + 4.5, dark)
	Kit.box(model, "PedestalBase", x - die - 2.5, p0 + 1.6, z - die - 2.5, x + die + 2.5, p0 + 3.2, z + die + 2.5, dark)
	Kit.box(model, "PedestalPlinth", x - die - 1, p0 + 3.2, z - die - 1, x + die + 1, p0 + 4.4, z + die + 1, granite)
	Kit.box(model, "Pedestal", x - die, p0 + 4.4, z - die, x + die, p1 - 2.6, z + die, granite)
	Kit.box(
		model,
		"PedestalBand",
		x - die - 0.3,
		p1 - 2.6,
		z - die - 0.3,
		x + die + 0.3,
		p1 - 2.1,
		z + die + 0.3,
		Kit.Style.Gold
	)
	Kit.box(model, "PedestalCornice", x - die - 1.6, p1 - 2.1, z - die - 1.6, x + die + 1.6, p1, z + die + 1.6, dark)
	-- Bronze plaques on the north face (below the figure's gaze) and the south face (avenue).
	local plaqueHalf = math.min(die - 2, 8)
	for _, side in { -1, 1 } do
		local face = z + side * die
		local plaque = Kit.box(
			model,
			"Plaque",
			x - plaqueHalf,
			p0 + 6,
			face,
			x + plaqueHalf,
			p0 + 6 + plaqueHalf,
			face + side * 0.2,
			Kit.Style.Bronze
		)
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
	local height = s.FigureHeight
	if figure then
		figure.Name = "Figure"
		local removed = pose(figure)
		petrify(figure, finish)
		figure.Parent = model
		removed += pruneStrays(figure)
		if removed > 0 then
			local noun = if removed == 1 then "accessory" else "accessories"
			print(
				`[Ro-Nation:BuildGundiville] Statue: {removed} {noun} of the avatar fit nowhere on the body and were left out.`
			)
		end
		height = place(figure, base, s.FigureHeight, NORTH)
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
		figure = standIn(model, base, s.FigureHeight, finish)
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
	model:SetAttribute("FigureHeight", height)

	-- Floodlights on the corners of the upper platform step, aimed at the chest of the figure.
	local chest = base + Vector3.new(0, s.FigureHeight * 0.6, 0)
	local reach = (platform.MaxX - platform.MinX) / 2 - 7
	for _, dx in { -1, 1 } do
		for _, dz in { -1, 1 } do
			local p = Vector3.new(x + dx * reach, W + 2.4, z + dz * reach)
			Kit.box(model, "FloodlightBase", p.X - 0.8, W + 1.6, p.Z - 0.8, p.X + 0.8, W + 1.8, p.Z + 0.8, dark)
			floodlight(model, p, chest)
		end
	end
	return {
		Parts = Kit.partCount() - before,
		Loaded = loaded,
		Source = source,
		Finish = finish,
		Height = height,
	}
end

return Statue
