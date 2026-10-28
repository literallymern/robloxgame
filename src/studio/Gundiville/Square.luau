--!strict
-- The main square: a ceremonial and market square (encyclopedia, Gundiville). Granite bands on
-- light paving, market stalls along the east and west edges, open parade space in the middle,
-- a row of national flags in front of the Congress steps, lamps, benches and corner trees.
-- The statue platform on the ceremonial axis is built by Statue.

local Kit = require(script.Parent.Kit)
local Util = require(script.Parent.Parent.Map.Builders.Util)

local Square = {}

local AWNINGS = {
	Color3.fromRGB(176, 52, 46),
	Color3.fromRGB(46, 112, 72),
	Color3.fromRGB(40, 84, 150),
	Color3.fromRGB(214, 160, 48),
}
local GOODS = {
	Color3.fromRGB(226, 128, 40), -- oranges
	Color3.fromRGB(196, 54, 44), -- tomatoes
	Color3.fromRGB(232, 206, 92), -- maize
	Color3.fromRGB(120, 160, 64), -- greens
	Color3.fromRGB(150, 98, 60), -- tobacco
}

local function stall(parent: Instance, x: number, z: number, y: number, facing: number, index: number): number
	-- facing: +1 = counter towards +X, -1 = towards -X. Stall is 10 along Z and 9 deep.
	local front, back = x + facing * 4.5, x - facing * 4.5
	local fabric = { Material = Enum.Material.Fabric, Color = AWNINGS[1 + index % #AWNINGS] }
	for _, px in { front, back } do
		for _, pz in { z - 4.8, z + 4.8 } do
			Kit.box(parent, "StallPost", px - 0.2, y, pz - 0.2, px + 0.2, y + 8.4, pz + 0.2, Kit.Style.DarkWood)
		end
	end
	local counterFront = front - facing * 0.3
	Kit.box(
		parent,
		"StallCounter",
		counterFront,
		y,
		z - 4.6,
		counterFront - facing * 2.6,
		y + 3.2,
		z + 4.6,
		Kit.Style.Wood
	)
	-- Sloping awning from the back (higher) to the front.
	local centre = Vector3.new(x, y + 8.6, z)
	local awning = Util.part(
		parent,
		"StallAwning",
		CFrame.new(centre) * CFrame.Angles(0, 0, facing * math.rad(-12)),
		Vector3.new(10.6, 0.25, 11.2),
		fabric
	)
	awning.CastShadow = true
	Kit.add(1)
	Kit.box(parent, "StallBack", back - facing * 0.1, y, z - 4.8, back + facing * 0.15, y + 6, z + 4.8, fabric)
	for k = 0, 1 do
		local colour = GOODS[1 + (index * 2 + k) % #GOODS]
		local gz = z - 2.2 + k * 4.4
		Kit.box(
			parent,
			"Goods",
			counterFront - facing * 0.4,
			y + 3.2,
			gz - 1.6,
			counterFront - facing * 2.2,
			y + 4.1,
			gz + 1.6,
			{ Material = Enum.Material.Pebble, Color = colour }
		)
	end
	return 10
end

function Square.build(district: any, parent: Instance): { [string]: number }
	local folder = Kit.folder(parent, "Square")
	local sq = district.Square
	local r = sq.Rect
	local ground = district.GroundY
	local top = ground + district.WalkTop
	local report = { Stalls = 0, Flags = 0, Lamps = 0, Benches = 0, Trees = 0 }

	-- Paving between the side streets, up to the Congress forecourt.
	local paving = Kit.rect(-145, 145, r.MinZ, r.MaxZ)
	Kit.slab(folder, "Paving", paving, ground - 0.6, top, Kit.Style.Paving)
	-- Granite bands every 20 studs, and the wide ceremonial axis.
	local band = Kit.with(Kit.Style.Granite, { CanCollide = false })
	local platform = sq.StatuePlatform
	for x = -120, 120, 20 do
		if math.abs(x) < 10 then
			continue
		end
		Kit.box(folder, "Band", x - 0.6, top, r.MinZ + 2, x + 0.6, top + 0.03, r.MaxZ - 2, band)
	end
	for z = r.MinZ + 20, r.MaxZ - 20, 20 do
		if z > platform.MinZ - 2 and z < platform.MaxZ + 2 then
			continue
		end
		Kit.box(folder, "Band", -143, top, z - 0.6, -6, top + 0.03, z + 0.6, band)
		Kit.box(folder, "Band", 6, top, z - 0.6, 143, top + 0.03, z + 0.6, band)
	end
	local axis = Kit.with(Kit.Style.DarkGranite, { CanCollide = false })
	Kit.box(folder, "Axis", -6, top, platform.MaxZ + 1, 6, top + 0.035, r.MaxZ - 1, axis)
	Kit.box(folder, "Axis", -6, top, r.MinZ + 1, 6, top + 0.035, platform.MinZ - 1, axis)

	-- Market stalls along the west and east edges, counters facing the square.
	local n = sq.StallsPerSide
	local spacing = (r.MaxZ - r.MinZ - 30) / (n - 1)
	for i = 0, n - 1 do
		local z = r.MinZ + 15 + i * spacing
		stall(folder, r.MinX + 6, z, top, 1, i)
		stall(folder, r.MaxX - 6, z, top, -1, i + 3)
		report.Stalls += 2
	end

	-- National flags in front of the Congress steps.
	for _, x in sq.FlagpolesX do
		Kit.box(folder, "FlagBase", x - 1.2, top, r.MinZ + 8.8, x + 1.2, top + 1, r.MinZ + 11.2, Kit.Style.DarkGranite)
		Kit.flagpole(folder, Vector3.new(x, top + 1, r.MinZ + 10), 26, 8, Vector3.new(if x < 0 then 1 else -1, 0, 0))
		report.Flags += 1
	end

	-- Lamps between the stalls and the parade space, benches facing the statue.
	for _, x in { -112, 112 } do
		for _, z in { r.MinZ + 30, r.MinZ + 90, r.MaxZ - 90, r.MaxZ - 30 } do
			Kit.lamp(folder, Vector3.new(x, top, z), 13, { Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }, 2)
			report.Lamps += 1
		end
		for _, z in { r.MinZ + 60, (r.MinZ + r.MaxZ) / 2, r.MaxZ - 60 } do
			Kit.bench(folder, Vector3.new(x, top, z), Vector3.new(-x, 0, 0))
			report.Benches += 1
		end
	end

	-- Trees in round planters at the south corners of the square.
	for _, x in { -128, 128 } do
		local z = r.MaxZ - 12
		Kit.drum(folder, "TreePlanter", x, z, top, top + 1.4, 9, Kit.Style.Granite)
		Kit.drum(folder, "TreeSoil", x, z, top + 1.4, top + 1.5, 7.6, Kit.Style.Soil)
		Kit.tree(folder, Vector3.new(x, top + 1.5, z), 24, 4 + report.Trees)
		report.Trees += 1
	end
	return report
end

return Square
