--!strict
-- Artist controls for the saved highland landscape. Distances/heights are in studs.
-- The authored Land/RoadNetwork anchors stay unchanged; this detail is blended around them.
return table.freeze({
	Enabled = true,
	Revision = "highland-3",
	ReliefAmplitude = 16, -- hard cap, before the protection masks below
	RidgeWavelength = 580,
	FoldWavelength = 230,
	DetailWavelength = 86,
	DomainWarp = 95,
	RoadProtection = 28, -- beyond the road edge, including its existing cutting/shoulder
	RoadFade = 100,
	PlaceProtection = 18, -- added beyond each place's existing blend margin
	PlaceFade = 115,
	FieldProtection = 14,
	FieldFade = 55,
	RiverProtection = 16, -- added beyond the existing river carving reach
	RiverFade = 110,
	LakeProtection = 120, -- beyond the widest radius; the complete legacy basin is always protected
	LakeFade = 105,
	EdgeProtection = 64,
	EdgeFade = 120,
	FloorProtection = 16,
	FloorFade = 32,
})
