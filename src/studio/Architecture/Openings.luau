--!strict
-- Windows and doors set into real wall openings (the wall pieces around the opening are built by
-- the wall builder, so every window has a reveal and every door a passage).
--
-- Window: recessed glass, a four-piece frame, mullion and transom bars, an outer sill that
-- sheds water, an inner window board, and optionally a facade surround, a lintel, open
-- shutters or security bars.
-- Door: an architrave frame, a leaf with lever handles on both sides and, for working doors,
-- a hinge and a ProximityPrompt. The server's DoorService swings tagged doors open and shut.

local CollectionService = game:GetService("CollectionService")
local Parts = require(script.Parent.Parts)
local Materials = require(script.Parent.Materials)

type Options = Parts.Options

local Openings = {}

-- A straight wall: it runs along `Axis`, its centre line is at `At` (the other horizontal
-- coordinate), `Out` (+1 or -1) points to the outside (for interior walls: any side).
export type Wall = { Axis: "X" | "Z", At: number, Thickness: number, Out: number }

-- A box in wall coordinates: s along the wall, y up, d across (world coordinate across the wall).
local function wallBox(
	parent: Instance,
	name: string,
	wall: Wall,
	s0: number,
	s1: number,
	y0: number,
	y1: number,
	d0: number,
	d1: number,
	options: Options?
): Part
	if wall.Axis == "X" then
		return Parts.box(parent, name, s0, y0, d0, s1, y1, d1, options)
	end
	return Parts.box(parent, name, d0, y0, s0, d1, y1, s1, options)
end
Openings.wallBox = wallBox

export type Hole = { From: number, To: number, Bottom: number, Top: number }

-- A solid wall from s0 to s1 along `wall`, y0 to y1 high, with rectangular holes (windows,
-- doors, passages). The wall is cut into horizontal bands at the hole edges; each band keeps its
-- solid stretches, and stretches that line up with the band below are merged, so a row of equal
-- windows costs one piece below, one above and one pier between each pair. Returns the parts.
function Openings.solid(
	parent: Instance,
	name: string,
	wall: Wall,
	s0: number,
	s1: number,
	y0: number,
	y1: number,
	holes: { Hole }?,
	options: Options?
): { Part }
	local list: { Hole } = {}
	local given: { Hole } = holes or {}
	for _, h in given do
		local a, b = math.max(h.From, s0), math.min(h.To, s1)
		local lo, hi = math.max(h.Bottom, y0), math.min(h.Top, y1)
		if b - a > 0.01 and hi - lo > 0.01 then
			table.insert(list, { From = a, To = b, Bottom = lo, Top = hi })
		end
	end
	local levels = { y0, y1 }
	for _, h in list do
		table.insert(levels, h.Bottom)
		table.insert(levels, h.Top)
	end
	table.sort(levels)
	local ys: { number } = {}
	for _, y in levels do
		if #ys == 0 or y - ys[#ys] > 0.01 then
			table.insert(ys, y)
		end
	end
	type Piece = { From: number, To: number, Bottom: number, Top: number }
	local open: { Piece } = {} -- pieces that may still grow upwards
	local done: { Piece } = {}
	for i = 1, #ys - 1 do
		local lo, hi = ys[i], ys[i + 1]
		local cuts: { { number } } = {}
		for _, h in list do
			if h.Bottom <= lo + 0.01 and h.Top >= hi - 0.01 then
				table.insert(cuts, { h.From, h.To })
			end
		end
		table.sort(cuts, function(p: { number }, q: { number })
			return p[1] < q[1]
		end)
		local spans: { { number } } = {}
		local cursor = s0
		for _, c in cuts do
			if c[1] - cursor > 0.01 then
				table.insert(spans, { cursor, c[1] })
			end
			cursor = math.max(cursor, c[2])
		end
		if s1 - cursor > 0.01 then
			table.insert(spans, { cursor, s1 })
		end
		local nextOpen: { Piece } = {}
		for _, span in spans do
			local grown = false
			for k, piece in open do
				if math.abs(piece.From - span[1]) < 0.01 and math.abs(piece.To - span[2]) < 0.01 then
					piece.Top = hi
					table.insert(nextOpen, piece)
					table.remove(open, k)
					grown = true
					break
				end
			end
			if not grown then
				table.insert(nextOpen, { From = span[1], To = span[2], Bottom = lo, Top = hi })
			end
		end
		for _, piece in open do
			table.insert(done, piece)
		end
		open = nextOpen
	end
	for _, piece in open do
		table.insert(done, piece)
	end
	local half = wall.Thickness / 2
	local built: { Part } = {}
	for _, piece in done do
		table.insert(
			built,
			wallBox(
				parent,
				name,
				wall,
				piece.From,
				piece.To,
				piece.Bottom,
				piece.Top,
				wall.At - half,
				wall.At + half,
				options
			)
		)
	end
	return built
