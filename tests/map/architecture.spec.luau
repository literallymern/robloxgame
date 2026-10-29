--!strict
-- needs: roblox-mock
-- The building overhaul (StudioTools Architecture): builds the Congress, the Hausali, the
-- Central Bank and the Residence against the Roblox stand-in and checks that every window has a
-- room behind it and no partition behind its glass, that every room can be reached from an
-- entrance, that the stairs are walkable, that rooms are furnished and lit, that every working
-- door has a prompt and swings with the server's DoorService, and that each building stays
-- within its part budget. A small plan with a sealed room checks that the reachability test
-- finds such rooms.

local District = load("ReplicatedStorage/Shared/Config/GovernmentDistrict")
local Kit = load("StudioTools/Gundiville/Kit")
local Plan = load("StudioTools/Architecture/Plan")
local Rooms = load("StudioTools/Architecture/Rooms")
local Materials = load("StudioTools/Architecture/Materials")
local DoorService = load("Server/Services/DoorService")

local failures = 0
local function check(name: string, ok: boolean, detail: any?)
	if ok then
		print("PASS", name)
	else
		failures += 1
		print("FAIL", name, if detail ~= nil then tostring(detail) else "")
	end
end

-- Part budgets per building (measured plus a margin) and the least number of rooms. Since the
-- interior overhaul (wall linings, skirting, panelling, chandeliers, radiators) the buildings
-- measure Congress 10,285, Hausali 11,069, Central Bank 4,765 and Residence 3,905 parts with
-- built furniture; with the official interior library they are slightly lighter
-- (tests/map/interior-assets.spec.luau uses the same budgets).
local BUDGET = { Congress = 10700, Hausali = 11500, CentralBank = 5000, Residence = 4200 }
local MIN_ROOMS = { Congress = 70, Hausali = 100, CentralBank = 30, Residence = 16 }
local ORDER = { "Congress", "Hausali", "CentralBank", "Residence" }

type Built = { Model: Model, Report: { [string]: number }, Parts: number }
local built: { [string]: Built } = {}
local taggedDoors = 0

