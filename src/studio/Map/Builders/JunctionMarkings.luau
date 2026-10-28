--!strict
-- Restore the clipped R3/N5 markings, including on saved maps with missing/hidden paint.
-- Read the actual carriageway top; terrain is deliberately excluded from these probes.
local Junction = require(script.Parent.Parent.JunctionLandscape)
local Util = require(script.Parent.Util)
local Markings = {}

function Markings.clip(a: Vector3, b: Vector3): (number?, number?)
	local lo, hi = 0, 1
	for _, axis in { "X", "Z" } do
		local delta = b[axis] - a[axis]
		local minimum, maximum = Junction.Bounds["Min" .. axis], Junction.Bounds["Max" .. axis]
		if math.abs(delta) < 1e-8 then
			if a[axis] < minimum or a[axis] > maximum then
				return nil, nil
			end
		else
			local t0, t1 = (minimum - a[axis]) / delta, (maximum - a[axis]) / delta
			lo, hi = math.max(lo, math.min(t0, t1)), math.min(hi, math.max(t0, t1))
		end
	end
	if hi <= lo then
		return nil, nil
	end
	return lo, hi
end

function Markings.surface(map: Instance): (Vector3) -> Vector3?
	local include = {}
	for _, name in { "Roads", "Bridges" } do
		local folder = map:FindFirstChild(name)
		if folder then
			table.insert(include, folder)
		end
	end
	local params = RaycastParams.new()
	params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Include, include
	return function(p: Vector3): Vector3?
		if #include == 0 then
			return nil
		end
		local hit = workspace:Raycast(p + Vector3.new(0, 6, 0), Vector3.new(0, -12, 0), params)
		return if hit then Vector3.new(p.X, hit.Position.Y + 0.055, p.Z) else nil
	end
end

function Markings.build(details: any, parent: Instance, sample: (Vector3) -> Vector3?): (number, boolean)
	local folder = Util.folder(parent, "Markings")
	local count, complete = 0, true
	for _, m in details.markings do
		local a, b = Vector3.new(m.AX, m.AY, m.AZ), Vector3.new(m.BX, m.BY, m.BZ)
		local lo, hi = Markings.clip(a, b)
		if lo == nil or hi == nil then
			continue
		end
		local first, last = a:Lerp(b, lo), a:Lerp(b, hi)
		local pieces = math.max(1, math.ceil((last - first).Magnitude / 24))
		for i = 1, pieces do
			local pa, pb = sample(first:Lerp(last, (i - 1) / pieces)), sample(first:Lerp(last, i / pieces))
			if pa and pb then
				Util.strip(folder, m.Kind, pa, pb, m.Width, 0.035, {
					Material = Enum.Material.SmoothPlastic,
					Color = Color3.fromRGB(226, 223, 212),
					Decoration = true,
				})
				count += 1
			else
				complete = false
			end
		end
	end
	-- A missing road probe must not remove existing paint or leave two paint layers.
	if not complete then
		folder:Destroy()
		return 0, false
	end
	return count, true
end

function Markings.removeReplaced(map: Instance)
	local details = map:FindFirstChild("RoadDetails")
	local folder = if details and Util.isGenerated(details) then details:FindFirstChild("Markings") else nil
	for _, part in if folder then folder:GetChildren() else {} do
		if not part:IsA("BasePart") or not table.find({ "Centre", "Edge", "Stop" }, part.Name) then
			continue
		end
		local top = part.Position + part.CFrame.UpVector * part.Size.Y / 2
		local a, b = top - part.CFrame.LookVector * part.Size.Z / 2, top + part.CFrame.LookVector * part.Size.Z / 2
		local lo, hi = Markings.clip(a, b)
		if lo == nil or hi == nil then
			continue
		end
		for _, span in { { 0, lo }, { hi, 1 } } do
			local pa, pb = a:Lerp(b, span[1]), a:Lerp(b, span[2])
			if (pb - pa).Magnitude > 0.01 then
				local retained = part:Clone()
				retained.Size = Vector3.new(part.Size.X, part.Size.Y, (pb - pa).Magnitude)
				local frame = CFrame.lookAt((pa + pb) / 2, pb)
				retained.CFrame = frame - frame.UpVector * part.Size.Y / 2
				retained.Parent = folder
			end
		end
		part:Destroy()
	end
end

return Markings
