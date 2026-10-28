--!strict
-- The central bank on the west side of the square, facing east onto West Street. A solid,
-- closed block: rusticated granite ground floor, sandstone upper floor, a portico of six columns
-- with a pediment, tall barred-looking windows. Inside, the banking hall is walkable: teller
-- counter with glass screens, waiting benches, the national emblem and the vault door.
-- Accounts and money stay in the Discord economy bot; the bank interface follows in Milestone 4.

local Kit = require(script.Parent.Kit)
local Util = require(script.Parent.Parent.Map.Builders.Util)

local CentralBank = {}

local STEEL: Kit.Options = { Material = Enum.Material.Metal, Color = Color3.fromRGB(150, 154, 160) }
local SCREEN: Kit.Options = {
	Material = Enum.Material.Glass,
	Color = Color3.fromRGB(200, 220, 230),
	Transparency = 0.6,
	CastShadow = false,
}

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
	local granite, sandstone = Kit.Style.Granite, Kit.Style.Sandstone
	local report = { Windows = 0, Tellers = 0, Flags = 0 }

	-- Grounds to the West Street sidewalk, plinth, portico platform and steps.
	Kit.slab(model, "Grounds", Kit.rect(cb.Rect.MinX, -185, cb.Rect.MinZ, cb.Rect.MaxZ), G - 0.6, W, Kit.Style.Paving)
	Kit.slab(model, "Plinth", Kit.inset(b, -1), W - 0.2, F, granite)
	Kit.slab(model, "Stylobate", Kit.rect(b.MaxX, b.MaxX + 8, doorZ - 28, doorZ + 28), W - 0.2, F, granite)
	for i = 0, 1 do
		local x0 = b.MaxX + 8 + i * 1.5
		Kit.box(model, "Step", x0, W - 0.2, doorZ - 22, x0 + 1.5, F - 1 - i, doorZ + 22, granite)
	end

	-- Shell: granite ground floor with the portal, sandstone upper floor, roof and cornice.
	local t = 2.5
	local function walls(y0: number, y1: number, options: Kit.Options, door: boolean)
		local openings = if door then { { From = doorZ - 4, To = doorZ + 4, Bottom = y0, Top = y0 + 13 } } else nil
		Kit.wall(model, "Wall", "Z", b.MinZ, b.MaxZ, b.MaxX - t / 2, t, y0, y1, openings, options)
		Kit.wall(model, "Wall", "Z", b.MinZ, b.MaxZ, b.MinX + t / 2, t, y0, y1, nil, options)
		Kit.wall(model, "Wall", "X", b.MinX + t, b.MaxX - t, b.MinZ + t / 2, t, y0, y1, nil, options)
		Kit.wall(model, "Wall", "X", b.MinX + t, b.MaxX - t, b.MaxZ - t / 2, t, y0, y1, nil, options)
	end
	walls(F, F + H, granite, true)
	walls(F + H, R, sandstone, false)
	local door: { Kit.Gap } = { { Side = "East", From = doorZ - 5, To = doorZ + 5 } }
	for _, y in { F + 4.5, F + 9 } do
		Kit.band(model, "Rustication", b, y - 0.15, y + 0.15, 0.15, Kit.Style.DarkGranite, door)
	end
	Kit.band(model, "StringCourse", b, F + H - 0.5, F + H + 0.7, 0.6, Kit.Style.Marble)
	Kit.slab(model, "RoofSlab", Kit.inset(b, t), R - 1, R, sandstone)
	Kit.band(model, "Cornice", b, R - 1.2, R + 0.4, 1.4, sandstone)
	Kit.slab(model, "RoofTop", Kit.inset(b, t), R, R + 0.4, Kit.Style.Slate)
	Kit.parapet(model, Kit.inset(b, -0.6), R + 0.4, 2.6, sandstone)

	-- Windows: tall on both floors, with lintels; the portal is left free.
	local spec: Kit.WindowSpec = {
		Width = 4,
		Height = 9,
		Spacing = 12,
		Sills = { F + 3.5, F + H + 3 },
		Lintel = true,
		Trim = Kit.Style.Marble,
	}
	local front: Kit.Face = { Axis = "X", At = b.MaxX, Out = 1 }
	local frontSpec = table.clone(spec)
	frontSpec.Skip = { { doorZ - 7, doorZ + 7 } }
	report.Windows += Kit.windows(model, front, b.MinZ + 4, b.MaxZ - 4, frontSpec)
	report.Windows += Kit.windows(model, { Axis = "X", At = b.MinX, Out = -1 }, b.MinZ + 4, b.MaxZ - 4, spec)
	report.Windows += Kit.windows(model, { Axis = "Z", At = b.MinZ, Out = -1 }, b.MinX + 4, b.MaxX - 4, spec)
	report.Windows += Kit.windows(model, { Axis = "Z", At = b.MaxZ, Out = 1 }, b.MinX + 4, b.MaxX - 4, spec)

	-- Portico: six columns, entablature with the name, pediment with the emblem.
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
	Kit.faceBox(model, "DoorFrame", front, doorZ - 5, doorZ - 4, F, F + 14, 0, 0.5, Kit.Style.Bronze)
	Kit.faceBox(model, "DoorFrame", front, doorZ + 4, doorZ + 5, F, F + 14, 0, 0.5, Kit.Style.Bronze)
	Kit.faceBox(model, "DoorFrame", front, doorZ - 5, doorZ + 5, F + 13, F + 14, 0, 0.5, Kit.Style.Bronze)
	for _, dz in { -34, 34 } do
		Kit.flagpole(model, Vector3.new(-188, W, doorZ + dz), 24, 7, Vector3.new(0, 0, if dz < 0 then -1 else 1))
		report.Flags += 1
	end

	-- Banking hall: two storeys high, behind the portal.
	local hall = Kit.rect(-262, b.MaxX - t, doorZ - 40, doorZ + 40)
	local ceiling = F + 24
	Kit.wall(model, "InnerWall", "X", hall.MinX - 1, hall.MaxX, hall.MinZ - 0.5, 1, F, ceiling, nil, Kit.Style.Marble)
	Kit.wall(model, "InnerWall", "X", hall.MinX - 1, hall.MaxX, hall.MaxZ + 0.5, 1, F, ceiling, nil, Kit.Style.Marble)
	Kit.wall(model, "InnerWall", "Z", hall.MinZ, hall.MaxZ, hall.MinX - 0.5, 1, F, ceiling, nil, Kit.Style.Marble)
	Kit.slab(model, "HallCeiling", Kit.inset(hall, -1), ceiling, ceiling + 1, Kit.Style.Plaster)
	Kit.slab(model, "HallFloor", hall, F, F + 0.1, Kit.Style.Floor)
	Kit.slab(
		model,
		"FloorBorder",
		Kit.inset(hall, 6),
		F + 0.1,
		F + 0.14,
		Kit.with(Kit.Style.DarkGranite, { Decoration = true })
	)
	Kit.slab(
		model,
		"FloorField",
		Kit.inset(hall, 7),
		F + 0.14,
		F + 0.18,
		Kit.with(Kit.Style.Floor, { Decoration = true })
	)
	Kit.slab(model, "Runner", Kit.rect(-238, hall.MaxX, doorZ - 3, doorZ + 3), F + 0.18, F + 0.28, Kit.Style.Carpet)

	-- Teller counter with glass screens and pass-through slots, one chair per teller.
	local cx = -240
	Kit.box(model, "Counter", cx - 1.5, F + 0.1, doorZ - 30, cx + 1.5, F + 3.6, doorZ + 30, Kit.Style.DarkWood)
	Kit.box(model, "CounterTop", cx - 1.8, F + 3.6, doorZ - 30.3, cx + 1.8, F + 3.9, doorZ + 30.3, Kit.Style.Marble)
	local slots = {}
	for _, dz in { -24, -12, 0, 12, 24 } do
		local z = doorZ + dz
		table.insert(slots, { From = z - 2, To = z + 2, Bottom = F + 3.9, Top = F + 5.4 })
		local chair = Instance.new("Seat")
		chair.Name = "TellerChair"
		chair.Anchored = true
		chair.Size = Vector3.new(2.2, 0.5, 2.2)
		chair.CFrame = CFrame.lookAt(Vector3.new(cx - 4.5, F + 1.6, z), Vector3.new(cx, F + 1.6, z))
		chair.Material = Enum.Material.Fabric
		chair.Color = Color3.fromRGB(40, 44, 52)
		chair.Parent = model
		Kit.add(1)
		report.Tellers += 1
	end
	Kit.wall(model, "Screen", "Z", doorZ - 30, doorZ + 30, cx + 0.5, 0.2, F + 3.9, F + 8, slots, SCREEN)
	local sign =
		Kit.box(model, "CounterSign", cx + 0.6, F + 9, doorZ - 14, cx + 0.8, F + 11.5, doorZ + 14, Kit.Style.DarkWood)
	Kit.inscription(
		sign,
		{ "CENTRAL BANK", "KAGUNDI DINAR · KGD" },
		Color3.fromRGB(236, 206, 130),
		Enum.NormalId.Right
	)

	-- Vault door in the back wall, the emblem and flags above it.
	local back: Kit.Face = { Axis = "X", At = hall.MinX, Out = 1 }
	local vy = F + 7.2
	Kit.faceBox(model, "VaultFrame", back, doorZ - 7.5, doorZ + 7.5, vy - 7, vy + 7.5, 0, 0.6, Kit.Style.DarkGranite)
	Util.cylinder(
		model,
		"VaultDoor",
		Vector3.new(hall.MinX + 0.6, vy, doorZ),
		Vector3.new(hall.MinX + 1.6, vy, doorZ),
		12,
		STEEL
	)
	Util.cylinder(
		model,
		"VaultWheel",
		Vector3.new(hall.MinX + 1.6, vy, doorZ),
		Vector3.new(hall.MinX + 2.1, vy, doorZ),
		3.6,
		STEEL
	)
	Kit.box(model, "VaultSpoke", hall.MinX + 2.1, vy - 0.25, doorZ - 3, hall.MinX + 2.5, vy + 0.25, doorZ + 3, STEEL)
	Kit.box(model, "VaultSpoke", hall.MinX + 2.1, vy - 3, doorZ - 0.25, hall.MinX + 2.5, vy + 3, doorZ + 0.25, STEEL)
	Kit.add(2)
	Kit.emblem(model, back, doorZ, F + 18.5, 6, 0.2)
	for _, dz in { -11, 11 } do
		Kit.flagpole(
			model,
			Vector3.new(hall.MinX + 2.5, F + 0.1, doorZ + dz),
			14,
			4,
			Vector3.new(0.3, 0, if dz < 0 then -1 else 1)
		)
		report.Flags += 1
	end

	-- Waiting benches facing the counter, ceiling lights.
	for _, x in { -226, -213 } do
		for _, dz in { -20, -10, 10, 20 } do
			Kit.bench(model, Vector3.new(x, F + 0.12, doorZ + dz), Vector3.new(-1, 0, 0))
		end
	end
	for _, x in { -252, -232, -212 } do
		for _, dz in { -22, 22 } do
			Kit.ceilingLight(model, x, doorZ + dz, ceiling, 5, 34)
		end
	end

	model:SetAttribute("Height", R + 0.4 + 8 - G)
	return report
end

return CentralBank
