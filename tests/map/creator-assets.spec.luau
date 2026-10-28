--!nocheck
-- needs: roblox-mock
-- Synthetic pack layouts test the importer, not Roblox's live asset hierarchy or renderer.
local Assets = load("StudioTools/Map/CreatorAssets")
local Trees = load("StudioTools/Map/Builders/JunctionTrees")
local U = load("StudioTools/Map/Builders/Util")
local passed = 0
local function check(ok, message)
	assert(ok, message)
	passed += 1
	print("PASS " .. message)
end
local function mesh(parent, name, position, size)
	local p = Instance.new("MeshPart")
	p.Name, p.Parent, p.CFrame, p.Size = name, parent, CFrame.new(position), size
	p.MeshId, p.TextureID, p.DoubleSided = "fixture-mesh", "fixture-texture", true
	return p
end
local function model(parent, name)
	local m = Instance.new("Model")
	m.Name, m.Parent = name, parent
	return m
end
local function forest()
	local root = model(nil, "Forest Pack")
	local group = model(root, "Trees")
	for i = 1, 2 do
		local tree = model(group, "BroadleafTree" .. i)
		mesh(tree, "Trunk", Vector3.new(i * 30, 15, 40), Vector3.new(1, 10, 1))
		local leaves = mesh(tree, "Leaves", Vector3.new(i * 30, 20, 40), Vector3.new(8, 8, 8))
		local appearance = Instance.new("SurfaceAppearance")
		appearance.ColorMap, appearance.Parent = "fixture-pbr", leaves
		Instance.new("ModuleScript").Parent = appearance
		Instance.new("Script").Parent = leaves
		Instance.new("Script").Parent = tree
		mesh(tree, "Soil", Vector3.new(i * 30, 0, 40), Vector3.new(90, 1, 90))
	end
	for _, kind in { "Bush", "Fern", "Boulder" } do
		mesh(model(root, kind), "Geometry", Vector3.new(60, 1.5, 70), Vector3.new(2, 3, 2))
	end
	return root
end
local function city()
	local root = model(nil, "City Props Pack")
	local lamp = model(root, "StreetLight")
	mesh(lamp, "Pole", Vector3.new(50, 10, 80), Vector3.new(0.7, 20, 0.7))
	mesh(lamp, "Head", Vector3.new(55, 19, 80), Vector3.new(2, 1, 1))
	Instance.new("Script").Parent = lamp
	mesh(model(root, "DecorativeLamp"), "Body", Vector3.new(0, 3, 0), Vector3.new(2, 6, 2))
	return root
end
local requests = {}
local function loader(id)
	table.insert(requests, id)
	return if id == Assets.Packs[1].Id then forest() else city()
end
local function metadata(_id)
	return { Creator = { Id = 1 }, AssetTypeId = 10 }
end
local library = Assets.install(loader, metadata)
check(
	#requests == 2 and requests[1] == 6432306802 and requests[2] == 6370681139,
	"only the two configured official model packs are requested"
)
check(
	#library.Tree:GetChildren() == 2 and #library.Lamp:GetChildren() == 2,
	"collection wrappers and nested components do not duplicate complete models"
)
check(
	#library.Tree:GetChildren()[1]:GetChildren() == 2,
	"soil demonstration planes are excluded from tree geometry and bounds"
)
local clean, pbr, sided = true, 0, 0
for _, node in library:GetDescendants() do
	clean = clean and not node:IsA("LuaSourceContainer")
	if node:IsA("SurfaceAppearance") then
		assert(node.ColorMap == "fixture-pbr")
		pbr += 1
	elseif node:IsA("MeshPart") then
		assert(node.MeshId == "fixture-mesh" and node.TextureID == "fixture-texture")
		assert(node.Anchored and not node.CanCollide and not node.CanTouch and not node.CanQuery)
		if node.DoubleSided then
			sided += 1
		end
	end
