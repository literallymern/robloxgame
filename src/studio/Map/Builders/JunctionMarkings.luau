--!strict
-- Restore the clipped R3/N5 markings, including on saved maps with missing/hidden paint.
-- Read the actual carriageway top, including visible terrain asphalt above saved parts.
local Junction = require(script.Parent.Parent.JunctionLandscape)
local Util = require(script.Parent.Util)
local Markings = {}

function Markings.clip(a: Vector3, b: Vector3): (number?, number?)
	local lo, hi = 0, 1
	local bounds = Junction.Bounds
	for _, axis in { { a.X, b.X, bounds.MinX, bounds.MaxX }, { a.Z, b.Z, bounds.MinZ, bounds.MaxZ } } do
		local from, minimum, maximum = axis[1], axis[3], axis[4]
		local delta = axis[2] - from
		if math.abs(delta) < 1e-8 then
			if from < minimum or from > maximum then
				return nil, nil
			end
		else
			local t0, t1 = (minimum - from) / delta, (maximum - from) / delta
			lo, hi = math.max(lo, math.min(t0, t1)), math.min(hi, math.max(t0, t1))
		end
	end
	if hi <= lo then
		return nil, nil
	end
	return lo, hi
end

-- Terrain asphalt can be the visible top of a smoothed saved road bed. Never paint grass.
function Markings.surface(map: Instance, cast: any?): (Vector3) -> Vector3?
	local include = { workspace.Terrain }
	for _, name in { "Roads", "Bridges" } do
		local folder = map:FindFirstChild(name)
		if folder then
			table.insert(include, folder)
		end
	end
	local params = RaycastParams.new()
	params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Include, include
	local raycast = cast
		or function(origin: Vector3, direction: Vector3, options: RaycastParams)
			return workspace:Raycast(origin, direction, options)
		end
	return function(p: Vector3): Vector3?
		local hit = raycast(p + Vector3.new(0, 64, 0), Vector3.new(0, -128, 0), params)
		if not hit or (hit.Instance == workspace.Terrain and hit.Material ~= Enum.Material.Asphalt) then
			return nil
		end
		return Vector3.new(p.X, hit.Position.Y + 0.065, p.Z)
	end
end

function Markings.build(details: any, parent: Instance, sample: (Vector3) -> Vector3?): any
	local folder = Util.folder(parent, "Markings")
	local coverage, skipped, examples = {}, 0, {}
	for _, m in details.markings do
		local a, b = Vector3.new(m.AX, m.AY, m.AZ), Vector3.new(m.BX, m.BY, m.BZ)
		local lo, hi = Markings.clip(a, b)
		if lo == nil or hi == nil then
			continue
		end
		local first, last = a:Lerp(b, lo), a:Lerp(b, hi)
		local pieces = math.max(1, math.ceil((last - first).Magnitude / 24))
		for i = 1, pieces do
			-- Probe just inside each strip: exact run boundaries can fall in tiny part seams.
			local a0, b0 = first:Lerp(last, (i - 1) / pieces), first:Lerp(last, i / pieces)
			local pa, pb = sample(a0:Lerp(b0, 0.002)), sample(a0:Lerp(b0, 0.998))
			local mid = sample((a0 + b0) / 2)
			if pa and pb and mid then
				local lift = math.max(0, mid.Y - (pa.Y + pb.Y) / 2)
				pa, pb = Vector3.new(a0.X, pa.Y + lift, a0.Z), Vector3.new(b0.X, pb.Y + lift, b0.Z)
				Util.strip(folder, m.Kind, pa, pb, m.Width, 0.035, {
					Material = Enum.Material.SmoothPlastic,
					Color = Color3.fromRGB(226, 223, 212),
					Decoration = true,
				})
				table.insert(coverage, { A = pa, B = pb, Kind = m.Kind })
			else
				skipped += 1
				if #examples < 4 then
					table.insert(examples, string.format("%s (%.1f, %.1f, %.1f)", m.Kind, a0.X, a0.Y, a0.Z))
				end
			end
		end
	end
	return #coverage, skipped == 0, coverage, skipped, examples