end

export type WindowStyle = {
	Frame: Options,
	Glass: Options?,
	Sill: Options?, -- outer sill (stone)
	Board: Options?, -- inner window board
	Surround: Options?, -- trim around the opening on the facade
	Lintel: Options?, -- a heavier head over the opening on the facade
	Shutters: Options?, -- open shutters beside the opening
	Bars: Options?, -- security bars in the outer reveal
	Recess: number?, -- glass set back from the outer face (default: middle of the wall)
	Mullion: boolean?, -- false = no vertical bar (default: when wider than 3 studs)
}

-- A window in the opening s0..s1 x y0..y1 of `wall`. Returns the glass pane.
function Openings.window(
	parent: Instance,
	wall: Wall,
	s0: number,
	s1: number,
	y0: number,
	y1: number,
	style: WindowStyle
): Part
	local out = wall.Out
	local face = wall.At + out * wall.Thickness / 2 -- outer face
	local inner = wall.At - out * wall.Thickness / 2
	local glassAt = face - out * (style.Recess or wall.Thickness / 2)
	local frame = style.Frame
	local fw, fd = 0.35, 0.5
	local f0, f1 = glassAt - fd / 2, glassAt + fd / 2
	local glass = wallBox(
		parent,
		"WindowGlass",
		wall,
		s0 + 0.05,
		s1 - 0.05,
		y0 + 0.05,
		y1 - 0.05,
		glassAt - 0.06,
		glassAt + 0.06,
		style.Glass or Materials.Glass.Window
	)
	glass:SetAttribute("Window", true)
	local detail = Parts.detail(frame)
	wallBox(parent, "WindowFrame", wall, s0, s0 + fw, y0, y1, f0, f1, detail)
	wallBox(parent, "WindowFrame", wall, s1 - fw, s1, y0, y1, f0, f1, detail)
	wallBox(parent, "WindowFrame", wall, s0 + fw, s1 - fw, y1 - fw, y1, f0, f1, detail)
	wallBox(parent, "WindowFrame", wall, s0 + fw, s1 - fw, y0, y0 + fw, f0, f1, detail)
	local width, height = s1 - s0, y1 - y0
	if style.Mullion ~= false and width > 3 then
		local mid = (s0 + s1) / 2
		wallBox(parent, "WindowMullion", wall, mid - 0.12, mid + 0.12, y0 + fw, y1 - fw, f0 + 0.05, f1 - 0.05, detail)
	end
	if height > 6.5 then
		local t = y1 - height * 0.27
		wallBox(parent, "WindowTransom", wall, s0 + fw, s1 - fw, t - 0.12, t + 0.12, f0 + 0.05, f1 - 0.05, detail)
	end
	-- Outer sill sloping water off the facade, inner board on the room side.
	local sill = style.Sill or Materials.Wall.Concrete
	wallBox(parent, "WindowSill", wall, s0 - 0.4, s1 + 0.4, y0 - 0.35, y0 + 0.05, glassAt, face + out * 0.7, sill)
	wallBox(
		parent,
		"WindowBoard",
		wall,
		s0 - 0.2,
		s1 + 0.2,
		y0 - 0.15,
		y0 + 0.05,
		inner - out * 0.3,
		glassAt - out * fd / 2,
		Parts.detail(style.Board or Materials.Wood.White)
	)
	if style.Surround then
		local trim = Parts.detail(style.Surround)
		wallBox(parent, "WindowSurround", wall, s0 - 0.55, s0, y0 - 0.35, y1 + 0.6, face, face + out * 0.25, trim)
		wallBox(parent, "WindowSurround", wall, s1, s1 + 0.55, y0 - 0.35, y1 + 0.6, face, face + out * 0.25, trim)
		wallBox(parent, "WindowSurround", wall, s0, s1, y1, y1 + 0.6, face, face + out * 0.25, trim)
	end
	if style.Lintel then
		wallBox(
			parent,
			"WindowLintel",
			wall,
			s0 - 0.5,
			s1 + 0.5,
			y1 + (if style.Surround then 0.6 else 0),
			y1 + (if style.Surround then 1.4 else 0.9),
			face,
			face + out * 0.55,
			Parts.detail(style.Lintel)
		)
	end
	if style.Shutters then
		local panel = Parts.detail(style.Shutters)
		local w = width / 2
		wallBox(
			parent,
			"Shutter",
			wall,
			s0 - (if style.Surround then 0.55 else 0) - w,
			s0 - (if style.Surround then 0.55 else 0),
			y0,
			y1,
			face,
			face + out * 0.18,
			panel
		)
		wallBox(
			parent,
			"Shutter",
			wall,
			s1 + (if style.Surround then 0.55 else 0),
			s1 + (if style.Surround then 0.55 else 0) + w,
			y0,
			y1,
			face,
			face + out * 0.18,
			panel
		)
	end
	if style.Bars then
		local bar = Parts.detail(style.Bars)
		local n = math.max(2, math.floor(width / 1.2))
		for i = 1, n do
			local s = s0 + i * width / (n + 1)
			wallBox(parent, "WindowBar", wall, s - 0.1, s + 0.1, y0, y1, face - out * 0.45, face - out * 0.25, bar)
		end
	end
	return glass
