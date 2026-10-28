--!strict
-- Switchback staircases inside a rectangular stair core. People enter at the `Entry` edge on
-- every floor: the first flight rises away from the entry on one side, a half landing at the
-- far end turns them round, and the second flight climbs back to the next floor beside the
-- first, separated by a spine wall. Steps are about 0.8 studs high and 1.3 deep, so characters
-- walk up without jumping. Handrails run along the outer walls.

local Parts = require(script.Parent.Parts)
local Materials = require(script.Parent.Materials)

type Options = Parts.Options
type Rect = { MinX: number, MaxX: number, MinZ: number, MaxZ: number }

local Stairs = {}

export type Edge = "MinX" | "MaxX" | "MinZ" | "MaxZ"
export type Style = {
	Tread: Options?,
	Spine: Options?,
	Rail: Options?,
	Landing: Options?,
	MaxFlight: number?, -- widest flight (default 6.5; grand stairs up to 9)
}

Stairs.NearLanding = 6 -- depth of the floor landing at the entry edge

-- Local stair coordinates: u from the entry edge inwards, v across. Returns a converter to a
-- world rectangle plus the length (u) and width (v) of the core.
local function frame(rect: Rect, entry: Edge): ((number, number, number, number) -> Rect, number, number)
	local minX, maxX, minZ, maxZ = rect.MinX, rect.MaxX, rect.MinZ, rect.MaxZ
	if entry == "MinX" or entry == "MaxX" then
		local toWorld = function(u0: number, u1: number, v0: number, v1: number): Rect
			if entry == "MinX" then
				return { MinX = minX + u0, MaxX = minX + u1, MinZ = minZ + v0, MaxZ = minZ + v1 }
			end
			return { MinX = maxX - u1, MaxX = maxX - u0, MinZ = minZ + v0, MaxZ = minZ + v1 }
		end
		return toWorld, maxX - minX, maxZ - minZ
	end
	local toWorld = function(u0: number, u1: number, v0: number, v1: number): Rect
		if entry == "MinZ" then
			return { MinX = minX + v0, MaxX = minX + v1, MinZ = minZ + u0, MaxZ = minZ + u1 }
		end
		return { MinX = minX + v0, MaxX = minX + v1, MinZ = maxZ - u1, MaxZ = maxZ - u0 }
	end
	return toWorld, maxZ - minZ, maxX - minX
end

export type Layout = {
	Steps: number, -- steps per flight (the landing or floor is the last rise)
	Rise: number,
	Tread: number,
	FlightWidth: number,
	Offset: number, -- v of the first flight's outer edge
	Gap: number, -- spine wall thickness
	Length: number,
	Width: number,
}

function Stairs.layout(rect: Rect, entry: Edge, height: number, maxFlight: number?): Layout
	local _, length, width = frame(rect, entry)
	local k = math.max(3, math.ceil(height / 1.6)) -- rises per flight (two flights per floor)
	local gap = 0.8
	local fw = math.min(maxFlight or 6.5, (width - gap) / 2)
	local tread = math.clamp((length - Stairs.NearLanding - 5) / (k - 1), 0.9, 1.4)
	return {
		Steps = k - 1,
		Rise = height / (2 * k),
		Tread = tread,
		FlightWidth = fw,
		Offset = (width - 2 * fw - gap) / 2,
		Gap = gap,
		Length = length,
		Width = width,
	}
end

local function slab(parent: Instance, name: string, r: Rect, y0: number, y1: number, o: Options?): Part
	return Parts.box(parent, name, r.MinX, y0, r.MinZ, r.MaxX, y1, r.MaxZ, o)
end

-- One storey of stairs from y0 up to y1. Returns the area the floor slab at y1 must leave open.
function Stairs.flight(parent: Instance, rect: Rect, entry: Edge, y0: number, y1: number, style: Style?): Rect
	local s: Style = style or {}
	local toWorld = frame(rect, entry)
	local L = Stairs.layout(rect, entry, y1 - y0, s.MaxFlight)
	local tread = s.Tread or Materials.Floor.Terrazzo
	local near, k, r, t = Stairs.NearLanding, L.Steps + 1, L.Rise, L.Tread
	local a0, a1 = L.Offset, L.Offset + L.FlightWidth -- first flight
	local b0, b1 = a1 + L.Gap, a1 + L.Gap + L.FlightWidth -- second flight
	local far = near + (k - 1) * t -- start of the half landing
	for i = 1, k - 1 do
		local top = y0 + i * r
		slab(parent, "Step", toWorld(near + (i - 1) * t, near + i * t, a0, a1), top - r - 1, top, tread)
	end
	local mid = y0 + k * r
	slab(parent, "Landing", toWorld(far, L.Length, a0, b1), mid - 1, mid, s.Landing or tread)
	for j = 1, k - 1 do
		local top = mid + j * r
		local u1 = far - (j - 1) * t
		slab(parent, "Step", toWorld(u1 - t, u1, b0, b1), top - r - 1, top, tread)
	end
	slab(parent, "StairSpine", toWorld(near, far, a1, b0), y0, y1, s.Spine or Materials.Wall.White)
	-- Handrails on the outer walls, 3 studs above the step noses.
	local rail = Parts.detail(s.Rail or Materials.Metal.Steel)
	local function point(u: number, v: number, y: number): Vector3
		local w = toWorld(u, u, v, v)
		return Vector3.new(w.MinX, y, w.MinZ)
	end
	Parts.cylinder(parent, "Handrail", point(near, a0 + 0.3, y0 + 3), point(far, a0 + 0.3, mid + 3), 0.25, rail)
	Parts.cylinder(parent, "Handrail", point(far, b1 - 0.3, mid + 3), point(near, b1 - 0.3, y1 + 3), 0.25, rail)
	return toWorld(near, L.Length, 0, L.Width)
end

-- The floor landing at the entry edge (the part of the stair core that has a floor on every
-- level).
function Stairs.landing(rect: Rect, entry: Edge): Rect
	local toWorld, _, width = frame(rect, entry)
	return toWorld(0, Stairs.NearLanding, 0, width)
end

-- The part of the stair core over the flights, which the floor slab above must leave open.
function Stairs.opening(rect: Rect, entry: Edge): Rect
	local toWorld, length, width = frame(rect, entry)
	return toWorld(Stairs.NearLanding, length, 0, width)
end

-- On the top floor: a balustrade along the stair opening (over the first flight and the spine).
function Stairs.guard(parent: Instance, rect: Rect, entry: Edge, y: number, height: number, style: Style?)
	local s: Style = style or {}
	local toWorld = frame(rect, entry)
	local L = Stairs.layout(rect, entry, height, s.MaxFlight)
	local near = Stairs.NearLanding
	local far = near + L.Steps * L.Tread
	local glass = Materials.Glass.Interior
	local a0, a1 = L.Offset, L.Offset + L.FlightWidth
	slab(parent, "Balustrade", toWorld(near, near + 0.2, a0, a1 + L.Gap), y, y + 3.4, glass)
	slab(parent, "Balustrade", toWorld(near, far, a1, a1 + L.Gap), y, y + 3.4, glass)
	local rail = Parts.detail(s.Rail or Materials.Metal.Steel)
	slab(parent, "BalustradeRail", toWorld(near - 0.1, near + 0.3, a0, a1 + L.Gap), y + 3.4, y + 3.6, rail)
	slab(parent, "BalustradeRail", toWorld(near, far, a1 - 0.1, a1 + L.Gap + 0.1), y + 3.4, y + 3.6, rail)
end

return Stairs
