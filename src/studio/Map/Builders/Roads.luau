--!strict
-- Road surfaces as parts: one straight piece per run of the calculated centre line and height
-- profile (RoadInfo.runs), round joints where a road bends. Bridge runs are left to the bridge
-- builder; markings are built by the road details builder.

local Heightfield = require(script.Parent.Parent.Heightfield)
local Util = require(script.Parent.Util)

local Roads = {}

local THICKNESS = 1.2
-- Where a road ends on another road, its last piece sits this much lower, so the two surfaces
-- never flicker where they overlap (the through road stays on top).
local JUNCTION_DROP = 0.03

type RoadInfo = any

local function point(road: RoadInfo, i: number): Vector3
	return Vector3.new(road.line.xs[i], road.profile[i], road.line.zs[i])
end

-- Point on the straight piece of a run at distance s along the road.
local function onRun(road: RoadInfo, first: number, last: number, s: number): Vector3
	local s0, s1 = road.line.s[first], road.line.s[last]
	return point(road, first):Lerp(point(road, last), (s - s0) / (s1 - s0))
end

export type RunOptions = {
	Bridge: boolean, -- build the bridge runs (true) or the others (false)
	Thickness: number,
	Part: Util.PartOptions,
	First: number?, -- only runs within these samples
	Last: number?,
	LowerBefore: number?, -- the surface before this distance along the road is lowered
	LowerAfter: number?, -- the surface after this distance along the road is lowered
}

-- Builds the straight pieces of a road into `parent`. Returns the number of parts.
function Roads.buildRuns(parent: Instance, road: RoadInfo, o: RunOptions): number
	local bridges, thickness, options = o.Bridge, o.Thickness, o.Part
	local lowerBefore, lowerAfter = o.LowerBefore, o.LowerAfter
	local first, last = o.First or 1, o.Last or #road.line.xs
	local width = road.Width
	local count = 0
	local previousDir: Vector3? = nil
	local previousBridge: boolean? = nil
	for n, run in road.runs do
		local a, b = point(road, run.First), point(road, run.Last)
		local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
		if run.Bridge == bridges and run.First >= first and run.Last <= last then
			local s0, s1 = road.line.s[run.First], road.line.s[run.Last]
			-- Cut points inside this run.
			local cuts: { number } = { s0 }
			if lowerBefore and lowerBefore > s0 and lowerBefore < s1 then
				table.insert(cuts, lowerBefore)
			end
			if lowerAfter and lowerAfter > s0 and lowerAfter < s1 then
				table.insert(cuts, lowerAfter)
			end
			table.insert(cuts, s1)
			for k = 1, #cuts - 1 do
				local pa = onRun(road, run.First, run.Last, cuts[k])
				local pb = onRun(road, run.First, run.Last, cuts[k + 1])
				local mid = (cuts[k] + cuts[k + 1]) / 2
				local lowered = (lowerBefore ~= nil and mid < lowerBefore) or (lowerAfter ~= nil and mid > lowerAfter)
				local drop = Vector3.new(0, if lowered then JUNCTION_DROP else 0, 0)
				Util.strip(parent, `{road.Id} {n}`, pa - drop, pb - drop, width, thickness, options)
				count += 1
			end
			if
				previousDir
				and previousBridge == bridges
				and math.deg(math.acos(math.clamp(previousDir:Dot(dir), -1, 1))) > 1.5
			then
				-- A round joint fills the wedge-shaped gap on the outside of the bend.
				local jointOptions = table.clone(options)
				jointOptions.Shape = Enum.PartType.Cylinder
				local lowered = (lowerBefore ~= nil and s0 < lowerBefore) or (lowerAfter ~= nil and s0 > lowerAfter)
				local top = a.Y - (if lowered then JUNCTION_DROP else 0) - 0.005
				Util.part(
					parent,
					`{road.Id} {n} joint`,
					CFrame.new(a.X, top - thickness / 2, a.Z) * CFrame.Angles(0, 0, math.pi / 2),
					Vector3.new(thickness, width, width),
					jointOptions
				)
				count += 1
			end
		end
		previousDir = dir
		previousBridge = run.Bridge
	end
	return count
end

-- Distances along road `r` before which (and after which) its surface is lowered because it
-- ends on another road there.
function Roads.junctionCuts(hf: Heightfield.Heightfield, r: number): (number?, number?)
	local road = hf.roads.roads[r]
	local lowerBefore, lowerAfter = nil, nil
	for _, junction in hf.roads.junctions do
		if junction.Minor == r then
			local line = road.line
			local inward = if junction.AtStart then 1 else -1
			local i = junction.MinorSample
			-- Walk inwards until the whole width is clear of the other road.
			while i + inward >= 1 and i + inward <= #line.xs do
				if hf.roads.otherDistance(line.xs[i], line.zs[i], r) >= road.Width / 2 + 2 then
					break
				end
				i += inward
			end
			if junction.AtStart then
				lowerBefore = line.s[i]
			else
				lowerAfter = line.s[i]
			end
		end
	end
	return lowerBefore, lowerAfter
end

function Roads.build(hf: Heightfield.Heightfield, layout: any, parent: Instance): number
	local folder = Util.folder(parent, "Roads")
	local total = 0
	for r, road in hf.roads.roads do
		local class = layout.RoadClasses[road.Class]
		local roadFolder = Instance.new("Folder")
		roadFolder.Name = road.Id
		roadFolder:SetAttribute("RoadName", road.Name)
		roadFolder:SetAttribute("RoadClass", road.Class)
		roadFolder.Parent = folder
		local options: Util.PartOptions = {
			Material = (Enum.Material :: any)[class.PartMaterial],
			Color = Util.rgb(class.Color),
		}
		local lowerBefore, lowerAfter = Roads.junctionCuts(hf, r)
		total += Roads.buildRuns(roadFolder, road, {
			Bridge = false,
			Thickness = THICKNESS,
			Part = options,
			LowerBefore = lowerBefore,
			LowerAfter = lowerAfter,
		})
		Util.yield()
	end
	return total
end

return Roads
