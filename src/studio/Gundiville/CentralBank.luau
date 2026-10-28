--!strict
-- The central bank on the west side of the square, facing east onto West Street. A solid block:
-- rusticated granite ground floor with barred windows, sandstone upper floor, a portico of six
-- columns with a pediment.
--
-- Inside (Architecture.Plan): the banking hall behind the portal, two storeys high under a
-- skylight, with the teller counter running across it, the round vault door in its back wall
-- and the staff area behind the counter; around it on two storeys the departments of the bank
-- (banknote issue, treasury accounts, banking supervision, monetary policy, research), the
-- counting room and the vault, the Governor's and the Deputy Governor's offices, the board room,
-- a stair and a lift. Every window opens into a room. Accounts and money stay in the Discord
-- economy bot; the bank interface follows in Milestone 4.

local Kit = require(script.Parent.Kit)
local Util = require(script.Parent.Parent.Map.Builders.Util)
local Architecture = script.Parent.Parent.Architecture
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

local CentralBank = {}

local STEEL: Kit.Options = { Material = Enum.Material.Metal, Color = Color3.fromRGB(150, 154, 160) }
local SCREEN: Kit.Options = {
	Material = Enum.Material.Glass,
	Color = Color3.fromRGB(200, 220, 230),
	Transparency = 0.6,
	CastShadow = false,
}
local DOOR_Z = -155
local SKYLIGHT = Plan.rect(-252, -212, -180, -130)

type Entry = { Name: string, Kind: string, Gender: ("Men" | "Women" | "Accessible")? }
local function e(name: string, kind: string, gender: ("Men" | "Women" | "Accessible")?): Entry
	return { Name = name, Kind = kind, Gender = gender }
end

