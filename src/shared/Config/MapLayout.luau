--!strict
-- The map of the East District as numbers: the single source for coordinates (docs/game/02-map-plan.md).
-- World space in studs. North = -Z, East = +X. Rectangles are axis-aligned.
-- Builders in ServerStorage.StudioTools read this file; game code may read it too (it holds no secrets).
-- Change a coordinate here, not in a builder, and update 02-map-plan.md with it.

export type Rect = { MinX: number, MaxX: number, MinZ: number, MaxZ: number }
export type Point = { number } -- { x, z }
export type Anchor = { number } -- { x, z, height }

export type Place = {
	Id: string,
	Name: string,
	Kind: "City" | "Facility" | "Crossing" | "Plot",
	Rect: Rect,
	GroundY: number?, -- flattened to this height; nil = flattened to the land height at the centre
	Margin: number, -- studs over which the ground blends back into the landscape
	Material: string, -- terrain material inside the rectangle
}

export type Zone = { Id: string, Rect: Rect, Material: string }

export type Hill = { Id: string, Rect: Rect, Peak: number, Margin: number }

export type Road = {
	Id: string,
	Name: string,
	Class: "National" | "Regional" | "Access",
	Points: { Point },
}

export type RoadClass = {
	Width: number,
	MaxGrade: number, -- rise per stud, e.g. 0.06 = 6 %
	MinRadius: number,
	Material: string, -- terrain material under the road
	PartMaterial: string, -- Enum.Material name of the road surface parts
	Color: { number }, -- RGB 0-255
	CentreLine: boolean,
}

export type Property = {
	Name: string, -- exactly as in the economy bot (GENESIS_PROPERTIES); the bot knows properties by name
	City: string,
	Type: string,
	Rect: Rect,
	Place: string?, -- id of the place it lies in, when that is not the city itself
}

local function rect(minX: number, maxX: number, minZ: number, maxZ: number): Rect
	return table.freeze({ MinX = minX, MaxX = maxX, MinZ = minZ, MaxZ = maxZ })
end

local function frozenList<T>(list: { T }): { T }
	for _, item in list do
		if type(item) == "table" and not table.isfrozen(item :: any) then
			table.freeze(item :: any)
		end
	end
	return table.freeze(list)
end

local MapLayout = {}

MapLayout.Version = 1

MapLayout.Bounds = table.freeze({
	Half = 5120, -- the map runs from -5120 to +5120 on X and Z
	Playable = 4400, -- the boundary mountains start here
	FloorY = 0, -- bottom of the terrain
	EdgeWallHeight = 1300,
})

-- Land height before hills, mountains, roads and the river. Heights between the anchors are
-- blended (inverse distance weighting) and get gentle noise on top. { x, z, height }
MapLayout.HeightAnchors = frozenList({
	{ 0, 0, 60 }, -- Gundiville basin
	{ 0, -1300, 85 },
	{ -1000, 1300, 50 },
	{ 1200, 1200, 55 },
	{ 2900, 950, 60 }, -- cargo airport
	{ 4000, 300, 62 },
	{ 4900, 250, 60 }, -- east border crossing
	{ -2700, 2700, 40 }, -- Kagundali lowland
	{ -1600, 2500, 40 }, -- industry zone
	{ -3800, 2500, 55 },
	{ -3000, -2300, 100 }, -- Stokondo
	{ -3400, -500, 90 }, -- west valley (R1)
	{ -3800, -3800, 140 },
	{ -300, -2600, 130 },
	{ 2000, -1600, 150 }, -- plateau escarpment
	{ 1150, -1600, 85 }, -- river valley below the escarpment (N3 bridge)
	{ 1250, 200, 50 }, -- river valley east of Gundiville (N4 bridge)
	{ 2400, -2800, 180 }, -- Oberdueshuson plateau
	{ 3650, -3000, 180 }, -- barracks
	{ 3900, -1950, 170 }, -- training grounds
	{ 1150, -3250, 170 }, -- western tobacco farms
	{ 2450, -3850, 190 }, -- eastern tobacco farms
	{ 3800, -800, 110 },
	{ 2600, 2750, 65 }, -- farmland and ranches
	{ 3800, 3800, 70 },
	{ 0, 3000, 52 },
	{ 500, 4900, 50 }, -- south border crossing
	{ -1300, 4300, 45 },
	{ -3900, 3800, 90 }, -- gold fields
	{ -4000, 1150, 100 }, -- palladium mine
} :: { Anchor })

