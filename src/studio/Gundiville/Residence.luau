--!strict
-- The residence of the Leader of the Revolution: a walled, guarded compound with gardens,
-- set back north-east of the square (map plan: gate in the south wall). Behind the gate with
-- its two manned guard posts and the boom barrier, a drive leads to a turning circle with a
-- fountain in front of a white villa with a portico and a balcony.
--
-- The villa (Architecture.Plan) has two storeys. On the ground floor: the entrance hall with
-- the main stair, the salon and the music room, the dining room and the kitchen, the library,
-- the aide-de-camp's office and the Leader's office with the desk and the Leader's chair.
-- Upstairs: the private rooms (bedrooms, a family room, a study, bathrooms, a dressing room and
-- a guest suite) around the upper hall, which opens onto the balcony over the portico. Every
-- window opens into a room. The gate stands open and the barrier is raised; access control
-- follows with the institutional gameplay (Milestone 6).

local Kit = require(script.Parent.Kit)
local Architecture = script.Parent.Parent.Architecture
local Parts = require(Architecture.Parts)
local Materials = require(Architecture.Materials)
local Openings = require(Architecture.Openings)
local Plan = require(Architecture.Plan)
local Shell = require(Architecture.Shell)
local Rooms = require(Architecture.Rooms)
local Furniture = require(Architecture.Furniture)
local StoreAssets = require(Architecture.StoreAssets)
local Exterior = require(Architecture.Exterior)

type Space = Plan.Space
type Room = Rooms.Room

local Residence = {}

local COBBLES: Kit.Options = { Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(150, 140, 128) }
local SHUTTERS: Kit.Options = { Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(70, 96, 120) }
local FLOWERS = {
	Color3.fromRGB(196, 40, 52),
	Color3.fromRGB(236, 196, 60),
	Color3.fromRGB(226, 120, 160),
	Color3.fromRGB(240, 240, 236),
}
local DOOR_X = 580 -- the villa's portal, on the axis of the gate
local GARDEN_X = 530 -- the garden door of the dining room, towards the gazebo

-- Places a piece centred at the world point (x, z) with its front towards `dir` (an axis
-- direction), if nothing (doors, windows, other furniture) is in the way.
local function put(
	room: Room,
	x: number,
	z: number,
	dir: Vector3,
	width: number,
	depth: number,
	build: (frame: CFrame) -> ()
): boolean
	local u, w = Rooms.toLocal(room, x, z)
	local side: Rooms.Side = "Left"
	if dir:Dot(-room.N) > 0.5 then
		side = "Front"
	elseif dir:Dot(room.N) > 0.5 then
		side = "Back"
	elseif dir:Dot(room.A) > 0.5 then
		side = "Right"
	end
	return Rooms.item(room, u, w, side, width, depth, false, build)
end

-- A CFrame on a wall surface at (x, y, z), facing `dir` (into the room).
local function wallAt(x: number, y: number, z: number, dir: Vector3): CFrame
	local p = Vector3.new(x, y, z)
	return CFrame.lookAt(p, p + dir)
end

-- An official painting (StoreAssets) at a wall frame (its centre), or a built picture.
local function portrait(parent: Instance, wall: CFrame, key: string, scale: number, seed: number)
	if not Furniture.store(parent, key, wall, scale) then
		local size = Furniture.size(key) * scale
		Furniture.picture(parent, wall, size.X, size.Y, seed)
	end
end

-- A wall lantern (glass box on a bracket) that the day/night cycle switches on at night.
local function lantern(parent: Instance, x: number, y: number, z: number, out: Vector3)
	local p = Vector3.new(x, y, z)
	Parts.part(
		parent,
		"LanternBracket",
		CFrame.lookAt(p + out * 0.4, p + out),
		Vector3.new(0.2, 0.2, 0.8),
		Parts.detail(Materials.Metal.Iron)
	)
	local glass = Parts.part(parent, "Lantern", CFrame.lookAt(p + out * 0.9, p + out * 2), Vector3.new(0.9, 1.4, 0.9), {
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(250, 238, 200),
		CastShadow = false,
		CanCollide = false,
	})
	glass:SetAttribute("RoNationLamp", true)
	local light = Instance.new("PointLight")
	light:SetAttribute("RoNationStreetLight", true)
	light.Enabled = false
	light.Range = 18
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 224, 180)
	light.Parent = glass
end

