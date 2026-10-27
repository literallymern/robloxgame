--!strict
-- Regional highland vegetation, using native geometry and materials only. Forked, leaning
-- stems carry reusable native CSG leaf sprays; acacias spread horizontally, eucalyptus stays
-- open, broadleaf crowns are irregular, and pines have tapered evergreen whorls. The sprays
-- contain gaps and tapered leaf geometry, replacing the former smooth sphere crowns.
-- Each tree is 4–5 parts, streamed as one model. Foliage and upper branches never collide.

local CanopyLibrary = require(script.Parent.CanopyLibrary)
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

local function trunkOptions(colour: Color3): Util.PartOptions
	return { Material = Enum.Material.Wood, Color = colour }
end

-- One tree: the same template vocabulary, varied deterministically by position and species.
-- Four parts for an open crown or pine, five for a fuller mature broadleaf crown.
function VegetationBuilder.tree(parent: Instance, plant: any): number
	local h: number = plant.Size
	local fx, fz = math.floor(plant.X), math.floor(plant.Z)
	local function r(k: number): number
		return Hash.unit(fx, fz, 100 + k)
	end
	local model = Instance.new("Model")
	model.Name = plant.Kind
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("VegetationSpecies", plant.Kind)
	local base = CFrame.new(plant.X, plant.Y, plant.Z) * CFrame.Angles(0, plant.Yaw, 0)
	local function at(dx: number, dy: number, dz: number): CFrame
		return base * CFrame.new(dx * h, dy * h, dz * h)
	end
	local function point(dx: number, dy: number, dz: number): Vector3
		return at(dx, dy, dz).Position
	end
	local crownColour = vary(pick(CROWNS[plant.Kind], plant.Seed), r(1))
	local trunk = trunkOptions(vary(TRUNKS[plant.Kind], r(2)))
	local branch = trunkOptions(trunk.Color :: Color3)
	branch.CanCollide = false
	branch.CanQuery = false
	local count = 0
	local function stem(a: Vector3, b: Vector3, diameter: number, upper: boolean)
		Util.cylinder(model, if upper then "Branch" else "Trunk", a, b, diameter, if upper then branch else trunk)
		count += 1
	end
	local function leaf(dx: number, dy: number, dz: number, w: number, height: number, depth: number, salt: number)
		local tilt = CFrame.Angles((r(salt) - 0.5) * 0.3, r(salt + 1) * 0.9, (r(salt + 2) - 0.5) * 0.3)
		CanopyLibrary.crown(
			plant.Kind,
			1 + math.floor(r(salt + 4) * CanopyLibrary.Variants),
			at(dx, dy, dz) * tilt,
			Vector3.new(w * h, height * h, depth * h),
			vary(crownColour, r(salt + 3)),
			model
		)
		count += 1
	end
	local sink = (1 + plant.Slope * 1.4) / h
	local leanX, leanZ = (r(3) - 0.5) * 0.12, (r(4) - 0.5) * 0.1
	local fuller = r(5) < 0.42
	-- Fork bases are interpolated on the actual trunk axis, including its buried foot.
	-- Independent offsets can leave a floating branch beside a leaning trunk.

	if plant.Kind == "Pine" then
		-- Three overlapping open whorl meshes make a tapered tree without a solid pyramid.
		stem(point(0, -sink, 0), point(leanX * 0.5, 0.86, leanZ * 0.5), math.max(0.8, 0.038 * h), false)
		leaf(leanX * 0.4, 0.42, leanZ * 0.4, 0.5, 0.43, 0.47, 20)
		leaf(leanX * 0.65, 0.66, leanZ * 0.65, 0.37, 0.38, 0.35, 26)
		leaf(leanX * 0.85, 0.85, leanZ * 0.85, 0.23, 0.31, 0.22, 32)
	elseif plant.Kind == "Acacia" then
		local foot, top = point(0, -sink, 0), point(leanX - 0.16, 0.7, leanZ - 0.04)
		stem(foot, top, math.max(0.75, 0.043 * h), false)
		local fork = foot:Lerp(top, (0.54 + sink) / (0.7 + sink))
		stem(fork, point(0.28 + leanX, 0.75, 0.05 + leanZ), math.max(0.45, 0.025 * h), true)
		leaf(leanX - 0.18, 0.75, leanZ - 0.05, 0.76, 0.2 + r(9) * 0.06, 0.58, 20)
		leaf(leanX + 0.25, 0.79, leanZ + 0.08, 0.65, 0.18, 0.53, 26)
		if fuller then
			leaf(leanX + 0.03, 0.82, leanZ - 0.18, 0.5, 0.17, 0.44, 32)
		end
	elseif plant.Kind == "Eucalyptus" then
		local foot, top = point(0, -sink, 0), point(leanX, 0.9, leanZ)
		stem(foot, top, math.max(0.9, 0.035 * h), false)
		local fork = foot:Lerp(top, (0.52 + sink) / (0.9 + sink))
		stem(fork, point(leanX + 0.13, 0.75, leanZ + 0.06), math.max(0.4, 0.018 * h), true)
		leaf(leanX - 0.035, 0.87, leanZ - 0.025, 0.27, 0.27, 0.2, 20)
		leaf(leanX + 0.14, 0.75, leanZ + 0.065, 0.26, 0.24, 0.19, 26)
		if fuller then
			leaf(leanX - 0.1, 0.65, leanZ + 0.06, 0.22, 0.2, 0.18, 32)
		end
	else
		local foot, top = point(0, -sink, 0), point(leanX - 0.09, 0.68, leanZ - 0.04)
		stem(foot, top, math.max(0.85, 0.05 * h), false)
		local fork = foot:Lerp(top, (0.36 + sink) / (0.68 + sink))
		stem(fork, point(leanX + 0.2, 0.65, leanZ + 0.09), math.max(0.5, 0.028 * h), true)
		local spread = 0.92 + r(6) * 0.2
		leaf(leanX - 0.11, 0.74, leanZ - 0.06, 0.5 * spread, 0.4, 0.38, 20)
		leaf(leanX + 0.2, 0.69, leanZ + 0.09, 0.46, 0.32 + r(9) * 0.09, 0.36 * spread, 26)
		if fuller then
			leaf(leanX + 0.02, 0.81, leanZ - 0.04, 0.36, 0.28, 0.32, 32)
		end
	end
	model.Parent = parent
	return count