end

-- Remove only intervals for which replacement paint exists. Keep gaps and outside paint.
local function retain(part: BasePart, coverage: any, parent: Instance)
	local top = part.Position + part.CFrame.UpVector * part.Size.Y / 2
	local a, b = top - part.CFrame.LookVector * part.Size.Z / 2, top + part.CFrame.LookVector * part.Size.Z / 2
	local dx, dz = b.X - a.X, b.Z - a.Z
	local squared = dx * dx + dz * dz
	local cuts = {}
	if squared > 1e-8 then
		local length = math.sqrt(squared)
		for _, span in coverage do
			if span.Kind ~= part.Name then
				continue
			end
			local function project(p: Vector3): (number, number)
				return ((p.X - a.X) * dx + (p.Z - a.Z) * dz) / squared,
					math.abs((p.X - a.X) * dz - (p.Z - a.Z) * dx) / length
			end
			local t0, d0 = project(span.A)
			local t1, d1 = project(span.B)
			if d0 <= 0.08 and d1 <= 0.08 then
				local lo, hi = math.max(0, math.min(t0, t1)), math.min(1, math.max(t0, t1))
				if hi - lo > 1e-6 then
					table.insert(cuts, { lo, hi })
				end
			end
		end
	end
	if #cuts == 0 then
		part:Clone().Parent = parent
		return
	end
	table.sort(cuts, function(x, y)
		return x[1] < y[1]
	end)
	local function keep(lo: number, hi: number)
		local pa, pb = a:Lerp(b, lo), a:Lerp(b, hi)
		if (pb - pa).Magnitude <= 0.01 then
			return
		end
		local clone = part:Clone()
		clone.Size = Vector3.new(part.Size.X, part.Size.Y, (pb - pa).Magnitude)
		local frame = CFrame.lookAt((pa + pb) / 2, pb)
		clone.CFrame, clone.Parent = frame - frame.UpVector * part.Size.Y / 2, parent
	end
	local cursor = 0
	for _, cut in cuts do
		if cut[1] > cursor then
			keep(cursor, cut[1])
		end
		cursor = math.max(cursor, cut[2])
	end
	keep(cursor, 1)
end

function Markings.retainPrevious(old: Instance?, replacement: Instance, coverage: any): number
	local before = #replacement:GetChildren()
	local previous: { Instance } = if old then old:GetChildren() else {}
	for _, part in previous do
		if part:IsA("BasePart") then
			retain(part, coverage, replacement)
		end
	end
	-- Global refresh can regenerate paint beneath retained regional sections. Include those
	-- retained spans when pruning global paint, without treating them as newly probed sections.
	for index, part in replacement:GetChildren() do
		if index > before and part:IsA("BasePart") then
			local top = part.Position + part.CFrame.UpVector * part.Size.Y / 2
			table.insert(coverage, {
				A = top - part.CFrame.LookVector * part.Size.Z / 2,
				B = top + part.CFrame.LookVector * part.Size.Z / 2,
				Kind = part.Name,
			})
		end
	end
	return #replacement:GetChildren() - before
end

function Markings.removeReplaced(map: Instance, coverage: any)
	if #coverage == 0 then
		return
	end
	local details = map:FindFirstChild("RoadDetails")
	local folder = if details and Util.isGenerated(details) then details:FindFirstChild("Markings") else nil
	if not folder then
		return
	end
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") and table.find({ "Centre", "Edge", "Stop" }, part.Name) then
			local top = part.Position + part.CFrame.UpVector * part.Size.Y / 2
			local lo = Markings.clip(
				top - part.CFrame.LookVector * part.Size.Z / 2,
				top + part.CFrame.LookVector * part.Size.Z / 2
			)
			if lo ~= nil then
				retain(part, coverage, folder)
				part:Destroy()
			end
		end
	end
end

return Markings
