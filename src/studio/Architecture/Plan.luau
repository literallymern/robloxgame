--!strict
-- Space plans: the interior of a building as a list of spaces (rooms, corridors, halls,
-- stairs, lift shafts) on storeys. From the plan this module builds the partition walls along
-- the shared edges of the spaces with their doors, the floor slabs with openings for stairs and
-- tall halls, floor finishes, ceiling lights and fittings, door signs and the staircases, and
-- hands every room to Rooms.luau for its furniture.
--
-- A space's Rect gives the centre lines of its partitions; along an exterior wall it is the
-- inner face of that wall. Partitions are 0.6 studs thick (about 17 cm).
--
-- Rules:
-- * Two spaces sharing an edge on a storey get a wall between them, unless both are open
--   (circulation: corridors, lobbies, halls) and both have their floor on that storey (open
--   plan). Where an open space with a floor meets the void of a taller open space (a gallery
--   over a hall), a glass balustrade replaces the wall.
-- * A stair is open towards its entry edge and walled on its other three edges.
-- * Every closed room gets a door to the open space it shares the longest wall with, unless
--   the plan lists its doors (suites: a bathroom opening off a bedroom).
-- * A space taller than one storey (the chamber, a banking hall, a lift shaft) cuts the slabs
--   it spans; a stair cuts the area over its flights.

local Parts = require(script.Parent.Parts)
local Materials = require(script.Parent.Materials)
local Openings = require(script.Parent.Openings)
local Stairs = require(script.Parent.Stairs)
local Furniture = require(script.Parent.Furniture)

type Options = Parts.Options

local Plan = {}

export type Rect = { MinX: number, MaxX: number, MinZ: number, MaxZ: number }
export type Edge = "MinX" | "MaxX" | "MinZ" | "MaxZ"
export type Axis = "X" | "Z"

Plan.Partition = 0.6 -- interior wall thickness
Plan.DoorHeight = 7.6 -- a character is about 5 studs tall

