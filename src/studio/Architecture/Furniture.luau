--!strict
-- Furniture and fittings, built from a few parts each. Every piece takes `base`: a CFrame on
-- the floor at the centre of the piece, whose LookVector is the piece's front (the side a
-- person uses: where one sits at a desk, the direction a seated person faces, the foot end of
-- a bed). Wall pieces take `wall`: a CFrame on the wall surface, LookVector into the room.
-- Seats are real Seat parts, so players can sit. Small items are details without collision.
-- Proportions follow the Roblox character (about 5 studs tall, seat height 1.7, desk 3).

local Parts = require(script.Parent.Parts)
local Materials = require(script.Parent.Materials)

type Options = Parts.Options

local Furniture = {}

local function piece(
	parent: Instance,
	name: string,
	base: CFrame,
	x: number,
	y: number,
	z: number,
	size: Vector3,
	o: Options
): Part
	-- (x, y, z) in the piece's frame: X right, Y up, Z towards the back (front is -Z).
	return Parts.part(parent, name, base * CFrame.new(x, y, z), size, o)
end

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- Desks and seating ---------------------------------------------------------------------------

function Furniture.desk(parent: Instance, base: CFrame, w: number, d: number, top: Options, frame: Options?)
	local f = frame or top
	piece(parent, "DeskTop", base, 0, 2.95, 0, v(w, 0.18, d), top)
	piece(parent, "DeskSide", base, -w / 2 + 0.12, 1.43, 0, v(0.2, 2.86, d - 0.2), f)
	piece(parent, "DeskSide", base, w / 2 - 0.12, 1.43, 0, v(0.2, 2.86, d - 0.2), f)
	piece(parent, "DeskPanel", base, 0, 1.9, d / 2 - 0.3, v(w - 0.45, 1.6, 0.12), f)
end

-- A monitor and keyboard on a desk top at height `top` above `base` (the screen faces the user,
-- who is in front of the desk).
function Furniture.computer(parent: Instance, base: CFrame, top: number, dual: boolean?)
	local dark = Parts.detail(Materials.Plastic.Black)
	local screens: { number } = if dual then { -1.35, 1.35 } else { 0 }
	for _, x in screens do
		local turn = CFrame.Angles(0, -x * 0.12, 0)
		local frame = base * CFrame.new(x, 0, 0.5) * turn
		piece(parent, "Monitor", frame, 0, top + 1.45, 0, v(2.5, 1.5, 0.14), dark)
		piece(parent, "Screen", frame, 0, top + 1.45, -0.075, v(2.3, 1.3, 0.02), Parts.detail(Materials.Screen))
		piece(parent, "MonitorStand", frame, 0, top + 0.4, 0.15, v(0.25, 0.8, 0.25), dark)
	end
	piece(parent, "Keyboard", base, 0, top + 0.05, -0.55, v(1.9, 0.08, 0.6), dark)
	piece(parent, "Mouse", base, 1.3, top + 0.05, -0.55, v(0.25, 0.08, 0.4), dark)
end

function Furniture.officeChair(parent: Instance, base: CFrame, fabric: Options)
	Parts.seat(parent, "OfficeChair", base * CFrame.new(0, 1.55, 0), v(2, 0.35, 2), fabric)
	piece(parent, "ChairBack", base, 0, 2.95, 0.95, v(1.9, 2.2, 0.3), fabric)
	local metal = Parts.detail(Materials.Metal.Dark)
	Parts.cylinder(
		parent,
		"ChairColumn",
		(base * CFrame.new(0, 0.15, 0)).Position,
		(base * CFrame.new(0, 1.4, 0)).Position,
		0.3,
		metal
	)
	Parts.cylinder(
		parent,
		"ChairFoot",
		(base * CFrame.new(0, 0, 0)).Position,
		(base * CFrame.new(0, 0.2, 0)).Position,
		2,
		metal
	)
end

function Furniture.chair(parent: Instance, base: CFrame, wood: Options, fabric: Options?)
	Parts.seat(parent, "Chair", base * CFrame.new(0, 1.55, 0), v(1.9, 0.3, 1.9), fabric or wood)
	piece(parent, "ChairBack", base, 0, 2.75, 0.85, v(1.8, 2.1, 0.22), wood)
	piece(parent, "ChairFrame", base, -0.8, 0.7, 0, v(0.2, 1.4, 1.7), Parts.detail(wood))
	piece(parent, "ChairFrame", base, 0.8, 0.7, 0, v(0.2, 1.4, 1.7), Parts.detail(wood))
