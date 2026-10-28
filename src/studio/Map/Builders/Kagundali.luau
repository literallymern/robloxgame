--!strict
-- Bounded R3/N5 art benchmark. Geometry is staged; old generated vegetation is removed only
-- after the replacement succeeds. Road axes, drive heights, signs and property plots survive.
local Junction = require(script.Parent.Parent.JunctionLandscape)
local Hash = require(script.Parent.Parent.Hash)
local Geometry = require(script.Parent.Parent.Geometry)
local Trees = require(script.Parent.JunctionTrees)
local CreatorAssets = require(script.Parent.Parent.CreatorAssets)
local Util = require(script.Parent.Util)
local Builder = {}
local UP = Vector3.new(0, 1, 0)
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Clip a channel against the finite driveway, including the channel's own half-width.
local function outsideAccess(a: Vector3, b: Vector3, start: Vector3?, finish: Vector3?): { { Vector3 } }
	if not start or not finish then
		return { { a, b } }
	end
	local delta = Vector3.new(finish.X - start.X, 0, finish.Z - start.Z)
	local along = delta.Unit
	local across = Vector3.new(-along.Z, 0, along.X)
	local from, step = a - start, b - a
	local lo, hi = 0, 1
	for _, axis in
		{ { Direction = along, Min = -6, Max = delta.Magnitude + 6 }, { Direction = across, Min = -6, Max = 6 } }
	do
		local origin, velocity = from:Dot(axis.Direction), step:Dot(axis.Direction)
		if math.abs(velocity) < 1e-8 then
			if origin < axis.Min or origin > axis.Max then
				return { { a, b } }
			end
		else
			local t1, t2 = (axis.Min - origin) / velocity, (axis.Max - origin) / velocity
			lo, hi = math.max(lo, math.min(t1, t2)), math.min(hi, math.max(t1, t2))
		end
	end
	if lo >= hi then
		return { { a, b } }
	end
	local result = {}
	if lo > 0 then
		table.insert(result, { a, a:Lerp(b, lo) })
	end
	if hi < 1 then
		table.insert(result, { a:Lerp(b, hi), b })
	end
	return result
end

