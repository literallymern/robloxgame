--!strict
-- Road signs in a German-influenced style (Kagundi was a German colony; German is an official
-- language): yellow town signs that show the name crossed out on the back when you leave,
-- yellow arrow-shaped direction signs with the road number, round speed limit signs, stop signs,
-- chevron boards in sharp bends, blue signs for facilities and a welcome board with the flag at
-- the border crossings. Text is drawn with SurfaceGuis, so no images need uploading (except the
-- flag, which is already in Config/Assets).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(script.Parent.Util)

local Signs = {}

local UP = Vector3.new(0, 1, 0)
local YELLOW = Color3.fromRGB(250, 200, 20)
local BLACK = Color3.fromRGB(20, 20, 20)
local WHITE = Color3.fromRGB(245, 245, 240)
local RED = Color3.fromRGB(200, 30, 36)
local BLUE = Color3.fromRGB(24, 78, 160)
local POST: Util.PartOptions = { Material = Enum.Material.Metal, Color = Color3.fromRGB(150, 152, 156) }
local PIXELS = 40 -- SurfaceGui pixels per stud

local function gui(board: BasePart, face: Enum.NormalId): SurfaceGui
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Face" .. face.Name
	surface.Face = face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = PIXELS
	surface.LightInfluence = 1
	surface.MaxDistance = 400
	surface.Parent = board
	return surface
end

local function frame(parent: Instance, colour: Color3, position: UDim2, size: UDim2): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = colour
	f.BorderSizePixel = 0
	f.Position = position
	f.Size = size
	f.Parent = parent
	return f
end

local function text(parent: Instance, value: string, colour: Color3, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = colour
	label.Text = value
	label.Parent = parent
	return label
end

local function full(): UDim2
	return UDim2.fromScale(1, 1)
end

-- A board facing `face` (the readable side), centred at `centre`.
local function board(parent: Instance, centre: Vector3, face: Vector3, size: Vector3, colour: Color3): Part
	return Util.part(parent, "Board", CFrame.lookAt(centre, centre + face), size, {
		Material = Enum.Material.SmoothPlastic,
		Color = colour,
	})
end

local function post(parent: Instance, base: Vector3, height: number)
	Util.cylinder(parent, "Post", base - UP * 1.5, base + UP * height, 0.35, POST)
end

-- The reader's right, for a sign facing `face`.
local function readerRight(face: Vector3): Vector3
	return Vector3.new(face.Z, 0, -face.X)
end

local function newModel(sign: any): (Model, Vector3, Vector3)
	local model = Instance.new("Model")
	model.Name = `{sign.Kind}Sign`
	local base = Vector3.new(sign.X, sign.Y, sign.Z)
	local face = Vector3.new(sign.FaceX, 0, sign.FaceZ).Unit
	return model, base, face
end

-- Yellow town sign; the back shows the name crossed out (end of the town).
function Signs.town(parent: Instance, sign: any): Model
	local model, base, face = newModel(sign)
	local right = readerRight(face)
	local width, height = 10, 4
	local centre = base + UP * 6
	local b = board(model, centre, face, Vector3.new(width, height, 0.2), YELLOW)
	for _, side in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local g = gui(b, side)
		frame(g, BLACK, UDim2.new(), full())
		local inner = frame(g, YELLOW, UDim2.fromOffset(8, 8), UDim2.new(1, -16, 1, -16))
		text(inner, sign.Text, BLACK, UDim2.fromScale(0.05, 0.12), UDim2.fromScale(0.9, 0.56))
		text(inner, "East District", BLACK, UDim2.fromScale(0.25, 0.7), UDim2.fromScale(0.5, 0.18))
		if side == Enum.NormalId.Back then
			local bar = frame(inner, RED, UDim2.fromScale(-0.05, 0.42), UDim2.fromScale(1.1, 0.12))
			bar.Rotation = -14
		end
	end
	post(model, base + right * (width / 2 - 1), 4)
	post(model, base - right * (width / 2 - 1), 4)
	model.PrimaryPart = b
	model.Parent = parent
	return model
end

-- Blue sign with the name of a facility (airport, mine, barracks, border crossing).
function Signs.facility(parent: Instance, sign: any): Model
	local model, base, face = newModel(sign)
	local right = readerRight(face)
	local width = math.clamp(#sign.Text * 0.55, 8, 15)
	local b = board(model, base + UP * 6, face, Vector3.new(width, 2.6, 0.2), BLUE)
	local g = gui(b, Enum.NormalId.Front)
	frame(g, WHITE, UDim2.new(), full())
	local inner = frame(g, BLUE, UDim2.fromOffset(5, 5), UDim2.new(1, -10, 1, -10))
	text(inner, sign.Text, WHITE, UDim2.fromScale(0.04, 0.15), UDim2.fromScale(0.92, 0.7))
	post(model, base + right * (width / 2 - 1), 4.7)
	post(model, base - right * (width / 2 - 1), 4.7)
	model.PrimaryPart = b
	model.Parent = parent
	return model
end

-- A round sign: coloured rim and a face of another colour with text on it.
local function roundSign(model: Model, centre: Vector3, face: Vector3, diameter: number, rim: Color3, inside: Color3)
	local frameAt = CFrame.fromMatrix(centre, face, UP)
	Util.part(model, "Rim", frameAt, Vector3.new(0.15, diameter, diameter), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.SmoothPlastic,
		Color = rim,
	})
	local inner = diameter * 0.78
	return Util.part(model, "Face", frameAt + face * 0.03, Vector3.new(0.15, inner, inner), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.SmoothPlastic,
		Color = inside,
		CanCollide = false,
	})
