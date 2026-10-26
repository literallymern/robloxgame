--!strict
-- Road surfaces as parts: straight pieces along the calculated centre line and height profile,
-- round joints where a road bends, and dashed centre lines on national and regional roads.
-- Bridge sections are left to the bridge builder.

local Heightfield = require(script.Parent.Parent.Heightfield)
local Util = require(script.Parent.Util)

local Roads = {}

local THICKNESS = 1.2
local MAX_PIECE = 400 -- longest single road part in studs
local STRAIGHT_TOLERANCE = 0.12 -- how far a point may sit off a straight piece before a new piece starts
local DASH_LENGTH = 12
local DASH_SPACING = 40

type RoadInfo = any

local function point(road: RoadInfo, i: number): Vector3
	return Vector3.new(road.line.xs[i], road.profile[i], road.line.zs[i])
end

-- Splits samples first..last into runs that are straight in 3D (within the tolerance).
function Roads.straightRuns(road: RoadInfo, first: number, last: number): { { number } }
	local runs = {}
	local i = first
	while i < last do
		local j = i + 1
		while j < last do
			local a, b = point(road, i), point(road, j + 1)
			if (b - a).Magnitude > MAX_PIECE then
				break
			end
			local dir = (b - a).Unit
			local straight = true
			for k = i + 1, j do
				local p = point(road, k) - a
				if (p - dir * p:Dot(dir)).Magnitude > STRAIGHT_TOLERANCE then
					straight = false
					break
				end
			end
			if not straight then
				break
			end
			j += 1
		end
		table.insert(runs, { i, j })
		i = j
	end
	return runs
end

-- Builds road pieces for samples first..last into `parent` with the given look.
function Roads.buildRuns(
	parent: Instance,
	road: RoadInfo,
	first: number,
	last: number,
	thickness: number,
	options: Util.PartOptions
): number
	local runs = Roads.straightRuns(road, first, last)
	local width = road.Width
	local count = 0
	local previousDir: Vector3? = nil
	for n, run in runs do
		local a, b = point(road, run[1]), point(road, run[2])
		Util.strip(parent, `{road.Id} {n}`, a, b, width, thickness, options)
		count += 1
		local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
		if previousDir and math.deg(math.acos(math.clamp(previousDir:Dot(dir), -1, 1))) > 1.5 then
			-- A round joint fills the wedge-shaped gap on the outside of the bend.
			local jointOptions = table.clone(options)
			jointOptions.Shape = Enum.PartType.Cylinder
			Util.part(
				parent,
				`{road.Id} {n} joint`,
				CFrame.new(a - Vector3.new(0, thickness / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				Vector3.new(thickness, width, width),
				jointOptions
			)
			count += 1
		end
		previousDir = dir
	end
	return count
end

-- Position, height and direction at distance s along a road.
local function sampleAt(road: RoadInfo, s: number): (Vector3, Vector3)
	local line = road.line
	local lo, hi = 1, #line.s
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if line.s[mid] <= s then
			lo = mid
		else
			hi = mid
		end
	end
	local span = line.s[hi] - line.s[lo]
	local t = if span > 0 then (s - line.s[lo]) / span else 0
	local a, b = point(road, lo), point(road, hi)
	return a:Lerp(b, t), (b - a).Unit
end

function Roads.build(hf: Heightfield.Heightfield, layout: any, parent: Instance): number
	local folder = Util.folder(parent, "Roads")
	local total = 0
	for _, road in hf.roads.roads do
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
		-- Split the road at bridges; bridge decks are built separately.
		local count = #road.line.xs
		local i = 1
		while i < count do
			if road.onBridge[i] and road.onBridge[i + 1] then
				i += 1
				continue
			end
			local j = i
			while j < count and not (road.onBridge[j] and road.onBridge[j + 1]) do
				j += 1
			end
			total += Roads.buildRuns(roadFolder, road, i, j, THICKNESS, options)
			i = j
		end
		if class.CentreLine then
			local dashOptions: Util.PartOptions = {
				Material = Enum.Material.SmoothPlastic,
				Color = Color3.fromRGB(235, 235, 220),
				Decoration = true,
			}
			local s = DASH_SPACING / 2
			while s + DASH_LENGTH < road.line.length - DASH_SPACING / 2 do
				local a = sampleAt(road, s)
				local b = sampleAt(road, s + DASH_LENGTH)
				local lift = Vector3.new(0, 0.06, 0)
				Util.strip(roadFolder, "Line", a + lift, b + lift, 0.8, 0.1, dashOptions)
				total += 1
				s += DASH_SPACING
			end
		end
		Util.yield()
	end
	return total
end

return Roads
