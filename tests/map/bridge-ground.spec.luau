--!nocheck
-- needs: roblox-mock
-- Actual bridge geometry on saved terrain that differs from the generator.
local layout = load("ReplicatedStorage/Shared/Config/MapLayout")
local hf = load("StudioTools/Map/Heightfield").new(layout)
local Bridges = load("StudioTools/Map/Builders/Bridges")
local passed = 0
local function check(ok, message)
	assert(ok, message)
	passed += 1
	print("PASS " .. message)
end
local function ground(x, z)
	return -20 + x * 0.001 - z * 0.002, 0.003
end
local original, saved = Instance.new("Folder"), Instance.new("Folder")
Bridges.build(hf, original)
local bedSamples, drySamples = 0, 0
local built = Bridges.build(hf, saved, function(x, z, allowWater)
	if allowWater then
		bedSamples += 1
	else
		drySamples += 1
	end
	return ground(x, z)
end)
check(
	#saved.Bridges:GetChildren() == 5 and bedSamples > 100 and drySamples > 0,
	"all five bridges sample saved beds and dry banks"
)
local footings, walls, rocks, parts = 0, 0, 0, 0
local buried, wallsGrounded, rocksGrounded, attributed = true, true, true, true
for _, model in saved.Bridges:GetChildren() do
	attributed = attributed and model:GetAttribute("FoundationGroundSource") == "SavedTerrain"
	for _, part in model:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		parts += 1
		if part.Name == "PierFooting" or part.Name == "AbutmentFooting" then
			footings += 1
			for _, x in { -1, 1 } do
				for _, z in { -1, 1 } do
					local p = part.CFrame * Vector3.new(x * part.Size.X / 2, part.Size.Y / 2, z * part.Size.Z / 2)
					buried = buried and p.Y < ground(p.X, p.Z)
				end
			end
		elseif part.Name == "WingWall" then
			walls += 1
			for _, z in { -1, 0, 1 } do
				local p = part.CFrame * Vector3.new(0, -part.Size.Y / 2, z * part.Size.Z / 2)
				wallsGrounded = wallsGrounded and p.Y < ground(p.X, p.Z)
			end
		elseif part.Name == "AbutmentRiprap" then
			rocks += 1
			local p = part.Position
			rocksGrounded = rocksGrounded and math.abs(part:GetAttribute("GroundY") - ground(p.X, p.Z)) < 1e-6
		end
	end
end
check(footings > 10 and buried, "all pier and abutment foundations are buried across their saved-ground footprints")
check(walls == 20 and wallsGrounded, "all wing walls extend to lowered saved banks")
check(rocks > 20 and rocksGrounded, "bank protection follows saved dry ground")
check(attributed and parts == built, "bridge report counts actual parts and identifies saved foundation heights")
local function carriageway(root)
	local result = {}
	for _, part in root:GetDescendants() do
		if
			part:IsA("BasePart")
			and (part.Material == Enum.Material.Asphalt or string.find(part.Name, "Parapet", 1, true))
		then
			table.insert(result, part)
		end
	end
	return result
end
local a, b = carriageway(original), carriageway(saved)
local identical = #a == #b and #a > 10
for index, part in a do
	local other = b[index]
	identical = identical
		and part.Name == other.Name
		and (part.Position - other.Position).Magnitude < 1e-8
		and (part.Size - other.Size).Magnitude < 1e-8
		and (part.CFrame.UpVector - other.CFrame.UpVector).Magnitude < 1e-8
end
check(identical, "saved-bank adjustments preserve the driving surface and safety barrier alignment")
local underwater = Instance.new("Folder")
Bridges.build(hf, underwater, function(x, z, allowWater)
	return if allowWater then ground(x, z) else nil, 0
end)
local noDryDecoration = true
for _, part in underwater:GetDescendants() do
	noDryDecoration = noDryDecoration and part.Name ~= "AbutmentRiprap" and part.Name ~= "ApproachDrainInvert"
end
check(
	noDryDecoration and #underwater.Bridges:GetChildren() == 5,
	"underwater banks omit dry decoration while retaining bed-supported structures"
)
for _, invalid in { "missing", "nonfinite" } do
	local staging = Instance.new("Folder")
	local okay, err = pcall(Bridges.build, hf, staging, function()
		return if invalid == "missing" then nil else 0 / 0, 0
	end)
	check(
		not okay and string.find(tostring(err), "no usable saved ground", 1, true) ~= nil,
		invalid .. " structural terrain stops bridge staging with a ground diagnostic"
	)
	check(#staging.Bridges:GetChildren() == 1, invalid .. " partial bridge remains owned by disposable staging")
	staging:Destroy()
end
print(`ALL CHECKS PASSED ({passed} bridge ground checks)`)
