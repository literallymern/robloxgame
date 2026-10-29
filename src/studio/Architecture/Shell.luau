--!strict
-- Exterior walls with real openings. A building's facades are given as wall runs; each run is
-- built storey by storey as a solid wall with holes for its windows, doors and passages, and
-- every opening gets its assembly (Openings.window / Openings.door). Each window is mapped to the
-- space of the Plan behind it on that storey and recorded there, so the tests can check that
-- every window has a room behind it and that no partition meets the facade inside a window.
-- Windows of washrooms get frosted glass; a window in front of a stair flight gets closed
-- shutters (the half landing would cross it).

local Parts = require(script.Parent.Parts)
local Materials = require(script.Parent.Materials)
local Openings = require(script.Parent.Openings)
local Plan = require(script.Parent.Plan)

type Options = Parts.Options

local Shell = {}

export type WindowRow = {
	Centres: { number }, -- along the wall
	Width: number,
	Height: number,
	Sill: number, -- above the storey floor
	Storeys: { number },
	Style: Openings.WindowStyle?, -- default: the run's style
}

export type DoorSpec = {
	At: number,
	Width: number,
	Height: number,
	Storey: number,
	Double: boolean?,
	Style: Openings.DoorStyle?,
	Label: string?,
	StartOpen: boolean?,
	Working: boolean?,
	Leaf: boolean?, -- false: an opening with a frame only (portals that stay open)
}

export type Passage = { From: number, To: number, Storey: number, Bottom: number?, Top: number? }

export type Run = {
	Name: string?,
	Axis: "X" | "Z",
	At: number, -- centre line of the wall
	From: number,
	To: number,
	Thickness: number,
	Out: number, -- +1 or -1: the outside
	Material: Options,
	Materials: { Options }?, -- per storey (storey 0 first), overrides Material
	Window: Openings.WindowStyle,
	Door: Openings.DoorStyle?,
	Windows: { WindowRow }?,
	Doors: { DoorSpec }?,
	Passages: { Passage }?,
	Storeys: { number }?, -- default: all storeys of the plan
	Top: number?, -- top of the wall on the highest storey (default: the roof slab)
}

-- Window centres: `n` windows `spacing` apart, centred on `mid`.
function Shell.grid(mid: number, spacing: number, n: number): { number }
	local out: { number } = {}
	for i = 0, n - 1 do
		table.insert(out, mid + (i - (n - 1) / 2) * spacing)
	end
	return out
end

-- Window centres from `first` in steps of `spacing` up to `last` (inclusive).
function Shell.steps(first: number, spacing: number, last: number): { number }
	local out: { number } = {}
	local c = first
	while c <= last + 1e-6 do
		table.insert(out, c)
		c += spacing
	end
	return out
end

-- The list without the centres inside any of the ranges (portals, risalits).
function Shell.without(centres: { number }, ranges: { { number } }): { number }
	local out: { number } = {}
	for _, c in centres do
		local skip = false
		for _, r in ranges do
			if c >= r[1] and c <= r[2] then
				skip = true
			end
		end
		if not skip then
			table.insert(out, c)
		end
	end
	return out
end

-- The edge of a space facing this run.
local function edgeOf(run: Run): Plan.Edge
	if run.Axis == "X" then
		return if run.Out > 0 then "MaxZ" else "MinZ"
	end
	return if run.Out > 0 then "MaxX" else "MinX"
end

local function storeysOf(plan: Plan.Plan, run: Run): { number }
	if run.Storeys then
		return run.Storeys
	end
	local list: { number } = {}
	for s = 0, plan.Storeys - 1 do
		table.insert(list, s)
	end
	return list
end

-- True when a partition on `storey` meets this facade between s0 and s1.
local function partitionAt(plan: Plan.Plan, run: Run, storey: number, s0: number, s1: number): boolean
	local inner = run.At - run.Out * run.Thickness / 2
	for _, seg in plan.Segments do
		if seg.Storey ~= storey or seg.Axis == run.Axis then
			continue
		end
		if seg.At > s0 - 0.6 and seg.At < s1 + 0.6 then
			if math.abs(seg.From - inner) < 0.6 or math.abs(seg.To - inner) < 0.6 then
				return true
			end
		end
	end
	return false
end

local function closedShutters(
	parent: Instance,
	wall: Openings.Wall,
	s0: number,
	s1: number,
	y0: number,
	y1: number,
	o: Options
)
	local face = wall.At + wall.Out * wall.Thickness / 2
	local mid = (s0 + s1) / 2
	local panel = Parts.detail(o)
	Openings.wallBox(
		parent,
		"ShutterClosed",
		wall,
		s0 + 0.05,
		mid - 0.03,
		y0,
		y1,
		face - wall.Out * 0.4,
		face - wall.Out * 0.2,
		panel
	)
	Openings.wallBox(
		parent,
		"ShutterClosed",
		wall,
		mid + 0.03,
		s1 - 0.05,
		y0,
		y1,
		face - wall.Out * 0.4,
		face - wall.Out * 0.2,
		panel
	)