end

export type DoorStyle = {
	Leaf: Options,
	Frame: Options?,
	Handle: Options?,
	Glass: Options?, -- glazed leaf: a frame of the leaf material around a glass pane
	KickPlate: Options?,
}

export type DoorOptions = {
	Hinge: "Start" | "End"?, -- hinge at the s0 end ("Start") or the s1 end
	Swing: number?, -- +1 or -1: the side the leaf opens to (default: wall.Out)
	Working: boolean?, -- false = a fixed leaf (no prompt), default true
	Label: string?, -- prompt object text, e.g. "Office 1.04"
	StartOpen: boolean?,
	Frame: boolean?, -- false = no architrave (inner leaf of a double door)
}

-- A door leaf in the opening s0..s1 x y0..y1 of `wall`, with its frame. Returns the door model.
function Openings.door(
	parent: Instance,
	wall: Wall,
	s0: number,
	s1: number,
	y0: number,
	y1: number,
	style: DoorStyle,
	options: DoorOptions?
): Model
	local opts: DoorOptions = options or {}
	local model = Instance.new("Model")
	model.Name = "Door"
	model.Parent = parent
	local half = wall.Thickness / 2
	local swing = opts.Swing or wall.Out
	if opts.Frame ~= false then
		local frame = style.Frame or Materials.Frame.White
		local d0, d1 = wall.At - half - 0.08, wall.At + half + 0.08
		wallBox(model, "DoorFrame", wall, s0 - 0.35, s0, y0, y1 + 0.35, d0, d1, Parts.detail(frame))
		wallBox(model, "DoorFrame", wall, s1, s1 + 0.35, y0, y1 + 0.35, d0, d1, Parts.detail(frame))
		wallBox(model, "DoorFrame", wall, s0, s1, y1, y1 + 0.35, d0, d1, Parts.detail(frame))
	end
	-- The leaf sits near the face it swings to; the hinge is on that face at one end.
	local lt = 0.25
	local plane = wall.At + swing * (half - lt / 2 - 0.05)
	local a, b = s0 + 0.04, s1 - 0.04
	local leafParts: { BasePart } = {}
	local leaf: Part
	if style.Glass then
		leaf = wallBox(model, "Leaf", wall, a, b, y0 + 0.05, y0 + 1.6, plane - lt / 2, plane + lt / 2, style.Leaf)
		local w = math.min(0.6, (b - a) / 5)
		for _, piece in
			{
				{ a, a + w, y0 + 1.6, y1 - 0.6 },
				{ b - w, b, y0 + 1.6, y1 - 0.6 },
				{ a, b, y1 - 0.6, y1 - 0.05 },
			}
		do
			table.insert(
				leafParts,
				wallBox(
					model,
					"LeafFrame",
					wall,
					piece[1],
					piece[2],
					piece[3],
					piece[4],
					plane - lt / 2,
					plane + lt / 2,
					style.Leaf
				)
			)
		end
		table.insert(
			leafParts,
			wallBox(model, "LeafGlass", wall, a + w, b - w, y0 + 1.6, y1 - 0.6, plane - 0.05, plane + 0.05, style.Glass)
		)
	else
		leaf = wallBox(model, "Leaf", wall, a, b, y0 + 0.05, y1 - 0.05, plane - lt / 2, plane + lt / 2, style.Leaf)
	end
	local hingeAtStart = opts.Hinge ~= "End"
	local latch = if hingeAtStart then b - 0.5 else a + 0.5
	local handle = Parts.detail(style.Handle or Materials.Metal.Chrome)
	local hy = y0 + 3.4
	for _, side in { -1, 1 } do
		local d = plane + side * (lt / 2 + 0.12)
		local towards = if hingeAtStart then -1 else 1
		table.insert(
			leafParts,
			wallBox(
				model,
				"Handle",
				wall,
				latch + math.min(0, towards * 0.7),
				latch + math.max(0, towards * 0.7),
				hy - 0.07,
				hy + 0.07,
				d - 0.07,
				d + 0.07,
				handle
			)
		)
		table.insert(
			leafParts,
			wallBox(
				model,
				"HandleRose",
				wall,
				latch - 0.12,
				latch + 0.12,
				hy - 0.12,
				hy + 0.12,
				plane + side * lt / 2,
				d,
				handle
			)
		)
	end
	if style.KickPlate then
		for _, side in { -1, 1 } do
			local d = plane + side * lt / 2
			table.insert(
				leafParts,
				wallBox(
					model,
					"KickPlate",
					wall,
					a + 0.2,
					b - 0.2,
					y0 + 0.1,
					y0 + 1,
					d,
					d + side * 0.03,
					Parts.detail(style.KickPlate)
				)
			)
		end
	end
	for _, part in leafParts do
		part:SetAttribute("MovesWithLeaf", true)
	end
	-- The hinge axis (vertical, through this point) and the angle that opens the leaf towards
	-- the swing side. DoorService turns the leaf parts about it.
	local hingeS = if hingeAtStart then s0 else s1
	local hingeD = plane + swing * lt / 2
	local hinge = if wall.Axis == "X" then Vector3.new(hingeS, y0, hingeD) else Vector3.new(hingeD, y0, hingeS)
	local along = if hingeAtStart then 1 else -1 -- direction from the hinge along the leaf
	local sign = if wall.Axis == "X" then -swing * along else swing * along
	model:SetAttribute("Hinge", hinge)
	model:SetAttribute("OpenAngle", 95 * sign)
	leaf:SetAttribute("MovesWithLeaf", true)
	if opts.Working ~= false then
		Openings.makeWorking(model, leaf, opts.Label, opts.StartOpen)
	end
	return model
