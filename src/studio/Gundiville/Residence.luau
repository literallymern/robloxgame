--!strict
-- The residence of the Leader of the Revolution: a walled, guarded compound with gardens,
-- set back north-east of the square (map plan: gate in the south wall). Behind the gate with
-- its guard posts and boom barrier, a drive leads to a turning circle with a fountain in front
-- of a white villa with a portico and a balcony. The entrance hall and the Leader's office are
-- walkable. The gate stands open and the barrier is raised; access control follows with the
-- institutional gameplay (Milestone 6).

local Kit = require(script.Parent.Kit)
local Util = require(script.Parent.Parent.Map.Builders.Util)

local Residence = {}

local COBBLES: Kit.Options = { Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(150, 140, 128) }
local SHUTTERS: Kit.Options = { Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(70, 96, 120) }
local LEATHER: Kit.Options = { Material = Enum.Material.Fabric, Color = Color3.fromRGB(92, 52, 36) }
local FLOWERS = {
	Color3.fromRGB(196, 40, 52),
	Color3.fromRGB(236, 196, 60),
	Color3.fromRGB(226, 120, 160),
	Color3.fromRGB(240, 240, 236),
}

local function chair(parent: Instance, name: string, position: Vector3, facing: Vector3, options: Kit.Options)
	local seat = Instance.new("Seat")
	seat.Name = name
	seat.Anchored = true
	seat.Size = Vector3.new(2.6, 0.6, 2.4)
	seat.CFrame = CFrame.lookAt(position, position + facing)
	seat.Material = options.Material or Enum.Material.Fabric
	seat.Color = options.Color or Color3.fromRGB(92, 52, 36)
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Parent = parent
	Util.part(
		parent,
		name .. "Back",
		CFrame.lookAt(position, position + facing) * CFrame.new(0, 1.6, 1.15),
		Vector3.new(2.6, 3, 0.4),
		options
	)
	Kit.add(2)
end

local function guardPost(parent: Instance, r: Kit.Rect, y: number, doorSide: number)
	-- A small booth: glazed above a counter towards the drive, door on the north side.
	local h = 9
	local plaster = Kit.Style.Plaster
	Kit.slab(parent, "BoothFloor", r, y - 0.2, y + 0.3, Kit.Style.Granite)
	local cx = (r.MinX + r.MaxX) / 2
	-- Wall away from the drive and the two end walls (the north one with the door).
	local outer = if doorSide > 0 then r.MinX + 0.4 else r.MaxX - 0.4
	Kit.wall(parent, "BoothWall", "Z", r.MinZ, r.MaxZ, outer, 0.8, y + 0.3, y + h, nil, plaster)
	Kit.wall(parent, "BoothWall", "X", r.MinX, r.MaxX, r.MaxZ - 0.4, 0.8, y + 0.3, y + h, {
		{ From = cx - 1.5, To = cx + 1.5, Bottom = y + 3.6, Top = y + 7.5 },
	}, plaster)
	Kit.wall(parent, "BoothWall", "X", r.MinX, r.MaxX, r.MinZ + 0.4, 0.8, y + 0.3, y + h, {
		{ From = cx - 1.6, To = cx + 1.6, Bottom = y + 0.3, Top = y + 7.5 },
	}, plaster)
	local inner = if doorSide > 0 then r.MaxX - 0.4 else r.MinX + 0.4
	Kit.box(parent, "BoothCounter", inner - 0.4, y + 0.3, r.MinZ + 0.8, inner + 0.4, y + 3.6, r.MaxZ - 0.8, plaster)
	Kit.box(parent, "BoothGlass", inner - 0.1, y + 3.6, r.MinZ + 0.8, inner + 0.1, y + h, r.MaxZ - 0.8, Kit.Style.Glass)
	Kit.box(parent, "BoothGlass", cx - 1.5, y + 3.6, r.MaxZ - 0.5, cx + 1.5, y + 7.5, r.MaxZ - 0.3, Kit.Style.Glass)
	Kit.slab(parent, "BoothRoof", Kit.inset(r, -1), y + h, y + h + 0.8, Kit.Style.Slate)
	local sx = inner + doorSide * 0.5
	local sign = Kit.box(
		parent,
		"BoothSign",
		sx - 0.1,
		y + h - 1.6,
		r.MinZ + 1.5,
		sx + 0.1,
		y + h - 0.3,
		r.MaxZ - 1.5,
		Kit.Style.DarkWood
	)
	Kit.inscription(
		sign,
		{ "GUARD POST" },
		Color3.fromRGB(240, 230, 200),
		if doorSide > 0 then Enum.NormalId.Right else Enum.NormalId.Left
	)
end