end

function Signs.speed(parent: Instance, sign: any): Model
	local model, base, face = newModel(sign)
	local centre = base + UP * 6.5
	local f = roundSign(model, centre, face, 3.2, RED, WHITE)
	local g = gui(f, Enum.NormalId.Right)
	text(g, tostring(sign.Limit), BLACK, UDim2.fromScale(0.12, 0.22), UDim2.fromScale(0.76, 0.56))
	post(model, base, 4.9)
	model.PrimaryPart = f
	model.Parent = parent
	return model
end

function Signs.stop(parent: Instance, sign: any): Model
	local model, base, face = newModel(sign)
	local centre = base + UP * 6
	local f = roundSign(model, centre, face, 3, WHITE, RED)
	local g = gui(f, Enum.NormalId.Right)
	text(g, "STOP", WHITE, UDim2.fromScale(0.1, 0.3), UDim2.fromScale(0.8, 0.4))
	post(model, base, 4.5)
	model.PrimaryPart = f
	model.Parent = parent
	return model
end

-- Arrow-shaped direction boards stacked on two posts ("Pfeilwegweiser").
function Signs.direction(parent: Instance, sign: any): Model
	local model, base, face = newModel(sign)
	local right = readerRight(face)
	local length, height, tip, thickness = 9, 1.8, 1.6, 0.2
	local options: Util.PartOptions = { Material = Enum.Material.SmoothPlastic, Color = YELLOW }
	local boards = sign.Boards
	local top = 4 + #boards * (height + 0.3)
	local primary: Part? = nil
	for k, info in boards do
		local cy = top - (k - 0.5) * (height + 0.3)
		local towards = if info.Arrow == "Left" then -right else right
		-- The rectangle sits opposite the tip so the whole arrow is centred on the posts.
		local rectCentre = base + UP * cy - towards * (tip / 2)
		local b = board(model, rectCentre, face, Vector3.new(length, height, thickness), YELLOW)
		primary = primary or b
		local g = gui(b, Enum.NormalId.Front)
		frame(g, BLACK, UDim2.new(), full())
		local inner = frame(g, YELLOW, UDim2.fromOffset(4, 4), UDim2.new(1, -8, 1, -8))
		local label = if info.Road then `{info.Road}   {info.Text}` else info.Text
		text(inner, label, BLACK, UDim2.fromScale(0.05, 0.14), UDim2.fromScale(0.9, 0.72))
		-- Tip: two wedges, upper and lower half of a triangle.
		local tipCentre = rectCentre + towards * (length / 2 + tip / 2)
		for _, half in { 1, -1 } do
			local centre = tipCentre + UP * (half * height / 4)
			local wedgeFrame = CFrame.lookAt(centre, centre + towards)
			if half < 0 then
				wedgeFrame *= CFrame.Angles(0, 0, math.pi)
			end
			Util.wedge(model, "Tip", wedgeFrame, Vector3.new(thickness, height / 2, tip), options)
		end
	end
	local postHeight = top - 0.2
	post(model, base + right * 3.2, postHeight)
	post(model, base - right * 3.2, postHeight)
	model.PrimaryPart = primary
	model.Parent = parent
	return model
