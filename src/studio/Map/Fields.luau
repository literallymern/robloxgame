--!strict
--!native
-- Farm fields in the farming zones of MapLayout: a patchwork of rectangles of varying size with
-- tracks and hedges between them, kept off roads, the river, lakes, places and steep ground.
-- Crop fields show rows in the terrain (4 studs of crop, 4 studs of soil). Pastures are fenced.
-- Tobacco drying barns stand at the end of some tobacco fields. Pure Luau, tested offline.

local Geometry = require(script.Parent.Geometry)
local Hash = require(script.Parent.Hash)

export type Field = {
	Id: number,
	Crop: string,
	Zone: string,
	MinX: number,
	MaxX: number,
	MinZ: number,
	MaxZ: number,
	AlongX: boolean, -- rows run along X (the field is wider than deep)
	Fence: boolean,
}

export type Barn = {
	X: number,
	Z: number,
	Width: number, -- along the barn's long side
	Depth: number,
	AlongX: boolean, -- the long side runs along X
	Field: number,
}

export type Fields = {
	list: { Field },
	barns: { Barn },
	-- The field at a point (nil outside fields) and whether the point is on a crop row.
	-- Inside a barn yard it returns the field and nil.
	cropAt: (x: number, z: number) -> (Field?, boolean?),
	gap: number,
}

local CELL = 128
local ROW = 4 -- width of a crop row and of the soil between rows (one terrain voxel)
local BARN_WIDTH, BARN_DEPTH, YARD = 30, 16, 6

local Fields = {}

local function key(cx: number, cz: number): number
	return (cx + 1000) * 4096 + (cz + 1000)
end