-- The banking hall (custom furnishing): patterned stone floor, the counter with glass screens
-- across the hall, the staff area behind it, the vault door and the emblem on the back wall,
-- waiting benches and chandeliers.
local function hall(room: Room, report: { [string]: number })
	local folder = room.Folder
	local r = room.Space.Rect
	local y = room.Floor
	local ceiling = y + room.Height
	local half = Plan.Partition / 2
	local inner = Kit.rect(r.MinX + half, r.MaxX, r.MinZ + half, r.MaxZ - half)
	local public = Kit.rect(-238, inner.MaxX, inner.MinZ, inner.MaxZ)
	Kit.slab(
		folder,
		"FloorBorder",
		Kit.inset(public, 4),
		y,
		y + 0.04,
		Kit.with(Kit.Style.DarkGranite, { Decoration = true })
	)
	Kit.slab(
		folder,
		"FloorField",
		Kit.inset(public, 5),
		y + 0.04,
		y + 0.08,
		Kit.with(Kit.Style.Floor, { Decoration = true })
	)
	Kit.slab(folder, "Runner", Kit.rect(-236, inner.MaxX, DOOR_Z - 3, DOOR_Z + 3), y + 0.08, y + 0.18, Kit.Style.Carpet)

	-- Teller counter from wall to wall, glass screens with pass-through slots, one chair per
	-- teller.
	local cx = -240
	local z0, z1 = inner.MinZ, inner.MaxZ
	Kit.box(folder, "Counter", cx - 1.5, y, z0, cx + 1.5, y + 3.5, z1, Kit.Style.DarkWood)
	Kit.box(folder, "CounterTop", cx - 1.8, y + 3.5, z0, cx + 1.8, y + 3.8, z1, Kit.Style.Marble)
	local slots: { Kit.Opening } = {}
	for _, dz in { -24, -12, 0, 12, 24 } do
		local z = DOOR_Z + dz
		table.insert(slots, { From = z - 2, To = z + 2, Bottom = y + 3.8, Top = y + 5.3 })
		local chair = Instance.new("Seat")
		chair.Name = "TellerChair"
		chair.Anchored = true
		chair.Size = Vector3.new(2.2, 0.5, 2.2)
		chair.CFrame = CFrame.lookAt(Vector3.new(cx - 4.5, y + 1.5, z), Vector3.new(cx, y + 1.5, z))
		chair.Material = Enum.Material.Fabric
		chair.Color = Color3.fromRGB(40, 44, 52)
		chair.Parent = folder
		Kit.add(1)
		report.Tellers += 1
		Furniture.computer(
			folder,
			CFrame.lookAt(Vector3.new(cx - 1.2, y, z + 0.6), Vector3.new(cx - 2.2, y, z + 0.6)),
			3.8
		)
	end
	Kit.wall(folder, "Screen", "Z", z0, z1, cx + 0.5, 0.2, y + 3.8, y + 8, slots, SCREEN)
	local sign = Kit.box(
		folder,
		"CounterSign",
		cx + 0.6,
		y + 9,
		DOOR_Z - 14,
		cx + 0.8,
		y + 11.5,
		DOOR_Z + 14,
		Kit.Style.DarkWood
	)
	Kit.inscription(
		sign,
		{ "CENTRAL BANK", "KAGUNDI DINAR · KGD" },
		Color3.fromRGB(236, 206, 130),
		Enum.NormalId.Right
	)

	-- Staff area behind the counter: desks, filing cabinets, a safe.
	for i, z in { -188, -170, -140, -122 } do
		local p = Vector3.new(-254, y, z)
		local frame = CFrame.lookAt(p, p + Vector3.new(1, 0, 0))
		Furniture.desk(folder, frame, 5, 2.8, Materials.Wood.Walnut)
		Furniture.computer(folder, frame, 3.04, i % 2 == 0)
		Furniture.officeChair(folder, CFrame.lookAt(p - Vector3.new(2.6, 0, 0), p), Materials.Fabric.Charcoal)
	end
	for _, z in { -194, -116 } do
		local p = Vector3.new(-243.5, y, z)
		Furniture.cabinet(folder, CFrame.lookAt(p, p + Vector3.new(-1, 0, 0)), 4, 1.8, 4.4, Materials.Metal.Steel)
	end

	-- Vault door in the back wall, the emblem and flags above it.
	local back: Kit.Face = { Axis = "X", At = inner.MinX, Out = 1 }
	local vy = y + 7.2
	Kit.faceBox(folder, "VaultFrame", back, DOOR_Z - 7.5, DOOR_Z + 7.5, vy - 7, vy + 7.5, 0, 0.6, Kit.Style.DarkGranite)
	Util.cylinder(
		folder,
		"VaultDoor",
		Vector3.new(inner.MinX + 0.6, vy, DOOR_Z),
		Vector3.new(inner.MinX + 1.6, vy, DOOR_Z),
		12,
		STEEL
	)
	Util.cylinder(
		folder,
		"VaultWheel",
		Vector3.new(inner.MinX + 1.6, vy, DOOR_Z),
		Vector3.new(inner.MinX + 2.1, vy, DOOR_Z),
		3.6,
		STEEL
	)
	Kit.box(
		folder,
		"VaultSpoke",
		inner.MinX + 2.1,
		vy - 0.25,
		DOOR_Z - 3,
		inner.MinX + 2.5,
		vy + 0.25,
		DOOR_Z + 3,
		STEEL
	)
	Kit.box(
		folder,
		"VaultSpoke",
		inner.MinX + 2.1,
		vy - 3,
		DOOR_Z - 0.25,
		inner.MinX + 2.5,
		vy + 3,
		DOOR_Z + 0.25,
		STEEL
	)
	Kit.add(2)
	Kit.emblem(folder, back, DOOR_Z, y + 18.5, 6, 0.2)
	for _, dz in { -11, 11 } do
		Kit.flagpole(
			folder,
			Vector3.new(inner.MinX + 2.5, y, DOOR_Z + dz),
			14,
			4,
			Vector3.new(0.3, 0, if dz < 0 then -1 else 1)
		)
		report.Flags += 1
	end

	-- Waiting benches facing the counter, a clock and plants; chandeliers under the skylight.
	for _, x in { -226, -213 } do
		for _, dz in { -20, -10, 10, 20 } do
			local p = Vector3.new(x, y, DOOR_Z + dz)
			Furniture.bench(folder, CFrame.lookAt(p, p - Vector3.new(1, 0, 0)), 6, Materials.Wood.Walnut)
		end
	end
	for _, z in { inner.MinZ + 1.6, inner.MaxZ - 1.6 } do
		Furniture.plant(folder, Vector3.new(inner.MaxX - 1.8, y, z), 7, math.floor(z))
		Furniture.plant(folder, Vector3.new(-236, y, z), 6, math.floor(z) + 1)
	end
	local clockAt = Vector3.new(-230, y + 14, inner.MinZ)
	Furniture.clock(folder, CFrame.lookAt(clockAt, clockAt + Vector3.new(0, 0, 1)))
	for _, x in { -248, -222 } do
		for _, z in { DOOR_Z - 26, DOOR_Z + 26 } do
			Furniture.chandelier(folder, Vector3.new(x, ceiling, z), 10.2, 50)
		end
	end
