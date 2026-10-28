--!strict
-- The Hausali, the government headquarters (lore: "great house"), on the east side of the square,
-- facing west. Administrative style, clearly different from the Congress: white plaster, ochre
-- bands and corner pilasters, green shutters and a red clay tile roof. A central risalit carries
-- the portal, the speaker's balcony, the name and the national emblem. A walled garden lies
-- behind.
--
-- Inside (Architecture.Plan) a classic three-tract office building on three storeys: offices
-- along the front and the back, two corridors, and a core between them with the main stair, a
-- second stair, two lifts, washrooms, kitchens, archives and meeting rooms; cross corridors and
-- strips of rooms at the north and south ends. The entrance lobby lies behind the portal; above
-- it the State Room opens onto the balcony and the Cabinet Room takes the top floor. The
-- Secretary-General of the People's Committee and the four Secretariats (lore bible, section 5)
-- have their offices here. Every window opens into a room.

local Kit = require(script.Parent.Kit)
local Architecture = script.Parent.Parent.Architecture
local Util = require(script.Parent.Parent.Map.Builders.Util)
local Parts = require(Architecture.Parts)
local Materials = require(Architecture.Materials)
local Openings = require(Architecture.Openings)
local Plan = require(Architecture.Plan)
local Shell = require(Architecture.Shell)
local Rooms = require(Architecture.Rooms)
local Furniture = require(Architecture.Furniture)
local Exterior = require(Architecture.Exterior)

type Space = Plan.Space
type Room = Rooms.Room

local Hausali = {}

local SHUTTERS: Kit.Options = { Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(52, 92, 64) }
local DOOR_Z = -160 -- centre of the portal

type Entry = { Name: string, Kind: string, Gender: ("Men" | "Women" | "Accessible")? }
local function e(name: string, kind: string, gender: ("Men" | "Women" | "Accessible")?): Entry
	return { Name = name, Kind = kind, Gender = gender }
end

-- Rooms per storey. Splits are the partitions (window bays are 9 studs, centred on the portal).
type Storey = {
	North: { Entry }, -- north strip, west to east
	NorthSplits: { number },
	West: { Entry }, -- front offices, north to south (without the lobby bay)
	WestSplits: { number },
	East: { Entry }, -- back offices, north to south
	South: { Entry }, -- south strip, west to east
	Core: { Entry }, -- between the corridors, north to south (without stairs and lifts)
	Bay: Entry, -- behind the portal
}
local NORTH_4 = { 198, 218, 236, 254, 274 }
local WEST_8 = { -241, -223, -205, -187, -176, -144, -133, -115, -97, -79 }
local EAST = { -241, -223, -205, -187, -169, -151, -133, -115, -97, -79 }
local SOUTH = { 198, 218, 236, 254, 274 }
-- Core rooms (z ranges) around the main stair (-176..-160) and the lifts (-160..-152).
local CORE = {
	{ -225, -215 },
	{ -215, -205 },
	{ -205, -193 },
	{ -193, -176 },
	{ -152, -142 },
	{ -142, -130 },
	{ -130, -106 },
	{ -106, -96 },
	{ -96, -86 },
	{ -86, -79 },
}

