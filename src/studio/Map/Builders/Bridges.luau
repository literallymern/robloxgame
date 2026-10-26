--!strict
-- Bridge decks where roads cross the river: a thicker concrete deck on the road's own line and
-- height, railings on both sides, and a pier in the river.

local Heightfield = require(script.Parent.Parent.Heightfield)
local Roads = require(script.Parent.Roads)
local Util = require(script.Parent.Util)

local Bridges = {}

local DECK_THICKNESS = 3
local RAIL_HEIGHT = 3.5

function Bridges.build(hf: Heightfield.Heightfield, parent: Instance): number
	local folder = Util.folder(parent, "Bridges")
	local total = 0
	local concrete: Util.PartOptions = {
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(160, 158, 150),
	}
	for _, bridge in hf.roads.bridges do
		local road = hf.roads.roads[bridge.RoadIndex]
		local model = Instance.new("Model")
		model.Name = `Bridge {bridge.Road}`
		model:SetAttribute("Road", bridge.Road)
		total += Roads.buildRuns(model, road, {
			Bridge = true,
			Thickness = DECK_THICKNESS,
			Part = concrete,
			First = bridge.First,
			Last = bridge.Last,
		})
		-- Railings along both edges.
		for i = bridge.First, bridge.Last - 1 do
			local a = Vector3.new(road.line.xs[i], road.profile[i], road.line.zs[i])
			local b = Vector3.new(road.line.xs[i + 1], road.profile[i + 1], road.line.zs[i + 1])
			local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
			local side = Vector3.new(-dir.Z, 0, dir.X) * (road.Width / 2 - 0.5)
			local up = Vector3.new(0, RAIL_HEIGHT, 0)
			for _, offset in { side, -side } do
				Util.strip(model, "Railing", a + offset + up, b + offset + up, 1, RAIL_HEIGHT, concrete)
				total += 1
			end
		end
		-- One pier in the middle of the river, across the deck.
		local mid, best = bridge.First, math.huge
		for i = bridge.First, bridge.Last - 1 do
			local d = (road.line.xs[i] - bridge.CrossX) ^ 2 + (road.line.zs[i] - bridge.CrossZ) ^ 2
			if d < best then
				mid, best = i, d
			end
		end
		local a = Vector3.new(road.line.xs[mid], road.profile[mid], road.line.zs[mid])
		local b = Vector3.new(road.line.xs[mid + 1], road.profile[mid + 1], road.line.zs[mid + 1])
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
		local _, waterY = hf.river.nearest(bridge.CrossX, bridge.CrossZ)
		local bedY = waterY - hf.river.drop - 12
		local deckBottom = road.profile[mid] - DECK_THICKNESS
		local height = deckBottom - bedY
		local centre = Vector3.new(bridge.CrossX, bedY + height / 2, bridge.CrossZ)
		Util.part(model, "Pier", CFrame.lookAt(centre, centre + flat), Vector3.new(road.Width - 6, height, 5), concrete)
		total += 1
		model.Parent = folder
		Util.yield()
	end
	return total
end

return Bridges
