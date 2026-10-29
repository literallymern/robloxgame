--!nocheck
-- needs: roblox-mock
-- Interior furnishings from official Roblox packs (StudioTools Architecture/StoreAssets): the
-- importer is run against synthetic packs that mirror the catalogue (one model per entry with
-- its measured size and part count, plus the clutter real packs carry: scripts, prompts,
-- lights, sounds, hit boxes, drawer contents and tiny knobs). The checks cover the clean-up,
-- the template frames, the creator check, the material variants, and then build the four
-- buildings with the library in place: every placed model stays inside its room, nothing is
-- unanchored or scripted, the game's fixed seats remain and the part budgets hold.
-- The synthetic packs test the importer, not Roblox's live asset hierarchy or renderer.

local StoreAssets = load("StudioTools/Architecture/StoreAssets")
local District = load("ReplicatedStorage/Shared/Config/GovernmentDistrict")
local Kit = load("StudioTools/Gundiville/Kit")

local failures = 0
local function check(name, ok, detail)
	if ok then
		print("PASS", name)
	else
		failures += 1
		print("FAIL", name, if detail ~= nil then tostring(detail) else "")
	end
end

-- Seats in the seating models (as in the real packs: invisible Seat parts).
local SEATS = {
	DeskChair = 1,
	ArmChair = 1,
	Sofa2 = 2,
	Sofa3 = 3,
	Sofa2Light = 2,
	Sofa3Light = 3,
	Ottoman = 1,
	DiningChair = 1,
	ArmDiningChair = 1,
	Piano = 1,
	Bed = 2,
	GuestBed = 2,
}

local function part(class, parent, name, cframe, size)
	local p = Instance.new(class)
	p.Name, p.CFrame, p.Size = name, cframe, size
	p.Anchored = false
	p.Parent = parent
	return p
end

-- One synthetic pack model for a catalogue entry, standing somewhere in the pack's world.
local function fakeModel(parent, key, entry, index)
	local model = Instance.new("Model")
	model.Name = entry.Source
	model.Parent = parent
	local size = entry.Size
	local turned = entry.Turn == 180
	local origin = CFrame.new(index * 40, 3 + index % 5, -60 - index % 7 * 3)
	local seats = SEATS[key] or 0
	local visible = entry.Parts - seats
	local names = entry.Keep or {}
	local bodyName = if entry.Child then entry.Child else (names[1] or "Body")
	local body = part("MeshPart", model, bodyName, origin, size)
	local look = Instance.new("SurfaceAppearance")
	look.ColorMap = "fixture-pbr"
	look.Parent = body
	Instance.new("Script").Parent = body
	local prompt = Instance.new("ProximityPrompt")
	prompt.Parent = body
	Instance.new("PointLight").Parent = body
	Instance.new("Sound").Parent = body
	for i = 2, visible do
		local s = Vector3.new(
			math.min(size.X, math.max(0.3, size.X * 0.4)),
			math.min(size.Y, math.max(0.2, size.Y * 0.3)),
			math.min(size.Z, math.max(0.2, size.Z * 0.3))
		)
		local p = part("MeshPart", model, names[i] or ("Piece" .. i), origin * CFrame.new(0, 0, 0), s)
		p.Transparency = 0
	end
	if turned then
		-- The clock's face points to +Z in the pack: a marker at its front.
		local marker = model:FindFirstChild("Piece2") or body
		marker.Name = "Face"
		marker.CFrame = origin * CFrame.new(0, 0, size.Z / 2 - marker.Size.Z / 2)
	end
	for i = 1, seats do
		local seat = part("Seat", model, "Seat", origin * CFrame.new((i - 0.5 - seats / 2) * 1.8, 0, 0), Vector3.new(1.6, 0.2, 0.9))
		seat.Transparency = 1
	end
	-- Clutter the importer must leave behind.
	part("Part", model, "Knob", origin, Vector3.new(0.1, 0.1, 0.1))
	local hitbox = part("Part", model, "Hitbox", origin, size * 0.9)
	hitbox.Transparency = 1
	local drawer = Instance.new("Folder")
	drawer.Name = "Drawer Things"
	drawer.Parent = model
	part("MeshPart", drawer, "Sock", origin, Vector3.new(0.6, 0.3, 0.6))
	if entry.Keep then
		part("MeshPart", model, "Photo", origin * CFrame.new(0, 0, -0.1), Vector3.new(1, 1, 0.05))
	end
	Instance.new("LocalScript").Parent = model
	return model
