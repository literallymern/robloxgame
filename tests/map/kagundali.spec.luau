--!nocheck
-- needs: roblox-mock
-- Real regional landscape, tree assets, scene builder and update orchestration; no Roblox rendering.
local Layout = load("ReplicatedStorage/Shared/Config/MapLayout")
local Heightfield = load("StudioTools/Map/Heightfield")
local hf = Heightfield.new(Layout)
local Junction = load("StudioTools/Map/JunctionLandscape")
local feature = Junction.decorate(hf, Layout)
local Trees = load("StudioTools/Map/Builders/JunctionTrees")
local Update = load("StudioTools/Map/KagundaliUpdate")
local Builder = load("StudioTools/Map/Builders/Kagundali")
local Util = load("StudioTools/Map/Builders/Util")
local passed = 0
local function check(ok, name)
	assert(ok, name)
	passed += 1
	print("PASS " .. name)
end
local changed, grass = 0, 0
local outside, roads, water, finite = true, true, true, true
for z = 2880, 3712, 16 do
	for x = 0, 896, 16 do
		local a, c, w = hf.surface(x, z)
		local b, d, v = feature.surface(x, z)
		local e = hf.roads.nearest(x, z) or math.huge
		if not Junction.contains(x, z) then
			outside = outside and a == b and c == d and w == v
		end
		if e < 5 then
			roads = roads and a == b and c == d
		end
		water = water and w == v
		finite = finite and b == b and math.abs(b - a) < 12
		if math.abs(b - a) > 0.1 then
			changed += 1
		end
		if d <= 0 and feature.naturalMaterial(b, 0.2, x, z, d) == 1 then
			grass += 1
		end
	end
end
check(outside and roads and water, "bounded landscape leaves outside terrain, driving heights and water unchanged")
check(
	changed > 700 and grass > 500 and finite,
	"local terrain has substantial bounded contours and continuous native-grass material"
)
local padFlat = true
local yard = Junction.Yard
local padHeight = feature.surface(yard.X, yard.Z)
for _, x in { -40, 0, 40 } do
	for _, z in { -30, 0, 30 } do
		padFlat = padFlat and math.abs(feature.surface(yard.X + x, yard.Z + z) - padHeight) < 0.01
	end
end
check(padFlat, "workshop pad is level and joined to the existing rural ground")
local oldFeature = Junction.decorateV1(hf, Layout)
local start, finish = Junction.access(hf)
local cleared = 0
for i = 1, 10 do
	local p = start:Lerp(finish, i / 12)
	local y, code = feature.surface(p.X, p.Z)
	if oldFeature.naturalMaterial(y, 0.1, p.X, p.Z, code) == 1 then
		assert(feature.naturalMaterial(y, 0.1, p.X, p.Z, code) == 4)
		cleared += 1
	end
end
check(cleared >= 5, "v2 driveway replaces the former grass material under its gravel surface")
local previousGround = Junction.decorateV2(hf, Layout)
local clearedDrains = 0
-- Native grass is rooted at voxel centres, including cells beside the channel axis.
for z = Junction.Bounds.MinZ + 2, Junction.Bounds.MaxZ - 2, 4 do
	for x = Junction.Bounds.MinX + 2, Junction.Bounds.MaxX - 2, 4 do
		local y, code, water = feature.surface(x, z)
		local dx = (feature.surface(x + 4, z) - feature.surface(x - 4, z)) / 8
		local dz = (feature.surface(x, z + 4) - feature.surface(x, z - 4)) / 8
		local slope = math.sqrt(dx * dx + dz * dz)
		local before, after =
			previousGround.naturalMaterial(y, slope, x, z, code), feature.naturalMaterial(y, slope, x, z, code)
		if before ~= after then
			assert(before == 1 and after == 4 and code <= 0)
			clearedDrains += 1
		end
		local oldY, _, oldWater = previousGround.surface(x, z)
		assert(oldY == y and oldWater == water)
	end
