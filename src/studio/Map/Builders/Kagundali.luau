--!strict
-- Bounded R3/N5 art benchmark. Geometry is staged; old generated vegetation is removed only
-- after the replacement succeeds. Road axes, drive heights, signs and property plots survive.
local Junction = require(script.Parent.Parent.JunctionLandscape)
local Hash = require(script.Parent.Parent.Hash)
local Geometry = require(script.Parent.Parent.Geometry)
local Trees = require(script.Parent.JunctionTrees)
local Util = require(script.Parent.Util)
local Builder = {}
local UP = Vector3.new(0, 1, 0)
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function workshop(root: Instance, sample: any, hf: any): boolean
	local yard = Junction.Yard
	local y = sample(yard.X, yard.Z)
	if not y then
		return false
	end
	for _, dx in { -43, 43 } do
		for _, dz in { -35, 35 } do
			local edge = sample(yard.X + dx, yard.Z + dz)
			if not edge or math.abs(edge - y) > 3 then
				return false
			end
		end
	end
	local model = Instance.new("Model")
	model.Name, model.Parent = "KagundaliTransportWorkshop", root
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	-- A short gravel driveway meets the existing R3 edge; the through carriageway is untouched.
	local _, entry = Junction.access(hf)
	if entry then
		local start = Vector3.new(yard.X, y + 0.08, yard.Z - 32)
		local points: { Vector3 } = { start }
		local clear = true
		for i = 1, 12 do
			local p = start:Lerp(entry, i / 12)
			local ground = sample(p.X, p.Z)
			if not ground then
				clear = false
				break
			end
			table.insert(points, Vector3.new(p.X, if i == 12 then entry.Y + 0.025 else ground + 0.09, p.Z))
		end
		if clear then
			for i = 1, #points - 1 do
				Util.strip(
					model,
					"WorkshopAccess",
					points[i],
					points[i + 1],
					9,
					0.35,
					{ Material = Enum.Material.Pebble, Color = rgb(123, 113, 93), Decoration = true }
				)
			end
		end
	end
	local function part(
		name: string,
		x: number,
		h: number,
		z: number,
		size: Vector3,
		material: Enum.Material,
		colour: Color3,
		decorative: boolean?
	): Part
		return Util.part(
			model,
			name,
			CFrame.new(yard.X + x, y + h, yard.Z + z),
			size,
			{ Material = material, Color = colour, Decoration = decorative }
		)
	end
	part("ServiceApron", 0, 0.08, -9, Vector3.new(64, 0.3, 48), Enum.Material.Concrete, rgb(124, 120, 107))
	part("Foundation", 0, 0.45, 12, Vector3.new(52, 0.8, 32), Enum.Material.Concrete, rgb(126, 119, 104))
	for _, side in { -1, 1 } do
		part("RenderedMasonry", side * 25, 7, 12, Vector3.new(1, 13, 31), Enum.Material.Brick, rgb(164, 144, 113))
		part("LowPlinth", side * 25, 1.4, 12, Vector3.new(1.2, 2, 31), Enum.Material.Concrete, rgb(99, 99, 91))
	end
	part("RearWall", 0, 7, 27, Vector3.new(50, 13, 1), Enum.Material.Brick, rgb(164, 144, 113))
	for _, x in { -24, -4, 24 } do
		part("BayColumn", x, 7, -3, Vector3.new(1.3, 13, 1.3), Enum.Material.Concrete, rgb(183, 172, 149))
	end
	part("Lintel", 0, 12.8, -3, Vector3.new(51, 1.4, 1.8), Enum.Material.Concrete, rgb(183, 172, 149))
	part("OfficeFront", 14, 6, -3, Vector3.new(18, 11, 0.8), Enum.Material.Brick, rgb(164, 144, 113))
	part("OfficeDoor", 20, 4.2, -3.5, Vector3.new(4, 7, 0.25), Enum.Material.WoodPlanks, rgb(70, 88, 79))
	part("OfficeWindowFrame", 11, 7.5, -3.6, Vector3.new(9, 5.2, 0.35), Enum.Material.Metal, rgb(59, 68, 64))
	part("OfficeWindow", 11, 7.5, -3.82, Vector3.new(8.2, 4.4, 0.1), Enum.Material.Glass, rgb(85, 110, 111), true)
	part("WindowMullion", 11, 7.5, -3.9, Vector3.new(0.2, 4.5, 0.12), Enum.Material.Metal, rgb(65, 68, 63), true)
	for _, side in { -1, 1 } do
		local roof = Util.part(
			model,
			"PitchedMetalRoof",
			CFrame.new(yard.X, y + 15, yard.Z + 12 + side * 9) * CFrame.Angles(side * 0.22, 0, 0),
			Vector3.new(57, 0.35, 19),
			{ Material = Enum.Material.Metal, Color = rgb(102, 109, 99) }
		)
		for i = -6, 6 do
			Util.part(
				model,
				"RoofSeam",
				roof.CFrame * CFrame.new(i * 4, 0.25, 0),
				Vector3.new(0.09, 0.12, 19),
				{ Material = Enum.Material.Metal, Color = rgb(82, 90, 81), Decoration = true }
			)
		end
	end
	part("RidgeCap", 0, 17.15, 12, Vector3.new(57, 0.3, 0.8), Enum.Material.Metal, rgb(81, 89, 80), true)
	for _, x in { -25, 25 } do
		part("Downpipe", x, 7.5, 28.5, Vector3.new(0.28, 14, 0.28), Enum.Material.Metal, rgb(103, 111, 102), true)
	end
	local tankBase = Vector3.new(yard.X + 34, y, yard.Z + 20)
	Util.cylinder(
		model,
		"RainwaterTank",
		tankBase,
		tankBase + UP * 10,
		7,
		{ Material = Enum.Material.SmoothPlastic, Color = rgb(63, 76, 61) }
	)
	for i = 1, 4 do
		part(
			"TransportCrate",
			-13 + i * 4,
			1.3,
			22,
			Vector3.new(3.5, 2.3, 4),
			Enum.Material.WoodPlanks,
			rgb(127, 106, 76)
		)
	end
	-- A physical sign replaces a floating development label in this selected area.
	local board =
		part("WorkshopSign", 0, 12, -4.1, Vector3.new(23, 2.1, 0.15), Enum.Material.Metal, rgb(47, 62, 54), true)
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.SizingMode, gui.PixelsPerStud, gui.LightInfluence =
		Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 40, 1
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.TextScaled = UDim2.fromScale(1, 1), 1, true
	label.Font, label.TextColor3, label.Text =
		Enum.Font.GothamBold, rgb(226, 220, 198), "KAGUNDALI · WERKSTATT / TRANSPORT"
	label.Parent = gui
	local lamp = part(
		"WorkshopLamp",
		-12,
		12,
		-4.8,
		Vector3.new(2, 0.4, 1),
		Enum.Material.SmoothPlastic,
		rgb(207, 198, 171),
		true
	)
	lamp:SetAttribute("RoNationLamp", true)
	local light = Instance.new("SpotLight")
	light.Face, light.Range, light.Angle, light.Brightness, light.Enabled = Enum.NormalId.Bottom, 36, 100, 1.6, false
	light.Color, light.Parent = rgb(255, 229, 190), lamp
	light:SetAttribute("RoNationStreetLight", true)
	return true