function Residence.build(district: any, parent: Instance): { [string]: number }
	local res = district.Residence
	local model = Kit.model(parent, "LeadersResidence", "Residence of the Leader of the Revolution")
	local G = district.GroundY
	local W = G + district.WalkTop
	local r = res.Rect
	local gx = res.Gate
	local plaster, ochre = Kit.Style.Plaster, Kit.Style.Ochre
	local report = { Windows = 0, Flags = 0, Trees = 0, Seats = 0 }

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
		local lantern = Kit.box(
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
		lantern:SetAttribute("RoNationLamp", true)
		local light = Instance.new("PointLight")
		light:SetAttribute("RoNationStreetLight", true)
		light.Enabled = false
		light.Range = 24
		light.Brightness = 1.5
		light.Color = Color3.fromRGB(255, 224, 180)
		light.Parent = lantern
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

	-- The villa: two storeys, white plaster, shutters, slate roof, portico with balcony.
	local F = W + 2
	local H = 12
	local R = F + 2 * H
	local t = 2
	local v = villa
	local doorX = gx
	Kit.slab(model, "VillaPlinth", Kit.inset(v, -0.8), W - 0.6, F, Kit.Style.Granite)
	Kit.wall(model, "Wall", "X", v.MinX, v.MaxX, v.MaxZ - t / 2, t, F, R, {
		{ From = doorX - 4, To = doorX + 4, Bottom = F, Top = F + 10 },
	}, plaster)
	Kit.wall(model, "Wall", "X", v.MinX, v.MaxX, v.MinZ + t / 2, t, F, R, nil, plaster)
	Kit.wall(model, "Wall", "Z", v.MinZ + t, v.MaxZ - t, v.MinX + t / 2, t, F, R, nil, plaster)
	Kit.wall(model, "Wall", "Z", v.MinZ + t, v.MaxZ - t, v.MaxX - t / 2, t, F, R, nil, plaster)
	Kit.slab(model, "Attic", Kit.inset(v, t), R - 1, R, plaster)
	Kit.band(model, "StringCourse", v, F + H - 0.3, F + H + 0.5, 0.4, ochre)
	Kit.band(model, "Cornice", v, R - 0.8, R + 0.2, 1, ochre)
	Kit.gableRoof(model, v, R, 11, "X", 1.5, Kit.Style.Slate)
	local gable = 11 * ((v.MaxZ - v.MinZ) / 2) / ((v.MaxZ - v.MinZ) / 2 + 1.5)
	Kit.pediment(model, { Axis = "X", At = v.MinX, Out = -1 }, v.MinZ, v.MaxZ, R, gable, -t, 0, plaster)
	Kit.pediment(model, { Axis = "X", At = v.MaxX, Out = 1 }, v.MinZ, v.MaxZ, R, gable, -t, 0, plaster)
	for _, x in { v.MinX + 30, v.MaxX - 30 } do
		Kit.box(model, "Chimney", x - 2, R + 4, v.MinZ + 16, x + 2, R + 14, v.MinZ + 20, plaster)
	end
	for _, corner in { { v.MinX, v.MinZ }, { v.MinX, v.MaxZ }, { v.MaxX, v.MinZ }, { v.MaxX, v.MaxZ } } do
		Kit.box(model, "Quoin", corner[1] - 1.4, F, corner[2] - 1.4, corner[1] + 1.4, R - 0.8, corner[2] + 1.4, ochre)
	end
	local spec: Kit.WindowSpec = {
		Width = 3.6,
		Height = 7.5,
		Spacing = 10,
		Sills = { F + 2.5, F + H + 2.5 },
		Trim = Kit.Style.Marble,
		Shutters = SHUTTERS,
	}
	local front: Kit.Face = { Axis = "Z", At = v.MaxZ, Out = 1 }
	local frontSpec = table.clone(spec)
	frontSpec.Skip = { { doorX - 15, doorX + 15 } }
	report.Windows += Kit.windows(model, front, v.MinX + 4, v.MaxX - 4, frontSpec)
	report.Windows += Kit.windows(model, { Axis = "Z", At = v.MinZ, Out = -1 }, v.MinX + 4, v.MaxX - 4, spec)
	report.Windows += Kit.windows(model, { Axis = "X", At = v.MinX, Out = -1 }, v.MinZ + 4, v.MaxZ - 4, spec)
	report.Windows += Kit.windows(model, { Axis = "X", At = v.MaxX, Out = 1 }, v.MinZ + 4, v.MaxZ - 4, spec)
	-- Portico: four columns carrying the balcony, French window behind it, emblem, flag.
	for _, dx in { -12, -4, 4, 12 } do
		Kit.column(model, doorX + dx, v.MaxZ + 6, F, F + H - 0.8, 2.6, Kit.Style.Marble)
	end
	Kit.box(model, "PorticoStep", doorX - 15, W - 0.2, v.MaxZ, doorX + 15, F, v.MaxZ + 8.5, Kit.Style.Granite)
	Kit.box(model, "PorticoStep", doorX - 15, W - 0.2, v.MaxZ + 8.5, doorX + 15, W + 1, v.MaxZ + 10, Kit.Style.Granite)
	Kit.faceBox(model, "Balcony", front, doorX - 15, doorX + 15, F + H - 0.8, F + H + 0.2, 0, 8.5, Kit.Style.Marble)
	Kit.faceBox(model, "Balustrade", front, doorX - 15, doorX + 15, F + H + 0.2, F + H + 3.2, 8, 8.5, Kit.Style.Marble)
	Kit.faceBox(model, "Balustrade", front, doorX - 15, doorX - 14.5, F + H + 0.2, F + H + 3.2, 0, 8, Kit.Style.Marble)
	Kit.faceBox(model, "Balustrade", front, doorX + 14.5, doorX + 15, F + H + 0.2, F + H + 3.2, 0, 8, Kit.Style.Marble)
	Kit.faceBox(
		model,
		"BalconyDoor",
		front,
		doorX - 3,
		doorX + 3,
		F + H + 0.2,
		F + H + 8.5,
		-0.2,
		0.15,
		Kit.Style.Glass
	)
	Kit.faceBox(model, "DoorFrame", front, doorX - 5, doorX - 4, F, F + 11, 0, 0.4, Kit.Style.DarkWood)
	Kit.faceBox(model, "DoorFrame", front, doorX + 4, doorX + 5, F, F + 11, 0, 0.4, Kit.Style.DarkWood)
	Kit.faceBox(model, "DoorFrame", front, doorX - 5, doorX + 5, F + 10, F + 11, 0, 0.4, Kit.Style.DarkWood)
	Kit.emblem(model, { Axis = "Z", At = v.MaxZ + 8.5, Out = 1 }, doorX, F + H + 1.7, 2.6, 0.05)
	for _, side in { -1, 1 } do
		Kit.flagpole(model, Vector3.new(doorX + side * 26, W, v.MaxZ + 16), 26, 8, Vector3.new(side, 0, 0))
		report.Flags += 1
	end

	-- Interior: entrance hall and the Leader's office; the rest of the villa is closed.
	local hall = Kit.rect(doorX - 20, doorX + 20, v.MaxZ - 30, v.MaxZ - t)
	local office = Kit.rect(hall.MaxX + 1, v.MaxX - 14, v.MinZ + 30, v.MaxZ - t)
	local ceiling = F + H - 1
	Kit.wall(model, "InnerWall", "Z", hall.MinZ - 1, hall.MaxZ, hall.MinX - 0.5, 1, F, ceiling, nil, plaster)
	Kit.wall(model, "InnerWall", "X", hall.MinX - 1, hall.MaxX + 1, hall.MinZ - 0.5, 1, F, ceiling, nil, plaster)
	Kit.wall(model, "InnerWall", "Z", office.MinZ - 1, office.MaxZ, hall.MaxX + 0.5, 1, F, ceiling, {
		{ From = hall.MaxZ - 12, To = hall.MaxZ - 6, Bottom = F, Top = F + 8.5 },
	}, plaster)
	Kit.wall(model, "InnerWall", "X", office.MinX, office.MaxX + 1, office.MinZ - 0.5, 1, F, ceiling, nil, plaster)
	Kit.wall(model, "InnerWall", "Z", office.MinZ - 1, office.MaxZ, office.MaxX + 0.5, 1, F, ceiling, nil, plaster)
	Kit.slab(model, "Floor", Kit.rect(hall.MinX, office.MaxX, office.MinZ, hall.MaxZ), F, F + 0.1, Kit.Style.Floor)
	Kit.slab(
		model,
		"Ceiling",
		Kit.rect(hall.MinX - 1, office.MaxX + 1, office.MinZ - 1, hall.MaxZ),
		ceiling,
		ceiling + 1,
		plaster
	)
	-- Hall: runner, emblem, flags, benches, light.
	Kit.slab(model, "Runner", Kit.rect(doorX - 3, doorX + 3, hall.MinZ, hall.MaxZ), F + 0.1, F + 0.2, Kit.Style.Carpet)
	Kit.emblem(model, { Axis = "Z", At = hall.MinZ, Out = 1 }, doorX, F + 6.5, 4, 0.2)
	for _, side in { -1, 1 } do
		Kit.flagpole(model, Vector3.new(doorX + side * 6, F + 0.1, hall.MinZ + 1.5), 9, 3, Vector3.new(side, 0, 0.3))
		Kit.bench(model, Vector3.new(hall.MinX + 1.4, F + 0.1, hall.MinZ + 8 + (side + 1) * 6), Vector3.new(1, 0, 0))
		report.Flags += 1
	end
	Kit.ceilingLight(model, doorX, (hall.MinZ + hall.MaxZ) / 2, ceiling, 4, 26)
	-- Office: desk with the Leader's chair, visitor chairs, flags and emblem behind the desk,
	-- bookshelves, a rug and a sofa corner.
	local ox = (office.MinX + office.MaxX) / 2
	local deskZ = office.MinZ + 12
	Kit.slab(
		model,
		"Rug",
		Kit.rect(ox - 12, ox + 12, office.MinZ + 6, office.MaxZ - 6),
		F + 0.1,
		F + 0.2,
		Kit.Style.Carpet
	)
	Kit.box(model, "Desk", ox - 6, F + 0.2, deskZ - 2, ox + 6, F + 3.4, deskZ + 2, Kit.Style.DarkWood)
	Kit.box(model, "DeskTop", ox - 6.3, F + 3.4, deskZ - 2.3, ox + 6.3, F + 3.7, deskZ + 2.3, Kit.Style.DarkWood)
	chair(model, "LeadersChair", Vector3.new(ox, F + 1.8, deskZ - 5), Vector3.new(0, 0, 1), LEATHER)
	for _, dx in { -3.5, 3.5 } do
		chair(model, "VisitorChair", Vector3.new(ox + dx, F + 1.5, deskZ + 5), Vector3.new(0, 0, -1), Kit.Style.Carpet)
	end
	report.Seats += 3
	local behind: Kit.Face = { Axis = "Z", At = office.MinZ, Out = 1 }
	Kit.emblem(model, behind, ox, F + 7, 4.4, 0.2)
	for _, side in { -1, 1 } do
		Kit.flagpole(model, Vector3.new(ox + side * 6, F + 0.2, office.MinZ + 1.6), 9, 3, Vector3.new(side, 0, 0.3))
		report.Flags += 1
		local shelfX = if side < 0 then office.MinX + 1 else office.MaxX - 1
		Kit.box(
			model,
			"Bookshelf",
			shelfX - 1,
			F + 0.1,
			office.MinZ + 6,
			shelfX + 1,
			F + 8.5,
			office.MinZ + 22,
			Kit.Style.DarkWood
		)
		for k = 0, 2 do
			Kit.box(
				model,
				"Books",
				shelfX - side * 1.05,
				F + 1.5 + k * 2.4,
				office.MinZ + 6.5,
				shelfX - side * 1.1,
				F + 3.2 + k * 2.4,
				office.MinZ + 21.5,
				{
					Material = Enum.Material.Fabric,
					Color = FLOWERS[1 + k],
					Decoration = true,
				}
			)
		end
	end
	local sofaZ = office.MaxZ - 9
	Kit.box(model, "CoffeeTable", ox - 3, F + 0.2, sofaZ - 2, ox + 3, F + 1.8, sofaZ + 2, Kit.Style.DarkWood)
	for _, side in { -1, 1 } do
		chair(model, "Sofa", Vector3.new(ox + side * 6, F + 1.4, sofaZ), Vector3.new(-side, 0, 0), LEATHER)
		report.Seats += 1
	end
	Kit.ceilingLight(model, ox, deskZ + 4, ceiling, 4, 26)
	Kit.ceilingLight(model, ox, sofaZ, ceiling, 3, 20)

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
	local gxz = Vector3.new(v.MinX + 30, W, gz)
	Kit.drum(model, "GazeboFloor", gxz.X, gxz.Z, W - 0.6, W + 0.8, 16, Kit.Style.Marble)
	for k = 0, 5 do
		local a = k * math.pi / 3
		local p = gxz + Vector3.new(math.cos(a) * 6.6, 0, math.sin(a) * 6.6)
		Util.cylinder(
			model,
			"GazeboColumn",
			p + Vector3.new(0, 0.8, 0),
			p + Vector3.new(0, 7.4, 0),
			0.9,
			Kit.Style.Marble
		)
		Kit.add(1)
	end
	-- The roof ring hides the lower half of the dome.
	Kit.drum(model, "GazeboRoof", gxz.X, gxz.Z, W + 7.4, W + 10.6, 16, Kit.Style.Plaster)
	Kit.ellipsoid(model, "GazeboDome", gxz + Vector3.new(0, 10.6, 0), Vector3.new(15, 6.4, 15), Kit.Style.Copper)
	Kit.bench(model, gxz + Vector3.new(0, 0.8, 4.4), Vector3.new(0, 0, -1))
	Kit.bench(model, gxz + Vector3.new(0, 0.8, -4.4), Vector3.new(0, 0, 1))

	model:SetAttribute("Height", R + 11 - G)
	return report
end

return Residence