-- Guard post just inside the gate: plastered walls, a working door on the side towards the
-- villa, a window towards the gate, and towards the drive a counter under a glazed front where
-- the guard sits at a desk with a CCTV monitor and a telephone. `r` is the 8 x 8 booth,
-- `driveSide` the direction of the drive (+1 = +X).
local function guardPost(parent: Instance, r: Kit.Rect, y: number, driveSide: number)
	local booth = Kit.folder(parent, "GuardPost")
	local h = 9
	local plaster = Kit.Style.Plaster
	local t = 0.8
	local floor = y + 0.3
	Kit.slab(booth, "BoothFloor", r, y - 0.2, floor, Kit.Style.Granite)
	local outer = if driveSide > 0 then r.MinX + t / 2 else r.MaxX - t / 2
	local inner = if driveSide > 0 then r.MaxX - t / 2 else r.MinX + t / 2
	local x0, x1 = r.MinX + t, r.MaxX - t
	local cx = (r.MinX + r.MaxX) / 2
	local cz = (r.MinZ + r.MaxZ) / 2
	-- Back wall (away from the drive) and the corner posts of the glazed front.
	Openings.solid(
		booth,
		"BoothWall",
		{ Axis = "Z", At = outer, Thickness = t, Out = -driveSide },
		r.MinZ,
		r.MaxZ,
		floor,
		y + h,
		nil,
		plaster
	)
	for _, z in { r.MinZ + t / 2, r.MaxZ - t / 2 } do
		Kit.box(booth, "BoothPost", inner - t / 2, floor, z - t / 2, inner + t / 2, y + h, z + t / 2, plaster)
	end
	-- North wall with the door, south wall with a window towards the gate.
	local north: Openings.Wall = { Axis = "X", At = r.MinZ + t / 2, Thickness = t, Out = -1 }
	local south: Openings.Wall = { Axis = "X", At = r.MaxZ - t / 2, Thickness = t, Out = 1 }
	local door = { From = cx - 1.6, To = cx + 1.6, Bottom = floor, Top = floor + 7.2 }
	Openings.solid(booth, "BoothWall", north, x0, x1, floor, y + h, { door }, plaster)
	Openings.door(booth, north, door.From, door.To, floor, door.Top, {
		Leaf = Materials.Wood.Walnut,
		Frame = Materials.Frame.White,
		Handle = Materials.Metal.Brass,
	}, { Swing = 1, Hinge = if driveSide > 0 then "Start" else "End", Label = "Guard Post" })
	local window = { From = cx - 1.5, To = cx + 1.5, Bottom = y + 3.6, Top = y + 7.4 }
	Openings.solid(booth, "BoothWall", south, x0, x1, floor, y + h, { window }, plaster)
	Openings.window(booth, south, window.From, window.To, window.Bottom, window.Top, {
		Frame = Materials.Frame.White,
		Glass = Materials.Glass.Window,
		Sill = Kit.Style.Marble,
		Board = Materials.Wood.White,
	})
	-- The glazed front: counter wall, sill, glass with a frame and two mullions.
	local z0, z1 = r.MinZ + t, r.MaxZ - t
	Kit.box(booth, "BoothCounter", inner - t / 2, floor, z0, inner + t / 2, y + 3.3, z1, plaster)
	Kit.box(booth, "BoothSill", inner - t / 2 - 0.2, y + 3.3, z0, inner + t / 2 + 0.2, y + 3.5, z1, Kit.Style.Marble)
	Kit.box(booth, "BoothGlass", inner - 0.06, y + 3.5, z0, inner + 0.06, y + h - 0.6, z1, Materials.Glass.Window)
	local frame = Parts.detail(Materials.Frame.White)
	Kit.box(booth, "BoothFrame", inner - 0.2, y + h - 0.6, z0, inner + 0.2, y + h, z1, frame)
	for _, z in { z0 + (z1 - z0) / 3, z0 + 2 * (z1 - z0) / 3 } do
		Kit.box(booth, "BoothMullion", inner - 0.15, y + 3.5, z - 0.1, inner + 0.15, y + h - 0.6, z + 0.1, frame)
	end
	-- Inside: the desk along the counter, the guard's chair facing the drive, a CCTV monitor,
	-- a telephone, a notice board, an extinguisher and the ceiling light.
	local deskX = inner - driveSide * (t / 2 + 0.8)
	local look = Vector3.new(-driveSide, 0, 0) -- the desk front faces the guard
	local deskFrame = CFrame.lookAt(Vector3.new(deskX, floor, cz + 0.6), Vector3.new(deskX, floor, cz + 0.6) + look)
	Furniture.desk(booth, deskFrame, 4.6, 1.6, Materials.Wood.Oak)
	Furniture.computer(booth, deskFrame * CFrame.new(0, 0, 0.2), 2.95)
	Parts.part(
		booth,
		"Telephone",
		deskFrame * CFrame.new(1.6, 3.15, 0),
		Vector3.new(0.9, 0.3, 0.7),
		Parts.detail(Materials.Plastic.Black)
	)
	local chairAt = Vector3.new(deskX - driveSide * 2.2, floor, cz + 0.6)
	Furniture.officeChair(
		booth,
		CFrame.lookAt(chairAt, chairAt + Vector3.new(driveSide, 0, 0)),
		Materials.Fabric.Charcoal
	)
	local backFace = outer + driveSide * t / 2
	Furniture.noticeBoard(
		booth,
		wallAt(backFace, floor + 5, cz + 1, Vector3.new(driveSide, 0, 0)),
		2.6,
		2,
		math.floor(cx)
	)
	Furniture.extinguisher(booth, wallAt(backFace, floor + 2.4, r.MinZ + t + 0.8, Vector3.new(driveSide, 0, 0)))
	Furniture.ceilingLight(booth, Vector3.new(cx, y + h, cz), 2, 2, 14)
	-- Roof with an overhang, the sign over the drive and a lantern over the door.
	Kit.slab(booth, "BoothRoof", Kit.inset(r, -1), y + h, y + h + 0.8, Kit.Style.Slate)
	local sx = inner + driveSide * (t / 2 + 0.6)
	local sign = Kit.box(
		booth,
		"BoothSign",
		sx - 0.1,
		y + h - 1.9,
		r.MinZ + 1.5,
		sx + 0.1,
		y + h - 0.5,
		r.MaxZ - 1.5,
		Kit.Style.DarkWood
	)
	Kit.inscription(
		sign,
		{ "GUARD POST" },
		Color3.fromRGB(240, 230, 200),
		if driveSide > 0 then Enum.NormalId.Right else Enum.NormalId.Left
	)
	lantern(booth, cx + 2.6, floor + 7.4, r.MinZ, Vector3.new(0, 0, -1))
end

-- Villa interiors ----------------------------------------------------------------------------

-- The entrance hall: marble with a runner from the portal to the stair, the national emblem
-- and a portrait facing each other over benches, flags at the foot of the stair, plants and two
-- chandeliers.
local function hall(room: Room)
	local folder = room.Folder
	local y = room.Floor
	local ceiling = y + room.Height
	local r = room.Space.Rect
	local half = Plan.Partition / 2
	local west, east = r.MinX + half, r.MaxX - half
	local runnerAt = Vector3.new(DOOR_X, y, (r.MinZ + r.MaxZ - 0.3) / 2)
	Furniture.runner(
		folder,
		CFrame.lookAt(runnerAt, runnerAt + Vector3.new(0, 0, 1)),
		7.2,
		r.MaxZ - 0.3 - r.MinZ,
		Materials.Floor.CarpetRed,
		Materials.Floor.CarpetSand
	)
	Rooms.panelling(room, Materials.Panel.Painted, 3.2)
	Rooms.cornice(room)
	Kit.emblem(folder, { Axis = "X", At = west, Out = 1 }, -722, y + 6.8, 4.2, 0.2)
	portrait(folder, wallAt(east, y + 6.6, -722, Vector3.new(-1, 0, 0)), "PaintingOfficer", 0.8, 3)
	for _, side in { -1, 1 } do
		local x = if side < 0 then west + 0.9 else east - 0.9
		local facing = Vector3.new(-side, 0, 0)
		put(room, x, -722, facing, 6, 1.6, function(frame)
			Furniture.bench(folder, frame, 6, Materials.Wood.Walnut)
		end)
		for _, z in { -727.5, -716.5 } do
			put(room, if side < 0 then west + 1.5 else east - 1.5, z, facing, 2.6, 2.6, function(frame)
				Furniture.plant(folder, frame.Position, 5.5, math.floor(z) + side, false, 1.2)
			end)
		end
		put(room, if side < 0 then west + 2.2 else east - 2.2, r.MaxZ - 2.2, facing, 3.6, 3.6, function(frame)
			Furniture.plant(folder, frame.Position, 7, 20 + side, true, 1.9)
		end)
		Kit.flagpole(folder, Vector3.new(DOOR_X + side * 11.5, y, r.MinZ + 1.5), 9, 3, Vector3.new(side, 0, 0.3))
	end
	for _, z in { -706, -730 } do
		Furniture.chandelier(folder, Vector3.new(DOOR_X, ceiling, z), 3.4, 40, 8)
	end
end