end

local function spaces(report: { [string]: number }): { Space }
	local list: { Space } = {}
	local function add(space: Space)
		table.insert(list, space)
	end
	local function strip(entries: { Entry }, splits: { number }, z0: number, z1: number, s: number)
		for i, entry in entries do
			add({
				Name = entry.Name,
				Kind = entry.Kind,
				Gender = entry.Gender,
				Rect = Plan.rect(splits[i], splits[i + 1], z0, z1),
				Storey = s,
			})
		end
	end
	add({
		Name = "Banking Hall",
		Kind = "BankingHall",
		Rect = Plan.rect(-262, -200.5, -197, -113),
		Storey = 0,
		Top = 1,
		Floor = Materials.Floor.Marble,
		Lights = false,
		Custom = function(room: Room)
			hall(room, report)
		end,
		-- Staff doors from the corridors behind the counter; the public comes through the portal.
		Doors = { Plan.door("MinZ", -252), Plan.door("MaxZ", -252) },
	})
	add({
		Name = "Stair",
		Kind = "Stair",
		Rect = Plan.rect(-288, -262, -135, -113),
		Storey = 0,
		Top = 1,
		Entry = "MinX",
	})
	add({ Name = "Lift", Kind = "Lift", Rect = Plan.rect(-288, -279, -197, -189), Storey = 0, Top = 1 })
	local northSplits = { -319.5, -290, -266, -242, -218, -200.5 }
	local westSplits = { -197, -185, -161, -137, -113 }
	for s = 0, 1 do
		add({ Name = "North Corridor", Kind = "Corridor", Rect = Plan.rect(-319.5, -200.5, -209, -197), Storey = s })
		add({ Name = "South Corridor", Kind = "Corridor", Rect = Plan.rect(-319.5, -200.5, -113, -101), Storey = s })
		add({ Name = "West Corridor", Kind = "Corridor", Rect = Plan.rect(-296, -288, -197, -113), Storey = s })
		if s == 0 then
			strip({
				e("Cash Logistics", "SharedOffice"),
				e("Security Office", "Security"),
				e("Staff Room", "Lounge"),
				e("Foreign Exchange", "Office"),
				e("Customer Service", "Office"),
			}, northSplits, -235.5, -209, s)
			for i, entry in
				{
					e("WC Women", "WC", "Women"),
					e("Treasury Accounts", "SharedOffice"),
					e("Banknote Issue", "SharedOffice"),
					e("Staff Kitchen", "Pantry"),
				}
			do
				add({
					Name = entry.Name,
					Kind = entry.Kind,
					Gender = entry.Gender,
					Rect = Plan.rect(-319.5, -296, westSplits[i], westSplits[i + 1]),
					Storey = s,
				})
			end
			add({ Name = "Cash Store", Kind = "Storage", Rect = Plan.rect(-288, -279, -189, -175), Storey = s })
			add({ Name = "Counting Room", Kind = "Counting", Rect = Plan.rect(-279, -262, -197, -175), Storey = s })
			add({
				Name = "Vault",
				Kind = "Vault",
				Rect = Plan.rect(-288, -262, -175, -135),
				Storey = s,
				Doors = { Plan.door("MinZ", -270.5) },
			})
			strip({
				e("Archive", "Archive"),
				e("WC Men", "WC", "Men"),
				e("Server Room", "Server"),
				e("Copy Room", "Copy"),
				e("Information", "Office"),
			}, northSplits, -101, -74.5, s)
		else
			strip({
				e("Economic Research", "SharedOffice"),
				e("Statistics", "SharedOffice"),
				e("Governor's Office", "Reception"),
				e("Governor", "Executive"),
			}, { -319.5, -290, -266, -242, -200.5 }, -235.5, -209, s)
			for i, entry in
				{
					e("WC Men", "WC", "Men"),
					e("Banking Supervision", "SharedOffice"),
					e("Legal Department", "Office"),
					e("Personnel", "Office"),
				}
			do
				add({
					Name = entry.Name,
					Kind = entry.Kind,
					Gender = entry.Gender,
					Rect = Plan.rect(-319.5, -296, westSplits[i], westSplits[i + 1]),
					Storey = s,
				})
			end
			add({ Name = "Storage", Kind = "Storage", Rect = Plan.rect(-288, -279, -189, -175), Storey = s })
			add({ Name = "Records", Kind = "Archive", Rect = Plan.rect(-279, -262, -197, -175), Storey = s })
			add({ Name = "Board Room", Kind = "Board", Rect = Plan.rect(-288, -262, -175, -135), Storey = s })
			strip({
				e("IT Department", "SharedOffice"),
				e("WC Women", "WC", "Women"),
				e("Tea Kitchen", "Pantry"),
				e("Deputy Governor", "Executive"),
			}, { -319.5, -290, -266, -242, -200.5 }, -101, -74.5, s)
		end
	end
	return list