local PROGRAMME: { Storey } = {
	{
		North = { e("Post Room", "Post"), e("Security Control", "Security"), e("Staff Cafeteria", "Cafeteria") },
		NorthSplits = { 198, 218, 236, 274 },
		West = {
			e("Citizens' Office", "Waiting"),
			e("Registry", "SharedOffice"),
			e("Press Office", "Office"),
			e("Guard Room", "Security"),
			e("First Aid", "FirstAid"),
			e("Conference Room", "Meeting"),
			e("Visitors' Office", "Office"),
			e("IT Helpdesk", "SharedOffice"),
		},
		WestSplits = WEST_8,
		East = {
			e("Personnel Office", "Office"),
			e("Accounts", "SharedOffice"),
			e("Procurement", "SharedOffice"),
			e("Translation Service", "SharedOffice"),
			e("Garden Entrance", "Lobby"),
			e("Legal Department", "Office"),
			e("Archive Reading Room", "Library"),
			e("Staff Room", "Lounge"),
			e("Print Shop", "Copy"),
		},
		South = {
			e("Drivers' Room", "Lounge"),
			e("Storage", "Storage"),
			e("Kitchen", "Kitchen"),
			e("Garden Room", "Garden"),
		},
		Core = {
			e("WC Men", "WC", "Men"),
			e("WC Women", "WC", "Women"),
			e("Archive", "Archive"),
			e("Staff Kitchen", "Pantry"),
			e("Copy Room", "Copy"),
			e("Server Room", "Server"),
			e("Interview Room", "Meeting"),
			e("WC Women", "WC", "Women"),
			e("WC Men", "WC", "Men"),
			e("Janitor", "Janitor"),
		},
		Bay = e("Entrance Lobby", "Lobby"),
	},
	{
		North = {
			e("Cabinet Secretariat", "SharedOffice"),
			e("Records", "Archive"),
			e("Secretary, Internal Affairs and Infrastructure", "Executive"),
			e("Internal Affairs", "SharedOffice"),
		},
		NorthSplits = NORTH_4,
		West = {
			e("Infrastructure Office", "SharedOffice"),
			e("Office of the Secretary-General", "Reception"),
			e("Secretary-General of the People's Committee", "Executive"),
			e("Protocol", "Office"),
			e("Secretary, Defence and Foreign Affairs", "Executive"),
			e("Foreign Affairs", "SharedOffice"),
			e("Defence Office", "SharedOffice"),
		},
		WestSplits = { -241, -223, -205, -176, -144, -133, -115, -97, -79 },
		East = {
			e("Police Liaison", "Office"),
			e("Justice Department", "SharedOffice"),
			e("Municipal Affairs", "SharedOffice"),
			e("Briefing Room", "Meeting"),
			e("Situation Room", "Board"),
			e("Gendarmerie Liaison", "Office"),
			e("Treaties Office", "Office"),
			e("Consular Affairs", "SharedOffice"),
			e("Duty Officer", "Office"),
		},
		South = {
			e("Secretariat Lounge", "Lounge"),
			e("Storage", "Storage"),
			e("Tea Kitchen", "Pantry"),
			e("Interview Room", "Meeting"),
		},
		Core = {
			e("WC Men", "WC", "Men"),
			e("WC Women", "WC", "Women"),
			e("Storage", "Storage"),
			e("Tea Kitchen", "Pantry"),
			e("Copy Room", "Copy"),
			e("Registry", "Archive"),
			e("Secretariat Meeting Room", "Meeting"),
			e("WC Women", "WC", "Women"),
			e("WC Men", "WC", "Men"),
			e("Janitor", "Janitor"),
		},
		Bay = e("State Room", "Salon"),
	},
	{
		North = {
			e("Secretary, Economy and Education", "Executive"),
			e("Budget Office", "SharedOffice"),
			e("Economy Office", "SharedOffice"),
			e("Education Office", "SharedOffice"),
		},
		NorthSplits = NORTH_4,
		West = {
			e("Statistics Office", "SharedOffice"),
			e("Finance Planning", "Office"),
			e("Central Bank Liaison", "Office"),
			e("Cabinet Clerk", "Office"),
			e("Cabinet Archive", "Archive"),
			e("Secretary, Health and Crisis Management", "Executive"),
			e("Health Office", "SharedOffice"),
			e("Crisis Management", "SharedOffice"),
		},
		WestSplits = WEST_8,
		East = {
			e("Schools Office", "Office"),
			e("Universities Office", "Office"),
			e("Trade Office", "SharedOffice"),
			e("Conference Room", "Board"),
			e("Emergency Coordination", "SharedOffice"),
			e("Medical Services", "Office"),
			e("Disaster Planning", "Office"),
			e("Health Statistics", "SharedOffice"),
			e("Duty Officer", "Office"),
		},
		South = {
			e("Library", "Library"),
			e("Storage", "Storage"),
			e("Tea Kitchen", "Pantry"),
			e("Meeting Room", "Meeting"),
		},
		Core = {
			e("WC Women", "WC", "Women"),
			e("WC Men", "WC", "Men"),
			e("Storage", "Storage"),
			e("Tea Kitchen", "Pantry"),
			e("Copy Room", "Copy"),
			e("Server Room", "Server"),
			e("Cabinet Secretariat", "Board"),
			e("Accessible WC", "WC", "Accessible"),
			e("WC Men", "WC", "Men"),
			e("Janitor", "Janitor"),
		},
		Bay = e("Cabinet Room", "Cabinet"),
	},
}

