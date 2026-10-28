--!strict
-- The first art benchmark is the existing R3/N5 junction, not a new road or city location.
-- Keep highland-4 as the immutable source outside this bounded, independently versioned area.
local Geometry = require(script.Parent.Geometry)
local GroundCover = require(script.Parent.GroundCover)

local Junction = {}
Junction.Revision = "kagundali-junction-6"
Junction.LightingRevision = "neutral-highland-2"
Junction.Bounds = table.freeze({ MinX = 64, MaxX = 832, MinZ = 2944, MaxZ = 3648 })
Junction.Centre = Vector3.new(453.2403817191586, 55.695266970006095, 3298.6057257873795)
Junction.Yard = table.freeze({ X = 245, Z = 3430, Width = 86, Depth = 70 })
Junction.MaxParts = 1600
Junction.Groves =
	{ { 220, 3090, "Broadleaf" }, { 670, 3100, "Eucalyptus" }, { 710, 3480, "Broadleaf" }, { 190, 3570, "Acacia" } }

function Junction.forest(x: number, z: number): number
	local cover = 0
	for _, centre in Junction.Groves do
		local radius = math.sqrt(((x - centre[1]) / 100) ^ 2 + ((z - centre[2]) / 78) ^ 2)
		cover = math.max(cover, 1 - Geometry.smoothstep((radius - 0.45) / 0.65))
	end
	return cover
end

function Junction.contains(x: number, z: number, inset: number?): boolean
	local b, m = Junction.Bounds, inset or 0
	return x >= b.MinX + m and x <= b.MaxX - m and z >= b.MinZ + m and z <= b.MaxZ - m
end

function Junction.weight(x: number, z: number): number
	local b = Junction.Bounds
	return Geometry.smoothstep(math.min(x - b.MinX, b.MaxX - x, z - b.MinZ, b.MaxZ - z) / 52)
end

-- Immutable junction-1 baseline for recognizing the user's already-saved voxel columns.
-- Add later appearance changes in decorate(), rather than editing these old functions.
function Junction.decorateV1(hf: any, layout: any): any
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

-- Shared by the gravel geometry and its grass-free terrain corridor.
function Junction.access(hf: any): (Vector3, Vector3?)
	local yard, closest, finish = Junction.Yard, math.huge, nil
	for _, road in hf.roads.roads do
		if road.Id == "R3" then
			for i, x in road.line.xs do
				if math.abs(x - yard.X) < closest then
					closest = math.abs(x - yard.X)
					finish = Vector3.new(x, road.profile[i], road.line.zs[i] + road.Width / 2)
				end
			end
		end
	end
	return Vector3.new(yard.X, hf.surface(yard.X, yard.Z), yard.Z - 32), finish
end

-- Immutable junction-2/3 material baseline, including the grass-free workshop access.
function Junction.decorateV2(hf: any, layout: any): any
	local previous = Junction.decorateV1(hf, layout)
	local result = table.clone(previous)
	local a, b = Junction.access(hf)
	result.naturalMaterial = function(y: number, slope: number, x: number, z: number, hint: number?): number
		if b and Geometry.segmentDistance(a.X, a.Z, b.X, b.Z, x, z) < 7 then
			local _, code, water = hf.surface(x, z)
			if water == nil and (code <= 0 or code == 4 or code == 5) and hf.fields.cropAt(x, z) == nil then
				return 4 -- Ground: native grass must not protrude through the gravel driveway.
			end
		end
		return previous.naturalMaterial(y, slope, x, z, hint)
	end
	-- Recognize both the user's already-applied junction-1 and the global highland-4 baseline.
	result.legacySurface, result.legacyNaturalMaterial = previous.surface, previous.naturalMaterial
	result.previousSurface, result.previousNaturalMaterial = hf.surface, hf.naturalMaterial
	return result
end

-- Shared footprints for the concrete channels and their cleared terrain bed.
function Junction.drains(hf: any): any
	local paths = {}
	for roadIndex, road in hf.roads.roads do
		if road.Id ~= "R3" and road.Id ~= "N5" then
			continue
		end
		for i = 1, #road.line.xs - 3, 3 do
			local a = Vector3.new(road.line.xs[i], road.profile[i], road.line.zs[i])
			local b = Vector3.new(road.line.xs[i + 3], road.profile[i + 3], road.line.zs[i + 3])
			if
				not Junction.contains(a.X, a.Z, 26)
				or not Junction.contains(b.X, b.Z, 26)
				or road.onBridge[i]
				or road.onBridge[i + 3]
			then
				continue
			end
			local along = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
			local across = Vector3.new(-along.Z, 0, along.X)
			for _, side in { -1, 1 } do
				local da, db = a + across * (road.Width / 2 + 12) * side, b + across * (road.Width / 2 + 12) * side
				if
					hf.roads.otherDistance(da.X, da.Z, roadIndex) > 10
					and hf.roads.otherDistance(db.X, db.Z, roadIndex) > 10
				then
					table.insert(paths, { A = da, B = db, Across = across })
				end
			end
		end
	end
	return paths
