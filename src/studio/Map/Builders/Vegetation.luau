--!strict
-- Trees, bushes and rocks as simple parts: a cylinder trunk and one or two stretched spheres as
-- the crown. Four tree kinds of the African highlands: broadleaf trees, flat-topped acacias, tall
-- pale eucalyptus and dark pines (timber plantations). Positions come from Map/Vegetation.
-- Crowns and bushes do not collide and let the camera through; trunks and rocks are solid.

local Hash = require(script.Parent.Parent.Hash)
local Util = require(script.Parent.Util)

local VegetationBuilder = {}

local CELL = 1024 -- parts are grouped in folders of this size, so Explorer stays usable

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local CROWNS: { [string]: { Color3 } } = {
	Broadleaf = { rgb(62, 104, 46), rgb(74, 116, 50), rgb(56, 92, 40), rgb(86, 120, 52) },
	Acacia = { rgb(96, 118, 54), rgb(108, 126, 60), rgb(84, 108, 46) },
	Eucalyptus = { rgb(98, 120, 90), rgb(110, 130, 98), rgb(88, 110, 82) },
	Pine = { rgb(40, 72, 44), rgb(48, 80, 48), rgb(36, 64, 40) },
	Bush = { rgb(70, 102, 46), rgb(82, 110, 50), rgb(60, 90, 42), rgb(96, 114, 56) },
}
local TRUNKS: { [string]: Color3 } = {
	Broadleaf = rgb(92, 70, 52),
	Acacia = rgb(78, 62, 50),
	Eucalyptus = rgb(184, 174, 156),
	Pine = rgb(86, 64, 48),
}
local ROCK_COLOURS = { rgb(118, 112, 104), rgb(104, 100, 96), rgb(128, 118, 106), rgb(92, 90, 92) }

-- Varies a colour's brightness by up to ±8 %.
local function vary(colour: Color3, t: number): Color3
	local k = 0.92 + 0.16 * t
	return Color3.new(math.min(1, colour.R * k), math.min(1, colour.G * k), math.min(1, colour.B * k))
end