end

function Furniture.armchair(parent: Instance, base: CFrame, upholstery: Options)
	piece(parent, "ArmchairBase", base, 0, 0.6, 0, v(3, 1.2, 2.8), upholstery)
	Parts.seat(parent, "Armchair", base * CFrame.new(0, 1.4, -0.1), v(2.2, 0.4, 2.2), upholstery)
	piece(parent, "ArmchairBack", base, 0, 2.3, 1.15, v(3, 2.6, 0.6), upholstery)
	piece(parent, "ArmchairArm", base, -1.3, 1.6, 0, v(0.5, 0.8, 2.6), upholstery)
	piece(parent, "ArmchairArm", base, 1.3, 1.6, 0, v(0.5, 0.8, 2.6), upholstery)
end

function Furniture.sofa(parent: Instance, base: CFrame, seats: number, upholstery: Options)
	local len = seats * 2.6
	piece(parent, "SofaBase", base, 0, 0.6, 0, v(len, 1.2, 2.8), upholstery)
	for i = 1, seats do
		Parts.seat(
			parent,
			"Sofa",
			base * CFrame.new(-len / 2 + (i - 0.5) * 2.6, 1.4, -0.1),
			v(2.4, 0.4, 2.2),
			upholstery
		)
	end
	piece(parent, "SofaBack", base, 0, 2.3, 1.15, v(len, 2.6, 0.6), upholstery)
	piece(parent, "SofaArm", base, -len / 2 - 0.3, 1.5, 0, v(0.6, 1.8, 2.8), upholstery)
	piece(parent, "SofaArm", base, len / 2 + 0.3, 1.5, 0, v(0.6, 1.8, 2.8), upholstery)
end

-- A row of connected waiting-room seats on a steel beam.
function Furniture.seatRow(parent: Instance, base: CFrame, seats: number, fabric: Options)
	local len = seats * 2.2
	local metal = Materials.Metal.Steel
	piece(parent, "SeatBeam", base, 0, 0.9, 0.2, v(len, 0.25, 0.3), metal)
	for _, x in { -len / 2 + 0.4, len / 2 - 0.4 } do
		piece(parent, "SeatLeg", base, x, 0.45, 0.2, v(0.3, 0.9, 1.6), Parts.detail(metal))
	end
	for i = 1, seats do
		local x = -len / 2 + (i - 0.5) * 2.2
		Parts.seat(parent, "WaitingSeat", base * CFrame.new(x, 1.55, 0), v(1.9, 0.3, 1.8), fabric)
		piece(parent, "SeatBack", base, x, 2.65, 0.85, v(1.9, 1.8, 0.2), fabric)
	end
end

function Furniture.bench(parent: Instance, base: CFrame, length: number, wood: Options)
	Parts.seat(parent, "Bench", base * CFrame.new(0, 1.55, 0), v(length, 0.3, 1.6), wood)
	piece(parent, "BenchFrame", base, 0, 0.7, 0, v(length - 0.4, 1.4, 1.2), Parts.detail(Materials.Metal.Dark))
end

-- Tables ---------------------------------------------------------------------------------------

function Furniture.table(parent: Instance, base: CFrame, w: number, d: number, top: Options, height: number?)
	local h = height or 2.95
	piece(parent, "TableTop", base, 0, h - 0.1, 0, v(w, 0.2, d), top)
	local legs = Parts.detail(top)
	if w >= 5 then
		for _, x in { -w / 2 + 0.9, w / 2 - 0.9 } do
			piece(parent, "TableLeg", base, x, (h - 0.2) / 2, 0, v(0.5, h - 0.2, math.max(0.5, d - 1.2)), legs)
		end
	else
		piece(parent, "TableLeg", base, 0, (h - 0.2) / 2, 0, v(0.5, h - 0.2, 0.5), legs)
		piece(parent, "TableFoot", base, 0, 0.06, 0, v(math.min(w, 2), 0.12, math.min(d, 2)), legs)
	end
end

function Furniture.coffeeTable(parent: Instance, base: CFrame, w: number, d: number, top: Options)
	piece(parent, "CoffeeTable", base, 0, 1.35, 0, v(w, 0.25, d), top)
	piece(parent, "CoffeeTableBase", base, 0, 0.62, 0, v(w - 0.6, 1.24, d - 0.6), Parts.detail(top))
end

-- Storage --------------------------------------------------------------------------------------