end
check(clearedDrains > 100, "channel beds clear native grass at voxel centres without changing ground or water heights")
for _, block in Layout.GundivillePlaceholders do
	if table.find({ "Congress", "Hausali", "CentralBank", "Residence" }, block.Id) then
		local r = block.Rect
		assert(
			Junction.Bounds.MinZ > r.MaxZ
				or Junction.Bounds.MaxZ < r.MinZ
				or Junction.Bounds.MinX > r.MaxX
				or Junction.Bounds.MaxX < r.MinX
		)
		for _, x in { r.MinX, (r.MinX + r.MaxX) / 2, r.MaxX } do
			for _, z in { r.MinZ, (r.MinZ + r.MaxZ) / 2, r.MaxZ } do
				local y, code, water = hf.surface(x, z)
				local fy, fc, fw = feature.surface(x, z)
				assert(y == fy and code == fc and water == fw)
				assert(hf.naturalMaterial(y, 0.1, x, z, code) == feature.naturalMaterial(y, 0.1, x, z, code))
			end
		end
	end
end
check(true, "bounded patch excludes all four government buildings and preserves their terrain")
local smallLeaves, branchCount, shapes = true, 0, 0
for _, kind in Trees.Kinds do
	for variant = 1, Trees.Variants do
		local source = Trees.blueprint(kind, variant)
		for group, parts in source.Groups do
			for _, part in parts do
				shapes += 1
				if group == 1 then
					branchCount += 1
				elseif part.Role == "Leaf" then
					smallLeaves = smallLeaves and part.Form == "Ball" and part.Size.Z < 2 and part.Size.Y >= 0.09
				end
			end
		end
	end
end
check(
	smallLeaves and branchCount > 1000 and shapes > 4000,
	"new original assets use small curved leaves and branching wood instead of oversized planar cards"
)
local library = Trees.prepare()
local calls = MockStats.unionCalls
check(
	#library:GetChildren() == 15 and calls == 61,
	"five species with three variants compile to four reusable CSG parts each"
)
check(
	MockStats.ballInputs == 1 and MockStats.solidInputs > 4000,
	"foliage uses scaled baked solids instead of nonuniform Ball parts that Roblox keeps spherical"
)
check(
	Trees.prepare() == library and MockStats.unionCalls == calls,
	"prepared asset library is reused without recompilation"
)
local map = Instance.new("Folder")
map.Name, map.Parent = "Map", workspace
local vegetation = Util.folder(map, "Vegetation")
local oldPlant = Instance.new("Model")
oldPlant.Parent = vegetation
Util.part(oldPlant, "Trunk", CFrame.new(210, 50, 3100), Vector3.new(1, 20, 1))
local farPlant = Util.part(vegetation, "OutsideArea", CFrame.new(-1000, 55, 3300), Vector3.new(1, 20, 1))
local rd = Util.folder(map, "RoadDetails")
local places = Util.folder(map, "Places")
local label = Instance.new("BillboardGui")
local place = Instance.new("Model")
place.Name, place.Parent = "SouthBorder", places
local marker = Util.part(place, "NameMarker", CFrame.new(), Vector3.new(1, 1, 1), { Decoration = true })
label.Parent = marker
local signs = Instance.new("Folder")
signs.Name, signs.Parent = "Signs", rd
local sourceSigns = load("StudioTools/Map/RoadDetails").new(Layout, hf).signs
for _, sign in sourceSigns do
	if Junction.contains(sign.X, sign.Z) then
		load("StudioTools/Map/Builders/Signs").build(signs, sign)
	end
end
local labels = {}
for _, item in signs:GetDescendants() do
	if item:IsA("TextLabel") then
		labels[item] = item.Text
	end
end
local report = Update.apply(hf, Layout, map, { Terrain = false, GeneratedTerrain = true })
check(not label.Enabled, "generated overview labels no longer float across the benchmark horizon")
check(report.MarkingsComplete and report.Markings > 20, "focused update restores local edge, centre and stop markings")
check(
	report.Trees >= 50 and report.Shrubs >= 35 and report.Ferns >= 35 and report.Workshop,
	"actual scene builds grouped forest, undergrowth and a transport workshop"
)
check(
	report.Parts < Junction.MaxParts and report.Parts > 800,
	"complete regional scene stays inside its saved-instance budget"
)
check(
	oldPlant.Parent == nil and farPlant.Parent == vegetation,
	"commit removes old benchmark vegetation and preserves the rest of the map"
)
local signTexts = true
for label, text in labels do
	signTexts = signTexts and label.Text == text and label.Parent ~= nil