end
check(
	clean and pbr == 2 and sided == 10,
	"script-free library preserves mesh IDs, PBR textures and double-sided foliage"
)
local before = MockStats.unionCalls or 0
check(
	Trees.prepare() == library and (MockStats.unionCalls or 0) == before,
	"complete imported vegetation bypasses procedural CSG preparation"
)
local parent = Instance.new("Folder")
local globalParent = Instance.new("Folder")
local globalCount = load("StudioTools/Map/Builders/Vegetation").tree(globalParent, {
	Kind = "Broadleaf",
	X = 100,
	Y = 30,
	Z = 200,
	Size = 28,
	Yaw = 0.4,
	Seed = 0.35,
	Slope = 0.1,
}, function()
	return 30
end)
local globalTree = globalParent:GetChildren()[1]
check(
	globalCount == 3
		and globalTree:GetAttribute("SourceAssetId") == Assets.Packs[1].Id
		and globalTree:GetAttribute("RootEmbedDepth") > 1
		and globalTree.TrunkCollision.CanCollide,
	"the shared map-wide builder reuses the saved official broadleaf tree with grounded roots"
)
check(
	Assets.place("Tree", 1, globalParent, Vector3.new(0, 30, 0), 28, 0, nil, "Pine") == nil,
	"missing imported species use the native fallback rather than changing the biome's trees"
)
local placed = Assets.place("Tree", 1, parent, Vector3.new(100, 30, 200), 28, 0)
local low, high = math.huge, -math.huge
for _, p in placed:GetChildren() do
	if p:IsA("MeshPart") then
		low, high = math.min(low, p.Position.Y - p.Size.Y / 2), math.max(high, p.Position.Y + p.Size.Y / 2)
	end
end
check(
	math.abs(low - 28.46) < 1e-6 and math.abs(high - 56.46) < 1e-6 and placed.TrunkCollision.CanCollide,
	"tree keeps source proportions while its root tips are embedded and trunk collision stays grounded"
)
local sloped = Trees.plant(library, parent, "Broadleaf", 1, Vector3.new(100, 30, 200), 28, 0.7, function(x, _z)
	return 30 + (x - 100) * 0.5
end)
check(
	math.abs(sloped:GetAttribute("RootEmbedDepth") - 2.66) < 1e-6
		and (sloped:GetAttribute("GroundPosition") - Vector3.new(100, 30, 200)).Magnitude < 1e-6
		and sloped.Trunk.CFrame.UpVector.Y == 1,
	"planting samples downhill ground around the roots without tilting the trunk or moving its ground reference"
)
local cliff = Assets.place("Tree", 1, parent, Vector3.new(0, 30, 0), 28, 0, function()
	return -100
end)
local unknown = Assets.place("Tree", 1, parent, Vector3.new(0, 30, 0), 28, 0, function()
	return nil
end)
check(
	cliff:GetAttribute("RootEmbedDepth") == 4.5 and math.abs(unknown:GetAttribute("RootEmbedDepth") - 1.54) < 1e-6,
	"root embedding is bounded at abrupt drops and missing neighbour probes keep the conservative base depth"
)
local lamp = Assets.place("Lamp", 1, parent, Vector3.new(10, 20, 30), 17, math.pi / 2)
local light = lamp.LightEmitter:FindFirstChildOfClass("SpotLight")
check(
	lamp:GetAttribute("SourceName") == "StreetLight"
		and Assets.place("Lamp", 2, parent, Vector3.new(), 17, 0):GetAttribute("SourceName") == "StreetLight",
	"road lights take priority over alphabetically earlier decorative lamp posts"
)
check(
	light
		and light:GetAttribute("RoNationStreetLight")
		and not light.Enabled
		and lamp.LightEmitter.CFrame.UpVector.Y == 1
		and lamp.Head.Position.X < lamp.Pole.Position.X,
	"lamp arm faces the requested road direction and known night light points down"
)
local ok = pcall(function()
	Assets.install(loader, function()
		return { Creator = { Id = 2 }, AssetTypeId = 10 }
	end)
end)
check(
	not ok and #requests == 2 and Assets.get() == library,
	"wrong creator metadata stops before download and preserves existing library"
)
ok = pcall(function()
	Assets.install(function()
		error("download unavailable")
	end, metadata)
end)
check(not ok and Assets.get() == library, "download failure preserves existing library")
ok = pcall(function()
	Assets.install(function()
		return model(nil, "UnknownPack")
	end, metadata)
end)
check(not ok and Assets.get() == library, "unrecognized live hierarchy cannot replace the working library")