end

function VegetationBuilder.bush(parent: Instance, plant: any): number
	local w: number = plant.Size
	local fx, fz = math.floor(plant.X), math.floor(plant.Z)
	local colour = vary(pick(CROWNS.Bush, plant.Seed), Hash.unit(fx, fz, 111))
	local base = CFrame.new(plant.X, plant.Y, plant.Z) * CFrame.Angles(0, plant.Yaw, 0)
	local habit = Hash.unit(fx, fz, 112)
	local height = w * (0.3 + 0.45 * habit)
	local tilt = CFrame.Angles((habit - 0.5) * 0.18, 0, (plant.Seed - 0.5) * 0.22)
	local variant = 1 + math.floor(Hash.unit(fx, fz, 114) * CanopyLibrary.Variants)
	local bush = CanopyLibrary.crown(
		"Bush",
		variant,
		base * CFrame.new(0, height * 0.32, 0) * tilt,
		Vector3.new(w, height, w * (0.55 + 0.3 * plant.Seed)),
		colour,
		parent
	)
	bush.Name = "Bush"
	if Hash.unit(fx, fz, 113) < 0.3 then
		local second = CanopyLibrary.crown(
			"Bush",
			variant % CanopyLibrary.Variants + 1,
			base * CFrame.new(w * 0.4, height * 0.2, w * 0.1),
			Vector3.new(w * 0.65, height * 0.7, w * 0.6),
			vary(colour, plant.Seed),
			parent
		)
		second.Name = "Bush"
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