-- Gentle rolling of the open land (studs up and down, and the size of the swells), plus fine detail.
MapLayout.Rolling = table.freeze({ Amplitude = 10, Wavelength = 700, DetailAmplitude = 2, DetailWavelength = 90 })

MapLayout.Hills = frozenList({
	{ Id = "NorthernHighlands", Rect = rect(-2300, 1900, -4400, -3850), Peak = 430, Margin = 450 },
	{ Id = "ForestedHills", Rect = rect(-2200, -900, -2600, -1500), Peak = 280, Margin = 350 },
	-- Moved from the map plan's (-1700…-1100 × -1000…-400) so that N1 does not cut through it.
	{ Id = "MastHill", Rect = rect(-1900, -1300, -700, -100), Peak = 190, Margin = 300 },
	{ Id = "GoldFieldHills", Rect = rect(-4400, -3300, 3200, 4400), Peak = 280, Margin = 300 },
	{ Id = "PalladiumHills", Rect = rect(-4400, -3600, 600, 1700), Peak = 260, Margin = 300 },
} :: { Hill })

MapLayout.Mountains = table.freeze({
	MinPeak = 560,
	ExtraPeak = 380, -- added by ridge noise, so the highest peaks reach about 940
	StartInside = 250, -- studs inside the playable edge where the foot begins (varies by about 200)
	FullOutside = 450, -- studs outside the playable edge where full height is reached
	-- Openings in the ring. Edge = side of the map, Centre = position along that edge,
	-- Flat = half-width of the open floor, Slope = width of the slopes on each side.
	Passes = frozenList({
		{ Id = "EastPass", Edge = "East", Centre = 250, Flat = 170, Slope = 320 }, -- east border crossing
		{ Id = "SouthPass", Edge = "South", Centre = 500, Flat = 170, Slope = 320 }, -- south border crossing
		{ Id = "RiverGap", Edge = "South", Centre = -1420, Flat = 220, Slope = 500 }, -- where the river leaves
	}),
})

