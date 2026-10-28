--!strict
-- needs: roblox-mock
-- Milestone 3: the Gundiville government district. Checks the plan (GovernmentDistrict config
-- against MapLayout), then runs the real StudioTools.BuildGundiville entry point against the
-- Roblox stand-in and inspects what it built: budget, entrances, streets, flags, lamps, the
-- statue, reruns, the statue finishes, the avatar fallbacks and removal.

local MapLayout = load("ReplicatedStorage/Shared/Config/MapLayout")
local District = load("ReplicatedStorage/Shared/Config/GovernmentDistrict")
local Places = load("StudioTools/Map/Builders/Places")
local BuildGundiville = load("StudioTools/BuildGundiville")

local failures = 0
local function check(name: string, ok: boolean, detail: any?)
	if ok then
		print("PASS", name)
	else
		failures += 1
		print("FAIL", name, if detail ~= nil then tostring(detail) else "")
	end
end

type Rect = { MinX: number, MaxX: number, MinZ: number, MaxZ: number }
local function overlaps(a: Rect, b: Rect, margin: number?): boolean
	local m = margin or 0
	return a.MinX < b.MaxX - m and b.MinX < a.MaxX - m and a.MinZ < b.MaxZ - m and b.MinZ < a.MaxZ - m
end
local function inside(a: Rect, b: Rect): boolean
	return a.MinX >= b.MinX and a.MaxX <= b.MaxX and a.MinZ >= b.MinZ and a.MaxZ <= b.MaxZ
end
local function contains(r: Rect, x: number, z: number): boolean
	return x >= r.MinX and x <= r.MaxX and z >= r.MinZ and z <= r.MaxZ
end

-- 1. The plan -------------------------------------------------------------------------------------
local city: Rect = MapLayout.Places[1].Rect
check("Gundiville is the first place", MapLayout.Places[1].Id == "Gundiville")
check("district ground matches Gundiville", District.GroundY == MapLayout.Places[1].GroundY)
local placeholders: { [string]: any } = {}
for _, block in MapLayout.GundivillePlaceholders do
	placeholders[block.Id] = block
end
local buildings = {
	Congress = District.Congress.Rect,
	Hausali = District.Hausali.Rect,
	CentralBank = District.CentralBank.Rect,
	Residence = District.Residence.Rect,
	Square = District.Square.Rect,
}
for id, r in buildings do
	local p = placeholders[id]
	check(
		`{id} keeps the footprint of the map plan`,
		p ~= nil and p.Rect.MinX == r.MinX and p.Rect.MaxX == r.MaxX and p.Rect.MinZ == r.MinZ and p.Rect.MaxZ == r.MaxZ
	)
	check(`{id} lies inside Gundiville`, inside(r, city))
end
for _, id in District.Replaces do
	check(`replaced placeholder {id} exists in MapLayout`, placeholders[id] ~= nil)
end
check("Congress body inside its plot", inside(District.Congress.Body, District.Congress.Rect))
check("Hausali body inside its plot", inside(District.Hausali.Body, District.Hausali.Rect))
check("bank body inside its plot", inside(District.CentralBank.Body, District.CentralBank.Rect))
check("villa inside the residence walls", inside(District.Residence.Villa, District.Residence.Rect))
check("statue platform on the square", inside(District.Square.StatuePlatform, District.Square.Rect))
check(
	"statue on the ceremonial axis in its platform",
	District.Statue.Position[1] == 0
		and contains(District.Square.StatuePlatform, District.Statue.Position[1], District.Statue.Position[2])
)
check("statue faces the Congress (north)", District.Statue.Facing == "North")
check("statue is the Owner's avatar", District.Statue.UserId == 2595858454)

local streetRects: { Rect } = {}
local carriageways: { Rect } = {}
for _, street in District.Streets do
	table.insert(streetRects, street.Rect)
	check(`{street.Id} inside Gundiville`, inside(street.Rect, city))
	for _, c in street.Carriageways do
		table.insert(carriageways, c)
	end
end
local function streetOverlap(r: Rect): string?
	for i, s in streetRects do
		if overlaps(r, s) then
			return District.Streets[i].Id
		end
	end
	return nil
end
for id, r in buildings do
	local hit = streetOverlap(r)
	check(`{id} stays off the streets`, hit == nil, hit)
end
-- Other planned buildings and the property plots stay clear of the district.
for _, block in MapLayout.GundivillePlaceholders do
	if not table.find(District.Replaces, block.Id) then
		local hit = streetOverlap(block.Rect)
		for id, r in buildings do
			if overlaps(block.Rect, r) then
				hit = id
			end
		end
		check(`{block.Id} plot is clear of the district`, hit == nil, hit)
	end
