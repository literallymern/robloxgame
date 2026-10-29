--!strict
-- Furnishing recipes for the spaces of a Plan. Each room gets a local frame: "Front" is the
-- wall with the most windows (or the wall facing the door), u runs across the room and w from
-- the front wall into it. Pieces are placed through `Rooms.item`, which keeps a clear zone in
-- front of every door, keeps tall pieces away from windows and stops pieces from overlapping,
-- so a recipe can try places and simply skip what does not fit. Seeds vary colours, sizes and
-- optional pieces, so rooms of the same kind are not furnished identically.

local Parts = require(script.Parent.Parts)
local Materials = require(script.Parent.Materials)
local Furniture = require(script.Parent.Furniture)
local Plan = require(script.Parent.Plan)
local Stairs = require(script.Parent.Stairs)

type Options = Parts.Options
type Space = Plan.Space
type Edge = Plan.Edge

local Rooms = {}

export type Side = "Front" | "Back" | "Left" | "Right"
-- Bottom and Top: heights above the floor (windows); Exterior: a stretch of facade wall.
type Span = { Side: Side, From: number, To: number, Bottom: number?, Top: number?, Exterior: boolean? }
type Box = { U0: number, U1: number, W0: number, W1: number }

export type Room = {
	Plan: Plan.Plan,
	Space: Space,
	Folder: Folder,
	Floor: number, -- top of the floor finish
	Height: number, -- floor to ceiling
	Front: Edge,
	Width: number, -- across (u)
	Depth: number, -- from the front wall (w)
	Origin: Vector3,
	N: Vector3, -- into the room from the front wall
	A: Vector3, -- across (+u)
	Sides: { [string]: Side }, -- room edge -> local side
	Doors: { Span },
	Windows: { Span },
	Used: { Box },
	Keep: { Box }, -- door zones
	Low: { Box }, -- in front of windows: nothing tall
	WallUsed: { Span },
	Walls: { Span }, -- where the room really has a wall (wall items only go there)
	Seed: number,
	Panel: number?, -- top of the wall panelling or dado (wall items below it stand off it)
	PanelDepth: number,
}

local NORMAL: { [string]: Vector3 } = {
	MinX = Vector3.new(-1, 0, 0),
	MaxX = Vector3.new(1, 0, 0),
	MinZ = Vector3.new(0, 0, -1),
	MaxZ = Vector3.new(0, 0, 1),
}

-- Room frame -----------------------------------------------------------------------------------

local function sideOf(edge: Edge, front: Edge, a: Vector3): Side
	if edge == front then
		return "Front"
	elseif edge == Plan.Opposite[front] then
		return "Back"
	end
	return if NORMAL[edge]:Dot(a) > 0 then "Right" else "Left"
end

-- The edge of `space` on the wall line (axis, at), if any.
local function edgeOn(space: Space, axis: "X" | "Z", at: number): Edge?
	local r = space.Rect
	if axis == "X" then
		if math.abs(r.MinZ - at) < 1e-3 then
			return "MinZ"
		elseif math.abs(r.MaxZ - at) < 1e-3 then
			return "MaxZ"
		end
	else
		if math.abs(r.MinX - at) < 1e-3 then
			return "MinX"
		elseif math.abs(r.MaxX - at) < 1e-3 then
			return "MaxX"
		end
	end
	return nil
end

function Rooms.toLocal(room: Room, x: number, z: number): (number, number)
	local d = Vector3.new(x, room.Origin.Y, z) - room.Origin
	return d:Dot(room.A), d:Dot(room.N)
end

function Rooms.world(room: Room, u: number, w: number, y: number?): Vector3
	return room.Origin + room.A * u + room.N * w + Vector3.new(0, y or 0, 0)
end

local function look(room: Room, facing: Side): Vector3
	if facing == "Front" then
		return -room.N
	elseif facing == "Back" then
		return room.N
	elseif facing == "Left" then
		return -room.A
	end
	return room.A
end

-- CFrame on the floor at (u, w), the piece's front towards `facing`.
function Rooms.frame(room: Room, u: number, w: number, facing: Side, y: number?): CFrame
	local p = Rooms.world(room, u, w, y)
	return CFrame.lookAt(p, p + look(room, facing))
end

-- The local span (along the wall) of a stretch of a room edge between world coordinates.
local function span(room: Room, edge: Edge, from: number, to: number): Span
	local side: Side = room.Sides[edge]
	local r = room.Space.Rect
	local axis: Plan.Axis = Plan.edgeLine(r, edge)
	local x0, z0, x1, z1
	if axis == "X" then
		x0, x1 = from, to
		z0 = if edge == "MinZ" then r.MinZ else r.MaxZ
		z1 = z0
	else
		z0, z1 = from, to
		x0 = if edge == "MinX" then r.MinX else r.MaxX
		x1 = x0
	end
	local u0, w0 = Rooms.toLocal(room, x0, z0)
	local u1, w1 = Rooms.toLocal(room, x1, z1)
	local a, b =
		if side == "Front" or side == "Back" then u0 else w0, if side == "Front" or side == "Back" then u1 else w1
	return { Side = side, From = math.min(a, b), To = math.max(a, b) }
end

local function zone(room: Room, s: Span, depth: number, margin: number): Box
	local W, D = room.Width, room.Depth
	local a, b = s.From - margin, s.To + margin
	if s.Side == "Front" then
		return { U0 = a, U1 = b, W0 = 0, W1 = depth }
	elseif s.Side == "Back" then
		return { U0 = a, U1 = b, W0 = D - depth, W1 = D }
	elseif s.Side == "Left" then
		return { U0 = -W / 2, U1 = -W / 2 + depth, W0 = a, W1 = b }
	end
	return { U0 = W / 2 - depth, U1 = W / 2, W0 = a, W1 = b }
end

