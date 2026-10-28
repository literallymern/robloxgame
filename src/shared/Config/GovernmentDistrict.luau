--!strict
-- Gundiville government district (Milestone 3): the streets around the main square, the
-- General People's Congress, the Hausali, the Central Bank, the Leader's residence, the square
-- with its market stalls and the statue of the Leader. Built in Studio by
-- `require(game.ServerStorage.StudioTools.BuildGundiville).run()`.
--
-- Footprints follow the map plan (docs/game/02-map-plan.md, section 5) and are the same
-- rectangles as MapLayout.GundivillePlaceholders, which they replace. Heights are in studs
-- above the Gundiville ground (MapLayout: GroundY 60). 1 stud is about 0.28 m.

export type Rect = { MinX: number, MaxX: number, MinZ: number, MaxZ: number }

local function rect(minX: number, maxX: number, minZ: number, maxZ: number): Rect
	assert(minX < maxX and minZ < maxZ, "rect needs min < max")
	return table.freeze({ MinX = minX, MaxX = maxX, MinZ = minZ, MaxZ = maxZ })
end

local function frozenList<T>(list: { T }): { T }
	return table.freeze(list)
end

export type Join = { Edge: "MaxX" | "MaxZ", Length: number }

local function join(edge: "MaxX" | "MaxZ", length: number): Join
	return table.freeze({ Edge = edge, Length = length })
end

export type Street = {
	Id: string,
	Name: string?, -- street name sign text (proposal, not canon; nil = no name sign)
	Axis: "X" | "Z", -- direction of travel
	Rect: Rect, -- the whole street including its sidewalks
	Carriageways: { Rect }, -- asphalt; may reach into the street it joins
	Median: Rect?, -- planted median (avenue only)
	CentreLines: { number }, -- coordinates (across the street) of dashed lines
	Crosswalks: { number }, -- coordinates along the street where a zebra crossing is painted
	-- The street's end meets a national road: its last `Length` studs ramp to the height of that
	-- road when the district had to be raised above the saved terrain (Gundiville/Ground.luau).
	Join: Join?,
}

local District = {}

District.Version = "district-2"
District.GeneratedBy = "BuildGundiville"
District.GroundY = 60
District.RoadTop = 0.05 -- asphalt top above the ground (N4 and N5 start at the ground)
District.WalkTop = 0.6 -- sidewalks, the square and building plinths
-- The whole district; checked by tests/map/gundiville.spec.luau. Since the building overhaul
-- (furnished interiors behind every window) the four buildings take about 26,800 parts; most
-- are small details without collision, and StreamingEnabled sends clients only what is near.
District.MaxParts = 30000

-- Placeholder blocks of MapLayout.GundivillePlaceholders that this district replaces.
District.Replaces = frozenList({ "Avenue", "Square", "Congress", "Hausali", "Residence", "CentralBank" })

