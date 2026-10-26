--!strict
-- Farm details from Map/Fields: wooden fences around some pastures and tobacco drying barns at
-- the end of tobacco fields.

local Hash = require(script.Parent.Parent.Hash)
local RoadNetwork = require(script.Parent.Parent.RoadNetwork)
local Util = require(script.Parent.Util)

local Countryside = {}

local POST_SPACING = 24
local FENCED_SHARE = 0.35 -- share of pastures with a fence
local GATE = 16 -- gap in the middle of the south side

local WOOD: Util.PartOptions = { Material = Enum.Material.Wood, Color = Color3.fromRGB(122, 96, 70) }

-- A fence along a straight line from (ax, az) to (bx, bz), following the ground.
local function fenceLine(parent: Instance, hf: any, ax: number, az: number, bx: number, bz: number): number
	local length = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
	if length < 4 then
		return 0
	end
	local n = math.max(1, math.ceil(length / POST_SPACING))
	local xs, zs, ys = {}, {}, {}
	for k = 0, n do
		local t = k / n
		local x, z = ax + (bx - ax) * t, az + (bz - az) * t
		table.insert(xs, x)
		table.insert(zs, z)
		table.insert(ys, (hf.surface(x, z)))
	end
	local count = 0
	for k = 1, #xs do
		Util.part(parent, "FencePost", CFrame.new(xs[k], ys[k] + 1.25, zs[k]), Vector3.new(0.5, 4.5, 0.5), WOOD)
		count += 1
	end
	-- Rails: straight pieces over several posts where the ground allows.
	for _, height in { 1.6, 3.0 } do
		local railY: { number } = {}
		for k = 1, #ys do
			railY[k] = ys[k] + height
		end
		for _, run in RoadNetwork.straightRuns(xs, zs, railY, 1, #xs) do
			local a = Vector3.new(xs[run[1]], railY[run[1]], zs[run[1]])
			local b = Vector3.new(xs[run[2]], railY[run[2]], zs[run[2]])
			Util.strip(parent, "FenceRail", a, b, 0.25, 0.3, WOOD)
			count += 1
		end
	end
	return count
end

local function fences(hf: any, parent: Instance): number
	local folder = Instance.new("Folder")
	folder.Name = "Fences"
	local count = 0
	for _, field in hf.fields.list do
		if not field.Fence or Hash.unit(field.Id, 1, 51) > FENCED_SHARE then
			continue
		end
		local x0, x1 = field.MinX + 1, field.MaxX - 1
		local z0, z1 = field.MinZ + 1, field.MaxZ - 1
		local mid = (x0 + x1) / 2
		count += fenceLine(folder, hf, x0, z0, x1, z0)
		count += fenceLine(folder, hf, x1, z0, x1, z1)
		count += fenceLine(folder, hf, x0, z0, x0, z1)
		-- South side with a gate in the middle.
		count += fenceLine(folder, hf, x0, z1, mid - GATE / 2, z1)
		count += fenceLine(folder, hf, mid + GATE / 2, z1, x1, z1)
		Util.yield()
	end
	folder.Parent = parent
	return count
end

local function barns(hf: any, parent: Instance): number
	local folder = Instance.new("Folder")
	folder.Name = "Barns"
	local count = 0
	local walls: Util.PartOptions = { Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(116, 74, 52) }
	local roof: Util.PartOptions = { Material = Enum.Material.CorrodedMetal, Color = Color3.fromRGB(124, 112, 100) }
	local door: Util.PartOptions = { Material = Enum.Material.Wood, Color = Color3.fromRGB(64, 46, 34) }
	for _, barn in hf.fields.barns do
		local model = Instance.new("Model")
		model.Name = "TobaccoBarn"
		local along = if barn.AlongX then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
		local across = Vector3.new(-along.Z, 0, along.X)
		-- Stand on the lowest corner, the rest of the floor goes into the ground.
		local lowest = math.huge
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = Vector3.new(barn.X, 0, barn.Z)
					+ along * (sx * barn.Width / 2)
					+ across * (sz * barn.Depth / 2)
				lowest = math.min(lowest, (hf.surface(p.X, p.Z)))
			end
		end
		local wallHeight = 12
		local base = Vector3.new(barn.X, lowest, barn.Z)
		local facing = CFrame.lookAt(base, base + across)
		local rotation = facing - facing.Position
		local body = Util.part(
			model,
			"Walls",
			CFrame.new(base + Vector3.new(0, (wallHeight - 2) / 2, 0)) * rotation,
			Vector3.new(barn.Width, wallHeight + 2, barn.Depth),
			walls
		)
		local roofHeight = 5
		-- Gable roof: two wedges, tall at the ridge and sloping down to the eaves.
		for _, side in { 1, -1 } do
			local centre = base + Vector3.new(0, wallHeight - 1 + roofHeight / 2, 0) + across * (side * barn.Depth / 4)
			Util.wedge(
				model,
				"Roof",
				CFrame.lookAt(centre, centre + across * side),
				Vector3.new(barn.Width + 1, roofHeight, barn.Depth / 2 + 0.5),
				roof
			)
		end
		Util.part(
			model,
			"Door",
			CFrame.new(base + across * (barn.Depth / 2 + 0.05) + Vector3.new(0, 4, 0)) * rotation,
			Vector3.new(6, 8, 0.2),
			door
		)
		model.PrimaryPart = body
		model.Parent = folder
		count += 4
	end
	folder.Parent = parent
	return count
end

function Countryside.build(hf: any, parent: Instance): { [string]: number }
	local root = Util.detachedFolder("Countryside")
	local counts = {
		Fences = fences(hf, root),
		Barns = barns(hf, root),
	}
	root.Parent = parent
	return counts
end

return Countryside
