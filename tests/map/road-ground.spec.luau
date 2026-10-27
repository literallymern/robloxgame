--!nocheck
-- needs: roblox-mock
local layout = load("ReplicatedStorage/Shared/Config/MapLayout")
local hf = load("StudioTools/Map/Heightfield").new(layout)
local Details = load("StudioTools/Map/RoadDetails")
local Builder = load("StudioTools/Map/Builders/RoadDetails")
local passed = 0
local function check(ok, message)
	assert(ok, message)
	passed += 1
	print("PASS " .. message)
end
local baseline = Details.new(layout, hf)
local function saved(x, z, allowWater)
	assert(not allowWater, "roadside furniture must stay on dry ground")
	return hf.surface(x, z) - 6, 0
end
local details = Details.new(layout, hf, saved)
local grounded = true
for _, group in { details.lights, details.poles, details.delineators } do
	for _, p in group do
		grounded = grounded and math.abs(p.Y - saved(p.X, p.Z)) < 1e-8
	end
end
for _, rail in details.rails do
	for _, p in rail.Posts do
		grounded = grounded and math.abs(p[2] - saved(p[1], p[3])) < 1e-8
	end
end
check(
	grounded and #details.poles > 10 and #details.lights > 10,
	"lamps, poles, markers and rail feet follow edited saved ground"
)
local function same(a, b)
	if type(a) ~= "table" then
		return a == b
	end
	if type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not same(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end
check(
	same(baseline.signs, details.signs) and same(baseline.markings, details.markings),
	"saved-ground adjustments preserve authored sign text, positions and road markings"
)
local missing = Details.new(layout, hf, function()
	return nil, 0
end)
check(
	#missing.lights == 0
		and #missing.poles == 0
		and #missing.delineators == 0
		and #missing.rails == 0
		and #missing.wires == 0,
	"missing or protected terrain creates no unsupported roadside furniture"
)
check(
	same(baseline.signs, missing.signs) and same(baseline.markings, missing.markings),
	"missing terrain cannot remove signs or road markings"
)
local removed = baseline.poles[baseline.wires[math.ceil(#baseline.wires / 2)][1]]
local function isHole(x, z)
	return math.abs(x - removed.X) < 0.01 and math.abs(z - removed.Z) < 0.01
end
local hole = Details.new(layout, hf, function(x, z)
	return if isHole(x, z) then nil else hf.surface(x, z), 0
end)
local noCrossing = #hole.poles == #baseline.poles - 1 and #hole.wires < #baseline.wires
for _, pair in hole.wires do
	local x, y = hole.poles[pair[1]], hole.poles[pair[2]]
	local matched = false
	for _, old in baseline.wires do
		local a, b = baseline.poles[old[1]], baseline.poles[old[2]]
		if x.X == a.X and x.Z == a.Z and y.X == b.X and y.Z == b.Z then
			matched = true
			break
		end
	end
	noCrossing = noCrossing and matched
end
check(noCrossing, "a missing utility support breaks its wire run instead of wiring across the gap")
local root = Instance.new("Folder")
Builder.build(details, root)
local poleCount, lampCount, railCount = 0, 0, 0
local builtGrounded = true
for _, part in root:GetDescendants() do
	if not part:IsA("BasePart") then
		continue
	end
	local p = part.Position
	if part.Name == "Pole" and part.Parent.Name == "PowerLines" then
		poleCount += 1
		local bottom = p - part.CFrame.RightVector * part.Size.X / 2
		builtGrounded = builtGrounded and math.abs(bottom.Y - (saved(p.X, p.Z) - 2)) < 1e-6
	elseif part.Name == "RailPost" then
		railCount += 1
		builtGrounded = builtGrounded and math.abs(p.Y - part.Size.Y / 2 - (saved(p.X, p.Z) - 1)) < 1e-6
	elseif part.Name == "LampPost" then
		lampCount += 1
	end
end
check(
	builtGrounded and poleCount == #details.poles and railCount > 0,
	"built utility and guardrail supports bury their feet in saved terrain"
)
local aligned, terminals = true, 0
local rails = root.RoadDetails.GuardRails:GetChildren()
for _, terminal in rails do
	if terminal.Name ~= "RailTerminal" then
		continue
	end
	terminals += 1
	local meets = false
	for _, rail in rails do
		if rail.Name ~= "Rail" then
			continue
		end
		local p = rail.CFrame:Inverse() * terminal.Position
		if math.abs(p.X) < 1e-6 and math.abs(p.Y) < 1e-6 and math.abs(p.Z) <= rail.Size.Z / 2 + 1e-6 then
			meets = true
			break
		end
	end
	aligned = aligned and meets
end
check(aligned and terminals == #details.rails * 2, "guardrail terminals meet the actual steel centre on sloping rails")
print(`ALL CHECKS PASSED ({passed} road ground checks)`)