end
check(
	signTexts and report.RefinedSigns >= 3,
	"yellow signs keep their actual text while their posts and rear construction are refined"
)
local signSizes, postPositions = {}, {}
for _, sign in signs:GetChildren() do
	for _, part in sign:GetChildren() do
		if part:IsA("BasePart") and part.Name == "Post" then
			postPositions[part] = part.Position
		end
		if sign.Name == "DirectionSign" and part:IsA("BasePart") and part.Name == "Board" then
			assert(part.Size.X >= 10.8 and part.Size.Y >= 1.95)
			signSizes[part] = part.Size
		end
	end
end
check(next(signSizes) ~= nil, "retained direction boards gain readable proportions without replacing text instances")
local area = map.KagundaliJunction
local allGrounded, sightClear, sourceParts, collisionSafe, driveConnected = true, true, 0, true, false
local species = {}
for _, plant in area.Planting:GetChildren() do
	if plant:IsA("Model") then
		local p = plant:GetAttribute("GroundPosition")
		allGrounded = allGrounded and math.abs(p.Y - feature.surface(p.X, p.Z)) < 1e-8
		if plant:FindFirstChild("TrunkCollision") then
			species[plant:GetAttribute("Species")] = true
			sightClear = sightClear
				and (Vector3.new(p.X, 0, p.Z) - Vector3.new(Junction.Centre.X, 0, Junction.Centre.Z)).Magnitude
					>= 92
		end
	end
end
for _, part in area:GetDescendants() do
	if part:IsA("PartOperation") then
		sourceParts += 1
		collisionSafe = collisionSafe and not part.CanCollide
	end
	if part:IsA("BasePart") and part.Name == "WorkshopAccess" then
		driveConnected = true
	end
end
check(allGrounded and sightClear, "plant bases follow sculpted terrain and tall trees leave junction sight lines clear")
check(
	species.Broadleaf and species.Acacia and species.Eucalyptus and sourceParts > 500 and collisionSafe,
	"three distinct trees use streamed CSG with separate narrow trunk collisions"
)
check(driveConnected, "workshop apron has a gravel connection to the existing R3")
local drainCount = 0
for _, part in area.Roadside:GetChildren() do
	if part:IsA("BasePart") and part.Name == "DrainInvert" then
		drainCount += 1
		for i = 0, 12 do
			for _, side in { -1, 0, 1 } do
				local p = part.CFrame
					* Vector3.new(side * part.Size.X / 2, part.Size.Y / 2, part.Size.Z * (i / 12 - 0.5))
				assert(p.Y >= feature.surface(p.X, p.Z) + 0.06, "channel floor is buried between sampled endpoints")
			end
		end
	end
end
check(drainCount > 0, "channel floors clear the ground across their full width and length")
local accessStart, accessEnd = Junction.access(feature)
local Geometry = load("StudioTools/Map/Geometry")
local crossingCount = 0
for _, part in area:GetDescendants() do
	if part:IsA("BasePart") and (part.Name == "DrainWall" or part.Name == "DrainInvert") then
		assert(part.Size.Z < 16.5, "long channel span did not follow the finer ground profile")
		for i = 0, 12 do
			local bottom = part.CFrame * Vector3.new(0, -part.Size.Y / 2, part.Size.Z * (i / 12 - 0.5))
			assert(bottom.Y < feature.surface(bottom.X, bottom.Z), "channel underside is suspended above the ground")
			for _, side in { -1, 1 } do
				local p = part.CFrame
					* Vector3.new(side * part.Size.X / 2, part.Size.Y / 2, part.Size.Z * (i / 12 - 0.5))
				assert(
					Geometry.segmentDistance(accessStart.X, accessStart.Z, accessEnd.X, accessEnd.Z, p.X, p.Z) >= 4.5,
					"open channel concrete crosses the workshop driving corridor"
				)
			end
		end
	elseif part:IsA("BasePart") and part.Name == "WorkshopDrainCrossing" then
		crossingCount += 1
		assert(part.Material == Enum.Material.Concrete and part.CanCollide)
		for i = 0, 8 do
			for _, side in { -1, 0, 1 } do
				local p = part.CFrame
					* Vector3.new(side * part.Size.X / 2, part.Size.Y / 2, part.Size.Z * (i / 8 - 0.5))
				assert(
					p.Y > feature.surface(p.X, p.Z),
					`workshop crossing surface is buried: {p.X},{p.Z} top={p.Y} ground={feature.surface(p.X, p.Z)}`
				)
			end
		end
	end
