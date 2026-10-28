--!strict
-- Streets of the government district: asphalt carriageways, raised sidewalks with kerbs, the
-- planted median of the ceremonial avenue with its trees and double street lights, dashed
-- centre lines, zebra crossings and street name signs. The avenue meets N5 at the south edge
-- of the city and the main street meets N4 at the east edge.

local Kit = require(script.Parent.Kit)
local Util = require(script.Parent.Parent.Map.Builders.Util)

local Streets = {}

type Rect = Kit.Rect

local DASH, GAP = 8, 12

local function inside(x: number, z: number, list: { Rect }, margin: number): boolean
	for _, r in list do
		if x > r.MinX - margin and x < r.MaxX + margin and z > r.MinZ - margin and z < r.MaxZ + margin then
			return true
		end
	end
	return false
end

-- Carriageways of the other streets: junction areas where no lines are painted.
local function others(district: any, street: any): { Rect }
	local list = {}
	for _, s in district.Streets do
		if s ~= street then
			for _, c in s.Carriageways do
				table.insert(list, c)
			end
		end
	end
	return list
end

local function nameSign(parent: Instance, base: Vector3, name: string, along: Vector3): number
	local metal = Kit.Style.Iron
	Util.cylinder(parent, "SignPost", base, base + Vector3.new(0, 10, 0), 0.35, metal)
	Kit.add(1)
	local dir = Vector3.new(along.X, 0, along.Z).Unit
	local centre = base + Vector3.new(0, 9.2, 0) + dir * 2.6
	-- The plate faces across the street, readable from both sides.
	local plate = Util.part(
		parent,
		"StreetName",
		CFrame.lookAt(centre, centre + Vector3.new(-dir.Z, 0, dir.X)),
		Vector3.new(5.6, 1.1, 0.12),
		{ Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(28, 64, 128) }
	)
	Kit.add(1)
	Kit.inscription(plate, { name }, Color3.fromRGB(255, 255, 255), Enum.NormalId.Front)
	Kit.inscription(plate, { name }, Color3.fromRGB(255, 255, 255), Enum.NormalId.Back)
	return 2
end