end

function Builder.build(hf: any, layout: any, parent: Instance, sample: any, library: Folder, details: any): any
	local root = Util.folder(parent, "KagundaliJunction")
	root:SetAttribute("Revision", Junction.Revision)
	local plants = Util.folder(root, "Planting")
	local infrastructure = Util.folder(root, "Roadside")
	local report = { Trees = 0, Shrubs = 0, Ferns = 0, Rocks = 0, Parts = 0, Workshop = false }
	local centres =
		{ { 220, 3090, "Broadleaf" }, { 670, 3100, "Eucalyptus" }, { 710, 3480, "Broadleaf" }, { 190, 3570, "Acacia" } }
	local occupied: { Vector3 } = {}
	local function suitable(x: number, z: number, tree: boolean): (number?, number)
		if not Junction.contains(x, z, 20) then
			return nil, 0
		end
		local edge = hf.roads.nearest(x, z) or math.huge
		if edge < (if tree then 30 else 8) then
			return nil, 0
		end
		local yard = Junction.Yard
		if math.abs(x - yard.X) < 65 and math.abs(z - yard.Z) < 59 then
			return nil, 0
		end
		if
			(Vector3.new(x, 0, z) - Vector3.new(Junction.Centre.X, 0, Junction.Centre.Z)).Magnitude
			< (if tree then 92 else 52)
		then
			return nil, 0
		end
		for _, wire in details.wires do
			local a, b = details.poles[wire[1]], details.poles[wire[2]]
			if tree and Geometry.segmentDistance(a.X, a.Z, b.X, b.Z, x, z) < 23 then
				return nil, 0
			end
		end
		local y, slope = sample(x, z)
		if not y or slope > (if tree then 0.6 else 0.85) then
			return nil, 0
		end
		for _, p in occupied do
			if (Vector3.new(x, p.Y, z) - p).Magnitude < (if tree then 14 else 4) then
				return nil, 0
			end
		end
		return y, slope
	end
	for cluster, centre in centres do
		local placed = 0
		for candidate = 1, 24 do
			local angle = candidate * 2.399963 + cluster
			local radius = 10 + math.sqrt(candidate / 24) * 76
			local x = centre[1] + math.cos(angle) * radius + Hash.range(cluster, candidate, 801, -7, 7)
			local z = centre[2] + math.sin(angle) * radius * 0.68
			local y = suitable(x, z, true)
			if y and report.Trees < 64 and placed < 18 then
				local kind = if candidate % 6 == 0 then "Acacia" else centre[3]
				local height = (if kind == "Eucalyptus" then 42 else 30)
					* Hash.range(cluster, candidate, 802, 0.72, 1.22)
				Trees.plant(library, plants, kind, 1 + candidate % 3, Vector3.new(x, y, z), height, angle)
				table.insert(occupied, Vector3.new(x, y, z))
				report.Trees += 1
				placed += 1
			end
		end
		for candidate = 1, 25 do
			local angle = candidate * 2.399963 + cluster * 0.4
			local radius = 8 + math.sqrt(candidate / 25) * 98
			local x, z = centre[1] + math.cos(angle) * radius, centre[2] + math.sin(angle) * radius * 0.7
			local y = suitable(x, z, false)
			if y then
				local fern = candidate % 2 == 0
				Trees.plant(
					library,
					plants,
					if fern then "Fern" else "Shrub",
					1 + candidate % 3,
					Vector3.new(x, y, z),
					if fern
						then 1.8 + Hash.unit(cluster, candidate, 803) * 1.4
						else 3.8 + Hash.unit(cluster, candidate, 804) * 2,
					angle
				)
				if fern then
					report.Ferns += 1
				else
					report.Shrubs += 1
				end
			end
		end
	end
	-- Wider gravel transitions and visible U-shaped drainage follow the existing road profile.
	for roadIndex, road in hf.roads.roads do
		if road.Id ~= "R3" and road.Id ~= "N5" then
			continue
		end
		if road.Id == "R3" then
			local i = #road.line.xs - 10
			local p = Vector3.new(road.line.xs[i], road.profile[i], road.line.zs[i])
			local q = Vector3.new(road.line.xs[i + 1], road.profile[i + 1], road.line.zs[i + 1])
			local along = (q - p).Unit
			local across = Vector3.new(-along.Z, 0, along.X).Unit
			local centre = p + across * road.Width * 0.25 + UP * 0.06
			local paint = { Material = Enum.Material.SmoothPlastic, Color = rgb(218, 214, 201), Decoration = true }
			local tip = centre + along * 2
			Util.strip(infrastructure, "ApproachTurnArrow", centre - along * 4, tip, 0.45, 0.025, paint)
			Util.strip(infrastructure, "ApproachTurnArrow", tip - across * 3, tip + across * 3, 0.45, 0.025, paint)
			for _, side in { -1, 1 } do
				for _, wing in { -1, 1 } do
					Util.strip(
						infrastructure,
						"ApproachTurnArrow",
						tip + across * 3 * side,
						tip + across * 1.9 * side + along * wing,
						0.45,
						0.025,
						paint
					)
				end
			end
		end
		for i = 1, #road.line.xs - 3, 3 do
			local a = Vector3.new(road.line.xs[i], road.profile[i], road.line.zs[i])
			local b = Vector3.new(road.line.xs[i + 3], road.profile[i + 3], road.line.zs[i + 3])
			if
				not Junction.contains(a.X, a.Z, 26)
				or not Junction.contains(b.X, b.Z, 26)
				or road.onBridge[i]
				or road.onBridge[i + 3]
			then
				continue
			end
			local along = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
			local across = Vector3.new(-along.Z, 0, along.X)
			for _, side in { -1, 1 } do
				local offset = across * (road.Width / 2 + 3.4) * side
				local pa, pb = a + offset - UP * 0.13, b + offset - UP * 0.13
				if
					hf.roads.otherDistance(pa.X, pa.Z, roadIndex) < 10
					or hf.roads.otherDistance(pb.X, pb.Z, roadIndex) < 10
				then
					continue
				end
				local ga, gb = sample(pa.X, pa.Z), sample(pb.X, pb.Z)
				if not ga or not gb or ga > pa.Y + 0.3 or gb > pb.Y + 0.3 or pa.Y - ga > 4 or pb.Y - gb > 4 then
					continue
				end
				Util.strip(
					infrastructure,
					"GravelTransition",
					pa,
					pb,
					3.8,
					math.max(0.45, pa.Y - ga + 0.2, pb.Y - gb + 0.2),
					{ Material = Enum.Material.Pebble, Color = rgb(125, 115, 95), Decoration = true }
				)
				local da, db = a + across * (road.Width / 2 + 12) * side, b + across * (road.Width / 2 + 12) * side
				local ya, yb = sample(da.X, da.Z), sample(db.X, db.Z)
				if
					ya
					and yb
					and math.abs(ya - yb) < 5
					and hf.roads.otherDistance(da.X, da.Z, roadIndex) > 10
					and hf.roads.otherDistance(db.X, db.Z, roadIndex) > 10
				then
					da, db = Vector3.new(da.X, ya + 0.08, da.Z), Vector3.new(db.X, yb + 0.08, db.Z)
					local concrete =
						{ Material = Enum.Material.Concrete, Color = rgb(124, 121, 108), Decoration = true }
					Util.strip(infrastructure, "DrainInvert", da, db, 2.4, 0.2, concrete)
					for _, bank in { -1, 1 } do
						Util.strip(
							infrastructure,
							"DrainWall",
							da + across * bank * 1.3 + UP * 0.5,
							db + across * bank * 1.3 + UP * 0.5,
							0.22,
							0.7,
							concrete
						)
					end
				end
			end
		end
	end
	for i = 1, 28 do
		local x, z = Hash.range(i, 1, 811, 90, 805), Hash.range(i, 2, 812, 2970, 3620)
		local y = suitable(x, z, false)
		if y then
			local size = Hash.range(i, 3, 813, 1.5, 4)
			Util.wedge(
				plants,
				"BuriedRock",
				CFrame.new(x, y + size * 0.12, z) * CFrame.Angles(0.1, i * 1.37, 0.2),
				Vector3.new(size * 1.3, size, size),
				{ Material = Enum.Material.Rock, Color = rgb(111, 108, 91), Decoration = true }
			)
			report.Rocks += 1
		end
	end
	report.Workshop = workshop(root, sample, hf)
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") then
			report.Parts += 1
		end
	end
	assert(report.Parts <= Junction.MaxParts, `Junction exceeded its {Junction.MaxParts}-part budget`)
	assert(report.Trees >= 20, "Too little usable terrain for the junction planting; old geometry retained")
	root:SetAttribute("PartCount", report.Parts)
	root:SetAttribute("TreeCount", report.Trees)
	return report
