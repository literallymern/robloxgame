--!strict
-- Shared helpers for the map builders: generated folders, parts, labels and signs.
-- Everything the builders create carries the attribute GeneratedBy = "BuildMap", so a rerun
-- can remove exactly its own output and leave hand-built work alone.

local Util = {}

Util.GENERATED = "BuildMap"

local lastYield = os.clock()

-- Gives Studio a moment to breathe during long loops (about ten times a second).
function Util.yield()
	if os.clock() - lastYield > 0.1 then
		task.wait()
		lastYield = os.clock()
	end
end

function Util.mark(instance: Instance)
	instance:SetAttribute("GeneratedBy", Util.GENERATED)
end

function Util.isGenerated(instance: Instance): boolean
	return instance:GetAttribute("GeneratedBy") == Util.GENERATED
end

-- Removes the children of `parent` that an earlier run generated. Returns how many.
function Util.clearGenerated(parent: Instance): number
	local removed = 0
	for _, child in parent:GetChildren() do
		if Util.isGenerated(child) then
			child:Destroy()
			removed += 1
		end
	end
	return removed
end

-- A folder for generated content (always new; clear old ones with clearGenerated first).
function Util.folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	Util.mark(folder)
	folder.Parent = parent
	return folder
end

-- A generated folder that is not in the place yet. Filling it first and parenting it when it is
-- complete is much faster for thousands of parts.
function Util.detachedFolder(name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	Util.mark(folder)
	return folder
end

-- A container that is not generated itself (Justin may add his own content next to ours).
function Util.container(parent: Instance, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Util.rgb(colour: { number }): Color3
	return Color3.fromRGB(colour[1], colour[2], colour[3])
end

export type PartOptions = {
	Material: Enum.Material?,
	Color: Color3?,
	Transparency: number?,
	CanCollide: boolean?,
	CanQuery: boolean?, -- false = ignored by raycasts (the camera looks through foliage)
	CastShadow: boolean?,
	Shape: Enum.PartType?,
	Decoration: boolean?, -- true = no collision, queries, touches or shadow (markings, outlines)
	Reflectance: number?,
}

local function setUp(part: BasePart, parent: Instance, name: string, cframe: CFrame, size: Vector3, o: PartOptions)
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Material = o.Material or Enum.Material.SmoothPlastic
	part.Color = o.Color or Color3.fromRGB(200, 200, 200)
	part.Transparency = o.Transparency or 0
	if o.Reflectance then
		part.Reflectance = o.Reflectance
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if o.Decoration then
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
	else
		part.CanCollide = if o.CanCollide == nil then true else o.CanCollide
		if o.CanQuery == false then
			part.CanQuery = false
		end
		if o.CastShadow == false then
			part.CastShadow = false
		end
		if o.CanCollide == false then
			part.CanTouch = false
		end
	end
	part.Parent = parent
end

function Util.part(parent: Instance, name: string, cframe: CFrame, size: Vector3, options: PartOptions?): Part
	local o: PartOptions = options or {}
	local part = Instance.new("Part")
	if o.Shape then
		part.Shape = o.Shape
	end
	setUp(part, parent, name, cframe, size, o)
	return part
end

-- A wedge: full height at the back, sloping down to the front (towards cframe.LookVector).
function Util.wedge(parent: Instance, name: string, cframe: CFrame, size: Vector3, options: PartOptions?): WedgePart
	local wedge = Instance.new("WedgePart")
	setUp(wedge, parent, name, cframe, size, options or {})
	return wedge
end

-- An ellipsoid of the given size (a block with a sphere mesh, which stretches with the part).
function Util.ellipsoid(parent: Instance, name: string, cframe: CFrame, size: Vector3, options: PartOptions?): Part
	local part = Util.part(parent, name, cframe, size, options)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- A cylinder from point A to point B.
function Util.cylinder(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	diameter: number,
	options: PartOptions?
): Part
	local o: PartOptions = table.clone(options or {})
	o.Shape = Enum.PartType.Cylinder
	local length = (b - a).Magnitude
	local mid = (a + b) / 2
	local frame
	if math.abs(b.X - a.X) + math.abs(b.Z - a.Z) < 1e-3 then
		frame = CFrame.new(mid) * CFrame.Angles(0, 0, math.pi / 2) -- upright
	else
		frame = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0)
	end
	return Util.part(parent, name, frame, Vector3.new(length, diameter, diameter), o)
end

-- A flat, possibly tilted strip from A to B whose top surface runs through A and B.
function Util.strip(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	thickness: number,
	options: PartOptions?
): Part
	local length = (b - a).Magnitude
	local frame = CFrame.lookAt((a + b) / 2, b)
	frame = frame - frame.UpVector * (thickness / 2)
	return Util.part(parent, name, frame, Vector3.new(width, thickness, length), options)
end

-- A floating name above a part, constant size on screen.
function Util.label(adornee: BasePart, text: string, heightAbove: number, maxDistance: number, width: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(width or 220, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, heightAbove, 0)
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	local text_ = Instance.new("TextLabel")
	text_.Size = UDim2.fromScale(1, 1)
	text_.BackgroundTransparency = 1
	text_.TextScaled = true
	text_.Font = Enum.Font.GothamBold
	text_.TextColor3 = Color3.fromRGB(255, 255, 255)
	text_.TextStrokeTransparency = 0.2
	text_.Text = text
	text_.Parent = gui
	gui.Parent = adornee
end

return Util