-- Flattened areas. Later entries win where they overlap.
MapLayout.Places = frozenList({
	{
		Id = "Gundiville",
		Name = "Gundiville",
		Kind = "City",
		Rect = rect(-900, 900, -900, 900),
		GroundY = 60,
		Margin = 220,
		Material = "Pavement",
	},
	{
		Id = "Stokondo",
		Name = "Stokondo",
		Kind = "City",
		Rect = rect(-3600, -2400, -2900, -1700),
		GroundY = 100,
		Margin = 220,
		Material = "Pavement",
	},
	{
		Id = "Kagundali",
		Name = "Kagundali",
		Kind = "City",
		Rect = rect(-3400, -2000, 2000, 3400),
		GroundY = 40,
		Margin = 220,
		Material = "Pavement",
	},
	{
		Id = "Oberdueshuson",
		Name = "Oberdueshuson",
		Kind = "City",
		Rect = rect(1900, 2900, -3300, -2300),
		GroundY = 180,
		Margin = 220,
		Material = "Pavement",
	},
	{
		Id = "CargoAirport",
		Name = "Kagundi Cargo Airport",
		Kind = "Facility",
		Rect = rect(1700, 4100, 600, 1300),
		GroundY = 60,
		Margin = 220,
		Material = "Grass",
	},
	{
		Id = "KagundaliIndustry",
		Name = "Kagundali Industrial Zone",
		Kind = "Facility",
		Rect = rect(-1900, -1300, 2100, 2900),
		GroundY = 40,
		Margin = 160,
		Material = "Ground",
	},
	{
		Id = "RGBarracks",
		Name = "Revolutionary Guard Barracks",
		Kind = "Facility",
		Rect = rect(3100, 4200, -3500, -2500),
		GroundY = 180,
		Margin = 160,
		Material = "Ground",
	},
	{
		Id = "TrainingGrounds",
		Name = "Military Training Grounds",
		Kind = "Facility",
		Rect = rect(3500, 4300, -2400, -1500),
		GroundY = 170,
		Margin = 100, -- the barracks are only 100 studs away
		Material = "Ground",
	},
	{
		Id = "GoldMineYard",
		Name = "Gold Mine",
		Kind = "Facility",
		Rect = rect(-3950, -3650, 3650, 3950),
		GroundY = 120,
		Margin = 240,
		Material = "Ground",
	},
	{
		Id = "PalladiumMineYard",
		Name = "Palladium Mine",
		Kind = "Facility",
		Rect = rect(-4100, -3850, 1000, 1300),
		GroundY = 125,
		Margin = 220,
		Material = "Ground",
	},
	{
		Id = "Ranch",
		Name = "Cattle Ranch",
		Kind = "Facility",
		Rect = rect(2560, 2760, 2700, 2860),
		Margin = 120,
		Material = "Ground",
	},
	{
		Id = "EastCrossing",
		Name = "East Border Crossing",
		Kind = "Crossing",
		Rect = rect(4600, 5120, 100, 400),
		GroundY = 60,
		Margin = 140,
		Material = "Pavement",
	},
	{
		Id = "SouthCrossing",
		Name = "South Border Crossing",
		Kind = "Crossing",
		Rect = rect(350, 650, 4600, 5120),
		GroundY = 50,
		Margin = 140,
		Material = "Pavement",
	},
	-- Property plots outside the cities get a small flat pad at the local land height.
	{
		Id = "PlotRiverside",
		Name = "Gundiville Riverside Apartment",
		Kind = "Plot",
		Rect = rect(990, 1050, 390, 450),
		GroundY = 60,
		Margin = 50,
		Material = "Pavement",
	},
	{
		Id = "PlotFarmhouse",
		Name = "Oberdueshuson Farmhouse",
		Kind = "Plot",
		Rect = rect(1625, 1675, -2975, -2925),
		Margin = 60,
		Material = "Ground",
	},
	{
		Id = "PlotTobaccoFields",
		Name = "Oberdueshuson Tobacco Fields",
		Kind = "Plot",
		Rect = rect(1200, 1400, -3280, -3120),
		Margin = 80,
		Material = "Ground",
	},
} :: { Place })

-- Surface material of larger rural areas (not flattened).
MapLayout.Zones = frozenList({
	{ Id = "TobaccoWest", Rect = rect(500, 1800, -3800, -2700), Material = "LeafyGrass" },
	{ Id = "TobaccoEast", Rect = rect(1900, 3000, -4300, -3400), Material = "LeafyGrass" },
	{ Id = "Farmland", Rect = rect(1400, 3800, 1700, 3800), Material = "LeafyGrass" },
	{ Id = "GoldFields", Rect = rect(-4300, -3500, 3400, 4200), Material = "Ground" },
} :: { Zone })

MapLayout.RoadClasses = table.freeze({
	National = table.freeze({
		Width = 40,
		MaxGrade = 0.06,
		MinRadius = 150,
		Material = "Asphalt",
		PartMaterial = "Asphalt",
		Color = table.freeze({ 58, 58, 62 }),
		CentreLine = true,
	}),
	Regional = table.freeze({
		Width = 32,
		MaxGrade = 0.10,
		MinRadius = 90,
		Material = "Asphalt",
		PartMaterial = "Asphalt",
		Color = table.freeze({ 66, 66, 70 }),
		CentreLine = true,
	}),
	Access = table.freeze({
		Width = 22,
		MaxGrade = 0.12,
		MinRadius = 40,
		Material = "Ground",
		PartMaterial = "Pebble",
		Color = table.freeze({ 128, 112, 92 }),
		CentreLine = false,
	}),
} :: { [string]: RoadClass })

