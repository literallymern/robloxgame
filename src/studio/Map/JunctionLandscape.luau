--!strict
-- The first art benchmark is the existing R3/N5 junction, not a new road or city location.
-- Keep highland-4 as the immutable source outside this bounded, independently versioned area.
local Geometry = require(script.Parent.Geometry)

local Junction = {}
Junction.Revision = "kagundali-junction-1"
Junction.LightingRevision = "neutral-highland-1"
Junction.Bounds = table.freeze({ MinX = 64, MaxX = 832, MinZ = 2944, MaxZ = 3648 })
Junction.Centre = Vector3.new(453.2403817191586, 55.695266970006095, 3298.6057257873795)
Junction.Yard = table.freeze({ X = 245, Z = 3430, Width = 86, Depth = 70 })
Junction.MaxParts = 1600

function Junction.contains(x: number, z: number, inset: number?): boolean
	local b, m = Junction.Bounds, inset or 0
	return x >= b.MinX + m and x <= b.MaxX - m and z >= b.MinZ + m and z <= b.MaxZ - m
end

function Junction.weight(x: number, z: number): number
	local b = Junction.Bounds
	return Geometry.smoothstep(math.min(x - b.MinX, b.MaxX - x, z - b.MinZ, b.MaxZ - z) / 52)
end

-- Feature landscape used both for new maps and conservative local saved-voxel migration.
function Junction.decorate(hf: any, layout: any): any
	local result = table.clone(hf)
	local yard = Junction.Yard
	local yardY = hf.surface(yard.X, yard.Z)
	local function eligible(x: number, z: number, code: number, water: number?): boolean
		if not Junction.contains(x, z) or water ~= nil or (code > 0 and code ~= 4 and code ~= 5) then
			return false
		end
		for _, place in layout.Places do
			if Geometry.rectDistance(place.Rect, x, z) < 12 then
				return false
			end
		end
		return hf.fields.cropAt(x, z) == nil
	end
	result.surface = function(x: number, z: number): (number, number, number?)
		local y, code, water = hf.surface(x, z)
		if not eligible(x, z, code, water) then
			return y, code, water
		end
		local edge = hf.roads.nearest(x, z) or math.huge
		if edge < 6 or Junction.weight(x, z) == 0 then
			return y, code, water
		end
		local clear = Geometry.smoothstep((edge - 5) / 20)
		local w = Junction.weight(x, z) * clear
		-- Shallow connected swales and shoulder berms; no random isolated dirt circles.
		local swale = -2.2 * math.exp(-((edge - 13) / 4.5) ^ 2)
		local berm = 1.6 * math.exp(-((edge - 25) / 10) ^ 2)
		local folds = 3.8 * math.noise(x / 85 + 0.7, z / 150 + 0.2, 82.3)
		y += (swale + berm + folds * clear) * w
		local padDistance = math.max(math.abs(x - yard.X) - yard.Width / 2, math.abs(z - yard.Z) - yard.Depth / 2)
		local pad = 1 - Geometry.smoothstep(math.max(0, padDistance) / 22)
		y += (yardY - y) * pad * w
		return y, 0, nil
	end
	result.naturalMaterial = function(y: number, slope: number, x: number, z: number, hint: number?): number
		local _, code, water = hf.surface(x, z)
		if not eligible(x, z, code, water) or Junction.weight(x, z) < 0.1 then
			return hf.naturalMaterial(y, slope, x, z, hint)
		end
		local edge = hf.roads.nearest(x, z) or math.huge
		if math.abs(x - yard.X) < yard.Width / 2 and math.abs(z - yard.Z) < yard.Depth / 2 then
			return 4
		end -- Ground
		if edge < 7 then
			return hf.naturalMaterial(y, slope, x, z, hint)
		end
		if edge > 10 and edge < 17 and slope < 0.45 then
			return 5
		end -- Mud in connected drainage
		if slope > 0.75 then
			return 3
		end -- Rock only on genuinely steep cuts
		return 1 -- Grass supports native Decoration; LeafyGrass left the old meadow visibly bare
	end
	result.legacySurface, result.legacyNaturalMaterial = hf.surface, hf.naturalMaterial
	return result
end

return Junction