end

local function fakePack(packName)
	local root = Instance.new("Model")
	root.Name = packName .. " Pack"
	if packName == "Materials" then
		for _, name in { "Wood Floor Herringbone MV", "Wood Floor MV", "Brick Wall MV" } do
			local variant = Instance.new("MaterialVariant")
			variant.Name = name
			variant.Parent = root
			Instance.new("Script").Parent = variant
		end
		return root
	end
	local group = Instance.new("Folder")
	group.Name = "Models"
	group.Parent = root
	local keys = {}
	for key, entry in StoreAssets.Catalog do
		if entry.Pack == packName then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	for i, key in keys do
		fakeModel(group, key, StoreAssets.Catalog[key], i)
	end
	return root
end

local requested = {}
local function loader(id)
	table.insert(requested, id)
	for name, pack in StoreAssets.Packs do
		if pack.Id == id then
			return fakePack(name)
		end
	end
	error("unexpected asset " .. tostring(id))
end
local function official()
	return { Creator = { Id = 1, Name = "Roblox" }, AssetTypeId = 10 }
end

local ServerStorage = game:GetService("ServerStorage")
local MaterialService = game:GetService("MaterialService")

-- A folder of that name that the importer did not make is never replaced.
local foreign = Instance.new("Folder")
foreign.Name = StoreAssets.FolderName
foreign.Parent = ServerStorage
check("a foreign RoNationInteriorAssets folder is not replaced", not pcall(StoreAssets.install, loader, official))
foreign:Destroy()

-- Someone else's material variant of the same name stays.
local theirs = Instance.new("MaterialVariant")
theirs.Name = "Wood Floor MV"
theirs.Parent = MaterialService

local library, report = StoreAssets.install(loader, official)
local catalogued = 0
for _ in StoreAssets.Catalog do
	catalogued += 1