-- Road numbers are development labels (map plan, section 4), not canon names.
-- Roads start and end on the edge of a place (city streets follow in Milestones 3 and 5) or on
-- another road. Points are corners; the builder rounds them to the class's minimum radius.
MapLayout.Roads = frozenList({
	{
		Id = "N1",
		Name = "N1 Gundiville - Stokondo",
		Class = "National",
		Points = frozenList({ { -900, -500 }, { -1800, -1200 }, { -2400, -1900 } }),
	},
	{
		Id = "N2",
		Name = "N2 Gundiville - Kagundali",
		Class = "National",
		Points = frozenList({ { -900, 500 }, { -1500, 1500 }, { -2000, 2200 } }),
	},
	{
		Id = "N3",
		Name = "N3 Gundiville - Oberdueshuson",
		Class = "National",
		Points = frozenList({ { 600, -900 }, { 1200, -1700 }, { 1900, -2500 } }),
	},
	{
		Id = "N4",
		Name = "N4 Gundiville - Airport - East Border",
		Class = "National",
		-- Leaves Gundiville on the main east-west street between the Brandwehr and the hospital.
		Points = frozenList({
			{ 900, 115 },
			{ 1700, 300 },
			{ 3000, 350 },
			{ 4100, 300 },
			{ 4900, 250 },
			{ 5120, 250 },
		}),
	},
	{
		Id = "N5",
		Name = "N5 Gundiville - South Border",
		Class = "National",
		-- Continues the ceremonial avenue southwards.
		Points = frozenList({ { 0, 900 }, { 0, 1100 }, { 400, 2500 }, { 500, 4000 }, { 500, 5120 } }),
	},
	{
		Id = "R1",
		Name = "R1 Stokondo - Kagundali",
		Class = "Regional",
		Points = frozenList({ { -3100, -1700 }, { -3400, -500 }, { -3300, 800 }, { -3000, 2000 } }),
	},
	{
		Id = "R2",
		Name = "R2 Stokondo - Oberdueshuson (northern pass)",
		Class = "Regional",
		Points = frozenList({ { -2600, -2900 }, { -1500, -3500 }, { 0, -3700 }, { 1200, -3400 }, { 1900, -3000 } }),
	},
	{
		Id = "R3",
		Name = "R3 Kagundali - N5",
		Class = "Regional",
		Points = frozenList({ { -2000, 3000 }, { -1000, 3250 }, { 453, 3300 } }),
	},
	{
		Id = "R4",
		Name = "R4 Oberdueshuson - N4",
		Class = "Regional",
		Points = frozenList({ { 2900, -2300 }, { 3150, -1200 }, { 3200, 0 }, { 3200, 341 } }),
	},
	{
		Id = "GoldHaul",
		Name = "Gold mine haul road",
		Class = "Access",
		Points = frozenList({ { -3000, 3400 }, { -3500, 3700 }, { -3650, 3800 } }),
	},
	{
		Id = "PalladiumAccess",
		Name = "Palladium mine road",
		Class = "Access",
		Points = frozenList({ { -3275, 900 }, { -3700, 1100 }, { -3850, 1150 } }),
	},
	{
		Id = "AirportAccess",
		Name = "Airport apron road",
		Class = "Access",
		Points = frozenList({ { 2600, 335 }, { 2600, 670 } }),
	},
	{
		Id = "BarracksAccess",
		Name = "Barracks road",
		Class = "Access",
		Points = frozenList({ { 2900, -2800 }, { 3100, -2850 } }),
	},
	{
		Id = "TrainingAccess",
		Name = "Training grounds road",
		Class = "Access",
		Points = frozenList({ { 2980, -1950 }, { 3500, -1950 } }),
	},
	{
		Id = "FarmRoad",
		Name = "Farm road (ranches)",
		Class = "Access",
		Points = frozenList({ { 314, 2200 }, { 1400, 2300 }, { 2600, 2750 } }),
	},
	{
		Id = "FarmhouseAccess",
		Name = "Farmhouse lane",
		Class = "Access",
		Points = frozenList({ { 1650, -3143 }, { 1650, -2975 } }),
	},
} :: { Road })

