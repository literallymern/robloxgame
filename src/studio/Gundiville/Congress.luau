--!strict
-- General People's Congress: the tallest building of the district, closing the north end of the
-- main square, with a central dome (encyclopedia). Cream limestone on a granite podium,
-- ceremonial steps down to the forecourt, a portico of eight columns with the national emblem
-- in the pediment.
--
-- Inside (Architecture.Plan): the assembly chamber in the middle of the building, three storeys
-- high under the dome, a hemicycle of 47 seats facing the presiding dais with three more; the
-- two-storey entrance hall between the portal and the chamber; around them on three storeys the
-- offices of the Congress, the delegations of the People's Councils, trade unions and
-- professional associations, committee rooms, a library, a cafeteria, washrooms, kitchens and
-- two stair and lift cores. A gallery runs along the whole north front on every floor; corridors
-- along the west and east wings and the front connect it to the hall. Every window of the
-- facades opens into one of these rooms.

local Kit = require(script.Parent.Kit)
local Util = require(script.Parent.Parent.Map.Builders.Util)
local Architecture = script.Parent.Parent.Architecture
local Materials = require(Architecture.Materials)
local Openings = require(Architecture.Openings)
local Plan = require(Architecture.Plan)
local Shell = require(Architecture.Shell)
local Rooms = require(Architecture.Rooms)
local Furniture = require(Architecture.Furniture)
local Exterior = require(Architecture.Exterior)

type Space = Plan.Space
type Rect = Plan.Rect
type Room = Rooms.Room

local Congress = {}

local function seat(parent: Instance, position: Vector3, facing: Vector3, options: any?): Seat
	local s = Instance.new("Seat")
	s.Name = "Seat"
	s.Anchored = true
	s.Size = Vector3.new(2.4, 0.5, 2.2)
	s.CFrame = CFrame.lookAt(position, position + facing)
	s.Material = Enum.Material.Leather
	s.Color = if options then options.Color else Color3.fromRGB(122, 78, 50) -- cognac leather
	s.TopSurface = Enum.SurfaceType.Smooth
	s.BottomSurface = Enum.SurfaceType.Smooth
	s.Parent = parent
	Kit.add(1)
	return s
end
Congress.seat = seat