end

-- Keep the actual sign texts, arrows, positions and manual edits. Improve their construction.
function Builder.refineSigns(map: Instance): number
	local details = map:FindFirstChild("RoadDetails")
	local signs = if details then details:FindFirstChild("Signs") else nil
	local count = 0
	for _, model in if signs then signs:GetChildren() else {} do
		-- Construction revision is independent of vegetation/terrain. Do not move the
		-- retained signposts a second time when upgrading junction-1 to junction-2.
		if not model:IsA("Model") or model:GetAttribute("JunctionConstruction") ~= nil then
			continue
		end
		local board = model.PrimaryPart
		if not board or not Junction.contains(board.Position.X, board.Position.Z, 10) then
			continue
		end
		local face = if model.Name == "StopSign" or model.Name == "SpeedSign"
			then board.CFrame.RightVector
			else board.CFrame.LookVector
		local braces = Instance.new("Folder")
		braces.Name, braces.Parent = "ConstructionDetails", model
		for _, item in model:GetChildren() do
			if item:IsA("BasePart") and item.Name == "Post" then
				item.CFrame -= face * 0.42
				local base = item.Position - UP * (item.Size.X / 2 - 1.5)
				Util.part(
					braces,
					"PostFooting",
					CFrame.new(base - UP * 0.1),
					Vector3.new(0.9, 0.45, 0.9),
					{ Material = Enum.Material.Concrete, Color = rgb(128, 127, 116), Decoration = true }
				)
			elseif item:IsA("BasePart") and item.Name == "Board" then
				item.Material = Enum.Material.Metal
				for _, vertical in { -1, 1 } do
					Util.part(
						braces,
						"RearStiffener",
						item.CFrame * CFrame.new(0, vertical * item.Size.Y * 0.32, item.Size.Z / 2 + 0.18),
						Vector3.new(item.Size.X * 0.92, 0.14, 0.18),
						{ Material = Enum.Material.Metal, Color = rgb(121, 127, 119), Decoration = true }
					)
				end
			end
		end
		model:SetAttribute("JunctionConstruction", Junction.Revision)
		count += 1
	end
	return count
end

function Builder.removeOldVegetation(map: Instance): number
	local vegetation = map:FindFirstChild("Vegetation")
	if not vegetation or not Util.isGenerated(vegetation) then
		return 0
	end
	local remove: { Instance } = {}
	for _, item in vegetation:GetDescendants() do
		if not item:IsA("BasePart") then
			continue
		end
		local p = item.Position
		if Junction.contains(p.X, p.Z, 12) then
			local target = if item.Parent and item.Parent:IsA("Model") then item.Parent else item
			if not table.find(remove, target) then
				table.insert(remove, target)
			end
		end
	end
	for _, item in remove do
		item:Destroy()
	end
	return #remove
end

return Builder