end
check("the four official packs are requested", #requested == 4, #requested)
check("every catalogued model became a template", report.Templates == catalogued and #report.Missing == 0, `{report.Templates}/{catalogued}, missing {table.concat(report.Missing, ", ")}`)
check("the two floor variants are copied (not other variants)", report.Variants == 2, report.Variants)
check("the library is found by the room recipes", StoreAssets.get() == library)

local clean, anchored, untouched, wrongParts, wrongSize, wrongOrigin, wrongSeats = true, true, true, {}, {}, {}, {}
for key, entry in StoreAssets.Catalog do
	local template = library:FindFirstChild(key)
	if not template then
		table.insert(wrongParts, key)
		continue
	end
	local parts, seats = 0, 0
	local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for _, node in template:GetDescendants() do
		if node:IsA("LuaSourceContainer") or node:IsA("ProximityPrompt") or node:IsA("Light") or node:IsA("Sound") then
			clean = false
		end
		if node:IsA("BasePart") then
			parts += 1
			anchored = anchored and node.Anchored
			untouched = untouched and not node.CanTouch
			if node:IsA("Seat") then
				seats += 1
			else
				for x = -1, 1, 2 do
					for y = -1, 1, 2 do
						for z = -1, 1, 2 do
							local c = node.CFrame * Vector3.new(x * node.Size.X / 2, y * node.Size.Y / 2, z * node.Size.Z / 2)
							lo = Vector3.new(math.min(lo.X, c.X), math.min(lo.Y, c.Y), math.min(lo.Z, c.Z))
							hi = Vector3.new(math.max(hi.X, c.X), math.max(hi.Y, c.Y), math.max(hi.Z, c.Z))
						end
					end
				end
			end
		end
	end
	if parts ~= entry.Parts then
		table.insert(wrongParts, `{key} {parts}/{entry.Parts}`)
	end
	if seats ~= (SEATS[key] or 0) then
		table.insert(wrongSeats, key)
	end
	if ((hi - lo) - entry.Size).Magnitude > 0.05 then
		table.insert(wrongSize, key)
	end
	local centre = (lo + hi) / 2
	local ok = if entry.Kind == "Wall"
		then math.abs(hi.Z) < 0.05 and math.abs(centre.X) < 0.05 and math.abs(centre.Y) < 0.05
		elseif entry.Kind == "Ceiling" then math.abs(hi.Y) < 0.05 and math.abs(centre.X) < 0.05
		else math.abs(lo.Y) < 0.05 and math.abs(centre.X) < 0.05 and math.abs(centre.Z) < 0.05
	if not ok then
		table.insert(wrongOrigin, key)
	end
end
check("templates hold no scripts, prompts, lights or sounds", clean)
check("template parts are anchored and do not touch", anchored and untouched)
check("templates keep exactly the visible parts (no knobs, hit boxes, drawer contents, photos)", #wrongParts == 0, table.concat(wrongParts, ", "))
check("seats stay so players can sit", #wrongSeats == 0, table.concat(wrongSeats, ", "))
check("templates have the catalogued sizes", #wrongSize == 0, table.concat(wrongSize, ", "))
check("template origins: floor items at their bottom centre, pictures at their back", #wrongOrigin == 0, table.concat(wrongOrigin, ", "))
local face = library.GrandfatherClock:FindFirstChild("Face")
check("a model facing +Z in its pack is turned to face -Z", face ~= nil and face.CFrame.Position.Z < 0, face and face.CFrame.Position.Z)
check("material variants are in MaterialService, foreign ones untouched", MaterialService:FindFirstChild("Wood Floor Herringbone MV") ~= nil and theirs.Parent == MaterialService and theirs:GetAttribute("ManagedBy") == nil)

-- Placing: the template's origin goes to the frame, scaled copies keep their proportions.
local scratch = Instance.new("Folder")
local placed = StoreAssets.place(scratch, "Sofa3", CFrame.new(10, 2, 10) * CFrame.Angles(0, math.pi / 2, 0), 0.5)
local _, extent = placed:GetBoundingBox()
check("a placed copy follows the frame and the scale", placed ~= nil and math.abs(extent.Y - StoreAssets.Catalog.Sofa3.Size.Y * 0.5) < 0.05, extent)
check("place() returns nil for a missing template", StoreAssets.place(scratch, "NoSuchThing", CFrame.new()) == nil)
scratch:Destroy()

-- A pack that is not by Roblox stops the import; the old library stays.
local ok = pcall(StoreAssets.install, loader, function()
	return { Creator = { Id = 158552482, Name = "Roblox" }, AssetTypeId = 10 }
end)
check("a pack by another creator is refused, the library is kept", not ok and StoreAssets.get() == library)

-- The buildings with the library -------------------------------------------------------------
-- The same budgets as tests/map/architecture.spec.luau (measured with the library: Congress
-- 10,093, Hausali 10,909, Central Bank 4,721, Residence 3,966 parts).
local BUDGET = { Congress = 10700, Hausali = 11500, CentralBank = 5000, Residence = 4200 }
local ORDER = { "Congress", "Hausali", "CentralBank", "Residence" }
local total = 0
for _, name in ORDER do
	local Builder = load("StudioTools/Gundiville/" .. name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	Kit.resetCount()
	Builder.build(District, folder)
	local model = folder:GetChildren()[1]
	local counted = Kit.partCount()
	local parts, loose, scripts, store, outside, rooms, furnished = 0, 0, 0, 0, {}, 0, 0
	local keys = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			parts += 1
			if not item.Anchored then
				loose += 1
			end
		elseif item:IsA("LuaSourceContainer") then
			scripts += 1
		elseif item:IsA("Model") and item:GetAttribute("SourceAssetId") then
			store += 1
			keys[item.Name] = (keys[item.Name] or 0) + 1
			-- Inside its room: between floor and ceiling, within the walls.
			local room = item:FindFirstAncestorWhichIsA("Folder")
			while room and not room:GetAttribute("Min") do
				room = room:FindFirstAncestorWhichIsA("Folder")
			end
			if room then
				local min, max = room:GetAttribute("Min"), room:GetAttribute("Max")
				local cf, size = item:GetBoundingBox()
				local lo, hi = cf.Position - size / 2, cf.Position + size / 2
				-- Min/Max run along the partitions' centre lines and the exterior walls' inner
				-- faces: nothing may reach into an exterior wall or past a partition's middle.
				local over = math.max(
					min.Y - lo.Y,
					hi.Y - max.Y,
					min.X - lo.X,
					hi.X - max.X,
					min.Z - lo.Z,
					hi.Z - max.Z
				)
				if over > 0.05 then
					table.insert(outside, `{item.Name} in {room.Name} ({string.format("%.2f", over)})`)
				end
			end
		elseif item:IsA("Folder") and item:GetAttribute("Kind") and not item:GetAttribute("Open") then
			local kind = item:GetAttribute("Kind")
			if kind ~= "Lift" and kind ~= "Stair" then
				rooms += 1
				local n = 0
				for _, d in item:GetDescendants() do
					if d:IsA("BasePart") and d.Name ~= "FloorFinish" then
						n += 1
					end
				end
				if n >= 8 then
					furnished += 1
				end
			end
		end
	end
	total += parts
	local top = {}
	for key, n in keys do
		table.insert(top, `{key} {n}`)
	end
	table.sort(top)
	print(`INFO {name}: {parts} parts, {store} official models ({table.concat(top, ", ")})`)
	check(`{name}: the part counter matches the parts built`, counted == parts, `{counted} vs {parts}`)
	check(`{name}: within its budget of {BUDGET[name]} parts with the library`, parts <= BUDGET[name], parts)
	check(`{name}: everything anchored`, loose == 0, loose)
	check(`{name}: no scripts inside`, scripts == 0, scripts)
	check(`{name}: official models are placed`, store >= 40, store)
	check(`{name}: every placed model stays inside its room`, #outside == 0, table.concat(outside, "; "))
	check(`{name}: every room is furnished`, rooms > 0 and furnished == rooms, `{furnished}/{rooms}`)
	if name == "Congress" then
		local chamberSeats = 0
		for _, item in model:GetDescendants() do
			if item:IsA("Folder") and item:GetAttribute("Kind") == "Chamber" then
				for _, d in item:GetDescendants() do
					if d:IsA("Seat") then
						chamberSeats += 1
					end
				end
			end
		end
		check("Congress: the chamber keeps its 50 seats", chamberSeats == 50, chamberSeats)
	elseif name == "Residence" then
		local chair, office = nil, nil
		for _, item in model:GetDescendants() do
			if item.Name == "LeadersChair" then
				chair = item
			elseif item:IsA("Folder") and item:GetAttribute("Kind") == "LeadersOffice" then
				office = item
			end
		end
		check("Residence: the Leader's chair is the seat of the official chair, in the office", chair ~= nil and chair:IsA("Seat") and office ~= nil and chair:IsDescendantOf(office) and chair:FindFirstAncestorWhichIsA("Model"):GetAttribute("SourceAssetId") ~= nil)
	end
	folder:Destroy()
end
print(`INFO with the interior library: {total} parts in the four buildings`)

library:Destroy()
check("without the library the recipes build their own furniture", StoreAssets.get() == nil)

if failures == 0 then
	print("ALL CHECKS PASSED")
else
	print(`{failures} CHECKS FAILED`)
end
