--!strict
-- Counted part creation for the building tools (the Gundiville kit and the architecture
-- modules share one counter, so a district build can check its part budget). Every part is
-- anchored; positions are world studs.
--
-- Footings: when a district stands above its planned ground, boxes that reach down to the
-- ground continue down to the footing level, so no gap shows where the terrain is lower.
-- Details: small decorative parts (switches, books, handles) do not collide, cast shadows or
-- take part in raycasts, which keeps physics and lighting cheap.

local Util = require(script.Parent.Parent.Map.Builders.Util)

local Parts = {}

export type Options = Util.PartOptions

local count = 0
local footingGround: number? = nil
local footingY: number? = nil

function Parts.reset()
	count = 0
end

function Parts.count(): number
	return count
end

function Parts.add(n: number)
	count += n
end

function Parts.setFooting(ground: number?, footing: number?)
	footingGround, footingY = ground, footing
end

-- A copy of `options` for a small detail: no collision, queries, touches or shadow.
function Parts.detail(options: Options): Options
	local o = table.clone(options)
	o.Decoration = true
	return o
end

-- A copy of `options` with the given fields replaced.
function Parts.with(options: Options, extra: Options): Options
	local o = table.clone(options)
	for key, value in extra :: any do
		(o :: any)[key] = value
	end
	return o
end

-- Axis-aligned box between two corners.
function Parts.box(
	parent: Instance,
	name: string,
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number,
	options: Options?
): Part
	local lo = Vector3.new(math.min(x0, x1), math.min(y0, y1), math.min(z0, z1))
	local hi = Vector3.new(math.max(x0, x1), math.max(y0, y1), math.max(z0, z1))
	if footingGround and footingY and lo.Y <= footingGround + 1e-3 and lo.Y > footingY then
		lo = Vector3.new(lo.X, footingY, lo.Z)
	end
	local size = hi - lo
	assert(size.X > 0 and size.Y > 0 and size.Z > 0, `Parts.box {name}: empty box`)
	count += 1
	return Util.part(parent, name, CFrame.new((lo + hi) / 2), size, options)
end

-- A block at any orientation.
function Parts.part(parent: Instance, name: string, frame: CFrame, size: Vector3, options: Options?): Part
	count += 1
	return Util.part(parent, name, frame, size, options)
end

function Parts.wedge(parent: Instance, name: string, frame: CFrame, size: Vector3, options: Options?): WedgePart
	count += 1
	return Util.wedge(parent, name, frame, size, options)
end

-- A cylinder from A to B.
function Parts.cylinder(parent: Instance, name: string, a: Vector3, b: Vector3, d: number, options: Options?): Part
	count += 1
	return Util.cylinder(parent, name, a, b, d, options)
end

function Parts.ellipsoid(parent: Instance, name: string, centre: Vector3, size: Vector3, options: Options?): Part
	count += 1
	return Util.ellipsoid(parent, name, CFrame.new(centre), size, options)
end

-- A seat players can sit on (the sitting surface), at `frame` facing its LookVector.
function Parts.seat(parent: Instance, name: string, frame: CFrame, size: Vector3, options: Options): Seat
	local seat = Instance.new("Seat")
	seat.Name = name
	seat.Anchored = true
	seat.Size = size
	seat.CFrame = frame
	seat.Material = options.Material or Enum.Material.Fabric
	seat.Color = options.Color or Color3.fromRGB(90, 90, 96)
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Parent = parent
	count += 1
	return seat
end

-- A deterministic number in [0, 1) from integer-ish keys (the same building always gets the same
-- furniture, colours and small irregularities).
function Parts.noise(a: number, b: number?, c: number?): number
	local v = math.sin(a * 12.9898 + (b or 0) * 78.233 + (c or 0) * 37.719) * 43758.5453
	return v - math.floor(v)
end

-- `colour` shifted slightly in brightness (±amount), for subtle irregularities between pieces
-- of the same material.
function Parts.vary(colour: Color3, key: number, amount: number?): Color3
	local f = 1 + ((Parts.noise(key) * 2 - 1) * (amount or 0.03))
	return Color3.new(math.clamp(colour.R * f, 0, 1), math.clamp(colour.G * f, 0, 1), math.clamp(colour.B * f, 0, 1))
end

return Parts
