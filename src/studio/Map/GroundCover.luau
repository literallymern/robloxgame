--!strict
-- Shared substrate, not decorative scatter. Grass alone emits Roblox's tall native blades;
-- LeafyGrass supplies low cover. Forest litter, drainage and exposed rock follow habitat.
local Cover = {}

function Cover.material(forest: number, dry: number, slope: number, x: number, z: number, waterside: boolean?): number
	local geology = math.noise(x / 510 + 0.41, z / 760 + 0.13, 111.3)
	local moisture = math.noise(x / 135 + 0.23, z / 290 + 0.59, 112.7)
	if slope > 1.02 + 0.2 * geology then
		return if geology < -0.2 then 9 else 3 -- coherent rock strata, not altitude-wide grey walls
	elseif slope > 0.64 and geology + slope * 0.3 > 0.12 then
		return if slope > 0.84 then 3 else 4 -- weathered talus below exposed faces
	end
	if forest > 0.24 then
		local litter = math.noise(x / 26 + 0.19, z / 39 + 0.61, 114.1)
		return if litter + forest * 0.32 > 0.1 then 4 else 2 -- leaf litter and low shade plants
	end
	if waterside and moisture < -0.18 and slope < 0.18 then
		return 5
	end
	if slope > 0.3 and geology + dry * 0.35 > 0.18 then
		return 4 -- connected eroding slopes; no scattered bare circles on flat meadows
	end
	local meadow = math.noise(x / 46 + 0.31, z / 76 + 0.73, 115.9)
	return if meadow + moisture * 0.3 > (if waterside then 0.02 else 0.18 + dry * 0.12) then 1 else 2
end

return Cover