local function channel(parent: Instance, a: Vector3, b: Vector3, across: Vector3, sample: any)
	local length = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
	if length < 0.5 then
		return
	end
	local segments = math.ceil(length / 16)
	local points: { Vector3 } = {}
	local lifts: { number } = {}
	for i = 0, segments do
		local p = a:Lerp(b, i / segments)
		local top = -math.huge
		for _, side in { -1, 0, 1 } do
			local ground = sample(p.X + across.X * side * 1.4, p.Z + across.Z * side * 1.4)
			if not ground then
				return
			end
			top = math.max(top, ground + 0.12)
		end
		table.insert(points, Vector3.new(p.X, top, p.Z))
	end
	-- Raise shared stations together, so neighbouring sections have no vertical step.
	for i = 1, segments do
		local da, db = points[i], points[i + 1]
		if math.abs(da.Y - db.Y) > 3 then
			return
		end
		local lift = 0
		local probes = math.ceil((db - da).Magnitude / 2)
		for j = 0, probes do
			local p = da:Lerp(db, j / probes)
			for _, side in { -1, 0, 1 } do
				local ground = sample(p.X + across.X * side * 1.4, p.Z + across.Z * side * 1.4)
				if not ground then
					return
				end
				lift = math.max(lift, ground + 0.12 - p.Y)
			end
		end
		if lift > 0.8 then
			return -- Preserve protected ground and leave sharp changes without suspended concrete.
		end
		lifts[i] = lift
	end
	for i, p in points do
		points[i] = p + UP * math.max(lifts[i - 1] or 0, lifts[i] or 0)
	end
	local concrete = { Material = Enum.Material.Concrete, Color = rgb(124, 121, 108), Decoration = true }
	for i = 1, segments do
		local da, db = points[i], points[i + 1]
		local depths = { 0.22, 0.5, 0.5 }
		local vertical = Vector3.new(db.X - da.X, 0, db.Z - da.Z).Magnitude / (db - da).Magnitude
		local probes = math.ceil((db - da).Magnitude / 2)
		for j = 0, probes do
			local p = da:Lerp(db, j / probes)
			for index, side in { 0, -1, 1 } do
				local ground = sample(p.X + across.X * side * 1.3, p.Z + across.Z * side * 1.3)
				if not ground then
					return
				end
				local top = p.Y + (if side == 0 then 0 else 0.28)
				depths[index] = math.max(depths[index], (top - ground + 0.15) / vertical)
			end
		end
		Util.strip(parent, "DrainInvert", da, db, 2.4, depths[1], concrete)
		for index, side in { -1, 1 } do
			local offset = across * side * 1.3 + UP * 0.28
			Util.strip(parent, "DrainWall", da + offset, db + offset, 0.22, depths[index + 1], concrete)
		end
	end
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
		local direction = (Vector3.new(entry.X, 0, entry.Z) - Vector3.new(start.X, 0, start.Z)).Unit
		local across = Vector3.new(-direction.Z, 0, direction.X) * 4.5
		local points: { Vector3 } = {}
		local bottoms: { number } = {}
		local segments = math.ceil((entry - start).Magnitude / 3)
		local clear = true
		for i = 0, segments do
			local p = start:Lerp(entry, i / segments)
			local highest, lowest = -math.huge, math.huge
			for _, side in { -1, -0.5, 0, 0.5, 1 } do
				local offset = across * side
				local ground = sample(p.X + offset.X, p.Z + offset.Z)
				if not ground then
					clear = false
					break
				end
				highest, lowest = math.max(highest, ground), math.min(lowest, ground)
			end
			if not clear then
				break
			end
			local top = math.max(highest + 0.16, if i == segments then entry.Y + 0.025 else -math.huge)
			table.insert(points, Vector3.new(p.X, top, p.Z))
			table.insert(bottoms, lowest)
		end
		-- A saved terrain lip can lie between the stations. Keep adjacent tops shared
		-- while lifting the whole crossing surface clear of those intermediate probes.
		local lifts: { number } = {}
		if clear then
			for i = 1, #points - 1 do
				local lift = 0
				for j = 0, 4 do
					local p = points[i]:Lerp(points[i + 1], j / 4)
					for _, side in { -1, -0.5, 0, 0.5, 1 } do
						local ground = sample(p.X + across.X * side, p.Z + across.Z * side)
						if not ground then
							clear = false
							break
						end
						lift = math.max(lift, ground + 0.12 - p.Y)
						bottoms[i] = math.min(bottoms[i], ground)
						bottoms[i + 1] = math.min(bottoms[i + 1], ground)
					end
				end
				lifts[i] = lift
			end
			for i, p in points do
				points[i] = p + UP * math.max(lifts[i - 1] or 0, lifts[i] or 0)
			end
		end
		if clear then
			local drains = Junction.drains(hf)
			for i = 1, #points - 1 do
				local centre = (points[i] + points[i + 1]) / 2
				local crossing = false
				for _, drain in drains do
					if
						Geometry.segmentDistance(drain.A.X, drain.A.Z, drain.B.X, drain.B.Z, centre.X, centre.Z) < 3.5
					then
						crossing = true
						break
					end
				end
				Util.strip(
					model,
					if crossing then "WorkshopDrainCrossing" else "WorkshopAccess",
					points[i],
					points[i + 1],
					9,
					math.max(0.35, points[i].Y - bottoms[i] + 0.15, points[i + 1].Y - bottoms[i + 1] + 0.15),
					{
						Material = if crossing then Enum.Material.Concrete else Enum.Material.Pebble,
						Color = if crossing then rgb(124, 121, 108) else rgb(123, 113, 93),
						Decoration = not crossing,
					}
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
		Enum.Font.GothamBold, rgb(226, 220, 198), "KAGUNDALI · WORKSHOP / TRANSPORT"
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

function Builder.build(hf: any, _layout: any, parent: Instance, sample: any, library: Folder, details: any): any
	local root = Util.folder(parent, "KagundaliJunction")
	root:SetAttribute("Revision", Junction.Revision)
	local plants = Util.folder(root, "Planting")
	local infrastructure = Util.folder(root, "Roadside")
	local report = { Trees = 0, Shrubs = 0, Ferns = 0, Rocks = 0, Parts = 0, Workshop = false }
	local centres: { { any } } =
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
				Trees.plant(library, plants, kind, 1 + candidate % 3, Vector3.new(x, y, z), height, angle, sample)
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
				if not ga or not gb or ga > pa.Y + 2 or gb > pb.Y + 2 or pa.Y - ga > 4 or pb.Y - gb > 4 then
					continue
				end
				pa, pb =
					Vector3.new(pa.X, math.max(pa.Y, ga + 0.12), pa.Z),
					Vector3.new(pb.X, math.max(pb.Y, gb + 0.12), pb.Z)
				Util.strip(
					infrastructure,
					"GravelTransition",
					pa,
					pb,
					3.8,
					math.max(0.45, pa.Y - ga + 0.2, pb.Y - gb + 0.2),
					{ Material = Enum.Material.Pebble, Color = rgb(125, 115, 95), Decoration = true }
				)
			end
		end
	end
	report.Workshop = workshop(root, sample, hf)
	local accessStart, accessEnd = Junction.access(hf)
	for _, path in Junction.drains(hf) do
		for _, span in
			outsideAccess(
				path.A,
				path.B,
				if report.Workshop then accessStart else nil,
				if report.Workshop then accessEnd else nil
			)
		do
			channel(infrastructure, span[1], span[2], path.Across, sample)
		end
	end
	for i = 1, 28 do
		local x, z = Hash.range(i, 1, 811, 90, 805), Hash.range(i, 2, 812, 2970, 3620)
		local y = suitable(x, z, false)
		if y then
			local size = Hash.range(i, 3, 813, 1.5, 4)
			local imported = CreatorAssets.place("Rock", i, plants, Vector3.new(x, y - size * 0.25, z), size, i * 1.37)
			if not imported then
				Util.wedge(
					plants,
					"BuriedRock",
					CFrame.new(x, y + size * 0.12, z) * CFrame.Angles(0.1, i * 1.37, 0.2),
					Vector3.new(size * 1.3, size, size),
					{ Material = Enum.Material.Rock, Color = rgb(111, 108, 91), Decoration = true }
				)
			end
			report.Rocks += 1
		end
	end
	report.ImportedLamps = 0
	report.ReplacedLampPositions = {}
	for index, lamp in details.lights do
		if Junction.contains(lamp.X, lamp.Z, 20) then
			local ground = sample(lamp.X, lamp.Z)
			if ground then
				local placed = CreatorAssets.place(
					"Lamp",
					index,
					infrastructure,
					Vector3.new(lamp.X, ground, lamp.Z),
					17,
					math.atan2(-lamp.ArmX, -lamp.ArmZ)
				)
				if placed then
					report.ImportedLamps += 1
					table.insert(report.ReplacedLampPositions, Vector3.new(lamp.X, ground, lamp.Z))
				end
			end
		end
	end
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
	local models: { Instance } = if signs then signs:GetChildren() else {}
	for _, model in models do
		local construction = model:GetAttribute("JunctionConstruction")
		if not model:IsA("Model") or construction == "junction-signs-2" then
			continue
		end
		local board = model.PrimaryPart
		if not board or not Junction.contains(board.Position.X, board.Position.Z, 10) then
			continue
		end
		local face = if model.Name == "StopSign" or model.Name == "SpeedSign"
			then board.CFrame.RightVector
			else board.CFrame.LookVector
		if model.Name == "DirectionSign" and model:GetAttribute("JunctionFaceRevision") ~= "junction-signs-2" then
			for _, panel in model:GetChildren() do
				if not panel:IsA("BasePart") or panel.Name ~= "Board" then
					continue
				end
				local oldSize = panel.Size
				local width, height = math.max(oldSize.X, 10.8), math.max(oldSize.Y, 1.95)
				for _, tip in model:GetChildren() do
					if tip:IsA("BasePart") and tip.Name == "Tip" then
						local relative = panel.CFrame:PointToObjectSpace(tip.Position)
						if math.abs(relative.Y) < oldSize.Y / 2 + 0.05 then
							local side = if relative.X < 0 then -1 else 1
							tip.CFrame += panel.CFrame.RightVector * side * (width - oldSize.X) / 2 + panel.CFrame.UpVector * relative.Y * (height / oldSize.Y - 1)
							tip.Size = Vector3.new(tip.Size.X, tip.Size.Y * height / oldSize.Y, tip.Size.Z)
							tip.Material = Enum.Material.Metal
						end
					end
				end
				panel.Size = Vector3.new(width, height, oldSize.Z)
				for _, gui in panel:GetChildren() do
					if gui:IsA("SurfaceGui") then
						gui.PixelsPerStud, gui.MaxDistance = 50, 600
					end
				end
			end
			model:SetAttribute("JunctionFaceRevision", "junction-signs-2")
		end
		local priorBraces = model:FindFirstChild("ConstructionDetails")
		if construction and priorBraces then
			priorBraces:Destroy()
		end
		local braces = Instance.new("Folder")
		braces.Name, braces.Parent = "ConstructionDetails", model
		for _, item in model:GetChildren() do
			if item:IsA("BasePart") and item.Name == "Post" then
				if not construction then
					item.CFrame -= face * 0.42
				end
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
		model:SetAttribute("JunctionConstruction", "junction-signs-2")
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

function Builder.removeOldLamps(map: Instance, replaced: { Vector3 })
	local details = map:FindFirstChild("RoadDetails")
	local lamps = if details and Util.isGenerated(details) then details:FindFirstChild("StreetLights") else nil
	local parts: { Instance } = if lamps then lamps:GetChildren() else {}
	for _, part in parts do
		if part:IsA("BasePart") and table.find({ "Pole", "Arm", "Lamp" }, part.Name) then
			for _, position in replaced do
				-- Original arms reach 5.5 studs from their pole. Leave unreplaced sites alone.
				if Vector3.new(part.Position.X - position.X, 0, part.Position.Z - position.Z).Magnitude <= 6 then
					part:Destroy()
					break
				end
			end
		end
	end
end

return Builder
