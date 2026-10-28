--!strict
-- Where the district stands. The plan puts the Gundiville ground at GroundY (60), but the terrain
-- saved in the place can sit higher (in Studio it showed at about 61.5 to 62, so streets and
-- lawns were buried). Before building, BuildGundiville surveys the saved terrain under the
-- district with raycasts and raises the whole district just above it. Terrain is only read,
-- never changed.
--
-- The survey also measures the surface just outside the two streets that meet the national
-- roads (the avenue meets N5, the main street meets N4), so the last stretch of each street can
-- ramp to that height instead of ending in a step.

local Ground = {}

export type Survey = {
	Lift: number, -- studs the district is raised (0 = built at GroundY as planned)
	Wanted: number, -- the lift the terrain asks for, before the cap
	Samples: number, -- terrain hits under the district
	Low: number?, -- 5th and 95th percentile of the terrain height under the district
	High: number?,
	Joins: { [string]: number }, -- street id -> height of the surface the street meets
}

local STEP = 8 -- studs between survey points
local CLEARANCE = 0.05 -- asphalt top above the high terrain
Ground.MaxLift = 6 -- more than this needs a look in Studio (terrain shaped on purpose?)

local function percentile(sorted: { number }, p: number): number
	local i = math.clamp(math.ceil(#sorted * p), 1, #sorted)
	return sorted[i]
end

-- Rectangles the district covers: its streets, the square and every building plot.
local function areas(config: any): { any }
	local list = {}
	for _, street in config.Streets do
		table.insert(list, street.Rect)
	end
	for _, key in { "Square", "Congress", "Hausali", "CentralBank", "Residence" } do
		table.insert(list, config[key].Rect)
	end
	return list
end

-- Points just outside the end of a street that joins another road, across its carriageways.
local function joinPoints(street: any): { Vector3 }
	local join = street.Join
	local points = {}
	for _, c in street.Carriageways do
		if join.Edge == "MaxZ" and c.MaxZ >= street.Rect.MaxZ then
			for x = c.MinX + 2, c.MaxX - 2, 4 do
				table.insert(points, Vector3.new(x, 0, street.Rect.MaxZ + 4))
			end
		elseif join.Edge == "MaxX" and c.MaxX >= street.Rect.MaxX then
			for z = c.MinZ + 2, c.MaxZ - 2, 4 do
				table.insert(points, Vector3.new(street.Rect.MaxX + 4, 0, z))
			end
		end
	end
	return points
end

-- Surveys the saved terrain. `exclude` lists what the join probes must not hit (the old district
-- and the placeholder blocks it replaces).
function Ground.survey(config: any, exclude: { Instance }): Survey
	local terrainOnly = RaycastParams.new()
	terrainOnly.FilterType = Enum.RaycastFilterType.Include
	terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
	terrainOnly.IgnoreWater = false
	local heights: { number } = {}
	local seen: { [string]: boolean } = {}
	for _, r in areas(config) do
		for x = r.MinX + STEP / 2, r.MaxX, STEP do
			for z = r.MinZ + STEP / 2, r.MaxZ, STEP do
				local key = `{math.floor(x / STEP)},{math.floor(z / STEP)}`
				if seen[key] then
					continue
				end
				seen[key] = true
				local hit = workspace:Raycast(Vector3.new(x, 2048, z), Vector3.new(0, -4096, 0), terrainOnly)
				if hit then
					table.insert(heights, hit.Position.Y)
				end
			end
		end
	end
	table.sort(heights)
	local survey: Survey = { Lift = 0, Wanted = 0, Samples = #heights, Joins = {} }
	if #heights > 0 then
		survey.Low = percentile(heights, 0.05)
		survey.High = percentile(heights, 0.95)
		local wanted = (survey.High :: number) + CLEARANCE - (config.GroundY + config.RoadTop)
		wanted = math.max(0, math.ceil(wanted * 20 - 1e-6) / 20)
		survey.Wanted = wanted
		survey.Lift = math.min(wanted, Ground.MaxLift)
	end

	-- What the joining streets meet: the top of whatever is there (road parts or terrain).
	local outside = RaycastParams.new()
	outside.FilterType = Enum.RaycastFilterType.Exclude
	outside.FilterDescendantsInstances = exclude
	outside.IgnoreWater = true
	outside.RespectCanCollide = true
	for _, street in config.Streets do
		if not street.Join then
			continue
		end
		local tops: { number } = {}
		for _, p in joinPoints(street) do
			local hit = workspace:Raycast(Vector3.new(p.X, 2048, p.Z), Vector3.new(0, -4096, 0), outside)
			if hit then
				table.insert(tops, hit.Position.Y)
			end
		end
		if #tops > 0 then
			table.sort(tops)
			survey.Joins[street.Id] = percentile(tops, 0.5)
		end
	end
	return survey
end

-- The configuration the district is built from: the plan, standing on the surveyed ground.
-- Boxes that reach down to the ground get footings down to the planned ground, so a raised
-- district shows no gap where the terrain is lower.
function Ground.apply(config: any, lift: number, joins: { [string]: number }?): any
	return setmetatable({
		GroundY = config.GroundY + lift,
		PlannedGroundY = config.GroundY,
		Lift = lift,
		FootingY = if lift > 0 then config.GroundY - 1 else nil,
		JoinHeights = joins or {},
	}, { __index = config })
end

return Ground