-- The assembly chamber (custom furnishing of the chamber space): wood panelling, the
-- presiding dais on the north side with the national emblem and two flags behind it, and the
-- hemicycle of four rising rows facing it.
local function chamber(room: Room, report: { [string]: number })
	local folder = room.Folder
	local r = room.Space.Rect
	local minZ = r.MinZ + Plan.Partition / 2
	local top = room.Floor
	local ceiling = room.Floor + room.Height
	Rooms.wainscot(room, 10, Materials.Panel.Walnut)

	local daisZ = minZ + 2
	Kit.box(folder, "Dais", -26, top, daisZ, 26, top + 1.6, daisZ + 14, Kit.Style.Floor)
	Kit.box(folder, "DaisDesk", -15, top + 1.6, daisZ + 9, 15, top + 5, daisZ + 10.5, Kit.Style.DarkWood)
	for _, x in { -8, 0, 8 } do
		seat(folder, Vector3.new(x, top + 2.1, daisZ + 6.5), Vector3.new(0, 0, 1))
		report.Seats += 1
	end
	Kit.box(folder, "Lectern", -2, top, daisZ + 18, 2, top + 4.6, daisZ + 20, Kit.Style.DarkWood)
	local back: Kit.Face = { Axis = "Z", At = minZ, Out = 1 }
	Kit.box(folder, "EmblemPanel", -11, top + 12, minZ, 11, top + 34, minZ + 0.4, Kit.Style.DarkWood)
	Kit.emblem(folder, back, 0, top + 23, 18, 0.7)
	for _, x in { -20, 20 } do
		Kit.flagpole(folder, Vector3.new(x, top + 1.6, daisZ + 3), 16, 5, Vector3.new(-x / 20, 0, 0.4))
	end

	local centre = Vector3.new(0, 0, daisZ + 16)
	local spread = math.rad(70)
	for row, radius in { 22, 29, 36, 43 } do
		local rise = (row - 1) * 0.9
		local n = math.floor(radius * 2 * spread / 6.5)
		for k = 0, n - 1 do
			local a = -spread + (k + 0.5) * (2 * spread / n)
			local dir = Vector3.new(math.sin(a), 0, math.cos(a)) -- from the dais outwards
			local p = centre + dir * radius
			local frame = CFrame.lookAt(Vector3.new(p.X, top, p.Z), Vector3.new(p.X, top, p.Z) - dir)
			if rise > 0 then
				Util.part(
					folder,
					"Tier",
					frame * CFrame.new(0, rise / 2, -0.6),
					Vector3.new(5.2, rise, 5.6),
					Kit.Style.Floor
				)
				Kit.add(1)
			end
			seat(folder, (frame * CFrame.new(0, rise + 1.5, 0.6)).Position, -dir)
			Util.part(
				folder,
				"SeatBack",
				frame * CFrame.new(0, rise + 2.9, 1.75),
				Vector3.new(2.4, 2.4, 0.3),
				{ Material = Enum.Material.Leather, Color = Color3.fromRGB(108, 68, 44) }
			)
			Util.part(
				folder,
				"Desk",
				frame * CFrame.new(0, rise + 1.5, -1.6),
				Vector3.new(4.6, 3, 1.1),
				Kit.Style.DarkWood
			)
			Kit.add(2)
			report.Seats += 1
		end
	end

	-- Vote displays on the side walls, a clock over the entrance, chandeliers.
	local sideWalls: { Rooms.Side } = { "Left", "Right" }
	for _, side in sideWalls do
		Rooms.findWall(room, side :: Rooms.Side, 16, 12, function(wall)
			Furniture.screen(folder, wall, 11)
		end)
	end
	local endWalls: { Rooms.Side } = { "Front", "Back" }
	for _, side in endWalls do
		Rooms.findWall(room, side :: Rooms.Side, 13, 1.6, function(wall)
			Furniture.clock(folder, wall)
		end)
	end
	for _, x in { -30, 0, 30 } do
		for _, z in { r.MinZ + 22, r.MaxZ - 22 } do
			Furniture.chandelier(folder, Vector3.new(x, ceiling, z), 8, 54, 12)
		end
	end
end

-- The entrance hall (custom furnishing): carpet runner from the portal to the chamber, the
-- emblem over the chamber door, security desks, benches, plants and chandeliers.
local function hall(room: Room)
	local folder = room.Folder
	local r = room.Space.Rect
	local y = room.Floor
	local ceiling = y + room.Height
	local minZ = r.MinZ + Plan.Partition / 2
	-- A deep green runner with a sand border from the portal to the chamber doors.
	local runnerAt = Vector3.new(0, y, (minZ + r.MaxZ) / 2)
	Furniture.runner(
		folder,
		CFrame.lookAt(runnerAt, runnerAt + Vector3.new(0, 0, 1)),
		12,
		r.MaxZ - minZ,
		Materials.Floor.CarpetGreen,
		Materials.Floor.CarpetSand
	)
	Rooms.panelling(room, Materials.Panel.Walnut, 3.4)
	Kit.emblem(folder, { Axis = "Z", At = minZ, Out = 1 }, 0, y + 17.3, 4.5, 0.2)
	for _, side in { -1, 1 } do
		local x = side * 24
		local desk = Vector3.new(x, y, -327)
		Furniture.counter(
			folder,
			CFrame.lookAt(desk, desk + Vector3.new(0, 0, 1)),
			8,
			2.4,
			Materials.Wood.Walnut,
			Kit.Style.Marble
		)
		Furniture.officeChair(
			folder,
			CFrame.lookAt(desk + Vector3.new(0, 0, -2.6), desk + Vector3.new(0, 0, 1)),
			Materials.Leather.Black
		)
		local bench = Vector3.new(side * 22, y, minZ + 1.4)
		Furniture.bench(folder, CFrame.lookAt(bench, bench + Vector3.new(0, 0, 1)), 10, Materials.Wood.Walnut)
		Furniture.plant(folder, Vector3.new(side * 38, y, r.MaxZ - 3), 8, 3 + side, true, 2.4)
		Furniture.plant(folder, Vector3.new(side * 11, y, minZ + 1.8), 6, 5 + side, false, 1.5)
		for _, z in { -337, -322 } do
			Furniture.chandelier(folder, Vector3.new(side * 22, ceiling, z), 7, 46, 8)
		end
	end
