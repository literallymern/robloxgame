--!strict
-- Detailed native foliage is compiled once in Studio, then cloned as a single saved CSG
-- part per crown. No uploaded meshes, runtime mesh generation or texture IDs are required.
-- GeometryService supports detached primitives and SplitApart=false for open leaf sprays:
-- https://create.roblox.com/docs/reference/engine/classes/GeometryService
local Hash = require(script.Parent.Parent.Hash)

local CanopyLibrary = {}
CanopyLibrary.Version = "highland-canopies-1"
CanopyLibrary.Variants = 4
CanopyLibrary.Kinds = table.freeze({ "Acacia", "Broadleaf", "Eucalyptus", "Pine", "Bush" })

export type Blade = {
	Position: Vector3,
	Size: Vector3,
	Frame: CFrame,
	Geometry: string,
}

local FOLDER = "RoNationCanopyLibrary"
local OWNER = "RoNationCanopyLibrary"
local cached: Folder? = nil

-- Source shapes form separate, tapered sprays with holes between them, rather than a
-- stretched sphere. These immutable blueprints can be inspected without a CSG engine.
function CanopyLibrary.blueprint(kind: string, variant: number): { Blade }
	local kindIndex = table.find(CanopyLibrary.Kinds, kind)
	assert(kindIndex, `Unknown canopy species {kind}`)
	assert(variant >= 1 and variant <= CanopyLibrary.Variants and variant % 1 == 0, "Invalid canopy variant")
	local sources: { Blade } = {}
	local function random(salt: number): number
		return Hash.unit(kindIndex :: number, variant, salt)
	end
	local function source(frame: CFrame, size: Vector3, geometry: string)
		table.insert(sources, { Position = frame.Position, Size = size, Frame = frame, Geometry = geometry })
	end
	local function twig(a: Vector3, b: Vector3, thickness: number)
		local length = (b - a).Magnitude
		if length < 0.001 then
			return
		end
		local frame = if math.abs(b.X - a.X) + math.abs(b.Z - a.Z) < 0.00001
			then CFrame.new((a + b) / 2) * CFrame.Angles(0, 0, math.pi / 2)
			else CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
		source(frame, Vector3.new(length, thickness, thickness), "Cylinder")
	end
	local function leaf(frame: CFrame, width: number, length: number)
		-- A flat wedge viewed from above is a rectangle. Four mirrored right-triangle
		-- prisms instead form a pointed diamond leaf, with real tapered edges.
		local flips =
			{ CFrame.new(), CFrame.Angles(0, 0, math.pi), CFrame.Angles(0, math.pi, 0), CFrame.Angles(math.pi, 0, 0) }
		for _, flip in flips do
			local quarter = frame * flip * CFrame.new(width / 4, 0, -length / 4) * CFrame.Angles(0, 0, -math.pi / 2)
			source(quarter, Vector3.new(0.009, width / 2 * 1.005, length / 2 * 1.005), "Wedge")
		end
	end
	if kind == "Pine" then
		twig(Vector3.new(0, -0.5, 0), Vector3.new(0, 0.5, 0), 0.018)
		for tier = 1, 5 do
			local radius = 0.47 - tier * 0.065
			local y = -0.55 + tier * 0.19
			for limb = 1, 6 do
				local angle = limb * math.pi / 3 + tier * 0.39 + random(tier * 11 + limb) * 0.24
				local reach = radius * (0.88 + random(tier * 23 + limb) * 0.24)
				local endPoint = Vector3.new(math.sin(angle) * reach, y - 0.025, math.cos(angle) * reach)
				twig(Vector3.new(0, y + 0.055, 0), endPoint, 0.012)
				local frame = CFrame.new(endPoint * Vector3.new(0.72, 1, 0.72))
					* CFrame.Angles(0.12 + random(limb + tier * 29) * 0.17, angle, 0.05)
				leaf(frame, 0.12 + radius * 0.11, reach * 0.98)
			end
		end
	else
		local groups = if kind == "Broadleaf" then 3 else 4
		local perGroup = if kind == "Broadleaf" then 12 else 9
		for group = 1, groups do
			local angle = group * math.pi * 2 / groups + random(group + 3) * 0.5
			local narrow = kind == "Eucalyptus"
			local flat = kind == "Acacia"
			local centre = Vector3.new(
				math.sin(angle) * (0.09 + random(group + 9) * 0.09),
				(random(group + 18) - 0.5) * (if narrow then 0.34 elseif flat then 0.08 else 0.2),
				math.cos(angle) * (0.09 + random(group + 13) * 0.09)
			)
			twig(Vector3.new(0, -0.32, 0), centre, 0.018)
			for index = 1, perGroup do
				local yaw = angle + index * 2.399963 + variant * 0.2
				local radius = 0.06 + 0.11 * math.sqrt(index / perGroup)
				local offset = Vector3.new(
					math.sin(yaw) * radius,
					(if flat then 0.09 else 0.22) * (index / perGroup - 0.5) + (random(group * 41 + index) - 0.5) * 0.04,
					math.cos(yaw) * radius
				)
				local point = centre + offset
				twig(centre, point, 0.009)
				local frame = CFrame.new(point)
					* CFrame.Angles(0, yaw, 0)
					* CFrame.Angles(
						if narrow
							then -0.35 + random(group * 47 + index) * 0.7
							else (random(index + group * 53) - 0.5) * 0.85,
						0,
						(random(index + group * 71) - 0.5) * (if narrow then 0.95 else 0.55)
					)
				local width = if narrow
					then 0.11
					else (if flat then 0.115 else 0.14) + random(index + group * 29) * 0.025
				local length = (if narrow then 0.24 elseif flat then 0.19 else 0.24)
					+ random(index + group * 31) * 0.035
				leaf(frame, width, length)
			end
		end
	end
	return sources