-- The unnamed river (a proposal in the map plan). It flows from the northern mountains past the
-- east of Gundiville to the south-west, where it leaves the map through a valley in the mountains.
MapLayout.River = table.freeze({
	Points = frozenList({
		{ 1000, -4400 },
		{ 900, -2500 },
		{ 1300, -1000 },
		{ 1250, 0 },
		{ 900, 1500 },
		{ -300, 2600 },
		{ -1200, 4000 },
		{ -1500, 5120 },
	}),
	Width = 60, -- water surface width
	Depth = 9, -- water depth in the middle
	DropBelowLand = 4, -- water surface below the surrounding land
	BankWidth = 18,
	WallSlope = 1.1, -- steepness of the valley sides where the river cuts through high ground
	RoadClearance = 12, -- bridge decks stay at least this far above the water
})

-- Cargo airport parts (map plan, section 3): runway east-west, apron and terminal on the north side.
MapLayout.Airport = table.freeze({
	Runway = rect(1800, 4000, 890, 1010),
	Taxiway = rect(1850, 3950, 800, 840),
	TaxiwayLinks = frozenList({ rect(1980, 2020, 840, 890), rect(2880, 2920, 840, 890), rect(3780, 3820, 840, 890) }),
	Apron = rect(1950, 2950, 670, 800),
	Buildings = frozenList({
		{ Id = "Terminal", Name = "Cargo Terminal", Rect = rect(2000, 2300, 610, 660), Height = 30 },
		{ Id = "Hangar", Name = "Cargo Hangar", Rect = rect(2380, 2560, 600, 665), Height = 36 },
		{ Id = "Tower", Name = "Control Tower", Rect = rect(2700, 2730, 620, 650), Height = 70 },
	}),
})

-- Customs posts at the two border crossings (map plan, section 3).
MapLayout.Crossings = frozenList({
	{
		Id = "East",
		Name = "East Border Crossing",
		Road = "N4",
		Axis = "X", -- the road runs along X here
		Canopy = 4850, -- position of the canopy along the road
		Barrier = 4980,
		RoadCentre = 250, -- the other coordinate of the road
		OfficeRect = rect(4780, 4840, 110, 165),
	},
	{
		Id = "South",
		Name = "South Border Crossing",
		Road = "N5",
		Axis = "Z",
		Canopy = 4850,
		Barrier = 4980,
		RoadCentre = 500,
		OfficeRect = rect(365, 420, 4780, 4840),
		InspectionRect = rect(570, 640, 4760, 4900),
	},
})