-- The upper hall: a sitting corner by the west wall, a display cabinet and pictures, the
-- runner from the stair to the balcony door, chandeliers.
local function upperHall(room: Room)
	local folder = room.Folder
	local y = room.Floor
	local ceiling = y + room.Height
	local r = room.Space.Rect
	local half = Plan.Partition / 2
	local west, east = r.MinX + half, r.MaxX - half
	local runnerAt = Vector3.new(DOOR_X, y, (r.MinZ + r.MaxZ - 0.3) / 2)
	Furniture.runner(
		folder,
		CFrame.lookAt(runnerAt, runnerAt + Vector3.new(0, 0, 1)),
		5.6,
		r.MaxZ - 0.3 - r.MinZ,
		Materials.Floor.CarpetRed,
		Materials.Floor.CarpetSand
	)
	Rooms.panelling(room, Materials.Panel.Painted, 3.2)
	Rooms.cornice(room)
	-- Sitting group by the west wall on an oriental rug.
	local rugAt = CFrame.lookAt(Vector3.new(west + 6.4, y, -718), Vector3.new(west + 7.4, y, -718))
	if not Furniture.store(folder, "RugKhamseh", rugAt) then
		Furniture.rug(folder, rugAt, 13, 9, Materials.Floor.CarpetRed)
	end
	local sofa = Furniture.size("Sofa3Light")
	put(room, west + 0.4 + sofa.Z / 2, -718, Vector3.new(1, 0, 0), sofa.X, sofa.Z, function(frame)
		if not Furniture.store(folder, "Sofa3Light", frame) then
			Furniture.sofa(folder, frame, 3, Materials.Fabric.Beige)
		end
	end)
	local ct = Furniture.size("CoffeeTable")
	put(room, west + 0.4 + sofa.Z + 1.3 + ct.Z / 2, -718, Vector3.new(1, 0, 0), ct.X, ct.Z, function(frame)
		if not Furniture.store(folder, "CoffeeTable", frame) then
			Furniture.coffeeTable(folder, frame, ct.X, ct.Z, Materials.Wood.Walnut)
		end
	end)
	for _, z in { -723, -713 } do
		local facing = Vector3.new(0, 0, if z < -718 then 1 else -1)
		put(room, west + 0.4 + sofa.Z + 1.3 + ct.Z / 2, z, facing, 3.3, 3.7, function(frame)
			if not Furniture.store(folder, "ArmChair", frame) then
				Furniture.armchair(folder, frame, Materials.Leather.Tan)
			end
		end)
	end
	Furniture.picture(folder, wallAt(west, y + 7.2, -718, Vector3.new(1, 0, 0)), 6, 4, 9)
	local console = Furniture.size("Console")
	put(room, east - 0.1 - console.Z / 2, -718, Vector3.new(-1, 0, 0), console.X, console.Z, function(frame)
		if Furniture.store(folder, "Console", frame) then
			Furniture.store(folder, "BustMan", frame * CFrame.new(0, console.Y, 0))
		else
			Furniture.cabinet(folder, frame, console.X, console.Z, console.Y, Materials.Wood.Walnut)
		end
	end)
	portrait(folder, wallAt(east, y + 7.6, -718, Vector3.new(-1, 0, 0)), "PaintingHelena", 0.6, 12)
	for _, x in { west + 2, east - 2 } do
		put(room, x, r.MaxZ - 2, Vector3.new(0, 0, -1), 3, 3, function(frame)
			Furniture.plant(folder, frame.Position, 6.5, math.floor(x), true, 1.7)
		end)
	end
	for _, z in { -706, -730 } do
		Furniture.chandelier(folder, Vector3.new(DOOR_X, ceiling, z), 3, 36, 8)
	end
end

-- The passages from the halls to the ends of the villa: a runner, pictures, console tables
-- with plants.
local function passage(room: Room)
	local folder = room.Folder
	local y = room.Floor
	local r = room.Space.Rect
	local cz = (r.MinZ + r.MaxZ) / 2
	local runnerAt = Vector3.new((r.MinX + r.MaxX) / 2, y, cz)
	Furniture.runner(
		folder,
		CFrame.lookAt(runnerAt, runnerAt + Vector3.new(0, 0, 1)),
		r.MaxX - r.MinX - 2,
		3.6,
		Materials.Floor.CarpetRed,
		Materials.Floor.CarpetSand
	)
	local walls: { Rooms.Side } = { "Left", "Right", "Left", "Right" }
	for i, side in walls do
		Rooms.findWall(room, side :: Rooms.Side, 6.6, 5, function(wall)
			portrait(folder, wall, if i % 2 == 0 then "PaintingBordighera" else "PaintingMurnau", 0.6, room.Seed + i)
		end)
	end
	local console = Furniture.size("Console")
	local consoles: { Rooms.Side } = { "Left", "Right" }
	for i, side in consoles do
		Rooms.alongWall(room, side :: Rooms.Side, console.X, console.Z, false, function(frame)
			if Furniture.store(folder, "Console", frame) then
				Furniture.store(folder, if i == 1 then "Bust" else "Bowl", frame * CFrame.new(0, console.Y, 0))
			else
				Furniture.table(folder, frame, console.X, console.Z, Materials.Wood.Walnut, 2.8)
			end
		end)
	end
end