local Layout = load("ReplicatedStorage/Shared/Config/MapLayout")
local hf = load("StudioTools/Map/Heightfield").new(Layout)
local map = Instance.new("Folder")
map.Name, map.Parent = "Map", workspace
local lamps = U.folder(U.folder(map, "RoadDetails"), "StreetLights")
local details = load("StudioTools/Map/RoadDetails").new(Layout, hf)
local Junction = load("StudioTools/Map/JunctionLandscape")
local poles = {}
for _, source in details.lights do
	local pole = U.part(lamps, "Pole", CFrame.new(source.X, source.Y + 8, source.Z), Vector3.new(1, 17, 1))
	table.insert(poles, pole)
end
local custom = U.part(lamps, "CustomFixture", CFrame.new(400, 50, 3300), Vector3.new(1, 10, 1))
local Update = load("StudioTools/Map/KagundaliUpdate")
local oldArea = U.folder(map, "KagundaliJunction")
local duplicate = U.folder(map, "KagundaliJunction")
local legacyTree = model(duplicate, "LegacyTree")
U.part(legacyTree, "TrunkCollision", CFrame.new(200, 50, 3200), Vector3.new(1, 20, 1))
local report = Update.apply(hf, Layout, map, { Terrain = false, GeneratedTerrain = true })
check(
	oldArea.Parent == nil and duplicate.Parent == nil and report.ReplacedRegions == 2,
	"all duplicate generated regional folders are replaced together"
)
local importedTrees, importedLamps = 0, 0
for _, child in map.KagundaliJunction:GetDescendants() do
	if child:IsA("Model") and child:GetAttribute("AssetVersion") == Assets.Version then
		if child:GetAttribute("Category") == "Tree" then
			assert(child:GetAttribute("RootEmbedDepth") >= 0.5, "regional planting did not embed imported roots")
			importedTrees += 1
		end
		if child:GetAttribute("Category") == "Lamp" then
			importedLamps += 1
		end
	end
end
check(
	importedTrees == report.Trees
		and importedTrees == 64
		and importedLamps > 0
		and importedLamps == report.ImportedLamps
		and report.Parts <= Junction.MaxParts,
	"real regional updater places imported trees and lamps within the part budget"
)
check(
	report.ImportedTrees == 64 and report.NativeTrees == 0,
	"update report counts actual imported and native tree models"
)
local replaced, kept = 0, 0
for _, p in poles do
	if Junction.contains(p.Position.X, p.Position.Z, 20) then
		assert(p.Parent == nil)
		replaced += 1
	else
		assert(p.Parent == lamps)
		kept += 1
	end
end
check(
	replaced == importedLamps and kept > 0 and custom.Parent == lamps,
	"completed imports replace local generated lamps and preserve outside/custom fixtures"
)
local Builder = load("StudioTools/Map/Builders/Kagundali")
local preserved = U.part(lamps, "Pole", CFrame.new(200, 50, 3100), Vector3.new(1, 17, 1))
Builder.removeOldLamps(map, { Vector3.new(300, 50, 3100) })
check(preserved.Parent == lamps, "unreplaced lamp sites survive a partial successful import")
local second = Update.apply(hf, Layout, map, { Terrain = false, GeneratedTerrain = true })
check(
	second.Parts == report.Parts and second.ImportedLamps == report.ImportedLamps,
	"repeat update reuses imports without stacking models"
)
local customRegion = Instance.new("Folder")
customRegion.Name, customRegion.Parent = "KagundaliJunction", map
ok = pcall(Update.apply, hf, Layout, map, { Terrain = false, GeneratedTerrain = true })
check(
	not ok and customRegion.Parent == map and map.KagundaliJunction ~= customRegion,
	"a custom duplicate blocks replacement even if a generated folder comes first"
)
customRegion:Destroy()
local refreshed = Assets.install(loader, metadata)
check(library.Parent == nil and Assets.get() == refreshed, "successful reinstall replaces only the managed library")
refreshed:Destroy()
local occupied = Instance.new("Folder")
occupied.Name, occupied.Parent = "RoNationCreatorAssets", game:GetService("ServerStorage")
ok = pcall(function()
	Assets.install(loader, metadata)
end)
check(not ok and occupied.Parent ~= nil, "custom library content blocks destructive replacement")
print(
	`INFO Creator assets: {importedTrees} imported trees, {importedLamps} lamps, {report.Parts} regional parts in synthetic fixture`
)
print(`ALL CHECKS PASSED ({passed} creator asset checks)`)
