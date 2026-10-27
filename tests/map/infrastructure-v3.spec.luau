--!strict
-- needs: roblox-mock
-- Inspect the generated detail geometry, not a duplicate of the placement algorithm.
local layout = load("ReplicatedStorage/Shared/Config/MapLayout")
local hf = load("StudioTools/Map/Heightfield").new(layout)
local Bridges = load("StudioTools/Map/Builders/Bridges")
local Details = load("StudioTools/Map/RoadDetails").new(layout, hf)
local DetailsBuilder = load("StudioTools/Map/Builders/RoadDetails")
local root = Instance.new("Folder")
local failures = 0
local function check(name: string, okay: boolean, detail: string?)
	print(if okay then "PASS" else "FAIL", name, detail or "")
	if not okay then
		failures += 1
	end
end

local bridgeCount = Bridges.build(hf, root)
local detailCounts = DetailsBuilder.build(Details, root)
local stoneCount, drainCount, terminalCount, insulatorCount = 0, 0, 0, 0
local grounded, outsideTraffic, cosmeticSafe, drainFalls = true, true, true, true
local reportedBridges, reportedPower, reportedRails = 0, 0, 0
for _, item in root:GetDescendants() do
	if not item:IsA("BasePart") then
		continue
	end
	if item.Parent:IsA("Model") and item.Parent.Parent == root.Bridges then
		reportedBridges += 1
	end
	if item.Parent == root.RoadDetails.PowerLines then
		reportedPower += 1
	end
	if item.Parent == root.RoadDetails.GuardRails then
		reportedRails += 1
	end
	local p = item.CFrame.Position
	if item.Name == "AbutmentRiprap" then
		stoneCount += 1
		local actual = hf.surface(p.X, p.Z)
		grounded = grounded
			and math.abs(item:GetAttribute("GroundY") - actual) < 1e-6
			and p.Y - actual > 0
			and p.Y - actual < item.Size.Y / 4
	elseif item.Name == "ApproachDrainInvert" then
		drainCount += 1
		local top = p + item.CFrame.UpVector * item.Size.Y / 2
		local a = top - item.CFrame.LookVector * item.Size.Z / 2
		local b = top + item.CFrame.LookVector * item.Size.Z / 2
		drainFalls = drainFalls and math.abs(a.Y - b.Y) >= 1.1 and math.abs(a.Y - b.Y) <= 8
		for _, endpoint in { a, b } do
			for _, side in { -1, 1 } do
				local corner = endpoint + item.CFrame.RightVector * item.Size.X / 2 * side
				local edge = hf.roads.nearest(corner.X, corner.Z)
				outsideTraffic = outsideTraffic and edge ~= nil and edge > 0.5
			end
		end
	elseif item.Name == "RailTerminal" then
		terminalCount += 1
	elseif item.Name == "LineInsulator" then
		insulatorCount += 1
	end
	if
		item.Name == "AbutmentRiprap"
		or string.match(item.Name, "^ApproachDrain")
		or item.Name == "RailTerminal"
		or item.Name == "LineInsulator"
	then
		cosmeticSafe = cosmeticSafe and not item.CanCollide and not item.CanQuery and not item.CanTouch
		local edge = hf.roads.nearest(p.X, p.Z)
		outsideTraffic = outsideTraffic and edge ~= nil and edge > 0.5
	end
end
check("wing-wall riprap is grounded and partly buried", stoneCount > 20 and grounded, `{stoneCount} rocks`)
check("approach drains only run downhill to the bank", drainCount > 0 and drainFalls, `{drainCount} drains`)
check("new infrastructure remains outside the driving width", outsideTraffic)
check("cosmetic infrastructure never blocks traffic, queries or touches", cosmeticSafe)
check("both ends of every guardrail run are closed", terminalCount == #Details.rails * 2)
check("each utility crossarm has two ceramic insulators", insulatorCount == #Details.poles * 2)

local wiresConnected = true
for _, arm in root.RoadDetails.PowerLines:GetChildren() do
	if arm.Name ~= "CrossArm" then
		continue
	end
	for _, name in { "WireA", "WireB" } do
		local attachment = arm:FindFirstChild(name)
		local point = arm.CFrame * attachment.CFrame.Position
		local closest = math.huge
		for _, insulator in root.RoadDetails.PowerLines:GetChildren() do
			if insulator.Name ~= "LineInsulator" then
				continue
			end
			local endpoint = insulator.CFrame.Position + insulator.CFrame.RightVector * insulator.Size.X / 2
			closest = math.min(closest, (point - endpoint).Magnitude)
		end
		wiresConnected = wiresConnected and closest < 1e-6
	end
end
check("wire attachments meet the insulator tops", wiresConnected)
check("bridge builder reports all generated parts", bridgeCount == reportedBridges, `{bridgeCount}/{reportedBridges}`)
check(
	"utility and rail builders report all generated parts",
	detailCounts.PowerLines == reportedPower and detailCounts.GuardRails == reportedRails
)
check(
	"added infrastructure stays within a 500-part budget",
	stoneCount + drainCount * 3 + terminalCount + insulatorCount <= 500
)

local again = Instance.new("Folder")
local bridgeAgain = Bridges.build(hf, again)
local detailAgain = DetailsBuilder.build(Details, again)
check(
	"identical inputs reproduce the same infrastructure budget",
	bridgeAgain == bridgeCount
		and detailAgain.PowerLines == detailCounts.PowerLines
		and detailAgain.GuardRails == detailCounts.GuardRails
)
print(
	`INFO {stoneCount} grounded riprap rocks, {drainCount} drainage chutes, {terminalCount} terminals, {insulatorCount} insulators`
)
if failures > 0 then
	error(`{failures} infrastructure checks failed`)
end
print("ALL CHECKS PASSED")
