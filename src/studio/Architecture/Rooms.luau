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
type Span = { Side: Side, From: number, To: number }
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
	type Raw = { Edge: Edge, From: number, To: number }
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
		if record.Space == space and record.Storey == space.Storey then
			if record.Kind == "Window" then
				table.insert(windows, { Edge = record.Edge, From = record.From, To = record.To })
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
				table.insert(walls, { Edge = e, From = cuts[i], To = cuts[i + 1] })
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
		table.insert(room.Windows, s)
		table.insert(room.Low, zone(room, s, 2.4, 0.5))
	end
	for _, w in walls do
		table.insert(room.Walls, span(room, w.Edge, w.From, w.To))
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

local WOODS = { Materials.Wood.Oak, Materials.Wood.Walnut, Materials.Wood.Pine, Materials.Wood.White }
local FABRICS = { Materials.Fabric.Grey, Materials.Fabric.Blue, Materials.Fabric.Green, Materials.Fabric.Charcoal }
local LEATHERS = { Materials.Leather.Brown, Materials.Leather.Black, Materials.Leather.Oxblood, Materials.Leather.Tan }

local f = Furniture

-- Wall sockets and a thermostat, plus an air conditioner in larger rooms.
local function services(room: Room)
	local folder = room.Folder
	for i, side in { "Left", "Right", "Back" } do
		local lo, hi = Rooms.wallRange(room, side :: Side)
		Rooms.onWall(room, side :: Side, lo + (hi - lo) * (0.3 + 0.4 * noise(room, 40 + i)), 1, 0.5, function(wall)
			f.fitting(folder, wall, "Outlet")
		end)
	end
	if room.Width * room.Depth > 220 and room.Height > 9 then
		Rooms.findWall(room, "Back", room.Height - 1.6, 3.4, function(wall)
			f.airConditioner(folder, wall)
		end)
	end
end

local function plantInCorner(room: Room, k: number)
	local W, D = room.Width, room.Depth
	local corners = { { -W / 2 + 1.1, D - 1.1 }, { W / 2 - 1.1, D - 1.1 }, { -W / 2 + 1.1, 1.1 }, { W / 2 - 1.1, 1.1 } }
	local start = 1 + math.floor(noise(room, k) * 4)
	for i = 0, 3 do
		local c = corners[1 + (start + i - 1) % 4]
		if
			Rooms.item(room, c[1], c[2], "Front", 1.8, 1.8, false, function(frame)
				f.plant(room.Folder, frame.Position, 4.5 + noise(room, k + 1) * 2.5, room.Seed + k)
			end)
		then
			return
		end
	end
end

local function pictures(room: Room, count: number, k: number)
	for i = 1, count do
		local choices: { Side } = { "Left", "Right", "Back" }
		local side: Side = choices[1 + math.floor(noise(room, k + i) * 3) % 3]
		local w = 3 + noise(room, k + 10 + i) * 2
		Rooms.findWall(room, side, 5.6, w + 0.6, function(wall)
			f.picture(room.Folder, wall, w, w * 0.72, room.Seed + i)
		end)
	end
end

local function storageWall(room: Room, side: Side, k: number)
	local wood = tint(pick(room, k, WOODS), room, k)
	local h = math.min(8, room.Height - 1.5)
	Rooms.alongWall(room, side, 4, 1.5, true, function(frame)
		f.shelf(room.Folder, frame, 4, 1.5, h, wood, room.Seed + k)
	end, if noise(room, k + 2) < 0.5 then -1 else 1)
	Rooms.alongWall(room, side, 3, 1.8, false, function(frame)
		f.cabinet(room.Folder, frame, 3, 1.8, 3.4, wood)
	end)
end

-- Pieces for large rooms in homes ----------------------------------------------------------------

local function large(room: Room): boolean
	return room.Width * room.Depth > 700
end