end

function CentralBank.build(district: any, parent: Instance): { [string]: number }
	local cb = district.CentralBank
	local model = Kit.model(parent, "CentralBank", "Central Bank")
	local G = district.GroundY
	local W = G + district.WalkTop
	local F = W + 3 -- banking floor on a high granite plinth
	local H = cb.StoreyHeight
	local R = F + H * cb.Storeys
	local b = cb.Body
	local doorZ = (b.MinZ + b.MaxZ) / 2
	assert(doorZ == DOOR_Z, "CentralBank: the plan expects the portal at z -155")
	local granite, sandstone = Kit.Style.Granite, Kit.Style.Sandstone
	local report: { [string]: number } = { Windows = 0, Tellers = 0, Flags = 0 }

	-- Grounds to the West Street sidewalk, plinth, portico platform and steps.
	Kit.slab(model, "Grounds", Kit.rect(cb.Rect.MinX, -185, cb.Rect.MinZ, cb.Rect.MaxZ), G - 0.6, W, Kit.Style.Paving)
	Kit.slab(model, "Plinth", Kit.inset(b, -1), W - 0.2, F, granite)
	Kit.slab(model, "Stylobate", Kit.rect(b.MaxX, b.MaxX + 8, doorZ - 28, doorZ + 28), W - 0.2, F, granite)
	for i = 0, 1 do
		local x0 = b.MaxX + 8 + i * 1.5
		Kit.box(model, "Step", x0, W - 0.2, doorZ - 22, x0 + 1.5, F - 1 - i, doorZ + 22, granite)
	end

	-- The plan of the interior.
	local t = 2.5
	local inner = Kit.inset(b, t)
	local plan = Plan.new({
		Model = model,
		Building = "CentralBank",
		Footprints = { inner },
		Levels = { F, F + H, R },
		Spaces = spaces(report),
		Skylights = { SKYLIGHT },
		Style = {
			Partition = Materials.Wall.Cream,
			Door = {
				Leaf = Materials.Wood.Walnut,
				Frame = Materials.Frame.Brown,
				Handle = Materials.Metal.Brass,
				KickPlate = Materials.Metal.Brass,
			},
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
				Spine = Materials.Wall.Cream,
				Rail = Materials.Metal.Brass,
			},
			Floors = { Corridor = Materials.Floor.Marble },
			Accent = Materials.Wall.Panel,
		},
		Seed = 3,
	})

	-- Facades: granite ground floor with barred windows, sandstone upper floor.
	local facade = Kit.folder(model, "Facade")
	local upper: Openings.WindowStyle = {
		Frame = Materials.Frame.Bronze,
		Glass = Materials.Glass.Window,
		Sill = Kit.Style.Marble,
		Board = Materials.Floor.Marble,
		Lintel = Kit.Style.Marble,
	}
	local barred: Openings.WindowStyle = table.clone(upper)
	barred.Bars = Materials.Metal.Iron
	local portal: Openings.DoorStyle = {
		Leaf = Materials.Metal.Bronze,
		Frame = Kit.Style.Bronze,
		Handle = Materials.Metal.Brass,
		Glass = Materials.Glass.Shop,
		KickPlate = Materials.Metal.Brass,
	}
	local zGrid = Shell.steps(-227, 12, -83)
	local xGrid = Shell.steps(-308, 12, -212)
	local function rows(centres: { number }, front: boolean): { Shell.WindowRow }
		return {
			{
				Centres = if front then Shell.without(centres, { { doorZ - 7, doorZ + 7 } }) else centres,
				Width = 4,
				Height = 9,
				Sill = 3.5,
				Storeys = { 0 },
				Style = barred,
			},
			{ Centres = centres, Width = 4, Height = 9, Sill = 3, Storeys = { 1 }, Style = upper },
		}
	end
	local materials = { granite, sandstone }
	local runs: { Shell.Run } = {
		{
			Axis = "Z",
			At = b.MaxX - t / 2,
			From = b.MinZ + t,
			To = b.MaxZ - t,
			Thickness = t,
			Out = 1,
			Material = granite,
			Materials = materials,
			Window = upper,
			Door = portal,
			Windows = rows(zGrid, true),
			Doors = {
				{ At = doorZ, Width = 8, Height = 13, Storey = 0, Double = true, StartOpen = true, Label = "Portal" },
			},
		},
		{
			Axis = "Z",
			At = b.MinX + t / 2,
			From = b.MinZ + t,
			To = b.MaxZ - t,
			Thickness = t,
			Out = -1,
			Material = granite,
			Materials = materials,
			Window = upper,
			Windows = rows(zGrid, false),
		},
	}
	for _, side in { -1, 1 } do
		table.insert(runs, {
			Axis = "X",
			At = (if side < 0 then b.MinZ else b.MaxZ) - side * t / 2,
			From = b.MinX,
			To = b.MaxX,
			Thickness = t,
			Out = side,
			Material = granite,
			Materials = materials,
			Window = upper,
			Windows = rows(xGrid, false),
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

	-- Rustication, string course, cornice, slate roof with the skylight, parapet.
	local door: { Kit.Gap } = { { Side = "East", From = doorZ - 5, To = doorZ + 5 } }
	for _, y in { F + 4.5, F + 9 } do
		Kit.band(model, "Rustication", b, y - 0.15, y + 0.15, 0.15, Kit.Style.DarkGranite, door)
	end
	Kit.band(model, "StringCourse", b, F + H - 0.5, F + H + 0.7, 0.6, Kit.Style.Marble)
	Kit.band(model, "Cornice", b, R - 1.2, R + 0.4, 1.4, sandstone)
	for _, piece in Kit.subtract({ inner }, SKYLIGHT) do
		Kit.slab(model, "RoofTop", piece, R, R + 0.4, Kit.Style.Slate)
	end
	Kit.parapet(model, Kit.inset(b, -0.6), R + 0.4, 2.6, sandstone)
	-- Skylight over the banking hall: a raised curb with a glazed lid on steel bars.
	local s = SKYLIGHT
	local curb = Materials.Metal.Dark
	Kit.box(model, "SkylightCurb", s.MinX - 0.6, R - 1, s.MinZ - 0.6, s.MaxX + 0.6, R + 1.4, s.MinZ, curb)
	Kit.box(model, "SkylightCurb", s.MinX - 0.6, R - 1, s.MaxZ, s.MaxX + 0.6, R + 1.4, s.MaxZ + 0.6, curb)
	Kit.box(model, "SkylightCurb", s.MinX - 0.6, R - 1, s.MinZ, s.MinX, R + 1.4, s.MaxZ, curb)
	Kit.box(model, "SkylightCurb", s.MaxX, R - 1, s.MinZ, s.MaxX + 0.6, R + 1.4, s.MaxZ, curb)
	Kit.slab(model, "SkylightGlass", s, R + 1.2, R + 1.35, Materials.Glass.Window)
	for x = s.MinX + 5, s.MaxX - 5, 5 do
		Kit.box(
			model,
			"SkylightBar",
			x - 0.15,
			R + 1.0,
			s.MinZ,
			x + 0.15,
			R + 1.2,
			s.MaxZ,
			Parts.detail(Materials.Metal.Dark)
		)
	end
	Exterior.condenser(model, -300, -90, R + 0.4)
	Exterior.condenser(model, -300, -222, R + 0.4)
	Exterior.vent(model, -275, -100, R + 0.4)
	Exterior.vent(model, -275, -210, R + 0.4)
	Exterior.hatch(model, -275, -124, R + 0.4)

	-- Portico: six columns, entablature with the name, pediment with the emblem.
	local front: Kit.Face = { Axis = "X", At = b.MaxX, Out = 1 }
	local px = b.MaxX + 5.4
	for _, dz in { -22.5, -13.5, -4.5, 4.5, 13.5, 22.5 } do
		Kit.column(model, px, doorZ + dz, F, F + 30, 3.4, Kit.Style.Marble)
	end
	Kit.slab(model, "PorticoCeiling", Kit.rect(b.MaxX, b.MaxX + 8, doorZ - 26, doorZ + 26), F + 29.4, F + 30, sandstone)
	local entablature =
		Kit.box(model, "Entablature", b.MaxX, F + 30, doorZ - 26, b.MaxX + 8.4, R, doorZ + 26, sandstone)
	Kit.inscription(entablature, { "CENTRAL BANK" }, Color3.fromRGB(90, 70, 46), Enum.NormalId.Right)
	Kit.pediment(model, front, doorZ - 27, doorZ + 27, R + 0.4, 8, 0, 8.6, sandstone)
	Kit.emblem(model, { Axis = "X", At = b.MaxX + 8.6, Out = 1 }, doorZ, R + 3.4, 4.2, 0.05)
	Kit.faceBox(model, "PortalSurround", front, doorZ - 5.2, doorZ - 4.35, F, F + 14, 0, 0.5, Kit.Style.Bronze)
	Kit.faceBox(model, "PortalSurround", front, doorZ + 4.35, doorZ + 5.2, F, F + 14, 0, 0.5, Kit.Style.Bronze)
	Kit.faceBox(model, "PortalSurround", front, doorZ - 5.2, doorZ + 5.2, F + 13.35, F + 14, 0, 0.5, Kit.Style.Bronze)
	for _, z in { doorZ - 30, doorZ + 30 } do
		Kit.ceilingLight(model, b.MaxX + 4, z, F + 29.4, 2, 24)
	end
	for _, dz in { -34, 34 } do
		Kit.flagpole(model, Vector3.new(-188, W, doorZ + dz), 24, 7, Vector3.new(0, 0, if dz < 0 then -1 else 1))
		report.Flags += 1
	end
	-- Air conditioners on the back wall.
	local back: Openings.Wall = { Axis = "Z", At = b.MinX + t / 2, Thickness = t, Out = -1 }
	for _, z in { -221, -173, -125, -89 } do
		Exterior.acUnit(model, back, z, F + H + 0.8)
	end

	model:SetAttribute("Height", R + 0.4 + 8 - G)
	return report
end

return CentralBank
