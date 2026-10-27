--!strict
-- needs: roblox-mock
-- Tests source blueprints, shared CSG preparation, persistence contracts and failure handling.
-- The mock validates inputs/transforms, not the Roblox boolean solver or rendered foliage.
local Library = load("StudioTools/Map/Builders/CanopyLibrary")
local Vegetation = load("StudioTools/Map/Vegetation")
local Heightfield = load("StudioTools/Map/Heightfield")
local Layout = load("ReplicatedStorage/Shared/Config/MapLayout")
local failures = 0
local function check(name: string, ok: boolean)
	print(if ok then "PASS" else "FAIL", name)
	if not ok then
		failures += 1
	end
end

local valid, separatedSprays = true, true
local signatures = {}
for _, kind in Library.Kinds do
	for variant = 1, Library.Variants do
		local sources = Library.blueprint(kind, variant)
		valid = valid and #sources >= 150 and #sources <= 190
		local signature = {}
		local low, high = math.huge, -math.huge
		local lower, upper = 0, 0
		for _, source in sources do
			local dimensionsOk = if source.Geometry == "Wedge"
				then source.Size.X < 0.02 and source.Size.Y > source.Size.X and source.Size.Z > source.Size.X
				else source.Size.Y < 0.03 and source.Size.Z < 0.03 and source.Size.X <= 1.1
			valid = valid
				and dimensionsOk
				and source.Size.X > 0
				and source.Size.Y > 0
				and source.Size.Z > 0
				and source.Position.Magnitude < 0.8
			local yaw = math.atan2(-source.Frame.LookVector.X, -source.Frame.LookVector.Z)
			low, high = math.min(low, yaw), math.max(high, yaw)
			local reach = Vector3.new(source.Position.X, 0, source.Position.Z).Magnitude
			if source.Position.Y < -0.15 then
				lower = math.max(lower, reach)
			end
			if source.Position.Y > 0.15 then
				upper = math.max(upper, reach)
			end
			table.insert(
				signature,
				string.format("%.5f:%.5f:%.5f:%.5f", source.Position.X, source.Position.Y, source.Position.Z, yaw)
			)
		end
		separatedSprays = separatedSprays and high - low > 3
		signatures[table.concat(signature, ";")] = true
		if kind == "Pine" then
			valid = valid and lower > upper * 1.4
		end
	end
end
local variations = 0
for _ in signatures do
	variations += 1
end
check("canopy blueprints use pointed thin leaf diamonds, connecting twigs and tapered pine whorls", valid)
check("every canopy has several divergent sprays with open spaces", separatedSprays)
check("all species and variants have distinct source silhouettes", variations == 20)

local stats: any = MockStats
local first = Library.prepare()
local storage = game:GetService("ServerStorage")
local folder = storage:FindFirstChild("RoNationCanopyLibrary")
check(
	"preparation creates all twenty saved native canopy prototypes",
	first.Created and first.Templates == 20 and folder ~= nil and #folder:GetChildren() == 20
)
local unions = stats.unionCalls
local again = Library.prepare()
check(
	"preparation reuses the complete saved library without new boolean work",
	not again.Created and stats.unionCalls == unions
)

local parent = Instance.new("Folder")
local small =
	Library.crown("Acacia", 1, CFrame.new(0, 5, 0), Vector3.new(10, 3, 8), Color3.fromRGB(80, 100, 60), parent)
local tall =
	Library.crown("Acacia", 1, CFrame.new(30, 12, 0), Vector3.new(20, 6, 16), Color3.fromRGB(74, 96, 52), parent)
check(
	"cloned canopies vary scale and colour without recomputing geometry",
	stats.unionCalls == unions
		and small ~= tall
		and small.Size.X == 10
		and tall.Size.X == 20
		and small.Color.R ~= tall.Color.R
)
check(
	"foliage stays anchored, shadowed and excluded from collision/touch/raycast",
	small.Anchored and small.CastShadow and not small.CanCollide and not small.CanTouch and not small.CanQuery
)

local angledFrame = CFrame.new(21, 40, -12) * CFrame.Angles(0.2, 0.65, -0.1)
local centred = Library.crown("Broadleaf", 3, angledFrame, Vector3.new(17, 9, 13), Color3.fromRGB(76, 104, 52), parent)
check(
	"resized CSG clones align physical extents instead of an offset mesh origin",
	(centred.ExtentsCFrame.Position - angledFrame.Position).Magnitude < 1e-6
		and (centred.ExtentsCFrame.RightVector - angledFrame.RightVector).Magnitude < 1e-6
)

folder:SetAttribute("CanopyVersion", "previous-version")
local success = pcall(function()
	Library.prepare(nil, {
		UnionAsync = function()
			error("Deliberate CSG service failure")
		end,
	})
end)
check(
	"CSG failure preserves the entire previous saved library",
	not success and storage:FindFirstChild("RoNationCanopyLibrary") == folder and #folder:GetChildren() == 20
)
folder:SetAttribute("CanopyVersion", Library.Version)
folder:SetAttribute("ManagedBy", "CustomContent")
local occupied = pcall(Library.prepare)
check("library refuses to overwrite custom content at its reserved name", not occupied and folder.Parent == storage)
folder:SetAttribute("ManagedBy", "RoNationCanopyLibrary")

-- Actual terrain sampler overrides modeled elevations, including all cascade rocks.
local hf = Heightfield.new(Layout)
local samplerCalls, bedCalls = 0, 0
local plants = Vegetation.new(Layout, hf, nil, nil, function(_x, _z, allowWater)
	samplerCalls += 1
	if allowWater then
		bedCalls += 1
	end
	return 222, 0.2
end)
local grounded = #plants.trees > 0 and #plants.bushes > 0 and #plants.rocks > 0
for _, list in { plants.trees, plants.bushes, plants.rocks } do
	for _, plant in list do
		grounded = grounded and plant.Y == 222 and plant.Slope == 0.2
	end
end
check(
	"all trees, shrubs and rocks conform to the saved-terrain sampler",
	grounded and samplerCalls > 10000 and bedCalls > 0
)
local empty = Vegetation.new(Layout, hf, nil, nil, function()
	return nil, 0
end)
check(
	"missing or sheltered terrain produces no floating vegetation",
	#empty.trees == 0 and #empty.bushes == 0 and #empty.rocks == 0
)

if failures > 0 then
	error(`{failures} canopy checks failed`)
end
print("ALL CHECKS PASSED")
