--!strict
-- A spatial grid that finds the line segments near a point quickly.
-- Each segment is stored in every cell its bounding box (plus a radius) touches.

export type SegmentGrid = {
	cellSize: number,
	cells: { [number]: { number } },
}

local SegmentGrid = {}

local OFFSET = 4096 -- keeps cell keys positive; the map is far smaller than OFFSET cells

local function key(cx: number, cz: number): number
	return (cx + OFFSET) * 2 * OFFSET + (cz + OFFSET)
end

function SegmentGrid.new(cellSize: number): SegmentGrid
	return { cellSize = cellSize, cells = {} }
end

-- Registers segment `id` running from A to B for all points within `radius` of it.
function SegmentGrid.insert(
	grid: SegmentGrid,
	id: number,
	ax: number,
	az: number,
	bx: number,
	bz: number,
	radius: number
)
	local size = grid.cellSize
	local x0 = math.floor((math.min(ax, bx) - radius) / size)
	local x1 = math.floor((math.max(ax, bx) + radius) / size)
	local z0 = math.floor((math.min(az, bz) - radius) / size)
	local z1 = math.floor((math.max(az, bz) + radius) / size)
	for cx = x0, x1 do
		for cz = z0, z1 do
			local k = key(cx, cz)
			local list = grid.cells[k]
			if list then
				table.insert(list, id)
			else
				grid.cells[k] = { id }
			end
		end
	end
end

-- The ids registered in the cell that contains the point (nil when there are none).
function SegmentGrid.query(grid: SegmentGrid, x: number, z: number): { number }?
	local size = grid.cellSize
	return grid.cells[key(math.floor(x / size), math.floor(z / size))]
end

return SegmentGrid
