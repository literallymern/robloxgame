--!strict
-- needs: roblox-mock
-- Real generated tree geometry: bounded part count, non-colliding foliage/branches, coherent
-- streamed models, distinct pine taper, deterministic variation and the full vegetation budget.
local Layout = load("ReplicatedStorage/Shared/Config/MapLayout")
local Heightfield = load("StudioTools/Map/Heightfield")
local RoadDetails = load("StudioTools/Map/RoadDetails")
local Vegetation = load("StudioTools/Map/Vegetation")
local Builder = load("StudioTools/Map/Builders/Vegetation")
local failures = 0
local function check(name: string, ok: boolean, detail: string?)
	if ok then
		print("PASS", name)
	else
		failures += 1
		print("FAIL", name, detail or "")
	end
end

local probes = Instance.new("Folder")
local geometryOk, collisionOk, streamingOk, speciesOk, crownsOk = true, true, true, true, true
local signatures = {}
for speciesIndex, kind in Vegetation.TreeKinds do
	for sample = 1, 20 do
		local count = Builder.tree(probes, {
			Kind = kind,
			X = speciesIndex * 70,
			Y = 70,
			Z = sample * 80,
			Size = 28,
			Yaw = 0,
			Seed = sample / 21,
			Slope = 0.1,
		})
		local models = probes:GetChildren()
		local model = models[#models]
		local actual, foliage, branches = 0, 0, 0
		local signature = {}
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				actual += 1
				geometryOk = geometryOk and item.Anchored and item.Size.X > 0 and item.Size.Y > 0 and item.Size.Z > 0
				table.insert(
					signature,
					string.format(
						"%.3f/%.3f/%.3f/%.3f/%.3f/%.3f",
						item.Size.X,
						item.Size.Y,
						item.Size.Z,
						item.CFrame.Position.X - speciesIndex * 70,
						item.CFrame.Position.Y - 70,
						item.CFrame.Position.Z - sample * 80
					)
				)
				if item.Name == "Foliage" or item.Name == "Branch" then
					collisionOk = collisionOk
						and item.CanCollide == false
						and item.CanQuery == false
						and item.CanTouch == false
				end
				if item.Name == "Foliage" then
					foliage += 1
					crownsOk = crownsOk
						and item:IsA("PartOperation")
						and item:GetAttribute("SourceBladeCount") >= 42
						and item:FindFirstChildOfClass("SpecialMesh") == nil
				end
				if item.Name == "Branch" then
					branches += 1
				end
			end
		end
		geometryOk = geometryOk and actual == count and count >= 4 and count <= 5
		streamingOk = streamingOk
			and model:IsA("Model")
			and model.ModelStreamingMode == Enum.ModelStreamingMode.Atomic
			and model:GetAttribute("VegetationSpecies") == kind
		speciesOk = speciesOk
			and (if kind == "Pine" then foliage == 3 and branches == 0 else branches == 1 and foliage >= 2)
		signatures[kind .. ":" .. table.concat(signature, ";")] = true
	end
end
check("trees: every species uses 4–5 anchored parts with valid geometry", geometryOk)
check("trees: foliage and upper branches do not block players, camera or raycasts", collisionOk)
check("trees: compact atomic models stream complete tree silhouettes", streamingOk)
check("trees: pines taper and other species have visible forks", speciesOk)
check("trees: all crowns reuse detailed open CSG sprays instead of sphere meshes", crownsOk)
local variations = 0
for _ in signatures do
	variations += 1
end
check("trees: same-height samples vary in crown proportions and branch lean", variations == 80, tostring(variations))

local hf = Heightfield.new(Layout)
local plants = Vegetation.new(Layout, hf, RoadDetails.new(Layout, hf))
local root = Instance.new("Folder")
local parts = Builder.build(plants, root)
local actual = 0
local connected, forkCount, worstSeparation = true, 0, 0
for _, item in root:GetDescendants() do
	-- A named branch alone does not establish a visible fork. Its base must actually start
	-- on the finite trunk axis, including the buried part of a trunk on sloping ground.
	if item:IsA("Model") and item:GetAttribute("VegetationSpecies") ~= "Pine" then
		local trunk = item:FindFirstChild("Trunk")
		local branch = item:FindFirstChild("Branch")
		if not trunk or not branch then
			connected = false
		else
			local a = trunk.CFrame.Position - trunk.CFrame.RightVector * trunk.Size.X / 2
			local b = trunk.CFrame.Position + trunk.CFrame.RightVector * trunk.Size.X / 2
			local base = branch.CFrame.Position - branch.CFrame.RightVector * branch.Size.X / 2
			local axis = b - a
			local t = math.clamp((base - a):Dot(axis) / axis:Dot(axis), 0, 1)
			local separation = (base - (a + axis * t)).Magnitude
			worstSeparation = math.max(worstSeparation, separation)
			connected = connected and separation < 1e-6
			forkCount += 1
		end
	end
	if item:IsA("BasePart") then
		actual += 1
	end
end
check(
	"trees: every full-map branch grows from its trunk, without disconnected forks",
	connected and forkCount > 3000,
	`{forkCount} forks; maximum axis separation {worstSeparation}`
)
check("vegetation: reported count matches all generated parts", parts == actual)
check("vegetation: full map stays below 36000 actual parts", actual <= 36000, tostring(actual))
print(`INFO detailed vegetation: {#plants.trees} trees, {actual} actual parts`)
if failures > 0 then
	error(`{failures} check(s) failed`)
end
print("ALL CHECKS PASSED")