-- The Leader's office: the desk with the Leader's chair before the national emblem and two
-- flags, bookcases along the back wall, visitors' chairs, a sitting corner by the front windows
-- and a conference table at the east end.
local function office(room: Room, report: { [string]: number })
	local folder = room.Folder
	local y = room.Floor
	local ceiling = y + room.Height
	local r = room.Space.Rect
	local half = Plan.Partition / 2
	local north, west = r.MinZ + half, r.MinX + half
	local cx = 620
	local mahogany = Materials.Wood.Mahogany
	local rugAt = CFrame.lookAt(Vector3.new(cx, y, -720.5), Vector3.new(cx, y, -719.5))
	if not Furniture.store(folder, "RugHall", rugAt, 0.62) then
		Furniture.rug(folder, rugAt, 21.7, 15.3, Materials.Floor.CarpetRed)
	end

	-- The desk (its front, the Leader's side, faces north) with a blotter, a banker's lamp, a
	-- telephone and a nameplate towards the visitors. The official study desk, a little
	-- enlarged, or a built mahogany desk.
	local deskAt = Vector3.new(cx, y, -727)
	local desk = CFrame.lookAt(deskAt, deskAt + Vector3.new(0, 0, -1))
	local deskTop = 3.04
	local study = Furniture.size("ExecutiveDesk")
	if Furniture.store(folder, "ExecutiveDesk", desk, 1.15) then
		deskTop = study.Y * 1.15
	else
		Furniture.desk(folder, desk, 10, 4.2, mahogany)
	end
	Parts.part(
		folder,
		"Blotter",
		desk * CFrame.new(0, deskTop + 0.03, -0.4),
		Vector3.new(3.6, 0.04, 2),
		Parts.detail(Materials.Leather.Black)
	)
	local lamp = desk * CFrame.new(-3.2, deskTop, 0.8)
	if not Furniture.store(folder, "BankersLamp", lamp) then
		local lampAt = lamp.Position
		Parts.cylinder(
			folder,
			"DeskLamp",
			lampAt,
			lampAt + Vector3.new(0, 1.4, 0),
			0.25,
			Parts.detail(Materials.Metal.Brass)
		)
		Parts.cylinder(
			folder,
			"DeskLampShade",
			lampAt + Vector3.new(0, 1.2, 0),
			lampAt + Vector3.new(0, 1.9, 0),
			1.2,
			Parts.detail(Materials.Fabric.Green)
		)
	end
	Furniture.store(folder, "Pen", desk * CFrame.new(1.2, deskTop, -0.6) * CFrame.Angles(0, 0.5, 0))
	Parts.part(
		folder,
		"Telephone",
		desk * CFrame.new(3, deskTop + 0.18, 0.4),
		Vector3.new(1, 0.35, 0.8),
		Parts.detail(Materials.Plastic.Black)
	)
	local plate = Parts.part(
		folder,
		"DeskNameplate",
		desk * CFrame.new(0, deskTop + 0.34, 1.6),
		Vector3.new(3.4, 0.6, 0.2),
		Kit.Style.Bronze
	)
	Kit.inscription(plate, { "LEADER OF THE REVOLUTION" }, Color3.fromRGB(240, 220, 170), Enum.NormalId.Back)

	-- The Leader's chair: the official leather study chair, enlarged (its seat is the
	-- LeadersChair), or a built high-backed leather chair.
	local chairBase = CFrame.lookAt(Vector3.new(cx, y, -730.4), Vector3.new(cx, y, -729.4))
	local chairModel = StoreAssets.place(folder, "DeskChair", chairBase, 1.15)
	local leadersSeat = if chairModel then chairModel:FindFirstChildWhichIsA("Seat", true) else nil
	if chairModel and leadersSeat then
		leadersSeat.Name = "LeadersChair"
	else
		if chairModel then
			chairModel:Destroy()
		end
		local seatAt = Vector3.new(cx, y + 1.65, -730.6)
		local chairFrame = CFrame.lookAt(seatAt, seatAt + Vector3.new(0, 0, 1))
		local leather = Materials.Leather.Oxblood
		Parts.seat(folder, "LeadersChair", chairFrame, Vector3.new(2.6, 0.5, 2.4), leather)
		Parts.part(
			folder,
			"LeadersChairBack",
			chairFrame * CFrame.new(0, 2.1, 1.15),
			Vector3.new(2.9, 4.2, 0.5),
			leather
		)
		for _, side in { -1, 1 } do
			Parts.part(
				folder,
				"LeadersChairArm",
				chairFrame * CFrame.new(side * 1.45, 0.65, 0),
				Vector3.new(0.35, 0.8, 2.3),
				leather
			)
		end
		Parts.cylinder(
			folder,
			"LeadersChairFoot",
			Vector3.new(cx, y, -730.6),
			Vector3.new(cx, y + 1.4, -730.6),
			0.5,
			Parts.detail(Materials.Metal.Dark)
		)
		Parts.cylinder(
			folder,
			"LeadersChairBase",
			Vector3.new(cx, y, -730.6),
			Vector3.new(cx, y + 0.2, -730.6),
			2.4,
			Parts.detail(Materials.Metal.Dark)
		)
	end
	report.Seats += 1

	-- Emblem and flags behind the desk, bookcases on both sides of them.
	Kit.emblem(folder, { Axis = "Z", At = north, Out = 1 }, cx, y + 7.6, 4.4, 0.2)
	for _, side in { -1, 1 } do
		Kit.flagpole(folder, Vector3.new(cx + side * 6.5, y, north + 1.4), 9, 3, Vector3.new(side, 0, 0.3))
		report.Flags += 1
	end
	local case = Furniture.size("BookcaseB")
	for i, x in { 598.6, 603.7, 608.8, 631.2, 636.3, 641.4 } do
		local p = Vector3.new(x, y, north + 0.1 + case.Z / 2)
		local frame = CFrame.lookAt(p, p + Vector3.new(0, 0, 1))
		if not Furniture.store(folder, if i % 2 == 0 then "Bookcase" else "BookcaseB", frame) then
			Furniture.shelf(folder, frame, case.X, case.Z, case.Y, Materials.Wood.Walnut, 70 + i)
		end
	end
	for _, dx in { -2.7, 2.7 } do
		local p = Vector3.new(cx + dx, y, -721.6)
		local frame = CFrame.lookAt(p, p + Vector3.new(0, 0, -1))
		if not Furniture.store(folder, "ArmDiningChair", frame) then
			Furniture.chair(folder, frame, mahogany, Materials.Leather.Brown)
		end
		report.Seats += 1
	end

	-- Sitting group by the front windows: sofa, armchairs, a coffee table on an oriental rug.
	local corner = CFrame.lookAt(Vector3.new(610, y, -700.5), Vector3.new(610, y, -699.5))
	if not Furniture.store(folder, "RugLarge", corner) then
		Furniture.rug(folder, corner, 13.4, 11.8, Materials.Fabric.Beige)
	end
	local sofa = Furniture.size("Sofa3")
	do
		local p = Vector3.new(610, y, -700.5 - 1.5 - 1.3 - sofa.Z / 2)
		local frame = CFrame.lookAt(p, p + Vector3.new(0, 0, 1))
		if not Furniture.store(folder, "Sofa3", frame) then
			Furniture.sofa(folder, frame, 3, Materials.Leather.Brown)
		end
		report.Seats += 3
	end
	do
		local p = Vector3.new(610, y, -700.5)
		local frame = CFrame.lookAt(p, p + Vector3.new(0, 0, 1))
		if not Furniture.store(folder, "CoffeeTable", frame) then
			Furniture.coffeeTable(folder, frame, 5, 2.6, mahogany)
		end
		Furniture.store(folder, "Bowl", frame * CFrame.new(0.8, Furniture.size("CoffeeTable").Y, 0))
	end
	for _, side in { -1, 1 } do
		local p = Vector3.new(610 + side * 6.6, y, -700.5)
		local frame = CFrame.lookAt(p, p - Vector3.new(side, 0, 0))
		if not Furniture.store(folder, "ArmChair", frame) then
			Furniture.armchair(folder, frame, Materials.Leather.Brown)
		end
		report.Seats += 1
	end

	-- Conference table at the east end.
	do
		local p = Vector3.new(647, y, -712)
		local frame = CFrame.lookAt(p, p + Vector3.new(1, 0, 0))
		if not Furniture.store(folder, "Table", frame) then
			Furniture.table(folder, frame, 12, 4.4, Materials.Wood.Walnut)
		end
		for _, z in { -716, -712, -708 } do
			for _, side in { -1, 1 } do
				local c = Vector3.new(647 + side * 3.6, y, z)
				local at = CFrame.lookAt(c, c - Vector3.new(side, 0, 0))
				if not Furniture.store(folder, "DiningChair", at) then
					Furniture.chair(folder, at, Materials.Wood.Walnut, Materials.Fabric.Green)
				end
				report.Seats += 1
			end
		end
	end

	-- A credenza with a portrait over it on the west wall, a grandfather clock, plants.
	do
		local c = Furniture.size("Credenza")
		local p = Vector3.new(west + 0.25 + c.Z / 2, y, -722)
		local frame = CFrame.lookAt(p, p + Vector3.new(1, 0, 0))
		if not Furniture.store(folder, "Credenza", frame) then
			Furniture.cabinet(folder, frame, c.X, c.Z, c.Y, Materials.Wood.Walnut)
		end
	end
	portrait(folder, wallAt(west + 0.02, y + 7, -722, Vector3.new(1, 0, 0)), "PaintingOfficer", 0.62, 11)
	do
		local p = Vector3.new(west + 1.2, y, -712)
		local frame = CFrame.lookAt(p, p + Vector3.new(1, 0, 0))
		if not Furniture.store(folder, "GrandfatherClock", frame) then
			Furniture.clock(folder, wallAt(west + 0.2, y + 8.4, -712, Vector3.new(1, 0, 0)))
		end
	end
	for i, spot in { { 597.4, -730.2 }, { 655.4, -730.2 }, { 597.8, -694.8 } } do
		Furniture.plant(folder, Vector3.new(spot[1], y, spot[2]), 6.5, math.floor(spot[1]), i == 3, 1.5)
	end
	Rooms.curtains(room, Materials.Fabric.Green)

	-- Lights: chandeliers over the desk, the sitting group and the conference table.
	Furniture.chandelier(folder, Vector3.new(cx, ceiling, -722), 3.2, 36, 8)
	Furniture.chandelier(folder, Vector3.new(610, ceiling, -700.5), 3, 28)
	Furniture.chandelier(folder, Vector3.new(647, ceiling, -712), 3, 28)
end