end

-- Rooftop plant: air-conditioning condensers, vent pipes and access hatches over the wings.
local function rooftop(parent: Instance, y: number)
	for _, x in { -112, -96, -80, 80, 96, 112 } do
		Exterior.condenser(parent, x, -326, y)
	end
	for _, p in { { -84, -396 }, { 84, -396 }, { -116, -370 }, { 116, -370 }, { -60, -330 }, { 60, -330 } } do
		Exterior.vent(parent, p[1], p[2], y)
	end
	for _, x in { -83, 83 } do
		Exterior.hatch(parent, x, -413, y)
	end
end

-- The space plan of the building. Rect coordinates are the centre lines of the partitions and
-- the inner faces of the exterior walls (inner -128..128 x -430..-314).
local function spaces(c: any, chamberRoom: (room: Room) -> (), hallRoom: (room: Room) -> ()): { Space }
	local list: { Space } = {}
	local function add(space: Space)
		table.insert(list, space)
	end
	-- West wing coordinates; the east wing mirrors them.
	local function place(rect: Rect, side: number): Rect
		if side < 0 then
			return rect
		end
		return Plan.rect(-rect.MaxX, -rect.MinX, rect.MinZ, rect.MaxZ)
	end
	type Entry = { Name: string, Kind: string, Gender: ("Men" | "Women" | "Accessible")? }
	local function e(name: string, kind: string, gender: ("Men" | "Women" | "Accessible")?): Entry
		return { Name = name, Kind = kind, Gender = gender }
	end
	type Wing = {
		Strip: { Entry }, -- outer strip along the side facade, north to south
		Front: { Entry }, -- along the south facade, from the side facade towards the hall
		Small: Entry, -- beside the lift
		WC: { Entry },
		Meeting: Entry,
		Pantry: Entry,
	}
	local programme: { [string]: { Wing } } = {
		West = {
			{
				Strip = { e("Post Room", "Post"), e("Ushers", "SharedOffice"), e("First Aid", "FirstAid") },
				Front = {
					e("Members' Library", "Library"),
					e("Clerk's Office", "Office"),
					e("Information", "Office"),
					e("Visitors' Centre", "Waiting"),
				},
				Small = e("Janitor", "Janitor"),
				WC = { e("WC Men", "WC", "Men"), e("WC Women", "WC", "Women") },
				Meeting = e("Conference Room", "Meeting"),
				Pantry = e("Staff Kitchen", "Pantry"),
			},
			{
				Strip = {
					e("Delegates' Office", "SharedOffice"),
					e("Delegates' Office", "SharedOffice"),
					e("Legal Service", "Office"),
				},
				Front = {
					e("Members' Lounge", "Lounge"),
					e("People's Councils Delegation", "SharedOffice"),
					e("Trade Unions Delegation", "SharedOffice"),
					e("Professions Delegation", "SharedOffice"),
				},
				Small = e("Storage", "Storage"),
				WC = { e("WC Women", "WC", "Women"), e("WC Men", "WC", "Men") },
				Meeting = e("Budget Committee", "Committee"),
				Pantry = e("Copy Room", "Copy"),
			},
			{
				Strip = {
					e("Records Office", "Archive"),
					e("Secretariat", "SharedOffice"),
					e("Personnel Office", "Office"),
				},
				Front = {
					e("Congress Secretariat", "SharedOffice"),
					e("Deputy Secretary", "Office"),
					e("Secretary's Office", "Reception"),
					e("Secretary of the Congress", "Executive"),
				},
				Small = e("Janitor", "Janitor"),
				WC = { e("WC Men", "WC", "Men"), e("WC Women", "WC", "Women") },
				Meeting = e("Secretariat Meeting Room", "Meeting"),
				Pantry = e("Tea Kitchen", "Pantry"),
			},
		},
		East = {
			{
				Strip = { e("Storage", "Storage"), e("Archive", "Archive"), e("Protocol Office", "Office") },
				Front = {
					e("Cafeteria", "Cafeteria"),
					e("Translation Service", "SharedOffice"),
					e("Press Office", "Office"),
					e("Security", "Security"),
				},
				Small = e("Server Room", "Server"),
				WC = { e("WC Women", "WC", "Women"), e("WC Men", "WC", "Men") },
				Meeting = e("Briefing Room", "Meeting"),
				Pantry = e("Copy Room", "Copy"),
			},
			{
				Strip = {
					e("Committee Staff", "SharedOffice"),
					e("Motions Office", "Office"),
					e("Members' Office", "Office"),
				},
				Front = {
					e("Budget Office", "SharedOffice"),
					e("Members' Office", "Office"),
					e("Members' Office", "Office"),
					e("Rapporteur", "Office"),
				},
				Small = e("Janitor", "Janitor"),
				WC = { e("Accessible WC", "WC", "Accessible"), e("WC Men", "WC", "Men") },
				Meeting = e("Legal Affairs Committee", "Committee"),
				Pantry = e("Tea Kitchen", "Pantry"),
			},
			{
				Strip = { e("Archive", "Archive"), e("Accounts Office", "SharedOffice"), e("IT Service", "Office") },
				Front = {
					e("Press Archive", "Archive"),
					e("Translation Office", "SharedOffice"),
					e("Protocol of the Secretary", "Office"),
					e("Small Conference Room", "Board"),
				},
				Small = e("Storage", "Storage"),
				WC = { e("WC Women", "WC", "Women"), e("WC Men", "WC", "Men") },
				Meeting = e("Delegation Room", "Meeting"),
				Pantry = e("Copy Room", "Copy"),
			},
		},
	}
	local stripZ = { -420, -396.75, -371.75, -345 }
	local frontX = { -128, -103, -83, -63, -41 }
	local galleryNames = { "North Lobby", "Members' Gallery", "Upper Gallery" }

	-- Tall spaces first: the chamber, the hall, the stair and lift cores.
	add({
		Name = "Assembly Chamber",
		Kind = "Chamber",
		Rect = Plan.rect(c.Chamber.MinX, c.Chamber.MaxX, c.Chamber.MinZ, c.Chamber.MaxZ),
		Storey = 0,
		Top = 2,
		Floor = Materials.Floor.CarpetGreen,
		Lights = false,
		Lining = false,
		Custom = chamberRoom,
		Doors = {
			Plan.door("MaxZ", 0, "Double", { Width = 8, Height = 10, StartOpen = true }),
			Plan.door("MinZ", -30, "Double"),
			Plan.door("MinZ", 30, "Double"),
		},
	})
	add({
		Name = "Entrance Hall",
		Kind = "Hall",
		Rect = Plan.rect(-41, 41, -345, -314),
		Storey = 0,
		Top = 1,
		Open = true,
		Lights = false,
		Lining = false,
		Custom = hallRoom,
	})
	for _, side in { -1, 1 } do
		add({
			Name = "Stair",
			Kind = "Stair",
			Rect = place(Plan.rect(-96, -70, -420, -404), side),
			Storey = 0,
			Top = 2,
			Entry = if side < 0 then "MinX" else "MaxX",
		})
		add({ Name = "Lift", Kind = "Lift", Rect = place(Plan.rect(-70, -61, -420, -404), side), Storey = 0, Top = 2 })
	end

	for s = 0, 2 do
		add({ Name = galleryNames[s + 1], Kind = "Gallery", Rect = Plan.rect(-128, 128, -430, -420), Storey = s })
		for _, side in { -1, 1 } do
			local wing: Wing = programme[if side < 0 then "West" else "East"][s + 1]
			local sideName = if side < 0 then "West" else "East"
			add({
				Name = `{sideName} Corridor`,
				Kind = "Corridor",
				Rect = place(Plan.rect(-104, -96, -420, -345), side),
				Storey = s,
			})
			add({
				Name = `{sideName} Front Corridor`,
				Kind = "Corridor",
				Rect = place(Plan.rect(-128, -41, -345, -336), side),
				Storey = s,
			})
			for i, entry in wing.Strip do
				add({
					Name = entry.Name,
					Kind = entry.Kind,
					Rect = place(Plan.rect(-128, -104, stripZ[i], stripZ[i + 1]), side),
					Storey = s,
				})
			end
			for i, entry in wing.Front do
				add({
					Name = entry.Name,
					Kind = entry.Kind,
					Rect = place(Plan.rect(frontX[i], frontX[i + 1], -336, -314), side),
					Storey = s,
				})
			end
			add({
				Name = wing.Small.Name,
				Kind = wing.Small.Kind,
				Rect = place(Plan.rect(-61, -53, -420, -404), side),
				Storey = s,
			})
			add({
				Name = wing.WC[1].Name,
				Kind = "WC",
				Gender = wing.WC[1].Gender,
				Rect = place(Plan.rect(-96, -53, -404, -394), side),
				Storey = s,
			})
			add({
				Name = wing.WC[2].Name,
				Kind = "WC",
				Gender = wing.WC[2].Gender,
				Rect = place(Plan.rect(-96, -53, -394, -384), side),
				Storey = s,
			})
			add({
				Name = wing.Meeting.Name,
				Kind = wing.Meeting.Kind,
				Rect = place(Plan.rect(-96, -53, -384, -356), side),
				Storey = s,
			})
			add({
				Name = wing.Pantry.Name,
				Kind = wing.Pantry.Kind,
				Rect = place(Plan.rect(-96, -53, -356, -345), side),
				Storey = s,
			})
		end
	end
	-- Over the entrance hall: the press room, with a window into the chamber.
	add({
		Name = "Press Room",
		Kind = "Press",
		Rect = Plan.rect(-41, 41, -345, -314),
		Storey = 2,
		Doors = { Plan.door("MinX", -340.5), Plan.door("MaxX", -340.5) },
		Extra = { Plan.door("MinZ", 0, "Glazing", { Width = 24, Bottom = 3.5, Height = 10 }) },
	})
	return list