District.Streets = frozenList({
	{
		Id = "Avenue",
		Name = "Avenue du 12 Mai",
		Axis = "Z",
		Rect = rect(-50, 50, 20, 900),
		Carriageways = frozenList({ rect(-40, -12, 12, 900), rect(12, 40, 12, 900), rect(-12, 12, 860, 900) }),
		Median = rect(-12, 12, 20, 860),
		CentreLines = frozenList({ -26, 26 }),
		Crosswalks = frozenList({ 26, 86, 144 }),
		Join = join("MaxZ", 40), -- N5
	} :: Street,
	{
		Id = "MainStreet",
		Name = "Rue de l'Indépendance",
		Axis = "X",
		Rect = rect(-185, 900, 95, 135),
		Carriageways = frozenList({ rect(-153, 900, 103, 127) }),
		CentreLines = frozenList({ 115 }),
		Crosswalks = frozenList({ -56, 56 }),
		Join = join("MaxX", 40), -- N4
	} :: Street,
	{
		Id = "WestStreet",
		Axis = "Z",
		Rect = rect(-185, -145, -540, 135),
		Carriageways = frozenList({ rect(-177, -153, -532, 127) }),
		CentreLines = frozenList({ -165 }),
		Crosswalks = frozenList({ -155, -300 }),
	} :: Street,
	{
		Id = "EastStreet",
		Axis = "Z",
		Rect = rect(145, 185, -540, 95),
		Carriageways = frozenList({ rect(153, 177, -532, 103) }),
		CentreLines = frozenList({ 165 }),
		Crosswalks = frozenList({ -160, -300 }),
	} :: Street,
	{
		Id = "SouthStreet",
		Axis = "X",
		Rect = rect(-145, 145, -20, 20),
		Carriageways = frozenList({ rect(-153, 153, -12, 12) }),
		CentreLines = frozenList({ 0 }),
		Crosswalks = frozenList({ -60, 60 }),
	} :: Street,
	{
		Id = "NorthStreet",
		Axis = "X",
		Rect = rect(-185, 640, -540, -500),
		Carriageways = frozenList({ rect(-153, 640, -532, -508) }),
		CentreLines = frozenList({ -520 }),
		Crosswalks = frozenList({}),
	} :: Street,
})

-- Avenue planting and lights (the median of the avenue).
District.Avenue = table.freeze({
	TreeSpacing = 30,
	TreeHeight = 26,
	LampSpacing = 60,
})

District.Square = table.freeze({
	Rect = rect(-140, 140, -260, -20),
	-- Statue platform on the ceremonial axis (map plan: -30..30 x -160..-100).
	StatuePlatform = rect(-30, 30, -160, -100),
	StallsPerSide = 8,
	FlagpolesX = frozenList({ -130, -105, -80, 80, 105, 130 }),
})

District.Congress = table.freeze({
	Rect = rect(-140, 140, -440, -290), -- podium incl. the ceremonial steps
	Body = rect(-130, 130, -432, -312), -- main block above the podium
	Forecourt = rect(-140, 140, -290, -260), -- the steps down to the square
	PodiumHeight = 4,
	StoreyHeight = 14,
	Storeys = 3,
	Chamber = rect(-53, 53, -420, -345), -- centre lines of its walls (Architecture.Plan)
	DomeDiameter = 60,
})

District.Hausali = table.freeze({
	Rect = rect(190, 360, -280, -40),
	Body = rect(196, 276, -272, -48),
	Entrance = rect(188, 196, -178, -142), -- the risalit with the portal on the west front
	StoreyHeight = 13,
	Storeys = 3,
})

District.CentralBank = table.freeze({
	Rect = rect(-330, -190, -250, -60),
	Body = rect(-322, -198, -238, -72),
	StoreyHeight = 17,
	Storeys = 2,
})

District.Residence = table.freeze({
	Rect = rect(440, 720, -800, -560),
	Gate = 580, -- X of the gate in the south wall
	Villa = rect(500, 660, -770, -690),
	WallHeight = 9,
})

-- The statue of the Leader of the Revolution (map plan P4-P6, decision D3).
District.Statue = table.freeze({
	UserId = 2595858454, -- Roblox user of the Owner (Dr. Justin Wachmann)
	Position = table.freeze({ 0, -130 }),
	-- Height of the body (accessories such as hair and hats come on top). Owner's wish of
	-- 2026-10-28: "in gold und viel größer" (was 30 on a 14-stud pedestal).
	FigureHeight = 50,
	PedestalHeight = 20,
	Facing = "North", -- towards the General People's Congress
	-- Decision D3 (Owner, 2026-10-28): gold. "Original" keeps the avatar's colours and
	-- clothing; "Bronze" and "Stone" remain as alternatives.
	Finish = "Gold",
	Inscription = table.freeze({
		"DR. JUSTIN WACHMANN",
		"LEADER OF THE REVOLUTION",
		"LEITER DER REVOLUTION · DI LAITA",
	}),
})

return table.freeze(District)