-- Two armchairs facing each other over a small table, with a floor lamp, near the windows.
local function sittingCorner(room: Room, k: number, upholstery: Options): boolean
	local folder = room.Folder
	local W = room.Width
	local sign = if noise(room, k) < 0.5 then -1 else 1
	for _, u in { sign * (W / 2 - 5.5), -sign * (W / 2 - 5.5) } do
		if
			Rooms.item(room, u, 5.5, "Front", 9.6, 4.2, false, function(frame)
				f.table(folder, frame, 2.4, 2.4, Materials.Wood.Walnut)
				f.armchair(folder, frame * CFrame.new(3.2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), upholstery)
				f.armchair(folder, frame * CFrame.new(-3.2, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), upholstery)
				f.floorLamp(folder, (frame * CFrame.new(0, 0, 1.6)).Position)
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
	for _, s: Side in { side, if side == "Left" then "Right" else "Left" } do
		if
			Rooms.alongWall(room, s, 5.2, 5, false, function(frame)
				local desk = frame * CFrame.new(0, 0, 1.2)
				f.desk(room.Folder, desk, 5, 2.6, wood)
				Parts.cylinder(
					room.Folder,
					"DeskLamp",
					(desk * CFrame.new(-1.8, 3.04, 0.6)).Position,
					(desk * CFrame.new(-1.8, 4.3, 0.6)).Position,
					0.25,
					Parts.detail(Materials.Metal.Brass)
				)
				Parts.cylinder(
					room.Folder,
					"DeskLampShade",
					(desk * CFrame.new(-1.8, 4.1, 0.6)).Position,
					(desk * CFrame.new(-1.8, 4.8, 0.6)).Position,
					1.1,
					Parts.detail(Materials.Fabric.Beige)
				)
				f.chair(
					room.Folder,
					frame * CFrame.new(0, 0, -1.2) * CFrame.Angles(0, math.pi, 0),
					wood,
					Materials.Fabric.Beige
				)
			end)
		then
			return true
		end
	end
	return false
end

-- A low chest of drawers with a mirror over it.
local function dresser(room: Room, side: Side, wood: Options): boolean
	return Rooms.alongWall(room, side, 5, 1.8, false, function(frame)
		f.cabinet(room.Folder, frame, 5, 1.8, 3.2, wood)
		f.mirror(room.Folder, frame * CFrame.new(0, 6.2, 0.9), 3.6, 3.4)
	end)
end

-- A round table with four chairs.
local function tableForFour(room: Room, u: number, w: number, wood: Options, fabric: Options?): boolean
	return Rooms.item(room, u, w, "Front", 7.6, 7.6, false, function(frame)
		f.table(room.Folder, frame, 3.6, 3.6, wood)
		for i = 0, 3 do
			local a = i * math.pi / 2
			f.chair(room.Folder, frame * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 2.9), wood, fabric)
		end
	end)
end

-- Desk with its chair, the user sitting between the desk and the window (facing the room).
local function workplace(room: Room, u: number, w: number, deskW: number, executive: boolean?): boolean
	local deskD = if executive then 3.6 else 3
	local top = tint(if executive then Materials.Wood.Walnut else pick(room, 3, WOODS), room, 3)
	local fabric = if executive then pick(room, 4, LEATHERS) else pick(room, 4, FABRICS)
	-- The whole workplace (chair zone in front of the desk) must be free.
	-- The frame faces the window; its local +Z points into the room. Chair zone first (3.5 deep),
	-- then the desk.
	local depth = deskD + 3.5
	return Rooms.item(room, u, w + depth / 2, "Front", deskW + 0.4, depth, false, function(frame)
		local deskBase = frame * CFrame.new(0, 0, depth / 2 - deskD / 2)
		f.desk(room.Folder, deskBase, deskW, deskD, top)
		f.computer(room.Folder, deskBase, 3.04, executive or noise(room, 5) < 0.3)
		local chair = frame * CFrame.new(0, 0, -depth / 2 + 1.2) * CFrame.Angles(0, math.pi, 0)
		f.officeChair(room.Folder, chair, fabric)
		f.bin(room.Folder, (deskBase * CFrame.new(deskW / 2 - 0.6, 0, 0.6)).Position)
	end)
end

-- Recipes --------------------------------------------------------------------------------------

local Recipes: { [string]: (room: Room) -> () } = {}
Rooms.Recipes = Recipes

