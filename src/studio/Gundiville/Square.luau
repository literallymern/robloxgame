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
local STRIPE = Color3.fromRGB(236, 230, 214)

-- What the stalls sell: a sign and the colours of the goods in the crates and baskets.
type Trade = { Sign: string, Goods: { Color3 } }
local TRADES: { Trade } = {
	{
		Sign = "FRUIT",
		Goods = { Color3.fromRGB(226, 128, 40), Color3.fromRGB(236, 200, 60), Color3.fromRGB(120, 160, 64) },
	},
	{
		Sign = "VEGETABLES",
		Goods = { Color3.fromRGB(196, 54, 44), Color3.fromRGB(232, 206, 92), Color3.fromRGB(86, 130, 52) },
	},
	{
		Sign = "SPICES",
		Goods = { Color3.fromRGB(176, 70, 34), Color3.fromRGB(214, 160, 40), Color3.fromRGB(120, 80, 46) },
	},
	{
		Sign = "COFFEE & TEA",
		Goods = { Color3.fromRGB(86, 56, 36), Color3.fromRGB(62, 96, 50), Color3.fromRGB(130, 88, 54) },
	},
	{
		Sign = "TEXTILES",
		Goods = { Color3.fromRGB(40, 84, 150), Color3.fromRGB(176, 52, 46), Color3.fromRGB(230, 180, 40) },
	},
}

