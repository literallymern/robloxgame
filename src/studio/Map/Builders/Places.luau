--!strict
-- Footprints of the cities, facilities and border crossings: a coloured outline on the ground,
-- a floating name over each place, and the placeholder blocks of the Gundiville government
-- district that are not built yet. (Name signs at the roads are built with the other road signs.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Heightfield = require(script.Parent.Parent.Heightfield)
local Util = require(script.Parent.Util)
local GovernmentDistrict = require(ReplicatedStorage.Shared.Config.GovernmentDistrict)

local Places = {}

local OUTLINE_COLOURS: { [string]: Color3 } = {
	City = Color3.fromRGB(245, 245, 245),
	Facility = Color3.fromRGB(240, 160, 60),
	Crossing = Color3.fromRGB(220, 60, 60),
}
local MAX_BAR = 2000

local function outline(parent: Instance, place: any, groundY: number)
	local r = place.Rect
	local colour = OUTLINE_COLOURS[place.Kind]
	local options: Util.PartOptions = { Color = colour, Material = Enum.Material.Neon, Decoration = true }
	local y = groundY + 0.15
	local edges = {
		{ Vector3.new(r.MinX, y, r.MinZ), Vector3.new(r.MaxX, y, r.MinZ) },
		{ Vector3.new(r.MaxX, y, r.MinZ), Vector3.new(r.MaxX, y, r.MaxZ) },
		{ Vector3.new(r.MaxX, y, r.MaxZ), Vector3.new(r.MinX, y, r.MaxZ) },
		{ Vector3.new(r.MinX, y, r.MaxZ), Vector3.new(r.MinX, y, r.MinZ) },
	}
	for _, edge in edges do
		local a, b = edge[1], edge[2]
		local pieces = math.ceil((b - a).Magnitude / MAX_BAR)
		for k = 1, pieces do
			Util.strip(parent, "Outline", a:Lerp(b, (k - 1) / pieces), a:Lerp(b, k / pieces), 2, 0.3, options)
		end
	end
end

-- The placeholder ids that the built government district replaces, if it exists under `map`.
function Places.replacedByDistrict(map: Instance): { [string]: boolean }
	local replaced: { [string]: boolean } = {}
	local built = map:FindFirstChild("GovernmentDistrict")
	if built and built:GetAttribute("GeneratedBy") == GovernmentDistrict.GeneratedBy then
		for _, id in GovernmentDistrict.Replaces do
			replaced[id] = true
		end
	end
	return replaced
end

-- One placeholder block of the government district (a box, or a slab for open areas).
function Places.placeholder(block: any, parent: Instance, cityY: number): BasePart
	local r = block.Rect
	local cx, cz = (r.MinX + r.MaxX) / 2, (r.MinZ + r.MaxZ) / 2
	local w, d = r.MaxX - r.MinX, r.MaxZ - r.MinZ
	local part
	if block.Height > 0 then
		part = Util.part(
			parent,
			block.Id,
			CFrame.new(cx, cityY + block.Height / 2, cz),
			Vector3.new(w, block.Height, d),
			{ Color = Color3.fromRGB(214, 206, 190), Material = Enum.Material.SmoothPlastic }
		)
		Util.label(part, `{block.Name} (placeholder)`, block.Height / 2 + 8, 900, 300)
	else
		part = Util.part(
			parent,
			block.Id,
			CFrame.new(cx, cityY, cz), -- top surface 0.2 above the ground
			Vector3.new(w, 0.4, d),
			{ Color = Color3.fromRGB(190, 182, 168), Material = Enum.Material.Concrete }
		)
		Util.label(part, block.Name, 6, 500, 220)
	end
	part:SetAttribute("Placeholder", true)
	part:SetAttribute("PlaceName", block.Name)
	return part
end

function Places.build(hf: Heightfield.Heightfield, layout: any, parent: Instance): number
	local folder = Util.folder(parent, "Places")
	local total = 0
	for _, place in layout.Places do
		if place.Kind == "Plot" then
			continue
		end
		local groundY = hf.land.placeGround[place.Id]
		local model = Instance.new("Model")
		model.Name = place.Id
		model:SetAttribute("PlaceName", place.Name)
		model:SetAttribute("Kind", place.Kind)
		model:SetAttribute("GroundY", groundY)
		outline(model, place, groundY)
		local r = place.Rect
		local marker = Util.part(
			model,
			"NameMarker",
			CFrame.new((r.MinX + r.MaxX) / 2, groundY + 1, (r.MinZ + r.MaxZ) / 2),
			Vector3.new(1, 1, 1),
			{ Transparency = 1, Decoration = true }
		)
		local big = place.Kind == "City"
		Util.label(marker, place.Name, if big then 120 else 50, if big then 4000 else 1500, if big then 320 else 240)
		model.Parent = folder
		total += 6
	end

	-- Gundiville government district placeholders. Blocks that the built district replaces
	-- (Milestone 3, StudioTools.BuildGundiville) are left out while Map.GovernmentDistrict exists.
	local district = Util.folder(parent, "GundivillePlaceholders")
	local cityY = hf.land.placeGround.Gundiville
	local replaced = Places.replacedByDistrict(parent)
	for _, block in layout.GundivillePlaceholders do
		if not replaced[block.Id] then
			Places.placeholder(block, district, cityY)
			total += 1
		end
	end
	return total
end

return Places