-- The entrance lobby (custom furnishing): a carpet runner from the portal, a security gate, the
-- reception desk before a panelled screen with the emblem and two flags, benches, the directory
-- and plants.
local function lobby(room: Room, report: { [string]: number })
	local folder = room.Folder
	local y = room.Floor
	local r = room.Space.Rect
	local minZ, maxZ = r.MinZ + Plan.Partition / 2, r.MaxZ - Plan.Partition / 2
	Kit.slab(folder, "Runner", Kit.rect(r.MinX, 208, DOOR_Z - 3, DOOR_Z + 3), y, y + 0.1, Kit.Style.Carpet)
	local steel = Materials.Metal.Steel
	Kit.box(folder, "SecurityGate", 200.5, y, DOOR_Z - 2.2, 201.1, y + 7.4, DOOR_Z - 1.8, steel)
	Kit.box(folder, "SecurityGate", 200.5, y, DOOR_Z + 1.8, 201.1, y + 7.4, DOOR_Z + 2.2, steel)
	Kit.box(folder, "SecurityGate", 200.5, y + 7.4, DOOR_Z - 2.2, 201.1, y + 8, DOOR_Z + 2.2, steel)
	local desk = Vector3.new(210.5, y, DOOR_Z)
	Furniture.counter(
		folder,
		CFrame.lookAt(desk, desk - Vector3.new(1, 0, 0)),
		12,
		2.6,
		Materials.Wood.Walnut,
		Kit.Style.Marble
	)
	for _, dz in { -3, 3 } do
		local chair = desk + Vector3.new(2.4, 0, dz)
		Furniture.officeChair(folder, CFrame.lookAt(chair, chair - Vector3.new(1, 0, 0)), Materials.Leather.Black)
		Furniture.computer(folder, CFrame.lookAt(desk + Vector3.new(0.4, 0, dz), desk + Vector3.new(-0.6, 0, dz)), 3.6)
	end
	Kit.box(folder, "ScreenWall", 214.4, y, DOOR_Z - 8, 215, y + 9.5, DOOR_Z + 8, Materials.Wall.Panel)
	Kit.emblem(folder, { Axis = "X", At = 214.4, Out = -1 }, DOOR_Z, y + 6.4, 4.5, 0.15)
	for _, z in { DOOR_Z - 6.5, DOOR_Z + 6.5 } do
		Kit.flagpole(folder, Vector3.new(213.2, y, z), 10, 3.2, Vector3.new(-0.4, 0, if z < DOOR_Z then -1 else 1))
		report.Flags += 1
	end
	for _, x in { 197, 205 } do
		for _, z in { minZ + 1, maxZ - 1 } do
			local p = Vector3.new(x, y, z)
			Furniture.bench(
				folder,
				CFrame.lookAt(p, p + Vector3.new(0, 0, if z < DOOR_Z then 1 else -1)),
				6,
				Materials.Wood.Walnut
			)
		end
	end
	local plaque = Kit.box(folder, "Directory", 209, y + 4, minZ, 213, y + 8, minZ + 0.2, Kit.Style.Bronze)
	Kit.inscription(
		plaque,
		{ "HAUSALI", "Government Headquarters", "People's Committee" },
		Color3.fromRGB(240, 220, 170),
		Enum.NormalId.Back
	)
	for _, z in { minZ + 1.4, maxZ - 1.4 } do
		Furniture.plant(folder, Vector3.new(216.4, y, z), 6.5, math.floor(z))
	end
end