end

local function key(kind: string, variant: number): string
	return `{kind}{variant}`
end

local function complete(folder: Instance?): boolean
	if
		not folder
		or not folder:IsA("Folder")
		or folder:GetAttribute("ManagedBy") ~= OWNER
		or folder:GetAttribute("CanopyVersion") ~= CanopyLibrary.Version
	then
		return false
	end
	for _, kind in CanopyLibrary.Kinds do
		for variant = 1, CanopyLibrary.Variants do
			local template = folder:FindFirstChild(key(kind, variant))
			if not template or not template:IsA("PartOperation") then
				return false
			end
		end
	end
	return true
end

function CanopyLibrary.prepare(log: ((string) -> ())?, geometryOverride: any?): { Created: boolean, Templates: number }
	assert(not game:GetService("RunService"):IsRunning(), "Canopy templates must be compiled in Studio edit mode")
	local storage = game:GetService("ServerStorage")
	local existing = storage:FindFirstChild(FOLDER)
	if complete(existing) then
		cached = existing :: Folder
		return { Created = false, Templates = #CanopyLibrary.Kinds * CanopyLibrary.Variants }
	end
	assert(
		not existing or existing:GetAttribute("ManagedBy") == OWNER,
		"Canopy library name is occupied by custom content"
	)
	local geometry = geometryOverride or game:GetService("GeometryService")
	local staging = Instance.new("Folder")
	staging.Name = FOLDER
	staging:SetAttribute("ManagedBy", OWNER)
	staging:SetAttribute("CanopyVersion", CanopyLibrary.Version)
	local inputs: { BasePart } = {}
	local function clearInputs()
		for _, part in inputs do
			part:Destroy()
		end
		table.clear(inputs)
	end
	local ok, err = pcall(function()
		for _, kind in CanopyLibrary.Kinds do
			for variant = 1, CanopyLibrary.Variants do
				local blueprint = CanopyLibrary.blueprint(kind, variant)
				-- A centered identity-frame root keeps all union geometry in the same local
				-- axes as its blueprint, rather than the rotated first leaf's coordinate space.
				local reference = Instance.new("Part")
				reference.Anchored = true
				reference.CanCollide = false
				reference.Material = Enum.Material.LeafyGrass
				reference.Color = Color3.fromRGB(72, 104, 61)
				reference.CFrame = CFrame.new()
				reference.Size = Vector3.new(0.05, 0.05, 0.05)
				table.insert(inputs, reference)
				local bladeCount, twigCount = 0, 0
				for _, source in blueprint do
					local part: BasePart
					if source.Geometry == "Cylinder" then
						local cylinder = Instance.new("Part")
						cylinder.Shape = Enum.PartType.Cylinder
						part = cylinder
						twigCount += 1
					else
						part = Instance.new("WedgePart")
						bladeCount += 1
					end
					part.Name = "LeafSpraySource"
					part.Anchored = true
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = false
					part.Material = Enum.Material.LeafyGrass
					part.Color = Color3.fromRGB(72, 104, 61)
					part.Size = source.Size * 20
					part.CFrame = CFrame.new(source.Frame.Position * 20) * (source.Frame - source.Frame.Position)
					table.insert(inputs, part)
				end
				local others = {}
				for i = 2, #inputs do
					table.insert(others, inputs[i])
				end
				local results = geometry:UnionAsync(inputs[1], others, {
					SplitApart = false,
					CollisionFidelity = Enum.CollisionFidelity.Box,
					RenderFidelity = Enum.RenderFidelity.Automatic,
				})
				if #results ~= 1 or not results[1]:IsA("PartOperation") then
					for _, result in results do
						result:Destroy()
					end
					error("CSG did not produce one reusable canopy")
				end
				local template = results[1] :: UnionOperation
				template.Name = key(kind, variant)
				template.Anchored = true
				template.CanCollide = false
				template.CanTouch = false
				template.CanQuery = false
				template.CastShadow = true
				template.UsePartColor = true
				template.Material = Enum.Material.LeafyGrass
				template.CFrame = CFrame.new()
				template:SetAttribute("CanopyVersion", CanopyLibrary.Version)
				template:SetAttribute("CanopySpecies", kind)
				template:SetAttribute("CanopyVariant", variant)
				template:SetAttribute("SourceBladeCount", bladeCount)
				template:SetAttribute("SourceTwigCount", twigCount)
				template:SetAttribute("SourceLeafCount", bladeCount / 4)
				template.Parent = staging
				clearInputs()
				if log then
					log(`Compiled open foliage template {kind} {variant}/{CanopyLibrary.Variants}.`)
				end
			end
		end
	end)
	clearInputs()
	if not ok then
		staging:Destroy()
		error(`Canopy compilation failed; existing library and map retained: {tostring(err)}`)
	end
	if existing then
		existing:Destroy()
	end
	staging.Parent = storage
	cached = staging
	return { Created = true, Templates = #CanopyLibrary.Kinds * CanopyLibrary.Variants }
end

function CanopyLibrary.crown(
	kind: string,
	variant: number,
	frame: CFrame,
	size: Vector3,
	colour: Color3,
	parent: Instance
): BasePart
	if not cached or cached.Parent == nil then
		CanopyLibrary.prepare()
	end
	local library = cached :: Folder
	local template = library:FindFirstChild(key(kind, variant))
	assert(template and template:IsA("BasePart"), `Missing prepared canopy {kind} {variant}`)
	local crown = template:Clone() :: BasePart
	crown.Name = "Foliage"
	crown.Size = size
	-- New CSG outputs retain their reference origin, which may differ from physical
	-- extents. Size changes scale that offset: align the resized body, not its origin.
	local localExtents = crown.CFrame:ToObjectSpace(crown.ExtentsCFrame)
	crown.CFrame = frame * localExtents:Inverse()
	crown.Color = colour
	crown.Parent = parent
	return crown
end

return CanopyLibrary