-- The 16 state properties of the economy bot (map plan, section 10). Plots are markers; buildings
-- follow in Milestones 3 and 5.
MapLayout.Properties = frozenList({
	{
		Name = "Gundiville Central Apartment 1",
		City = "Gundiville",
		Type = "residential",
		Rect = rect(-560, -480, 340, 420),
	},
	{
		Name = "Gundiville Central Apartment 2",
		City = "Gundiville",
		Type = "residential",
		Rect = rect(-560, -480, 440, 520),
	},
	{
		Name = "Gundiville Riverside Apartment",
		City = "Gundiville",
		Type = "residential",
		Rect = rect(990, 1050, 390, 450),
	},
	{
		Name = "Gundiville Embassy Row House",
		City = "Gundiville",
		Type = "residential",
		Rect = rect(-670, -610, -525, -475),
	},
	{
		Name = "Gundiville Commercial District Office",
		City = "Gundiville",
		Type = "commercial",
		Rect = rect(130, 190, 380, 440),
	},
	{
		Name = "Gundiville Market Street Retail Unit",
		City = "Gundiville",
		Type = "commercial",
		Rect = rect(-220, -180, 300, 340),
	},
	{
		Name = "Stokondo Courthouse Quarter Apartment",
		City = "Stokondo",
		Type = "residential",
		Rect = rect(-2910, -2860, -2450, -2390),
	},
	{
		Name = "Stokondo Polyclinic Lane Apartment",
		City = "Stokondo",
		Type = "residential",
		Rect = rect(-2650, -2600, -2130, -2070),
	},
	{
		Name = "Stokondo Legal Chambers Office",
		City = "Stokondo",
		Type = "commercial",
		Rect = rect(-3140, -3090, -2210, -2160),
	},
	{
		Name = "Kagundali Workers' Apartment 1",
		City = "Kagundali",
		Type = "residential",
		Rect = rect(-2180, -2120, 2420, 2480),
	},
	{
		Name = "Kagundali Workers' Apartment 2",
		City = "Kagundali",
		Type = "residential",
		Rect = rect(-2180, -2120, 2520, 2580),
	},
	{
		Name = "Kagundali Freight Warehouse",
		City = "Kagundali",
		Type = "industrial",
		Rect = rect(-2300, -2200, 2220, 2280),
	},
	{
		Name = "Kagundali Ore Yard Industrial Lot",
		City = "Kagundali",
		Type = "industrial",
		Rect = rect(-1660, -1540, 2550, 2650),
		Place = "KagundaliIndustry",
	},
	{
		Name = "Oberdueshuson Farmhouse",
		City = "Oberdueshuson",
		Type = "residential",
		Rect = rect(1625, 1675, -2975, -2925),
	},
	{
		Name = "Oberdueshuson Tobacco Fields",
		City = "Oberdueshuson",
		Type = "agricultural",
		Rect = rect(1200, 1400, -3280, -3120),
	},
	{
		Name = "Oberdueshuson Garrison Town Apartment",
		City = "Oberdueshuson",
		Type = "residential",
		Rect = rect(2420, 2470, -2790, -2730),
	},
} :: { Property })

-- Placeholder blocks for the Gundiville government district (map plan, section 5), so the layout
-- can be checked on foot. Height 0 = flat slab. Replaced by the real buildings in Milestone 3.
MapLayout.GundivillePlaceholders = frozenList({
	{ Id = "Avenue", Name = "Ceremonial avenue", Rect = rect(-50, 50, -20, 900), Height = 0 },
	{ Id = "Square", Name = "Main square", Rect = rect(-140, 140, -260, -20), Height = 0 },
	{ Id = "Congress", Name = "General People's Congress", Rect = rect(-140, 140, -440, -290), Height = 70 },
	{ Id = "Hausali", Name = "Hausali", Rect = rect(190, 360, -280, -40), Height = 45 },
	{ Id = "Residence", Name = "Leader's residence", Rect = rect(440, 720, -800, -560), Height = 24 },
	{ Id = "CentralBank", Name = "Central bank", Rect = rect(-330, -190, -250, -60), Height = 36 },
	{ Id = "University", Name = "National university", Rect = rect(-820, -440, -820, -560), Height = 30 },
	{ Id = "PoliceStation", Name = "Central City Police", Rect = rect(-300, -90, 140, 250), Height = 24 },
	{ Id = "Hospital", Name = "Central hospital", Rect = rect(430, 720, 160, 420), Height = 40 },
	{ Id = "Brandwehr", Name = "Brandwehr Crisis Response Center", Rect = rect(430, 640, -80, 70), Height = 24 },
	{ Id = "BusTerminal", Name = "Bus terminal", Rect = rect(90, 300, 700, 860), Height = 0 },
})

-- New players arrive at the Gundiville bus terminal (map plan, sections 5 and 8).
MapLayout.Spawn = table.freeze({
	Name = "BusTerminal",
	Centre = table.freeze({ 195, 780 }),
	GroundY = 60,
	Size = 12,
})

return table.freeze(MapLayout)