local function office(room: Room, executive: boolean)
	local W, D = room.Width, room.Depth
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
	local wood = pick(room, 6, WOODS)
	for _, u in { -1.6, 1.6 } do
		Rooms.item(room, u, 1.6 + 3.5 + (if executive then 3.6 else 3) + 1.2, "Front", 1.9, 1.9, false, function(frame)
			f.chair(room.Folder, frame, wood, pick(room, 7, FABRICS))
		end)
	end
	storageWall(room, if noise(room, 8) < 0.5 then "Left" else "Right", 9)
	if executive then
		-- A sitting corner at the back: sofa, armchairs, coffee table on a rug.
		local leather = pick(room, 10, LEATHERS)
		if D > 22 and W > 12 then
			f.rug(room.Folder, Rooms.frame(room, 0, D - 7, "Front"), math.min(W - 4, 12), 9, Materials.Fabric.Red)
			Rooms.item(room, 0, D - 2, "Front", 8.4, 2.8, false, function(frame)
				f.sofa(room.Folder, frame, 3, leather)
			end)
			Rooms.item(room, 0, D - 6.5, "Front", 4.5, 2.6, false, function(frame)
				f.coffeeTable(room.Folder, frame, 4.5, 2.6, Materials.Wood.Walnut)
			end)
			for _, u in { -4.6, 4.6 } do
				Rooms.item(room, u, D - 7.5, if u < 0 then "Right" else "Left", 3, 2.8, false, function(frame)
					f.armchair(room.Folder, frame, leather)
				end)
			end
		end
		storageWall(room, if noise(room, 8) < 0.5 then "Right" else "Left", 11)
		pictures(room, 2, 12)
	else
		pictures(room, 1, 12)
		if noise(room, 13) < 0.5 then
			Rooms.findWall(room, "Back", 5, 5.5, function(wall)
				f.whiteboard(room.Folder, wall, 5, 3.2)
			end)
		else
			Rooms.findWall(room, "Back", 5, 4.2, function(wall)
				f.noticeBoard(room.Folder, wall, 4, 3, room.Seed)
			end)
		end
	end
	plantInCorner(room, 14)
	Rooms.findWall(room, "Back", room.Height - 3.2, 1.6, function(wall)
		f.clock(room.Folder, wall)
	end)
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

