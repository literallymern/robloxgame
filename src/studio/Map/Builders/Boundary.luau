--!strict
-- Invisible walls along the map edge. The mountains stop players almost everywhere, but
-- characters can climb steep terrain, and the passes and the river valley lead to the edge.

local Util = require(script.Parent.Util)

local Boundary = {}

local THICKNESS = 20
local SEGMENT = 2048 -- largest allowed part size

function Boundary.build(layout: any, parent: Instance): number
	local folder = Util.folder(parent, "Boundary")
	local half: number = layout.Bounds.Half
	local height: number = layout.Bounds.EdgeWallHeight
	local floorY: number = layout.Bounds.FloorY
	local pieces = math.ceil(2 * half / SEGMENT)
	local length = 2 * half / pieces
	local total = 0
	for _, side in { "East", "West", "South", "North" } do
		for k = 1, pieces do
			local along = -half + length * (k - 0.5)
			local edge = half - THICKNESS / 2
			local position, size
			if side == "East" or side == "West" then
				position = Vector3.new(if side == "East" then edge else -edge, floorY + height / 2, along)
				size = Vector3.new(THICKNESS, height, length)
			else
				position = Vector3.new(along, floorY + height / 2, if side == "South" then edge else -edge)
				size = Vector3.new(length, height, THICKNESS)
			end
			local wall = Util.part(folder, `EdgeWall{side}`, CFrame.new(position), size, { Transparency = 1 })
			wall.CanQuery = false
			wall.CanTouch = false
			wall.CastShadow = false
			total += 1
		end
	end
	return total
end

return Boundary