end

function Junction.decorateV4(hf: any, layout: any): any
	local previous = Junction.decorateV2(hf, layout)
	local first = Junction.decorateV1(hf, layout)
	local result = table.clone(previous)
	local paths = Junction.drains(hf)
	result.naturalMaterial = function(y: number, slope: number, x: number, z: number, hint: number?): number
		local material = previous.naturalMaterial(y, slope, x, z, hint)
		if material ~= 1 or not Junction.contains(x, z) then
			return material
		end
		local _, code, water = hf.surface(x, z)
		if water ~= nil or code > 0 or hf.fields.cropAt(x, z) ~= nil then
			return material
		end
		for _, place in layout.Places do
			if Geometry.rectDistance(place.Rect, x, z) < 12 then
				return material
			end
		end
		for _, path in paths do
			if Geometry.segmentDistance(path.A.X, path.A.Z, path.B.X, path.B.Z, x, z) < 4 then
				return 4 -- Ground bed, including voxel-width clearance for native grass blades.
			end
		end
		return material
	end
	-- Recognize the saved junction-2/3, junction-1 and highland-4 generators exactly.
	result.legacySurface, result.legacyNaturalMaterial = previous.surface, previous.naturalMaterial
	result.previousSurface, result.previousNaturalMaterial = first.surface, first.naturalMaterial
	result.originalSurface, result.originalNaturalMaterial = hf.surface, hf.naturalMaterial
	return result
end

-- Concrete is reserved for the driveway crossing and genuinely erosive grades.
-- Elsewhere the existing shallow terrain swale drains the verge without continuous walls.
function Junction.engineeredDrains(hf: any): any
	local result = {}
	local accessA, accessB = Junction.access(hf)
	for _, path in Junction.drains(hf) do
		local mid = (path.A + path.B) / 2
		local grade = math.abs(path.B.Y - path.A.Y) / math.max(1, (path.B - path.A).Magnitude)
		local crossing = accessB
			and Geometry.segmentDistance(accessA.X, accessA.Z, accessB.X, accessB.Z, mid.X, mid.Z) < 26
		if grade > 0.045 or crossing then
			table.insert(result, path)
		end
	end
	return result
end

function Junction.decorate(hf: any, layout: any): any
	local result = Junction.decorateV4(hf, layout)
	local oldGlobal = hf.highland4 or hf
	local old = Junction.decorateV4(oldGlobal, layout)
	local paths = Junction.engineeredDrains(hf)
	local accessA, accessB = Junction.access(hf)
	result.naturalMaterial = function(y: number, slope: number, x: number, z: number, hint: number?): number
		local _, code, water = hf.surface(x, z)
		if
			not Junction.contains(x, z)
			or Junction.weight(x, z) < 0.1
			or water
			or code > 0
			or hf.fields.cropAt(x, z) ~= nil
		then
			return hf.naturalMaterial(y, slope, x, z, hint)
		end
		local yard = Junction.Yard
		if math.abs(x - yard.X) < yard.Width / 2 + 4 and math.abs(z - yard.Z) < yard.Depth / 2 + 4 then
			return old.naturalMaterial(y, slope, x, z, hint)
		end
		if accessB and Geometry.segmentDistance(accessA.X, accessA.Z, accessB.X, accessB.Z, x, z) < 7 then
			return 4
		end
		for _, place in layout.Places do
			if Geometry.rectDistance(place.Rect, x, z) < 12 then
				return hf.naturalMaterial(y, slope, x, z, hint)
			end
		end
		local edge = hf.roads.nearest(x, z) or math.huge
		if edge < 7 then
			return hf.naturalMaterial(y, slope, x, z, hint)
		end
		for _, path in paths do
			if Geometry.segmentDistance(path.A.X, path.A.Z, path.B.X, path.B.Z, x, z) < 4 then
				return 4
			end
		end
		if edge > 10 and edge < 17 and slope < 0.45 then
			return 5
		end
		return GroundCover.material(
			math.max(hf.biomes.forest(x, z), Junction.forest(x, z)),
			hf.biomes.dryness(x, z),
			slope,
			x,
			z
		)
	end
	result.additionalBaselines = {
		{ Surface = old.surface, Material = old.naturalMaterial },
		{ Surface = oldGlobal.surface, Material = oldGlobal.naturalMaterial },
	}
	local v1, v2 = Junction.decorateV1(oldGlobal, layout), Junction.decorateV2(oldGlobal, layout)
	result.legacySurface, result.legacyNaturalMaterial = v2.surface, v2.naturalMaterial
	result.previousSurface, result.previousNaturalMaterial = v1.surface, v1.naturalMaterial
	return result
end

return Junction