end

-- Tags a door model for DoorService and gives it a prompt on `leaf`.
function Openings.makeWorking(model: Model, leaf: BasePart, label: string?, startOpen: boolean?)
	model:SetAttribute("RoNationDoor", true)
	model:SetAttribute("StartOpen", startOpen == true)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- leaf and hinge stream together
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DoorPrompt"
	prompt.ActionText = if startOpen then "Close" else "Open"
	prompt.ObjectText = label or "Door"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = leaf
	CollectionService:AddTag(model, "RoNationDoor")
end

-- An architrave around the opening s0..s1 (both faces of the wall), without a leaf: arches,
-- passages and the frame of a double door.
function Openings.frame(parent: Instance, wall: Wall, s0: number, s1: number, y0: number, y1: number, options: Options?)
	local half = wall.Thickness / 2
	local d0, d1 = wall.At - half - 0.08, wall.At + half + 0.08
	local o = Parts.detail(options or Materials.Frame.White)
	wallBox(parent, "DoorFrame", wall, s0 - 0.35, s0, y0, y1 + 0.35, d0, d1, o)
	wallBox(parent, "DoorFrame", wall, s1, s1 + 0.35, y0, y1 + 0.35, d0, d1, o)
	wallBox(parent, "DoorFrame", wall, s0, s1, y1, y1 + 0.35, d0, d1, o)
end

-- Two leaves in one opening, opening together (one prompt on the first leaf).
function Openings.doubleDoor(
	parent: Instance,
	wall: Wall,
	s0: number,
	s1: number,
	y0: number,
	y1: number,
	style: DoorStyle,
	options: DoorOptions?
): Model
	local opts: DoorOptions = options or {}
	local model = Instance.new("Model")
	model.Name = "DoubleDoor"
	model.Parent = parent
	Openings.frame(model, wall, s0, s1, y0, y1, style.Frame)
	local mid = (s0 + s1) / 2
	local first = Openings.door(model, wall, s0, mid, y0, y1, style, {
		Hinge = "Start",
		Swing = opts.Swing,
		Working = false,
		Frame = false,
	})
	Openings.door(model, wall, mid, s1, y0, y1, style, {
		Hinge = "End",
		Swing = opts.Swing,
		Working = false,
		Frame = false,
	})
	if opts.Working ~= false then
		Openings.makeWorking(model, first:FindFirstChild("Leaf") :: BasePart, opts.Label, opts.StartOpen)
	end
	return model
end

return Openings
