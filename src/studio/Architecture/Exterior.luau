--!strict
-- Small exterior fittings that make a facade look used and maintained: rain gutters under the
-- eaves, downpipes with shoes, split air-conditioning units under windows, rooftop condensers,
-- vent pipes and roof hatches. All cheap (two to four parts each) and anchored; details do not
-- collide.

local Parts = require(script.Parent.Parts)
local Materials = require(script.Parent.Materials)
local Openings = require(script.Parent.Openings)

type Options = Parts.Options

local Exterior = {}

-- A box gutter along an eave line: `axis` is the direction of the eave, `at` the coordinate of
-- its outer edge across the wall, `out` the side away from the building, y the underside of the
-- roof edge.
function Exterior.gutter(
	parent: Instance,
	axis: "X" | "Z",
	at: number,
	from: number,
	to: number,
	y: number,
	out: number,
	o: Options?
)
	local metal = Parts.detail(o or Materials.Roof.Zinc)
	local d0, d1 = at - out * 0.1, at + out * 0.5
	if axis == "X" then
		Parts.box(parent, "Gutter", from, y - 0.5, d0, to, y + 0.05, d1, metal)
	else
		Parts.box(parent, "Gutter", d0, y - 0.5, from, d1, y + 0.05, to, metal)
	end
end

-- A downpipe on a wall face: from the gutter at `top` down to `bottom`, standing 0.7 off the
-- wall (clear of string courses), with the swan neck reaching `reach` further out to the gutter
-- and a shoe at the foot. (x, z) is the point on the wall face, `out` the outward normal.
function Exterior.downpipe(
	parent: Instance,
	x: number,
	z: number,
	out: Vector3,
	top: number,
	bottom: number,
	reach: number,
	o: Options?
)
	local metal = Parts.detail(o or Materials.Roof.Zinc)
	local centre = Vector3.new(x, 0, z) + out * 0.7
	Parts.cylinder(
		parent,
		"Downpipe",
		Vector3.new(centre.X, bottom + 0.3, centre.Z),
		Vector3.new(centre.X, top - 0.6, centre.Z),
		0.45,
		metal
	)
	local neck = centre + out * (reach / 2)
	Parts.part(
		parent,
		"DownpipeNeck",
		CFrame.lookAt(Vector3.new(neck.X, top - 0.45, neck.Z), Vector3.new(neck.X, top - 0.45, neck.Z) + out),
		Vector3.new(0.4, 0.4, reach + 0.4),
		metal
	)
	local shoe = centre + out * 0.35
	Parts.part(
		parent,
		"DownpipeShoe",
		CFrame.lookAt(Vector3.new(shoe.X, bottom + 0.3, shoe.Z), Vector3.new(shoe.X, bottom + 0.3, shoe.Z) + out),
		Vector3.new(0.45, 0.35, 1.1),
		metal
	)
end

-- The outdoor unit of a split air conditioner on two brackets on a wall, centred at `s` along
-- it, bottom at y.
function Exterior.acUnit(parent: Instance, wall: Openings.Wall, s: number, y: number)
	local face = wall.At + wall.Out * wall.Thickness / 2
	local body = Openings.wallBox(
		parent,
		"AirConditioner",
		wall,
		s - 1.3,
		s + 1.3,
		y,
		y + 1.8,
		face + wall.Out * 0.1,
		face + wall.Out * 1.2,
		Materials.Plastic.Beige
	)
	body:SetAttribute("Fitting", "AirConditioner")
	local dark = Parts.detail(Materials.Metal.Dark)
	local front = face + wall.Out * 1.2
	local cx = if wall.Axis == "X" then s - 0.3 else front
	local cz = if wall.Axis == "X" then front else s - 0.3
	local dir = if wall.Axis == "X" then Vector3.new(0, 0, wall.Out) else Vector3.new(wall.Out, 0, 0)
	Parts.cylinder(
		parent,
		"AirConditionerFan",
		Vector3.new(cx, y + 0.9, cz) - dir * 0.02,
		Vector3.new(cx, y + 0.9, cz) + dir * 0.04,
		1.3,
		dark
	)
	for _, k in { -0.9, 0.9 } do
		Openings.wallBox(
			parent,
			"AirConditionerBracket",
			wall,
			s + k - 0.08,
			s + k + 0.08,
			y - 0.2,
			y,
			face,
			face + wall.Out * 1.3,
			dark
		)
	end
end

-- A condenser on a flat roof: a metal cabinet with a fan on top and a pipe into the roof.
function Exterior.condenser(parent: Instance, x: number, z: number, y: number)
	local metal = Materials.Metal.Aluminium
	Parts.box(parent, "Condenser", x - 2.5, y, z - 1.6, x + 2.5, y + 3.2, z + 1.6, metal)
	Parts.cylinder(
		parent,
		"CondenserFan",
		Vector3.new(x, y + 3.2, z),
		Vector3.new(x, y + 3.3, z),
		2.6,
		Parts.detail(Materials.Metal.Dark)
	)
	Parts.box(
		parent,
		"CondenserPipe",
		x - 0.2,
		y + 0.4,
		z + 1.6,
		x + 0.2,
		y + 0.8,
		z + 5,
		Parts.detail(Materials.Metal.Dark)
	)
end

-- A vent pipe with a cap on a flat roof.
function Exterior.vent(parent: Instance, x: number, z: number, y: number)
	local metal = Materials.Metal.Aluminium
	Parts.cylinder(parent, "VentPipe", Vector3.new(x, y, z), Vector3.new(x, y + 2.6, z), 1, metal)
	Parts.cylinder(parent, "VentCap", Vector3.new(x, y + 2.6, z), Vector3.new(x, y + 2.9, z), 1.7, metal)
end

-- A roof access hatch.
function Exterior.hatch(parent: Instance, x: number, z: number, y: number)
	Parts.box(parent, "RoofHatch", x - 2.5, y, z - 3, x + 2.5, y + 1.2, z + 3, Materials.Metal.Steel)
end

return Exterior
