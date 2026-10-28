--!strict
-- The Hausali, the government headquarters (lore: "great house"), on the east side of the square,
-- facing west. Administrative style, clearly different from the Congress: white plaster, ochre
-- bands and corner pilasters, green shutters and a red tile roof. A central risalit carries the
-- portal, a speaker's balcony, the name and the national emblem. The entrance lobby with the
-- reception is walkable; the offices above are closed. A walled garden lies behind.

local Kit = require(script.Parent.Kit)

local Hausali = {}

local SHUTTERS: Kit.Options = { Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(52, 92, 64) }

function Hausali.build(district: any, parent: Instance): { [string]: number }
	local h = district.Hausali
	local model = Kit.model(parent, "Hausali", "Hausali")
	local G = district.GroundY
	local W = G + district.WalkTop
	local F = W + 1.6 -- ground floor on a low stone plinth
	local H = h.StoreyHeight
	local R = F + H * h.Storeys -- eaves
	local b = h.Body
	local e = h.Entrance
	local doorZ = (e.MinZ + e.MaxZ) / 2
	local plaster, ochre, granite = Kit.Style.Plaster, Kit.Style.Ochre, Kit.Style.Granite
	local report = { Windows = 0, Flags = 0 }

	-- Grounds from the East Street sidewalk to the back of the plot, plinth and entrance steps.
	Kit.slab(model, "Grounds", Kit.rect(185, h.Rect.MaxX, h.Rect.MinZ, h.Rect.MaxZ), G - 0.6, W, Kit.Style.Paving)
	Kit.slab(model, "Plinth", Kit.inset(b, -0.8), W - 0.2, F, granite)
	Kit.slab(model, "Plinth", Kit.rect(e.MinX - 0.8, b.MinX, e.MinZ - 0.8, e.MaxZ + 0.8), W - 0.2, F, granite)
	Kit.box(model, "Step", e.MinX - 2.6, W - 0.2, doorZ - 6, e.MinX - 0.8, W + 0.8, doorZ + 6, granite)

	-- Shell. The lobby opens into the risalit through the front wall of the main block.
	local t = 2
	Kit.wall(model, "Wall", "Z", b.MinZ, b.MaxZ, b.MinX + t / 2, t, F, R, {
		{ From = e.MinZ + 2, To = e.MaxZ - 2, Bottom = F, Top = F + H - 1 },
	}, plaster)
	Kit.wall(model, "Wall", "Z", b.MinZ, b.MaxZ, b.MaxX - t / 2, t, F, R, nil, plaster)
	Kit.wall(model, "Wall", "X", b.MinX + t, b.MaxX - t, b.MinZ + t / 2, t, F, R, nil, plaster)
	Kit.wall(model, "Wall", "X", b.MinX + t, b.MaxX - t, b.MaxZ - t / 2, t, F, R, nil, plaster)
	local top = R + 3 -- the risalit rises above the eaves
	Kit.wall(model, "RisalitWall", "Z", e.MinZ, e.MaxZ, e.MinX + t / 2, t, F, top, {
		{ From = doorZ - 3, To = doorZ + 3, Bottom = F, Top = F + 11 },
		{ From = doorZ - 3, To = doorZ + 3, Bottom = F + H + 0.6, Top = F + H + 9.5 }, -- balcony door
	}, plaster)
	Kit.wall(model, "RisalitWall", "X", e.MinX + t, b.MinX, e.MinZ + t / 2, t, F, top, nil, plaster)
	Kit.wall(model, "RisalitWall", "X", e.MinX + t, b.MinX, e.MaxZ - t / 2, t, F, top, nil, plaster)
	-- Above the eaves the risalit reaches back into the roof, so its cross gable meets the slope.
	Kit.box(model, "RisalitWall", b.MinX, R, e.MinZ, b.MinX + 8, top, e.MaxZ, plaster)
	Kit.box(
		model,
		"BalconyDoor",
		e.MinX + 1.4,
		F + H + 0.6,
		doorZ - 3,
		e.MinX + 1.7,
		F + H + 9.5,
		doorZ + 3,
		Kit.Style.Glass
	)

	-- Lobby with reception, flags and the national emblem; ceiling under the closed offices.
	local lobby = Kit.rect(b.MinX + t, 236, e.MinZ - 14, e.MaxZ + 14)
	Kit.wall(model, "InnerWall", "X", lobby.MinX, lobby.MaxX + 1, lobby.MinZ - 0.5, 1, F, F + H, nil, plaster)
	Kit.wall(model, "InnerWall", "X", lobby.MinX, lobby.MaxX + 1, lobby.MaxZ + 0.5, 1, F, F + H, nil, plaster)
	Kit.wall(model, "InnerWall", "Z", lobby.MinZ - 1, lobby.MaxZ + 1, lobby.MaxX + 0.5, 1, F, F + H, nil, plaster)
	local hall = Kit.rect(e.MinX + t, lobby.MaxX, lobby.MinZ, lobby.MaxZ)
	Kit.slab(model, "LobbyFloor", Kit.rect(e.MinX + t, lobby.MaxX, e.MinZ + t, e.MaxZ - t), F, F + 0.1, Kit.Style.Floor)
	Kit.slab(model, "LobbyFloor", lobby, F, F + 0.1, Kit.Style.Floor)
	Kit.slab(model, "LobbyCeiling", hall, F + H - 1, F + H, plaster)
	Kit.slab(model, "Runner", Kit.rect(e.MinX + t, 220, doorZ - 3, doorZ + 3), F + 0.1, F + 0.2, Kit.Style.Carpet)
	Kit.box(model, "Reception", 222, F + 0.1, doorZ - 7, 225, F + 3.6, doorZ + 7, Kit.Style.DarkWood)
	Kit.box(model, "ReceptionTop", 221.6, F + 3.6, doorZ - 7.4, 225.4, F + 3.9, doorZ + 7.4, Kit.Style.Marble)
	local chair = Instance.new("Seat")
	chair.Name = "ReceptionChair"
	chair.Anchored = true
	chair.Size = Vector3.new(2.2, 0.5, 2.2)
	chair.CFrame = CFrame.lookAt(Vector3.new(228, F + 1.6, doorZ), Vector3.new(220, F + 1.6, doorZ))
	chair.Material = Enum.Material.Fabric
	chair.Color = Color3.fromRGB(40, 44, 52)
	chair.Parent = model
	Kit.add(1)
	local back: Kit.Face = { Axis = "X", At = lobby.MaxX, Out = -1 }
	Kit.emblem(model, back, doorZ, F + 8, 5.5, 0.2)
	for _, z in { doorZ - 8, doorZ + 8 } do
		Kit.flagpole(
			model,
			Vector3.new(lobby.MaxX - 2, F + 0.1, z),
			10,
			3.2,
			Vector3.new(-0.4, 0, if z < doorZ then -1 else 1)
		)
		report.Flags += 1
	end
	for _, z in { lobby.MinZ + 1.2, lobby.MaxZ - 1.2 } do
		for _, x in { 206, 214 } do
			Kit.bench(model, Vector3.new(x, F + 0.1, z), Vector3.new(0, 0, doorZ - z))
		end
	end
	local plaque = Kit.box(model, "Directory", 210, F + 4, lobby.MinZ, 218, F + 8, lobby.MinZ + 0.2, Kit.Style.Bronze)
	Kit.inscription(
		plaque,
		{ "HAUSALI", "Government Headquarters", "People's Committee" },
		Color3.fromRGB(240, 220, 170),
		Enum.NormalId.Back
	)
	Kit.ceilingLight(model, 212, doorZ, F + H - 1, 5, 28)
	Kit.ceilingLight(model, 228, doorZ, F + H - 1, 4, 20)

	-- Roof: attic slab, red tile gable roof along the block, gable ends, cross gable over the
	-- risalit with the emblem and the name, chimneys.
	Kit.slab(model, "Attic", Kit.inset(b, t), R - 1, R, plaster)
	Kit.slab(model, "Eaves", Kit.inset(b, -1), R - 0.8, R, ochre)
	local roofHeight = 14
	Kit.gableRoof(model, b, R, roofHeight, "Z", 1.5, Kit.Style.Tile)
	local gable = roofHeight * ((b.MaxX - b.MinX) / 2) / ((b.MaxX - b.MinX) / 2 + 1.5)
	Kit.pediment(model, { Axis = "Z", At = b.MinZ, Out = -1 }, b.MinX, b.MaxX, R, gable, -t, 0, plaster)
	Kit.pediment(model, { Axis = "Z", At = b.MaxZ, Out = 1 }, b.MinX, b.MaxX, R, gable, -t, 0, plaster)
	Kit.slab(model, "RisalitTop", Kit.rect(e.MinX, b.MinX, e.MinZ, e.MaxZ), top - 1, top, plaster)
	Kit.gableRoof(model, Kit.rect(e.MinX, b.MinX + 12, e.MinZ, e.MaxZ), top, 8, "X", 1, Kit.Style.Tile)
	local front: Kit.Face = { Axis = "X", At = e.MinX, Out = -1 }
	Kit.pediment(model, front, e.MinZ, e.MaxZ, top, 8 * 18 / 19, -t, 0, plaster)
	Kit.emblem(model, front, doorZ, top + 3, 4.5, 0.1)
	local frieze = Kit.faceBox(model, "Frieze", front, e.MinZ + 3, e.MaxZ - 3, R - 0.4, R + 2.6, 0, 0.3, ochre)
	Kit.inscription(frieze, { "HAUSALI" }, Color3.fromRGB(255, 255, 255), Enum.NormalId.Left)
	Kit.flagpole(model, Vector3.new(e.MinX + 1, top + 8 * 18 / 19, doorZ), 10, 6, Vector3.new(0, 0, 1))
	report.Flags += 1
	for _, z in { b.MinZ + 40, b.MaxZ - 40 } do
		Kit.box(model, "Chimney", 250, R + 6, z - 2, 256, R + roofHeight + 3, z + 2, Kit.Style.Plaster)
	end

	-- Facade: ochre bands and pilasters, shuttered windows, portal and speaker's balcony.
	for level = 1, h.Storeys - 1 do
		local y = F + level * H
		Kit.band(model, "Band", b, y - 0.3, y + 0.5, 0.4, ochre, {
			{ Side = "West", From = e.MinZ, To = e.MaxZ },
		})
		Kit.box(model, "Band", e.MinX - 0.4, y - 0.3, e.MinZ - 0.4, b.MinX, y + 0.5, e.MaxZ + 0.4, ochre)
	end
	for _, corner in { { b.MinX, b.MinZ }, { b.MinX, b.MaxZ }, { b.MaxX, b.MinZ }, { b.MaxX, b.MaxZ } } do
		local x, z = corner[1], corner[2]
		Kit.box(model, "Pilaster", x - 1.6, F, z - 1.6, x + 1.6, R - 0.8, z + 1.6, ochre)
	end
	for _, z in { e.MinZ, e.MaxZ } do
		Kit.box(model, "Pilaster", e.MinX - 0.6, F, z - 1.4, e.MinX + 2.2, top, z + 1.4, ochre)
	end
	local sills = {}
	for level = 0, h.Storeys - 1 do
		table.insert(sills, F + level * H + 3)
	end
	local spec: Kit.WindowSpec = {
		Width = 3.6,
		Height = 7,
		Spacing = 9,
		Sills = sills,
		Trim = ochre,
		Shutters = SHUTTERS,
	}
	local west: Kit.Face = { Axis = "X", At = b.MinX, Out = -1 }
	local east: Kit.Face = { Axis = "X", At = b.MaxX, Out = 1 }
	local north: Kit.Face = { Axis = "Z", At = b.MinZ, Out = -1 }
	local south: Kit.Face = { Axis = "Z", At = b.MaxZ, Out = 1 }
	report.Windows += Kit.windows(model, west, b.MinZ + 4, e.MinZ - 2, spec)
	report.Windows += Kit.windows(model, west, e.MaxZ + 2, b.MaxZ - 4, spec)
	report.Windows += Kit.windows(model, east, b.MinZ + 4, b.MaxZ - 4, spec)
	report.Windows += Kit.windows(model, north, b.MinX + 4, b.MaxX - 4, spec)
	report.Windows += Kit.windows(model, south, b.MinX + 4, b.MaxX - 4, spec)
	local upper = table.clone(spec)
	upper.Sills = { sills[2], sills[3] }
	upper.Skip = { { doorZ - 4, doorZ + 4 } }
	report.Windows += Kit.windows(model, front, e.MinZ + 3, e.MaxZ - 3, upper)
	-- Portal frame, keystone, name plaque beside the door.
	Kit.faceBox(model, "DoorFrame", front, doorZ - 4, doorZ - 3, F, F + 11, 0, 0.5, ochre)
	Kit.faceBox(model, "DoorFrame", front, doorZ + 3, doorZ + 4, F, F + 11, 0, 0.5, ochre)
	Kit.faceBox(model, "DoorFrame", front, doorZ - 4, doorZ + 4, F + 11, F + 12, 0, 0.5, ochre)
	Kit.faceBox(model, "Keystone", front, doorZ - 0.8, doorZ + 0.8, F + 10.6, F + 12.6, 0, 0.7, Kit.Style.Marble)
	local sign = Kit.faceBox(model, "NamePlaque", front, doorZ + 6, doorZ + 12, F + 4, F + 7, 0, 0.15, Kit.Style.Bronze)
	Kit.inscription(
		sign,
		{ "HAUSALI", "GOVERNMENT", "HEADQUARTERS" },
		Color3.fromRGB(240, 220, 170),
		Enum.NormalId.Left
	)
	-- Speaker's balcony over the portal (addresses to the square), on two consoles.
	local by = F + H
	Kit.faceBox(model, "Balcony", front, doorZ - 8, doorZ + 8, by, by + 0.6, 0, 2.6, Kit.Style.Marble)
	Kit.faceBox(model, "Balustrade", front, doorZ - 8, doorZ + 8, by + 0.6, by + 3.6, 2.2, 2.6, Kit.Style.Marble)
	Kit.faceBox(model, "Balustrade", front, doorZ - 8, doorZ - 7.6, by + 0.6, by + 3.6, 0, 2.2, Kit.Style.Marble)
	Kit.faceBox(model, "Balustrade", front, doorZ + 7.6, doorZ + 8, by + 0.6, by + 3.6, 0, 2.2, Kit.Style.Marble)
	for _, z in { doorZ - 6, doorZ + 6 } do
		Kit.faceBox(model, "Console", front, z - 0.6, z + 0.6, by - 2.4, by, 0, 2, Kit.Style.Marble)
	end
	-- Flags on both sides of the risalit.
	for _, z in { e.MinZ - 6, e.MaxZ + 6 } do
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

	model:SetAttribute("Height", top + 8 - G)
	return report
end

return Hausali