local function spaces(report: { [string]: number }): { Space }
	local list: { Space } = {}
	local function add(space: Space)
		table.insert(list, space)
	end
	local function room(entry: Entry, rect: Plan.Rect, storey: number): Space
		return {
			Name = entry.Name,
			Kind = entry.Kind,
			Gender = entry.Gender,
			Rect = rect,
			Storey = storey,
			Open = if entry.Kind == "Lobby" then true else nil,
		}
	end
	add({
		Name = "Main Stair",
		Kind = "Stair",
		Rect = Plan.rect(226, 246, -176, -160),
		Storey = 0,
		Top = 2,
		Entry = "MinX",
		Grand = true,
	})
	add({ Name = "Stair", Kind = "Stair", Rect = Plan.rect(226, 246, -241, -225), Storey = 0, Top = 2, Entry = "MinX" })
	add({ Name = "Lift", Kind = "Lift", Rect = Plan.rect(226, 236, -160, -152), Storey = 0, Top = 2 })
	add({ Name = "Lift", Kind = "Lift", Rect = Plan.rect(236, 246, -160, -152), Storey = 0, Top = 2 })
	for s = 0, 2 do
		local p = PROGRAMME[s + 1]
		add({ Name = "North Corridor", Kind = "Corridor", Rect = Plan.rect(198, 274, -250, -241), Storey = s })
		add({ Name = "West Corridor", Kind = "Corridor", Rect = Plan.rect(218, 226, -241, -79), Storey = s })
		add({ Name = "East Corridor", Kind = "Corridor", Rect = Plan.rect(246, 254, -241, -79), Storey = s })
		add({ Name = "South Corridor", Kind = "Corridor", Rect = Plan.rect(198, 274, -79, -70), Storey = s })
		for i, entry in p.North do
			add(room(entry, Plan.rect(p.NorthSplits[i], p.NorthSplits[i + 1], -270, -250), s))
		end
		-- The front tract, with the bay behind the portal reaching into the risalit.
		local bay = room(p.Bay, Plan.rect(190, 218, -176, -144), s)
		if s == 0 then
			bay.Custom = function(r: Room)
				lobby(r, report)
			end
		end
		add(bay)
		local k = 0
		for i = 1, #p.WestSplits - 1 do
			local z0, z1 = p.WestSplits[i], p.WestSplits[i + 1]
			if z0 == -176 then
				continue -- the bay
			end
			k += 1
			add(room(p.West[k], Plan.rect(198, 218, z0, z1), s))
		end
		for i, entry in p.East do
			add(room(entry, Plan.rect(254, 274, EAST[i], EAST[i + 1]), s))
		end
		for i, entry in p.Core do
			add(room(entry, Plan.rect(226, 246, CORE[i][1], CORE[i][2]), s))
		end
		for i, entry in p.South do
			add(room(entry, Plan.rect(SOUTH[i], SOUTH[i + 1], -70, -50), s))
		end
	end
	return list
end