export type OpeningSpec = {
	Edge: Edge, -- edge of the space that lists it
	At: number?, -- centre along the edge (world coordinate); default: chosen automatically
	Width: number?,
	Height: number?,
	Bottom: number?, -- glazing: sill above the storey floor (Height is then the head)
	Kind: ("Door" | "Double" | "Arch" | "Glazing")?,
	Storey: number?, -- for tall spaces (default: the space's own storey)
	StartOpen: boolean?,
	Glass: boolean?, -- glazed leaf
	Working: boolean?,
}

type OpeningMore = { Width: number?, Height: number?, Bottom: number?, StartOpen: boolean?, Storey: number? }
export type OpeningKind = "Door" | "Double" | "Arch" | "Glazing"

-- An opening for Space.Doors or Space.Extra (keeps plan tables typed).
function Plan.door(edge: Edge, at: number?, kind: OpeningKind?, more: OpeningMore?): OpeningSpec
	local none: OpeningMore = {}
	local o: OpeningMore = more or none
	return {
		Edge = edge,
		At = at,
		Kind = kind,
		Width = o.Width,
		Height = o.Height,
		Bottom = o.Bottom,
		StartOpen = o.StartOpen,
		Storey = o.Storey,
	}
end

export type Space = {
	Name: string,
	Kind: string, -- furnishing recipe in Rooms.luau
	Rect: Rect,
	Storey: number,
	Top: number?, -- tall spaces: the highest storey they span
	Open: boolean?, -- circulation
	Entry: Edge?, -- stairs: the edge people step on from
	Doors: { OpeningSpec }?, -- replaces the automatic door
	Extra: { OpeningSpec }?, -- in addition to the automatic door
	Floor: Options?, -- finish (default by kind)
	Number: string?, -- room number on the door sign (default: storey.nn)
	Custom: ((room: any) -> ())?, -- builds the furnishing instead of the recipe
	Lights: boolean?, -- false: the custom furnishing lights the space
	Seed: number?,
	Grand: boolean?, -- stairs: wider flights
	Gender: ("Men" | "Women" | "Accessible")?, -- WCs
}

export type Style = {
	Partition: Options,
	Door: Openings.DoorStyle,
	GlassDoor: Openings.DoorStyle?,
	Plate: Options?, -- door signs
	Ink: Color3?,
	Stair: Stairs.Style?,
	Floors: { [string]: Options }?, -- floor finish per kind
	Accent: Options?, -- feature walls in representative rooms
}

export type Spec = {
	Model: Instance,
	Building: string, -- "Congress", "Hausali", ... (seed, report)
	Footprints: { Rect }, -- floor areas inside the exterior walls
	Levels: { number }, -- floor level of each storey (storey 0 first), then the top of the roof slab
	Slab: number?, -- slab thickness (default 1)
	Spaces: { Space },
	Style: Style,
	Seed: number?,
	Skylights: { Rect }?, -- openings left in the roof slab (the building glazes them)
	DoorSigns: boolean?, -- false: no room signs beside the doors (homes)
}

export type Hole = {
	From: number,
	To: number,
	Bottom: number,
	Top: number,
	Kind: "Door" | "Double" | "Arch" | "Glazing",
	Room: Space, -- the side a door swings into
	Other: Space?, -- the other side
	Toward: number, -- +1/-1: direction across the wall towards Room
	Hinge: "Start" | "End",
	Spec: OpeningSpec?,
}

export type Segment = {
	Storey: number,
	Axis: "X" | "Z",
	At: number,
	From: number,
	To: number,
	Type: "Wall" | "Rail",
	A: Space,
	B: Space?,
	EdgeA: Edge,
	Out: number, -- outward normal of EdgeA (from A towards B)
	Holes: { Hole },
}

export type WindowRecord = {
	Kind: "Window" | "Door" | "Opening", -- exterior windows, doors and passages
	Storey: number,
	Space: Space?,
	Edge: Edge, -- the space's edge (the facade side)
	From: number,
	To: number,
	Bottom: number,
	Top: number,
	Glass: BasePart?,
	Shuttered: boolean?,
}

export type Plan = {
	Spec: Spec,
	Spaces: { Space },
	Storeys: number,
	Slab: number,
	Index: { [Space]: number },
	Numbers: { [Space]: string },
	Folders: { [Space]: Folder },
	Segments: { Segment },
	Windows: { WindowRecord },
	Root: Folder,
	Report: { [string]: number },
}

local OPPOSITE: { [string]: Edge } = { MinX = "MaxX", MaxX = "MinX", MinZ = "MaxZ", MaxZ = "MinZ" }
local EDGES: { Edge } = { "MinX", "MaxX", "MinZ", "MaxZ" }
Plan.Opposite = OPPOSITE
Plan.Edges = EDGES

local OPEN_KINDS = { Corridor = true, Hall = true, Lobby = true, Gallery = true, Landing = true }

-- Geometry helpers -----------------------------------------------------------------------------

function Plan.rect(minX: number, maxX: number, minZ: number, maxZ: number): Rect
	assert(minX < maxX and minZ < maxZ, "Plan.rect needs min < max")
	return { MinX = minX, MaxX = maxX, MinZ = minZ, MaxZ = maxZ }
end

-- The wall line of an edge: axis of the wall, its coordinate, the range along it and the
-- outward direction (away from the rectangle).
function Plan.edgeLine(r: Rect, e: Edge): ("X" | "Z", number, number, number, number)
	if e == "MinX" then
		return "Z", r.MinX, r.MinZ, r.MaxZ, -1
	elseif e == "MaxX" then
		return "Z", r.MaxX, r.MinZ, r.MaxZ, 1
	elseif e == "MinZ" then
		return "X", r.MinZ, r.MinX, r.MaxX, -1
	end
	return "X", r.MaxZ, r.MinX, r.MaxX, 1
end

-- World (x, z) of a point `s` along a wall line and `d` across it.
local function point(axis: "X" | "Z", at: number, s: number, d: number): (number, number)
	if axis == "X" then
		return s, at + d
	end
	return at + d, s
end
Plan.point = point

local function clip(a: Rect, b: Rect): Rect?
	local minX, maxX = math.max(a.MinX, b.MinX), math.min(a.MaxX, b.MaxX)
	local minZ, maxZ = math.max(a.MinZ, b.MinZ), math.min(a.MaxZ, b.MaxZ)
	if maxX - minX < 0.01 or maxZ - minZ < 0.01 then
		return nil
	end
	return { MinX = minX, MaxX = maxX, MinZ = minZ, MaxZ = maxZ }
end
Plan.clip = clip

-- Splits `pieces` so that nothing remains inside `cutter`.
function Plan.subtract(pieces: { Rect }, cutter: Rect): { Rect }
	local out: { Rect } = {}
	for _, r in pieces do
		if cutter.MaxX <= r.MinX or cutter.MinX >= r.MaxX or cutter.MaxZ <= r.MinZ or cutter.MinZ >= r.MaxZ then
			table.insert(out, r)
			continue
		end
		local x0, x1 = math.max(r.MinX, cutter.MinX), math.min(r.MaxX, cutter.MaxX)
		local z0, z1 = math.max(r.MinZ, cutter.MinZ), math.min(r.MaxZ, cutter.MaxZ)
		if cutter.MinZ > r.MinZ then
			table.insert(out, { MinX = r.MinX, MaxX = r.MaxX, MinZ = r.MinZ, MaxZ = cutter.MinZ })
		end
		if cutter.MaxZ < r.MaxZ then
			table.insert(out, { MinX = r.MinX, MaxX = r.MaxX, MinZ = cutter.MaxZ, MaxZ = r.MaxZ })
		end
		if x0 > r.MinX then
			table.insert(out, { MinX = r.MinX, MaxX = x0, MinZ = z0, MaxZ = z1 })
		end
		if x1 < r.MaxX then
			table.insert(out, { MinX = x1, MaxX = r.MaxX, MinZ = z0, MaxZ = z1 })
		end
	end
	return out
end

local function present(space: Space, storey: number): boolean
	return space.Storey <= storey and storey <= (space.Top or space.Storey)
end
Plan.present = present

function Plan.isOpen(space: Space): boolean
	return space.Open == true or space.Kind == "Stair" or OPEN_KINDS[space.Kind] == true
end

local function inside(plan: Plan, x: number, z: number): boolean
	for _, f in plan.Spec.Footprints do
		if x > f.MinX + 0.01 and x < f.MaxX - 0.01 and z > f.MinZ + 0.01 and z < f.MaxZ - 0.01 then
			return true
		end
	end
	return false
end
Plan.inside = inside

-- The space on `storey` containing the point, if any.
function Plan.spaceAt(plan: Plan, storey: number, x: number, z: number): Space?
	for _, space in plan.Spaces do
		local r = space.Rect
		if present(space, storey) and x > r.MinX and x < r.MaxX and z > r.MinZ and z < r.MaxZ then
			return space
		end
	end
	return nil
end

-- True when the edge of the space lies on an exterior wall (the point just outside it is not
-- inside the building).
function Plan.exteriorEdge(plan: Plan, space: Space, e: Edge): boolean
	local axis: Axis, at, f, t, out = Plan.edgeLine(space.Rect, e)
	local x, z = point(axis, at, (f + t) / 2, out * 0.5)
	return not inside(plan, x, z)
end

function Plan.level(plan: Plan, storey: number): number
	return plan.Spec.Levels[storey + 1]
end

-- Ceiling height (underside of the slab above) of a space.
function Plan.ceiling(plan: Plan, space: Space): number
	return plan.Spec.Levels[(space.Top or space.Storey) + 2] - plan.Slab
end

-- Walls ----------------------------------------------------------------------------------------

local function wallType(a: Space, edge: Edge, b: Space, storey: number): ("Wall" | "Rail")?
	local aStair, bStair = a.Kind == "Stair", b.Kind == "Stair"
	if aStair or bStair then
		if aStair and a.Entry == edge then
			return nil
		end
		if bStair and b.Entry == OPPOSITE[edge] then
			return nil
		end
		return "Wall"
	end
	if Plan.isOpen(a) and Plan.isOpen(b) then
		local floorA, floorB = a.Storey == storey, b.Storey == storey
		if floorA == floorB then
			return nil
		end
		return "Rail"
	end
	return "Wall"
end

-- Splits [f, t] at the footprint edges along the axis, so each piece is either inside or
-- outside the building.
local function splitByFootprints(plan: Plan, axis: "X" | "Z", f: number, t: number): { { number } }
	local cuts = { f, t }
	for _, fp in plan.Spec.Footprints do
		local bounds: { number } = if axis == "X" then { fp.MinX, fp.MaxX } else { fp.MinZ, fp.MaxZ }
		for _, c in bounds do
			if c > f + 0.01 and c < t - 0.01 then
				table.insert(cuts, c)
			end
		end
	end
	table.sort(cuts)
	local out: { { number } } = {}
	for i = 1, #cuts - 1 do
		if cuts[i + 1] - cuts[i] > 0.01 then
			table.insert(out, { cuts[i], cuts[i + 1] })
		end
	end
	return out
end

local function rawSegments(plan: Plan): { Segment }
	local list: { Segment } = {}
	for s = 0, plan.Storeys - 1 do
		local here: { Space } = {}
		for _, space in plan.Spaces do
			if present(space, s) then
				table.insert(here, space)
			end
		end
		for _, a in here do
			for _, e: Edge in EDGES do
				local axis: Axis, at, f, t, out = Plan.edgeLine(a.Rect, e)
				local covered: { { number } } = {}
				for _, b in here do
					if b == a then
						continue
					end
					local _, atB, fB, tB = Plan.edgeLine(b.Rect, OPPOSITE[e])
					if math.abs(atB - at) > 1e-3 then
						continue
					end
					local lo, hi = math.max(f, fB), math.min(t, tB)
					if hi - lo <= 0.01 then
						continue
					end
					table.insert(covered, { lo, hi })
					if plan.Index[a] < plan.Index[b] then
						local kind: ("Wall" | "Rail")? = wallType(a, e, b, s)
						if kind then
							table.insert(list, {
								Storey = s,
								Axis = axis,
								At = at,
								From = lo,
								To = hi,
								Type = kind,
								A = a,
								B = b,
								EdgeA = e,
								Out = out,
								Holes = {},
							})
						end
					end
				end
				-- Stretches without a neighbour: an exterior wall, or (inside the building) a plain wall.
				table.sort(covered, function(p: { number }, q: { number })
					return p[1] < q[1]
				end)
				local gaps: { { number } } = {}
				local cursor = f
				for _, c in covered do
					if c[1] - cursor > 0.01 then
						table.insert(gaps, { cursor, c[1] })
					end
					cursor = math.max(cursor, c[2])
				end
				if t - cursor > 0.01 then
					table.insert(gaps, { cursor, t })
				end
				for _, gap in gaps do
					for _, piece in splitByFootprints(plan, axis, gap[1], gap[2]) do
						local x, z = point(axis, at, (piece[1] + piece[2]) / 2, out * 0.5)
						local stairEntry = a.Kind == "Stair" and a.Entry == e
						if inside(plan, x, z) and not stairEntry then
							table.insert(list, {
								Storey = s,
								Axis = axis,
								At = at,
								From = piece[1],
								To = piece[2],
								Type = "Wall",
								A = a,
								B = nil,
								EdgeA = e,
								Out = out,
								Holes = {},
							})
						end
					end
				end
			end
		end
	end
	return list
end

-- Raw wall segments of `space` along `edge` on `storey`.
local function segmentsOf(raw: { Segment }, space: Space, edge: Edge, storey: number): { Segment }
	local out: { Segment } = {}
	for _, seg in raw do
		if seg.Storey ~= storey or seg.Type ~= "Wall" then
			continue
		end
		if (seg.A == space and seg.EdgeA == edge) or (seg.B == space and OPPOSITE[seg.EdgeA] == edge) then
			table.insert(out, seg)
		end
	end
	return out
end

local DEFAULT_WIDTH = { Door = 3.6, Double = 6.4, Arch = 6, Glazing = 8 }
local CLEAR = 1.6 -- door frame plus a little wall to the next junction

local function addHole(plan: Plan, seg: Segment, room: Space, other: Space?, spec: OpeningSpec?, at: number?)
	local kind: "Door" | "Double" | "Arch" | "Glazing" = (spec and spec.Kind) or "Door"
	local width = (spec and spec.Width) or DEFAULT_WIDTH[kind]
	local length = seg.To - seg.From
	local centre = at
	local hinge: "Start" | "End" = "Start"
	if not centre then
		if length - 2 * CLEAR < width + 4 then
			centre = (seg.From + seg.To) / 2
		elseif Parts.noise(plan.Index[room], seg.Storey, 7) < 0.5 then
			centre = seg.From + CLEAR + 0.4 + width / 2
		else
			centre = seg.To - CLEAR - 0.4 - width / 2
			hinge = "End"
		end
	end
	assert(centre, "addHole: no centre for the opening")
	local from, to = centre - width / 2, centre + width / 2
	if from < seg.From + 0.5 or to > seg.To - 0.5 then
		warn(`[Ro-Nation:Plan] {room.Name}: opening of {width} does not fit a wall of {math.floor(length * 10) / 10}`)
		return
	end
	local y0 = Plan.level(plan, seg.Storey)
	local bottom = y0
	local top = y0 + ((spec and spec.Height) or (if kind == "Double" or kind == "Arch" then 8.4 else Plan.DoorHeight))
	if kind == "Glazing" then
		bottom = y0 + ((spec and spec.Bottom) or 3)
		top = y0 + ((spec and spec.Height) or 7.6)
	end
	local toward = if seg.A == room then -seg.Out else seg.Out
	table.insert(seg.Holes, {
		From = from,
		To = to,
		Bottom = bottom,
		Top = top,
		Kind = kind,
		Room = room,
		Other = other,
		Toward = toward,
		Hinge = hinge,
		Spec = spec,
	})
end

local function otherSide(seg: Segment, space: Space): Space?
	return if seg.A == space then seg.B else seg.A
end

local function placeOpenings(plan: Plan, raw: { Segment })
	for _, space in plan.Spaces do
		local specs: { OpeningSpec } = {}
		local doors: { OpeningSpec } = space.Doors or {}
		local extra: { OpeningSpec } = space.Extra or {}
		for _, spec in doors do
			table.insert(specs, spec)
		end
		for _, spec in extra do
			table.insert(specs, spec)
		end
		for _, spec in specs do
			local storey = spec.Storey or space.Storey
			local segs = segmentsOf(raw, space, spec.Edge, storey)
			local chosen: Segment? = nil
			for _, seg in segs do
				if spec.At then
					if spec.At > seg.From and spec.At < seg.To then
						chosen = seg
					end
				elseif not chosen or seg.To - seg.From > chosen.To - chosen.From then
					chosen = seg
				end
			end
			if chosen then
				local other = otherSide(chosen, space)
				local room = space
				if Plan.isOpen(space) and other and not Plan.isOpen(other) then
					room = other
					other = space
				end
				addHole(plan, chosen, room, other, spec, spec.At)
			else
				warn(`[Ro-Nation:Plan] {space.Name}: no wall on {spec.Edge} for an opening`)
			end
		end
		-- The automatic door: to the open space sharing the longest wall.
		if space.Doors or Plan.isOpen(space) or space.Kind == "Lift" then
			continue
		end
		local best: Segment? = nil
		for _, e: Edge in EDGES do
			for _, seg in segmentsOf(raw, space, e, space.Storey) do
				local other = otherSide(seg, space)
				-- Only to circulation with a floor on this storey (not into the void of a hall).
				if other and Plan.isOpen(other) and other.Kind ~= "Stair" and other.Storey == space.Storey then
					if not best or seg.To - seg.From > best.To - best.From then
						best = seg
					end
				end
			end
		end
		if best then
			addHole(plan, best, space, otherSide(best, space), nil, nil)
		end
	end
end

-- Joins collinear segments of the same storey and type.
local function merge(raw: { Segment }): { Segment }
	local groups: { [string]: { Segment } } = {}
	local keys: { string } = {}
	for _, seg in raw do
		local key = `{seg.Storey}|{seg.Axis}|{math.floor(seg.At * 100 + 0.5)}|{seg.Type}`
		if not groups[key] then
			groups[key] = {}
			table.insert(keys, key)
		end
		table.insert(groups[key], seg)
	end
	table.sort(keys)
	local out: { Segment } = {}
	for _, key in keys do
		local list = groups[key]
		table.sort(list, function(p: Segment, q: Segment)
			return p.From < q.From
		end)
		local current: Segment? = nil
		for _, seg in list do
			if current and seg.From <= current.To + 0.01 then
				current.To = math.max(current.To, seg.To)
				for _, hole in seg.Holes do
					table.insert(current.Holes, hole)
				end
			else
				current = {
					Storey = seg.Storey,
					Axis = seg.Axis,
					At = seg.At,
					From = seg.From,
					To = seg.To,
					Type = seg.Type,
					A = seg.A,
					B = seg.B,
					EdgeA = seg.EdgeA,
					Out = seg.Out,
					Holes = table.clone(seg.Holes),
				}
				table.insert(out, current :: Segment)
			end
		end
	end
	return out
end

-- Wall ends: into the exterior wall where they meet it; at inner junctions walls along X run
-- through the corner and walls along Z stop at their faces, so no two faces lie in one plane.
local function ends(plan: Plan, seg: Segment): (number, number)
	local half = Plan.Partition / 2 - 0.01
	local function adjust(endpoint: number, dir: number): number
		local x, z = point(seg.Axis, seg.At, endpoint + dir * 0.5, 0)
		if not inside(plan, x, z) then
			return endpoint + dir * 0.3
		end
		return endpoint + dir * (if seg.Axis == "X" then half else -half)
	end
	return adjust(seg.From, -1), adjust(seg.To, 1)
end

-- Room numbers --------------------------------------------------------------------------------

local function number(plan: Plan)
	local counters: { [number]: number } = {}
	for _, space in plan.Spaces do
		if Plan.isOpen(space) or space.Kind == "Lift" then
			continue
		end
		local n = (counters[space.Storey] or 0) + 1
		counters[space.Storey] = n
		plan.Numbers[space] = space.Number or string.format("%d.%02d", space.Storey, n)
	end
end

function Plan.label(plan: Plan, space: Space): string
	local n = plan.Numbers[space]
	return if n then `{n} {space.Name}` else space.Name
end

-- Setup ----------------------------------------------------------------------------------------

-- Lays out the plan (walls, doors, numbers) without building anything yet, so the exterior
-- shell can map its windows to the spaces first.
function Plan.new(spec: Spec): Plan
	local root = Instance.new("Folder")
	root.Name = "Interior"
	root.Parent = spec.Model
	local plan: Plan = {
		Spec = spec,
		Spaces = spec.Spaces,
		Storeys = #spec.Levels - 1,
		Slab = spec.Slab or 1,
		Index = {},
		Numbers = {},
		Folders = {},
		Segments = {},
		Windows = {},
		Root = root,
		Report = { Rooms = 0, Doors = 0, Spaces = 0, Stairs = 0, Lights = 0, Rails = 0, Unreachable = 0 },
	}
	for i, space in spec.Spaces do
		plan.Index[space] = i
		assert(space.Storey >= 0 and (space.Top or space.Storey) < plan.Storeys, `{space.Name}: storey out of range`)
		if space.Kind == "Stair" then
			assert(space.Entry, `{space.Name}: a stair needs an Entry edge`)
		end
	end
	number(plan)
	local raw = rawSegments(plan)
	placeOpenings(plan, raw)
	plan.Segments = merge(raw)
	return plan
end

function Plan.addWindow(plan: Plan, record: WindowRecord)
	table.insert(plan.Windows, record)
end

-- Reachability ---------------------------------------------------------------------------------

-- Length along which edge `e` of `a` lies on the opposite edge of `b` (0 if it does not).
local function overlapOn(a: Rect, e: Edge, b: Rect): number
	local _, at, f, t = Plan.edgeLine(a, e)
	local _, atB, fB, tB = Plan.edgeLine(b, OPPOSITE[e])
	if math.abs(at - atB) > 0.01 then
		return 0
	end
	return math.min(t, tB) - math.max(f, fB)
end

-- The spaces nobody can walk to from an entrance (an exterior door): people move through
-- doors and arches, between open spaces that have their floor on the same storey, and up and
-- down the stairs from the spaces at their entry edge. Lift shafts are not counted.
function Plan.unreachable(plan: Plan): { Space }
	local links: { [Space]: { Space } } = {}
	local function link(a: Space, b: Space)
		links[a] = links[a] or {}
		table.insert(links[a], b)
		links[b] = links[b] or {}
		table.insert(links[b], a)
	end
	for _, seg in plan.Segments do
		for _, hole in seg.Holes do
			if hole.Kind ~= "Glazing" and hole.Other then
				link(hole.Room, hole.Other :: Space)
			end
		end
	end
	for s = 0, plan.Storeys - 1 do
		for i, a in plan.Spaces do
			if not present(a, s) or not Plan.isOpen(a) then
				continue
			end
			for j = i + 1, #plan.Spaces do
				local b = plan.Spaces[j]
				if not present(b, s) or not Plan.isOpen(b) then
					continue
				end
				for _, e: Edge in EDGES do
					if overlapOn(a.Rect, e, b.Rect) >= 2 then
						local walk: boolean
						if a.Kind == "Stair" then
							walk = a.Entry == e and b.Storey == s
						elseif b.Kind == "Stair" then
							walk = b.Entry == OPPOSITE[e] and a.Storey == s
						else
							walk = a.Storey == s and b.Storey == s
						end
						if walk then
							link(a, b)
						end
					end
				end
			end
		end
	end
	local reached: { [Space]: boolean } = {}
	local queue: { Space } = {}
	for _, record in plan.Windows do
		local space = record.Space
		if record.Kind == "Door" and space and not reached[space] then
			reached[space] = true
			table.insert(queue, space)
		end
	end
	while #queue > 0 do
		local space = table.remove(queue) :: Space
		local neighbours: { Space } = links[space] or {}
		for _, other in neighbours do
			if not reached[other] then
				reached[other] = true
				table.insert(queue, other)
			end
		end
	end
	local out: { Space } = {}
	for _, space in plan.Spaces do
		if not reached[space] and space.Kind ~= "Lift" then
			table.insert(out, space)
		end
	end
	return out
end

-- Building -------------------------------------------------------------------------------------

local FLOORS: { [string]: Options } = {
	Corridor = Materials.Floor.Terrazzo,
	Hall = Materials.Floor.Marble,
	Lobby = Materials.Floor.Marble,
	Gallery = Materials.Floor.Terrazzo,
	Stair = Materials.Floor.Terrazzo,
	WC = Materials.Floor.TileWhite,
	Bathroom = Materials.Floor.TileWhite,
	Pantry = Materials.Floor.TileGrey,
	Kitchen = Materials.Floor.TileTerracotta,
	Storage = Materials.Floor.Concrete,
	Archive = Materials.Floor.Linoleum,
	Server = Materials.Floor.Linoleum,
	Copy = Materials.Floor.Linoleum,
	Janitor = Materials.Floor.Concrete,
	Lift = Materials.Floor.Concrete,
	Vault = Materials.Floor.Concrete,
	Security = Materials.Floor.Linoleum,
	Office = Materials.Floor.CarpetGrey,
	SharedOffice = Materials.Floor.CarpetBlue,
	Executive = Materials.Floor.ParquetDark,
	Meeting = Materials.Floor.CarpetBlue,
	Committee = Materials.Floor.CarpetRed,
	Press = Materials.Floor.CarpetGrey,
	Library = Materials.Floor.Parquet,
	Lounge = Materials.Floor.Parquet,
	Waiting = Materials.Floor.Terrazzo,
	Reception = Materials.Floor.Marble,
	Cafeteria = Materials.Floor.TileTerracotta,
	Salon = Materials.Floor.Parquet,
	Music = Materials.Floor.Parquet,
	LeadersOffice = Materials.Floor.ParquetDark,
	Dining = Materials.Floor.Parquet,
	Bedroom = Materials.Floor.Parquet,
	Study = Materials.Floor.ParquetDark,
	Family = Materials.Floor.Parquet,
	Dressing = Materials.Floor.Parquet,
	FirstAid = Materials.Floor.Linoleum,
	Garden = Materials.Floor.TileTerracotta,
}

function Plan.floorFor(plan: Plan, space: Space): Options
	local own = plan.Spec.Style.Floors
	return space.Floor or (own and own[space.Kind]) or FLOORS[space.Kind] or Materials.Floor.Terrazzo
end

local function folderFor(plan: Plan, storey: number, name: string): Folder
	local storeyName = `Storey{storey}`
	local storeyFolder: Instance? = plan.Root:FindFirstChild(storeyName)
	if not storeyFolder then
		local created = Instance.new("Folder")
		created.Name = storeyName
		created.Parent = plan.Root
		storeyFolder = created
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = storeyFolder
	return folder
end

local function wallsFolder(plan: Plan, storey: number): Folder
	local storeyFolder = plan.Root:FindFirstChild(`Storey{storey}`)
	local existing = storeyFolder and storeyFolder:FindFirstChild("Walls")
	if existing and existing:IsA("Folder") then
		return existing
	end
	return folderFor(plan, storey, "Walls")
end

local function buildWalls(plan: Plan)
	local style = plan.Spec.Style
	for _, seg in plan.Segments do
		local y0 = Plan.level(plan, seg.Storey)
		local y1 = Plan.level(plan, seg.Storey + 1)
		local parent = wallsFolder(plan, seg.Storey)
		local wall: Openings.Wall = { Axis = seg.Axis, At = seg.At, Thickness = Plan.Partition, Out = seg.Out }
		local from, to = ends(plan, seg)
		if seg.Type == "Rail" then
			-- A glass balustrade on a low kerb, with a steel handrail.
			local thin: Openings.Wall = { Axis = seg.Axis, At = seg.At, Thickness = 0.3, Out = seg.Out }
			Openings.solid(parent, "BalustradeKerb", thin, from, to, y0, y0 + 0.4, nil, style.Partition)
			local glass: Openings.Wall = { Axis = seg.Axis, At = seg.At, Thickness = 0.12, Out = seg.Out }
			Openings.solid(parent, "Balustrade", glass, from, to, y0 + 0.4, y0 + 3.4, nil, Materials.Glass.Interior)
			Openings.wallBox(
				parent,
				"BalustradeRail",
				wall,
				from,
				to,
				y0 + 3.4,
				y0 + 3.65,
				seg.At - 0.2,
				seg.At + 0.2,
				Parts.detail(Materials.Metal.Steel)
			)
			plan.Report.Rails += 1
			continue
		end
		local holes: { Openings.Hole } = {}
		for _, hole in seg.Holes do
			table.insert(holes, { From = hole.From, To = hole.To, Bottom = hole.Bottom, Top = hole.Top })
		end
		Openings.solid(parent, "Partition", wall, from, to, y0, y1, holes, style.Partition)
		for _, hole in seg.Holes do
			local roomFolder = plan.Folders[hole.Room] or parent
			local w: Openings.Wall = { Axis = seg.Axis, At = seg.At, Thickness = Plan.Partition, Out = hole.Toward }
			local label = Plan.label(plan, hole.Room)
			local doorStyle = if hole.Spec and hole.Spec.Glass then (style.GlassDoor or style.Door) else style.Door
			local working = not (hole.Spec and hole.Spec.Working == false)
			if hole.Kind == "Door" then
				Openings.door(roomFolder, w, hole.From, hole.To, hole.Bottom, hole.Top, doorStyle, {
					Hinge = hole.Hinge,
					Swing = hole.Toward,
					Label = label,
					StartOpen = hole.Spec and hole.Spec.StartOpen,
					Working = working,
				})
				plan.Report.Doors += 1
			elseif hole.Kind == "Double" then
				Openings.doubleDoor(roomFolder, w, hole.From, hole.To, hole.Bottom, hole.Top, doorStyle, {
					Swing = hole.Toward,
					Label = label,
					StartOpen = hole.Spec and hole.Spec.StartOpen,
					Working = working,
				})
				plan.Report.Doors += 1
			elseif hole.Kind == "Arch" then
				Openings.frame(roomFolder, w, hole.From, hole.To, hole.Bottom, hole.Top, doorStyle.Frame)
			else
				Openings.window(roomFolder, w, hole.From, hole.To, hole.Bottom, hole.Top, {
					Frame = doorStyle.Frame or Materials.Frame.White,
					Glass = Materials.Glass.Interior,
					Sill = Parts.detail(doorStyle.Frame or Materials.Frame.White),
					Board = doorStyle.Frame or Materials.Frame.White,
				})
			end
			if hole.Kind == "Door" or hole.Kind == "Double" then
				-- Light switch inside, at the latch side; the room sign outside.
				local latch = if hole.Hinge == "Start" then hole.To + 0.75 else hole.From - 0.75
				local inner = seg.At + hole.Toward * (Plan.Partition / 2)
				local function wallFrame(s: number, y: number, face: number, dir: number): CFrame
					local x, z = point(seg.Axis, seg.At, s, face - seg.At)
					local p = Vector3.new(x, y, z)
					local dx, dz = point(seg.Axis, 0, 0, dir)
					return CFrame.lookAt(p, p + Vector3.new(dx, 0, dz))
				end
				if not Plan.isOpen(hole.Room) then
					Furniture.fitting(roomFolder, wallFrame(latch, hole.Bottom + 3.6, inner, hole.Toward), "Switch")
				end
				local roomNumber = plan.Numbers[hole.Room]
				if roomNumber and hole.Other and Plan.isOpen(hole.Other) and plan.Spec.DoorSigns ~= false then
					local outer = seg.At - hole.Toward * (Plan.Partition / 2)
					local s = if hole.Hinge == "Start" then hole.To + 1.4 else hole.From - 1.4
					local sign = Furniture.sign(
						roomFolder,
						wallFrame(s, hole.Bottom + 5.4, outer, -hole.Toward),
						1.8,
						0.8,
						{ roomNumber, hole.Room.Name },
						style.Plate or Materials.Plastic.White,
						style.Ink or Color3.fromRGB(40, 44, 52)
					)
					sign.Name = "DoorSign"
				end
			end
		end
	end
end

local function buildSlabs(plan: Plan)
	local folder = Instance.new("Folder")
	folder.Name = "Slabs"
	folder.Parent = plan.Root
	local ceiling = Materials.Ceiling
	for level = 1, plan.Storeys do
		local y = Plan.level(plan, level)
		local pieces: { Rect } = table.clone(plan.Spec.Footprints)
		if level == plan.Storeys then
			local skylights: { Rect } = plan.Spec.Skylights or {}
			for _, r in skylights do
				pieces = Plan.subtract(pieces, r)
			end
		end
		for _, space in plan.Spaces do
			if space.Storey < level and (space.Top or space.Storey) >= level then
				if space.Kind == "Stair" then
					pieces = Plan.subtract(pieces, Stairs.opening(space.Rect, space.Entry :: Edge))
				else
					pieces = Plan.subtract(pieces, space.Rect)
				end
			end
		end
		for _, r in pieces do
			Parts.box(
				folder,
				if level == plan.Storeys then "RoofSlab" else "FloorSlab",
				r.MinX,
				y - plan.Slab,
				r.MinZ,
				r.MaxX,
				y,
				r.MaxZ,
				ceiling
			)
		end
	end
end

-- Floor finish on a rectangle, clipped to the building.
local function finish(plan: Plan, parent: Instance, r: Rect, y: number, options: Options)
	for _, fp in plan.Spec.Footprints do
		local c = clip(r, fp)
		if c then
			Parts.box(parent, "FloorFinish", c.MinX, y, c.MinZ, c.MaxX, y + 0.1, c.MaxZ, options)
		end
	end
end

local function lights(plan: Plan, space: Space, folder: Instance)
	local r = space.Rect
	local y = Plan.ceiling(plan, space)
	local w, d = r.MaxX - r.MinX, r.MaxZ - r.MinZ
	local corridor = space.Kind == "Corridor" or space.Kind == "Gallery"
	local spacing = if corridor then 12 else 14
	local nx = math.max(1, math.floor(w / spacing + 0.5))
	local nz = math.max(1, math.floor(d / spacing + 0.5))
	local cx, cz = (r.MinX + r.MaxX) / 2, (r.MinZ + r.MaxZ) / 2
	local alongX = w >= d
	local long = math.max(w, d)
	-- A few panels carry point lights, spread along the long axis (one per 50 studs).
	local carriers = math.max(1, math.ceil(long / 50))
	local reach = if carriers == 1
		then math.clamp(math.sqrt(w * w + d * d) * 0.6, 16, 60)
		else math.min(60, long / carriers + 14)
	local targets: { Vector3 } = {}
	for j = 1, carriers do
		local t = (j - 0.5) / carriers
		table.insert(targets, if alongX then Vector3.new(r.MinX + t * w, y, cz) else Vector3.new(cx, y, r.MinZ + t * d))
	end
	local panels: { Vector3 } = {}
	for i = 1, nx do
		for k = 1, nz do
			table.insert(panels, Vector3.new(r.MinX + (i - 0.5) * w / nx, y, r.MinZ + (k - 0.5) * d / nz))
		end
	end
	local carrying: { [number]: boolean } = {}
	for _, target in targets do
		local best, bestDistance = 1, math.huge
		for i, p in panels do
			local distance = (p - target).Magnitude
			if distance < bestDistance then
				best, bestDistance = i, distance
			end
		end
		carrying[best] = true
	end
	for i, p in panels do
		local pw, pd = 2.4, 2.4
		if corridor then
			pw, pd = if alongX then 4 else 1.2, if alongX then 1.2 else 4
		end
		Furniture.ceilingLight(folder, p, pw, pd, if carrying[i] then reach else nil)
	end
	plan.Report.Lights += #panels
	-- Smoke detector and air vent beside the central light.
	local offset = if alongX then Vector3.new(0, 0, math.min(3, d / 4)) else Vector3.new(math.min(3, w / 4), 0, 0)
	Furniture.smokeDetector(folder, Vector3.new(cx, y, cz) + offset)
	if not corridor and w * d > 120 then
		Furniture.ceilingVent(folder, Vector3.new(cx, y, cz) - offset * 1.6)
	end
end

local function buildStair(plan: Plan, space: Space, folder: Instance)
	local entry: Edge = space.Entry :: Edge
	local style: Stairs.Style = table.clone(plan.Spec.Style.Stair or {})
	if space.Grand then
		style.MaxFlight = 9
	end
	local top = space.Top or space.Storey
	for s = space.Storey, top - 1 do
		Stairs.flight(folder, space.Rect, entry, Plan.level(plan, s), Plan.level(plan, s + 1), style)
		if s > space.Storey then
			finish(plan, folder, Stairs.landing(space.Rect, entry), Plan.level(plan, s), Plan.floorFor(plan, space))
		end
	end
	if top > space.Storey then
		finish(plan, folder, Stairs.landing(space.Rect, entry), Plan.level(plan, top), Plan.floorFor(plan, space))
		local below = Plan.level(plan, top) - Plan.level(plan, top - 1)
		Stairs.guard(folder, space.Rect, entry, Plan.level(plan, top), below, style)
	end
	plan.Report.Stairs += 1
end

-- Builds the interior: walls, doors, slabs, finishes, stairs, lights and furniture. `furnish`
-- is Rooms.furnish (passed in so Rooms can use the plan helpers without a require cycle).
function Plan.build(plan: Plan, furnish: (plan: Plan, space: Space, folder: Folder) -> ())
	for _, space in plan.Spaces do
		local roomNumber = plan.Numbers[space]
		local folder = folderFor(plan, space.Storey, if roomNumber then `{roomNumber} {space.Name}` else space.Name)
		local r = space.Rect
		folder:SetAttribute("Kind", space.Kind)
		folder:SetAttribute("Storey", space.Storey)
		folder:SetAttribute("Top", space.Top or space.Storey)
		folder:SetAttribute("Open", Plan.isOpen(space))
		folder:SetAttribute("Min", Vector3.new(r.MinX, Plan.level(plan, space.Storey), r.MinZ))
		folder:SetAttribute("Max", Vector3.new(r.MaxX, Plan.ceiling(plan, space), r.MaxZ))
		if roomNumber then
			folder:SetAttribute("Number", roomNumber)
		end
		if space.Entry then
			folder:SetAttribute("Entry", space.Entry)
		end
		plan.Folders[space] = folder
		plan.Report.Spaces += 1
		if not Plan.isOpen(space) and space.Kind ~= "Lift" then
			plan.Report.Rooms += 1
		end
	end
	buildWalls(plan)
	buildSlabs(plan)
	for _, space in plan.Spaces do
		local folder = plan.Folders[space]
		if space.Kind == "Lift" then
			furnish(plan, space, folder)
			continue
		end
		finish(plan, folder, space.Rect, Plan.level(plan, space.Storey), Plan.floorFor(plan, space))
		if space.Kind == "Stair" then
			buildStair(plan, space, folder)
		end
		if space.Lights ~= false then
			lights(plan, space, folder)
		end
		furnish(plan, space, folder)
		Parts.add(0)
	end
	local lost = Plan.unreachable(plan)
	plan.Report.Unreachable = #lost
	plan.Spec.Model:SetAttribute("RoomsUnreachable", #lost)
	for _, space in lost do
		warn(
			`[Ro-Nation:Plan] {plan.Spec.Building}: {Plan.label(plan, space)} on storey {space.Storey} cannot be reached`
		)
	end
	return plan.Report
end

return Plan
