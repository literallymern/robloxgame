--!strict
-- Original whole-tree assets for the bounded Kagundali benchmark. Small curved leaves,
-- tapered branching wood and three foliage tones replace the old oversized flat leaf cards.
-- Compiled once in edit mode; four cached CSG parts per plant, no uploaded asset IDs.
local Hash = require(script.Parent.Parent.Hash)
local Util = require(script.Parent.Util)
local CreatorAssets = require(script.Parent.Parent.CreatorAssets)
local Trees = {}
Trees.Version = "kagundali-trees-2"
Trees.Kinds = { "Broadleaf", "Acacia", "Eucalyptus", "Shrub", "Fern" }
Trees.Variants = 3
local NAME = "RoNationJunctionTrees"
local PALETTE =
	{ Color3.fromRGB(82, 68, 51), Color3.fromRGB(54, 80, 37), Color3.fromRGB(68, 93, 43), Color3.fromRGB(79, 103, 49) }

function Trees.currentVersion(): string
	return if CreatorAssets.get() then CreatorAssets.Version else Trees.Version
end

function Trees.blueprint(kind: string, variant: number): any
	local index = table.find(Trees.Kinds, kind)
	assert(index and variant >= 1 and variant <= Trees.Variants, "Unknown junction tree template")
	local groups: any = { {}, {}, {}, {} }
	local function random(s: number): number
		return Hash.unit(index :: number, variant, s)
	end
	local function shape(group: number, frame: CFrame, size: Vector3, form: string, role: string?)
		table.insert(
			groups[group],
			{ Frame = frame, Size = size, Form = form, Role = role or (if group == 1 then "Wood" else "Leaf") }
		)
	end
	local function branch(a: Vector3, b: Vector3, diameter: number, endDiameter: number?)
		for i = 1, 3 do
			local start, finish = a:Lerp(b, (i - 1) / 3), a:Lerp(b, i / 3)
			local frame = CFrame.lookAt((start + finish) / 2, finish) * CFrame.Angles(0, math.pi / 2, 0)
			local d = diameter + ((endDiameter or diameter * 0.4) - diameter) * (i - 1) / 3
			shape(1, frame, Vector3.new((finish - start).Magnitude + d * 0.3, d, d), "Cylinder")
		end
	end
	local fern, shrub, acacia, eucalyptus = kind == "Fern", kind == "Shrub", kind == "Acacia", kind == "Eucalyptus"
	local height = if fern then 3.6 elseif shrub then 8 else 32
	local foot = Vector3.new(0, -0.65, 0)
	local lean = Vector3.new((random(1) - 0.5) * 2, 0, (random(2) - 0.5) * 2)
	local last = foot
	local trunkPoints = { foot }
	for i = 1, 4 do
		local p = lean * (i / 4) ^ 2
			+ Vector3.new(0, height * (if fern then 0.35 elseif acacia then 0.65 else 0.88) * i / 4, 0)
		local diameter = if fern then 0.14 elseif shrub then 0.4 else 1.25
		branch(last, p, diameter * (1 - (i - 1) * 0.17), diameter * (1 - i * 0.17))
		last = p
		table.insert(trunkPoints, p)
	end
	local function trunkAt(y: number): Vector3
		for i = 1, #trunkPoints - 1 do
			local a, b = trunkPoints[i], trunkPoints[i + 1]
			if y <= b.Y then
				return a:Lerp(b, math.clamp((y - a.Y) / (b.Y - a.Y), 0, 1))
			end
		end
		return trunkPoints[#trunkPoints]
	end
	local limbs = if fern then 7 elseif shrub then 9 else 13
	for limb = 1, limbs do
		local t = (limb - 1) / (limbs - 1)
		local angle = limb * 2.399963 + variant * 0.7 + random(limb + 11) * 0.4
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local startY = height
			* (
				if fern
					then 0.15
					elseif shrub then 0.2 + t * 0.35
					elseif acacia then 0.43 + t * 0.12
					elseif eucalyptus then 0.32 + t * 0.48
					else 0.32 + t * 0.22
			)
		local reach = (
			if fern then 2.1 elseif shrub then 3.2 elseif acacia then 10.8 elseif eucalyptus then 5.2 else 8.3
		)
			* (0.8 + random(limb + 29) * 0.3)
			* (if acacia or fern then 1 else 1 - t * 0.38)
		local a = trunkAt(startY)
		local b = a + direction * reach * 0.56 + Vector3.new(0, height * 0.11, 0)
		local c = a
			+ direction * reach
			+ Vector3.new(0, height * (if acacia then 0.19 + (1 - t) * 0.14 elseif fern then 0.23 else 0.18), 0)
		if kind == "Broadleaf" then
			c = Vector3.new(c.X, height * (0.68 + 0.22 * t) + random(limb + 44) * 1.8, c.Z)
		end
		local diameter = if fern then 0.09 elseif shrub then 0.21 else 0.5 * (1 - t * 0.5)
		branch(a, b, diameter)
		branch(b, c, diameter * 0.62)
		if not fern and not shrub then
			for layer = 1, 3 do
				local fraction = 0.28 + layer * 0.18
				local centre = a:Lerp(c, fraction) + Vector3.new(-direction.Z, 0, direction.X) * (layer - 2) * 0.9
				if acacia then
					centre = Vector3.new(centre.X, height * 0.75 + random(limb * 19 + layer) * 1.6, centre.Z)
				end
				local width = if eucalyptus then 2.6 else 5.2
				shape(
					2 + (limb + layer) % 3,
					CFrame.new(centre) * CFrame.Angles(0.12 * layer, angle + layer, 0.07 * limb),
					Vector3.new(width, if acacia then 1.8 else width * 0.65, width * 0.9),
					"Ball",
					"FoliageCluster"
				)
			end
		end
		for twig = 1, (if fern then 1 else 3) do
			local yaw = angle + (twig - 2) * 0.9
			local endPoint = if fern
				then c
				else c + Vector3.new(math.cos(yaw), 0.3, math.sin(yaw)) * (if shrub then 0.7 else 1.7)
			local twigBase = b:Lerp(c, 0.35 + twig * 0.12)
			branch(twigBase, endPoint, diameter * 0.25)
			if not fern then
				-- Overlapping irregular leaf clusters fill the crown between fine terminal leaves.
				-- These are small elongated foliage masses, not one spherical tree cap.
				local centre = twigBase:Lerp(endPoint, 0.5)
				local width = if shrub then 2.2 elseif eucalyptus then 2.7 elseif acacia then 4.1 else 4.4
				local depth = width * (0.7 + random(limb * 17 + twig) * 0.3)
				local thickness = width * (if acacia then 0.3 elseif eucalyptus then 0.6 else 0.58)
				shape(
					2 + (limb + twig) % 3,
					CFrame.new(centre) * CFrame.Angles(0.1 * twig, yaw, 0.08 * limb),
					Vector3.new(width, thickness, depth),
					"Ball",
					"FoliageCluster"
				)
			end
			for leaf = 1, (if fern then 18 else 8) do
				local salt = limb * 313 + twig * 31 + leaf
				local phi = leaf * 2.399963 + random(salt) * 0.8
				local tLeaf = leaf / 18
				local attachment = if fern
					then (if tLeaf < 0.5 then a:Lerp(b, tLeaf * 2) else b:Lerp(c, tLeaf * 2 - 1))
					else twigBase:Lerp(endPoint, 0.15 + 0.85 * leaf / 8)
				local length = (
					if fern then 1.05 * (1 - tLeaf * 0.65) elseif eucalyptus then 1.3 elseif acacia then 1.15 else 1.55
				) * (0.75 + random(salt + 2) * 0.45)
				local width = length * (if eucalyptus or fern then 0.28 else 0.55)
				local outward = if fern
					then Vector3.new(-direction.Z, 0.08, direction.X) * (if leaf % 2 == 0 then 1 else -1)
					else Vector3.new(math.cos(phi), (random(salt + 1) - 0.5) * 0.7, math.sin(phi)).Unit
				local p = attachment + outward * (length * 0.46)
				local frame = CFrame.lookAt(p, p + outward)
				shape(
					2 + (limb + twig + leaf) % 3,
					frame,
					Vector3.new(width, math.max(0.09, width * 0.2), length),
					"Ball"
				)
				groups[2 + (limb + twig + leaf) % 3][#groups[2 + (limb + twig + leaf) % 3]].Attachment = attachment
			end
		end
	end
	return { Groups = groups, Height = height }
end

function Trees.prepare(): Folder
	assert(not game:GetService("RunService"):IsRunning(), "Prepare junction trees in edit mode")
	local imported = CreatorAssets.get()
	if
		imported
		and CreatorAssets.count(imported, "Tree") > 0
		and CreatorAssets.count(imported, "Shrub") > 0
		and CreatorAssets.count(imported, "Fern") > 0
	then
		return imported
	end
	local storage = game:GetService("ServerStorage")
	local old = storage:FindFirstChild(NAME)
	assert(not old or old:GetAttribute("ManagedBy") == NAME, "Junction asset name is occupied by custom content")
	if
		old
		and old:GetAttribute("AssetVersion") == Trees.Version
		and #old:GetChildren() == #Trees.Kinds * Trees.Variants
	then
		local complete = true
		for _, kind in Trees.Kinds do
			for variant = 1, Trees.Variants do
				local model = old:FindFirstChild(kind .. variant)
				complete = complete and model ~= nil and model:IsA("Model") and #model:GetChildren() == 4
				if model then
					for _, part in model:GetChildren() do
						complete = complete and part:IsA("PartOperation")
					end
				end
			end
		end
		if complete then
			return old :: Folder
		end
	end
	local library = Instance.new("Folder")
	library.Name = NAME
	library:SetAttribute("ManagedBy", NAME)
	library:SetAttribute("AssetVersion", Trees.Version)
	local inputs: { BasePart } = {}
	local ellipsoid: BasePart? = nil
	local function clear()
		for _, part in inputs do
			part:Destroy()
		end
		table.clear(inputs)
	end
	local ok, err = pcall(function()
		local geometry = game:GetService("GeometryService")
		-- A Part with Shape=Ball always renders a sphere with diameter min(Size).
		-- Bake ONE uniform sphere into solid geometry first. A PartOperation can then
		-- be stretched into a real ellipsoid before the foliage unions are assembled.
		local ball = Instance.new("Part")
		ball.Shape, ball.Size, ball.CFrame = Enum.PartType.Ball, Vector3.new(1, 1, 1), CFrame.new()
		ball.Anchored, ball.Material, ball.Color = true, Enum.Material.SmoothPlastic, PALETTE[2]
		table.insert(inputs, ball)
		local core = Instance.new("Part")
		core.Size, core.CFrame, core.Anchored = Vector3.new(0.05, 0.05, 0.05), CFrame.new(), true
		table.insert(inputs, core)
		local baked = geometry:UnionAsync(ball, { core }, {
			SplitApart = false,
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
		})
		if #baked ~= 1 or not baked[1]:IsA("PartOperation") then
			for _, item in baked do
				item:Destroy()
			end
			error("Could not bake the solid leaf prototype")
		end
		ellipsoid = baked[1]
		clear()
		for _, kind in Trees.Kinds do
			for variant = 1, Trees.Variants do
				local model = Instance.new("Model")
				model.Name = kind .. variant
				model:SetAttribute("Species", kind)
				model.Parent = library
				local source = Trees.blueprint(kind, variant)
				model:SetAttribute("SourceHeight", source.Height)
				for group, shapes in source.Groups do
					local origin = Instance.new("Part")
					origin.Material, origin.Color = Enum.Material.SmoothPlastic, PALETTE[group]
					origin.CFrame, origin.Size, origin.Anchored = CFrame.new(), Vector3.new(0.05, 0.05, 0.05), true
					table.insert(inputs, origin)
					for _, item in shapes do
						local part: BasePart
						if item.Form == "Ball" then
							part = (ellipsoid :: BasePart):Clone()
						else
							local primitive = Instance.new("Part")
							primitive.Shape = (Enum.PartType :: any)[item.Form]
							part = primitive
						end
						part.Anchored, part.CFrame, part.Size = true, item.Frame, item.Size
						table.insert(inputs, part)
					end
					local others = table.clone(inputs)
					table.remove(others, 1)
					local result = geometry:UnionAsync(origin, others, {
						SplitApart = false,
						CollisionFidelity = Enum.CollisionFidelity.Box,
						RenderFidelity = Enum.RenderFidelity.Automatic,
					})
					if #result ~= 1 or not result[1]:IsA("PartOperation") then
						for _, item in result do
							item:Destroy()
						end
						error("Junction CSG returned an invalid asset")
					end
					local part = result[1]
					part.Name = if group == 1 then "BranchingWood" else "SmallLeaves" .. group
					part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
					part.CastShadow, part.UsePartColor = true, true
					part.Material = if group == 1 then Enum.Material.Wood else Enum.Material.SmoothPlastic
					part.Color = PALETTE[group]
					if kind == "Eucalyptus" then
						local c = PALETTE[group]
						part.Color = if group == 1
							then Color3.fromRGB(161, 153, 133)
							else Color3.new(
								c.R * 0.7 + 105 / 255 * 0.3,
								c.G * 0.7 + 126 / 255 * 0.3,
								c.B * 0.7 + 96 / 255 * 0.3
							)
					end
					part.CFrame = CFrame.new()
					part:SetAttribute("SourcePrimitives", #shapes)
					part.Parent = model
					clear()
					Util.yield()
				end
			end
		end
	end)
	clear()
	if ellipsoid then
		ellipsoid:Destroy()
	end
	if not ok then
		library:Destroy()
		error(`Junction trees failed before map replacement: {tostring(err)}`)
	end
	if old then
		old:Destroy()
	end
	library.Parent = storage
	return library
end

function Trees.plant(
	library: Folder,
	parent: Instance,
	kind: string,
	variant: number,
	position: Vector3,
	height: number,
	yaw: number
): Model
	local imported = CreatorAssets.place(
		if kind == "Shrub" or kind == "Fern" then kind else "Tree",
		variant,
		parent,
		position,
		height,
		yaw
	)
	if imported then
		return imported
	end
	local template = library:FindFirstChild(kind .. variant) :: Model
	assert(template, "Missing prepared junction species")
	local plant = template:Clone()
	plant.Name = kind
	plant.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	plant:SetAttribute("AssetVersion", Trees.Version)
	plant:SetAttribute("GroundPosition", position)
	local scale = height / (template:GetAttribute("SourceHeight") :: number)
	local frame = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	for _, item in plant:GetChildren() do
		local part = item :: BasePart
		part.Size *= scale
		-- CSG retains the origin of its identity reference part; preserve that authored origin.
		part.CFrame = frame
	end
	if kind ~= "Shrub" and kind ~= "Fern" then
		Util.cylinder(
			plant,
			"TrunkCollision",
			position - Vector3.new(0, 0.5, 0),
			position + Vector3.new(0, height * 0.3, 0),
			math.max(0.6, 1.1 * scale),
			{ Transparency = 1, CastShadow = false }
		)
	end
	plant.Parent = parent
	return plant
end

return Trees
