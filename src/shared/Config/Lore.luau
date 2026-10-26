--!strict
-- Canon names from the Kagundi Encyclopedia (26 Oct 2026). Change only together with the canon.

local Lore = {
	Country = "Democratic Republic of Kagundi",
	Capital = "Gundiville",
	District = "East District",
	Cities = table.freeze({ "Gundiville", "Stokondo", "Kagundali", "Oberdueshuson" }),
	Currency = table.freeze({
		Code = "KGD",
		Name = "Kagundi Dinar",
		MinorUnitsPerUnit = 100,
	}),
	-- The economic day runs 00:00-24:00 in this time zone. Daily processing happens in the Discord economy bot only.
	EconomicDayTimeZone = "Europe/Berlin",
}

return table.freeze(Lore)
