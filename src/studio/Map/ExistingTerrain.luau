--!strict
-- Protect existing custom construction and place new plants on saved terrain, including
-- columns that the conservative terrain upgrade deliberately leaves unchanged.
local ExistingTerrain = {}
local CELL = 128

local function generated(instance: Instance): boolean
	local current: Instance? = instance
	while current and current ~= workspace do
		if current.Name == "KagundaliTransportWorkshop" then
			return false -- saved architecture is protected even inside a generated region
		end
		if current:GetAttribute("GeneratedBy") == "BuildMap" then
			return true
		end
		current = current.Parent
	end
	return false
end

function ExistingTerrain.protection(): ((number, number) -> boolean, number)
	local grid: { [string]: { { number } } } = {}
	local count = 0
	for _, item in workspace:GetDescendants() do
		if
			not item:IsA("BasePart")
			or item:IsA("Terrain")
			or not item.Anchored
			or not item.CanCollide
			or generated(item)
		then
			continue
		end
		local frame, size = item.CFrame, item.Size
		local right, up, forward = frame.RightVector, frame.UpVector, frame.LookVector
		local dx = (math.abs(right.X) * size.X + math.abs(up.X) * size.Y + math.abs(forward.X) * size.Z) / 2 + 8
		local dz = (math.abs(right.Z) * size.X + math.abs(up.Z) * size.Y + math.abs(forward.Z) * size.Z) / 2 + 8
		local p = frame.Position
		local rect = { p.X - dx, p.X + dx, p.Z - dz, p.Z + dz }
		for z = math.floor(rect[3] / CELL), math.floor(rect[4] / CELL) do
			for x = math.floor(rect[1] / CELL), math.floor(rect[2] / CELL) do
				local key = `{x},{z}`
				local list = grid[key]
				if not list then
					list = {}
					grid[key] = list
				end
				table.insert(list, rect)
			end
		end
		count += 1
	end
	return function(x: number, z: number): boolean
		local list = grid[`{math.floor(x / CELL)},{math.floor(z / CELL)}`]
		if list then
			for _, r in list do
				if x >= r[1] and x <= r[2] and z >= r[3] and z <= r[4] then
					return true
				end
			end
		end
		return false
	end,
		count
end

function ExistingTerrain.groundSampler(
	protected: ((number, number) -> boolean)?
): (number, number, boolean?) -> (number?, number)
	local dry = RaycastParams.new()
	dry.FilterType = Enum.RaycastFilterType.Include
	dry.FilterDescendantsInstances = { workspace.Terrain }
	dry.IgnoreWater = false
	local bed = RaycastParams.new()
	bed.FilterType = Enum.RaycastFilterType.Include
	bed.FilterDescendantsInstances = { workspace.Terrain }
	bed.IgnoreWater = true
	return function(x: number, z: number, allowWater: boolean?): (number?, number)
		if protected and protected(x, z) then
			return nil, 0
		end
		local hit =
			workspace:Raycast(Vector3.new(x, 2048, z), Vector3.new(0, -8192, 0), if allowWater then bed else dry)
		if not hit or (not allowWater and hit.Material == Enum.Material.Water) then
			return nil, 0
		end
		local normal = hit.Normal
		local slope = math.sqrt(normal.X * normal.X + normal.Z * normal.Z) / math.max(0.05, normal.Y)
		return hit.Position.Y, math.min(4, slope)
	end
end

return ExistingTerrain