local function pick<T>(list: { T }, t: number): T
	return list[math.floor(t * #list) % #list + 1]
end

local function crownOptions(colour: Color3): Util.PartOptions
	return {
		Material = Enum.Material.LeafyGrass,
		Color = colour,
		CanCollide = false,
		CanQuery = false,
	}
end

local function trunkOptions(colour: Color3): Util.PartOptions
	return { Material = Enum.Material.Wood, Color = colour }
end

-- One tree. Returns the number of parts.
function VegetationBuilder.tree(parent: Instance, plant: any): number
	local h: number = plant.Size
	local x, y, z = plant.X, plant.Y, plant.Z
	local fx, fz = math.floor(x), math.floor(z)
	local function r(k: number): number
		return Hash.unit(fx, fz, 100 + k)
	end
	local yaw = CFrame.Angles(0, plant.Yaw, 0)
	local crownColour = vary(pick(CROWNS[plant.Kind], plant.Seed), r(1))
	local trunk = trunkOptions(vary(TRUNKS[plant.Kind], r(2)))
	local crown = crownOptions(crownColour)
	local function at(dx: number, dy: number, dz: number): CFrame
		return CFrame.new(x, y, z) * yaw * CFrame.new(dx, dy, dz)
	end
	local count = 0

	if plant.Kind == "Acacia" then
		-- Leaning trunk, wide flat crown, sometimes a second layer to one side.
		local trunkHeight = 0.72 * h
		local lean = (r(3) - 0.5) * 0.25
		local top = at(lean * trunkHeight, trunkHeight, 0).Position
		local sink = 1 + plant.Slope * 1.2
		Util.cylinder(parent, "Trunk", Vector3.new(x, y - sink, z), top, math.max(0.8, 0.05 * h), trunk)
		Util.ellipsoid(
			parent,
			"Crown",
			CFrame.new(top + Vector3.new(0, 0.05 * h, 0)) * yaw,
			Vector3.new(1.15 * h, 0.2 * h, 1.0 * h),
			crown
		)
		count += 2
		if r(4) < 0.7 then
			Util.ellipsoid(
				parent,
				"Crown",
				CFrame.new(top) * yaw * CFrame.new(0.28 * h, 0.12 * h, 0.1 * h),
				Vector3.new(0.6 * h, 0.16 * h, 0.55 * h),
				crown
			)
			count += 1
		end
	elseif plant.Kind == "Eucalyptus" then
		-- Tall pale trunk with a narrow, open crown.
		local trunkHeight = 0.72 * h
		local sink = 1 + plant.Slope * 1.5
		local diameter = math.max(1.2, 0.045 * h)
		Util.cylinder(parent, "Trunk", Vector3.new(x, y - sink, z), Vector3.new(x, y + trunkHeight, z), diameter, trunk)
		Util.ellipsoid(parent, "Crown", at(0, 0.73 * h, 0), Vector3.new(0.34 * h, 0.5 * h, 0.3 * h), crown)
		count += 2
		if r(4) < 0.7 then
			Util.ellipsoid(
				parent,
				"Crown",
				at(0.13 * h, 0.55 * h, 0.04 * h),
				Vector3.new(0.24 * h, 0.28 * h, 0.22 * h),
				crown
			)
			count += 1
		end
	elseif plant.Kind == "Pine" then
		-- Short trunk, a long lower crown and a narrower top.
		local sink = 1 + plant.Slope * 1.2
		local diameter = math.max(1, 0.05 * h)
		Util.cylinder(parent, "Trunk", Vector3.new(x, y - sink, z), Vector3.new(x, y + 0.4 * h, z), diameter, trunk)
		Util.ellipsoid(parent, "Crown", at(0, 0.5 * h, 0), Vector3.new(0.38 * h, 0.62 * h, 0.38 * h), crown)
		Util.ellipsoid(parent, "Crown", at(0, 0.82 * h, 0), Vector3.new(0.22 * h, 0.38 * h, 0.22 * h), crown)
		count += 3
	else
		-- Broadleaf: trunk and a round crown, often with a second lobe.
		local sink = 1 + plant.Slope * 1.5
		local diameter = math.max(1, 0.06 * h)
		Util.cylinder(parent, "Trunk", Vector3.new(x, y - sink, z), Vector3.new(x, y + 0.5 * h, z), diameter, trunk)
		local width = (0.56 + 0.14 * r(5)) * h
		Util.ellipsoid(parent, "Crown", at(0, 0.66 * h, 0), Vector3.new(width, 0.52 * h, width * 0.92), crown)
		count += 2
		if r(4) < 0.6 then
			Util.ellipsoid(
				parent,
				"Crown",
				at(0.2 * h, 0.76 * h, 0.06 * h),
				Vector3.new(width * 0.6, 0.34 * h, width * 0.56),
				crown
			)
			count += 1
		end
	end
	return count
end

function VegetationBuilder.bush(parent: Instance, plant: any): number
	local w: number = plant.Size
	local fx, fz = math.floor(plant.X), math.floor(plant.Z)
	local colour = vary(pick(CROWNS.Bush, plant.Seed), Hash.unit(fx, fz, 111))
	local options = crownOptions(colour)
	local base = CFrame.new(plant.X, plant.Y, plant.Z) * CFrame.Angles(0, plant.Yaw, 0)
	local height = w * (0.55 + 0.2 * Hash.unit(fx, fz, 112))
	Util.ellipsoid(parent, "Bush", base * CFrame.new(0, height * 0.32, 0), Vector3.new(w, height, w * 0.85), options)
	if Hash.unit(fx, fz, 113) < 0.3 then
		Util.ellipsoid(
			parent,
			"Bush",
			base * CFrame.new(w * 0.4, height * 0.2, w * 0.1),
			Vector3.new(w * 0.65, height * 0.7, w * 0.6),
			options
		)
		return 2
	end
	return 1
end

function VegetationBuilder.rock(parent: Instance, plant: any): number
	local s: number = plant.Size
	local fx, fz = math.floor(plant.X), math.floor(plant.Z)
	local function r(k: number): number
		return Hash.unit(fx, fz, 120 + k)
	end
	local size = Vector3.new(s * (0.8 + 0.5 * r(1)), s * (0.5 + 0.3 * r(2)), s * (0.7 + 0.4 * r(3)))
	local tilt = CFrame.Angles((r(4) - 0.5) * 0.6, plant.Yaw, (r(5) - 0.5) * 0.6)
	-- Mostly buried: about a third shows above the ground.
	local frame = CFrame.new(plant.X, plant.Y + size.Y * 0.15 - plant.Slope * s * 0.2, plant.Z) * tilt
	local options: Util.PartOptions = {
		Material = if r(6) < 0.6 then Enum.Material.Rock else Enum.Material.Slate,
		Color = vary(pick(ROCK_COLOURS, plant.Seed), r(7)),
	}
	if r(8) < 0.5 then
		Util.ellipsoid(parent, "Rock", frame, size, options)
	else
		Util.part(parent, "Rock", frame, size, options)
	end
	return 1
end

-- Builds all plants into Workspace.Map.Vegetation. Returns the number of parts.
function VegetationBuilder.build(vegetation: any, parent: Instance): number
	local root = Util.detachedFolder("Vegetation")
	local cells: { [string]: Folder } = {}
	local function cellFolder(x: number, z: number): Folder
		local name = `Area {math.floor(x / CELL)},{math.floor(z / CELL)}`
		local existing: Folder? = cells[name]
		if existing then
			return existing
		end
		local created = Instance.new("Folder")
		created.Name = name
		created.Parent = root
		cells[name] = created
		return created
	end
	local total = 0
	for _, plant in vegetation.trees do
		total += VegetationBuilder.tree(cellFolder(plant.X, plant.Z), plant)
		Util.yield()
	end
	for _, plant in vegetation.bushes do
		total += VegetationBuilder.bush(cellFolder(plant.X, plant.Z), plant)
		Util.yield()
	end
	for _, plant in vegetation.rocks do
		total += VegetationBuilder.rock(cellFolder(plant.X, plant.Z), plant)
		Util.yield()
	end
	root.Parent = parent
	return total
end

return VegetationBuilder
