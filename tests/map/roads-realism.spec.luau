--!strict
-- needs: roblox-mock
-- Actual road/bridge builders: driving surfaces remain on their original profile, roadside
-- layers stay clear of traffic, and bridge loads reach supported foundations.

local layout = load("ReplicatedStorage/Shared/Config/MapLayout")
local hf = load("StudioTools/Map/Heightfield").new(layout)
local Roads = load("StudioTools/Map/Builders/Roads")
local Bridges = load("StudioTools/Map/Builders/Bridges")
local Details = load("StudioTools/Map/RoadDetails")
local DetailsBuilder = load("StudioTools/Map/Builders/RoadDetails")
local root = Instance.new("Folder")
root.Name = "TestMap"
root.Parent = workspace
local failures = 0
local function check(name: string, okay: boolean, detail: string?)
	if okay then
		print("PASS", name)
	else
		failures += 1
		print("FAIL", name, detail or "")
	end
end
Roads.build(hf, layout, root)
Bridges.build(hf, root)
DetailsBuilder.build(Details.new(layout, hf), root)
local shoulders, patches, worstShoulder, worstSurface, badCollision = 0, 0, 0, 0, 0
local roadById = {}
for _, road in hf.roads.roads do
	roadById[road.Id] = road
end
for _, roadFolder in root.Roads:GetChildren() do
	for _, item in roadFolder:GetDescendants() do
		if not item:IsA("BasePart") then
			continue
		end
		local top = item.CFrame.Position + item.CFrame.UpVector * item.Size.Y / 2
		local edge, y = hf.roads.nearest(top.X, top.Z)
		if item.Name == "GravelShoulder" then
			shoulders += 1
			if not edge or edge < 0.65 or edge > 1.1 then
				worstShoulder += 1
			end
			check(`shoulder meets the road bed {shoulders}`, math.abs(top.Y - y + 0.08) < 0.25)
		elseif string.match(item.Name, "^AsphaltRepair %d+$") then
			patches += 1
			if item.CanCollide or item.CanQuery or item.CanTouch or item.CastShadow then
				badCollision += 1
			end
			local road = roadById[roadFolder.Name]
			local run = road.runs[tonumber(string.match(item.Name, "%d+$"))]
			local f, l = run.First, run.Last
			local dx, dz = road.line.xs[l] - road.line.xs[f], road.line.zs[l] - road.line.zs[f]
			local t = ((top.X - road.line.xs[f]) * dx + (top.Z - road.line.zs[f]) * dz) / (dx * dx + dz * dz)
			local surfaceY = road.profile[f] + (road.profile[l] - road.profile[f]) * t
			check(`repair below marking level {patches}`, math.abs(top.Y - surfaceY - 0.025) < 0.001)
		elseif not string.find(item.Name, "joint") then
			worstSurface = math.max(worstSurface, math.abs(top.Y - y))
		end
	end
end
check("rural gravel shoulders generated within part budget", shoulders > 100 and shoulders < 850, tostring(shoulders))
check("shoulders outside the carriageway", worstShoulder == 0, tostring(worstShoulder))
check("asphalt repairs sparse and noncolliding", patches > 0 and patches < 100 and badCollision == 0, tostring(patches))
check("road surface profile preserved", worstSurface < 0.3, tostring(worstSurface))
local piers, abutments, footings, rails, deckSurfaces, badSupport, badRail = 0, 0, 0, 0, 0, 0, 0
for _, item in root.Bridges:GetDescendants() do
	if not item:IsA("BasePart") then
		continue
	end
	local p = item.Position
	local edge, roadY = hf.roads.nearest(p.X, p.Z)
	local top = item.CFrame.Position + item.CFrame.UpVector * item.Size.Y / 2
	if item.Name == "PierCap" then
		piers += 1
		if top.Y > roadY - 2.8 then
			badSupport += 1
		end
	elseif item.Name == "Abutment" then
		abutments += 1
	elseif string.find(item.Name, "Footing") then
		footings += 1
	elseif item.Name == "ParapetRail" then
		rails += 1
		if not edge or edge < 0.3 then
			badRail += 1
		end
	elseif item.Material == Enum.Material.Asphalt then
		deckSurfaces += 1
		check(`bridge wearing course on road profile {deckSurfaces}`, math.abs(top.Y - roadY) < 0.3)
	end
end
check("all five bridges have two abutments", abutments == 10, tostring(abutments))
check(
	"long spans have pier caps and foundations",
	piers >= 6 and footings == piers + abutments,
	`{piers} caps, {footings} footings`
)
check("supports terminate below deck", badSupport == 0)
check("open parapets outside original driving width", rails >= 20 and badRail == 0, `{rails} rails, {badRail} inside`)
check("asphalt bridge deck surfaces generated", deckSurfaces >= 5)
local streetlights, lamps = 0, 0
for _, item in root.RoadDetails.StreetLights:GetDescendants() do
	if item:GetAttribute("RoNationStreetLight") then
		streetlights += 1
		check(`streetlight daytime baseline {streetlights}`, item:IsA("Light") and item.Enabled == false)
	elseif item:GetAttribute("RoNationLamp") then
		lamps += 1
	end
end
check(
	"all lamps can participate in automatic night cycle",
	streetlights > 0 and streetlights == lamps,
	`{streetlights} lights, {lamps} lamps`
)
print(`INFO {shoulders} shoulder parts, {patches} repair parts; {piers} pier bents, {rails} parapet rails`)
if failures > 0 then
	error(`{failures} road realism check(s) failed`)
end
print("ALL CHECKS PASSED")