local function villaSpaces(report: { [string]: number }): { Space }
	local list: { Space } = {}
	local function add(space: Space)
		table.insert(list, space)
	end
	local parquet = Materials.Floor.Parquet
	add({
		Name = "Entrance Hall",
		Kind = "Hall",
		Rect = Plan.rect(565, 595, -745, -692),
		Storey = 0,
		Open = true,
		Lights = false,
		Lining = false,
		Custom = hall,
	})
	add({
		Name = "Stair",
		Kind = "Stair",
		Rect = Plan.rect(565, 595, -768, -745),
		Storey = 0,
		Top = 1,
		Entry = "MaxZ",
		Grand = true,
	})
	for s = 0, 1 do
		add({
			Name = "West Passage",
			Kind = "Corridor",
			Rect = Plan.rect(502, 565, -745, -735),
			Storey = s,
			Open = true,
			Floor = parquet,
			Custom = passage,
		})
		add({
			Name = "East Passage",
			Kind = "Corridor",
			Rect = Plan.rect(595, 658, -745, -735),
			Storey = s,
			Open = true,
			Floor = parquet,
			Custom = passage,
		})
	end

	-- Ground floor: reception rooms, the kitchen and the Leader's office.
	add({
		Name = "Salon",
		Kind = "Salon",
		Rect = Plan.rect(525, 565, -735, -692),
		Storey = 0,
		Doors = { Plan.door("MaxX", -705, "Double") },
	})
	add({
		Name = "Music Room",
		Kind = "Music",
		Rect = Plan.rect(502, 525, -735, -692),
		Storey = 0,
		Doors = { Plan.door("MaxX", -705, "Double") },
	})
	add({
		Name = "Dining Room",
		Kind = "Dining",
		Rect = Plan.rect(502, 545, -768, -745),
		Storey = 0,
		Extra = { Plan.door("MaxX") },
	})
	add({ Name = "Kitchen", Kind = "Kitchen", Rect = Plan.rect(545, 565, -768, -745), Storey = 0 })
	add({
		Name = "Office of the Leader",
		Kind = "LeadersOffice",
		Rect = Plan.rect(595, 658, -735, -692),
		Storey = 0,
		Floor = Materials.Floor.ParquetDark,
		Lights = false,
		Doors = { Plan.door("MinX", -705, "Double") },
		Custom = function(room: Room)
			office(room, report)
		end,
	})
	add({ Name = "Library", Kind = "Library", Rect = Plan.rect(595, 635, -768, -745), Storey = 0 })
	add({ Name = "WC", Kind = "WC", Rect = Plan.rect(635, 645, -768, -745), Storey = 0 })
	add({ Name = "Aide-de-Camp", Kind = "Office", Rect = Plan.rect(645, 658, -768, -745), Storey = 0 })

	-- Upper floor: the private rooms.
	add({
		Name = "Upper Hall",
		Kind = "Landing",
		Rect = Plan.rect(565, 595, -745, -692),
		Storey = 1,
		Open = true,
		Floor = parquet,
		Lights = false,
		Lining = false,
		Custom = upperHall,
	})
	add({ Name = "Bedroom", Kind = "Bedroom", Rect = Plan.rect(502, 535, -735, -692), Storey = 1 })
	add({ Name = "Family Room", Kind = "Family", Rect = Plan.rect(535, 565, -735, -692), Storey = 1 })
	add({ Name = "Study", Kind = "Study", Rect = Plan.rect(502, 545, -768, -745), Storey = 1 })
	add({ Name = "Bathroom", Kind = "Bathroom", Rect = Plan.rect(545, 565, -768, -745), Storey = 1 })
	add({ Name = "Master Bedroom", Kind = "Bedroom", Rect = Plan.rect(595, 635, -735, -692), Storey = 1 })
	add({
		Name = "Dressing Room",
		Kind = "Dressing",
		Rect = Plan.rect(635, 658, -735, -715),
		Storey = 1,
		Doors = { Plan.door("MinX") },
	})
	add({
		Name = "Master Bathroom",
		Kind = "Bathroom",
		Rect = Plan.rect(635, 658, -715, -692),
		Storey = 1,
		Doors = { Plan.door("MinX") },
	})
	add({ Name = "Guest Room", Kind = "Guest", Rect = Plan.rect(595, 635, -768, -745), Storey = 1 })
	add({
		Name = "Guest Bathroom",
		Kind = "Bathroom",
		Rect = Plan.rect(635, 658, -768, -745),
		Storey = 1,
		Doors = { Plan.door("MinX") },
	})
	return list
end