function Hausali.build(district: any, parent: Instance): { [string]: number }
	local h = district.Hausali
	local model = Kit.model(parent, "Hausali", "Hausali")
	local G = district.GroundY
	local W = G + district.WalkTop
	local F = W + 1.6 -- ground floor on a low stone plinth
	local H = h.StoreyHeight
	local R = F + H * h.Storeys -- eaves
	local b = h.Body
	local en = h.Entrance
	local doorZ = (en.MinZ + en.MaxZ) / 2
	assert(doorZ == DOOR_Z, "Hausali: the plan expects the portal at z -160")
	local plaster = Materials.Wall.White
	local ochre = Materials.Wall.Ochre
	local granite = Kit.Style.Granite
	local report: { [string]: number } = { Windows = 0, Flags = 0 }

	-- Grounds from the East Street sidewalk to the back of the plot, plinth and entrance steps.
	Kit.slab(model, "Grounds", Kit.rect(185, h.Rect.MaxX, h.Rect.MinZ, h.Rect.MaxZ), G - 0.6, W, Kit.Style.Paving)
	Kit.slab(model, "Plinth", Kit.inset(b, -0.8), W - 0.2, F, granite)
	Kit.slab(model, "Plinth", Kit.rect(en.MinX - 0.8, b.MinX, en.MinZ - 0.8, en.MaxZ + 0.8), W - 0.2, F, granite)
	Kit.box(model, "Step", en.MinX - 2.6, W - 0.2, doorZ - 6, en.MinX - 0.8, W + 0.8, doorZ + 6, granite)

	-- The plan of the interior: the main block and the risalit (with the passage through the
	-- main wall).
	local t = 2
	local inner = Kit.inset(b, t)
	local plan = Plan.new({
		Model = model,
		Building = "Hausali",
		Footprints = { inner, Plan.rect(en.MinX + t, b.MinX + t, en.MinZ + t, en.MaxZ - t) },
		Levels = { F, F + H, F + 2 * H, R },
		Spaces = spaces(report),
		Style = {
			Partition = Materials.Wall.White,
			Door = { Leaf = Materials.Wood.Oak, Frame = Materials.Frame.White, Handle = Materials.Metal.Chrome },
			GlassDoor = {
				Leaf = Materials.Wood.Oak,
				Frame = Materials.Frame.White,
				Handle = Materials.Metal.Chrome,
				Glass = Materials.Glass.Interior,
			},
			Plate = Materials.Plastic.White,
			Ink = Color3.fromRGB(30, 52, 40),
			Stair = {
				Tread = Materials.Floor.Terrazzo,
				Landing = Materials.Floor.Terrazzo,
				Spine = Materials.Wall.White,
				Rail = Materials.Metal.Iron,
			},
			Floors = { Corridor = Materials.Floor.Terrazzo, Lobby = Materials.Floor.Marble },
			Accent = Materials.Wall.Sage,
		},
		Seed = 2,
	})

	-- Facades: plaster walls with shuttered windows in ochre surrounds.
	local facade = Kit.folder(model, "Facade")
	local window: Openings.WindowStyle = {
		Frame = Materials.Frame.White,
		Glass = Materials.Glass.Window,
		Sill = Kit.Style.Limestone,
		Board = Materials.Wood.White,
		Surround = ochre,
		Shutters = SHUTTERS,
	}
	local doorStyle: Openings.DoorStyle = {
		Leaf = Materials.Wood.Walnut,
		Frame = Materials.Frame.Brown,
		Handle = Materials.Metal.Brass,
		Glass = Materials.Glass.Window,
	}
	local all = { 0, 1, 2 }
	local risalitDoors: { Shell.DoorSpec } = {
		{ At = doorZ, Width = 6, Height = 11, Storey = 0, Double = true, StartOpen = true, Label = "Portal" },
		{ At = doorZ, Width = 6, Height = 9, Storey = 1, Double = true, Label = "Balcony" },
	}
	local bays = Shell.steps(-263.5, 9, -56.5) -- along Z, centred on the portal
	local across = Shell.steps(204.5, 9, 267.5) -- along X
	local runs: { Shell.Run } = {
		{
			Axis = "X",
			At = b.MinZ + t / 2,
			From = b.MinX,
			To = b.MaxX,
			Thickness = t,
			Out = -1,
			Material = plaster,
			Window = window,
			Windows = { { Centres = across, Width = 3.6, Height = 7, Sill = 3, Storeys = all } },
		},
		{
			Axis = "X",
			At = b.MaxZ - t / 2,
			From = b.MinX,
			To = b.MaxX,
			Thickness = t,
			Out = 1,
			Material = plaster,
			Window = window,
			Windows = { { Centres = across, Width = 3.6, Height = 7, Sill = 3, Storeys = all } },
		},
		{
			Axis = "Z",
			At = b.MinX + t / 2,
			From = b.MinZ + t,
			To = b.MaxZ - t,
			Thickness = t,
			Out = -1,
			Material = plaster,
			Window = window,
			Windows = {
				{
					Centres = Shell.without(bays, { { en.MinZ, en.MaxZ } }),
					Width = 3.6,
					Height = 7,
					Sill = 3,
					Storeys = all,
				},
			},
			Passages = {
				{ From = en.MinZ + t, To = en.MaxZ - t, Storey = 0 },
				{ From = en.MinZ + t, To = en.MaxZ - t, Storey = 1 },
				{ From = en.MinZ + t, To = en.MaxZ - t, Storey = 2 },
			},
		},
		{
			Axis = "Z",
			At = b.MaxX - t / 2,
			From = b.MinZ + t,
			To = b.MaxZ - t,
			Thickness = t,
			Out = 1,
			Material = plaster,
			Window = window,
			Door = doorStyle,
			Windows = {
				{
					Centres = Shell.without(bays, { { -166, -154 } }),
					Width = 3.6,
					Height = 7,
					Sill = 3,
					Storeys = { 0 },
				},
				{ Centres = bays, Width = 3.6, Height = 7, Sill = 3, Storeys = { 1, 2 } },
			},
			Doors = { { At = doorZ, Width = 6, Height = 9, Storey = 0, Double = true, Label = "Garden" } },
		},
		-- The risalit: portal, balcony door and the windows of the lobby, State and Cabinet Rooms.
		{
			Name = "RisalitWall",
			Axis = "Z",
			At = en.MinX + t / 2,
			From = en.MinZ,
			To = en.MaxZ,
			Thickness = t,
			Out = -1,
			Material = plaster,
			Window = window,
			Door = doorStyle,
			Top = R + 3,
			Windows = {
				{ Centres = { doorZ - 10, doorZ + 10 }, Width = 3.6, Height = 7, Sill = 3, Storeys = all },
				{ Centres = { doorZ }, Width = 3.6, Height = 7, Sill = 3, Storeys = { 2 } },
			},
			Doors = risalitDoors,
		},
	}
	for _, side in { -1, 1 } do
		table.insert(runs, {
			Name = "RisalitWall",
			Axis = "X",
			At = (if side < 0 then en.MinZ else en.MaxZ) - side * t / 2,
			From = en.MinX + t,
			To = b.MinX,
			Thickness = t,
			Out = side,
			Material = plaster,
			Window = window,
			Top = R + 3,
		})
	end
	local shell = Shell.build(plan, facade, runs)
	report.Windows = shell.Windows
	model:SetAttribute("WindowsWithoutRoom", shell.Unmapped)
	model:SetAttribute("WindowsBlocked", shell.Blocked)
	Util.yield()
	local interior = Plan.build(plan, Rooms.furnish)
	for key, value in interior do
		report[key] = value
	end
	Util.yield()

	-- Above the eaves the risalit reaches back into the roof, so its cross gable meets the slope.
	local top = R + 3
	Kit.box(model, "RisalitWall", b.MinX, R, en.MinZ, b.MinX + 8, top, en.MaxZ, plaster)

	-- Roof: red clay tile gable roof along the block over the eaves band, gable ends, cross gable
	-- over the risalit with the emblem and the name, chimneys, gutters and downpipes.
	Kit.band(model, "Eaves", b, R - 0.8, R, 1, ochre, { { Side = "West", From = en.MinZ, To = en.MaxZ } })
	local roofHeight = 14
	local tiles = Materials.Roof.ClayTiles
	Kit.gableRoof(model, b, R, roofHeight, "Z", 1.5, tiles)
	local gable = roofHeight * ((b.MaxX - b.MinX) / 2) / ((b.MaxX - b.MinX) / 2 + 1.5)
	Kit.pediment(model, { Axis = "Z", At = b.MinZ, Out = -1 }, b.MinX, b.MaxX, R, gable, -t, 1.55, plaster)
	Kit.pediment(model, { Axis = "Z", At = b.MaxZ, Out = 1 }, b.MinX, b.MaxX, R, gable, -t, 1.55, plaster)
	Kit.slab(model, "RisalitTop", Kit.rect(en.MinX, b.MinX, en.MinZ, en.MaxZ), top - 1, top, plaster)
	Kit.gableRoof(model, Kit.rect(en.MinX, b.MinX + 12, en.MinZ, en.MaxZ), top, 8, "X", 1, tiles)
	local front: Kit.Face = { Axis = "X", At = en.MinX, Out = -1 }
	Kit.pediment(model, front, en.MinZ, en.MaxZ, top, 8 * 18 / 19, -t, 1.05, plaster)
	Kit.emblem(model, front, doorZ, top + 3, 4.5, 0.1)
	local frieze = Kit.faceBox(model, "Frieze", front, en.MinZ + 3, en.MaxZ - 3, R - 0.4, R + 2.6, 0, 0.3, ochre)
	Kit.inscription(frieze, { "HAUSALI" }, Color3.fromRGB(255, 255, 255), Enum.NormalId.Left)
	Kit.flagpole(model, Vector3.new(en.MinX + 1, top + 8 * 18 / 19, doorZ), 10, 6, Vector3.new(0, 0, 1))
	report.Flags += 1
	for _, z in { b.MinZ + 40, b.MaxZ - 40 } do
		Kit.box(model, "Chimney", 250, R + 6, z - 2, 256, R + roofHeight + 3, z + 2, plaster)
		Kit.box(
			model,
			"ChimneyCap",
			249.6,
			R + roofHeight + 3,
			z - 2.4,
			256.4,
			R + roofHeight + 3.5,
			z + 2.4,
			Kit.Style.Granite
		)
	end
	local eaveW, eaveE = b.MinX - 1.5, b.MaxX + 1.5
	Exterior.gutter(model, "Z", eaveW, b.MinZ - 1.5, en.MinZ - 0.5, R, -1)
	Exterior.gutter(model, "Z", eaveW, en.MaxZ + 0.5, b.MaxZ + 1.5, R, -1)
	Exterior.gutter(model, "Z", eaveE, b.MinZ - 1.5, b.MaxZ + 1.5, R, 1)
	for _, z in { b.MinZ + 3, b.MaxZ - 3 } do
		Exterior.downpipe(model, b.MinX, z, Vector3.new(-1, 0, 0), R, F, 1)
		Exterior.downpipe(model, b.MaxX, z, Vector3.new(1, 0, 0), R, F, 1)
	end

	-- Facade: ochre bands and pilasters, portal surround and speaker's balcony.
	for level = 1, h.Storeys - 1 do
		local y = F + level * H
		Kit.band(model, "Band", b, y - 0.3, y + 0.5, 0.4, ochre, {
			{ Side = "West", From = en.MinZ, To = en.MaxZ },
		})
		Kit.box(model, "Band", en.MinX - 0.4, y - 0.3, en.MinZ - 0.4, b.MinX, y + 0.5, en.MaxZ + 0.4, ochre)
	end
	for _, corner in { { b.MinX, b.MinZ }, { b.MinX, b.MaxZ }, { b.MaxX, b.MinZ }, { b.MaxX, b.MaxZ } } do
		local x, z = corner[1], corner[2]
		Kit.box(model, "Pilaster", x - 1.6, F, z - 1.6, x + 1.6, R - 0.8, z + 1.6, ochre)
	end
	for _, z in { en.MinZ, en.MaxZ } do
		Kit.box(model, "Pilaster", en.MinX - 0.6, F, z - 1.4, en.MinX + 2.2, top, z + 1.4, ochre)
	end
	Kit.faceBox(model, "PortalSurround", front, doorZ - 4.4, doorZ - 3.4, F, F + 11.4, 0, 0.5, ochre)
	Kit.faceBox(model, "PortalSurround", front, doorZ + 3.4, doorZ + 4.4, F, F + 11.4, 0, 0.5, ochre)
	Kit.faceBox(model, "PortalSurround", front, doorZ - 4.4, doorZ + 4.4, F + 11.4, F + 12.4, 0, 0.5, ochre)
	Kit.faceBox(model, "Keystone", front, doorZ - 0.8, doorZ + 0.8, F + 11, F + 13, 0, 0.7, Kit.Style.Marble)
	local sign =
		Kit.faceBox(model, "NamePlaque", front, doorZ + 5.4, doorZ + 7.6, F + 3.5, F + 6.5, 0, 0.15, Kit.Style.Bronze)
	Kit.inscription(
		sign,
		{ "HAUSALI", "GOVERNMENT", "HEADQUARTERS" },
		Color3.fromRGB(240, 220, 170),
		Enum.NormalId.Left
	)
	-- Speaker's balcony in front of the State Room (addresses to the square), on two consoles; its
	-- floor is level with the room.
	local by = F + H - 0.5
	Kit.faceBox(model, "Balcony", front, doorZ - 8, doorZ + 8, by, by + 0.6, 0, 2.6, Kit.Style.Marble)
	Kit.faceBox(model, "Balustrade", front, doorZ - 8, doorZ + 8, by + 0.6, by + 3.6, 2.2, 2.6, Kit.Style.Marble)
	Kit.faceBox(model, "Balustrade", front, doorZ - 8, doorZ - 7.6, by + 0.6, by + 3.6, 0, 2.2, Kit.Style.Marble)
	Kit.faceBox(model, "Balustrade", front, doorZ + 7.6, doorZ + 8, by + 0.6, by + 3.6, 0, 2.2, Kit.Style.Marble)
	for _, z in { doorZ - 6, doorZ + 6 } do
		Kit.faceBox(model, "Console", front, z - 0.6, z + 0.6, by - 2.4, by, 0, 2, Kit.Style.Marble)
	end
	-- Split air conditioners under some windows of the back and the ends (not on the front).
	local east: Openings.Wall = { Axis = "Z", At = b.MaxX - t / 2, Thickness = t, Out = 1 }
	local north: Openings.Wall = { Axis = "X", At = b.MinZ + t / 2, Thickness = t, Out = -1 }
	local south: Openings.Wall = { Axis = "X", At = b.MaxZ - t / 2, Thickness = t, Out = 1 }
	for _, unit in
		{
			{ 1, -227.5 },
			{ 1, -191.5 },
			{ 1, -128.5 },
			{ 2, -236.5 },
			{ 2, -173.5 },
			{ 2, -101.5 },
			{ 0, -218.5 },
			{ 0, -110.5 },
		}
	do
		Exterior.acUnit(model, east, unit[2], F + unit[1] * H + 0.5)
	end
	for _, unit in { { 1, 213.5 }, { 2, 258.5 } } do
		Exterior.acUnit(model, north, unit[2], F + unit[1] * H + 0.5)
		Exterior.acUnit(model, south, 472 - unit[2], F + unit[1] * H + 0.5)
	end
	-- Flags on both sides of the risalit.
	for _, z in { en.MinZ - 6, en.MaxZ + 6 } do
		Kit.flagpole(model, Vector3.new(187, W, z), 22, 7, Vector3.new(0, 0, if z < doorZ then -1 else 1))
		report.Flags += 1
	end

	-- Walled garden behind the building: lawn, hedges, a fountain, benches and trees.
	local garden = Kit.rect(b.MaxX + 4, h.Rect.MaxX - 4, b.MinZ, b.MaxZ)
	Kit.slab(model, "Lawn", garden, W, W + 0.15, Kit.Style.Lawn)
	Kit.planter(model, Kit.rect(garden.MaxX - 2, garden.MaxX, garden.MinZ, garden.MaxZ), W, 4)
	Kit.planter(model, Kit.rect(garden.MinX, garden.MaxX - 2, garden.MinZ, garden.MinZ + 2), W, 4)
	Kit.planter(model, Kit.rect(garden.MinX, garden.MaxX - 2, garden.MaxZ - 2, garden.MaxZ), W, 4)
	local fx, fz = (garden.MinX + garden.MaxX) / 2, doorZ
	Kit.slab(model, "Path", Kit.rect(b.MaxX, fx, fz - 2.5, fz + 2.5), W + 0.15, W + 0.2, Kit.Style.Paving)
	Kit.box(model, "GardenStep", b.MaxX + 0.8, W, fz - 3.5, b.MaxX + 2.4, F - 0.8, fz + 3.5, granite)
	Kit.drum(model, "FountainBasin", fx, fz, W, W + 1.8, 16, Kit.Style.Marble)
	Kit.drum(model, "FountainWater", fx, fz, W + 1.8, W + 1.9, 14.6, Kit.Style.Water)
	Kit.drum(model, "FountainColumn", fx, fz, W + 1.8, W + 5, 1.6, Kit.Style.Marble)
	Kit.drum(model, "FountainBowl", fx, fz, W + 5, W + 5.6, 5, Kit.Style.Marble)
	for _, d in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local p = Vector3.new(fx, W + 0.15, fz) + d * 13
		Kit.bench(model, p, -d)
	end
	local trees = 0
	for _, z in { garden.MinZ + 22, garden.MinZ + 60, garden.MaxZ - 60, garden.MaxZ - 22 } do
		for _, x in { garden.MinX + 18, garden.MaxX - 18 } do
			trees += 1
			Kit.tree(model, Vector3.new(x, W + 0.15, z), 22, 10 + trees)
		end
	end
	Parts.add(0)

	model:SetAttribute("Height", top + 8 - G)
	return report
end

return Hausali