local BOOK_COLOURS = {
	Color3.fromRGB(120, 36, 36),
	Color3.fromRGB(36, 60, 104),
	Color3.fromRGB(44, 86, 54),
	Color3.fromRGB(176, 150, 96),
	Color3.fromRGB(70, 50, 40),
	Color3.fromRGB(200, 196, 186),
}

-- A bookcase or office shelf with rows of books or binders on its front.
function Furniture.shelf(parent: Instance, base: CFrame, w: number, d: number, h: number, wood: Options, seed: number)
	piece(parent, "Shelf", base, 0, h / 2, 0, v(w, h, d), wood)
	local rows = math.max(1, math.floor((h - 0.6) / 2.1))
	for r = 1, rows do
		local y = 0.4 + (r - 1) * 2.1
		local split = 0.35 + Parts.noise(seed, r) * 0.3
		for k = 0, 1 do
			local x0 = if k == 0 then -w / 2 + 0.25 else -w / 2 + 0.25 + (w - 0.5) * split
			local x1 = if k == 0 then -w / 2 + 0.25 + (w - 0.5) * split - 0.05 else w / 2 - 0.25
			local colour = BOOK_COLOURS[1 + math.floor(Parts.noise(seed, r, k) * #BOOK_COLOURS)]
			local bh = 1.3 + Parts.noise(seed + 3, r, k) * 0.5
			piece(parent, "Books", base, (x0 + x1) / 2, y + bh / 2, -d / 2 - 0.05, v(x1 - x0, bh, 0.12), {
				Material = Enum.Material.Fabric,
				Color = colour,
				Decoration = true,
			})
		end
	end
end

function Furniture.cabinet(parent: Instance, base: CFrame, w: number, d: number, h: number, o: Options)
	piece(parent, "Cabinet", base, 0, h / 2, 0, v(w, h, d), o)
	local drawers = math.max(1, math.floor(h / 1.4))
	local line = Parts.detail(Materials.Metal.Steel)
	for i = 1, drawers do
		piece(
			parent,
			"DrawerHandle",
			base,
			0,
			(i - 0.5) * h / drawers + 0.3,
			-d / 2 - 0.05,
			v(w * 0.35, 0.1, 0.1),
			line
		)
	end
end

function Furniture.wardrobe(parent: Instance, base: CFrame, w: number, d: number, h: number, wood: Options)
	piece(parent, "Wardrobe", base, 0, h / 2, 0, v(w, h, d), wood)
	piece(
		parent,
		"WardrobeGap",
		base,
		0,
		h / 2,
		-d / 2 - 0.02,
		v(0.08, h - 0.4, 0.06),
		Parts.detail(Materials.Wood.Walnut)
	)
	local brass = Parts.detail(Materials.Metal.Brass)
	piece(parent, "WardrobeHandle", base, -0.35, h * 0.55, -d / 2 - 0.1, v(0.1, 0.8, 0.1), brass)
	piece(parent, "WardrobeHandle", base, 0.35, h * 0.55, -d / 2 - 0.1, v(0.1, 0.8, 0.1), brass)
end

-- A steel shelving rack with cardboard boxes or archive files.
function Furniture.rack(parent: Instance, base: CFrame, w: number, d: number, h: number, seed: number, goods: Options?)
	local steel = Materials.Metal.Steel
	piece(parent, "RackUpright", base, -w / 2 + 0.15, h / 2, 0, v(0.3, h, d), steel)
	piece(parent, "RackUpright", base, w / 2 - 0.15, h / 2, 0, v(0.3, h, d), steel)
	local levels = math.max(2, math.floor(h / 2.3))
	for i = 0, levels - 1 do
		local y = 0.3 + i * (h - 0.6) / (levels - 1)
		piece(parent, "RackShelf", base, 0, y, 0, v(w - 0.6, 0.12, d), Parts.detail(steel))
		if i < levels - 1 then
			local filled = 0.5 + Parts.noise(seed, i) * 0.45
			local bw = (w - 0.8) * filled
			piece(
				parent,
				"RackGoods",
				base,
				-w / 2 + 0.4 + bw / 2,
				y + 0.06 + 0.8,
				0,
				v(bw, 1.6, d - 0.3),
				Parts.detail(goods or Materials.Cardboard)
			)
		end
	end
end

-- Living things and small items ---------------------------------------------------------------

function Furniture.plant(parent: Instance, position: Vector3, height: number, seed: number)
	local pot = Materials.Pot
	Parts.cylinder(parent, "PlantPot", position, position + v(0, 1.3, 0), 1.5, pot)
	local green =
		Color3.fromRGB(60 + math.floor(Parts.noise(seed) * 30), 104 + math.floor(Parts.noise(seed, 1) * 30), 52)
	local size = height - 1.2
	Parts.ellipsoid(
		parent,
		"PlantLeaves",
		position + v(0, 1.2 + size / 2, 0),
		v(size * 0.55, size, size * 0.55),
		{ Material = Enum.Material.Grass, Color = green, CanCollide = false, CastShadow = true }
	)
end

function Furniture.bin(parent: Instance, position: Vector3)
	Parts.cylinder(parent, "Bin", position, position + v(0, 1.2, 0), 0.9, Parts.detail(Materials.Plastic.Grey))
end

function Furniture.rug(parent: Instance, base: CFrame, w: number, d: number, o: Options)
	piece(parent, "Rug", base, 0, 0.03, 0, v(w, 0.06, d), Parts.detail(o))
end

-- Wall pieces ----------------------------------------------------------------------------------

local PAINTINGS = {
	Color3.fromRGB(86, 120, 92), -- highland landscape
	Color3.fromRGB(196, 150, 86), -- savanna
	Color3.fromRGB(70, 96, 130), -- lake
	Color3.fromRGB(150, 70, 52), -- market scene
	Color3.fromRGB(210, 200, 176), -- portrait study
}

function Furniture.picture(parent: Instance, wall: CFrame, w: number, h: number, seed: number)
	piece(parent, "PictureFrame", wall, 0, 0, -0.06, v(w, h, 0.12), Parts.detail(Materials.Wood.Walnut))
	local colour = PAINTINGS[1 + math.floor(Parts.noise(seed) * #PAINTINGS)]
	piece(parent, "Picture", wall, 0, 0, -0.13, v(w - 0.5, h - 0.5, 0.03), {
		Material = Enum.Material.Fabric,
		Color = colour,
		Decoration = true,
	})
end

function Furniture.clock(parent: Instance, wall: CFrame)
	local face = Parts.part(
		parent,
		"Clock",
		wall * CFrame.new(0, 0, -0.08) * CFrame.Angles(0, math.pi / 2, 0),
		v(0.16, 1.4, 1.4),
		{
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(244, 244, 240),
			Shape = Enum.PartType.Cylinder,
			Decoration = true,
		}
	)
	face:SetAttribute("Fitting", "Clock")
end

function Furniture.whiteboard(parent: Instance, wall: CFrame, w: number, h: number)
	piece(parent, "WhiteboardFrame", wall, 0, 0, -0.08, v(w, h, 0.16), Parts.detail(Materials.Metal.Aluminium))
	piece(parent, "Whiteboard", wall, 0, 0, -0.17, v(w - 0.3, h - 0.3, 0.02), Parts.detail(Materials.Plastic.White))
end

function Furniture.screen(parent: Instance, wall: CFrame, w: number)
	local h = w * 0.58
	piece(parent, "WallScreen", wall, 0, 0, -0.15, v(w, h, 0.3), Parts.detail(Materials.Plastic.Black))
	piece(parent, "WallScreenGlass", wall, 0, 0, -0.31, v(w - 0.3, h - 0.3, 0.02), Parts.detail(Materials.Screen))
end

function Furniture.noticeBoard(parent: Instance, wall: CFrame, w: number, h: number, seed: number)
	piece(parent, "NoticeBoard", wall, 0, 0, -0.08, v(w, h, 0.16), Parts.detail(Materials.Cardboard))
	for i = 0, 2 do
		local x = -w / 2 + 0.9 + i * (w - 1.8) / 2
		local y = (Parts.noise(seed, i) - 0.5) * (h - 1.8)
		piece(parent, "Notice", wall, x, y, -0.17, v(1.1, 1.4, 0.02), Parts.detail(Materials.Paper))
	end
end

function Furniture.mirror(parent: Instance, wall: CFrame, w: number, h: number)
	piece(parent, "Mirror", wall, 0, 0, -0.05, v(w, h, 0.1), {
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(206, 216, 220),
		Reflectance = 0.5,
		Decoration = true,
	})
end

-- Wall-mounted air conditioner (indoor unit of a split system).
function Furniture.airConditioner(parent: Instance, wall: CFrame)
	piece(parent, "AirConditioner", wall, 0, 0, -0.4, v(3.2, 1, 0.8), Parts.detail(Materials.Plastic.White))
	piece(parent, "AirConditionerVent", wall, 0, -0.42, -0.65, v(2.8, 0.12, 0.3), Parts.detail(Materials.Plastic.Grey))
end

function Furniture.extinguisher(parent: Instance, wall: CFrame)
	local base = wall * CFrame.new(0, 0, -0.45)
	Parts.cylinder(
		parent,
		"FireExtinguisher",
		(base * CFrame.new(0, -0.9, 0)).Position,
		(base * CFrame.new(0, 0.9, 0)).Position,
		0.7,
		Parts.detail(Materials.Plastic.Red)
	)
	piece(parent, "ExtinguisherSign", wall, 0, 2.2, -0.03, v(1, 1, 0.05), Parts.detail(Materials.Plastic.Red))
end

-- Sign with text on its face (door signs, exit signs, WC signs).
function Furniture.sign(
	parent: Instance,
	wall: CFrame,
	w: number,
	h: number,
	lines: { string },
	plate: Options,
	ink: Color3
): Part
	local board = piece(parent, "Sign", wall, 0, 0, -0.04, v(w, h, 0.08), Parts.detail(plate))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 1
	gui.MaxDistance = 60
	for i, line in lines do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.06, (i - 1) / #lines + 0.04)
		label.Size = UDim2.fromScale(0.88, 1 / #lines - 0.08)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = ink
		label.TextStrokeTransparency = 1
		label.Text = line
		label.Parent = gui
	end
	gui.Parent = board
	return board
end

function Furniture.exitSign(parent: Instance, wall: CFrame)
	local sign = Furniture.sign(
		parent,
		wall,
		2.2,
		0.8,
		{ "EXIT · SORTIE" },
		Materials.Plastic.Green,
		Color3.fromRGB(255, 255, 255)
	)
	sign.Name = "ExitSign"
end

-- Electrical and safety fittings (tiny, no collision).
function Furniture.fitting(parent: Instance, wall: CFrame, kind: "Switch" | "Outlet" | "Thermostat")
	local size = if kind == "Switch"
		then v(0.35, 0.55, 0.06)
		elseif kind == "Outlet" then v(0.45, 0.3, 0.06)
		else v(0.6, 0.6, 0.12)
	local part = piece(parent, kind, wall, 0, 0, -size.Z / 2, size, Parts.detail(Materials.Plastic.White))
	part:SetAttribute("Fitting", kind)
end

function Furniture.smokeDetector(parent: Instance, position: Vector3)
	local part = Parts.cylinder(
		parent,
		"SmokeDetector",
		position,
		position - v(0, 0.2, 0),
		0.7,
		Parts.detail(Materials.Plastic.White)
	)
	part:SetAttribute("Fitting", "SmokeDetector")
end

function Furniture.ceilingVent(parent: Instance, position: Vector3)
	local part = Parts.box(
		parent,
		"CeilingVent",
		position.X - 0.9,
		position.Y - 0.08,
		position.Z - 0.9,
		position.X + 0.9,
		position.Y,
		position.Z + 0.9,
		Parts.detail(Materials.Metal.Aluminium)
	)
	part:SetAttribute("Fitting", "Vent")
end

-- A ceiling light panel with an optional point light (interiors are lit day and night).
function Furniture.ceilingLight(parent: Instance, position: Vector3, w: number, d: number, range: number?): Part
	local panel = Parts.box(
		parent,
		"CeilingLight",
		position.X - w / 2,
		position.Y - 0.18,
		position.Z - d / 2,
		position.X + w / 2,
		position.Y,
		position.Z + d / 2,
		{
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 244, 226),
			Decoration = true,
		}
	)
	if range then
		local light = Instance.new("PointLight")
		light.Range = range
		light.Brightness = 0.9
		light.Color = Color3.fromRGB(255, 238, 214)
		light.Shadows = false
		light.Parent = panel
	end
	return panel
end

-- A brass chandelier with a glowing globe and a point light, hanging `drop` studs below the
-- ceiling point `top`.
function Furniture.chandelier(parent: Instance, top: Vector3, drop: number, range: number): Part
	local brass = Parts.detail(Materials.Metal.Brass)
	local bottom = top - v(0, drop, 0)
	Parts.cylinder(parent, "ChandelierRod", top, bottom + v(0, 1, 0), 0.25, brass)
	Parts.cylinder(parent, "ChandelierRing", bottom + v(0, 0.6, 0), bottom + v(0, 0.9, 0), 5, brass)
	local globe = Parts.ellipsoid(
		parent,
		"ChandelierGlobe",
		bottom + v(0, 0.4, 0),
		v(3, 2.2, 3),
		{ Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 236, 200), CastShadow = false, CanCollide = false }
	)
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 232, 196)
	light.Shadows = false
	light.Parent = globe
	return globe
end

-- A fireplace against a wall: marble surround, dark firebox, mantel shelf and hearth. `wall`
-- is on the wall surface at floor level.
function Furniture.fireplace(parent: Instance, wall: CFrame)
	local marble = Materials.Floor.Marble
	piece(parent, "FireplaceJamb", wall, -2.9, 2, -0.5, v(1.2, 4, 1), marble)
	piece(parent, "FireplaceJamb", wall, 2.9, 2, -0.5, v(1.2, 4, 1), marble)
	piece(parent, "FireplaceLintel", wall, 0, 4.5, -0.5, v(7, 1, 1), marble)
	piece(parent, "Mantel", wall, 0, 5.15, -0.7, v(7.6, 0.3, 1.4), marble)
	piece(parent, "Firebox", wall, 0, 2, -0.1, v(4.6, 4, 0.2), Parts.detail(Materials.Metal.Iron))
	piece(parent, "Hearth", wall, 0, 0.1, -1, v(7.6, 0.2, 2), Parts.detail(Materials.Floor.Marble))
	piece(parent, "Logs", wall, 0, 0.5, -0.6, v(2.4, 0.6, 0.6), Parts.detail(Materials.Wood.Walnut))
end

-- A grand piano with its bench. The front (the keyboard) faces the pianist; the body with the
-- raised lid reaches back.
function Furniture.piano(parent: Instance, base: CFrame)
	local black = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(22, 22, 24), Reflectance = 0.08 }
	piece(parent, "PianoBody", base, 0, 2.7, 2.4, v(4.8, 1.1, 4.8), black)
	Parts.cylinder(
		parent,
		"PianoTail",
		(base * CFrame.new(0.5, 2.15, 4.6)).Position,
		(base * CFrame.new(0.5, 3.25, 4.6)).Position,
		3.8,
		black
	)
	piece(parent, "PianoKeys", base, 0, 2.8, -0.4, v(4.6, 0.22, 1), Parts.detail(Materials.Plastic.White))
	piece(parent, "PianoKeyCover", base, 0, 3.05, 0.05, v(4.8, 0.35, 0.3), Parts.detail(black))
	piece(parent, "PianoStand", base, 0, 3.9, 0.5, v(2.8, 1.2, 0.12), Parts.detail(black))
	piece(
		parent,
		"PianoLid",
		base * CFrame.new(-0.9, 4.4, 2.6) * CFrame.Angles(0, 0, math.rad(32)),
		0,
		0,
		0,
		v(4.4, 0.12, 5),
		Parts.detail(black)
	)
	piece(parent, "PianoLidProp", base, 1.6, 3.9, 2.6, v(0.1, 1.6, 0.1), Parts.detail(Materials.Metal.Brass))
	for _, leg in { { -2.1, 0.4 }, { 2.1, 0.4 }, { 0.5, 5.6 } } do
		piece(parent, "PianoLeg", base, leg[1], 1.08, leg[2], v(0.45, 2.16, 0.45), Parts.detail(black))
	end
	Parts.seat(parent, "PianoBench", base * CFrame.new(0, 1.55, -2.3), v(3.4, 0.4, 1.4), black)
	piece(parent, "PianoBenchBase", base, 0, 0.7, -2.3, v(3, 1.4, 1), Parts.detail(black))
end

-- Bedroom and bathroom -------------------------------------------------------------------------

function Furniture.bed(parent: Instance, base: CFrame, w: number, l: number, wood: Options, linen: Options)
	piece(parent, "BedFrame", base, 0, 0.55, 0, v(w, 1.1, l), wood)
	piece(parent, "Mattress", base, 0, 1.45, 0.1, v(w - 0.3, 0.7, l - 0.4), Materials.Wood.White)
	piece(parent, "Duvet", base, 0, 1.85, -l * 0.12, v(w - 0.1, 0.25, l * 0.7), linen)
	local pillows: { number } = if w > 4 then { -w / 4, w / 4 } else { 0 }
	for _, x in pillows do
		piece(
			parent,
			"Pillow",
			base,
			x,
			2,
			l / 2 - 1.1,
			v(math.min(2.4, w / 2 - 0.3), 0.45, 1.2),
			Parts.detail(Materials.Plastic.White)
		)
	end
	piece(parent, "Headboard", base, 0, 2.1, l / 2 + 0.2, v(w + 0.2, 4.2, 0.4), wood)
end

function Furniture.nightstand(parent: Instance, base: CFrame, wood: Options)
	piece(parent, "Nightstand", base, 0, 1.1, 0, v(1.8, 2.2, 1.6), wood)
	Parts.cylinder(
		parent,
		"LampFoot",
		(base * CFrame.new(0, 2.2, 0)).Position,
		(base * CFrame.new(0, 3.2, 0)).Position,
		0.3,
		Parts.detail(Materials.Metal.Brass)
	)
	Parts.cylinder(
		parent,
		"LampShade",
		(base * CFrame.new(0, 3.1, 0)).Position,
		(base * CFrame.new(0, 3.9, 0)).Position,
		1.1,
		Parts.detail(Materials.Fabric.Beige)
	)
end

function Furniture.floorLamp(parent: Instance, position: Vector3)
	Parts.cylinder(parent, "FloorLampFoot", position, position + v(0, 0.15, 0), 1.2, Parts.detail(Materials.Metal.Dark))
	Parts.cylinder(parent, "FloorLampPole", position, position + v(0, 5.4, 0), 0.2, Parts.detail(Materials.Metal.Dark))
	Parts.cylinder(
		parent,
		"FloorLampShade",
		position + v(0, 5.2, 0),
		position + v(0, 6.3, 0),
		1.6,
		Parts.detail(Materials.Fabric.Beige)
	)
end

function Furniture.toilet(parent: Instance, base: CFrame)
	local porcelain = Materials.Porcelain
	piece(parent, "Toilet", base, 0, 0.75, -0.15, v(1.5, 1.5, 2.2), porcelain)
	piece(parent, "ToiletTank", base, 0, 2.1, 0.95, v(1.8, 1.4, 0.6), Parts.detail(porcelain))
end

function Furniture.urinal(parent: Instance, wall: CFrame)
	piece(parent, "Urinal", wall, 0, 0, -0.6, v(1.4, 2.2, 1.2), Parts.detail(Materials.Porcelain))
end

-- A washbasin on the wall with a tap and a mirror above. `wall` is at basin height.
function Furniture.washbasin(parent: Instance, wall: CFrame, mirror: boolean?)
	piece(parent, "Washbasin", wall, 0, 0, -0.85, v(2.2, 0.5, 1.7), Materials.Porcelain)
	piece(parent, "Tap", wall, 0, 0.45, -0.25, v(0.2, 0.5, 0.5), Parts.detail(Materials.Metal.Chrome))
	if mirror ~= false then
		Furniture.mirror(parent, wall * CFrame.new(0, 2.6, 0), 2.4, 3)
	end
end

function Furniture.bathtub(parent: Instance, base: CFrame, l: number, w: number)
	piece(parent, "Bathtub", base, 0, 0.9, 0, v(w, 1.8, l), Materials.Porcelain)
	piece(parent, "BathWater", base, 0, 1.78, 0, v(w - 0.6, 0.06, l - 0.6), {
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(190, 220, 230),
		Transparency = 0.3,
		Decoration = true,
	})
end

function Furniture.shower(parent: Instance, base: CFrame, size: number)
	piece(parent, "ShowerTray", base, 0, 0.1, 0, v(size, 0.2, size), Materials.Porcelain)
	piece(parent, "ShowerScreen", base, -size / 2 + 0.05, 3.6, 0, v(0.1, 7, size), Materials.Glass.Interior)
	piece(parent, "ShowerHead", base, 0, 7.4, size / 2 - 0.3, v(0.8, 0.15, 0.8), Parts.detail(Materials.Metal.Chrome))
end

-- Kitchens and service --------------------------------------------------------------------------

-- A run of base cabinets with a worktop, sink and hob, and wall cabinets above. The back of
-- the run (+Z of `base`) is against the wall.
function Furniture.kitchen(
	parent: Instance,
	base: CFrame,
	length: number,
	doors: Options,
	worktop: Options,
	ceiling: number
)
	piece(parent, "KitchenBase", base, 0, 1.4, 0, v(length, 2.8, 2.1), doors)
	piece(parent, "Worktop", base, 0, 2.9, -0.05, v(length + 0.1, 0.2, 2.3), worktop)
	local steel = Parts.detail(Materials.Metal.Steel)
	piece(parent, "Sink", base, -length / 4, 3.02, 0, v(2.2, 0.06, 1.5), steel)
	piece(parent, "KitchenTap", base, -length / 4, 3.4, 0.7, v(0.2, 0.8, 0.2), Parts.detail(Materials.Metal.Chrome))
	if length >= 6 then
		piece(parent, "Hob", base, length / 4, 3.02, 0, v(2, 0.06, 1.6), Parts.detail(Materials.Plastic.Black))
	end
	local top = math.min(ceiling - 0.6, 8.6)
	piece(parent, "WallCabinets", base, 0, top - 1.3, 0.5, v(length, 2.6, 1.1), doors)
end

function Furniture.fridge(parent: Instance, base: CFrame)
	piece(parent, "Fridge", base, 0, 3.3, 0, v(2.6, 6.6, 2.4), Materials.Metal.Aluminium)
	piece(parent, "FridgeHandle", base, 1, 3.8, -1.25, v(0.12, 2.4, 0.12), Parts.detail(Materials.Metal.Dark))
end

function Furniture.appliance(parent: Instance, base: CFrame, kind: "Microwave" | "CoffeeMachine" | "Kettle" | "Machine")
	local size = if kind == "Microwave"
		then v(1.8, 1.1, 1.3)
		elseif kind == "CoffeeMachine" then v(1, 1.4, 1.2)
		elseif kind == "Machine" then v(1.4, 0.9, 1.2)
		else v(0.6, 0.8, 0.6)
	local o = if kind == "Microwave" or kind == "Machine" then Materials.Plastic.White else Materials.Plastic.Black
	piece(parent, kind, base, 0, size.Y / 2, 0, size, Parts.detail(o))
end

function Furniture.waterCooler(parent: Instance, base: CFrame)
	piece(parent, "WaterCooler", base, 0, 1.6, 0, v(1.2, 3.2, 1.2), Materials.Plastic.White)
	Parts.cylinder(
		parent,
		"WaterBottle",
		(base * CFrame.new(0, 3.2, 0)).Position,
		(base * CFrame.new(0, 4.8, 0)).Position,
		1,
		{
			Material = Enum.Material.Glass,
			Color = Color3.fromRGB(120, 170, 220),
			Transparency = 0.3,
			Decoration = true,
		}
	)
end

function Furniture.copier(parent: Instance, base: CFrame)
	piece(parent, "Copier", base, 0, 1.6, 0, v(3, 3.2, 2.4), Materials.Plastic.Beige)
	piece(parent, "CopierPanel", base, 0.6, 3.3, -0.8, v(1.2, 0.2, 0.6), Parts.detail(Materials.Plastic.Grey))
end

function Furniture.serverRack(parent: Instance, base: CFrame)
	piece(parent, "ServerRack", base, 0, 3.6, 0, v(2.4, 7.2, 3), Materials.Metal.Dark)
	piece(parent, "ServerLights", base, 0, 3.6, -1.52, v(1.8, 5.6, 0.04), {
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(60, 200, 110),
		Decoration = true,
	})
end

function Furniture.counter(parent: Instance, base: CFrame, length: number, depth: number, body: Options, top: Options)
	piece(parent, "Counter", base, 0, 1.75, 0, v(length, 3.5, depth), body)
	piece(parent, "CounterTop", base, 0, 3.6, 0, v(length + 0.3, 0.2, depth + 0.3), top)
end

function Furniture.lectern(parent: Instance, base: CFrame, wood: Options)
	piece(parent, "Lectern", base, 0, 2, 0, v(2.4, 4, 1.8), wood)
	piece(parent, "LecternTop", base, 0, 4.1, -0.1, v(2.6, 0.2, 2.2), wood)
end

function Furniture.locker(parent: Instance, base: CFrame, w: number)
	piece(parent, "Locker", base, 0, 3.4, 0, v(w, 6.8, 1.8), Materials.Metal.Steel)
	local doors = math.max(1, math.floor(w / 1.4))
	for i = 1, doors - 1 do
		piece(
			parent,
			"LockerGap",
			base,
			-w / 2 + i * w / doors,
			3.4,
			-0.92,
			v(0.06, 6.4, 0.04),
			Parts.detail(Materials.Metal.Dark)
		)
	end
end

function Furniture.safe(parent: Instance, base: CFrame)
	piece(parent, "Safe", base, 0, 1.8, 0, v(2.6, 3.6, 2.4), Materials.Metal.Dark)
	Parts.cylinder(
		parent,
		"SafeDial",
		(base * CFrame.new(0, 2.2, -1.2)).Position,
		(base * CFrame.new(0, 2.2, -1.35)).Position,
		0.6,
		Parts.detail(Materials.Metal.Chrome)
	)
end

return Furniture