end
for _, property in MapLayout.Properties do
	if property.City == "Gundiville" then
		local hit = streetOverlap(property.Rect)
		for id, r in buildings do
			if overlaps(property.Rect, r) then
				hit = id
			end
		end
		check(`property {property.Name} is clear of the district`, hit == nil, hit)
	end
end
-- The avenue meets N5 at the south edge, the main street meets N4 at the east edge.
local function roadStart(id: string): { number }?
	for _, road in MapLayout.Roads do
		if road.Id == id then
			return road.Points[1]
		end
	end
	return nil
end
local function onCarriageway(x: number, z: number): boolean
	for _, c in carriageways do
		if contains(c, x, z) then
			return true
		end
	end
	return false
end
local n4, n5 = roadStart("N4"), roadStart("N5")
check(
	"N4 starts at the east edge of the main street",
	n4 ~= nil and onCarriageway(n4[1] - 1, n4[2]),
	n4 and `{n4[1]},{n4[2]}`
)
check(
	"N5 starts at the south end of the avenue",
	n5 ~= nil and onCarriageway(n5[1] + 13, n5[2] - 1),
	n5 and `{n5[1]},{n5[2]}`
)
check("the avenue carriageways continue to the square", onCarriageway(-26, 14) and onCarriageway(26, 14))
check("the side streets connect to the main street", onCarriageway(-165, 110) and onCarriageway(165, 110))
check("North Street reaches the residence gate", onCarriageway(District.Residence.Gate, -520))

-- 2. The build --------------------------------------------------------------------------------------
local mockWorkspace: any = workspace
local stats: any = MockStats
local map = Instance.new("Folder")
map.Name = "Map"
map.Parent = mockWorkspace
-- A generated placeholder folder as BuildMap leaves it.
local placeholderFolder = Instance.new("Folder")
placeholderFolder.Name = "GundivillePlaceholders"
placeholderFolder:SetAttribute("GeneratedBy", "BuildMap")
placeholderFolder.Parent = map
for _, block in MapLayout.GundivillePlaceholders do
	Places.placeholder(block, placeholderFolder, District.GroundY)
end
check("no replacement before the district exists", next(Places.replacedByDistrict(map)) == nil)

-- Saved terrain exactly as planned: flat at the Gundiville ground, so nothing is raised.
stats.groundSurface = function(_x: number, _z: number): (number, number, number?)
	return District.GroundY, 0, nil
end
local partsBefore = stats.parts
local started = os.clock()
local report = BuildGundiville.run()
print(string.format("INFO district build took %.2f s here", os.clock() - started))
check("build returned a report", report ~= nil)
local folder = map:FindFirstChild("GovernmentDistrict")
check("district folder built", folder ~= nil)
assert(report and folder, "the district was not built")
check("district folder is marked BuildGundiville", folder:GetAttribute("GeneratedBy") == "BuildGundiville")
check("district version recorded", folder:GetAttribute("DistrictVersion") == District.Version)
check(
	"terrain as planned: district not raised, no ramps",
	report.Lift == 0 and folder:GetAttribute("GroundLift") == 0 and report.Streets.Ramps == 0,
	`{report.Lift}, {report.Streets.Ramps} ramps`
)
check("one undo step committed", stats.lastRecording == "Commit")

local parts: { any } = {}
local seats, buildMapMarks, unanchored = 0, 0, 0
for _, item in folder:GetDescendants() do
	if item:IsA("BasePart") then
		table.insert(parts, item)
		if not item.Anchored then
			unanchored += 1
		end
	end
	if item:IsA("Seat") then
		seats += 1
	end
	if item:GetAttribute("GeneratedBy") == "BuildMap" then
		buildMapMarks += 1
	end
end
local summary = {}
for name, n in report.PartsBy do
	table.insert(summary, `{name} {n}`)