function Rooms.context(plan: Plan.Plan, space: Space, folder: Folder): Room
	local r = space.Rect
	-- Inner faces: the rectangle is the centre line of partitions, the face of exterior walls.
	local inset: { [string]: number } = {}
	for _, e: Edge in Plan.Edges do
		inset[e] = if Plan.exteriorEdge(plan, space, e) then 0 else Plan.Partition / 2
	end
	local inner = {
		MinX = r.MinX + inset.MinX,
		MaxX = r.MaxX - inset.MaxX,
		MinZ = r.MinZ + inset.MinZ,
		MaxZ = r.MaxZ - inset.MaxZ,
	}
	-- Doors and windows on the base storey.
	type Raw = { Edge: Edge, From: number, To: number, Bottom: number?, Top: number?, Exterior: boolean? }
	local doors: { Raw } = {}
	for _, seg in plan.Segments do
		if seg.Storey ~= space.Storey then
			continue
		end
		for _, hole in seg.Holes do
			if hole.Room == space or hole.Other == space then
				local edge: Edge? = edgeOn(space, seg.Axis, seg.At)
				if edge then
					table.insert(doors, { Edge = edge, From = hole.From, To = hole.To })
				end
			end
		end
	end
	local windows: { Raw } = {}
	local windowLength: { [string]: number } = {}
	for _, record in plan.Windows do
		-- A passage through a wall that crosses the space (the Hausali portal bay runs through
		-- the main block's front wall) is not an opening in the space's own wall.
		if record.At then
			local _, line = Plan.edgeLine(r, record.Edge)
			if math.abs(line - record.At) > 3 then
				continue
			end
		end
		if record.Space == space and record.Storey == space.Storey then
			if record.Kind == "Window" then
				table.insert(
					windows,
					{ Edge = record.Edge, From = record.From, To = record.To, Bottom = record.Bottom, Top = record.Top }
				)
				windowLength[record.Edge] = (windowLength[record.Edge] or 0) + record.To - record.From
			else
				table.insert(doors, { Edge = record.Edge, From = record.From, To = record.To })
			end
		end
	end
	-- Where the edges have walls: exterior stretches and partitions on the base storey.
	local walls: { Raw } = {}
	for _, e: Edge in Plan.Edges do
		local axis: Plan.Axis, at, f0, f1, out = Plan.edgeLine(r, e)
		local cuts = { f0, f1 }
		for _, fp in plan.Spec.Footprints do
			local bounds: { number } = if axis == "X" then { fp.MinX, fp.MaxX } else { fp.MinZ, fp.MaxZ }
			for _, c in bounds do
				if c > f0 + 0.01 and c < f1 - 0.01 then
					table.insert(cuts, c)
				end
			end
		end
		table.sort(cuts)
		for i = 1, #cuts - 1 do
			local x, z = Plan.point(axis, at, (cuts[i] + cuts[i + 1]) / 2, out * 0.5)
			if not Plan.inside(plan, x, z) then
				table.insert(walls, { Edge = e, From = cuts[i], To = cuts[i + 1], Exterior = true })
			end
		end
		for _, seg in plan.Segments do
			if
				seg.Storey == space.Storey
				and seg.Type == "Wall"
				and seg.Axis == axis
				and math.abs(seg.At - at) < 1e-3
			then
				local lo, hi = math.max(f0, seg.From), math.min(f1, seg.To)
				if hi - lo > 0.01 then
					table.insert(walls, { Edge = e, From = lo, To = hi })
				end
			end
		end
	end
	local front: Edge = "MinZ"
	local best = 0
	for _, e: Edge in Plan.Edges do
		if (windowLength[e] or 0) > best then
			front, best = e, windowLength[e]
		end
	end
	if best == 0 and #doors > 0 then
		front = Plan.Opposite[doors[1].Edge]
	end
	local n = -NORMAL[front]
	local a = Vector3.new(-n.Z, 0, n.X)
	local y = Plan.level(plan, space.Storey) + 0.1
	local cx, cz = (inner.MinX + inner.MaxX) / 2, (inner.MinZ + inner.MaxZ) / 2
	local origin = if front == "MinX"
		then Vector3.new(inner.MinX, y, cz)
		elseif front == "MaxX" then Vector3.new(inner.MaxX, y, cz)
		elseif front == "MinZ" then Vector3.new(cx, y, inner.MinZ)
		else Vector3.new(cx, y, inner.MaxZ)
	local alongZ = front == "MinX" or front == "MaxX"
	local room: Room = {
		Plan = plan,
		Space = space,
		Folder = folder,
		Floor = y,
		Height = Plan.ceiling(plan, space) - y,
		Front = front,
		Width = if alongZ then inner.MaxZ - inner.MinZ else inner.MaxX - inner.MinX,
		Depth = if alongZ then inner.MaxX - inner.MinX else inner.MaxZ - inner.MinZ,
		Origin = origin,
		N = n,
		A = a,
		Sides = {},
		Doors = {},
		Windows = {},
		Used = {},
		Keep = {},
		Low = {},
		WallUsed = {},
		Walls = {},
		Seed = (space.Seed or 0) + plan.Index[space] * 7 + (plan.Spec.Seed or 0) * 131,
		Panel = nil,
		PanelDepth = 0,
	}
	for _, e: Edge in Plan.Edges do
		room.Sides[e] = sideOf(e, front, a)
	end
	for _, d in doors do
		local s = span(room, d.Edge, d.From, d.To)
		table.insert(room.Doors, s)
		table.insert(room.Keep, zone(room, s, 5, 1))
	end
	for _, w in windows do
		local s = span(room, w.Edge, w.From, w.To)
		s.Bottom = if w.Bottom then w.Bottom - y else nil
		s.Top = if w.Top then w.Top - y else nil
		table.insert(room.Windows, s)
		table.insert(room.Low, zone(room, s, 2.4, 0.5))
	end
	for _, w in walls do
		local s = span(room, w.Edge, w.From, w.To)
		s.Exterior = w.Exterior
		table.insert(room.Walls, s)
	end
	return room
end

-- Placement ------------------------------------------------------------------------------------

local function overlaps(p: Box, q: Box): boolean
	return p.U0 < q.U1 - 0.01 and q.U0 < p.U1 - 0.01 and p.W0 < q.W1 - 0.01 and q.W0 < p.W1 - 0.01
end

function Rooms.free(room: Room, box: Box, tall: boolean?): boolean
	local W, D = room.Width, room.Depth
	if box.U0 < -W / 2 - 0.01 or box.U1 > W / 2 + 0.01 or box.W0 < -0.01 or box.W1 > D + 0.01 then
		return false
	end
	for _, list in { room.Used, room.Keep } do
		for _, other in list do
			if overlaps(box, other) then
				return false
			end
		end
	end
	if tall then
		for _, other in room.Low do
			if overlaps(box, other) then
				return false
			end
		end
	end
	return true
end

-- Places a piece `width` x `depth` (its own X and Z) centred at (u, w), front towards `facing`.
-- Builds it only when the place is free. Returns whether it was placed.
function Rooms.item(
	room: Room,
	u: number,
	w: number,
	facing: Side,
	width: number,
	depth: number,
	tall: boolean?,
	build: (frame: CFrame) -> ()
): boolean
	local across = facing == "Front" or facing == "Back"
	local su, sw = if across then width else depth, if across then depth else width
	local box = { U0 = u - su / 2, U1 = u + su / 2, W0 = w - sw / 2, W1 = w + sw / 2 }
	if not Rooms.free(room, box, tall) then
		return false
	end
	table.insert(room.Used, box)
	build(Rooms.frame(room, u, w, facing))
	return true
end

-- Marks an area as taken without building (walkways).
function Rooms.reserve(room: Room, u0: number, u1: number, w0: number, w1: number)
	table.insert(
		room.Used,
		{ U0 = math.min(u0, u1), U1 = math.max(u0, u1), W0 = math.min(w0, w1), W1 = math.max(w0, w1) }
	)
end

-- True when `side` has a wall over the whole stretch a..b.
function Rooms.hasWall(room: Room, side: Side, a: number, b: number): boolean
	for _, s in room.Walls do
		if s.Side == side and a >= s.From - 0.05 and b <= s.To + 0.05 then
			return true
		end
	end
	return false
end

-- A piece standing with its back to `side`, at `along` on that wall.
function Rooms.against(
	room: Room,
	side: Side,
	along: number,
	width: number,
	depth: number,
	tall: boolean?,
	build: (frame: CFrame) -> ()
): boolean
	local W, D = room.Width, room.Depth
	local gap = 0.05
	if not Rooms.hasWall(room, side, along - width / 2, along + width / 2) then
		return false
	end
	if side == "Back" then
		return Rooms.item(room, along, D - depth / 2 - gap, "Front", width, depth, tall, build)
	elseif side == "Front" then
		return Rooms.item(room, along, depth / 2 + gap, "Back", width, depth, tall, build)
	elseif side == "Left" then
		return Rooms.item(room, -W / 2 + depth / 2 + gap, along, "Right", width, depth, tall, build)
	end
	return Rooms.item(room, W / 2 - depth / 2 - gap, along, "Left", width, depth, tall, build)
end

-- Length of a wall (the range of `along`) and its centre.
function Rooms.wallRange(room: Room, side: Side): (number, number)
	if side == "Front" or side == "Back" then
		return -room.Width / 2, room.Width / 2
	end
	return 0, room.Depth
end

-- Tries positions along a wall (centre first, then outwards) until the piece fits.
function Rooms.alongWall(
	room: Room,
	side: Side,
	width: number,
	depth: number,
	tall: boolean?,
	build: (frame: CFrame) -> (),
	prefer: number? -- -1 = start of the wall first, +1 = end first
): boolean
	local lo, hi = Rooms.wallRange(room, side)
	local mid = (lo + hi) / 2
	local candidates: { number } = {}
	local step = math.max(1, width / 2)
	if prefer then
		local start = if prefer < 0 then lo + width / 2 + 0.3 else hi - width / 2 - 0.3
		for k = 0, 40 do
			local s = start - prefer * k * step
			if s - width / 2 < lo - 0.01 or s + width / 2 > hi + 0.01 then
				break
			end
			table.insert(candidates, s)
		end
	else
		table.insert(candidates, mid)
		for k = 1, 40 do
			for _, sign in { 1, -1 } do
				local s = mid + sign * k * step
				if s - width / 2 >= lo - 0.01 and s + width / 2 <= hi + 0.01 then
					table.insert(candidates, s)
				end
			end
		end
	end
	for _, s in candidates do
		if Rooms.against(room, side, s, width, depth, tall, build) then
			return true
		end
	end
	return false
end

-- Something mounted on a wall at height `y` above the floor (pictures, boards, screens). Keeps
-- clear of doors, windows and other wall items.
function Rooms.onWall(
	room: Room,
	side: Side,
	along: number,
	y: number,
	width: number,
	build: (wall: CFrame) -> ()
): boolean
	local lo, hi = Rooms.wallRange(room, side)
	local a, b = along - width / 2, along + width / 2
	if a < lo + 0.4 or b > hi - 0.4 or not Rooms.hasWall(room, side, a, b) then
		return false
	end
	for _, list in { room.Doors, room.Windows, room.WallUsed } do
		for _, s in list do
			if s.Side == side and a < s.To + 0.6 and s.From - 0.6 < b then
				return false
			end
		end
	end
	table.insert(room.WallUsed, { Side = side, From = a, To = b })
	local W, D = room.Width, room.Depth
	local p: Vector3
	local dir: Vector3
	if side == "Front" then
		p, dir = Rooms.world(room, along, 0, y), room.N
	elseif side == "Back" then
		p, dir = Rooms.world(room, along, D, y), -room.N
	elseif side == "Left" then
		p, dir = Rooms.world(room, -W / 2, along, y), room.A
	else
		p, dir = Rooms.world(room, W / 2, along, y), -room.A
	end
	if room.Panel and y < room.Panel then
		p += dir * room.PanelDepth -- on the face of the panelling
	end
	build(CFrame.lookAt(p, p + dir))
	return true
end

-- Tries a few places on the wall for a wall item.
function Rooms.findWall(room: Room, side: Side, y: number, width: number, build: (wall: CFrame) -> ()): boolean
	local lo, hi = Rooms.wallRange(room, side)
	local mid = (lo + hi) / 2
	for k = 0, 20 do
		local signs: { number } = if k == 0 then { 1 } else { 1, -1 }
		for _, sign in signs do
			local s = mid + sign * k * 1.5
			if s - width / 2 >= lo and s + width / 2 <= hi and Rooms.onWall(room, side, s, y, width, build) then
				return true
			end
		end
	end
	return false
end

-- Helpers --------------------------------------------------------------------------------------

local function noise(room: Room, k: number): number
	return Parts.noise(room.Seed, k)
end

local function pick<T>(room: Room, k: number, list: { T }): T
	return list[1 + math.floor(noise(room, k) * #list) % #list]
end

local function tint(o: Options, room: Room, k: number): Options
	return Parts.with(o, { Color = Parts.vary(o.Color or Color3.new(0.8, 0.8, 0.8), room.Seed * 13 + k, 0.05) })
end

local WOODS = { Materials.Wood.Oak, Materials.Wood.Walnut, Materials.Wood.Oak, Materials.Wood.Walnut }
local FABRICS = { Materials.Fabric.Grey, Materials.Fabric.Blue, Materials.Fabric.Green, Materials.Fabric.Charcoal }
local LEATHERS = { Materials.Leather.Brown, Materials.Leather.Black, Materials.Leather.Oxblood, Materials.Leather.Tan }

local f = Furniture

-- The building's furniture wood and upholstery (Style.Wood / Style.Upholstery), or a pick.
local function woodOf(room: Room, k: number): Options
	return room.Plan.Spec.Style.Wood or pick(room, k, WOODS)
end
local function upholsteryOf(room: Room, k: number): Options
	return room.Plan.Spec.Style.Upholstery or pick(room, k, LEATHERS)
end

-- Official models ---------------------------------------------------------------------------------

-- An official Roblox model (StoreAssets) with its catalogued footprint, centred at (u, w) with
-- its front towards `facing`. When it is not installed, `fallback` builds a piece in its place.
-- The layout is the same either way.
local function model(
	room: Room,
	key: string,
	u: number,
	w: number,
	facing: Side,
	tall: boolean?,
	fallback: ((frame: CFrame) -> ())?,
	scale: number?
): boolean
	local size = f.size(key) * (scale or 1)
	return Rooms.item(room, u, w, facing, size.X, size.Z, tall, function(frame)
		if not f.store(room.Folder, key, frame, scale) and fallback then
			fallback(frame)
		end
	end)
end

-- The same with its back against a wall (positions as Rooms.alongWall tries them).
local function modelAlong(
	room: Room,
	side: Side,
	key: string,
	tall: boolean?,
	fallback: ((frame: CFrame) -> ())?,
	prefer: number?,
	scale: number?
): boolean
	local size = f.size(key) * (scale or 1)
	return Rooms.alongWall(room, side, size.X, size.Z, tall, function(frame)
		if not f.store(room.Folder, key, frame, scale) and fallback then
			fallback(frame)
		end
	end, prefer)
end

-- A model at a free place without layout bookkeeping (props on tables and desks).
local function prop(room: Room, key: string, frame: CFrame, scale: number?)
	f.store(room.Folder, key, frame, scale)
end

-- Wall sockets and a thermostat, plus an air conditioner in larger rooms.
local function services(room: Room)
	local folder = room.Folder
	for i, side in { "Left", "Right", "Back" } do
		local lo, hi = Rooms.wallRange(room, side :: Side)
		Rooms.onWall(room, side :: Side, lo + (hi - lo) * (0.3 + 0.4 * noise(room, 40 + i)), 1, 0.5, function(wall)
			f.fitting(folder, wall, "Outlet")
		end)
	end
	if room.Width * room.Depth > 220 and room.Height > 9 and not room.Plan.Spec.Style.Panelling then
		Rooms.findWall(room, "Back", room.Height - 1.6, 3.4, function(wall)
			f.airConditioner(folder, wall)
		end)
	end
end

-- A radiator under the first `count` windows that have a sill high enough.
local function radiators(room: Room, count: number)
	local W, D = room.Width, room.Depth
	local placed = 0
	for _, win in room.Windows do
		if placed >= count then
			return
		end
		if (win.Bottom or 0) < 2.7 or win.To - win.From < 2.4 then
			continue
		end
		local along = (win.From + win.To) / 2
		local width = math.min(win.To - win.From - 0.4, 5)
		local p: Vector3, dir: Vector3
		if win.Side == "Front" then
			p, dir = Rooms.world(room, along, 0), room.N
		elseif win.Side == "Back" then
			p, dir = Rooms.world(room, along, D), -room.N
		elseif win.Side == "Left" then
			p, dir = Rooms.world(room, -W / 2, along), room.A
		else
			p, dir = Rooms.world(room, W / 2, along), -room.A
		end
		f.radiator(room.Folder, CFrame.lookAt(p, p + dir), width)
		placed += 1
	end
end

-- A plant in a free corner; its leaves keep clear of both walls and of the panelling.
local function plantInCorner(room: Room, k: number, wide: boolean?)
	local W, D = room.Width, room.Depth
	local a = if wide then 2 else 1.5
	local corners = { { -W / 2 + a, D - a }, { W / 2 - a, D - a }, { -W / 2 + a, a }, { W / 2 - a, a } }
	local start = 1 + math.floor(noise(room, k) * 4)
	for i = 0, 3 do
		local c = corners[1 + (start + i - 1) % 4]
		if
			Rooms.item(room, c[1], c[2], "Front", 2 * a - 0.4, 2 * a - 0.4, false, function(frame)
				f.plant(room.Folder, frame.Position, 5 + noise(room, k + 1) * 1.8, room.Seed + k, wide, a - 0.25)
			end)
		then
			return
		end
	end
end

-- Paintings: official reproductions (landscapes and portraits), hung above the panelling.
local LANDSCAPES = {
	"PaintingMurnau",
	"PaintingBordighera",
	"PaintingBoats",
	"PaintingGulfStream",
	"PaintingSail",
	"PaintingBathers",
}
local PORTRAITS =
	{ "PaintingOfficer", "PaintingCottage", "PaintingHelena", "PaintingFurCap", "PaintingTocsin", "PaintingLark" }

local function painting(room: Room, side: Side, k: number, scale: number?, portrait: boolean?): boolean
	local list = if portrait or (portrait == nil and noise(room, k + 70) < 0.35) then PORTRAITS else LANDSCAPES
	local key = pick(room, k, list)
	local s = scale or 0.75
	local bottom = math.max(room.Panel or 0, 2.6) + 0.7
	local size = f.size(key)
	local room_ = room.Height - 1 - bottom
	if size.Y * s > room_ then
		s = math.max(0.45, room_ / size.Y)
	end
	local w, h = size.X * s, size.Y * s
	return Rooms.findWall(room, side, bottom + h / 2, w + 0.8, function(wall)
		if not f.store(room.Folder, key, wall, s) then
			f.picture(room.Folder, wall, w, h, room.Seed + k)
		end
	end)
end

local function pictures(room: Room, count: number, k: number, scale: number?)
	for i = 1, count do
		local choices: { Side } = { "Left", "Right", "Back" }
		local side: Side = choices[1 + math.floor(noise(room, k + i) * 3) % 3]
		painting(room, side, k + i, scale)
	end
end

-- A bookcase and a filing cabinet (offices), or two bookcases and a credenza (executive).
local function storageWall(room: Room, side: Side, k: number, executive: boolean?)
	local wood = tint(woodOf(room, k), room, k)
	local key = if noise(room, k + 1) < 0.5 then "Bookcase" else "BookcaseB"
	local size = f.size(key)
	local prefer = if noise(room, k + 2) < 0.5 then -1 else 1
	for _ = 1, if executive then 2 else 1 do
		modelAlong(room, side, key, true, function(frame)
			f.shelf(room.Folder, frame, size.X, size.Z, math.min(size.Y, room.Height - 1.5), wood, room.Seed + k)
		end, prefer)
	end
	if executive then
		modelAlong(room, side, "Credenza", false, function(frame)
			local c = f.size("Credenza")
			f.cabinet(room.Folder, frame, c.X, c.Z, c.Y, wood)
		end)
	else
		local c = f.size("FilingCabinet")
		modelAlong(room, side, "FilingCabinet", false, function(frame)
			f.cabinet(room.Folder, frame, c.X, c.Z, c.Y, Materials.Metal.Steel)
		end, -prefer)
	end
end

-- Pieces for large rooms in homes ----------------------------------------------------------------

local function large(room: Room): boolean
	return room.Width * room.Depth > 700
end

-- Two armchairs facing each other over a side table with a lamp, near the windows.
local function sittingCorner(room: Room, k: number, upholstery: Options): boolean
	local folder = room.Folder
	local W = room.Width
	local sign = if noise(room, k) < 0.5 then -1 else 1
	local arm = f.size("ArmChair")
	for _, u in { sign * (W / 2 - 6), -sign * (W / 2 - 6) } do
		if
			Rooms.item(room, u, 5.6, "Front", 10.4, 4.4, false, function(frame)
				local tableFrame = frame
				if f.store(folder, "SideTable", tableFrame) then
					prop(room, "TableLamp", tableFrame * CFrame.new(0, f.size("SideTable").Y, 0))
				else
					f.table(folder, tableFrame, 2.4, 2.4, Materials.Wood.Walnut)
				end
				for _, side in { -1, 1 } do
					local chair = frame
						* CFrame.new(side * (arm.Z / 2 + 1.6), 0, 0)
						* CFrame.Angles(0, side * math.pi / 2, 0)
					if not f.store(folder, "ArmChair", chair) then
						f.armchair(folder, chair, upholstery)
					end
				end
			end)
		then
			return true
		end
	end
	return false
end

-- A writing desk with a chair against a side wall.
local function writingDesk(room: Room, k: number, wood: Options): boolean
	local side: Side = if noise(room, k) < 0.5 then "Left" else "Right"
	local desk = f.size("ExecutiveDesk")
	for _, s: Side in { side, if side == "Left" then "Right" else "Left" } do
		if
			Rooms.alongWall(room, s, desk.X + 0.4, desk.Z + 2.6, false, function(frame)
				-- The desk's back is at the wall; its user side faces the room.
				local deskBase = frame * CFrame.new(0, 0, 1.3)
				if f.store(room.Folder, "ExecutiveDesk", deskBase) then
					prop(room, "TableLamp", deskBase * CFrame.new(-desk.X / 2 + 0.9, desk.Y, 0.9))
					prop(room, "Journal", deskBase * CFrame.new(0.4, desk.Y, -0.5) * CFrame.Angles(0, 0.3, 0))
				else
					f.desk(room.Folder, deskBase, desk.X, desk.Z, wood)
				end
				local chair = frame * CFrame.new(0, 0, -desk.Z / 2 + 0.6)
				if not f.store(room.Folder, "ArmDiningChair", chair * CFrame.Angles(0, math.pi, 0)) then
					f.chair(room.Folder, chair * CFrame.Angles(0, math.pi, 0), wood, Materials.Fabric.Beige)
				end
			end)
		then
			return true
		end
	end
	return false
end

-- A chest of drawers with a mirror over it.
local function dresser(room: Room, side: Side, wood: Options): boolean
	local size = f.size("Dresser")
	return Rooms.alongWall(room, side, size.X, size.Z, false, function(frame)
		if not f.store(room.Folder, "Dresser", frame) then
			f.cabinet(room.Folder, frame, size.X, size.Z, size.Y, wood)
		end
		f.mirror(room.Folder, frame * CFrame.new(0, size.Y + 2.6, size.Z / 2), 3.6, 3.4)
	end)
end

-- A table for four: the round entry table with dining chairs.
local function tableForFour(room: Room, u: number, w: number, wood: Options, fabric: Options?): boolean
	local t = f.size("RoundTable")
	return Rooms.item(room, u, w, "Front", t.X + 3.6, t.Z + 3.6, false, function(frame)
		if not f.store(room.Folder, "RoundTable", frame) then
			f.table(room.Folder, frame, 3.6, 3.6, wood)
		end
		for i = 0, 3 do
			local chair = frame * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0, t.Z / 2 + 0.9)
			if not f.store(room.Folder, "DiningChair", chair) then
				f.chair(room.Folder, chair, wood, fabric)
			end
		end
	end)
end

-- Desk props: a lamp, and for executives a notepad and a pen (official models only).
local function deskProps(room: Room, deskBase: CFrame, top: number, deskW: number, executive: boolean?)
	local lamp = deskBase * CFrame.new(-deskW / 2 + 0.9, top, 0.5)
	if not f.store(room.Folder, if executive then "BankersLamp" else "DeskLamp", lamp) then
		Parts.cylinder(
			room.Folder,
			"DeskLamp",
			(lamp * CFrame.new(0, 0.02, 0)).Position,
			(lamp * CFrame.new(0, 1.3, 0)).Position,
			0.25,
			Parts.detail(Materials.Metal.Brass)
		)
		Parts.cylinder(
			room.Folder,
			"DeskLampShade",
			(lamp * CFrame.new(0, 1.1, 0)).Position,
			(lamp * CFrame.new(0, 1.8, 0)).Position,
			1.1,
			Parts.detail(Materials.Fabric.Beige)
		)
	end
	if executive then
		prop(room, "Notepad", deskBase * CFrame.new(0.3, top, -0.75) * CFrame.Angles(0, 0.15, 0))
		prop(room, "Pen", deskBase * CFrame.new(1.0, top, -0.75) * CFrame.Angles(0, -0.4, 0))
	else
		prop(room, "Cup", deskBase * CFrame.new(deskW / 2 - 0.8, top, -0.6))
	end
end

-- Desk with its chair, the user sitting between the desk and the window (facing the room).
-- Executives get the official study desk and chair where it fits.
local function workplace(room: Room, u: number, w: number, deskW: number, executive: boolean?): boolean
	local studyDesk = f.size("ExecutiveDesk")
	local store = executive and deskW >= studyDesk.X
	if store then
		deskW = studyDesk.X
	end
	local deskD = if store then studyDesk.Z elseif executive then 3.6 else 3
	local top = tint(if executive then Materials.Wood.Walnut else woodOf(room, 3), room, 3)
	local fabric = if executive then upholsteryOf(room, 4) else pick(room, 4, FABRICS)
	-- The whole workplace (chair zone between window and desk, then the desk) must be free.
	-- The frame faces the window; its local +Z points into the room.
	local depth = deskD + 3.5
	return Rooms.item(room, u, w + depth / 2, "Front", deskW + 0.4, depth, false, function(frame)
		local folder = room.Folder
		local deskBase = frame * CFrame.new(0, 0, depth / 2 - deskD / 2)
		local height = 3.04
		if store and f.store(folder, "ExecutiveDesk", deskBase) then
			height = studyDesk.Y
		else
			f.desk(folder, deskBase, deskW, deskD, top)
		end
		f.computer(
			folder,
			deskBase * CFrame.new(if executive then deskW / 2 - 1.8 else 0, 0, 0),
			height,
			not executive and noise(room, 5) < 0.3
		)
		deskProps(room, deskBase, height, deskW, executive)
		local chair = frame * CFrame.new(0, 0, -depth / 2 + 1.3) * CFrame.Angles(0, math.pi, 0)
		if not (executive and f.store(folder, "DeskChair", chair)) then
			f.officeChair(folder, chair, fabric)
		end
		f.bin(folder, (deskBase * CFrame.new(deskW / 2 - 0.6, 0, 0.6)).Position)
	end)
end

-- Recipes --------------------------------------------------------------------------------------

local Recipes: { [string]: (room: Room) -> () } = {}
Rooms.Recipes = Recipes

local function office(room: Room, executive: boolean)
	local W, D = room.Width, room.Depth
	local folder = room.Folder
	local deskW = math.clamp(W - 3.5, 4, if executive then 9 else 6.5)
	local placed = workplace(room, 0, 1.6, deskW, executive)
	if not placed then
		for _, u in { -W / 4, W / 4 } do
			if workplace(room, u, 1.6, math.min(deskW, W / 2 - 1), executive) then
				break
			end
		end
	end
	-- Visitor chairs in front of the desk.
	local wood = woodOf(room, 6)
	local visitor = if executive then "ArmDiningChair" else "DiningChair"
	local deskD = if executive then f.size("ExecutiveDesk").Z else 3
	for _, u in { -1.7, 1.7 } do
		model(room, visitor, u, 1.6 + 3.5 + deskD + 1.4, "Front", false, function(frame)
			f.chair(folder, frame, wood, if executive then upholsteryOf(room, 7) else pick(room, 7, FABRICS))
		end)
	end
	local storeSide: Side = if noise(room, 8) < 0.5 then "Left" else "Right"
	local other: Side = if storeSide == "Left" then "Right" else "Left"
	storageWall(room, storeSide, 9, executive)
	if executive then
		-- A sitting group at the back on an oriental rug: sofa, coffee table, two armchairs.
		local sofa = f.size("Sofa3")
		if D > 19 and W > 15 then
			local rugKey = pick(room, 10, { "RugKhamseh", "RugUshak", "RugClassic" })
			local rug = f.size(rugKey)
			local rugFrame = Rooms.frame(room, 0, D - rug.Z / 2 - 1.2, "Front")
			if not f.store(folder, rugKey, rugFrame) then
				f.rug(folder, rugFrame, rug.X, rug.Z, Materials.Floor.CarpetRed)
			end
			model(room, "Sofa3", 0, D - sofa.Z / 2 - 0.2, "Front", false, function(frame)
				f.sofa(folder, frame, 3, upholsteryOf(room, 10))
			end)
			model(room, "CoffeeTable", 0, D - sofa.Z - 2.6, "Front", false, function(frame)
				f.coffeeTable(folder, frame, f.size("CoffeeTable").X, f.size("CoffeeTable").Z, Materials.Wood.Walnut)
			end)
			for _, u in { -5.4, 5.4 } do
				model(room, "ArmChair", u, D - sofa.Z - 2.8, if u < 0 then "Right" else "Left", false, function(frame)
					f.armchair(folder, frame, upholsteryOf(room, 10))
				end)
			end
		end
		storageWall(room, other, 11, true)
		painting(room, "Back", 12, 0.85, true)
		pictures(room, 1, 13, 0.8)
		model(room, "GrandfatherClock", W / 2 - 2, D - 1.2, "Front", true, nil)
	else
		pictures(room, 1, 12)
		if noise(room, 13) < 0.5 then
			Rooms.findWall(room, other, 5.4, 5.5, function(wall)
				f.whiteboard(folder, wall, 5, 3.2)
			end)
		else
			local cork = f.size("CorkBoard")
			Rooms.findWall(room, other, 5.4, cork.X + 0.6, function(wall)
				if not f.store(folder, "CorkBoard", wall) then
					f.noticeBoard(folder, wall, 4, 3, room.Seed)
				end
			end)
		end
	end
	-- A coat stand by the door, a plant, a clock and the radiators.
	local door = room.Doors[1]
	if door then
		local rack = f.size("CoatRack")
		local zoneU = if door.Side == "Back" then (if door.From > 0 then door.From - 2.2 else door.To + 2.2) else 0
		if door.Side == "Back" then
			model(room, "CoatRack", zoneU, D - rack.Z / 2 - 0.3, "Front", true, function(frame)
				f.coatStand(folder, frame.Position)
			end)
		end
	end
	plantInCorner(room, 14)
	Rooms.findWall(room, "Back", room.Height - 3.2, 1.6, function(wall)
		f.clock(folder, wall)
	end)
	radiators(room, if W > 22 then 2 else 1)
	services(room)
end

Recipes.Office = function(room)
	office(room, false)
end
Recipes.Executive = function(room)
	office(room, true)
end
Recipes.Study = Recipes.Executive

-- Desks in pairs, back to back, across the room.
Recipes.SharedOffice = function(room)
	local W, D = room.Width, room.Depth
	local deskD = 3
	local columns = math.max(1, math.floor((W - 3) / 6.4))
	local pairDepth = 2 * deskD + 2 * 2.6
	local pairs = math.max(1, math.floor((D - 6) / (pairDepth + 2.4)))
	local top = tint(pick(room, 3, WOODS), room, 3)
	local fabric = pick(room, 4, FABRICS)
	for p = 0, pairs - 1 do
		local wc = 1.2 + pairDepth / 2 + p * (pairDepth + 2.4)
		for c = 0, columns - 1 do
			local u = -W / 2 + 1.5 + 3.2 + c * 6.4
			Rooms.item(room, u, wc, "Front", 6, pairDepth, false, function(frame)
				for _, side in { -1, 1 } do
					-- Back to back: each desk's front (its user's side) faces outwards.
					local desk = frame * CFrame.new(0, 0, side * deskD / 2)
					if side > 0 then
						desk = desk * CFrame.Angles(0, math.pi, 0)
					end
					f.desk(room.Folder, desk, 5.6, deskD, top)
					f.computer(room.Folder, desk, 3.04, noise(room, 20 + c + p) < 0.4)
					f.officeChair(
						room.Folder,
						desk * CFrame.new(0, 0, -deskD / 2 - 1.3) * CFrame.Angles(0, math.pi, 0),
						fabric
					)
				end
				Parts.part(
					room.Folder,
					"DeskScreen",
					frame * CFrame.new(0, 3.8, 0),
					Vector3.new(5.6, 1.6, 0.12),
					Parts.detail(Materials.Fabric.Grey)
				)
			end)
		end
	end
	Rooms.alongWall(room, "Back", 3, 2.4, false, function(frame)
		f.copier(room.Folder, frame)
	end, 1)
	for _ = 1, 3 do
		Rooms.alongWall(room, "Back", 3, 1.8, false, function(frame)
			f.cabinet(room.Folder, frame, 3, 1.8, 3.4, Materials.Metal.Steel)
		end, -1)
	end
	plantInCorner(room, 15)
	plantInCorner(room, 16)
	Rooms.findWall(room, "Left", 5, 5.5, function(wall)
		f.whiteboard(room.Folder, wall, 5, 3.2)
	end)
	pictures(room, 1, 17)
	services(room)
end

-- Conference table with chairs, a screen and a whiteboard (meeting rooms); formal rooms
-- (committees, the cabinet, boards) get the long official dining table with upholstered
-- armchairs, a credenza, paintings and a grandfather clock.
local function meeting(room: Room, formal: boolean)
	local W, D = room.Width, room.Depth
	local folder = room.Folder
	local alongW = D >= W
	local long = math.max(W, D) - 9
	local short = math.min(W, D) - 9
	local wood = woodOf(room, 5)
	local top = tint(if formal then Materials.Wood.Mahogany else wood, room, 3)
	local seat = if formal then upholsteryOf(room, 4) else pick(room, 4, FABRICS)
	-- The official tables where they fit, else a built table sized to the room.
	local key: string? = nil
	if long >= f.size("LongTable").X and short >= f.size("LongTable").Z then
		key = "LongTable"
	elseif long >= f.size("Table").X and short >= f.size("Table").Z then
		key = "Table"
	end
	local tl = if key then f.size(key).X else math.clamp(long, 5, if formal then 34 else 18)
	local tw = if key then f.size(key).Z else math.clamp(short, 3.5, if formal then 7 else 5)
	local th = if key then f.size(key).Y else 2.95
	local chairKey = if formal then "ArmDiningChair" else "DiningChair"
	local facing: Side = if alongW then "Left" else "Front"
	local placed = Rooms.item(room, 0, D / 2, facing, tl + 4.4, tw + 4.4, false, function(frame)
		if not (key and f.store(folder, key, frame)) then
			f.table(folder, frame, tl, tw, top, th)
		end
		local n = math.max(1, math.floor(tl / 2.8))
		local function chair(at: CFrame)
			if not f.store(folder, chairKey, at) then
				if formal then
					f.officeChair(folder, at, seat)
				else
					f.chair(folder, at, wood, seat)
				end
			end
		end
		for i = 1, n do
			local x = -tl / 2 + (i - 0.5) * tl / n
			for _, side in { -1, 1 } do
				-- Chairs face the table: those on the -Z side turn round.
				local at = frame * CFrame.new(x, 0, side * (tw / 2 + 0.9))
				if side < 0 then
					at = at * CFrame.Angles(0, math.pi, 0)
				end
				chair(at)
			end
		end
		for _, side in { -1, 1 } do
			chair(frame * CFrame.new(side * (tl / 2 + 0.9), 0, 0) * CFrame.Angles(0, side * math.pi / 2, 0))
		end
		if formal then
			for i = 1, math.min(n, 4) do
				prop(room, "Notepad", frame * CFrame.new(-tl / 2 + (i - 0.5) * tl / math.min(n, 4), th, -tw / 2 + 0.7))
			end
		end
	end)
	if not placed then
		Rooms.item(room, 0, D / 2, "Front", 8, 8, false, function(frame)
			f.table(folder, frame, 4, 4, top)
			for k = 0, 3 do
				f.chair(folder, frame * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, 3), wood, seat)
			end
		end)
	end
	-- Screen at one end, whiteboard (meetings) or a portrait (formal rooms) at the other.
	local ends: { Side } = if alongW then { "Back", "Front" } else { "Left", "Right" }
	Rooms.findWall(room, ends[1], 6, 8, function(wall)
		f.screen(folder, wall, 7)
	end)
	if formal then
		painting(room, ends[2], 20, 0.9, true)
	else
		Rooms.findWall(room, ends[2], 5.4, 5.5, function(wall)
			f.whiteboard(folder, wall, 5, 3.2)
		end)
	end
	local sides: { Side } = if alongW then { "Left", "Right" } else { "Back" }
	modelAlong(room, sides[1], if formal then "CredenzaLong" else "Credenza", false, function(frame)
		local c = f.size(if formal then "CredenzaLong" else "Credenza")
		f.cabinet(folder, frame, c.X, c.Z, c.Y, wood)
	end)
	plantInCorner(room, 18)
	plantInCorner(room, 19)
	pictures(room, if formal then 2 else 1, 21, 0.8)
	if formal then
		modelAlong(room, sides[#sides], "GrandfatherClock", true, nil, 1)
	else
		Rooms.findWall(room, sides[#sides], room.Height - 3.2, 1.6, function(wall)
			f.clock(folder, wall)
		end)
	end
	radiators(room, 2)
	services(room)
end

Recipes.Meeting = function(room)
	meeting(room, false)
end
Recipes.Committee = function(room)
	meeting(room, true)
end
Recipes.Cabinet = Recipes.Committee
Recipes.Board = Recipes.Committee

-- Rows of chairs facing a lectern at the back wall.
Recipes.Press = function(room)
	local W, D = room.Width, room.Depth
	local fabric = pick(room, 4, FABRICS)
	Rooms.against(room, "Back", 0, 2.6, 2.2, false, function(frame)
		f.lectern(room.Folder, frame * CFrame.new(0, 0, -1.2), Materials.Wood.Walnut)
	end)
	Rooms.findWall(room, "Back", 7, 12, function(wall)
		Parts.part(
			room.Folder,
			"Backdrop",
			wall * CFrame.new(0, 0, -0.1),
			Vector3.new(12, 7, 0.2),
			Materials.Fabric.Blue
		)
	end)
	local rows = math.floor((D - 12) / 3.2)
	local per = math.floor((W - 6) / 2.4)
	for r = 0, rows - 1 do
		for i = 0, per - 1 do
			local u = -((per - 1) * 2.4) / 2 + i * 2.4
			if math.abs(u) < 1.6 then
				continue -- centre aisle
			end
			Rooms.item(room, u, 4 + r * 3.2, "Back", 2, 2, false, function(frame)
				f.chair(room.Folder, frame, Materials.Metal.Dark, fabric)
			end)
		end
	end
	Rooms.alongWall(room, "Left", 6, 2, false, function(frame)
		f.table(room.Folder, frame, 6, 2, Materials.Wood.Oak)
	end)
	plantInCorner(room, 21)
	services(room)
end

-- Toilets in cubicles along one wall, washbasins opposite, urinals in the men's room.
Recipes.WC = function(room)
	local W, D = room.Width, room.Depth
	local folder = room.Folder
	local tile = Materials.Wall.Tile
	local gender = room.Space.Gender
	local panel = Parts.with(Materials.Plastic.Grey, { Color = Color3.fromRGB(150, 160, 168) })
	-- Cubicles along the back wall (or the longer side wall).
	local side: Side = if D > W + 4 then "Left" else "Back"
	local lo, hi = Rooms.wallRange(room, side)
	local n = math.max(1, math.floor((hi - lo - 1) / 3.8))
	if gender == "Accessible" then
		n = 1
	end
	local cubicle = if gender == "Accessible" then math.min(hi - lo - 1, 7) else 3.8
	for i = 0, n - 1 do
		local s = lo + 0.5 + cubicle / 2 + i * cubicle
		Rooms.against(room, side, s, cubicle, 5.6, false, function(frame)
			f.toilet(folder, frame * CFrame.new(0, 0, 1.2))
			-- Partitions on raised feet (one between neighbours), a pilaster at the front and the
			-- door standing open inside against the partition.
			local walls: { number } = if i == n - 1 then { -cubicle / 2, cubicle / 2 } else { -cubicle / 2 }
			for _, x in walls do
				Parts.part(
					folder,
					"CubiclePartition",
					frame * CFrame.new(x, 3.8, 0),
					Vector3.new(0.12, 6.4, 5.6),
					Parts.detail(panel)
				)
			end
			Parts.part(
				folder,
				"CubicleFront",
				frame * CFrame.new(-cubicle / 2 + 0.36, 3.8, -2.8),
				Vector3.new(0.6, 6.4, 0.12),
				Parts.detail(panel)
			)
			Parts.part(
				folder,
				"CubicleDoor",
				frame * CFrame.new(cubicle / 2 - 0.2, 3.8, -1.3),
				Vector3.new(0.1, 6.2, 3),
				Parts.detail(panel)
			)
			if gender == "Accessible" then
				Parts.part(
					folder,
					"GrabRail",
					frame * CFrame.new(-cubicle / 2 + 0.25, 2.8, 1),
					Vector3.new(0.15, 0.15, 3),
					Parts.detail(Materials.Metal.Chrome)
				)
			end
		end)
	end
	-- Washbasins with mirrors on the opposite or the front wall.
	local basinSide: Side = if side == "Back" then "Front" else "Right"
	local blo, bhi = Rooms.wallRange(room, basinSide)
	local basins = math.clamp(math.floor((bhi - blo - 2) / 3), 1, 4)
	for i = 0, basins - 1 do
		local s = (blo + bhi) / 2 + (i - (basins - 1) / 2) * 3
		Rooms.onWall(room, basinSide, s, 2.9, 2.6, function(wall)
			f.washbasin(folder, wall, true)
		end)
	end
	if gender == "Men" then
		local uSide: Side = if side == "Back" then "Left" else "Back"
		local ulo, uhi = Rooms.wallRange(room, uSide)
		for i = 0, math.clamp(math.floor((uhi - ulo - 2) / 2.6), 1, 3) - 1 do
			Rooms.onWall(room, uSide, (ulo + uhi) / 2 + (i - 1) * 2.6, 2.6, 1.6, function(wall)
				f.urinal(folder, wall)
			end)
		end
	end
	Rooms.findWall(room, basinSide, 4, 1.2, function(wall)
		Parts.part(
			folder,
			"HandDryer",
			wall * CFrame.new(0, 0, -0.35),
			Vector3.new(1, 1.2, 0.7),
			Parts.detail(Materials.Plastic.White)
		)
	end)
	plantInCorner(room, 22)
	Rooms.wainscot(room, 5.5, tile)
end
Recipes.Bathroom = function(room)
	local folder = room.Folder
	local W = room.Width
	Rooms.alongWall(room, "Back", 6, 3, false, function(frame)
		f.bathtub(folder, frame * CFrame.Angles(0, math.pi / 2, 0), 6, 3)
	end, -1)
	Rooms.alongWall(room, "Left", 3.6, 3.6, false, function(frame)
		f.shower(folder, frame, 3.6)
	end, 1)
	Rooms.alongWall(room, "Right", 2.2, 3, false, function(frame)
		f.toilet(folder, frame)
	end, 1)
	for _, side in { "Right", "Left", "Front" } do
		if Rooms.findWall(room, side :: Side, 2.9, 2.6, function(wall)
			f.washbasin(folder, wall, true)
		end) then
			break
		end
	end
	Rooms.alongWall(room, "Right", 2, 1.4, true, function(frame)
		f.cabinet(folder, frame, 2, 1.4, 6, Materials.Wood.White)
	end, -1)
	if W > 10 then
		plantInCorner(room, 23)
	end
	Rooms.wainscot(room, 6, Materials.Wall.TileBlue)
end

-- Tea kitchen: kitchen run, fridge, a table with chairs, a water cooler.
local function kitchenette(room: Room, dining: number)
	local folder = room.Folder
	local doors = pick(room, 3, { Materials.Wood.White, Materials.Wood.Oak, Materials.Plastic.Grey })
	local worktop = pick(room, 4, { Materials.Metal.Steel, Materials.Wood.Walnut, Materials.Plastic.Black })
	for _, side in { "Back", "Left", "Right" } do
		local lo, hi = Rooms.wallRange(room, side :: Side)
		local length = math.min(12, hi - lo - 4)
		if
			length >= 5
			and Rooms.alongWall(room, side :: Side, length, 2.3, false, function(frame)
				f.kitchen(folder, frame, length, doors, worktop, room.Height)
				f.appliance(folder, frame * CFrame.new(length / 2 - 1.2, 3, 0.2), "Microwave")
				if not f.store(folder, "CoffeeMachine", frame * CFrame.new(0.4, 3, 0.3)) then
					f.appliance(folder, frame * CFrame.new(0.4, 3, 0.3), "CoffeeMachine")
				end
				prop(room, "Kettle", frame * CFrame.new(-length / 2 + 1.4, 3, 0.2))
			end)
		then
			Rooms.alongWall(room, side :: Side, 2.6, 2.4, true, function(frame)
				f.fridge(folder, frame)
			end)
			break
		end
	end
	local W, D = room.Width, room.Depth
	if dining > 0 then
		local tl = math.clamp(dining * 1.4, 4, 10)
		Rooms.item(room, 0, D / 2, "Front", tl, 3.6, false, function(frame)
			f.table(folder, frame, tl, 3.6, pick(room, 5, WOODS))
			local n = math.max(1, math.floor(tl / 2.6))
			for i = 1, n do
				for _, side in { -1, 1 } do
					local c = frame * CFrame.new(-tl / 2 + (i - 0.5) * tl / n, 0, side * 2.9)
					if side < 0 then
						c = c * CFrame.Angles(0, math.pi, 0)
					end
					f.chair(folder, c, Materials.Wood.Pine)
				end
			end
		end)
	end
	Rooms.alongWall(room, "Left", 1.4, 1.4, false, function(frame)
		f.waterCooler(folder, frame)
	end)
	Rooms.alongWall(room, "Right", 1, 1, false, function(frame)
		f.bin(folder, frame.Position)
	end)
	Rooms.findWall(room, "Left", 5, 4.2, function(wall)
		f.noticeBoard(folder, wall, 4, 3, room.Seed)
	end)
	if W * D > 200 then
		plantInCorner(room, 24)
	end
	Rooms.wainscot(room, 4.5, Materials.Wall.Tile, { "Back" :: Side })
	services(room)
end
Recipes.Pantry = function(room)
	kitchenette(room, if room.Width * room.Depth > 150 then 4 else 0)
end

Recipes.Cafeteria = function(room)
	local W, D = room.Width, room.Depth
	local folder = room.Folder
	Rooms.alongWall(room, "Back", math.min(16, W - 6), 2.3, false, function(frame)
		f.kitchen(folder, frame, math.min(16, W - 6), Materials.Metal.Steel, Materials.Metal.Steel, room.Height)
	end)
	Rooms.item(room, 0, D - 7, "Front", math.min(14, W - 8), 2.6, false, function(frame)
		f.counter(folder, frame, math.min(14, W - 8), 2.4, Materials.Wood.Oak, Materials.Metal.Steel)
	end)
	local wood = pick(room, 5, WOODS)
	for row = 0, 6 do
		for col = 0, 8 do
			local u = -W / 2 + 5 + col * 7.5
			local w = 4.5 + row * 7.5
			if u > W / 2 - 4 or w > D - 11 then
				continue
			end
			Rooms.item(room, u, w, "Front", 6.4, 6.4, false, function(frame)
				f.table(folder, frame, 3.4, 3.4, wood)
				for k = 0, 3 do
					f.chair(
						folder,
						frame * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, 2.6),
						Materials.Metal.Dark,
						pick(room, 6 + k, FABRICS)
					)
				end
			end)
		end
	end
	plantInCorner(room, 25)
	plantInCorner(room, 26)
	pictures(room, 2, 27)
	services(room)
end

Recipes.Storage = function(room)
	for _, side in { "Back", "Left", "Right" } do
		for k = 1, 4 do
			Rooms.alongWall(room, side :: Side, 5, 2, true, function(frame)
				f.rack(room.Folder, frame, 5, 2, math.min(8, room.Height - 1.5), room.Seed + k)
			end)
		end
	end
	Rooms.findWall(room, "Back", room.Height - 1.4, 2.2, function(wall)
		f.exitSign(room.Folder, wall)
	end)
end
Recipes.Post = function(room)
	Recipes.Storage(room)
	Rooms.item(room, 0, room.Depth / 2, "Front", 6, 3, false, function(frame)
		f.table(room.Folder, frame, 6, 3, Materials.Wood.Pine)
		Parts.part(
			room.Folder,
			"Parcels",
			frame * CFrame.new(-1, 3.4, 0),
			Vector3.new(1.6, 1, 1.2),
			Parts.detail(Materials.Cardboard)
		)
	end)
end

-- Rows of archive racks across the room with aisles between.
Recipes.Archive = function(room)
	local W, D = room.Width, room.Depth
	local files = Parts.with(Materials.Cardboard, { Color = Color3.fromRGB(196, 176, 130) })
	local rows = math.floor((D - 4) / 4.6)
	for r = 0, rows - 1 do
		local w = 3 + r * 4.6
		local length = math.max(4, W - 6)
		Rooms.item(room, -W / 2 + 0.2 + length / 2, w, "Front", length, 2, true, function(frame)
			f.rack(room.Folder, frame, length, 2, math.min(8, room.Height - 1.5), room.Seed + r, files)
		end)
	end
	Rooms.alongWall(room, "Back", 3, 2, false, function(frame)
		f.table(room.Folder, frame, 3, 2, Materials.Wood.Pine)
	end)
	services(room)
end
Recipes.Library = function(room)
	local W, D = room.Width, room.Depth
	local folder = room.Folder
	local wood = tint(Materials.Wood.Walnut, room, 2)
	local keys = if room.Height >= 14.5 then { "BookcaseTall", "BookcaseTallB" } else { "Bookcase", "BookcaseB" }
	local rugKey = pick(room, 3, { "RugClassic", "RugLarge", "RugSwan" })
	local rugFrame = Rooms.frame(room, 0, D / 2, "Front")
	if not f.store(folder, rugKey, rugFrame) then
		f.rug(folder, rugFrame, math.min(W - 6, 13), math.min(D - 8, 8), Materials.Floor.CarpetGreen)
	end
	for _, side in { "Back", "Left", "Right" } do
		for k = 1, 6 do
			local key = keys[1 + k % 2]
			local size = f.size(key)
			modelAlong(room, side :: Side, key, true, function(frame)
				f.shelf(folder, frame, size.X, size.Z, math.min(size.Y, room.Height - 1.5), wood, room.Seed + k * 3)
			end)
		end
	end
	-- Reading tables with chairs and banker's lamps.
	local t = f.size("Table")
	local tables = math.max(1, math.floor((D - 10) / 9))
	for i = 0, tables - 1 do
		Rooms.item(room, 0, 5.5 + i * 9, "Front", t.X + 1, t.Z + 4.4, false, function(frame)
			if not f.store(folder, "Table", frame) then
				f.table(folder, frame, t.X, t.Z, Materials.Wood.Oak, t.Y)
			end
			for c = 1, 3 do
				for _, side in { -1, 1 } do
					local at = frame * CFrame.new(-t.X / 2 + (c - 0.5) * t.X / 3, 0, side * (t.Z / 2 + 0.9))
					if side < 0 then
						at = at * CFrame.Angles(0, math.pi, 0)
					end
					if not f.store(folder, "DiningChair", at) then
						f.chair(folder, at, Materials.Wood.Walnut, Materials.Leather.Brown)
					end
				end
			end
			for _, x in { -t.X / 4, t.X / 4 } do
				prop(room, "BankersLamp", frame * CFrame.new(x, t.Y, 0))
			end
			prop(room, "BookDark", frame * CFrame.new(-t.X / 2 + 1.2, t.Y, -0.8) * CFrame.Angles(0, 0.3, 0))
		end)
	end
	model(room, "ArmChair", W / 2 - 3, D - 4, "Left", false, function(frame)
		f.armchair(folder, frame, Materials.Leather.Oxblood)
	end)
	Rooms.item(room, W / 2 - 3, D - 7, "Left", 1.6, 1.6, false, function(frame)
		f.floorLamp(folder, frame.Position)
	end)
	model(room, "GrandfatherClock", -W / 2 + 2, D - 1.2, "Front", true, nil)
	plantInCorner(room, 28)
	radiators(room, 2)
	services(room)
end

Recipes.Server = function(room)
	local W, D = room.Width, room.Depth
	local rows = math.max(1, math.floor((D - 4) / 6))
	for r = 0, rows - 1 do
		local n = math.max(1, math.floor((W - 4) / 2.5))
		for i = 0, n - 1 do
			Rooms.item(room, -W / 2 + 2 + 1.25 + i * 2.5, 3.5 + r * 6, "Front", 2.4, 3, true, function(frame)
				f.serverRack(room.Folder, frame)
			end)
		end
	end
	for _, side in { "Left", "Right" } do
		Rooms.findWall(room, side :: Side, room.Height - 1.6, 3.4, function(wall)
			f.airConditioner(room.Folder, wall)
		end)
	end
	Rooms.alongWall(room, "Back", 2, 1.6, false, function(frame)
		f.extinguisher(room.Folder, frame * CFrame.new(0, 2, 0.8) * CFrame.Angles(0, math.pi, 0))
	end)
end

Recipes.Copy = function(room)
	Rooms.alongWall(room, "Back", 3, 2.4, false, function(frame)
		f.copier(room.Folder, frame)
	end)
	Rooms.alongWall(room, "Left", 4, 1.6, true, function(frame)
		f.rack(room.Folder, frame, 4, 1.6, 7, room.Seed)
	end)
	Rooms.alongWall(room, "Right", 4, 2, false, function(frame)
		f.cabinet(room.Folder, frame, 4, 2, 3.4, Materials.Plastic.Grey)
		Parts.part(
			room.Folder,
			"PaperStack",
			frame * CFrame.new(0.8, 3.6, 0),
			Vector3.new(1, 0.4, 1.4),
			Parts.detail(Materials.Paper)
		)
	end)
	Rooms.alongWall(room, "Right", 1, 1, false, function(frame)
		f.bin(room.Folder, frame.Position)
	end)
	services(room)
end

Recipes.Janitor = function(room)
	Rooms.alongWall(room, "Back", 3.4, 1.6, true, function(frame)
		f.rack(room.Folder, frame, 3.4, 1.6, 6.5, room.Seed)
	end)
	Rooms.findWall(room, "Left", 2.9, 2.6, function(wall)
		f.washbasin(room.Folder, wall, false)
	end)
	Rooms.item(room, 0, room.Depth / 2, "Front", 1.4, 1.4, false, function(frame)
		Parts.cylinder(
			room.Folder,
			"Bucket",
			frame.Position,
			frame.Position + Vector3.new(0, 1.3, 0),
			1.2,
			Parts.detail(Materials.Plastic.Red)
		)
	end)
end

Recipes.Security = function(room)
	local folder = room.Folder
	Rooms.item(room, 0, 1.6 + 1.75, "Front", 7, 6.5, false, function(frame)
		local desk = frame * CFrame.new(0, 0, 1.5)
		f.desk(folder, desk, 7, 3, Materials.Plastic.Grey)
		f.computer(folder, desk, 3.04, true)
		f.officeChair(folder, frame * CFrame.new(0, 0, -1.6) * CFrame.Angles(0, math.pi, 0), Materials.Fabric.Charcoal)
	end)
	for _, side in { "Back", "Left" } do
		Rooms.findWall(room, side :: Side, 6.5, 7.4, function(wall)
			f.screen(folder, wall, 7)
		end)
	end
	Rooms.alongWall(room, "Right", 4.2, 1.8, true, function(frame)
		f.locker(folder, frame, 4.2)
	end)
	Rooms.alongWall(room, "Back", 2.6, 2.4, false, function(frame)
		f.safe(folder, frame)
	end)
	services(room)
end

Recipes.FirstAid = function(room)
	local folder = room.Folder
	Rooms.alongWall(room, "Left", 6.5, 3, false, function(frame)
		Parts.part(
			folder,
			"TreatmentCouch",
			frame * CFrame.new(0, 1.4, 0),
			Vector3.new(6.2, 0.6, 2.6),
			Materials.Leather.Black
		)
		Parts.part(
			folder,
			"CouchFrame",
			frame * CFrame.new(0, 0.55, 0),
			Vector3.new(5.6, 1.1, 2),
			Parts.detail(Materials.Metal.Steel)
		)
	end)
	Rooms.alongWall(room, "Back", 4, 1.8, true, function(frame)
		f.cabinet(folder, frame, 4, 1.8, 6.5, Materials.Wood.White)
		Parts.part(
			folder,
			"RedCross",
			frame * CFrame.new(0, 5.5, -0.95),
			Vector3.new(1.2, 1.2, 0.05),
			Parts.detail(Materials.Plastic.Red)
		)
	end)
	Rooms.findWall(room, "Right", 2.9, 2.6, function(wall)
		f.washbasin(folder, wall, true)
	end)
	workplace(room, 0, 1.6, 5)
	services(room)
end

Recipes.Reception = function(room)
	local folder = room.Folder
	local W, D = room.Width, room.Depth
	Rooms.item(room, 0, D - 4.5, "Back", math.min(10, W - 4), 2.4, false, function(frame)
		f.counter(folder, frame, math.min(10, W - 4), 2.2, Materials.Wood.Walnut, Materials.Floor.Marble)
		f.officeChair(folder, frame * CFrame.new(0, 0, 2.6) * CFrame.Angles(0, math.pi, 0), Materials.Fabric.Charcoal)
		f.computer(folder, frame * CFrame.new(0, 0, 0.6), 3.6)
	end)
	Recipes.Waiting(room)
end

Recipes.Waiting = function(room)
	local folder = room.Folder
	local fabric = pick(room, 4, FABRICS)
	for _, side in { "Left", "Right", "Front" } do
		Rooms.alongWall(room, side :: Side, 4 * 2.2, 2.2, false, function(frame)
			f.seatRow(folder, frame, 4, fabric)
		end)
	end
	local ct = f.size("CoffeeTable")
	Rooms.item(room, 0, room.Depth / 2, "Front", ct.X, ct.Z, false, function(frame)
		if not f.store(folder, "CoffeeTable", frame) then
			f.coffeeTable(folder, frame, ct.X, ct.Z, Materials.Wood.Oak)
		end
		Parts.part(
			folder,
			"Magazines",
			frame * CFrame.new(0.6, ct.Y + 0.05, 0),
			Vector3.new(1.4, 0.1, 1),
			Parts.detail(Materials.Paper)
		)
	end)
	Rooms.alongWall(room, "Back", 1.4, 1.4, false, function(frame)
		f.waterCooler(folder, frame)
	end)
	plantInCorner(room, 29, true)
	plantInCorner(room, 30)
	local cork = f.size("CorkBoard")
	Rooms.findWall(room, "Back", 5.4, cork.X + 0.6, function(wall)
		if not f.store(folder, "CorkBoard", wall) then
			f.noticeBoard(folder, wall, 4, 3, room.Seed)
		end
	end)
	pictures(room, 1, 31)
	radiators(room, 2)
	services(room)
end

-- Sofa (official model, dark or light upholstery by building), side tables with lamps.
local function sofaKey(room: Room, seats: number): string
	local light = room.Plan.Spec.Style.LightSofas == true
	return (if seats >= 3 then "Sofa3" else "Sofa2") .. (if light then "Light" else "")
end

local function sofaGroup(room: Room, w: number, facing: Side, seats: number): boolean
	local folder = room.Folder
	local key = sofaKey(room, seats)
	local sofa = f.size(key)
	local side = f.size("SideTable")
	return Rooms.item(room, 0, w, facing, sofa.X + 2 * side.X + 0.6, sofa.Z, false, function(frame)
		if not f.store(folder, key, frame) then
			f.sofa(folder, frame, seats, upholsteryOf(room, 10))
		end
		for _, s in { -1, 1 } do
			local at = frame * CFrame.new(s * (sofa.X / 2 + side.X / 2 + 0.25), 0, 0.6)
			if f.store(folder, "SideTable", at) then
				prop(room, "TableLamp", at * CFrame.new(0, side.Y, 0))
			end
		end
	end)
end

Recipes.Lounge = function(room)
	local folder = room.Folder
	local D, W = room.Depth, room.Width
	local up = upholsteryOf(room, 10)
	local rugKey = pick(room, 11, { "RugLarge", "RugKhamseh", "RugSwan" })
	local rugFrame = Rooms.frame(room, 0, D / 2 + 1, "Front")
	if not f.store(folder, rugKey, rugFrame) then
		f.rug(folder, rugFrame, math.min(W - 4, 13), math.min(D - 6, 10), Materials.Floor.CarpetRed)
	end
	local sofa = f.size(sofaKey(room, 3))
	local ct = f.size("CoffeeTable")
	sofaGroup(room, D / 2 + 1 + ct.Z / 2 + 1.3 + sofa.Z / 2, "Front", 3)
	model(room, "CoffeeTable", 0, D / 2 + 1, "Front", false, function(frame)
		f.coffeeTable(folder, frame, ct.X, ct.Z, Materials.Wood.Walnut)
	end)
	local arm = f.size("ArmChair")
	for _, u in { -1, 1 } do
		local facing: Side = if u < 0 then "Right" else "Left"
		model(room, "ArmChair", u * (ct.X / 2 + 1.3 + arm.Z / 2), D / 2 + 0.6, facing, false, function(frame)
			f.armchair(folder, frame, up)
		end)
	end
	local kind = room.Space.Kind
	if kind == "Family" or string.find(room.Space.Name, "Staff") or string.find(room.Space.Name, "Drivers") then
		Rooms.findWall(room, "Back", 6, 7.4, function(wall)
			f.screen(folder, wall, 7)
		end)
	else
		painting(room, "Back", 34, 0.9)
	end
	if large(room) then
		storageWall(room, if noise(room, 35) < 0.5 then "Left" else "Right", 36)
		tableForFour(
			room,
			(if noise(room, 37) < 0.5 then -1 else 1) * (room.Width / 2 - 6),
			6,
			Materials.Wood.Oak,
			Materials.Fabric.Beige
		)
		modelAlong(room, "Back", "Credenza", false, function(frame)
			local c = f.size("Credenza")
			f.cabinet(folder, frame, c.X, c.Z, c.Y, Materials.Wood.Walnut)
		end)
		sittingCorner(room, 38, Materials.Fabric.Green)
	end
	plantInCorner(room, 32, true)
	plantInCorner(room, 33)
	pictures(room, 2, 34, 0.8)
	radiators(room, 2)
	services(room)
end
Recipes.Family = Recipes.Lounge
Recipes.Garden = function(room)
	local folder = room.Folder
	local ct = f.size("CoffeeTable")
	local arm = f.size("ArmChair")
	for _, u in { -1, 1 } do
		local facing: Side = if u < 0 then "Right" else "Left"
		model(room, "ArmChair", u * (ct.X / 2 + 1.2 + arm.Z / 2), room.Depth / 2, facing, false, function(frame)
			f.armchair(folder, frame, Materials.Fabric.Beige)
		end)
	end
	model(room, "CoffeeTable", 0, room.Depth / 2, "Front", false, function(frame)
		f.coffeeTable(folder, frame, ct.X, ct.Z, Materials.Wood.Oak)
	end)
	for k = 1, 4 do
		plantInCorner(room, 40 + k, k % 2 == 1)
	end
end

-- Bank ------------------------------------------------------------------------------------------

Recipes.Counting = function(room)
	local folder = room.Folder
	local W, D = room.Width, room.Depth
	for r = 0, math.max(0, math.floor((D - 8) / 8)) do
		Rooms.item(room, 0, 4 + r * 8, "Front", math.min(12, W - 6), 6, false, function(frame)
			local tl = math.min(12, W - 6)
			f.table(folder, frame, tl, 3, Materials.Plastic.Grey)
			for i = 0, math.max(1, math.floor(tl / 4)) - 1 do
				local x = -tl / 2 + 2 + i * 4
				f.appliance(folder, frame * CFrame.new(x, 3, 0), "Machine") -- banknote counter
				f.officeChair(
					folder,
					frame * CFrame.new(x, 0, -2.4) * CFrame.Angles(0, math.pi, 0),
					Materials.Fabric.Charcoal
				)
			end
		end)
	end
	for _ = 1, 3 do
		Rooms.alongWall(room, "Back", 2.6, 2.4, false, function(frame)
			f.safe(folder, frame)
		end)
	end
	Rooms.findWall(room, "Left", 6.5, 7.4, function(wall)
		f.screen(folder, wall, 7)
	end)
	services(room)
end

Recipes.Vault = function(room)
	local folder = room.Folder
	local steel = Materials.Metal.Steel
	-- Safe deposit boxes from floor to ceiling on the walls, cash on racks in the middle.
	for _, side in { "Back", "Left", "Right" } do
		for _ = 1, 6 do
			Rooms.alongWall(room, side :: Side, 4, 1.6, true, function(frame)
				local h = math.min(9, room.Height - 1)
				Parts.part(folder, "DepositBoxes", frame * CFrame.new(0, h / 2, 0), Vector3.new(4, h, 1.6), steel)
				for row = 0, math.floor(h / 1.2) - 1 do
					Parts.part(
						folder,
						"BoxLine",
						frame * CFrame.new(0, 0.6 + row * 1.2, -0.81),
						Vector3.new(3.9, 0.06, 0.04),
						Parts.detail(Materials.Metal.Dark)
					)
				end
			end)
		end
	end
	local gold = Parts.with(Materials.Metal.Brass, { Color = Color3.fromRGB(212, 172, 72), Reflectance = 0.15 })
	for r = 0, 1 do
		Rooms.item(room, 0, room.Depth / 2 - 3 + r * 6, "Front", 6, 2, true, function(frame)
			f.rack(folder, frame, 6, 2, 6, room.Seed + r, gold)
		end)
	end
end

-- Villa ------------------------------------------------------------------------------------------

-- Floor-length curtains at the windows of a representative room in a home.
function Rooms.curtains(room: Room, fabric: Options)
	local W, D = room.Width, room.Depth
	for _, win in room.Windows do
		local along = (win.From + win.To) / 2
		local p: Vector3, dir: Vector3
		if win.Side == "Front" then
			p, dir = Rooms.world(room, along, 0), room.N
		elseif win.Side == "Back" then
			p, dir = Rooms.world(room, along, D), -room.N
		elseif win.Side == "Left" then
			p, dir = Rooms.world(room, -W / 2, along), room.A
		else
			p, dir = Rooms.world(room, W / 2, along), -room.A
		end
		local top = math.min(win.Top or (room.Height - 1.5), room.Height - 0.8)
		f.curtains(room.Folder, CFrame.lookAt(p, p + dir), win.To - win.From, top, fabric)
	end
end

-- A large official rug scaled down to the room (at most `fill` of it).
local function bigRug(room: Room, w: number, fill: number, fallback: Options)
	local key = "RugHall"
	local size = f.size(key)
	local scale = math.min(1, (room.Width * fill) / size.X, (room.Depth * fill) / size.Z)
	local frame = Rooms.frame(room, 0, w, "Front")
	if not f.store(room.Folder, key, frame, scale) then
		f.rug(room.Folder, frame, size.X * scale, size.Z * scale, fallback)
	end
end

Recipes.Salon = function(room)
	local folder = room.Folder
	local D, W = room.Depth, room.Width
	local up = upholsteryOf(room, 10)
	-- Fireplace on a side wall with the seating around it.
	local fireSide: Side = if noise(room, 2) < 0.5 then "Left" else "Right"
	local lo, hi = Rooms.wallRange(room, fireSide)
	Rooms.onWall(room, fireSide, (lo + hi) / 2, 0, 7.6, function(wall)
		f.fireplace(folder, wall)
		prop(room, "Bowl", wall * CFrame.new(1.8, 5.3, -0.7))
		-- A landscape over the mantel, as large as the wall above it allows.
		local key = pick(room, 3, LANDSCAPES)
		local size = f.size(key)
		local scale = math.clamp((room.Height - 1 - 6.2) / size.Y, 0.4, 0.9)
		local at = wall * CFrame.new(0, 6.2 + size.Y * scale / 2, 0)
		if not f.store(folder, key, at, scale) then
			f.picture(folder, at, size.X * scale, size.Y * scale, room.Seed + 3)
		end
	end)
	bigRug(room, D / 2, 0.62, Materials.Floor.CarpetRed)
	local ct = f.size("CoffeeTable")
	local sofa = f.size(sofaKey(room, 3))
	local gap = ct.Z / 2 + 1.3 + sofa.Z / 2
	sofaGroup(room, D / 2 + gap, "Front", 3)
	model(room, sofaKey(room, 3), 0, D / 2 - gap, "Back", false, function(frame)
		f.sofa(folder, frame, 3, up)
	end)
	model(room, "CoffeeTable", 0, D / 2, "Front", false, function(frame)
		f.coffeeTable(folder, frame, ct.X, ct.Z, Materials.Wood.Walnut)
	end)
	prop(room, "Bowl", Rooms.frame(room, 0.6, D / 2, "Front", ct.Y))
	local arm = f.size("ArmChair")
	for _, u in { -1, 1 } do
		local facing: Side = if u < 0 then "Right" else "Left"
		model(room, "ArmChair", u * (sofa.X / 2 + 1 + arm.Z / 2), D / 2, facing, false, function(frame)
			f.armchair(folder, frame, Materials.Leather.Brown)
		end)
	end
	modelAlong(room, "Back", "Console", false, function(frame)
		local c = f.size("Console")
		f.cabinet(folder, frame, c.X, c.Z, c.Y, Materials.Wood.Mahogany)
	end)
	modelAlong(room, "Back", "GrandfatherClock", true, nil, 1)
	modelAlong(room, "Back", "DisplayCase", true, function(frame)
		local c = f.size("DisplayCase")
		f.cabinet(folder, frame, c.X, c.Z, c.Y, Materials.Wood.Mahogany)
	end, -1)
	storageWall(room, if fireSide == "Left" then "Right" else "Left", 3, true)
	if large(room) then
		sittingCorner(room, 47, Materials.Fabric.Beige)
		tableForFour(
			room,
			(if noise(room, 48) < 0.5 then -1 else 1) * (W / 2 - 6),
			D - 6,
			Materials.Wood.Walnut,
			Materials.Fabric.Red
		)
	end
	pictures(room, 3, 36, 0.85)
	for k = 1, 3 do
		plantInCorner(room, 50 + k, k == 1)
	end
	if room.Plan.Spec.Style.LightSofas then
		Rooms.curtains(room, Materials.Fabric.Beige)
	end
end

-- Music room: a grand piano by the windows, a few chairs for listeners, a console for sheet
-- music, a bookcase, pictures and plants.
Recipes.Music = function(room)
	local folder = room.Folder
	local D = room.Depth
	bigRug(room, D / 2, 0.55, Materials.Floor.CarpetRed)
	-- The pianist faces the room's side wall; the body reaches towards the windows' side.
	Rooms.item(room, 0, 9, "Left", 6, 9.6, false, function(frame)
		if not f.store(folder, "Piano", frame) then
			f.piano(folder, frame * CFrame.new(0, 0, -1.75))
		end
	end)
	for i, u in { -4.5, -1.5, 1.5, 4.5 } do
		model(room, "DiningChair", u, D / 2 + 6 + math.abs(u) * 0.3, "Front", false, function(frame)
			f.chair(
				folder,
				frame,
				Materials.Wood.Walnut,
				if i % 2 == 0 then Materials.Fabric.Red else Materials.Fabric.Beige
			)
		end)
	end
	modelAlong(room, "Back", "Console", false, function(frame)
		local c = f.size("Console")
		f.cabinet(folder, frame, c.X, c.Z, c.Y, Materials.Wood.Mahogany)
	end)
	modelAlong(room, if noise(room, 2) < 0.5 then "Left" else "Right", "BookcaseB", true, function(frame)
		local c = f.size("BookcaseB")
		f.shelf(folder, frame, c.X, c.Z, math.min(c.Y, room.Height - 1.5), Materials.Wood.Walnut, room.Seed + 5)
	end)
	sittingCorner(room, 3, Materials.Leather.Tan)
	pictures(room, 3, 4, 0.85)
	plantInCorner(room, 5, true)
	plantInCorner(room, 6)
	if room.Plan.Spec.Style.LightSofas then
		Rooms.curtains(room, Materials.Fabric.Beige)
	end
end

Recipes.Dining = function(room)
	local folder = room.Folder
	local W, D = room.Width, room.Depth
	local alongW = D >= W
	local key: string? = if math.max(W, D) - 12 >= f.size("LongTable").X then "LongTable" else nil
	local tl = if key then f.size("LongTable").X else math.clamp(math.max(W, D) - 12, 8, 22)
	local tw = if key then f.size("LongTable").Z else 4.4
	local th = if key then f.size("LongTable").Y else 2.95
	bigRug(room, D / 2, 0.68, Materials.Floor.CarpetRed)
	Rooms.item(room, 0, D / 2, if alongW then "Left" else "Front", tl + 4.6, tw + 4.4, false, function(frame)
		if not (key and f.store(folder, key, frame)) then
			f.table(folder, frame, tl, tw, Materials.Wood.Mahogany, th)
		end
		local n = math.floor(tl / 2.8)
		for i = 1, n do
			for _, side in { -1, 1 } do
				local c = frame * CFrame.new(-tl / 2 + (i - 0.5) * tl / n, 0, side * (tw / 2 + 0.8))
				if side < 0 then
					c = c * CFrame.Angles(0, math.pi, 0)
				end
				if not f.store(folder, "DiningChair", c) then
					f.chair(folder, c, Materials.Wood.Walnut, Materials.Fabric.Red)
				end
			end
		end
		for _, side in { -1, 1 } do
			local c = frame * CFrame.new(side * (tl / 2 + 1.1), 0, 0) * CFrame.Angles(0, side * math.pi / 2, 0)
			if not f.store(folder, "ArmDiningChair", c) then
				f.chair(folder, c, Materials.Wood.Walnut, Materials.Fabric.Red)
			end
		end
		for _, x in { -tl / 3, 0, tl / 3 } do
			prop(room, "Bowl", frame * CFrame.new(x, th, 0))
		end
	end)
	modelAlong(room, "Back", "CredenzaLong", false, function(frame)
		local c = f.size("CredenzaLong")
		f.cabinet(folder, frame, c.X, c.Z, c.Y, Materials.Wood.Mahogany)
	end)
	pictures(room, 3, 37, 0.85)
	plantInCorner(room, 54, true)
	plantInCorner(room, 55)
	if room.Plan.Spec.Style.LightSofas then
		Rooms.curtains(room, Materials.Fabric.Beige)
	end
end

Recipes.Kitchen = function(room)
	local folder = room.Folder
	kitchenette(room, 0)
	Rooms.item(room, 0, room.Depth / 2 + 1, "Front", 6, 3, false, function(frame)
		f.counter(folder, frame, 6, 2.8, Materials.Wood.White, Materials.Floor.Marble)
	end)
	Rooms.alongWall(room, "Left", 3, 2.4, false, function(frame)
		f.appliance(folder, frame * CFrame.new(0, 3, 0), "Microwave")
		f.cabinet(folder, frame, 3, 2.4, 3, Materials.Wood.White)
	end)
end

local function bedroom(room: Room, double: boolean, wardrobe: number, guest: boolean?)
	local folder = room.Folder
	local wood = pick(room, 3, { Materials.Wood.Walnut, Materials.Wood.Oak })
	local linen =
		pick(room, 4, { Materials.Fabric.Beige, Materials.Fabric.Blue, Materials.Fabric.Green, Materials.Fabric.Grey })
	local bedKey = if guest then "GuestBed" else "Bed"
	local bed = f.size(bedKey)
	local stand = f.size("Nightstand")
	local bw = if double then bed.X else 3.6
	local bl = if double then bed.Z else 7.6
	Rooms.alongWall(room, "Back", bw + 2 * stand.X + 0.8, bl + 0.4, false, function(frame)
		-- The bed's front is its foot end; the headboard is at the wall (+Z of the frame).
		if not (double and f.store(folder, bedKey, frame)) then
			local l = if double then 7.6 else bl
			f.bed(folder, frame * CFrame.new(0, 0, bl / 2 - l / 2), if double then 6.4 else bw, l, wood, linen)
		end
		for _, side in { -1, 1 } do
			if double or side > 0 then
				local at = frame * CFrame.new(side * (bw / 2 + stand.X / 2 + 0.2), 0, bl / 2 - stand.Z / 2)
				if f.store(folder, "Nightstand", at) then
					prop(room, "TableLamp", at * CFrame.new(0, stand.Y, 0.2))
				else
					f.nightstand(folder, at, wood)
				end
			end
		end
	end)
	local armoire = f.size("Armoire")
	local wardrobeSide: Side = if noise(room, 5) < 0.5 then "Left" else "Right"
	for _ = 1, wardrobe do
		modelAlong(room, wardrobeSide, "Armoire", true, function(frame)
			f.wardrobe(folder, frame, armoire.X, armoire.Z, math.min(armoire.Y, room.Height - 1.5), wood)
		end)
	end
	dresser(room, if wardrobeSide == "Left" then "Right" else "Left", wood)
	local rugKey = pick(room, 6, { "RugLarge", "RugKhamseh", "RugUshak" })
	local rugFrame = Rooms.frame(room, 0, room.Depth - bl - 2.2, "Front")
	if not f.store(folder, rugKey, rugFrame) then
		f.rug(folder, rugFrame, math.min(room.Width - 4, 9), 5, Materials.Fabric.Beige)
	end
	model(room, "ArmChair", room.Width / 2 - 3, 3.8, "Left", false, function(frame)
		f.armchair(folder, frame, linen)
	end)
	if large(room) then
		sittingCorner(room, 57, linen)
		writingDesk(room, 58, wood)
		dresser(room, if noise(room, 59) < 0.5 then "Left" else "Right", wood)
		plantInCorner(room, 60, true)
	end
	pictures(room, 2, 38, 0.8)
	plantInCorner(room, 56)
	if room.Plan.Spec.Style.LightSofas then
		Rooms.curtains(room, linen)
	end
	services(room)
end

Recipes.Bedroom = function(room)
	bedroom(room, true, 2)
end
Recipes.Guest = function(room)
	bedroom(room, true, 1, true)
	writingDesk(room, 61, Materials.Wood.Oak)
end
Recipes.Staff = function(room)
	bedroom(room, false, 1)
	Rooms.alongWall(room, "Left", 2.8, 1.8, true, function(frame)
		f.locker(room.Folder, frame, 2.8)
	end)
end
Recipes.Dressing = function(room)
	local folder = room.Folder
	for _, side in { "Left", "Right", "Back" } do
		for _ = 1, 4 do
			Rooms.alongWall(room, side :: Side, 4, 2.2, true, function(frame)
				f.wardrobe(folder, frame, 4, 2.2, math.min(8, room.Height - 1.5), Materials.Wood.White)
			end)
		end
	end
	Rooms.findWall(room, "Front", 3.5, 3.4, function(wall)
		f.mirror(folder, wall * CFrame.new(0, 2, 0), 3, 7)
	end)
	Rooms.item(room, 0, room.Depth / 2, "Front", 3.6, 1.8, false, function(frame)
		f.bench(folder, frame, 3.6, Materials.Leather.Tan)
	end)
end

-- Circulation ------------------------------------------------------------------------------------

-- The room numbers of the rooms whose doors open onto a circulation space, as "1.01–1.14".
local function roomRange(room: Room): string?
	local plan = room.Plan
	local numbers: { string } = {}
	for _, seg in plan.Segments do
		for _, hole in seg.Holes do
			local other = if hole.Other == room.Space
				then hole.Room
				elseif hole.Room == room.Space then hole.Other
				else nil
			local n = if other then plan.Numbers[other] else nil
			if n and not table.find(numbers, n) then
				table.insert(numbers, n)
			end
		end
	end
	if #numbers == 0 then
		return nil
	end
	table.sort(numbers)
	return if #numbers == 1 then `Room {numbers[1]}` else `Rooms {numbers[1]}–{numbers[#numbers]}`
end

-- Corridors: fire safety along the walls (extinguishers, hose reels, call points, an
-- evacuation plan), exit signs and a direction sign at both ends, notice boards, and benches
-- with paintings and plants in wide ones.
Recipes.Corridor = function(room)
	local folder = room.Folder
	local style = room.Plan.Spec.Style
	local alongSide = room.Width >= room.Depth -- long walls are Front/Back
	local longSides: { Side } = if alongSide then { "Front", "Back" } else { "Left", "Right" }
	local lo, hi = Rooms.wallRange(room, longSides[1])
	local length = hi - lo
	local wide = math.min(room.Width, room.Depth)
	local k = 0
	local s = lo + 10
	while s < hi - 6 do
		k += 1
		local side: Side = longSides[1 + k % 2]
		if k % 3 == 2 then
			Rooms.onWall(room, side, s, 4.2, 2.8, function(wall)
				f.hoseCabinet(folder, wall)
			end)
		else
			Rooms.onWall(room, side, s, 2.6, 1.6, function(wall)
				f.extinguisher(folder, wall)
			end)
		end
		s += 36
	end
	for i = 1, math.max(1, math.floor(length / 50)) do
		local side = longSides[1 + i % 2]
		local cork = f.size("CorkBoard")
		Rooms.findWall(room, side, 5.4, cork.X + 0.6, function(wall)
			if not f.store(folder, "CorkBoard", wall) then
				f.noticeBoard(folder, wall, 4, 3, room.Seed + i)
			end
		end)
	end
	if wide >= 8 then
		for i = 1, math.max(1, math.floor(length / 40)) do
			local at = lo + i * length / (math.floor(length / 40) + 1)
			local side: Side = longSides[1 + (i + 1) % 2]
			local placed = Rooms.against(room, side, at, 5, 1.6, false, function(frame)
				f.bench(folder, frame, 5, style.Wood or Materials.Wood.Oak)
			end)
			if placed then
				painting(room, side, 60 + i, 0.7)
			end
		end
	end
	-- Exit sign, direction sign, call point and evacuation plan at both ends; plants there.
	local endSides: { Side } = if alongSide then { "Left", "Right" } else { "Front", "Back" }
	local range = roomRange(room)
	local storey = if room.Space.Storey == 0 then "G" else tostring(room.Space.Storey)
	for i, side: Side in endSides do
		local elo, ehi = Rooms.wallRange(room, side)
		local mid = (elo + ehi) / 2
		Rooms.onWall(room, side, mid, room.Height - 1.4, 2.4, function(wall)
			f.exitSign(folder, wall)
		end)
		if range and room.Height > 10 then
			Rooms.onWall(room, side, mid, 7.9, 3.6, function(wall)
				local sign = f.sign(
					folder,
					wall,
					3.4,
					1.3,
					{ string.upper(room.Space.Name), range },
					style.Plate or Materials.Plastic.White,
					style.Ink or Color3.fromRGB(40, 44, 52)
				)
				sign.Name = "DirectionSign"
			end)
		end
		Rooms.findWall(room, longSides[i], 4.4, 1, function(wall)
			f.callPoint(folder, wall)
		end)
		if i == 1 then
			Rooms.findWall(room, longSides[2], 5.4, 3.2, function(wall)
				f.evacuationPlan(folder, wall, storey)
			end)
		end
	end
	if wide >= 9 then
		plantInCorner(room, 60, true)
		plantInCorner(room, 61)
	end
end
Recipes.Gallery = Recipes.Corridor
Recipes.Landing = Recipes.Corridor

Recipes.Hall = function(room)
	plantInCorner(room, 62, true)
	plantInCorner(room, 63, true)
	plantInCorner(room, 64)
	plantInCorner(room, 65)
end
Recipes.Lobby = Recipes.Hall

-- A storey sign on the side wall of the landing on each floor.
Recipes.Stair = function(room)
	local plan = room.Plan
	local space = room.Space
	local entry: Edge = space.Entry :: Edge
	local landing = Stairs.landing(space.Rect, entry)
	local cx, cz = (landing.MinX + landing.MaxX) / 2, (landing.MinZ + landing.MaxZ) / 2
	local r = space.Rect
	for s = space.Storey, space.Top or space.Storey do
		local y = Plan.level(plan, s) + 6
		local p: Vector3
		local dir: Vector3
		if entry == "MinX" or entry == "MaxX" then
			p, dir = Vector3.new(cx, y, r.MinZ + Plan.Partition / 2), Vector3.new(0, 0, 1)
		else
			p, dir = Vector3.new(r.MinX + Plan.Partition / 2, y, cz), Vector3.new(1, 0, 0)
		end
		local label = if s == 0 then "G" else tostring(s)
		local sign = f.sign(
			room.Folder,
			CFrame.lookAt(p, p + dir),
			1.6,
			1.6,
			{ label },
			Materials.Plastic.White,
			Color3.fromRGB(30, 40, 60)
		)
		sign.Name = "StoreySign"
	end
end

-- Lift doors (steel leaves in a frame, call button, floor indicator) on every floor, on the
-- wall the shaft shares with an open space.
Recipes.Lift = function(room)
	local plan = room.Plan
	local space = room.Space
	local r = space.Rect
	for s = space.Storey, space.Top or space.Storey do
		for _, e: Edge in Plan.Edges do
			local axis: Plan.Axis, at, f0, f1, out = Plan.edgeLine(r, e)
			local mid = (f0 + f1) / 2
			local x, z = Plan.point(axis, at, mid, out * 0.5)
			local other = Plan.spaceAt(plan, s, x, z)
			if not other or not Plan.isOpen(other) or other.Kind == "Stair" then
				continue
			end
			local y = Plan.level(plan, s)
			local face = at + out * Plan.Partition / 2
			local function at3(sAlong: number, h: number, d: number): Vector3
				local px, pz = Plan.point(axis, face, sAlong, out * d)
				return Vector3.new(px, y + h, pz)
			end
			local dir = if axis == "X" then Vector3.new(0, 0, out) else Vector3.new(out, 0, 0)
			local steel = Materials.Metal.Steel
			local width = math.min(5, f1 - f0 - 1.5)
			for _, side in { -1, 1 } do
				local c = at3(mid + side * width / 4, 3.9, 0.06)
				Parts.part(
					room.Folder,
					"LiftDoor",
					CFrame.lookAt(c, c + dir),
					Vector3.new(width / 2 - 0.05, 7.8, 0.12),
					steel
				)
			end
			local frameO = Parts.detail(Materials.Metal.Dark)
			for _, side in { -1, 1 } do
				local c = at3(mid + side * (width / 2 + 0.25), 4.1, 0.1)
				Parts.part(room.Folder, "LiftFrame", CFrame.lookAt(c, c + dir), Vector3.new(0.5, 8.2, 0.2), frameO)
			end
			local head = at3(mid, 8.45, 0.1)
			Parts.part(
				room.Folder,
				"LiftFrame",
				CFrame.lookAt(head, head + dir),
				Vector3.new(width + 1, 0.5, 0.2),
				frameO
			)
			local indicator = at3(mid, 9.3, 0.08)
			local panel = Parts.part(
				room.Folder,
				"LiftIndicator",
				CFrame.lookAt(indicator, indicator + dir),
				Vector3.new(1.4, 0.6, 0.1),
				Parts.detail(Materials.Plastic.Black)
			)
			panel:SetAttribute("Fitting", "LiftIndicator")
			local button = at3(mid + width / 2 + 1.2, 3.6, 0.06)
			Parts.part(
				room.Folder,
				"LiftButton",
				CFrame.lookAt(button, button + dir),
				Vector3.new(0.4, 0.8, 0.08),
				Parts.detail(Materials.Metal.Chrome)
			)
			break
		end
	end
end

-- Thin wall lining (tiles, panelling) on the room's walls up to `height`, cut at doors and
-- windows. `only` limits it to some walls.
function Rooms.wainscot(room: Room, height: number, options: Options, only: { Side }?)
	local W, D = room.Width, room.Depth
	local h = math.min(height, room.Height)
	local sides: { Side } = only or { "Front", "Back", "Left", "Right" }
	for _, side: Side in sides do
		local lo, hi = Rooms.wallRange(room, side)
		local cuts: { { number } } = {}
		for _, list in { room.Doors, room.Windows } do
			for _, s in list do
				if s.Side == side then
					table.insert(cuts, { s.From - 0.35, s.To + 0.35 })
				end
			end
		end
		table.sort(cuts, function(a: { number }, b: { number })
			return a[1] < b[1]
		end)
		local cursor = lo
		local pieces: { { number } } = {}
		for _, c in cuts do
			if c[1] - cursor > 0.2 then
				table.insert(pieces, { cursor, c[1] })
			end
			cursor = math.max(cursor, c[2])
		end
		if hi - cursor > 0.2 then
			table.insert(pieces, { cursor, hi })
		end
		for _, p in pieces do
			local a, b = p[1], p[2]
			local len = b - a
			local cframe: CFrame
			if side == "Front" then
				cframe = Rooms.frame(room, (a + b) / 2, 0.03, "Back", h / 2)
			elseif side == "Back" then
				cframe = Rooms.frame(room, (a + b) / 2, D - 0.03, "Front", h / 2)
			elseif side == "Left" then
				cframe = Rooms.frame(room, -W / 2 + 0.03, (a + b) / 2, "Right", h / 2)
			else
				cframe = Rooms.frame(room, W / 2 - 0.03, (a + b) / 2, "Left", h / 2)
			end
			Parts.part(room.Folder, "WallTiles", cframe, Vector3.new(len, h, 0.06), Parts.detail(options))
		end
	end
end

-- Linings ---------------------------------------------------------------------------------------
-- Skirting boards on the facade walls (Plan builds them on the partitions), an oil-paint or
-- wooden dado in corridors, and in representative rooms a wooden wainscot with a chair rail and
-- a plaster cornice under the ceiling. Every piece runs between doors and floor-length windows.

Rooms.Representative = {
	Executive = true,
	Committee = true,
	Board = true,
	Cabinet = true,
	Salon = true,
	Library = true,
	Dining = true,
	LeadersOffice = true,
	Study = true,
	Music = true,
	Lounge = true,
	Family = true,
}
local CIRCULATION = { Corridor = true, Gallery = true, Landing = true }
local UNLINED = { WC = true, Bathroom = true, Lift = true, Stair = true }

-- Stretches (along the wall) of `side` that have a wall, without its doors and without the
-- windows whose sill is below `height`. `exterior`: only the facade stretches.
function Rooms.stretches(room: Room, side: Side, height: number, exterior: boolean?): { { number } }
	local lo, hi = Rooms.wallRange(room, side)
	local cuts: { { number } } = {}
	for _, d in room.Doors do
		if d.Side == side then
			table.insert(cuts, { d.From - 0.35, d.To + 0.35 })
		end
	end
	for _, w in room.Windows do
		if w.Side == side and (w.Bottom or 0) < height then
			table.insert(cuts, { w.From - 0.1, w.To + 0.1 })
		end
	end
	table.sort(cuts, function(a: { number }, b: { number })
		return a[1] < b[1]
	end)
	local out: { { number } } = {}
	for _, wall in room.Walls do
		if wall.Side ~= side or (exterior and not wall.Exterior) then
			continue
		end
		local a, b = math.max(lo, wall.From), math.min(hi, wall.To)
		local cursor = a
		for _, c in cuts do
			if c[2] <= cursor or c[1] >= b then
				continue
			end
			if c[1] - cursor > 0.3 then
				table.insert(out, { cursor, c[1] })
			end
			cursor = math.max(cursor, c[2])
		end
		if b - cursor > 0.3 then
			table.insert(out, { cursor, b })
		end
	end
	return out
end

-- A board on the wall face of `side` from a to b, y0..y1 above the floor, `depth` thick.
local function board(
	room: Room,
	side: Side,
	a: number,
	b: number,
	y0: number,
	y1: number,
	depth: number,
	name: string,
	o: Options
)
	local W, D = room.Width, room.Depth
	local mid, h, c = (a + b) / 2, y1 - y0, depth / 2
	local frame: CFrame
	if side == "Front" then
		frame = Rooms.frame(room, mid, c, "Back", y0 + h / 2)
	elseif side == "Back" then
		frame = Rooms.frame(room, mid, D - c, "Front", y0 + h / 2)
	elseif side == "Left" then
		frame = Rooms.frame(room, -W / 2 + c, mid, "Right", y0 + h / 2)
	else
		frame = Rooms.frame(room, W / 2 - c, mid, "Left", y0 + h / 2)
	end
	Parts.part(room.Folder, name, frame, Vector3.new(b - a, h, depth), Parts.detail(o))
end

local SIDES: { Side } = { "Front", "Back", "Left", "Right" }

-- Skirting boards on the facade walls of the room.
function Rooms.skirting(room: Room)
	local o = room.Plan.Spec.Style.Skirting or Materials.Wood.Walnut
	local top = Plan.Skirting - 0.1
	for _, side in SIDES do
		for _, st in Rooms.stretches(room, side, top + 0.1, true) do
			board(room, side, st[1], st[2], -0.1, top, 0.08, "Skirting", o)
		end
	end
end

-- Height of a lining that should end under the window sills (at most `max`).
local function underSills(room: Room, max: number): number
	local h = max
	for _, w in room.Windows do
		if w.Bottom and w.Bottom > 1.5 then
			h = math.min(h, w.Bottom - 0.15)
		end
	end
	return math.max(h, 2.2)
end

-- Corridor dado: oil paint (thin) or a wooden wainscot with a rail, up to about one metre.
function Rooms.dado(room: Room, o: Options, height: number?)
	local wood = o.Material == Enum.Material.Wood or o.Material == Enum.Material.WoodPlanks
	local h = underSills(room, height or 3.4)
	local depth = if wood then 0.1 else 0.04
	for _, side in SIDES do
		for _, st in Rooms.stretches(room, side, h) do
			board(room, side, st[1], st[2], 0, h, depth, "Dado", o)
			if wood then
				board(room, side, st[1], st[2], h - 0.05, h + 0.12, depth + 0.07, "DadoRail", o)
			end
		end
	end
	room.Panel, room.PanelDepth = h + 0.15, depth + 0.07
end

-- Representative rooms: wooden wainscot to the window sills with a chair rail.
function Rooms.panelling(room: Room, o: Options, height: number?)
	local h = underSills(room, height or 3.2)
	local rail = Parts.with(o, { Color = Parts.vary(o.Color or Color3.new(0.4, 0.3, 0.2), room.Seed, 0.08) })
	for _, side in SIDES do
		for _, st in Rooms.stretches(room, side, h) do
			board(room, side, st[1], st[2], -0.1, h, 0.12, "Wainscot", o)
			board(room, side, st[1], st[2], h - 0.04, h + 0.16, 0.2, "ChairRail", rail)
		end
	end
	room.Panel, room.PanelDepth = h + 0.2, 0.2
end

-- Plaster cornice along the top of every wall (cut only where an opening reaches the ceiling).
function Rooms.cornice(room: Room, o: Options?)
	local top = room.Height
	for _, side in SIDES do
		local lo, hi = Rooms.wallRange(room, side)
		local cuts: { { number } } = {}
		for _, list in { room.Doors, room.Windows } do
			for _, opening in list do
				if opening.Side == side and (opening.Top or 0) > top - 0.6 then
					table.insert(cuts, { opening.From, opening.To })
				end
			end
		end
		for _, wall in room.Walls do
			if wall.Side ~= side then
				continue
			end
			local a, b = math.max(lo, wall.From), math.min(hi, wall.To)
			table.sort(cuts, function(p: { number }, q: { number })
				return p[1] < q[1]
			end)
			local cursor = a
			for _, c in cuts do
				if c[2] > cursor and c[1] < b then
					if c[1] - cursor > 0.3 then
						board(room, side, cursor, c[1], top - 0.5, top, 0.32, "Cornice", o or Materials.Ceiling)
					end
					cursor = math.max(cursor, c[2])
				end
			end
			if b - cursor > 0.3 then
				board(room, side, cursor, b, top - 0.5, top, 0.32, "Cornice", o or Materials.Ceiling)
			end
		end
	end
end

-- The linings a room of its kind gets in its building (see the Style fields in Plan.luau).
function Rooms.lining(room: Room)
	local style = room.Plan.Spec.Style
	local kind = room.Space.Kind
	if UNLINED[kind] or room.Height < 6 then
		return
	end
	local representative = (style.Representative or Rooms.Representative)[kind]
	local panel = if style.PanellingBy and style.PanellingBy[kind] then style.PanellingBy[kind] else style.Panelling
	if representative and panel then
		Rooms.panelling(room, panel)
	else
		if CIRCULATION[kind] and style.Dado then
			Rooms.dado(room, style.Dado)
		end
		Rooms.skirting(room)
	end
	if representative then
		Rooms.cornice(room)
	end
end

-- Furnishes a space: linings, then its custom builder or the recipe of its kind.
function Rooms.furnish(plan: Plan.Plan, space: Space, folder: Folder)
	local room = Rooms.context(plan, space, folder)
	if not space.Custom or space.Lining ~= false then
		Rooms.lining(room)
	end
	if space.Custom then
		space.Custom(room)
		return
	end
	local recipe = Recipes[space.Kind]
	if recipe then
		recipe(room)
	end
end

return Rooms