for _, name in ORDER do
	local Builder = load("StudioTools/Gundiville/" .. name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	Kit.resetCount()
	local report = Builder.build(District, folder)
	local model = folder:GetChildren()[1] :: Model
	local parts = Kit.partCount()
	built[name] = { Model = model, Report = report, Parts = parts }

	check(
		`{name}: every window has a room behind it`,
		model:GetAttribute("WindowsWithoutRoom") == 0,
		model:GetAttribute("WindowsWithoutRoom")
	)
	check(
		`{name}: no partition meets a window`,
		model:GetAttribute("WindowsBlocked") == 0,
		model:GetAttribute("WindowsBlocked")
	)
	check(
		`{name}: every room can be reached from an entrance`,
		model:GetAttribute("RoomsUnreachable") == 0,
		model:GetAttribute("RoomsUnreachable")
	)
	check(`{name}: at least {MIN_ROOMS[name]} rooms`, (report.Rooms or 0) >= MIN_ROOMS[name], report.Rooms)
	check(`{name}: within its budget of {BUDGET[name]} parts`, parts <= BUDGET[name], parts)

	local glass, labelled, frosted, washroomGlass = 0, 0, 0, 0
	local doors, prompts, unanchored = 0, 0, 0
	local seats, lights = 0, 0
	local rooms, furnished = 0, 0
	local stairs, steepest, narrowest = 0, 0, math.huge
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and not item.Anchored then
			unanchored += 1
		end
		if item.Name == "WindowGlass" and item:IsDescendantOf(model:FindFirstChild("Facade") :: Instance) then
			glass += 1
			local space = item:GetAttribute("Space")
			if space then
				labelled += 1
				if string.find(space, "WC") or string.find(space, "Bath") then
					washroomGlass += 1
					if item.Transparency < 0.3 then
						frosted += 1
					end
				end
			end
		elseif item:GetAttribute("RoNationDoor") then
			doors += 1
			for _, d in item:GetDescendants() do
				if d:IsA("ProximityPrompt") and d.Name == "DoorPrompt" then
					prompts += 1
				end
			end
		elseif item:IsA("Seat") then
			seats += 1
		elseif item:IsA("PointLight") then
			lights += 1
		elseif item:IsA("Folder") and item:GetAttribute("Kind") then
			local kind = item:GetAttribute("Kind")
			if kind == "Stair" then
				stairs += 1
				local tops: { number } = {}
				for _, step in item:GetDescendants() do
					if
						step:IsA("BasePart")
						and (step.Name == "Step" or step.Name == "Landing" or step.Name == "FloorFinish")
					then
						table.insert(tops, step.CFrame.Position.Y + step.Size.Y / 2)
						if step.Name == "Step" then
							narrowest = math.min(narrowest, math.max(step.Size.X, step.Size.Z))
						end
					end
				end
				table.sort(tops)
				for i = 2, #tops do
					steepest = math.max(steepest, tops[i] - tops[i - 1])
				end
			elseif not item:GetAttribute("Open") and kind ~= "Lift" then
				rooms += 1
				local pieces = 0
				for _, d in item:GetDescendants() do
					if d:IsA("BasePart") and d.Name ~= "FloorFinish" and d.Name ~= "Partition" then
						pieces += 1
					end
				end
				if pieces >= 8 then
					furnished += 1
				end
			end
		end
	end
	taggedDoors += doors
	check(`{name}: every window glass names the room behind it`, glass > 0 and labelled == glass, `{labelled}/{glass}`)
	check(`{name}: washroom windows have frosted glass`, frosted == washroomGlass, `{frosted}/{washroomGlass}`)
	check(`{name}: every working door has a prompt`, doors > 0 and prompts == doors, `{prompts}/{doors}`)
	check(`{name}: everything is anchored when built`, unanchored == 0, unanchored)
	check(`{name}: every room is furnished`, rooms > 0 and furnished == rooms, `{furnished}/{rooms}`)
	check(`{name}: has seats and lights`, seats >= 10 and lights >= 20, `{seats} seats, {lights} lights`)
	check(`{name}: stairs rise at most 1 stud per step`, stairs > 0 and steepest <= 1, steepest)
	check(`{name}: flights are at least 4 studs wide`, stairs > 0 and narrowest >= 4, narrowest)
end

-- Named fittings the game relies on.
local function find(root: Instance, name: string): Instance?
	for _, item in root:GetDescendants() do
		if item.Name == name then
			return item
		end
	end
	return nil
end
local function folderOfKind(root: Instance, kind: string): Instance?
	for _, item in root:GetDescendants() do
		if item:IsA("Folder") and item:GetAttribute("Kind") == kind then
			return item
		end
	end
	return nil
end
local chamber = folderOfKind(built.Congress.Model, "Chamber")
local chamberSeats = 0
if chamber then
	for _, item in chamber:GetDescendants() do
		if item:IsA("Seat") then
			chamberSeats += 1
		end
	end
end
check("Congress: the chamber has 50 seats (47 delegates, 3 presiding)", chamberSeats == 50, chamberSeats)
check("Central Bank: five teller places", built.CentralBank.Report.Tellers == 5, built.CentralBank.Report.Tellers)
local chair = find(built.Residence.Model, "LeadersChair")
check(
	"Residence: the Leader's chair is a seat in the Leader's office",
	chair ~= nil
		and chair:IsA("Seat")
		and folderOfKind(built.Residence.Model, "LeadersOffice") ~= nil
		and chair:IsDescendantOf(folderOfKind(built.Residence.Model, "LeadersOffice") :: Instance)
)
local guardPosts = 0
for _, item in built.Residence.Model:GetChildren() do
	if item.Name == "GuardPost" then
		guardPosts += 1
		check(
			"Residence: guard post has a working door and a chair",
			find(item, "DoorPrompt") ~= nil and find(item, "OfficeChair") ~= nil
		)
	end
end
check("Residence: two guard posts at the gate", guardPosts == 2, guardPosts)

-- DoorService -------------------------------------------------------------------------------
DoorService.start()
check(
	"DoorService: registers every tagged door",
	DoorService.count() == taggedDoors,
	`{DoorService.count()}/{taggedDoors}`
)

local function doorLabelled(root: Instance, label: string): Model?
	for _, item in root:GetDescendants() do
		if item:GetAttribute("RoNationDoor") then
			local prompt = find(item, "DoorPrompt") :: ProximityPrompt?
			if prompt and string.find(prompt.ObjectText, label, 1, true) then
				return item :: Model
			end
		end
	end
	return nil
end
local function turned(a: CFrame, b: CFrame): number
	return math.deg(math.acos(math.clamp(a.LookVector:Dot(b.LookVector), -1, 1)))
end

local officeModel = doorLabelled(built.Residence.Model, "Office of the Leader")
local office = if officeModel then DoorService.get(officeModel) else nil
check("DoorService: the Leader's office has a working double door", office ~= nil and #office.Leaves == 2)
if office then
	local closed = office.Leaves[1].Hinge.CFrame
	local welded, loose = 0, 0
	for _, item in office.Model:GetDescendants() do
		if item:IsA("BasePart") and item:GetAttribute("MovesWithLeaf") then
			local weld = item:FindFirstChildOfClass("WeldConstraint")
			if weld and not item.Anchored then
				welded += 1
			else
				loose += 1
			end
		elseif item:IsA("BasePart") and item.Name == "DoorFrame" and not item.Anchored then
			loose += 1
		end
	end
	check(
		"DoorService: leaf parts are welded to their hinges, frames stay anchored",
		welded > 0 and loose == 0,
		`{welded} welded, {loose} wrong`
	)
	check(
		"DoorService: a closed door starts closed",
		office.Open == false and office.Prompt and office.Prompt.ActionText == "Open"
	)
	local prompt = office.Prompt :: ProximityPrompt
	prompt.Triggered:Fire()
	local opened = office.Leaves[1].Hinge.CFrame
	check(
		"DoorService: the prompt opens the door by about 95 degrees",
		office.Open and math.abs(turned(closed, opened) - 95) < 1,
		turned(closed, opened)
	)
	local a1 = office.Leaves[1].Hinge.CFrame.LookVector
	local a2 = office.Leaves[2].Hinge.CFrame.LookVector
	check("DoorService: the two leaves swing apart", a1:Dot(a2) < -0.9, a1:Dot(a2))
	check("DoorService: the prompt then offers to close", prompt.ActionText == "Close")
	prompt.Triggered:Fire()
	check("DoorService: a second trigger while it moves is ignored", office.Open == true)
	office.Last = -math.huge
	prompt.Triggered:Fire()
	check(
		"DoorService: the next trigger closes it again",
		office.Open == false and turned(closed, office.Leaves[1].Hinge.CFrame) < 0.01
	)
end
local portalModel = doorLabelled(built.Residence.Model, "Residence")
local portal = if portalModel then DoorService.get(portalModel) else nil
check("DoorService: the villa portal stands open at start", portal ~= nil and portal.Open == true)
local boothModel = doorLabelled(built.Residence.Model, "Guard Post")
check("DoorService: guard post doors work", boothModel ~= nil and DoorService.get(boothModel :: Model) ~= nil)

-- A sealed room is found -------------------------------------------------------------------
local probe = Instance.new("Model")
probe.Parent = workspace
Kit.resetCount()
local plan = Plan.new({
	Model = probe,
	Building = "Probe",
	Footprints = { Plan.rect(0, 40, 0, 20) },
	Levels = { 0, 10, 20 },
	Spaces = {
		{ Name = "Hall", Kind = "Hall", Rect = Plan.rect(0, 20, 0, 20), Storey = 0, Open = true },
		{ Name = "Office", Kind = "Office", Rect = Plan.rect(20, 30, 0, 20), Storey = 0 },
		{ Name = "Sealed", Kind = "Storage", Rect = Plan.rect(30, 40, 0, 20), Storey = 0, Doors = {} },
	},
	Style = { Partition = Materials.Wall.White, Door = { Leaf = Materials.Wood.Oak } },
})
Plan.addWindow(
	plan,
	{ Kind = "Door", Storey = 0, Space = plan.Spaces[1], Edge = "MinX", From = 8, To = 12, Bottom = 0, Top = 8 }
)
local lost = Plan.unreachable(plan)
check("reachability: a room without a door is found", #lost == 1 and lost[1].Name == "Sealed", #lost)
Plan.build(plan, Rooms.furnish)
check(
	"reachability: the plan reports it",
	probe:GetAttribute("RoomsUnreachable") == 1,
	probe:GetAttribute("RoomsUnreachable")
)

local total = 0
for _, name in ORDER do
	total += built[name].Parts
end
print(
	`INFO parts: Congress {built.Congress.Parts}, Hausali {built.Hausali.Parts}, Central Bank {built.CentralBank.Parts}, Residence {built.Residence.Parts}, total {total}`
)

if failures == 0 then
	print("ALL CHECKS PASSED")
else
	print(`{failures} CHECKS FAILED`)
end
