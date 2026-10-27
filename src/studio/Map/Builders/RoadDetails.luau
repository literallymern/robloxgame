--!strict
-- Builds everything along the roads from Map/RoadDetails: markings, marker posts, guard rails,
-- street lights, signs and power lines.

local Signs = require(script.Parent.Signs)
local Util = require(script.Parent.Util)

local RoadDetailsBuilder = {}

local UP = Vector3.new(0, 1, 0)
local LINE_WHITE = Color3.fromRGB(236, 236, 228)

local function markings(details: any, parent: Instance): number
	local folder = Instance.new("Folder")
	folder.Name = "Markings"
	local options: Util.PartOptions = {
		Material = Enum.Material.SmoothPlastic,
		Color = LINE_WHITE,
		Decoration = true,
	}
	for _, m in details.markings do
		local a = Vector3.new(m.AX, m.AY, m.AZ)
		local b = Vector3.new(m.BX, m.BY, m.BZ)
		if (b - a).Magnitude > 0.2 then
			Util.strip(folder, m.Kind, a, b, m.Width, 0.1, options)
		end
		Util.yield()
	end
	folder.Parent = parent
	return #folder:GetChildren()
end

local function delineators(details: any, parent: Instance): number
	local folder = Instance.new("Folder")
	folder.Name = "MarkerPosts"
	local white: Util.PartOptions = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(240, 240, 236) }
	local band: Util.PartOptions = {
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(28, 28, 28),
		CanCollide = false,
		CastShadow = false,
	}
	local count = 0
	for _, p in details.delineators do
		local look = CFrame.lookAt(Vector3.new(p.X, 0, p.Z), Vector3.new(p.X + p.DirX, 0, p.Z + p.DirZ))
		local rotation = look - look.Position
		Util.part(folder, "Post", CFrame.new(p.X, p.Y + 1.2, p.Z) * rotation, Vector3.new(0.45, 3.6, 0.3), white)
		Util.part(folder, "Band", CFrame.new(p.X, p.Y + 2.4, p.Z) * rotation, Vector3.new(0.5, 0.7, 0.34), band)
		count += 2
		Util.yield()
	end
	folder.Parent = parent
	return count
end

