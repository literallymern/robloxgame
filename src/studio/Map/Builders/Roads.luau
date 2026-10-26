--!strict
-- Road surfaces as parts: one straight piece per run of the calculated centre line and height
-- profile (RoadInfo.runs), round joints where a road bends. Bridge runs are left to the bridge
-- builder; markings are built by the road details builder.

local Heightfield = require(script.Parent.Parent.Heightfield)
local Hash = require(script.Parent.Parent.Hash)
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
	Weathering: boolean?, -- very small, coherent asphalt colour variation; no extra geometry
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
			local runOptions = options
			if o.Weathering and options.Color then
				local colour = options.Color
				-- Broad maintenance/age differences, kept deliberately subtle so seams do not read
				-- as alternating tiles. Roblox's Asphalt material supplies the surface grain.
				local factor = 1 + 0.035 * math.noise((s0 + s1) / 700, road.line.xs[run.First] / 1800, 18.7)
				runOptions = table.clone(options)
				runOptions.Color = Color3.new(colour.R * factor, colour.G * factor, colour.B * factor)
			end
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
				Util.strip(parent, `{road.Id} {n}`, pa - drop, pb - drop, width, thickness, runOptions)
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

-- Gravel is placed on the existing road bed, rather than scattered across the countryside.
-- All three probes must be clear of junctions, settlements and bridge approaches. The outer
-- shoulder and drainage swale remain terrain, avoiding a second layer of roadside parts.
local function roadside(hf: Heightfield.Heightfield, layout: any, r: number, parent: Instance): number
	local road = hf.roads.roads[r]
	local folder = Instance.new("Folder")
	folder.Name = "SurfaceDetails"
	folder.Parent = parent
	local gravel: Util.PartOptions = {
		Material = Enum.Material.Pebble,
		Color = Color3.fromRGB(119, 108, 89),
		CastShadow = false,
	}
	local patch: Util.PartOptions = {
		Material = Enum.Material.Asphalt,
		Color = Color3.fromRGB(53, 53, 55),
		Decoration = true,
	}
	local count = 0
	local function clear(p: Vector3): boolean
		if hf.roads.otherDistance(p.X, p.Z, r) < 7 then
			return false
		end
		for _, place in layout.Places do
			local rect = place.Rect
			if p.X > rect.MinX - 6 and p.X < rect.MaxX + 6 and p.Z > rect.MinZ - 6 and p.Z < rect.MaxZ + 6 then
				return false
			end
		end
		local distance, _, _, halfWidth = hf.river.nearest(p.X, p.Z)
		return distance - halfWidth > hf.river.bankWidth + 4 and hf.lakes.shoreDistance(p.X, p.Z) > 5
	end
	for n, run in road.runs do
		if run.Bridge then
			continue
		end
		local a, b = point(road, run.First), point(road, run.Last)
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		if flat.Magnitude < 1 then
			continue
		end
		local across = Vector3.new(-flat.Z, 0, flat.X).Unit
		for side = -1, 1, 2 do
			local offset = across * (road.Width / 2 + 0.9) * side - Vector3.new(0, 0.08, 0)
			local pa, pb = a + offset, b + offset
			if clear(pa) and clear(pb) and clear((pa + pb) / 2) then
				Util.strip(folder, "GravelShoulder", pa, pb, 1.8, 0.65, gravel)
				count += 1
			end
		end
		-- Occasional narrow resurfacing repairs, below the markings and with no collision.
		-- Short curved pieces and junction approaches receive none.
		if flat.Magnitude > 90 and Hash.unit(r, n, 71) < 0.32 and clear((a + b) / 2) then
			local t = 0.3 + 0.4 * Hash.unit(r, n, 72)
			local mid = a:Lerp(b, t) + across * (road.Width * 0.22) * (if n % 2 == 0 then 1 else -1)
			local halfLength = 4 + 5 * Hash.unit(r, n, 73)
			local slopeDir = (b - a).Unit
			local lift = Vector3.new(0, 0.025, 0)
			local pa, pb = mid - slopeDir * halfLength + lift, mid + slopeDir * halfLength + lift
			if not clear(pa) or not clear(pb) then
				continue
			end
			Util.strip(folder, `AsphaltRepair {n}`, pa, pb, 3.2, 0.025, patch)
			count += 1
		end
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
			Weathering = class.PartMaterial == "Asphalt",
		})
		if class.PartMaterial == "Asphalt" then
			total += roadside(hf, layout, r, roadFolder)
		end
		Util.yield()
	end
	return total
end

return Roads