function Streets.build(district: any, parent: Instance): { [string]: number }
	local folder = Kit.folder(parent, "Streets")
	local ground = district.GroundY
	local roadTop, walkTop = ground + district.RoadTop, ground + district.WalkTop
	local report = { Asphalt = 0, Sidewalks = 0, Median = 0, Lines = 0, Crosswalks = 0, Trees = 0, Lamps = 0 }

	-- 1. Asphalt: every carriageway, without overlaps (the first street wins at a junction).
	local asphalt: { Rect } = {}
	for _, street in district.Streets do
		for _, c in street.Carriageways do
			for _, piece in Kit.subtractAll({ c }, asphalt) do
				Kit.slab(folder, "Asphalt", piece, ground - 1, roadTop, Kit.Style.Asphalt)
				table.insert(asphalt, piece)
				report.Asphalt += 1
			end
		end
	end

	-- 2. Sidewalks: the rest of each street, minus asphalt, medians and earlier sidewalks.
	local walks: { Rect } = {}
	local medians: { Rect } = {}
	for _, street in district.Streets do
		if street.Median then
			table.insert(medians, street.Median)
		end
	end
	for _, street in district.Streets do
		local pieces = Kit.subtractAll({ street.Rect }, asphalt)
		pieces = Kit.subtractAll(pieces, medians)
		pieces = Kit.subtractAll(pieces, walks)
		for _, piece in pieces do
			if piece.MaxX - piece.MinX < 0.5 or piece.MaxZ - piece.MinZ < 0.5 then
				continue
			end
			Kit.slab(folder, "Sidewalk", piece, ground - 0.6, walkTop, Kit.Style.Paving)
			table.insert(walks, piece)
			report.Sidewalks += 1
		end
	end

	-- 3. The avenue median: lawn with kerbs, trees and double street lights.
	local avenue = district.Avenue
	for _, street in district.Streets do
		if not street.Median then
			continue
		end
		local pieces = Kit.subtractAll({ street.Median }, asphalt)
		pieces = Kit.subtractAll(pieces, walks)
		for _, piece in pieces do
			Kit.slab(folder, "MedianKerb", piece, ground - 0.6, walkTop - 0.1, Kit.Style.Kerb)
			Kit.slab(folder, "MedianLawn", Kit.inset(piece, 0.6), walkTop - 0.1, walkTop, Kit.Style.Lawn)
			report.Median += 2
			local length = piece.MaxZ - piece.MinZ
			local trees = math.floor((length - 12) / avenue.TreeSpacing)
			for i = 0, trees do
				local z = piece.MinZ + 6 + i * avenue.TreeSpacing + (length - 12 - trees * avenue.TreeSpacing) / 2
				-- Lamps stand halfway between two trees, every second gap.
				Kit.tree(folder, Vector3.new(0, walkTop, z), avenue.TreeHeight, i + 1)
				report.Trees += 1
				local lampZ = z + avenue.TreeSpacing / 2
				if i < trees and i % 2 == 0 and lampZ < piece.MaxZ - 4 then
					-- Double lamps; with the one-armed imported lamp, alternate the sides.
					local side = if report.Lamps % 2 == 0 then 1 else -1
					Kit.lamp(
						folder,
						Vector3.new(0, walkTop, lampZ),
						16,
						{ Vector3.new(side, 0, 0), Vector3.new(-side, 0, 0) },
						1
					)
					report.Lamps += 1
				end
			end
		end
	end

	-- 4. Dashed centre lines, interrupted at junctions.
	local paint = Kit.Style.Paint
	for _, street in district.Streets do
		local cross = others(district, street)
		for _, c in street.Carriageways do
			local along0 = if street.Axis == "X" then c.MinX else c.MinZ
			local along1 = if street.Axis == "X" then c.MaxX else c.MaxZ
			for _, line in street.CentreLines do
				local acrossMin = if street.Axis == "X" then c.MinZ else c.MinX
				local acrossMax = if street.Axis == "X" then c.MaxZ else c.MaxX
				if line <= acrossMin or line >= acrossMax then
					continue
				end
				local s = along0 + 4
				while s + DASH < along1 - 4 do
					local mx = if street.Axis == "X" then s + DASH / 2 else line
					local mz = if street.Axis == "X" then line else s + DASH / 2
					if not inside(mx, mz, cross, 3) then
						if street.Axis == "X" then
							Kit.box(
								folder,
								"Line",
								s,
								roadTop,
								line - 0.25,
								s + DASH,
								roadTop + 0.04,
								line + 0.25,
								paint
							)
						else
							Kit.box(
								folder,
								"Line",
								line - 0.25,
								roadTop,
								s,
								line + 0.25,
								roadTop + 0.04,
								s + DASH,
								paint
							)
						end
						report.Lines += 1
					end
					s += DASH + GAP
				end
			end
		end
	end

	-- 5. Zebra crossings: stripes along the direction of travel, across the whole carriageway.
	for _, street in district.Streets do
		for _, at in street.Crosswalks do
			for _, c in street.Carriageways do
				local along0 = if street.Axis == "X" then c.MinX else c.MinZ
				local along1 = if street.Axis == "X" then c.MaxX else c.MaxZ
				if at - 3 < along0 or at + 3 > along1 then
					continue
				end
				local acrossMin = if street.Axis == "X" then c.MinZ else c.MinX
				local acrossMax = if street.Axis == "X" then c.MaxZ else c.MaxX
				local w = acrossMax - acrossMin
				local stripes = math.floor((w - 1) / 2.5)
				local first = acrossMin + (w - (stripes * 2.5 - 1)) / 2
				for k = 0, stripes - 1 do
					local a = first + k * 2.5
					if street.Axis == "X" then
						Kit.box(folder, "Zebra", at - 3, roadTop, a, at + 3, roadTop + 0.04, a + 1.5, paint)
					else
						Kit.box(folder, "Zebra", a, roadTop, at - 3, a + 1.5, roadTop + 0.04, at + 3, paint)
					end
				end
				report.Crosswalks += 1
			end
		end
	end

	-- 6. Street name signs at the start of the named streets.
	for _, street in district.Streets do
		if street.Name then
			local r = street.Rect
			if street.Axis == "Z" then
				nameSign(folder, Vector3.new(r.MaxX - 2, walkTop, r.MinZ + 10), street.Name, Vector3.new(0, 0, 1))
				nameSign(folder, Vector3.new(r.MinX + 2, walkTop, r.MaxZ - 14), street.Name, Vector3.new(0, 0, -1))
			else
				nameSign(folder, Vector3.new(r.MinX + 40, walkTop, r.MinZ + 2), street.Name, Vector3.new(1, 0, 0))
				nameSign(folder, Vector3.new(r.MaxX - 14, walkTop, r.MaxZ - 2), street.Name, Vector3.new(-1, 0, 0))
			end
		end
	end
	return report
end

return Streets