local function rails(details: any, parent: Instance): number
	local folder = Instance.new("Folder")
	folder.Name = "GuardRails"
	local steel: Util.PartOptions = { Material = Enum.Material.Metal, Color = Color3.fromRGB(170, 172, 176) }
	local postOptions: Util.PartOptions = { Material = Enum.Material.Metal, Color = Color3.fromRGB(120, 122, 126) }
	local count = 0
	for _, rail in details.rails do
		for _, piece in rail.Pieces do
			local a = Vector3.new(piece[1], piece[2] + 0.5, piece[3])
			local b = Vector3.new(piece[4], piece[5] + 0.5, piece[6])
			if (b - a).Magnitude > 0.5 then
				-- Overlap a little at the joints so bends have no gaps.
				local dir = (b - a).Unit
				Util.strip(folder, "Rail", a - dir * 0.3, b + dir * 0.3, 0.3, 1, steel)
				count += 1
			end
		end
		for _, p in rail.Posts do
			local bottom, top = p[2] - 1, p[4]
			if top - bottom > 0.5 then
				Util.part(
					folder,
					"RailPost",
					CFrame.new(p[1], (bottom + top) / 2, p[3]),
					Vector3.new(0.4, top - bottom, 0.4),
					postOptions
				)
				count += 1
			end
		end
		-- Rounded end plates close the exposed rail profile without extending a terminal
		-- towards traffic or placing another colliding obstacle on the verge.
		local first, last = rail.Pieces[1], rail.Pieces[#rail.Pieces]
		if first and last then
			for _, endpoint in { { first, true }, { last, false } } do
				local piece, atStart = endpoint[1], endpoint[2]
				local a = Vector3.new(piece[1], piece[2] + 0.5, piece[3])
				local b = Vector3.new(piece[4], piece[5] + 0.5, piece[6])
				if (b - a).Magnitude <= 0.2 then
					continue
				end
				-- Util.strip places its centre half a thickness below the top endpoints.
				local centre = (if atStart then a else b) - CFrame.lookAt(a, b).UpVector * 0.5
				local axis = (b - a).Unit * 0.28
				Util.cylinder(folder, "RailTerminal", centre - axis, centre + axis, 1.1, {
					Material = Enum.Material.Metal,
					Color = Color3.fromRGB(150, 153, 151),
					Decoration = true,
				})
				count += 1
			end
		end
		Util.yield()
	end
	folder.Parent = parent
	return count
end

local function lights(details: any, parent: Instance): number
	local folder = Instance.new("Folder")
	folder.Name = "StreetLights"
	local metal: Util.PartOptions = { Material = Enum.Material.Metal, Color = Color3.fromRGB(96, 100, 106) }
	local count = 0
	for _, l in details.lights do
		local foot = Vector3.new(l.X, l.Y, l.Z)
		local arm = Vector3.new(l.ArmX, 0, l.ArmZ).Unit
		local height = 17
		Util.cylinder(folder, "Pole", foot - UP * 1.5, foot + UP * height, 0.6, metal)
		local armStart = foot + UP * (height - 0.4)
		local armEnd = armStart + arm * 5.5
		Util.strip(folder, "Arm", armStart, armEnd, 0.35, 0.35, metal)
		local head = Util.part(
			folder,
			"Lamp",
			CFrame.lookAt(armEnd - UP * 0.5, armEnd - UP * 0.5 + arm),
			Vector3.new(1.2, 0.5, 2.4),
			{ Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(210, 210, 204), CastShadow = false }
		)
		head:SetAttribute("RoNationLamp", true)
		local light = Instance.new("SpotLight")
		light:SetAttribute("RoNationStreetLight", true)
		light.Enabled = false -- the local environment controller switches this at dusk, including streamed lamps
		light.Face = Enum.NormalId.Bottom
		light.Angle = 120
		light.Range = 48
		light.Brightness = 2
		light.Color = Color3.fromRGB(255, 225, 185)
		light.Shadows = false
		light.Parent = head
		count += 3
		Util.yield()
	end
	folder.Parent = parent
	return count
end

local function powerLines(details: any, parent: Instance): number
	local folder = Instance.new("Folder")
	folder.Name = "PowerLines"
	local wood: Util.PartOptions = { Material = Enum.Material.Wood, Color = Color3.fromRGB(98, 76, 56) }
	local ceramic: Util.PartOptions = {
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(111, 129, 115),
		Decoration = true,
	}
	local arms: { Part } = {}
	local count = 0
	for k, p in details.poles do
		local foot = Vector3.new(p.X, p.Y, p.Z)
		local height = 20
		Util.cylinder(folder, "Pole", foot - UP * 2, foot + UP * height, 0.8, wood)
		local top = foot + UP * (height - 1)
		-- The cross arm runs across the line.
		local across = Vector3.new(-p.DirZ, 0, p.DirX)
		local arm = Util.part(folder, "CrossArm", CFrame.lookAt(top, top + across), Vector3.new(0.5, 0.5, 7), wood)
		arms[k] = arm
		for _, side in { -3, 3 } do
			local base = arm.CFrame * Vector3.new(0, 0.25, side)
			Util.cylinder(folder, "LineInsulator", base, base + UP * 0.75, 0.46, ceramic)
			local attachment = Instance.new("Attachment")
			attachment.Name = if side < 0 then "WireA" else "WireB"
			-- The attachment's axis points down, so the wires sag between the poles.
			attachment.CFrame = CFrame.fromMatrix(Vector3.new(0, 1, side), Vector3.new(0, -1, 0), Vector3.new(1, 0, 0))
			attachment.Parent = arm
		end
		count += 4
		Util.yield()
	end
	for _, pair in details.wires do
		local a, b = arms[pair[1]], arms[pair[2]]
		local span = (a.Position - b.Position).Magnitude
		for _, name in { "WireA", "WireB" } do
			local beam = Instance.new("Beam")
			beam.Name = "Wire"
			beam.Attachment0 = a:FindFirstChild(name) :: Attachment
			beam.Attachment1 = b:FindFirstChild(name) :: Attachment
			beam.Width0 = 0.12
			beam.Width1 = 0.12
			beam.Color = ColorSequence.new(Color3.fromRGB(34, 34, 34))
			beam.LightInfluence = 1
			beam.FaceCamera = true
			beam.Segments = 12
			beam.CurveSize0 = span * 0.035
			beam.CurveSize1 = -span * 0.035
			beam.Parent = a
		end
	end
	folder.Parent = parent
	return count
end

local function signs(details: any, parent: Instance): number
	local folder = Instance.new("Folder")
	folder.Name = "Signs"
	local count = 0
	for _, sign in details.signs do
		if Signs.build(folder, sign) then
			count += 1
		end
		Util.yield()
	end
	folder.Parent = parent
	return count
end

-- Builds into Workspace.Map.RoadDetails. Returns part counts by group.
function RoadDetailsBuilder.build(details: any, parent: Instance): { [string]: number }
	local root = Util.detachedFolder("RoadDetails")
	local counts = {
		Markings = markings(details, root),
		MarkerPosts = delineators(details, root),
		GuardRails = rails(details, root),
		StreetLights = lights(details, root),
		PowerLines = powerLines(details, root),
		Signs = signs(details, root),
	}
	root.Parent = parent
	return counts
end

return RoadDetailsBuilder