function Residence.build(district: any, parent: Instance): { [string]: number }
	local res = district.Residence
	local model = Kit.model(parent, "LeadersResidence", "Residence of the Leader of the Revolution")
	local G = district.GroundY
	local W = G + district.WalkTop
	local r = res.Rect
	local gx = res.Gate
	assert(gx == DOOR_X, "Residence: the villa plan expects the gate at x 580")
	local plaster, ochre = Kit.Style.Plaster, Kit.Style.Ochre
	local report: { [string]: number } = { Windows = 0, Flags = 0, Trees = 0, Seats = 0 }

	-- Apron along the south wall to North Street, lawn inside the walls.
	Kit.slab(model, "Apron", Kit.rect(r.MinX, r.MaxX, r.MaxZ, r.MaxZ + 20), G - 0.6, W, Kit.Style.Paving)
	local inner = Kit.inset(r, 2)
	Kit.slab(model, "Lawn", inner, G - 0.6, W - 0.1, Kit.Style.Lawn)

	-- Perimeter wall with coping and pillars; the gate opening in the south wall.
	local wh = res.WallHeight
	local gate = { { From = gx - 12, To = gx + 12, Bottom = W - 1, Top = W + wh + 2 } }
	Kit.wall(model, "Wall", "X", r.MinX, r.MaxX, r.MaxZ - 1, 2, W - 0.6, W + wh, gate, ochre)
	Kit.wall(model, "Wall", "X", r.MinX, r.MaxX, r.MinZ + 1, 2, W - 0.6, W + wh, nil, ochre)
	Kit.wall(model, "Wall", "Z", r.MinZ + 2, r.MaxZ - 2, r.MinX + 1, 2, W - 0.6, W + wh, nil, ochre)
	Kit.wall(model, "Wall", "Z", r.MinZ + 2, r.MaxZ - 2, r.MaxX - 1, 2, W - 0.6, W + wh, nil, ochre)
	Kit.wall(model, "Coping", "X", r.MinX - 0.4, r.MaxX + 0.4, r.MaxZ - 1, 2.8, W + wh, W + wh + 0.6, gate, plaster)
	Kit.wall(model, "Coping", "X", r.MinX - 0.4, r.MaxX + 0.4, r.MinZ + 1, 2.8, W + wh, W + wh + 0.6, nil, plaster)
	Kit.wall(model, "Coping", "Z", r.MinZ + 2.4, r.MaxZ - 2.4, r.MinX + 1, 2.8, W + wh, W + wh + 0.6, nil, plaster)
	Kit.wall(model, "Coping", "Z", r.MinZ + 2.4, r.MaxZ - 2.4, r.MaxX - 1, 2.8, W + wh, W + wh + 0.6, nil, plaster)
	for x = r.MinX + 40, r.MaxX - 40, 40 do
		if math.abs(x - gx) > 20 then
			Kit.box(model, "WallPillar", x - 1.5, W - 0.6, r.MaxZ - 2.5, x + 1.5, W + wh + 1.2, r.MaxZ + 0.5, plaster)
		end
		Kit.box(model, "WallPillar", x - 1.5, W - 0.6, r.MinZ - 0.5, x + 1.5, W + wh + 1.2, r.MinZ + 2.5, plaster)
	end
	for z = r.MinZ + 40, r.MaxZ - 40, 40 do
		Kit.box(model, "WallPillar", r.MinX - 0.5, W - 0.6, z - 1.5, r.MinX + 2.5, W + wh + 1.2, z + 1.5, plaster)
		Kit.box(model, "WallPillar", r.MaxX - 2.5, W - 0.6, z - 1.5, r.MaxX + 0.5, W + wh + 1.2, z + 1.5, plaster)
	end

	-- Gate: two tall pillars with lanterns, open iron leaves, name plaque, guard posts, barrier.
	for _, side in { -1, 1 } do
		local x = gx + side * 14
		Kit.box(model, "GatePillar", x - 2, W - 0.6, r.MaxZ - 3, x + 2, W + 13, r.MaxZ + 1, plaster)
		Kit.box(model, "GatePillarCap", x - 2.6, W + 13, r.MaxZ - 3.6, x + 2.6, W + 14, r.MaxZ + 1.6, ochre)
		local lamp = Kit.box(
			model,
			"GateLantern",
			x - 0.8,
			W + 14,
			r.MaxZ - 1.8,
			x + 0.8,
			W + 16,
			r.MaxZ - 0.2,
			{ Material = Enum.Material.Glass, Color = Color3.fromRGB(250, 238, 200), CastShadow = false }
		)
		lamp:SetAttribute("RoNationLamp", true)
		local light = Instance.new("PointLight")
		light:SetAttribute("RoNationStreetLight", true)
		light.Enabled = false
		light.Range = 24
		light.Brightness = 1.5
		light.Color = Color3.fromRGB(255, 224, 180)
		light.Parent = lamp
		-- Open leaf, swung inwards against the inside of the pillar.
		local hinge = gx + side * 12
		Kit.box(
			model,
			"GateLeaf",
			hinge - side * 0.2,
			W,
			r.MaxZ - 14,
			hinge + side * 0.2,
			W + 8,
			r.MaxZ - 2,
			{ Material = Enum.Material.Metal, Color = Color3.fromRGB(36, 38, 40), Transparency = 0.25 }
		)
		Kit.box(
			model,
			"GateLeafTop",
			hinge - side * 0.3,
			W + 8,
			r.MaxZ - 14,
			hinge + side * 0.3,
			W + 8.6,
			r.MaxZ - 2,
			Kit.Style.Gold
		)
		-- Guard posts just inside the gate, one on each side of the drive.
		local bx0 = if side < 0 then gx - 22 else gx + 14
		guardPost(model, Kit.rect(bx0, bx0 + 8, r.MaxZ - 26, r.MaxZ - 18), W, -side)
		-- Flags outside the gate.
		Kit.flagpole(model, Vector3.new(gx + side * 26, W, r.MaxZ + 10), 24, 7, Vector3.new(side, 0, 0))
		report.Flags += 1
	end
	local plaque =
		Kit.box(model, "NamePlaque", gx - 23, W + 4, r.MaxZ + 0.05, gx - 16, W + 8, r.MaxZ + 0.25, Kit.Style.Bronze)
	Kit.inscription(
		plaque,
		{ "RESIDENCE OF THE", "LEADER OF THE", "REVOLUTION" },
		Color3.fromRGB(240, 220, 170),
		Enum.NormalId.Back
	)
	-- Boom barrier, raised (open), beside the west guard post.
	local bz = r.MaxZ - 16
	Kit.box(model, "BarrierPost", gx - 11.8, W, bz - 0.6, gx - 10.6, W + 3.6, bz + 0.6, Kit.Style.Iron)
	Kit.box(model, "BarrierArm", gx - 11.6, W + 3.6, bz - 0.3, gx - 10.8, W + 20, bz + 0.3, Kit.Style.Plaster)
	for _, y in { W + 7, W + 12, W + 17 } do
		Kit.box(model, "BarrierStripe", gx - 11.65, y, bz - 0.35, gx - 10.75, y + 2, bz + 0.35, {
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(196, 40, 40),
		})
	end

	-- Drive, turning circle with fountain, lamps.
	local villa = res.Villa
	local circle = Vector3.new(gx, W, villa.MaxZ + 30)
	Kit.slab(model, "Drive", Kit.rect(gx - 9, gx + 9, circle.Z, r.MaxZ - 1), W - 0.6, W + 0.05, COBBLES)
	Kit.drum(model, "TurningCircle", circle.X, circle.Z, W - 0.6, W + 0.05, 46, COBBLES)
	Kit.slab(
		model,
		"Forecourt",
		Kit.rect(villa.MinX + 50, villa.MaxX - 50, villa.MaxZ, circle.Z),
		W - 0.6,
		W + 0.05,
		COBBLES
	)
	Kit.drum(model, "CircleLawn", circle.X, circle.Z, W, W + 0.3, 22, Kit.Style.Lawn)
	Kit.drum(model, "FountainBasin", circle.X, circle.Z, W, W + 1.8, 13, Kit.Style.Marble)
	Kit.drum(model, "FountainWater", circle.X, circle.Z, W + 1.8, W + 1.9, 11.8, Kit.Style.Water)
	Kit.drum(model, "FountainColumn", circle.X, circle.Z, W + 1.8, W + 6, 1.4, Kit.Style.Marble)
	Kit.drum(model, "FountainBowl", circle.X, circle.Z, W + 6, W + 6.6, 4.4, Kit.Style.Marble)
	for _, z in { r.MaxZ - 40, r.MaxZ - 70 } do
		for _, side in { -1, 1 } do
			Kit.lamp(model, Vector3.new(gx + side * 12.5, W, z), 12, { Vector3.new(-side, 0, 0) }, 3)
		end
	end
	for _, side in { -1, 1 } do
		Kit.planter(model, Kit.rect(gx + side * 10 - 1, gx + side * 10 + 1, circle.Z + 26, r.MaxZ - 30), W, 2.4)
		for k = 0, 3 do
			local z0 = circle.Z + 30 + k * 12
			local x0 = if side < 0 then gx - 24 else gx + 14
			Kit.slab(model, "FlowerBed", Kit.rect(x0, x0 + 10, z0, z0 + 8), W - 0.1, W + 0.6, Kit.Style.Soil)
			Kit.slab(model, "Flowers", Kit.rect(x0 + 0.6, x0 + 9.4, z0 + 0.6, z0 + 7.4), W + 0.6, W + 1.4, {
				Material = Enum.Material.Grass,
				Color = FLOWERS[1 + (k + (if side < 0 then 0 else 2)) % #FLOWERS],
				CanCollide = false,
			})
		end
	end

	-- The villa: two storeys, white plaster with ochre quoins and bands, shuttered windows,
	-- slate roof, portico with the balcony.
	local F = W + 2
	local H = 12
	local R = F + 2 * H
	local t = 2
	local v = villa
	Kit.slab(model, "VillaPlinth", Kit.inset(v, -0.8), W - 0.6, F, Kit.Style.Granite)
	local plan = Plan.new({
		Model = model,
		Building = "Residence",
		Footprints = { Kit.inset(v, t) },
		Levels = { F, F + H, R },
		Spaces = villaSpaces(report),
		DoorSigns = false,
		-- Interior of a residence: cream walls, painted wainscot and skirting, walnut panelling
		-- in the Leader's rooms, herringbone parquet, oriental rugs, light upholstery,
		-- curtains, chandeliers in the reception and private rooms.
		Style = {
			Partition = Materials.Paint.Cream,
			Skirting = Materials.Panel.Painted,
			Dado = Materials.Panel.Painted,
			Panelling = Materials.Panel.Painted,
			PanellingBy = {
				Library = Materials.Panel.Walnut,
				Study = Materials.Panel.Walnut,
				LeadersOffice = Materials.Panel.Walnut,
				Dining = Materials.Panel.Walnut,
			},
			Representative = {
				Salon = true,
				Music = true,
				Dining = true,
				Library = true,
				Study = true,
				LeadersOffice = true,
				Family = true,
				Bedroom = true,
				Guest = true,
			},
			Wood = Materials.Wood.Walnut,
			Upholstery = Materials.Fabric.Beige,
			Runner = Materials.Floor.CarpetRed,
			LightSofas = true,
			Fixtures = {
				Salon = "Chandelier",
				Music = "Chandelier",
				Dining = "Chandelier",
				Library = "Chandelier",
				Study = "Chandelier",
				Family = "Chandelier",
				Bedroom = "Chandelier",
				Guest = "Chandelier",
			},
			Door = { Leaf = Materials.Wood.Walnut, Frame = Materials.Frame.White, Handle = Materials.Metal.Brass },
			GlassDoor = {
				Leaf = Materials.Wood.Walnut,
				Frame = Materials.Frame.White,
				Handle = Materials.Metal.Brass,
				Glass = Materials.Glass.Interior,
			},
			Stair = {
				Tread = Materials.Floor.Marble,
				Landing = Materials.Floor.Marble,
				Spine = Materials.Paint.Cream,
				Rail = Materials.Metal.Brass,
			},
			Floors = { Corridor = Materials.Floor.Parquet, Bathroom = Materials.Floor.Marble },
			Accent = Materials.Panel.Walnut,
		},
		Seed = 4,
	})

	-- Facades: windows on a 10-stud grid with marble sills and lintels and open shutters; the
	-- portal and the balcony door on the axis of the gate, a garden door at the back.
	local facade = Kit.folder(model, "Facade")
	local window: Openings.WindowStyle = {
		Frame = Materials.Frame.White,
		Glass = Materials.Glass.Window,
		Sill = Kit.Style.Marble,
		Board = Materials.Wood.White,
		Lintel = Kit.Style.Marble,
		Shutters = SHUTTERS,
	}
	local doorStyle: Openings.DoorStyle = {
		Leaf = Materials.Wood.Walnut,
		Frame = Materials.Frame.White,
		Handle = Materials.Metal.Brass,
		Glass = Materials.Glass.Window,
	}
	local function row(centres: { number }, storeys: { number }): Shell.WindowRow
		return { Centres = centres, Width = 3.6, Height = 7.5, Sill = 2.5, Storeys = storeys }
	end
	local frontDoors: { Shell.DoorSpec } = {
		{ At = DOOR_X, Width = 8, Height = 10, Storey = 0, Double = true, StartOpen = true, Label = "Residence" },
		{ At = DOOR_X, Width = 6, Height = 10, Storey = 1, Double = true, Label = "Balcony" },
	}
	local xs = Shell.steps(510, 10, 650)
	local zs = Shell.steps(-760, 10, -700)
	local beside = Shell.without(xs, { { DOOR_X - 15, DOOR_X + 15 } })
	local runs: { Shell.Run } = {
		{
			Axis = "X",
			At = v.MaxZ - t / 2,
			From = v.MinX,
			To = v.MaxX,
			Thickness = t,
			Out = 1,
			Material = plaster,
			Window = window,
			Door = doorStyle,
			Windows = { row(beside, { 0, 1 }), row({ DOOR_X - 10, DOOR_X + 10 }, { 1 }) },
			Doors = frontDoors,
		},
		{
			Axis = "X",
			At = v.MinZ + t / 2,
			From = v.MinX,
			To = v.MaxX,
			Thickness = t,
			Out = -1,
			Material = plaster,
			Window = window,
			Door = doorStyle,
			Windows = { row(Shell.without(xs, { { GARDEN_X - 5, GARDEN_X + 5 } }), { 0 }), row(xs, { 1 }) },
			Doors = { { At = GARDEN_X, Width = 6, Height = 9, Storey = 0, Double = true, Label = "Garden" } },
		},
	}
	for _, side in { -1, 1 } do
		table.insert(runs, {
			Axis = "Z",
			At = (if side < 0 then v.MinX else v.MaxX) - side * t / 2,
			From = v.MinZ + t,
			To = v.MaxZ - t,
			Thickness = t,
			Out = side,
			Material = plaster,
			Window = window,
			Windows = { row(zs, { 0, 1 }) },
		})
	end
	local shell = Shell.build(plan, facade, runs)
	report.Windows = shell.Windows
	model:SetAttribute("WindowsWithoutRoom", shell.Unmapped)
	model:SetAttribute("WindowsBlocked", shell.Blocked)
	local interior = Plan.build(plan, Rooms.furnish)
	for key, value in interior do
		report[key] = value
	end

	-- Bands, quoins, roof with gable ends, chimneys, gutters and downpipes.
	local balconyGap: { Kit.Gap } = { { Side = "South", From = DOOR_X - 15, To = DOOR_X + 15 } }
	Kit.band(model, "StringCourse", v, F + H - 0.3, F + H + 0.5, 0.4, ochre, balconyGap)
	Kit.band(model, "Cornice", v, R - 0.8, R + 0.2, 1, ochre)
	local roofHeight = 11
	Kit.gableRoof(model, v, R, roofHeight, "X", 1.5, Kit.Style.Slate)
	local gable = roofHeight * ((v.MaxZ - v.MinZ) / 2) / ((v.MaxZ - v.MinZ) / 2 + 1.5)
	Kit.pediment(model, { Axis = "X", At = v.MinX, Out = -1 }, v.MinZ, v.MaxZ, R, gable, -t, 1.55, plaster)
	Kit.pediment(model, { Axis = "X", At = v.MaxX, Out = 1 }, v.MinZ, v.MaxZ, R, gable, -t, 1.55, plaster)
	for _, x in { v.MinX + 30, v.MaxX - 30 } do
		Kit.box(model, "Chimney", x - 2, R + 4, v.MinZ + 16, x + 2, R + 14, v.MinZ + 20, plaster)
		Kit.box(
			model,
			"ChimneyCap",
			x - 2.4,
			R + 14,
			v.MinZ + 15.6,
			x + 2.4,
			R + 14.5,
			v.MinZ + 20.4,
			Kit.Style.Granite
		)
	end
	for _, corner in { { v.MinX, v.MinZ }, { v.MinX, v.MaxZ }, { v.MaxX, v.MinZ }, { v.MaxX, v.MaxZ } } do
		Kit.box(model, "Quoin", corner[1] - 1.4, F, corner[2] - 1.4, corner[1] + 1.4, R - 0.8, corner[2] + 1.4, ochre)
	end
	Exterior.gutter(model, "X", v.MaxZ + 1.5, v.MinX - 1.5, v.MaxX + 1.5, R, 1)
	Exterior.gutter(model, "X", v.MinZ - 1.5, v.MinX - 1.5, v.MaxX + 1.5, R, -1)
	for _, x in { v.MinX + 3, v.MaxX - 3 } do
		Exterior.downpipe(model, x, v.MaxZ, Vector3.new(0, 0, 1), R, F, 1)
		Exterior.downpipe(model, x, v.MinZ, Vector3.new(0, 0, -1), R, F, 1)
	end
	-- Air conditioners under some windows at the back and on the east side.
	local back: Openings.Wall = { Axis = "X", At = v.MinZ + t / 2, Thickness = t, Out = -1 }
	local eastWall: Openings.Wall = { Axis = "Z", At = v.MaxX - t / 2, Thickness = t, Out = 1 }
	Exterior.acUnit(model, back, 550, F + 0.5)
	Exterior.acUnit(model, back, 520, F + H + 0.5)
	Exterior.acUnit(model, back, 610, F + H + 0.5)
	Exterior.acUnit(model, eastWall, -720, F + 0.5)
	Exterior.acUnit(model, eastWall, -750, F + 0.5)

	-- Portico: four columns carrying the balcony, the portal surround, lanterns, emblem, flags.
	local front: Kit.Face = { Axis = "Z", At = v.MaxZ, Out = 1 }
	for _, dx in { -12, -4, 4, 12 } do
		Kit.column(model, DOOR_X + dx, v.MaxZ + 6, F, F + H - 1, 2.6, Kit.Style.Marble)
	end
	Kit.box(model, "PorticoStep", DOOR_X - 15, W - 0.2, v.MaxZ, DOOR_X + 15, F, v.MaxZ + 8.5, Kit.Style.Granite)
	Kit.box(
		model,
		"PorticoStep",
		DOOR_X - 15,
		W - 0.2,
		v.MaxZ + 8.5,
		DOOR_X + 15,
		W + 1,
		v.MaxZ + 10,
		Kit.Style.Granite
	)
	Kit.faceBox(model, "Balcony", front, DOOR_X - 15, DOOR_X + 15, F + H - 1, F + H, 0, 8.5, Kit.Style.Marble)
	Kit.faceBox(model, "Balustrade", front, DOOR_X - 15, DOOR_X + 15, F + H, F + H + 3.2, 8, 8.5, Kit.Style.Marble)
	Kit.faceBox(model, "Balustrade", front, DOOR_X - 15, DOOR_X - 14.5, F + H, F + H + 3.2, 0, 8, Kit.Style.Marble)
	Kit.faceBox(model, "Balustrade", front, DOOR_X + 14.5, DOOR_X + 15, F + H, F + H + 3.2, 0, 8, Kit.Style.Marble)
	Kit.ceilingLight(model, DOOR_X, v.MaxZ + 4.5, F + H - 1, 2, 20)
	Kit.faceBox(model, "DoorSurround", front, DOOR_X - 5.3, DOOR_X - 4.35, F, F + 10.4, 0, 0.4, Kit.Style.Marble)
	Kit.faceBox(model, "DoorSurround", front, DOOR_X + 4.35, DOOR_X + 5.3, F, F + 10.4, 0, 0.4, Kit.Style.Marble)
	Kit.faceBox(model, "DoorSurround", front, DOOR_X - 5.3, DOOR_X + 5.3, F + 10.35, F + 11.3, 0, 0.5, Kit.Style.Marble)
	for _, side in { -1, 1 } do
		lantern(model, DOOR_X + side * 7, F + 7, v.MaxZ, Vector3.new(0, 0, 1))
	end
	Kit.emblem(model, { Axis = "Z", At = v.MaxZ + 8.5, Out = 1 }, DOOR_X, F + H + 1.6, 2.6, 0.05)
	for _, side in { -1, 1 } do
		Kit.flagpole(model, Vector3.new(DOOR_X + side * 26, W, v.MaxZ + 16), 26, 8, Vector3.new(side, 0, 0))
		report.Flags += 1
	end

	-- Garden terrace at the back, before the dining room's garden door.
	Kit.slab(
		model,
		"Terrace",
		Kit.rect(GARDEN_X - 12, GARDEN_X + 12, v.MinZ - 4.5, v.MinZ - 0.8),
		W - 0.6,
		F,
		Kit.Style.Granite
	)
	Kit.box(
		model,
		"TerraceStep",
		GARDEN_X - 5,
		W - 0.2,
		v.MinZ - 6,
		GARDEN_X + 5,
		W + 1,
		v.MinZ - 4.5,
		Kit.Style.Granite
	)
	for _, side in { -1, 1 } do
		Furniture.plant(model, Vector3.new(GARDEN_X + side * 10.5, F, v.MinZ - 2.6), 4.5, 90 + side)
	end
	lantern(model, GARDEN_X - 5, F + 6.5, v.MinZ, Vector3.new(0, 0, -1))

	-- Gardens: trees along the walls, a gazebo behind the villa.
	local treeIndex = 0
	local function treeAt(x: number, z: number)
		treeIndex += 1
		Kit.tree(model, Vector3.new(x, W - 0.1, z), 20 + treeIndex % 3 * 3, 20 + treeIndex)
		report.Trees += 1
	end
	for x = r.MinX + 14, r.MaxX - 14, 30 do
		treeAt(x, r.MinZ + 10)
		if math.abs(x - gx) > 40 then
			treeAt(x, r.MaxZ - 10)
		end
	end
	for z = r.MinZ + 40, r.MaxZ - 30, 30 do
		treeAt(r.MinX + 10, z)
		treeAt(r.MaxX - 10, z)
	end
	local gz = (r.MinZ + v.MinZ) / 2
	local centre = Vector3.new(GARDEN_X, W, gz)
	Kit.drum(model, "GazeboFloor", centre.X, centre.Z, W - 0.6, W + 0.8, 16, Kit.Style.Marble)
	for k = 0, 5 do
		local a = k * math.pi / 3
		local p = centre + Vector3.new(math.cos(a) * 6.6, 0, math.sin(a) * 6.6)
		Parts.cylinder(
			model,
			"GazeboColumn",
			p + Vector3.new(0, 0.8, 0),
			p + Vector3.new(0, 7.4, 0),
			0.9,
			Kit.Style.Marble
		)
	end
	-- The roof ring hides the lower half of the dome.
	Kit.drum(model, "GazeboRoof", centre.X, centre.Z, W + 7.4, W + 10.6, 16, Kit.Style.Plaster)
	Kit.ellipsoid(model, "GazeboDome", centre + Vector3.new(0, 10.6, 0), Vector3.new(15, 6.4, 15), Kit.Style.Copper)
	Kit.bench(model, centre + Vector3.new(0, 0.8, 4.4), Vector3.new(0, 0, -1))
	Kit.bench(model, centre + Vector3.new(0, 0.8, -4.4), Vector3.new(0, 0, 1))
	-- A round table between the benches and a lantern hanging from the roof.
	local wood = Materials.Wood.Walnut
	Parts.cylinder(
		model,
		"GazeboTableFoot",
		centre + Vector3.new(0, 0.8, 0),
		centre + Vector3.new(0, 3.5, 0),
		0.6,
		Parts.detail(wood)
	)
	Parts.cylinder(model, "GazeboTable", centre + Vector3.new(0, 3.5, 0), centre + Vector3.new(0, 3.75, 0), 4, wood)
	Parts.cylinder(
		model,
		"GazeboLanternChain",
		centre + Vector3.new(0, 6.9, 0),
		centre + Vector3.new(0, 7.5, 0),
		0.12,
		Parts.detail(Materials.Metal.Iron)
	)
	local glass = Parts.box(
		model,
		"GazeboLantern",
		centre.X - 0.5,
		W + 6,
		centre.Z - 0.5,
		centre.X + 0.5,
		W + 6.9,
		centre.Z + 0.5,
		{
			Material = Enum.Material.Glass,
			Color = Color3.fromRGB(250, 238, 200),
			CastShadow = false,
			CanCollide = false,
		}
	)
	glass:SetAttribute("RoNationLamp", true)
	local light = Instance.new("PointLight")
	light:SetAttribute("RoNationStreetLight", true)
	light.Enabled = false
	light.Range = 16
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 224, 180)
	light.Parent = glass

	model:SetAttribute("Height", R + roofHeight + 3.5 - G)
	return report
end

return Residence