end
check(true, "short channel sections reach into the ground and leave the full driveway width clear")
check(crossingCount > 0, "workshop crossing has a grounded concrete driving surface with collision")
local arrowCount, safeMarking = 0, true
for _, part in area.Roadside:GetChildren() do
	if part.Name == "ApproachTurnArrow" then
		arrowCount += 1
		local p = part.Position
		local _, surface = hf.surface(p.X, p.Z)
		local edge, height, roadIndex = hf.roads.nearest(p.X, p.Z)
		safeMarking = safeMarking
			and Junction.contains(p.X, p.Z)
			and Heightfield.Materials[surface] == "Asphalt"
			and edge < 0
			and hf.roads.roads[roadIndex].Id == "R3"
			and p.Y > height
			and p.Y - height < 0.15
			and not part.CanCollide
	end
end
check(arrowCount == 6 and safeMarking, "turn arrow stays on the existing carriageway without adding collision")
local first = area
local signsBefore = #signs:GetDescendants()
for _, sign in signs:GetChildren() do
	if sign:IsA("Model") then
		sign:SetAttribute("JunctionConstruction", "kagundali-junction-1")
	end
end
local again = Update.apply(hf, Layout, map, { Terrain = false, GeneratedTerrain = true })
for post, position in postPositions do
	assert((post.Position - position).Magnitude < 1e-8)
end
for board, size in signSizes do
	assert((board.Size - size).Magnitude < 1e-8)
end
check(true, "repeat and old-construction migration neither shift posts again nor keep enlarging boards")
check(
	first.Parent == nil and again.Parts == report.Parts and #signs:GetDescendants() == signsBefore,
	"repeat update replaces its scene without stacking vegetation or sign hardware"
)
check(MockStats.unionCalls == calls, "repeat update does not recompile tree assets")
local prior = map.KagundaliJunction
local realBuild = Builder.build
Builder.build = function()
	error("simulated scene failure")
end
local okay = pcall(Update.apply, hf, Layout, map, { Terrain = false, GeneratedTerrain = true })
Builder.build = realBuild
check(not okay and map.KagundaliJunction == prior, "failed replacement preserves the previous completed regional scene")
local lightingModel = load("ReplicatedStorage/Shared/Environment/Model")
local lightingRevision = lightingModel.VisualRevision
lightingModel.VisualRevision = "cached-old-lighting"
local cacheOkay, cacheError = pcall(Update.apply, hf, Layout, map, { Terrain = false, GeneratedTerrain = true })
lightingModel.VisualRevision = lightingRevision
check(
	not cacheOkay
		and string.find(tostring(cacheError), "cached lighting", 1, true)
		and map.KagundaliJunction == prior
		and MockStats.unionCalls == calls,
	"stale loaded lighting stops the update before changing assets or geometry"
)
prior:SetAttribute("GeneratedBy", nil)
okay = pcall(Update.apply, hf, Layout, map, { Terrain = false, GeneratedTerrain = true })
check(not okay and map.KagundaliJunction == prior, "custom content occupying the benchmark folder blocks replacement")
library:SetAttribute("AssetVersion", "kagundali-trees-1")
local updatedLibrary = Trees.prepare()
check(
	updatedLibrary ~= library and library.Parent == nil and updatedLibrary:GetAttribute("AssetVersion") == Trees.Version,
	"saved tree-1 library is replaced so old spherical assets cannot survive the v2 upgrade"
)
print(
	`INFO Kagundali: {report.Trees} trees, {report.Shrubs} shrubs, {report.Ferns} ferns, {report.Rocks} rocks, {report.Parts} parts; {changed} changed height samples`
)
print(`ALL CHECKS PASSED ({passed} Kagundali checks)`)