end

-- Red board with white chevrons, readable from both directions.
function Signs.chevron(parent: Instance, sign: any): Model
	local model, base, face = newModel(sign)
	local b = board(model, base + UP * 4, face, Vector3.new(2.6, 2, 0.15), RED)
	for _, side in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local g = gui(b, side)
		frame(g, RED, UDim2.new(), full())
		-- The back is read by traffic going the other way, for whom the bend turns the other way.
		local turnsRight = (sign.Turn == "Right") == (side == Enum.NormalId.Front)
		text(g, if turnsRight then ">>" else "<<", WHITE, UDim2.fromScale(0.1, 0.1), UDim2.fromScale(0.8, 0.8))
	end
	post(model, base, 2.9)
	model.PrimaryPart = b
	model.Parent = parent
	return model
end

-- The welcome board at a border crossing, with the flag of Kagundi.
function Signs.welcome(parent: Instance, sign: any): Model
	local model, base, face = newModel(sign)
	local right = readerRight(face)
	local width, height = 24, 8
	local b = board(model, base + UP * 9, face, Vector3.new(width, height, 0.3), Color3.fromRGB(22, 88, 56))
	local g = gui(b, Enum.NormalId.Front)
	frame(g, WHITE, UDim2.new(), full())
	local inner = frame(g, Color3.fromRGB(22, 88, 56), UDim2.fromOffset(10, 10), UDim2.new(1, -20, 1, -20))
	local ok, assets = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Assets")) :: any
	end)
	if ok and assets and assets.Images and assets.Images.Flag then
		local flag = Instance.new("ImageLabel")
		flag.BackgroundTransparency = 1
		flag.Position = UDim2.fromScale(0.03, 0.2)
		flag.Size = UDim2.fromScale(0.3, 0.6)
		flag.Image = assets.Images.Flag
		flag.Parent = inner
	end
	text(inner, "WELCOME TO THE", WHITE, UDim2.fromScale(0.36, 0.1), UDim2.fromScale(0.6, 0.18))
	text(inner, "DEMOCRATIC REPUBLIC OF KAGUNDI", WHITE, UDim2.fromScale(0.36, 0.32), UDim2.fromScale(0.6, 0.26))
	text(
		inner,
		"Willkommen in der Demokratischen Republik Kagundi",
		WHITE,
		UDim2.fromScale(0.36, 0.66),
		UDim2.fromScale(0.6, 0.16)
	)
	post(model, base + right * (width / 2 - 2), 5)
	post(model, base - right * (width / 2 - 2), 5)
	model.PrimaryPart = b
	model.Parent = parent
	return model
end

local BUILDERS: { [string]: (Instance, any) -> Model } = {
	Town = Signs.town,
	Facility = Signs.facility,
	Speed = Signs.speed,
	Stop = Signs.stop,
	Direction = Signs.direction,
	Chevron = Signs.chevron,
	Welcome = Signs.welcome,
}

function Signs.build(parent: Instance, sign: any): Model?
	local builder = BUILDERS[sign.Kind]
	if not builder then
		warn(`[Ro-Nation:BuildMap] Unknown sign kind {sign.Kind}`)
		return nil
	end
	return builder(parent, sign)
end

return Signs