end

-- Interior skin: where rooms lie behind a facade, the inner `Plan.Lining` studs of the wall are
-- a separate layer in the building's interior paint (Style.Lining, else Style.Partition), so
-- rooms do not show the facade stone or render on their window wall. The layer stops at the
-- ceiling of the top storey; a parapet above keeps the full facade thickness.
local function lined(
	plan: Plan.Plan,
	parent: Instance,
	run: Run,
	wall: Openings.Wall,
	storey: number,
	y0: number,
	y1: number,
	holes: { Openings.Hole },
	material: Options
)
	local style = plan.Spec.Style
	local paint = style.Lining or style.Partition
	local name = run.Name or "Wall"
	local skin = Plan.Lining
	local top = Plan.level(plan, storey + 1) - (if storey >= plan.Storeys - 1 then plan.Slab else 0)
	top = math.min(top, y1)
	if top - y0 < 1 then
		Openings.solid(parent, name, wall, run.From, run.To, y0, y1, holes, material)
		return
	end
	-- Stretches of the run with the building behind them (cut at the footprint corners).
	local cuts = { run.From, run.To }
	for _, fp in plan.Spec.Footprints do
		local bounds: { number } = if run.Axis == "X" then { fp.MinX, fp.MaxX } else { fp.MinZ, fp.MaxZ }
		for _, c in bounds do
			if c > run.From + 0.01 and c < run.To - 0.01 then
				table.insert(cuts, c)
			end
		end
	end
	table.sort(cuts)
	type Stretch = { From: number, To: number, Inside: boolean }
	local stretches: { Stretch } = {}
	for i = 1, #cuts - 1 do
		local a, b = cuts[i], cuts[i + 1]
		if b - a < 0.01 then
			continue
		end
		local x, z = Plan.point(run.Axis, run.At, (a + b) / 2, -run.Out * (run.Thickness / 2 + 0.5))
		local inside = Plan.inside(plan, x, z)
		local last = stretches[#stretches]
		if last and last.Inside == inside then
			last.To = b
		else
			table.insert(stretches, { From = a, To = b, Inside = inside })
		end
	end
	local half = run.Thickness / 2
	local outer: Openings.Wall =
		{ Axis = run.Axis, At = run.At + run.Out * skin / 2, Thickness = run.Thickness - skin, Out = run.Out }
	local inner: Openings.Wall =
		{ Axis = run.Axis, At = run.At - run.Out * (half - skin / 2), Thickness = skin, Out = run.Out }
	local finish = Parts.with(paint, { CastShadow = false })
	for _, st in stretches do
		if not st.Inside then
			Openings.solid(parent, name, wall, st.From, st.To, y0, y1, holes, material)
			continue
		end
		Openings.solid(parent, name, outer, st.From, st.To, y0, top, holes, material)
		Openings.solid(parent, "WallLining", inner, st.From, st.To, y0, top, holes, finish)
		if y1 - top > 0.01 then
			Openings.solid(parent, name, wall, st.From, st.To, top, y1, holes, material)
		end
	end
end

export type Report = { Windows: number, Doors: number, Unmapped: number, Blocked: number }

-- Builds the runs into `parent` and records their windows and doors in the plan.
function Shell.build(plan: Plan.Plan, parent: Instance, runs: { Run }): Report
	local report: Report = { Windows = 0, Doors = 0, Unmapped = 0, Blocked = 0 }
	for _, run in runs do
		local edge: Plan.Edge = edgeOf(run)
		local rows: { WindowRow } = run.Windows or {}
		local doors: { DoorSpec } = run.Doors or {}
		local passages: { Passage } = run.Passages or {}
		local wall: Openings.Wall = { Axis = run.Axis, At = run.At, Thickness = run.Thickness, Out = run.Out }
		local storeys = storeysOf(plan, run)
		local highest = storeys[#storeys]
		for _, s in storeys do
			local y0 = Plan.level(plan, s)
			local y1 = if s == highest and run.Top then run.Top else Plan.level(plan, s + 1)
			local holes: { Openings.Hole } = {}
			type Win = { S0: number, S1: number, B: number, T: number, Style: Openings.WindowStyle }
			local windows: { Win } = {}
			for _, row in rows do
				if not table.find(row.Storeys, s) then
					continue
				end
				for _, c in row.Centres do
					local w: Win = {
						S0 = c - row.Width / 2,
						S1 = c + row.Width / 2,
						B = y0 + row.Sill,
						T = y0 + row.Sill + row.Height,
						Style = row.Style or run.Window,
					}
					table.insert(windows, w)
					table.insert(holes, { From = w.S0, To = w.S1, Bottom = w.B, Top = w.T })
				end
			end
			-- A door taller than its storey (the portals) also cuts the walls of the storeys above.
			for _, door in doors do
				local bottom = Plan.level(plan, door.Storey)
				local top = bottom + door.Height
				if door.Storey <= s and top > y0 + 0.01 then
					table.insert(holes, {
						From = door.At - door.Width / 2,
						To = door.At + door.Width / 2,
						Bottom = math.max(bottom, y0),
						Top = top,
					})
				end
			end
			for _, passage in passages do
				local base = Plan.level(plan, passage.Storey)
				local top = base + (passage.Top or (Plan.level(plan, passage.Storey + 1) - base - plan.Slab))
				if passage.Storey <= s and top > y0 + 0.01 then
					table.insert(holes, {
						From = passage.From,
						To = passage.To,
						Bottom = math.max(base + (passage.Bottom or 0), y0),
						Top = top,
					})
				end
			end
			local material = if run.Materials then run.Materials[s + 1] or run.Material else run.Material
			lined(plan, parent, run, wall, s, y0, y1, holes, material)
			-- The space behind a point of the wall, on this storey.
			local function behind(along: number): Plan.Space?
				local x, z = Plan.point(run.Axis, run.At, along, -run.Out * (run.Thickness / 2 + 0.5))
				return Plan.spaceAt(plan, s, x, z)
			end
			for _, w in windows do
				local mid = (w.S0 + w.S1) / 2
				local space = behind(mid)
				local style = w.Style
				local shuttered = false
				if space and (space.Kind == "WC" or space.Kind == "Bathroom") then
					style = table.clone(style)
					style.Glass = Materials.Glass.Frosted
				elseif space and space.Kind == "Stair" and s < (space.Top or space.Storey) then
					style = table.clone(style)
					shuttered = true
					if not style.Shutters then
						style.Glass = Materials.Glass.Frosted
					end
				end
				local shutters = style.Shutters
				if shuttered and shutters then
					style.Shutters = nil
				end
				local glass = Openings.window(parent, wall, w.S0, w.S1, w.B, w.T, style)
				if shuttered and shutters then
					closedShutters(parent, wall, w.S0, w.S1, w.B, w.T, shutters)
				end
				if not space then
					report.Unmapped += 1
					warn(`[Ro-Nation:Shell] window at {math.floor(mid)} on storey {s} has no room behind it`)
				end
				if partitionAt(plan, run, s, w.S0, w.S1) then
					report.Blocked += 1
					glass:SetAttribute("PartitionBehind", true)
					warn(`[Ro-Nation:Shell] a partition meets the window at {math.floor(mid)} on storey {s}`)
				end
				if space then
					glass:SetAttribute("Space", Plan.label(plan, space))
				end
				Plan.addWindow(plan, {
					Kind = "Window",
					Storey = s,
					Space = space,
					Edge = edge,
					From = w.S0,
					To = w.S1,
					Bottom = w.B,
					Top = w.T,
					Glass = glass,
					Shuttered = shuttered,
				})
				report.Windows += 1
			end
			for _, door in doors do
				if door.Storey ~= s then
					continue
				end
				local s0, s1 = door.At - door.Width / 2, door.At + door.Width / 2
				local style = door.Style or run.Door
				local inward: Openings.Wall =
					{ Axis = run.Axis, At = run.At, Thickness = run.Thickness, Out = -run.Out }
				if door.Leaf == false or not style then
					Openings.frame(parent, inward, s0, s1, y0, y0 + door.Height, if style then style.Frame else nil)
				elseif door.Double then
					Openings.doubleDoor(parent, inward, s0, s1, y0, y0 + door.Height, style, {
						Swing = -run.Out,
						Label = door.Label,
						StartOpen = door.StartOpen,
						Working = door.Working,
					})
				else
					Openings.door(parent, inward, s0, s1, y0, y0 + door.Height, style, {
						Swing = -run.Out,
						Label = door.Label,
						StartOpen = door.StartOpen,
						Working = door.Working,
					})
				end
				local space = behind(door.At)
				Plan.addWindow(plan, {
					Kind = "Door",
					Storey = s,
					Space = space,
					Edge = edge,
					From = s0,
					To = s1,
					Bottom = y0,
					Top = y0 + door.Height,
				})
				report.Doors += 1
			end
			for _, passage in passages do
				if passage.Storey == s then
					Plan.addWindow(plan, {
						Kind = "Opening",
						Storey = s,
						Space = behind((passage.From + passage.To) / 2),
						Edge = edge,
						From = passage.From,
						To = passage.To,
						Bottom = y0,
						Top = y1,
					})
				end
			end
		end
	end
	return report
end

return Shell
