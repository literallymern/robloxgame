--!strict
-- The cargo airport blockout: runway with centre line, taxiway and links, cargo apron, and
-- placeholder blocks for the terminal, hangar and control tower.

local Heightfield = require(script.Parent.Parent.Heightfield)
local Util = require(script.Parent.Util)

local Airport = {}

local MAX_PIECE = 1200

-- A flat slab covering a rectangle, split into pieces no longer than MAX_PIECE.
local function slab(parent: Instance, name: string, rect: any, topY: number, options: Util.PartOptions): number
	local w, d = rect.MaxX - rect.MinX, rect.MaxZ - rect.MinZ
	local alongX = w >= d
	local length = if alongX then w else d
	local pieces = math.ceil(length / MAX_PIECE)
	for k = 1, pieces do
		local piece = length / pieces
		local cx = if alongX then rect.MinX + piece * (k - 0.5) else (rect.MinX + rect.MaxX) / 2
		local cz = if alongX then (rect.MinZ + rect.MaxZ) / 2 else rect.MinZ + piece * (k - 0.5)
		local size = if alongX then Vector3.new(piece, 1, d) else Vector3.new(w, 1, piece)
		Util.part(parent, name, CFrame.new(cx, topY - 0.5, cz), size, options)
	end
	return pieces
end

function Airport.build(hf: Heightfield.Heightfield, layout: any, parent: Instance): number
	local config = layout.Airport
	local folder = Util.folder(parent, "Airport")
	local groundY = hf.land.placeGround.CargoAirport
	local top = groundY + 0.3
	local total = 0
	local asphalt: Util.PartOptions = { Material = Enum.Material.Asphalt, Color = Color3.fromRGB(52, 52, 56) }
	local apron: Util.PartOptions = { Material = Enum.Material.Concrete, Color = Color3.fromRGB(150, 148, 142) }

	total += slab(folder, "Runway", config.Runway, top, asphalt)
	total += slab(folder, "Taxiway", config.Taxiway, top, asphalt)
	for _, link in config.TaxiwayLinks do
		total += slab(folder, "TaxiwayLink", link, top, asphalt)
	end
	total += slab(folder, "CargoApron", config.Apron, top, apron)

	-- Runway centre line.
	local runway = config.Runway
	local z = (runway.MinZ + runway.MaxZ) / 2
	local marking: Util.PartOptions = { Color = Color3.fromRGB(240, 240, 235), Decoration = true }
	local x = runway.MinX + 60
	while x + 30 < runway.MaxX - 60 do
		Util.part(folder, "RunwayLine", CFrame.new(x + 15, top + 0.03, z), Vector3.new(30, 0.1, 1.5), marking)
		total += 1
		x += 60
	end

	for _, building in config.Buildings do
		local r = building.Rect
		local part = Util.part(
			folder,
			building.Id,
			CFrame.new((r.MinX + r.MaxX) / 2, groundY + building.Height / 2, (r.MinZ + r.MaxZ) / 2),
			Vector3.new(r.MaxX - r.MinX, building.Height, r.MaxZ - r.MinZ),
			{ Color = Color3.fromRGB(205, 200, 188) }
		)
		part:SetAttribute("Placeholder", true)
		Util.label(part, `{building.Name} (placeholder)`, building.Height / 2 + 8, 900, 260)
		total += 1
	end
	return total
end

return Airport