-- Conference table with chairs, a screen and a whiteboard.
local function meeting(room: Room, formal: boolean)
	local W, D = room.Width, room.Depth
	local alongW = D >= W
	local long = math.max(W, D) - 9
	local short = math.min(W, D) - 9
	local tl = math.clamp(long, 5, if formal then 34 else 18)
	local tw = math.clamp(short, 3.5, if formal then 7 else 5)
	local top = tint(if formal then Materials.Wood.Mahogany else pick(room, 3, WOODS), room, 3)
	local seat = if formal then pick(room, 4, LEATHERS) else pick(room, 4, FABRICS)
	local wood = pick(room, 5, WOODS)
	local cu, cw = 0, D / 2
	local facing: Side = if alongW then "Left" else "Front"
	local placed = Rooms.item(room, cu, cw, facing, tl, tw, false, function(frame)
		f.table(room.Folder, frame, tl, tw, top)
		local n = math.max(1, math.floor(tl / 2.8))
		for i = 1, n do
			local x = -tl / 2 + (i - 0.5) * tl / n
			for _, side in { -1, 1 } do
				local chair = frame * CFrame.new(x, 0, side * (tw / 2 + 1.1))
				if side < 0 then
					chair = chair * CFrame.Angles(0, math.pi, 0)
				end
				if formal then
					f.officeChair(room.Folder, chair, seat)
				else
					f.chair(room.Folder, chair, wood, seat)
				end
			end
		end
		for _, side in { -1, 1 } do
			local chair = frame * CFrame.new(side * (tl / 2 + 1.1), 0, 0) * CFrame.Angles(0, side * math.pi / 2, 0)
			f.officeChair(room.Folder, chair, seat)
		end
	end)
	if not placed then
		Rooms.item(room, 0, D / 2, "Front", 4, 4, false, function(frame)
			f.table(room.Folder, frame, 4, 4, top)
			for k = 0, 3 do
				f.chair(room.Folder, frame * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, 3), wood, seat)
			end
		end)
	end
	-- Screen at one end, whiteboard or flipchart at the other.
	local ends: { Side } = if alongW then { "Back", "Front" } else { "Left", "Right" }
	Rooms.findWall(room, ends[1], 6, 8, function(wall)
		f.screen(room.Folder, wall, 7)
	end)
	Rooms.findWall(room, ends[2], 5, 5.5, function(wall)
		f.whiteboard(room.Folder, wall, 5, 3.2)
	end)
	local sides: { Side } = if alongW then { "Left", "Right" } else { "Back" }
	Rooms.alongWall(room, sides[1], 6, 1.8, false, function(frame)
		f.cabinet(room.Folder, frame, 6, 1.8, 3, wood)
		f.appliance(room.Folder, frame * CFrame.new(1.6, 3, 0), "Kettle")
	end)
	plantInCorner(room, 18)
	plantInCorner(room, 19)
	pictures(room, if formal then 3 else 1, 20)
	Rooms.findWall(room, sides[#sides], room.Height - 3.2, 1.6, function(wall)
		f.clock(room.Folder, wall)
	end)
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
				f.appliance(folder, frame * CFrame.new(0.4, 3, 0.3), "CoffeeMachine")
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
	local wood = tint(Materials.Wood.Walnut, room, 2)
	for _, side in { "Back", "Left", "Right" } do
		for k = 1, 6 do
			Rooms.alongWall(room, side :: Side, 4, 1.5, true, function(frame)
				f.shelf(room.Folder, frame, 4, 1.5, math.min(9, room.Height - 1.5), wood, room.Seed + k * 3)
			end)
		end
	end
	local tables = math.max(1, math.floor((D - 10) / 8))
	for t = 0, tables - 1 do
		Rooms.item(room, 0, 5 + t * 8, "Front", math.min(10, W - 8), 6.5, false, function(frame)
			local tl = math.min(10, W - 8)
			f.table(room.Folder, frame, tl, 3.4, Materials.Wood.Oak)
			for i = 1, math.max(1, math.floor(tl / 3)) do
				for _, side in { -1, 1 } do
					local c = frame
						* CFrame.new(-tl / 2 + (i - 0.5) * tl / math.max(1, math.floor(tl / 3)), 0, side * 2.6)
					if side < 0 then
						c = c * CFrame.Angles(0, math.pi, 0)
					end
					f.chair(room.Folder, c, Materials.Wood.Walnut, Materials.Leather.Brown)
				end
			end
		end)
	end
	Rooms.item(room, W / 2 - 3, D - 4, "Left", 3, 2.8, false, function(frame)
		f.armchair(room.Folder, frame, Materials.Leather.Oxblood)
		f.floorLamp(room.Folder, (frame * CFrame.new(2.2, 0, 0.8)).Position)
	end)
	plantInCorner(room, 28)
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
	Rooms.item(room, 0, room.Depth / 2, "Front", 4, 2.4, false, function(frame)
		f.coffeeTable(folder, frame, 4, 2.4, Materials.Wood.Oak)
		Parts.part(
			folder,
			"Magazines",
			frame * CFrame.new(0.6, 1.5, 0),
			Vector3.new(1.4, 0.1, 1),
			Parts.detail(Materials.Paper)
		)
	end)
	Rooms.alongWall(room, "Back", 1.4, 1.4, false, function(frame)
		f.waterCooler(folder, frame)
	end)
	plantInCorner(room, 29)
	plantInCorner(room, 30)
	Rooms.findWall(room, "Back", 5, 4.2, function(wall)
		f.noticeBoard(folder, wall, 4, 3, room.Seed)
	end)
	pictures(room, 1, 31)
	services(room)
end

Recipes.Lounge = function(room)
	local folder = room.Folder
	local leather = pick(room, 10, LEATHERS)
	local D = room.Depth
	f.rug(
		folder,
		Rooms.frame(room, 0, D / 2, "Front"),
		math.min(room.Width - 4, 14),
		math.min(D - 6, 10),
		pick(room, 11, { Materials.Fabric.Red, Materials.Fabric.Beige, Materials.Fabric.Green })
	)
	Rooms.item(room, 0, D / 2 + 4, "Front", 8.4, 2.8, false, function(frame)
		f.sofa(folder, frame, 3, leather)
	end)
	Rooms.item(room, 0, D / 2, "Front", 4.5, 2.6, false, function(frame)
		f.coffeeTable(folder, frame, 4.5, 2.6, Materials.Wood.Walnut)
	end)
	for _, u in { -5, 5 } do
		Rooms.item(room, u, D / 2 - 1, if u < 0 then "Right" else "Left", 3, 2.8, false, function(frame)
			f.armchair(folder, frame, leather)
		end)
	end
	Rooms.findWall(room, "Back", 6, 7.4, function(wall)
		f.screen(folder, wall, 7)
	end)
	if large(room) then
		storageWall(room, if noise(room, 35) < 0.5 then "Left" else "Right", 36)
		tableForFour(
			room,
			(if noise(room, 37) < 0.5 then -1 else 1) * (room.Width / 2 - 5),
			5,
			Materials.Wood.Oak,
			Materials.Fabric.Beige
		)
		Rooms.alongWall(room, "Back", 6, 1.8, false, function(frame)
			f.cabinet(folder, frame, 6, 1.8, 3.2, Materials.Wood.Walnut)
		end)
		sittingCorner(room, 38, Materials.Fabric.Green)
	end
	plantInCorner(room, 32)
	plantInCorner(room, 33)
	pictures(room, 2, 34)
	services(room)
end
Recipes.Family = Recipes.Lounge
Recipes.Garden = function(room)
	local folder = room.Folder
	for _, u in { -3, 3 } do
		Rooms.item(room, u, room.Depth / 2, if u < 0 then "Right" else "Left", 3, 2.8, false, function(frame)
			f.armchair(folder, frame, Materials.Fabric.Beige)
		end)
	end
	Rooms.item(room, 0, room.Depth / 2, "Front", 2.6, 2.6, false, function(frame)
		f.coffeeTable(folder, frame, 2.6, 2.6, Materials.Wood.Pine)
	end)
	for k = 1, 4 do
		plantInCorner(room, 40 + k)
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

Recipes.Salon = function(room)
	local folder = room.Folder
	local D, W = room.Depth, room.Width
	local fabric = pick(room, 10, { Materials.Fabric.Beige, Materials.Fabric.Green, Materials.Fabric.Blue })
	-- Fireplace on a side wall with the seating around it.
	local fireSide: Side = if noise(room, 2) < 0.5 then "Left" else "Right"
	local lo, hi = Rooms.wallRange(room, fireSide)
	Rooms.onWall(room, fireSide, (lo + hi) / 2, 0, 7, function(wall)
		f.fireplace(folder, wall)
	end)
	f.rug(folder, Rooms.frame(room, 0, D / 2, "Front"), math.min(W - 6, 18), math.min(D - 8, 14), Materials.Fabric.Red)
	Rooms.item(room, 0, D / 2 + 5, "Front", 11, 2.8, false, function(frame)
		f.sofa(folder, frame, 4, fabric)
	end)
	Rooms.item(room, 0, D / 2 - 5, "Back", 8.4, 2.8, false, function(frame)
		f.sofa(folder, frame, 3, fabric)
	end)
	Rooms.item(room, 0, D / 2, "Front", 6, 3.2, false, function(frame)
		f.coffeeTable(folder, frame, 6, 3.2, Materials.Wood.Walnut)
	end)
	for _, u in { -7.5, 7.5 } do
		Rooms.item(room, u, D / 2, if u < 0 then "Right" else "Left", 3, 2.8, false, function(frame)
			f.armchair(folder, frame, Materials.Leather.Brown)
		end)
		Rooms.item(room, u, D / 2 + 4.5, "Front", 1.4, 1.4, false, function(frame)
			f.floorLamp(folder, frame.Position)
		end)
	end
	Rooms.alongWall(room, "Back", 7, 1.8, false, function(frame)
		f.cabinet(folder, frame, 7, 1.8, 3.4, Materials.Wood.Mahogany)
	end)
	storageWall(room, if fireSide == "Left" then "Right" else "Left", 3)
	if large(room) then
		sittingCorner(room, 47, Materials.Fabric.Beige)
		tableForFour(
			room,
			(if noise(room, 48) < 0.5 then -1 else 1) * (W / 2 - 5),
			D - 5,
			Materials.Wood.Walnut,
			Materials.Fabric.Red
		)
	end
	pictures(room, 4, 36)
	for k = 1, 3 do
		plantInCorner(room, 50 + k)
	end
end

-- Music room: a grand piano by the windows, a few chairs for listeners, a cabinet for sheet
-- music, pictures and plants.
Recipes.Music = function(room)
	local folder = room.Folder
	local W, D = room.Width, room.Depth
	f.rug(folder, Rooms.frame(room, 0, D / 2, "Front"), math.min(W - 4, 14), math.min(D - 6, 16), Materials.Fabric.Red)
	-- The pianist faces the room's side wall; the body reaches towards the windows' side.
	Rooms.item(room, 0, 9, "Left", 6, 9.6, false, function(frame)
		f.piano(folder, frame * CFrame.new(0, 0, -1.75))
	end)
	for i, u in { -4.5, -1.5, 1.5, 4.5 } do
		Rooms.item(room, u, D / 2 + 6 + math.abs(u) * 0.3, "Front", 2, 2, false, function(frame)
			f.chair(
				folder,
				frame,
				Materials.Wood.Walnut,
				if i % 2 == 0 then Materials.Fabric.Red else Materials.Fabric.Beige
			)
		end)
	end
	Rooms.alongWall(room, "Back", 6, 1.8, false, function(frame)
		f.cabinet(folder, frame, 6, 1.8, 3.6, Materials.Wood.Mahogany)
	end)
	Rooms.alongWall(room, if noise(room, 2) < 0.5 then "Left" else "Right", 4, 1.5, true, function(frame)
		f.shelf(folder, frame, 4, 1.5, math.min(8, room.Height - 1.5), Materials.Wood.Walnut, room.Seed + 5)
	end)
	sittingCorner(room, 3, Materials.Leather.Tan)
	pictures(room, 3, 4)
	plantInCorner(room, 5)
	plantInCorner(room, 6)
end

Recipes.Dining = function(room)
	local folder = room.Folder
	local W, D = room.Width, room.Depth
	local alongW = D >= W
	local tl = math.clamp(math.max(W, D) - 12, 8, 22)
	Rooms.item(room, 0, D / 2, if alongW then "Left" else "Front", tl, 4.4, false, function(frame)
		f.table(folder, frame, tl, 4.4, Materials.Wood.Mahogany)
		local n = math.floor(tl / 2.8)
		for i = 1, n do
			for _, side in { -1, 1 } do
				local c = frame * CFrame.new(-tl / 2 + (i - 0.5) * tl / n, 0, side * 3.3)
				if side < 0 then
					c = c * CFrame.Angles(0, math.pi, 0)
				end
				f.chair(folder, c, Materials.Wood.Walnut, Materials.Fabric.Red)
			end
		end
		for _, side in { -1, 1 } do
			f.chair(
				folder,
				frame * CFrame.new(side * (tl / 2 + 1.3), 0, 0) * CFrame.Angles(0, side * math.pi / 2, 0),
				Materials.Wood.Walnut,
				Materials.Fabric.Red
			)
		end
	end)
	Rooms.alongWall(room, "Back", 8, 2, false, function(frame)
		f.cabinet(folder, frame, 8, 2, 3.6, Materials.Wood.Mahogany)
	end)
	pictures(room, 3, 37)
	plantInCorner(room, 54)
	plantInCorner(room, 55)
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

local function bedroom(room: Room, double: boolean, wardrobe: number)
	local folder = room.Folder
	local wood = pick(room, 3, { Materials.Wood.Walnut, Materials.Wood.Oak, Materials.Wood.White })
	local linen =
		pick(room, 4, { Materials.Fabric.Beige, Materials.Fabric.Blue, Materials.Fabric.Green, Materials.Fabric.Grey })
	local bw = if double then 6.4 else 3.6
	local bl = 7.6
	Rooms.alongWall(room, "Back", bw + 0.4, bl + 0.4, false, function(frame)
		f.bed(folder, frame, bw, bl, wood, linen)
		for _, side in { -1, 1 } do
			if double or side > 0 then
				f.nightstand(folder, frame * CFrame.new(side * (bw / 2 + 1.2), 0, bl / 2 - 0.9), wood)
			end
		end
	end)
	for _ = 1, wardrobe do
		Rooms.alongWall(room, if noise(room, 5) < 0.5 then "Left" else "Right", 4, 2.2, true, function(frame)
			f.wardrobe(folder, frame, 4, 2.2, math.min(8, room.Height - 1.5), wood)
		end)
	end
	Rooms.alongWall(room, "Front", 4, 1.8, false, function(frame)
		f.cabinet(folder, frame, 4, 1.8, 3, wood)
	end)
	f.rug(
		folder,
		Rooms.frame(room, 0, room.Depth - bl - 1, "Front"),
		math.min(room.Width - 4, 9),
		5,
		Materials.Fabric.Beige
	)
	Rooms.item(room, room.Width / 2 - 2.5, 3.5, "Left", 3, 2.8, false, function(frame)
		f.armchair(folder, frame, linen)
	end)
	if large(room) then
		sittingCorner(room, 57, linen)
		writingDesk(room, 58, wood)
		dresser(room, if noise(room, 59) < 0.5 then "Left" else "Right", wood)
		plantInCorner(room, 60)
	end
	pictures(room, 2, 38)
	plantInCorner(room, 56)
	services(room)
end

Recipes.Bedroom = function(room)
	bedroom(room, true, 2)
end
Recipes.Guest = function(room)
	bedroom(room, true, 1)
	workplace(room, -room.Width / 4, 1.6, 5)
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

-- Corridors: fire extinguishers, exit signs, notice boards, benches and plants in wide ones.
Recipes.Corridor = function(room)
	local folder = room.Folder
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
		Rooms.onWall(room, side, s, 2.6, 1.6, function(wall)
			f.extinguisher(folder, wall)
		end)
		s += 36
	end
	for i = 1, math.max(1, math.floor(length / 50)) do
		Rooms.findWall(room, longSides[1 + i % 2], 5.2, 4.4, function(wall)
			f.noticeBoard(folder, wall, 4, 3, room.Seed + i)
		end)
	end
	if wide >= 8 then
		for i = 1, math.max(1, math.floor(length / 40)) do
			local at = lo + i * length / (math.floor(length / 40) + 1)
			local side: Side = longSides[1 + (i + 1) % 2]
			Rooms.onWall(room, side, at, 5.6, 5, function(wall)
				f.picture(folder, wall, 4, 3, room.Seed + i)
			end)
			Rooms.against(room, side, at, 5, 1.6, false, function(frame)
				f.bench(folder, frame, 5, Materials.Wood.Oak)
			end)
		end
	end
	-- Exit signs over both ends, plants in the end corners.
	local endSides: { Side } = if alongSide then { "Left", "Right" } else { "Front", "Back" }
	for _, side: Side in endSides do
		local elo, ehi = Rooms.wallRange(room, side)
		Rooms.onWall(room, side, (elo + ehi) / 2, room.Height - 1.4, 2.4, function(wall)
			f.exitSign(folder, wall)
		end)
	end
	if wide >= 9 then
		plantInCorner(room, 60)
		plantInCorner(room, 61)
	end
end
Recipes.Gallery = Recipes.Corridor
Recipes.Landing = Recipes.Corridor

Recipes.Hall = function(room)
	plantInCorner(room, 62)
	plantInCorner(room, 63)
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

-- Furnishes a space: its custom builder, or the recipe of its kind.
function Rooms.furnish(plan: Plan.Plan, space: Space, folder: Folder)
	local room = Rooms.context(plan, space, folder)
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