function Fields.new(layout: any, land: any, roads: any, river: any, lakes: any): Fields
	local farming = layout.Farming
	local list: { Field } = {}
	local barns: { Barn } = {}
	if not farming then
		return {
			list = list,
			barns = barns,
			cropAt = function(_x: number, _z: number): (Field?, boolean?)
				return nil, nil
			end,
			gap = 0,
		}
	end
	local gap: number = farming.Gap
	local maxSlope: number = farming.MaxSlope
	local clearance: number = farming.RoadClearance

	local function snap(v: number): number
		return math.floor(v / ROW + 0.5) * ROW
	end

	local function suitable(minX: number, maxX: number, minZ: number, maxZ: number): boolean
		for _, place in layout.Places do
			local r = place.Rect
			if minX < r.MaxX + 20 and r.MinX - 20 < maxX and minZ < r.MaxZ + 20 and r.MinZ - 20 < maxZ then
				return false
			end
		end
		local lo, hi = math.huge, -math.huge
		local nx = math.max(2, math.ceil((maxX - minX) / 24))
		local nz = math.max(2, math.ceil((maxZ - minZ) / 24))
		for i = 0, nx do
			local x = minX + (maxX - minX) * i / nx
			for j = 0, nz do
				local z = minZ + (maxZ - minZ) * j / nz
				local e = roads.nearest(x, z)
				if e and e < clearance then
					return false
				end
				local d, _, _, halfWidth = river.nearest(x, z)
				if d - halfWidth - river.bankWidth < 30 then
					return false
				end
				if lakes.shoreDistance(x, z) < 25 then
					return false
				end
				local h = land.height(x, z)
				lo = math.min(lo, h)
				hi = math.max(hi, h)
			end
		end
		return hi - lo <= maxSlope * math.max(maxX - minX, maxZ - minZ)
	end

	local function pickCrop(mix: any, roll: number): string
		local names: { string } = {}
		for name in mix do
			table.insert(names, name)
		end
		table.sort(names)
		local total = 0
		for _, name in names do
			total += mix[name]
		end
		local sum = 0
		for _, name in names do
			sum += mix[name] / total
			if roll < sum then
				return name
			end
		end
		return names[#names]
	end

	local function add(crop: string, zone: string, minX: number, maxX: number, minZ: number, maxZ: number)
		local config = farming.Crops[crop]
		table.insert(list, {
			Id = #list + 1,
			Crop = crop,
			Zone = zone,
			MinX = minX,
			MaxX = maxX,
			MinZ = minZ,
			MaxZ = maxZ,
			AlongX = maxX - minX >= maxZ - minZ,
			Fence = config ~= nil and config.Fence == true,
		})
	end

	for zoneIndex, zone in layout.Zones do
		local mix = zone.Farming and farming.Mixes[zone.Farming]
		if not mix then
			continue
		end
		local r = zone.Rect
		local wMin, wMax = farming.FieldWidth[1], farming.FieldWidth[2]
		local dMin, dMax = farming.FieldDepth[1], farming.FieldDepth[2]
		local x = r.MinX
		local column = 0
		while x < r.MaxX - wMin * 0.6 do
			column += 1
			local x2 = snap(x + Hash.range(zoneIndex, column, 11, wMin, wMax))
			if r.MaxX - x2 < wMin * 0.6 then
				x2 = r.MaxX
			end
			local z = r.MinZ
			local row = 0
			while z < r.MaxZ - dMin * 0.6 do
				row += 1
				local z2 = snap(z + Hash.range(zoneIndex * 97 + column, row, 12, dMin, dMax))
				if r.MaxZ - z2 < dMin * 0.6 then
					z2 = r.MaxZ
				end
				local minX, maxX = x + gap / 2, x2 - gap / 2
				local minZ, maxZ = z + gap / 2, z2 - gap / 2
				if suitable(minX, maxX, minZ, maxZ) then
					local crop = pickCrop(mix, Hash.unit(zoneIndex * 97 + column, row, 13))
					add(crop, zone.Id, minX, maxX, minZ, maxZ)
				end
				z = z2
			end
			x = x2
		end
	end

	-- Places that are fields themselves (the tobacco fields property).
	for _, place in layout.Places do
		if place.Crop then
			local r = place.Rect
			add(place.Crop, place.Id, r.MinX, r.MaxX, r.MinZ, r.MaxZ)
		end
	end

	-- Barns at the end of some tobacco fields in the farming zones, spread over the list.
	local placeIds: { [string]: boolean } = {}
	for _, place in layout.Places do
		placeIds[place.Id] = true
	end
	local candidates: { Field } = {}
	for _, field in list do
		if field.Crop == "Tobacco" and not placeIds[field.Zone] then
			table.insert(candidates, field)
		end
	end
	local wanted = math.min(farming.Barns or 0, #candidates)
	for k = 1, wanted do
		local field = candidates[math.floor((k - 0.5) * #candidates / wanted) + 1]
		local alongX = not field.AlongX -- the barn stands across the end of the rows
		local atMax = Hash.unit(field.Id, k, 14) < 0.5
		local x, z
		if field.AlongX then
			x = if atMax then field.MaxX - BARN_DEPTH / 2 - YARD else field.MinX + BARN_DEPTH / 2 + YARD
			z = (field.MinZ + field.MaxZ) / 2
		else
			x = (field.MinX + field.MaxX) / 2
			z = if atMax then field.MaxZ - BARN_DEPTH / 2 - YARD else field.MinZ + BARN_DEPTH / 2 + YARD
		end
		table.insert(barns, {
			X = x,
			Z = z,
			Width = BARN_WIDTH,
			Depth = BARN_DEPTH,
			AlongX = alongX,
			Field = field.Id,
		})
	end

	-- Spatial index.
	local cells: { [number]: { number } } = {}
	for _, field in list do
		for cx = math.floor(field.MinX / CELL), math.floor(field.MaxX / CELL) do
			for cz = math.floor(field.MinZ / CELL), math.floor(field.MaxZ / CELL) do
				local k = key(cx, cz)
				local ids = cells[k]
				if ids then
					table.insert(ids, field.Id)
				else
					cells[k] = { field.Id }
				end
			end
		end
	end

	local function inBarnYard(x: number, z: number): boolean
		for _, barn in barns do
			local hw = (if barn.AlongX then barn.Width else barn.Depth) / 2 + YARD
			local hd = (if barn.AlongX then barn.Depth else barn.Width) / 2 + YARD
			if math.abs(x - barn.X) <= hw and math.abs(z - barn.Z) <= hd then
				return true
			end
		end
		return false
	end

	local function cropAt(x: number, z: number): (Field?, boolean?)
		local ids = cells[key(math.floor(x / CELL), math.floor(z / CELL))]
		if not ids then
			return nil, nil
		end
		for _, id in ids do
			local f = list[id]
			if x >= f.MinX and x <= f.MaxX and z >= f.MinZ and z <= f.MaxZ then
				if f.Crop == "Tobacco" and inBarnYard(x, z) then
					return f, nil
				end
				local across = if f.AlongX then z - f.MinZ else x - f.MinX
				return f, math.floor(across / ROW) % 2 == 0
			end
		end
		return nil, nil
	end

	return {
		list = list,
		barns = barns,
		cropAt = cropAt,
		gap = gap,
	}
end

-- Exposed for tests: the rectangle a barn stands on.
function Fields.barnRect(barn: Barn): Geometry.Rect
	local hw = (if barn.AlongX then barn.Width else barn.Depth) / 2
	local hd = (if barn.AlongX then barn.Depth else barn.Width) / 2
	return { MinX = barn.X - hw, MaxX = barn.X + hw, MinZ = barn.Z - hd, MaxZ = barn.Z + hd }
end

return Fields