-- A market stall: four posts (the back ones taller), a striped awning sloping to the front with
-- a valance, side curtains, a counter with a cloth skirt and crates of goods, a shelf at the
-- back, baskets in front, a stool for the vendor and a sign with the trade. `facing`: +1 = the
-- counter faces +X, -1 = -X. The stall is 10 along Z and 9 deep.
local function stall(parent: Instance, x: number, z: number, y: number, facing: number, index: number): number
	local folder = Kit.folder(parent, "MarketStall")
	local trade = TRADES[1 + index % #TRADES]
	local front, back = x + facing * 4.5, x - facing * 4.5
	local colour = AWNINGS[1 + index % #AWNINGS]
	local fabric: Kit.Options = { Material = Enum.Material.Fabric, Color = colour }
	local wood = Kit.Style.DarkWood
	for _, px in { front, back } do
		local h = if px == front then 7.8 else 9.6
		for _, pz in { z - 4.8, z + 4.8 } do
			Kit.box(folder, "StallPost", px - 0.2, y, pz - 0.2, px + 0.2, y + h, pz + 0.2, wood)
		end
	end
	-- Striped awning: four strips, alternating the stall's colour and cream, tilted 12 degrees.
	local tilt = CFrame.Angles(0, 0, facing * math.rad(-12))
	for k = 0, 3 do
		local strip = Util.part(
			folder,
			"StallAwning",
			CFrame.new(x, y + 8.75, z - 4.2 + k * 2.8) * tilt,
			Vector3.new(10.6, 0.2, 2.8),
			{ Material = Enum.Material.Fabric, Color = if k % 2 == 0 then colour else STRIPE }
		)
		strip.CastShadow = true
		Kit.add(1)
	end
	local edge = x + facing * 5.2
	Kit.box(folder, "StallValance", edge - 0.05, y + 6.9, z - 5.6, edge + 0.05, y + 7.65, z + 5.6, fabric)
	for _, pz in { z - 4.85, z + 4.85 } do
		Kit.box(
			folder,
			"StallCurtain",
			math.min(back, x),
			y + 3.4,
			pz - 0.05,
			math.max(back, x),
			y + 8,
			pz + 0.05,
			fabric
		)
	end
	Kit.box(folder, "StallBack", back - facing * 0.1, y, z - 4.8, back + facing * 0.15, y + 6.4, z + 4.8, fabric)

	-- Counter with a top board and a cloth skirt, crates of goods on it.
	local c0 = front - facing * 0.3
	local c1 = c0 - facing * 2.6
	Kit.box(folder, "StallCounter", math.min(c0, c1), y, z - 4.4, math.max(c0, c1), y + 3, z + 4.4, Kit.Style.Wood)
	Kit.box(
		folder,
		"StallCounterTop",
		math.min(c0, c1) - 0.2,
		y + 3,
		z - 4.6,
		math.max(c0, c1) + 0.2,
		y + 3.25,
		z + 4.6,
		wood
	)
	local skirt = c0 + facing * 0.08
	Kit.box(folder, "StallSkirt", skirt - 0.04, y + 0.4, z - 4.4, skirt + 0.04, y + 2.9, z + 4.4, fabric)
	local mid = (c0 + c1) / 2
	for k = 0, 2 do
		local gz = z - 2.9 + k * 2.9
		local goods: Kit.Options =
			{ Material = Enum.Material.Pebble, Color = trade.Goods[1 + (k + index) % #trade.Goods] }
		Kit.box(folder, "Crate", mid - 1.1, y + 3.25, gz - 1.2, mid + 1.1, y + 4.05, gz + 1.2, Kit.Style.Wood)
		Kit.box(folder, "Goods", mid - 0.95, y + 4.05, gz - 1.05, mid + 0.95, y + 4.45, gz + 1.05, goods)
	end
	-- Shelf at the back with more goods.
	local s0 = back + facing * 0.2
	local s1 = s0 + facing * 1.4
	for _, h in { 2.4, 4.6 } do
		Kit.box(folder, "StallShelf", math.min(s0, s1), y + h - 0.15, z - 4, math.max(s0, s1), y + h, z + 4, wood)
		for k = 0, 1 do
			local gz = z - 2 + k * 4
			Kit.box(
				folder,
				"Goods",
				math.min(s0, s1) + 0.15,
				y + h,
				gz - 1.4,
				math.max(s0, s1) - 0.15,
				y + h + 0.9,
				gz + 1.4,
				{
					Material = Enum.Material.Fabric,
					Color = trade.Goods[1 + (k + index + 1) % #trade.Goods],
				}
			)
		end
	end
	-- Vendor's stool behind the counter.
	local sx = c1 - facing * 2.2
	local stool = Instance.new("Seat")
	stool.Name = "VendorStool"
	stool.Anchored = true
	stool.Size = Vector3.new(1.4, 0.3, 1.4)
	stool.CFrame = CFrame.lookAt(Vector3.new(sx, y + 2.6, z + 1), Vector3.new(sx + facing, y + 2.6, z + 1))
	stool.Material = Enum.Material.Wood
	stool.Color = Color3.fromRGB(122, 84, 54)
	stool.Parent = folder
	Kit.add(1)
	Util.cylinder(folder, "StoolLeg", Vector3.new(sx, y, z + 1), Vector3.new(sx, y + 2.45, z + 1), 0.4, wood)
	Kit.add(1)
	-- Baskets in front of the counter.
	for k, dz in { -2.6, 2.4 } do
		local bx = front + facing * 1.2
		Util.cylinder(folder, "Basket", Vector3.new(bx, y, z + dz), Vector3.new(bx, y + 1.3, z + dz), 1.8, {
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(176, 140, 86),
		})
		Util.cylinder(folder, "Goods", Vector3.new(bx, y + 1.3, z + dz), Vector3.new(bx, y + 1.5, z + dz), 1.5, {
			Material = Enum.Material.Pebble,
			Color = trade.Goods[1 + (k + index + 2) % #trade.Goods],
		})
		Kit.add(2)
	end
	-- Sign board under the front of the awning.
	local board = Kit.box(folder, "StallSign", front - 0.05, y + 6, z - 3, front + 0.05, y + 6.9, z + 3, wood)
	Kit.inscription(
		board,
		{ trade.Sign },
		Color3.fromRGB(240, 230, 200),
		if facing > 0 then Enum.NormalId.Right else Enum.NormalId.Left
	)
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
