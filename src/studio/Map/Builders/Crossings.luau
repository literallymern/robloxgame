--!strict
-- The two border crossings: a customs canopy over the road, a barrier, the customs office and,
-- at the south crossing, the truck inspection shed. Simple blocks for the blockout.

local Heightfield = require(script.Parent.Parent.Heightfield)
local Util = require(script.Parent.Util)

local Crossings = {}

local CANOPY_HEIGHT = 18

function Crossings.build(hf: Heightfield.Heightfield, layout: any, parent: Instance): number
	local folder = Util.folder(parent, "Crossings")
	local total = 0
	local concrete: Util.PartOptions = { Material = Enum.Material.Concrete, Color = Color3.fromRGB(200, 196, 186) }
	local metal: Util.PartOptions = { Material = Enum.Material.Metal, Color = Color3.fromRGB(120, 124, 130) }
	local red: Util.PartOptions = { Color = Color3.fromRGB(200, 40, 40) }

	for _, crossing in layout.Crossings do
		local model = Instance.new("Model")
		model.Name = `{crossing.Id}Crossing`
		local placeId = `{crossing.Id}Crossing`
		local groundY = hf.land.placeGround[placeId]
		local alongX = crossing.Axis == "X"
		-- World position from (position along the road, offset across the road).
		local function at(along: number, across: number, y: number): Vector3
			if alongX then
				return Vector3.new(along, y, crossing.RoadCentre + across)
			end
			return Vector3.new(crossing.RoadCentre + across, y, along)
		end
		local function size(along: number, across: number, height: number): Vector3
			return if alongX then Vector3.new(along, height, across) else Vector3.new(across, height, along)
		end

		-- Canopy: roof on four pillars, spanning the road.
		Util.part(
			model,
			"CanopyRoof",
			CFrame.new(at(crossing.Canopy, 0, groundY + CANOPY_HEIGHT + 1)),
			size(30, 64, 2),
			metal
		)
		for _, along in { -12, 12 } do
			for _, across in { -29, 29 } do
				Util.part(
					model,
					"CanopyPillar",
					CFrame.new(at(crossing.Canopy + along, across, groundY + CANOPY_HEIGHT / 2)),
					size(2, 2, CANOPY_HEIGHT),
					metal
				)
			end
		end
		-- Barrier across the road with a post on each side.
		Util.part(model, "Barrier", CFrame.new(at(crossing.Barrier, 0, groundY + 3.5)), size(1, 44, 1), red)
		for _, across in { -23, 23 } do
			Util.part(
				model,
				"BarrierPost",
				CFrame.new(at(crossing.Barrier, across, groundY + 2)),
				size(1.5, 1.5, 4),
				metal
			)
		end
		local function block(name: string, label: string, rect: any, height: number)
			local part = Util.part(
				model,
				name,
				CFrame.new((rect.MinX + rect.MaxX) / 2, groundY + height / 2, (rect.MinZ + rect.MaxZ) / 2),
				Vector3.new(rect.MaxX - rect.MinX, height, rect.MaxZ - rect.MinZ),
				concrete
			)
			part:SetAttribute("Placeholder", true)
			Util.label(part, label, height / 2 + 6, 700, 220)
		end
		block("CustomsOffice", "Customs Office (placeholder)", crossing.OfficeRect, 14)
		if crossing.InspectionRect then
			block("TruckInspection", "Truck Inspection (placeholder)", crossing.InspectionRect, 16)
		end
		model:SetAttribute("CrossingName", crossing.Name)
		model.Parent = folder
		total += 10
	end
	return total
end

return Crossings
