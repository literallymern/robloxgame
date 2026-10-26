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
	Shape: Enum.PartType?,
	Decoration: boolean?, -- true = no collision, queries, touches or shadow (markings, outlines)
}

function Util.part(parent: Instance, name: string, cframe: CFrame, size: Vector3, options: PartOptions?): Part
	local o: PartOptions = options or {}
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	if o.Shape then
		part.Shape = o.Shape
	end
	part.Size = size
	part.CFrame = cframe
	part.Material = o.Material or Enum.Material.SmoothPlastic
	part.Color = o.Color or Color3.fromRGB(200, 200, 200)
	part.Transparency = o.Transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if o.Decoration then
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
	else
		part.CanCollide = if o.CanCollide == nil then true else o.CanCollide
	end
	part.Parent = parent
	return part
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

local function signFace(board: BasePart, face: Enum.NormalId, text: string, background: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0.5
	local text_ = Instance.new("TextLabel")
	text_.Size = UDim2.fromScale(1, 1)
	text_.BackgroundColor3 = background
	text_.BorderSizePixel = 0
	text_.TextScaled = true
	text_.Font = Enum.Font.GothamBold
	text_.TextColor3 = Color3.fromRGB(255, 255, 255)
	text_.Text = text
	text_.Parent = gui
	gui.Parent = board
end

-- A road sign on a post. `facing` is the direction the readable side looks towards.
function Util.sign(parent: Instance, text: string, groundPosition: Vector3, facing: Vector3, background: Color3?)
	local model = Instance.new("Model")
	model.Name = "Sign " .. text
	local colour = background or Color3.fromRGB(28, 92, 52)
	local look = Vector3.new(facing.X, 0, facing.Z).Unit
	local up = Vector3.new(0, 1, 0)
	Util.part(model, "Post", CFrame.new(groundPosition + up * 5), Vector3.new(0.6, 10, 0.6), {
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(150, 150, 150),
	})
	local boardCentre = groundPosition + up * 9
	local board = Util.part(model, "Board", CFrame.lookAt(boardCentre, boardCentre + look), Vector3.new(14, 4, 0.4), {
		Color = colour,
	})
	signFace(board, Enum.NormalId.Front, text, colour)
	signFace(board, Enum.NormalId.Back, text, colour)
	model.PrimaryPart = board
	model.Parent = parent
	return model
end

return Util
