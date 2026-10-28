--!strict
-- General People's Congress: the tallest building of the district, closing the north end of the
-- main square, with a central dome (encyclopedia). Cream limestone on a granite podium,
-- ceremonial steps down to the forecourt, a portico of eight columns with the national emblem
-- in the pediment, and the assembly chamber inside: a hemicycle of 47 seats facing the
-- presiding dais with three more. The entrance hall and the chamber are walkable; the wings
-- are closed.

local Kit = require(script.Parent.Kit)
local Util = require(script.Parent.Parent.Map.Builders.Util)

local Congress = {}

local function seat(parent: Instance, position: Vector3, facing: Vector3, options: any?): Seat
	local s = Instance.new("Seat")
	s.Name = "Seat"
	s.Anchored = true
	s.Size = Vector3.new(2.4, 0.5, 2.2)
	s.CFrame = CFrame.lookAt(position, position + facing)
	s.Material = Enum.Material.Fabric
	s.Color = if options then options.Color else Color3.fromRGB(120, 34, 38)
	s.TopSurface = Enum.SurfaceType.Smooth
	s.BottomSurface = Enum.SurfaceType.Smooth
	s.Parent = parent
	Kit.add(1)
	return s
end
Congress.seat = seat

local function chamber(c: any, parent: Instance, floorY: number, ceilingY: number): { [string]: number }
	local folder = Kit.folder(parent, "Chamber")
	local room = c.Chamber
	local report = { Seats = 0 }
	Kit.slab(folder, "ChamberCarpet", room, floorY, floorY + 0.2, Kit.Style.Carpet)
	local top = floorY + 0.2

	-- Presiding dais on the north side with the national emblem and two flags behind it.
	local daisZ = room.MinZ + 2
	Kit.box(folder, "Dais", -26, top, daisZ, 26, top + 1.6, daisZ + 14, Kit.Style.Floor)
	Kit.box(folder, "DaisDesk", -15, top + 1.6, daisZ + 9, 15, top + 5, daisZ + 10.5, Kit.Style.DarkWood)
	for _, x in { -8, 0, 8 } do
		seat(folder, Vector3.new(x, top + 2.1, daisZ + 6.5), Vector3.new(0, 0, 1))
		report.Seats += 1
	end
	Kit.box(folder, "Lectern", -2, top, daisZ + 18, 2, top + 4.6, daisZ + 20, Kit.Style.DarkWood)
	local back: Kit.Face = { Axis = "Z", At = room.MinZ, Out = 1 }
	Kit.box(folder, "EmblemPanel", -11, top + 12, room.MinZ, 11, top + 34, room.MinZ + 0.4, Kit.Style.DarkWood)
	Kit.emblem(folder, back, 0, top + 23, 18, 0.7)
	for _, x in { -20, 20 } do
		Kit.flagpole(folder, Vector3.new(x, top + 1.6, daisZ + 3), 16, 5, Vector3.new(-x / 20, 0, 0.4))
	end

	-- Hemicycle: four rising rows of seats with desks, facing the dais.
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
				{ Material = Enum.Material.Fabric, Color = Color3.fromRGB(104, 28, 32) }
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

	-- Ceiling lights.
	for _, x in { -30, 0, 30 } do
		for _, z in { room.MinZ + 22, room.MaxZ - 22 } do
			Kit.ceilingLight(folder, x, z, ceilingY, 6, 40)
		end
	end
	return report
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
	local report = { Windows = 0, Seats = 0 }
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

	-- Shell: outer walls with the three portal doors and the service door.
	local t = 2
	local doors = {
		{ From = -18, To = -10, Bottom = P, Top = P + 16 },
		{ From = -4, To = 4, Bottom = P, Top = P + 16 },
		{ From = 10, To = 18, Bottom = P, Top = P + 16 },
	}
	Kit.wall(model, "Wall", "X", b.MinX, b.MaxX, b.MaxZ - t / 2, t, P, R, doors, stone)
	Kit.wall(model, "Wall", "X", b.MinX, b.MaxX, b.MinZ + t / 2, t, P, R, {
		{ From = -4, To = 4, Bottom = P, Top = P + 12 },
	}, stone)
	Kit.wall(model, "Wall", "Z", b.MinZ + t, b.MaxZ - t, b.MinX + t / 2, t, P, R, nil, stone)
	Kit.wall(model, "Wall", "Z", b.MinZ + t, b.MaxZ - t, b.MaxX - t / 2, t, P, R, nil, stone)
	-- Door frames in bronze.
	for _, d in doors do
		Kit.box(model, "DoorFrame", d.From - 0.8, P, b.MaxZ, d.From, d.Top + 0.8, b.MaxZ + 0.5, Kit.Style.Bronze)
		Kit.box(model, "DoorFrame", d.To, P, b.MaxZ, d.To + 0.8, d.Top + 0.8, b.MaxZ + 0.5, Kit.Style.Bronze)
		Kit.box(model, "DoorFrame", d.From, d.Top, b.MaxZ, d.To, d.Top + 0.8, b.MaxZ + 0.5, Kit.Style.Bronze)
	end

	-- Interior: marble floor, entrance hall, chamber walls, roof slab.
	local inner = Kit.inset(b, t)
	Kit.slab(model, "Floor", inner, P, P + 0.2, Kit.Style.Floor)
	local room = c.Chamber
	local hallTop = P + 20
	Kit.wall(model, "InnerWall", "X", room.MinX, room.MaxX, room.MaxZ + 1, 2, P, R - 1.5, {
		{ From = -7, To = 7, Bottom = P, Top = P + 15 },
	}, stone)
	Kit.wall(model, "InnerWall", "Z", room.MinZ, room.MaxZ + 2, room.MinX - 1, 2, P, R - 1.5, nil, stone)
	Kit.wall(model, "InnerWall", "Z", room.MinZ, room.MaxZ + 2, room.MaxX + 1, 2, P, R - 1.5, nil, stone)
	-- Entrance hall between the portal and the chamber, with its own ceiling.
	local hall = Kit.rect(-40, 40, room.MaxZ + 2, b.MaxZ - t)
	Kit.wall(model, "InnerWall", "Z", hall.MinZ, hall.MaxZ, hall.MinX - 1, 2, P, hallTop, nil, stone)
	Kit.wall(model, "InnerWall", "Z", hall.MinZ, hall.MaxZ, hall.MaxX + 1, 2, P, hallTop, nil, stone)
	Kit.slab(
		model,
		"HallCeiling",
		Kit.rect(hall.MinX - 2, hall.MaxX + 2, hall.MinZ, hall.MaxZ),
		hallTop,
		hallTop + 1,
		marble
	)
	Kit.slab(model, "HallCarpet", Kit.rect(-6, 6, hall.MinZ, hall.MaxZ), P + 0.2, P + 0.3, Kit.Style.Carpet)
	Kit.emblem(model, { Axis = "Z", At = hall.MinZ, Out = 1 }, 0, P + 17.4, 4.5, 0.2)
	for _, x in { -24, 24 } do
		Kit.ceilingLight(model, x, -328, hallTop, 6, 30)
		Kit.bench(model, Vector3.new(x * 1.4, P + 0.2, (hall.MinZ + hall.MaxZ) / 2), Vector3.new(-x, 0, 0))
	end
	local chamberReport = chamber(c, model, P + 0.2, R - 1.5)
	report.Seats = chamberReport.Seats
	Kit.slab(model, "RoofSlab", inner, R - 1.5, R, stone)

	-- Facade: string courses, cornice, attic parapet and windows on every side.
	for level = 1, c.Storeys - 1 do
		local y = P + level * H
		Kit.band(model, "StringCourse", b, y - 0.4, y + 0.6, 0.5, marble, {
			{ Side = "South", From = -20, To = 20 }, -- over the portal doors
		})
	end
	Kit.slab(model, "Cornice", Kit.inset(b, -1.8), R, R + 1.6, marble)
	Kit.parapet(model, Kit.inset(b, -0.6), R + 1.6, 3.2, stone)
	local sills = {}
	for level = 0, c.Storeys - 1 do
		table.insert(sills, P + level * H + 3.5)
	end
	local front: Kit.Face = { Axis = "Z", At = b.MaxZ, Out = 1 }
	local backFace: Kit.Face = { Axis = "Z", At = b.MinZ, Out = -1 }
	local west: Kit.Face = { Axis = "X", At = b.MinX, Out = -1 }
	local east: Kit.Face = { Axis = "X", At = b.MaxX, Out = 1 }
	local spec: Kit.WindowSpec = { Width = 4.4, Height = 8, Spacing = 10, Sills = sills, Lintel = true }
	report.Windows += Kit.windows(model, front, b.MinX + 4, -50, spec)
	report.Windows += Kit.windows(model, front, 50, b.MaxX - 4, spec)
	report.Windows += Kit.windows(model, front, -46, 46, {
		Width = 4.4,
		Height = 8,
		Spacing = 12,
		Sills = { sills[2], sills[3] },
		Lintel = true,
	})
	local plain: Kit.WindowSpec = { Width = 4.4, Height = 8, Spacing = 13, Sills = sills }
	report.Windows += Kit.windows(model, backFace, b.MinX + 4, b.MaxX - 4, {
		Width = 4.4,
		Height = 8,
		Spacing = 13,
		Sills = sills,
		Skip = { { -8, 8 } },
	})
	report.Windows += Kit.windows(model, west, b.MinZ + 4, b.MaxZ - 4, plain)
	report.Windows += Kit.windows(model, east, b.MinZ + 4, b.MaxZ - 4, plain)

	-- Portico: eight columns, entablature with the inscription, pediment with the emblem.
	local porticoFront = c.Forecourt.MinZ - 2
	for i = 0, 7 do
		Kit.column(model, -42 + i * 12, porticoFront - 2.6, P, P + 36, 4.4, marble)
	end
	local entablature = Kit.box(model, "Entablature", -48, P + 36, b.MaxZ, 48, P + 40, porticoFront, marble)
	Kit.inscription(entablature, { "GENERAL PEOPLE'S CONGRESS" }, Color3.fromRGB(150, 120, 60), Enum.NormalId.Back)
	Kit.slab(model, "PorticoCeiling", Kit.rect(-48, 48, b.MaxZ, porticoFront), P + 35.4, P + 36, marble)
	Kit.pediment(model, front, -49, 49, P + 40, 12, 0, porticoFront - b.MaxZ, stone)
	Kit.emblem(model, { Axis = "Z", At = porticoFront, Out = 1 }, 0, P + 44.4, 7, 0.05)

	-- Dome over the chamber: stylobate, ring of columns, drum, copper dome, lantern and flag.
	local cz = (room.MinZ + room.MaxZ) / 2
	local roofTop = R + 1.6
	local d = c.DomeDiameter
	Kit.drum(model, "Stylobate", 0, cz, roofTop, roofTop + 1, d + 12, granite)
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