end

function Congress.build(district: any, parent: Instance): { [string]: number }
	local c = district.Congress
	local model = Kit.model(parent, "GeneralPeoplesCongress", "General People's Congress")
	local G = district.GroundY
	local W = G + district.WalkTop
	local P = W + c.PodiumHeight
	local H = c.StoreyHeight
	local R = P + H * c.Storeys -- roof line
	local b = c.Body
	local report: { [string]: number } = { Windows = 0, Seats = 0 }
	local stone, marble, granite = Kit.Style.Limestone, Kit.Style.Marble, Kit.Style.Granite

	-- Grounds: paving to the side streets, the podium, the ceremonial steps and the back yard.
	Kit.slab(model, "Grounds", Kit.rect(-145, 145, -500, c.Forecourt.MaxZ), G - 0.6, W, Kit.Style.Paving)
	Kit.slab(model, "Podium", Kit.rect(c.Rect.MinX, c.Rect.MaxX, c.Rect.MinZ, c.Forecourt.MinZ), W - 0.2, P, granite)
	Kit.slab(
		model,
		"PodiumCourse",
		Kit.rect(c.Rect.MinX - 0.6, c.Rect.MaxX + 0.6, c.Rect.MinZ - 0.6, c.Forecourt.MinZ + 0.6),
		P - 0.8,
		P - 0.2,
		Kit.Style.DarkGranite
	)
	local f = c.Forecourt
	local steps = 8
	local depth = (f.MaxZ - f.MinZ) / steps
	for i = 0, steps - 1 do
		local front = f.MaxZ - i * depth
		Kit.box(model, "Step", -70, W - 0.4, front - depth, 70, W + (P - W) * (i + 1) / steps, front, marble)
	end
	for _, side in { -1, 1 } do
		local centre = Vector3.new(side * 73, (W + P) / 2, (f.MinZ + f.MaxZ) / 2)
		Util.wedge(
			model,
			"StepCheek",
			CFrame.lookAt(centre, centre + Vector3.new(0, 0, 1)),
			Vector3.new(6, P - W, f.MaxZ - f.MinZ),
			granite
		)
		Kit.add(1)
		Kit.planter(
			model,
			Kit.rect(
				side * 78 - (if side < 0 then 60 else 0),
				side * 78 + (if side > 0 then 60 else 0),
				f.MinZ + 2,
				f.MaxZ - 2
			),
			W,
			2.2
		)
	end
	-- Back yard (service entrance, cars) with steps down from the back door.
	Kit.slab(model, "Yard", Kit.rect(-100, 100, -498, -458), W - 0.6, W + 0.02, Kit.Style.Asphalt)
	for i = 0, 7 do
		Kit.box(
			model,
			"BackStep",
			-8,
			W - 0.4,
			b.MinZ - 8 - 1.5 * (7 - i) - 1.5,
			8,
			W + (P - W) * (i + 1) / 8,
			b.MinZ - 8 - 1.5 * (7 - i),
			marble
		)
	end
	for x = -90, 80, 14 do
		Kit.box(model, "ParkingLine", x, W + 0.02, -496, x + 0.4, W + 0.06, -480, Kit.Style.Paint)
	end

	-- The plan of the interior.
	local t = 2
	local inner = Kit.inset(b, t)
	local plan = Plan.new({
		Model = model,
		Building = "Congress",
		Footprints = { inner },
		Levels = { P, P + H, P + 2 * H, R },
		Spaces = spaces(c, function(room)
			chamber(room, report)
		end, hall),
		-- Interior: warm stone-grey walls, walnut skirting, dado and panelling, moss and taupe
		-- carpets in the offices, deep green in the committee rooms, oak parquet in the
		-- corridors, chandeliers in the representative rooms.
		Style = {
			Partition = Materials.Paint.Stone,
			Skirting = Materials.Panel.Walnut,
			Dado = Materials.Panel.Walnut,
			Panelling = Materials.Panel.Walnut,
			Wood = Materials.Wood.Walnut,
			Upholstery = Materials.Leather.Brown,
			Runner = Materials.Floor.CarpetGreen,
			Fixtures = { Committee = "Chandelier", Board = "Chandelier", Library = "Chandelier", Lounge = "Chandelier", Executive = "Chandelier" },
			Door = { Leaf = Materials.Wood.Walnut, Frame = Materials.Frame.Brown, Handle = Materials.Metal.Brass },
			GlassDoor = {
				Leaf = Materials.Wood.Walnut,
				Frame = Materials.Frame.Brown,
				Handle = Materials.Metal.Brass,
				Glass = Materials.Glass.Interior,
			},
			Plate = Materials.Metal.Brass,
			Ink = Color3.fromRGB(34, 28, 20),
			Stair = {
				Tread = Materials.Floor.Marble,
				Landing = Materials.Floor.Marble,
				Spine = Materials.Paint.Stone,
				Rail = Materials.Metal.Brass,
			},
			Floors = {
				Gallery = Materials.Floor.Marble,
				Corridor = Materials.Floor.Parquet,
				Office = Materials.Floor.CarpetMoss,
				SharedOffice = Materials.Floor.CarpetTaupe,
				Meeting = Materials.Floor.CarpetTaupe,
				Committee = Materials.Floor.CarpetGreen,
				Board = Materials.Floor.CarpetGreen,
				Reception = Materials.Floor.CarpetMoss,
				Press = Materials.Floor.CarpetTaupe,
				Waiting = Materials.Floor.Marble,
			},
			Accent = Materials.Panel.Walnut,
		},
		Seed = 1,
	})

	-- Facades: limestone walls with bronze windows, the three portal doors and the back door.
	local facade = Kit.folder(model, "Facade")
	local grand: Openings.WindowStyle = {
		Frame = Materials.Frame.Bronze,
		Glass = Materials.Glass.Window,
		Sill = marble,
		Board = Materials.Floor.Marble,
		Surround = marble,
		Lintel = marble,
	}
	local plain: Openings.WindowStyle = {
		Frame = Materials.Frame.Bronze,
		Glass = Materials.Glass.Window,
		Sill = marble,
		Board = Materials.Floor.Marble,
	}
	local portal: Openings.DoorStyle = {
		Leaf = Materials.Metal.Bronze,
		Frame = Kit.Style.Bronze,
		Handle = Materials.Metal.Brass,
		Glass = Materials.Glass.Shop,
		KickPlate = Materials.Metal.Brass,
	}
	local service: Openings.DoorStyle = {
		Leaf = Materials.Wood.Walnut,
		Frame = Kit.Style.Bronze,
		Handle = Materials.Metal.Brass,
		Glass = Materials.Glass.Window,
	}
	local all = { 0, 1, 2 }
	local wings = Shell.steps(-118, 10, -48)
	for _, x in Shell.steps(48, 10, 118) do
		table.insert(wings, x)
	end
	local centre = Shell.steps(-28, 14, 28)
	local sideWindows = { -425, -415.5, -403, -390.5, -378, -365.5, -353, -340.5, -328 }
	local northWindows = Shell.steps(-117, 13, 117)
	local runs: { Shell.Run } = {
		{
			Name = "Wall",
			Axis = "X",
			At = b.MaxZ - t / 2,
			From = b.MinX,
			To = b.MaxX,
			Thickness = t,
			Out = 1,
			Material = stone,
			Window = grand,
			Door = portal,
			Windows = {
				{ Centres = wings, Width = 4.4, Height = 8, Sill = 3.5, Storeys = all },
				{ Centres = centre, Width = 4.4, Height = 8, Sill = 3.5, Storeys = { 1 } },
				-- Under the portico ceiling: lower windows of the press room.
				{ Centres = centre, Width = 4.4, Height = 5, Sill = 1.5, Storeys = { 2 } },
			},
			Doors = {
				{ At = -14, Width = 8, Height = 16, Storey = 0, Double = true, StartOpen = true, Label = "Portal" },
				{ At = 0, Width = 8, Height = 16, Storey = 0, Double = true, StartOpen = true, Label = "Portal" },
				{ At = 14, Width = 8, Height = 16, Storey = 0, Double = true, StartOpen = true, Label = "Portal" },
			},
		},
		{
			Name = "Wall",
			Axis = "X",
			At = b.MinZ + t / 2,
			From = b.MinX,
			To = b.MaxX,
			Thickness = t,
			Out = -1,
			Material = stone,
			Window = plain,
			Door = service,
			Windows = {
				{
					Centres = Shell.without(northWindows, { { -6, 6 } }),
					Width = 4.4,
					Height = 8,
					Sill = 3.5,
					Storeys = { 0 },
				},
				{ Centres = northWindows, Width = 4.4, Height = 8, Sill = 3.5, Storeys = { 1, 2 } },
			},
			Doors = { { At = 0, Width = 8, Height = 12, Storey = 0, Double = true, Label = "Back Entrance" } },
		},
	}
	for _, side in { -1, 1 } do
		table.insert(runs, {
			Name = "Wall",
			Axis = "Z",
			At = (if side < 0 then b.MinX else b.MaxX) - side * t / 2,
			From = b.MinZ + t,
			To = b.MaxZ - t,
			Thickness = t,
			Out = side,
			Material = stone,
			Window = plain,
			Windows = { { Centres = sideWindows, Width = 4.4, Height = 8, Sill = 3.5, Storeys = all } },
		})
	end
	local shell = Shell.build(plan, facade, runs)
	report.Windows = shell.Windows
	model:SetAttribute("WindowsWithoutRoom", shell.Unmapped)
	model:SetAttribute("WindowsBlocked", shell.Blocked)
	Util.yield()

	-- The interior: partitions, doors, floors, stairs, lights and furniture.
	local interior = Plan.build(plan, Rooms.furnish)
	for key, value in interior do
		report[key] = value
	end
	Util.yield()

	-- Facade: string courses, cornice band, gravel roof behind the parapet, rooftop plant.
	for level = 1, c.Storeys - 1 do
		local y = P + level * H
		Kit.band(model, "StringCourse", b, y - 0.4, y + 0.6, 0.5, marble, {
			{ Side = "South", From = -20, To = 20 }, -- over the portal doors
		})
	end
	Kit.band(model, "Cornice", inner, R, R + 1.6, t + 1.8, marble)
	Kit.slab(model, "RoofGravel", Kit.inset(inner, 0.5), R, R + 0.3, Materials.Roof.Gravel)
	Kit.parapet(model, Kit.inset(b, -0.6), R + 1.6, 3.2, stone)
	rooftop(model, R + 0.3)

	-- Portico: eight columns, entablature with the inscription, pediment with the emblem.
	local porticoFront = c.Forecourt.MinZ - 2
	for i = 0, 7 do
		Kit.column(model, -42 + i * 12, porticoFront - 2.6, P, P + 36, 4.4, marble)
	end
	local entablature = Kit.box(model, "Entablature", -48, P + 36, b.MaxZ, 48, P + 40, porticoFront, marble)
	Kit.inscription(entablature, { "GENERAL PEOPLE'S CONGRESS" }, Color3.fromRGB(150, 120, 60), Enum.NormalId.Back)
	Kit.slab(model, "PorticoCeiling", Kit.rect(-48, 48, b.MaxZ, porticoFront), P + 35.4, P + 36, marble)
	local front: Kit.Face = { Axis = "Z", At = b.MaxZ, Out = 1 }
	Kit.pediment(model, front, -49, 49, P + 40, 12, 0, porticoFront - b.MaxZ, stone)
	Kit.emblem(model, { Axis = "Z", At = porticoFront, Out = 1 }, 0, P + 44.4, 7, 0.05)
	for _, x in { -30, 30 } do
		Kit.ceilingLight(model, x, (b.MaxZ + porticoFront) / 2, P + 35.4, 3, 30)
	end

	-- Dome over the chamber: stylobate, ring of columns, drum, copper dome, lantern and flag.
	local room = c.Chamber
	local cz = (room.MinZ + room.MaxZ) / 2
	local roofTop = R + 1.6
	local d = c.DomeDiameter
	Kit.drum(model, "Stylobate", 0, cz, R + 0.3, roofTop + 1, d + 12, granite)
	Kit.drum(model, "Drum", 0, cz, roofTop + 1, roofTop + 21, d + 2, stone)
	for k = 0, 15 do
		local a = k * math.pi / 8
		Kit.column(
			model,
			math.cos(a) * (d / 2 + 4.2),
			cz + math.sin(a) * (d / 2 + 4.2),
			roofTop + 1,
			roofTop + 19,
			2.4,
			marble
		)
	end
	Kit.drum(model, "DrumCornice", 0, cz, roofTop + 19, roofTop + 21, d + 11, marble)
	local domeBase = roofTop + 21
	Kit.ellipsoid(model, "Dome", Vector3.new(0, domeBase, cz), Vector3.new(d, 42, d), Kit.Style.Copper)
	local crown = domeBase + 21
	Kit.drum(model, "Lantern", 0, cz, crown - 2, crown + 6, 8, stone)
	Kit.ellipsoid(model, "LanternDome", Vector3.new(0, crown + 6, cz), Vector3.new(8, 6, 8), Kit.Style.Copper)
	Kit.flagpole(model, Vector3.new(0, crown + 8.5, cz), 14, 9, Vector3.new(1, 0, 0))
	model:SetAttribute("Height", crown + 22.5 - G)
	return report
end

return Congress