end
table.sort(summary)
print(`INFO {#parts} parts: {table.concat(summary, ", ")}`)
check("part counter matches the parts built", report.Parts == #parts, `{report.Parts} vs {#parts}`)
check(`within the district budget of {District.MaxParts}`, #parts <= District.MaxParts, #parts)
check("all parts anchored", unanchored == 0, unanchored)
check("nothing inside carries the BuildMap mark (terrain refresh protects it)", buildMapMarks == 0, buildMapMarks)
check("parts were created by this build", stats.parts - partsBefore >= #parts)

-- Placeholders: replaced ones gone, others kept, BuildMap would skip the replaced ones.
for _, block in MapLayout.GundivillePlaceholders do
	local present = placeholderFolder:FindFirstChild(block.Id) ~= nil
	if table.find(District.Replaces, block.Id) then
		check(`placeholder {block.Id} removed`, not present)
	else
		check(`placeholder {block.Id} kept`, present)
	end
end
local replaced = Places.replacedByDistrict(map)
local replacedCount = 0
for _ in replaced do
	replacedCount += 1
end
check("BuildMap skips the replaced placeholders", replacedCount == #District.Replaces)

-- Buildings: models, heights, Congress tallest, flags and emblems on government buildings.
local models = {
	Congress = folder:FindFirstChild("GeneralPeoplesCongress"),
	Hausali = folder:FindFirstChild("Hausali"),
	CentralBank = folder:FindFirstChild("CentralBank"),
	Residence = folder:FindFirstChild("LeadersResidence"),
	Statue = folder:FindFirstChild("LeaderStatue"),
}
local G = District.GroundY
local function topOf(model: any): number
	local top = -math.huge
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item.Transparency < 1 then
			top = math.max(top, item.Position.Y + item.Size.Y / 2)
		end
	end
	return top - G
end
local heights = {}
for name, model in models do
	check(`{name} built`, model ~= nil)
	if model then
		heights[name] = topOf(model)
	end
end
print(
	string.format(
		"INFO heights above ground: Congress %.0f, Hausali %.0f, bank %.0f, residence %.0f, statue %.0f",
		heights.Congress or 0,
		heights.Hausali or 0,
		heights.CentralBank or 0,
		heights.Residence or 0,
		heights.Statue or 0
	)
)
for name, h in heights do
	if name ~= "Congress" then
		check(`Congress is taller than the {name}`, (heights.Congress or 0) > h + 10, `{heights.Congress} vs {h}`)
	end
end
local function count(model: any, attribute: string): number
	local n = 0
	for _, item in model:GetDescendants() do
		if item:GetAttribute(attribute) == true then
			n += 1
		end
	end
	return n
end
for _, name in { "Congress", "Hausali", "CentralBank", "Residence" } do
	local model = models[name]
	if model then
		check(`{name} flies the national flag`, count(model, "NationalFlag") >= 2, count(model, "NationalFlag"))
		check(`{name} shows the national emblem`, count(model, "NationalEmblem") >= 1)
	end
end
local Assets = load("ReplicatedStorage/Shared/Config/Assets")
local flagImages, emblemImages, otherImages = 0, 0, 0
local avatar = folder:FindFirstChild("LeaderStatue"):FindFirstChild("Figure")
for _, item in folder:GetDescendants() do
	if item:IsA("Decal") and not item:IsDescendantOf(avatar) then
		if item.Texture == Assets.Images.Flag then
			flagImages += 1
		elseif item.Texture == Assets.Images.Emblem then
			emblemImages += 1
		else
			otherImages += 1
		end
	end
end
local mirrored = 0
for _, item in folder:GetDescendants() do
	if item:IsA("ImageLabel") and item.Image == Assets.Images.Flag then
		local size, offset = item.ImageRectSize, item.ImageRectOffset
		if size.X == -1024 and size.Y == 609 and offset.X == 1024 and item.Parent.Face == Enum.NormalId.Back then
			mirrored += 1
		end
	end
end
check("flags use the uploaded flag image", flagImages == count(folder, "NationalFlag"), flagImages)
check("flag backs show the mirrored flag", mirrored == flagImages, mirrored)
check("emblems use the uploaded emblem image", emblemImages == count(folder, "NationalEmblem"), emblemImages)
check("no other images (besides the avatar's face)", otherImages == 0, otherImages)
check(
	"Square has a row of flags",
	count(folder:FindFirstChild("Square"), "NationalFlag") == #District.Square.FlagpolesX
)

-- Inscriptions.
local texts: { [string]: boolean } = {}
for _, item in folder:GetDescendants() do
	if item:IsA("TextLabel") then
		texts[item.Text] = true
	end
end
for _, text in
	{
		"GENERAL PEOPLE'S CONGRESS",
		"HAUSALI",
		"CENTRAL BANK",
		"RESIDENCE OF THE",
		"DR. JUSTIN WACHMANN",
		"Avenue du 12 Mai",
	}
do
	check(`inscription "{text}"`, texts[text] == true)
end

-- Seats: the assembly chamber, offices and benches.
local chamberSeats = 0
local function folderOfKind(root: Instance?, kind: string): Instance?
	if not root then
		return nil
	end
	for _, item in root:GetDescendants() do
		if item:IsA("Folder") and item:GetAttribute("Kind") == kind then
			return item
		end
	end
	return nil
end
local chamber = folderOfKind(models.Congress, "Chamber")
if chamber then
	for _, item in chamber:GetDescendants() do
		if item:IsA("Seat") and item.Name == "Seat" then
			chamberSeats += 1
		end
	end
end
check("assembly chamber has at least 40 seats", chamberSeats >= 40, chamberSeats)
local office = folderOfKind(models.Residence, "LeadersOffice")
check("Leader's chair in the office", office ~= nil and office:FindFirstChild("LeadersChair", true) ~= nil)
check("teller chairs in the bank", report.CentralBank.Tellers == 5)
print(`INFO {seats} seats in total, {chamberSeats} in the chamber`)

-- Lamps: switched by the environment controller at night (same attributes as the road lights).
local lamps, lampsWithLight, lightsOn = 0, 0, 0
for _, item in folder:GetDescendants() do
	if item:IsA("BasePart") and item:GetAttribute("RoNationLamp") == true then
		lamps += 1
		for _, child in item:GetChildren() do
			if child:IsA("Light") and child:GetAttribute("RoNationStreetLight") == true then
				lampsWithLight += 1
				if child.Enabled then
					lightsOn += 1
				end
			end
		end
	end
end
check("street lamps built", lamps >= 30, lamps)
check("every lamp carries a switched light", lampsWithLight == lamps, `{lampsWithLight} of {lamps}`)
check("lamps start switched off (the environment controller turns them on)", lightsOn == 0, lightsOn)

-- Collision probes: entrances and rooms must be free; walls must stop at the streets.
type Probe = { Name: string, Point: Vector3 }
local W = G + District.WalkTop
local probes: { Probe } = {
	{ Name = "Congress steps", Point = Vector3.new(0, W + 6, -275) },
	{ Name = "Congress portal", Point = Vector3.new(0, W + 4 + 3, District.Congress.Body.MaxZ - 1) },
	{ Name = "Congress entrance hall", Point = Vector3.new(0, W + 4 + 3, -330) },
	{ Name = "Congress chamber door", Point = Vector3.new(0, W + 4 + 3, District.Congress.Chamber.MaxZ + 1) },
	{ Name = "Congress chamber floor", Point = Vector3.new(0, W + 4 + 3, -400) },
	{ Name = "Hausali portal", Point = Vector3.new(189, W + 1.6 + 3, -160) },
	{ Name = "Hausali lobby", Point = Vector3.new(212, W + 1.6 + 3, -160) },
	{ Name = "Hausali lobby side", Point = Vector3.new(210, W + 1.6 + 3, -180) },
	{ Name = "bank portico", Point = Vector3.new(-194, W + 3 + 3, -155) },
	{ Name = "bank portal", Point = Vector3.new(-199.25, W + 3 + 3, -155) },
	{ Name = "banking hall", Point = Vector3.new(-230, W + 3 + 3, -155) },
	{ Name = "residence gate", Point = Vector3.new(580, W + 3, -561) },
	{ Name = "residence drive", Point = Vector3.new(580, W + 3, -600) },
	{ Name = "villa portal", Point = Vector3.new(580, W + 2 + 3, -691) },
	{ Name = "villa hall", Point = Vector3.new(580, W + 2 + 3, -705) },
	{ Name = "Leader's office door", Point = Vector3.new(600.5, W + 2 + 3, -701) },
	{ Name = "Leader's office", Point = Vector3.new(612, W + 2 + 3, -712) },
	{ Name = "avenue south end", Point = Vector3.new(-26, W + 3, 880) },
	{ Name = "main street east end", Point = Vector3.new(880, W + 3, 115) },
	{ Name = "square parade ground", Point = Vector3.new(0, W + 3, -60) },
}
-- World-aligned footprint of a (possibly rotated) part.
local function footprint(part: any): (Rect, number)
	local f, s = part.CFrame, part.Size
	local r, u, l = f.RightVector, f.UpVector, f.LookVector
	local hx = (math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z) / 2
	local hy = (math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z) / 2
	local hz = (math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z) / 2
	local p = f.Position
	return { MinX = p.X - hx, MaxX = p.X + hx, MinZ = p.Z - hz, MaxZ = p.Z + hz }, p.Y + hy
end
local function solidAt(point: Vector3): string?
	for _, part in parts do
		if part.CanCollide and part.Transparency < 1 then
			local p = part.CFrame:PointToObjectSpace(point)
			local s = part.Size / 2
			if math.abs(p.X) < s.X and math.abs(p.Y) < s.Y and math.abs(p.Z) < s.Z then
				return `{part.Name} in {part.Parent and part.Parent.Name}`
			end
		end
	end
	return nil
end
for _, probe in probes do
	local hit = solidAt(probe.Point)
	check(`free to walk: {probe.Name}`, hit == nil, hit)
end
local roadTop = G + District.RoadTop
local streetsFolder = folder:FindFirstChild("Streets")
local blocking = {}
for _, part in parts do
	if part.CanCollide and not part:IsDescendantOf(streetsFolder) then
		local r, top = footprint(part)
		if top > roadTop + 0.2 then
			for _, c in carriageways do
				if overlaps(r, c, 0.05) then
					table.insert(blocking, `{part.Name} in {part.Parent and part.Parent.Name}`)
					break
				end
			end
		end
	end
end
check("no building part stands on a carriageway", #blocking == 0, table.concat(blocking, ", "))

-- Streets: asphalt pieces do not overlap; sidewalks do not overlap asphalt.
local asphalt, walks = {}, {}
for _, part in streetsFolder:GetChildren() do
	if part:IsA("BasePart") then
		local r = footprint(part)
		if part.Name == "Asphalt" then
			table.insert(asphalt, r)
		elseif part.Name == "Sidewalk" then
			table.insert(walks, r)
		end
	end
end
local asphaltOverlaps, walkOverlaps = 0, 0
for i, a in asphalt do
	for j = i + 1, #asphalt do
		if overlaps(a, asphalt[j], 0.01) then
			asphaltOverlaps += 1
		end
	end
	for _, w in walks do
		if overlaps(a, w, 0.01) then
			walkOverlaps += 1
		end
	end
end
check("asphalt laid without overlaps", asphaltOverlaps == 0, asphaltOverlaps)
check("sidewalks beside, not on, the asphalt", walkOverlaps == 0, walkOverlaps)
check("street pieces built", #asphalt >= 6 and #walks >= 6, `{#asphalt} asphalt, {#walks} sidewalks`)
check("avenue trees on the median", report.Streets.Trees >= 20, report.Streets.Trees)
check("zebra crossings painted", report.Streets.Crosswalks >= 10, report.Streets.Crosswalks)
check("market stalls on both sides", report.Square.Stalls == 2 * District.Square.StallsPerSide)

-- The statue.
local statue = models.Statue
local s = report.Statue
check(
	"statue figure loaded from the avatar",
	s.Loaded and s.Source == `avatar of user {District.Statue.UserId}`,
	s.Source
)
check("statue finish recorded", s.Finish == District.Statue.Finish and statue:GetAttribute("Finish") == s.Finish)
local figure = statue:FindFirstChild("Figure")
check("figure in the statue model", figure ~= nil)
-- The body without accessories (the figure height is the body height; hair and hats add to it).
local function bodyExtent(model: any): (number, number)
	local bottom, top = math.huge, -math.huge
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and not item:FindFirstAncestorWhichIsA("Accoutrement") then
			bottom = math.min(bottom, item.Position.Y - item.Size.Y / 2)
			top = math.max(top, item.Position.Y + item.Size.Y / 2)
		end
	end
	return bottom, top
end
if figure then
	local bottom, top = bodyExtent(figure)
	local pedestalTop = W + 1.6 + District.Statue.PedestalHeight
	check(
		`figure about {District.Statue.FigureHeight} studs high`,
		math.abs(top - bottom - District.Statue.FigureHeight) < 0.05
			and math.abs(statue:GetAttribute("FigureHeight") - District.Statue.FigureHeight) < 0.05,
		top - bottom
	)
	check("figure stands on the pedestal", math.abs(bottom - pedestalTop) < 0.05, bottom)
	-- The mock avatar arrives like a real one in edit mode: head off its neck, hat not fitted,
	-- and one accessory whose attachment the body does not have.
	local scale = District.Statue.FigureHeight / 5 -- the mock body is 5 studs tall
	local torso, head = figure:FindFirstChild("Torso"), figure:FindFirstChild("Head")
	check(
		"head placed by its neck joint",
		head ~= nil and torso ~= nil and math.abs(head.Position.Y - torso.Position.Y - 1.5 * scale) < 0.01,
		head and torso and (head.Position.Y - torso.Position.Y) / scale
	)
	local hat = figure:FindFirstChild("Hat")
	local handle = hat and hat:FindFirstChild("Handle")
	check(
		"hat fitted onto the head attachment",
		handle ~= nil
			and head ~= nil
			and (handle.Position - (head.Position + Vector3.new(0, 0.8 * scale, 0))).Magnitude < 0.01,
		handle and head and (handle.Position - head.Position) / scale
	)
	check("accessory that fits nowhere is left out", figure:FindFirstChild("Stray") == nil)
	local root = figure:FindFirstChild("HumanoidRootPart")
	local look = root.CFrame.LookVector
	check(
		"figure faces north, towards the Congress",
		look.Z < -0.999 and math.abs(look.Y) < 1e-6,
		`{look.X},{look.Y},{look.Z}`
	)
	check(
		"figure centred on the statue position",
		math.abs(root.Position.X - District.Statue.Position[1]) < 0.01
			and math.abs(root.Position.Z - District.Statue.Position[2]) < 0.01
	)
	local scripts, loose = 0, 0
	for _, item in figure:GetDescendants() do
		if item:IsA("LuaSourceContainer") then
			scripts += 1
		elseif item:IsA("BasePart") and (not item.Anchored or item.CanCollide) then
			loose += 1
		end
	end
	check("no scripts left in the figure", scripts == 0, scripts)
	check(
		"figure parts anchored, collider instead of figure collision",
		loose == 0 and statue:FindFirstChild("Collider") ~= nil
	)
	local humanoid = figure:FindFirstChildOfClass("Humanoid")
	check(
		"no name or health bar over the statue",
		humanoid ~= nil and humanoid.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.None
	)
	local clothing, textured, gilded = 0, 0, true
	for _, item in figure:GetDescendants() do
		if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("BodyColors") then
			clothing += 1
		elseif item:IsA("MeshPart") and item.TextureID ~= "" then
			textured += 1
		elseif item:IsA("SpecialMesh") and item.TextureId ~= "" then
			textured += 1
		end
		if item:IsA("BasePart") and (item.Material ~= Enum.Material.Metal or item.Color.G < item.Color.B) then
			gilded = false
		end
	end
	check("statue is gold by default (decision D3)", District.Statue.Finish == "Gold" and gilded)
	check(
		"gold finish removes clothing and textures",
		clothing == 0 and textured == 0,
		`{clothing} clothing, {textured} textured`
	)
end
check("figure scaled once", stats.scaled == 1, stats.scaled)

-- 3. Rerun, finishes, fallbacks, removal -----------------------------------------------------------
local second = BuildGundiville.run()
local districts = 0
for _, child in map:GetChildren() do
	if child.Name == "GovernmentDistrict" then
		districts += 1
	end
end
check("rerun replaces the district (one folder)", districts == 1)
check("rerun builds the same number of parts", second ~= nil and second.Parts == report.Parts)
folder = map:FindFirstChild("GovernmentDistrict")

local bronze = BuildGundiville.statue({ Finish = "Bronze" })
local statues = 0
for _, child in folder:GetChildren() do
	if child.Name == "LeaderStatue" then
		statues += 1
	end
end
check("statue rebuilt in place", statues == 1 and bronze ~= nil and bronze.Finish == "Bronze")
local bronzeFigure = folder:FindFirstChild("LeaderStatue"):FindFirstChild("Figure")
local clothing, textured, coloured = 0, 0, true
for _, item in bronzeFigure:GetDescendants() do
	if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("BodyColors") then
		clothing += 1
	elseif item:IsA("MeshPart") and item.TextureID ~= "" then
		textured += 1
	elseif item:IsA("SpecialMesh") and item.TextureId ~= "" then
		textured += 1
	end
	if item:IsA("BasePart") and item.Material ~= Enum.Material.Metal then
		coloured = false
	end
end
check(
	"bronze finish removes clothing and textures",
	clothing == 0 and textured == 0,
	`{clothing} clothing, {textured} textured`
)
check("bronze finish casts every part in metal", coloured)
local face = bronzeFigure:FindFirstChild("Head") and bronzeFigure.Head:FindFirstChild("face")
check("bronze finish keeps the face, tinted", face ~= nil and face.Transparency > 0)
local original = BuildGundiville.statue({ Finish = "Original" })
local originalFigure = folder:FindFirstChild("LeaderStatue"):FindFirstChild("Figure")
check("original finish keeps the clothing", original ~= nil and originalFigure:FindFirstChildOfClass("Shirt") ~= nil)
local ok = pcall(function()
	BuildGundiville.statue({ Finish = "Chocolate" })
end)
check("unknown finish is refused", not ok)
check("refused finish leaves the statue", folder:FindFirstChild("LeaderStatue") ~= nil)

stats.avatarFails = true
local fallback = BuildGundiville.statue()
check(
	"without the avatar a stand-in is placed",
	fallback ~= nil and not fallback.Loaded and fallback.Source == "stand-in"
)
local standIn = folder:FindFirstChild("LeaderStatue"):FindFirstChild("StatueStandIn")
check(
	"stand-in has the planned height",
	standIn ~= nil and math.abs(fallback.Height - District.Statue.FigureHeight) < 0.05,
	fallback and fallback.Height
)

local source = MockMakeCharacter()
source.Name = "StatueSource"
source.Parent = mockWorkspace
local manual = BuildGundiville.statue({ Finish = "Stone" })
check(
	"a hand-placed StatueSource is used first",
	manual ~= nil and manual.Loaded and manual.Source == "Workspace.StatueSource"
)
check("StatueSource itself is left in place", mockWorkspace:FindFirstChild("StatueSource") == source)
source:Destroy()
stats.avatarFails = false

-- 4. Saved terrain higher than planned ---------------------------------------------------------------
-- As seen in Studio: the terrain of the city sits about 1.7 studs above the planned ground, while
-- the national roads the district joins stay at road height.
local TERRAIN = District.GroundY + 1.7
local OUTSIDE = District.GroundY + District.RoadTop
stats.groundSurface = function(x: number, z: number): (number, number, number?)
	if math.abs(x) <= 900 and math.abs(z) <= 900 then
		return TERRAIN, 0, nil
	end
	return OUTSIDE, 0, nil
end
local raised = BuildGundiville.run()
folder = map:FindFirstChild("GovernmentDistrict")
local lift = 1.7
check(
	"district raised onto the saved terrain",
	raised ~= nil and math.abs(raised.Lift - lift) < 1e-6 and folder:GetAttribute("GroundLift") == raised.Lift,
	raised and raised.Lift
)
local roadTop = District.GroundY + lift + District.RoadTop
local flatAsphalt, buriedAsphalt, footed, gaps, tilted = 0, 0, 0, 0, {}
for _, item in folder:GetDescendants() do
	if not item:IsA("BasePart") then
		continue
	end
	local up = item.CFrame.UpVector
	local bottom = item.Position.Y - item.Size.Y / 2
	if (item.Name == "Asphalt" or item.Name == "Sidewalk") and up.Y < 0.99999 then
		table.insert(tilted, item)
	elseif item.Name == "Asphalt" then
		flatAsphalt += 1
		if item.Position.Y + item.Size.Y / 2 < TERRAIN then
			buriedAsphalt += 1
		end
	end
	if up.Y > 0.99999 and math.abs(bottom - (District.GroundY - 1)) < 1e-6 then
		footed += 1
	elseif up.Y > 0.99999 and bottom > District.GroundY - 1 and bottom <= District.GroundY + lift + 1e-6 then
		gaps += 1 -- reaches the raised ground but stops above the planned ground
	end
end
check("raised asphalt is above the terrain", flatAsphalt > 0 and buriedAsphalt == 0, `{buriedAsphalt} of {flatAsphalt}`)
check(
	"ground pieces have footings down to the planned ground",
	footed > 50 and gaps == 0,
	`{footed} footed, {gaps} gaps`
)
check("the avenue and the main street ramp down to N5 and N4", raised ~= nil and raised.Streets.Ramps == 2)
-- The ramps: one end level with the raised street, the other with the road it meets.
local function topAt(part: any, sign: number): number
	local f, sz = part.CFrame, part.Size
	local alongZ = math.abs(f.RightVector.Y) < 1e-9 -- ramps along Z keep their X axis level
	local offset = if alongZ
		then Vector3.new(0, sz.Y / 2, sign * sz.Z / 2)
		else Vector3.new(sign * sz.X / 2, sz.Y / 2, 0)
	return (f * offset).Y
end
local rampsOk = #tilted > 0
for _, part in tilted do
	local a, b = topAt(part, -1), topAt(part, 1)
	local high, low = math.max(a, b), math.min(a, b)
	local walk = if part.Name == "Sidewalk" then District.WalkTop - District.RoadTop else 0
	if math.abs(high - (roadTop + walk)) > 0.05 or math.abs(low - (OUTSIDE + walk)) > 0.05 then
		rampsOk = false
		print("INFO ramp piece", part.Name, high, low)
	end
end
check("ramps run from the raised street to the national road", rampsOk, #tilted)
local raisedFigure = folder:FindFirstChild("LeaderStatue"):FindFirstChild("Figure")
local raisedBottom = bodyExtent(raisedFigure)
local raisedPedestal = District.GroundY + lift + District.WalkTop + 1.6 + District.Statue.PedestalHeight
check("statue stands on the raised pedestal", math.abs(raisedBottom - raisedPedestal) < 0.05, raisedBottom)
local rebuilt = BuildGundiville.statue()
local rebuiltBottom = bodyExtent(folder:FindFirstChild("LeaderStatue"):FindFirstChild("Figure"))
check(
	"statue rebuild keeps the raised ground",
	rebuilt ~= nil and math.abs(rebuiltBottom - raisedPedestal) < 0.05,
	rebuiltBottom
)

check("remove() succeeds", BuildGundiville.remove())
check("district removed", map:FindFirstChild("GovernmentDistrict") == nil)
for _, id in District.Replaces do
	check(`placeholder {id} restored`, placeholderFolder:FindFirstChild(id) ~= nil)
end

-- With the imported Creator Store library (StudioTools.UseCreatorStoreAssets), trees and lamps
-- come from the official packs (synthetic fixtures here, as in creator-assets.spec.luau).
local CreatorAssets = load("StudioTools/Map/CreatorAssets")
local function mesh(parent: any, name: string, position: Vector3, size: Vector3)
	local p = Instance.new("MeshPart")
	p.Name, p.Parent, p.CFrame, p.Size = name, parent, CFrame.new(position), size
	p.MeshId, p.TextureID, p.DoubleSided = "fixture-mesh", "fixture-texture", true
end
local function packModel(parent: any, name: string): any
	local m = Instance.new("Model")
	m.Name, m.Parent = name, parent
	return m
end
local library = CreatorAssets.install(function(id: number)
	if id == CreatorAssets.Packs[1].Id then
		local root = packModel(nil, "Forest Pack")
		local trees = packModel(root, "Trees")
		for i = 1, 2 do
			local tree = packModel(trees, "BroadleafTree" .. i)
			mesh(tree, "Trunk", Vector3.new(i * 30, 15, 40), Vector3.new(1, 10, 1))
			mesh(tree, "Leaves", Vector3.new(i * 30, 20, 40), Vector3.new(8, 8, 8))
		end
		return root
	end
	local root = packModel(nil, "City Props Pack")
	local lamp = packModel(root, "StreetLight")
	mesh(lamp, "Pole", Vector3.new(50, 10, 80), Vector3.new(0.7, 20, 0.7))
	mesh(lamp, "Head", Vector3.new(55, 19, 80), Vector3.new(2, 1, 1))
	return root
end, function()
	return { Creator = { Id = 1 }, AssetTypeId = 10 }
end)
local withStore = BuildGundiville.run()
local storeFolder = map:FindFirstChild("GovernmentDistrict")
local storeTrees, storeLamps, storeLights, storeMarks, storeParts = 0, 0, 0, 0, 0
for _, item in storeFolder:GetDescendants() do
	if item:IsA("Model") and item:GetAttribute("AssetVersion") == CreatorAssets.Version then
		if item.Name == "StreetLamp" then
			storeLamps += 1
		else
			storeTrees += 1
		end
	elseif item:IsA("Light") and item:GetAttribute("RoNationStreetLight") == true then
		storeLights += 1
	end
	if item:GetAttribute("GeneratedBy") == "BuildMap" then
		storeMarks += 1
	end
	if item:IsA("BasePart") then
		storeParts += 1
	end
end
print(`INFO with store assets: {storeParts} parts, {storeTrees} trees, {storeLamps} lamps`)
check("store assets: district built", withStore ~= nil and withStore.Parts == storeParts, withStore and withStore.Parts)
check("store assets: trees from the Forest Pack", storeTrees >= 40, storeTrees)
check("store assets: lamps from the City Props Pack", storeLamps >= 25, storeLamps)
check("store assets: every lamp keeps a switched light", storeLights >= storeLamps, `{storeLights} lights`)
check("store assets: still within the budget", storeParts <= District.MaxParts, storeParts)
check("store assets: no BuildMap mark inside the district", storeMarks == 0, storeMarks)
library:Destroy()
BuildGundiville.remove()

-- A folder with the same name that this tool did not build is never replaced.
local custom = Instance.new("Folder")
custom.Name = "GovernmentDistrict"
custom.Parent = map
check("custom GovernmentDistrict folder is not replaced", BuildGundiville.run() == nil and custom.Parent == map)
custom:Destroy()

if failures == 0 then
	print("ALL CHECKS PASSED")
else
	print(`{failures} CHECKS FAILED`)
end
