--!strict
-- Interior furnishings from official Roblox Creator Store packs. Only packs published by Roblox
-- itself (creator: user 1 "Roblox", verified) are used: the Duvall Drive furniture, props and
-- landscaping packs and their realistic material variants. Third-party Store content is never
-- loaded.
--
-- In Studio (edit mode) `install()` loads the packs with InsertService, checks every pack's
-- creator and asset type with MarketplaceService before using it, and copies only the visible
-- geometry of the catalogued models into ServerStorage.RoNationInteriorAssets: no scripts,
-- prompts, sounds, particles, beams, lights or constraints, no hidden drawer contents and no
-- tiny pieces (drawer knobs). Seats stay so players can sit. The two wooden floor variants go to
-- MaterialService (floors fall back to plain wood without them).
--
-- The room recipes place templates with `place()` and build their own furniture when a template
-- (or the whole library, as in the offline tests) is missing, so a build always completes.
-- Template sizes below were measured from the packs after the same clean-up; the recipes lay
-- rooms out with them, so the layout is the same with and without the library.
--
-- Install or refresh the library from the command bar:
--     require(game.ServerStorage.StudioTools.UseInteriorAssets)()
-- BuildGundiville.run() installs it automatically when it is missing.

local Parts = require(script.Parent.Parts)

local StoreAssets = {}

StoreAssets.Version = "interior-1"
StoreAssets.FolderName = "RoNationInteriorAssets"

export type Pack = { Id: number, Name: string, CreatorId: number }

StoreAssets.Packs = {
	Furniture = { Id = 10847897579, Name = "House Furniture Pack - Duvall Drive", CreatorId = 1 } :: Pack,
	Props = { Id = 10840642581, Name = "House Props Pack - Duvall Drive", CreatorId = 1 } :: Pack,
	Landscaping = { Id = 10840661513, Name = "Landscaping Pack - Duvall Drive", CreatorId = 1 } :: Pack,
	Materials = { Id = 10841357434, Name = "Realistic Material Variants - Duvall Drive", CreatorId = 1 } :: Pack,
}
StoreAssets.PackOrder = { "Furniture", "Props", "Landscaping", "Materials" }

-- Material variants used by the floor finishes (Materials.luau names them).
StoreAssets.Variants = { "Wood Floor Herringbone MV", "Wood Floor MV" }

-- Kind: where the template's origin is. Floor and Rug: bottom centre; Wall: centre of the back
-- face (it hangs on a wall); Ceiling: top centre. The front of every template faces -Z (the
-- LookVector of the frame it is placed at), like the furniture of Furniture.luau.
export type Kind = "Floor" | "Wall" | "Ceiling" | "Rug"
export type Entry = {
	Pack: string,
	Source: string, -- model name in the pack
	Kind: Kind,
	Size: Vector3, -- after clean-up and turn (X across, Y up, Z depth)
	Parts: number,
	Height: number?, -- picks the model of that height when several share the name
	Width: number?,
	Child: string?, -- picks the model with a child of that name
	Keep: { string }?, -- only parts with these names (drops pinned photos)
	Turn: number?, -- degrees about Y when the model's front faces +Z
}

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

StoreAssets.Catalog = {
	ExecutiveDesk = { Pack = "Furniture", Source = "Furniture_Study_Desk", Kind = "Floor", Size = v(7.24, 3.03, 3.80), Parts = 7 },
	DeskChair = { Pack = "Furniture", Source = "Study_OfficeChair", Kind = "Floor", Size = v(2.49, 4.01, 2.39), Parts = 5 },
	FilingCabinet = { Pack = "Furniture", Source = "Furniture_FilingCabinet", Kind = "Floor", Size = v(2.05, 2.64, 3.30), Parts = 1 },
	Credenza = { Pack = "Furniture", Source = "Furniture_Credenza_A", Kind = "Floor", Size = v(7.81, 3.47, 2.86), Parts = 5 },
	CredenzaLong = { Pack = "Furniture", Source = "Furniture_RoomAgnostic_Credenza_B", Kind = "Floor", Size = v(11.22, 3.47, 2.86), Parts = 5 },
	Console = { Pack = "Furniture", Source = "Furniture_Console_A", Kind = "Floor", Size = v(5.82, 3.46, 2.16), Parts = 5 },
	Bookcase = { Pack = "Furniture", Source = "Furniture_Bookshelf_A", Kind = "Floor", Size = v(5.01, 8.31, 1.80), Parts = 2, Height = 8.3 },
	BookcaseB = { Pack = "Furniture", Source = "Furniture_Bookshelf_B", Kind = "Floor", Size = v(5.01, 8.31, 1.82), Parts = 4, Height = 8.3 },
	BookcaseTall = { Pack = "Furniture", Source = "Furniture_Bookshelf_A", Kind = "Floor", Size = v(5.00, 13.12, 1.48), Parts = 4, Height = 13.1 },
	BookcaseTallB = { Pack = "Furniture", Source = "Furniture_BookShelf_B", Kind = "Floor", Size = v(5.00, 13.12, 1.48), Parts = 6, Height = 13.1 },
	CoatRack = { Pack = "Furniture", Source = "Furniture_FloorCoatRack", Kind = "Floor", Size = v(2.55, 6.25, 2.55), Parts = 1 },
	GrandfatherClock = { Pack = "Furniture", Source = "GrandfatherClock", Kind = "Floor", Size = v(2.76, 8.02, 1.54), Parts = 6, Turn = 180 },
	DisplayCase = { Pack = "Furniture", Source = "Display_Case_Wide", Kind = "Floor", Size = v(6.78, 8.89, 3.02), Parts = 2 },
	ArmChair = { Pack = "Furniture", Source = "ArmChair", Kind = "Floor", Size = v(3.26, 4.64, 3.70), Parts = 3 },
	Sofa2 = { Pack = "Furniture", Source = "Couch_Double_Dark", Kind = "Floor", Size = v(6.58, 3.85, 4.38), Parts = 8 },
	Sofa3 = { Pack = "Furniture", Source = "Couch_Triple_Dark", Kind = "Floor", Size = v(9.08, 3.85, 4.38), Parts = 10 },
	Sofa2Light = { Pack = "Furniture", Source = "Couch_Double", Kind = "Floor", Size = v(6.58, 3.85, 4.38), Parts = 8 },
	Sofa3Light = { Pack = "Furniture", Source = "Couch_Triple", Kind = "Floor", Size = v(9.08, 3.85, 4.38), Parts = 10 },
	Ottoman = { Pack = "Furniture", Source = "Furniture_Study_Ottoman", Kind = "Floor", Size = v(2.47, 1.61, 2.11), Parts = 3 },
	DiningChair = { Pack = "Furniture", Source = "DiningRoom_Chair", Kind = "Floor", Size = v(1.97, 4.09, 2.05), Parts = 3 },
	ArmDiningChair = { Pack = "Furniture", Source = "DiningRoom_ChairArms", Kind = "Floor", Size = v(2.33, 4.09, 2.05), Parts = 3 },
	CoffeeTable = { Pack = "Furniture", Source = "Furniture_CoffeeTable", Kind = "Floor", Size = v(5.22, 1.77, 2.97), Parts = 1 },
	SideTable = { Pack = "Furniture", Source = "Furniture_SideTable_A", Kind = "Floor", Size = v(1.79, 2.26, 1.79), Parts = 1 },
	RoundTable = { Pack = "Furniture", Source = "Furniture_Entry_Table", Kind = "Floor", Size = v(5.19, 3.12, 5.19), Parts = 1 },
	LongTable = { Pack = "Furniture", Source = "Furniture_DiningRoom_Table", Kind = "Floor", Size = v(17.09, 3.12, 5.50), Parts = 1 },
	Table = { Pack = "Furniture", Source = "Kitchen_DiningTable", Kind = "Floor", Size = v(9.70, 3.03, 4.77), Parts = 1 },
	Bed = { Pack = "Furniture", Source = "Furniture_ParentsBedroom_KingBedFrame", Kind = "Floor", Size = v(11.77, 5.81, 9.97), Parts = 11 },
	GuestBed = { Pack = "Furniture", Source = "Furniture_GrandparentsBedroom_KingBedFrame", Kind = "Floor", Size = v(11.77, 5.81, 9.97), Parts = 11 },
	Nightstand = { Pack = "Furniture", Source = "Furniture_ParentsRoom_Nightstand", Kind = "Floor", Size = v(2.87, 2.58, 2.63), Parts = 3 },
	Dresser = { Pack = "Furniture", Source = "Furniture_ParentsRoom_WideDresser", Kind = "Floor", Size = v(6.70, 4.13, 2.43), Parts = 13 },
	Armoire = { Pack = "Furniture", Source = "Amoire_A", Kind = "Floor", Size = v(5.29, 8.10, 2.11), Parts = 3 },
	Piano = { Pack = "Furniture", Source = "Piano", Kind = "Floor", Size = v(4.80, 4.11, 8.27), Parts = 8 },
	BankersLamp = { Pack = "Furniture", Source = "Bankers_Lamp", Kind = "Floor", Size = v(1.69, 2.18, 1.19), Parts = 4 },
	DeskLamp = { Pack = "Furniture", Source = "Desk Lamp_Off", Kind = "Floor", Size = v(1.05, 3.52, 2.51), Parts = 4 },
	TableLamp = { Pack = "Furniture", Source = "Table_Lamp_A_Off", Kind = "Floor", Size = v(1.71, 2.86, 1.71), Parts = 4, Height = 2.9 },
	Pendant = { Pack = "Furniture", Source = "CeilingLight_Off", Kind = "Ceiling", Size = v(2.49, 6.02, 2.47), Parts = 4 },
	RugKhamseh = { Pack = "Furniture", Source = "Khamseh Carpet", Kind = "Rug", Size = v(13.36, 0.10, 7.78), Parts = 1 },
	RugUshak = { Pack = "Furniture", Source = "Ushak prayer rug", Kind = "Rug", Size = v(13.36, 0.10, 7.78), Parts = 1 },
	RugClassic = { Pack = "Furniture", Source = "Carpet 1", Kind = "Rug", Size = v(13.36, 0.10, 7.78), Parts = 1 },
	RugLarge = { Pack = "Furniture", Source = "Rug 4", Kind = "Rug", Size = v(13.36, 0.10, 11.79), Parts = 1 },
	RugSwan = { Pack = "Furniture", Source = "Swan House Carpet", Kind = "Rug", Size = v(13.36, 0.10, 7.78), Parts = 1, Width = 13.4 },
	RugHall = { Pack = "Furniture", Source = "Swan House Carpet", Kind = "Rug", Size = v(35.02, 0.12, 24.61), Parts = 1, Width = 35.0 },
	PaintingOfficer = { Pack = "Props", Source = "A Mounted Officer", Kind = "Wall", Size = v(5.59, 7.07, 0.38), Parts = 2 },
	PaintingMurnau = { Pack = "Props", Source = "Houses at Murnau", Kind = "Wall", Size = v(7.07, 5.59, 0.32), Parts = 2 },
	PaintingBordighera = { Pack = "Props", Source = "Bordighera", Kind = "Wall", Size = v(7.07, 5.59, 0.35), Parts = 2 },
	PaintingBoats = { Pack = "Props", Source = "Boats at Rest", Kind = "Wall", Size = v(7.07, 5.59, 0.35), Parts = 2 },
	PaintingGulfStream = { Pack = "Props", Source = "The Gulf Stream", Kind = "Wall", Size = v(7.07, 5.59, 0.38), Parts = 2 },
	PaintingCottage = { Pack = "Props", Source = "Fisherman's Cottage", Kind = "Wall", Size = v(5.59, 7.07, 0.30), Parts = 2 },
	PaintingHelena = { Pack = "Props", Source = "Helena Tromper Du Bois", Kind = "Wall", Size = v(5.59, 7.07, 0.38), Parts = 2 },
	PaintingFurCap = { Pack = "Props", Source = "Self-Portrait in a Fur Cap", Kind = "Wall", Size = v(5.59, 7.07, 0.30), Parts = 2 },
	PaintingSail = { Pack = "Props", Source = "Stowing Sail", Kind = "Wall", Size = v(7.07, 5.59, 0.30), Parts = 2 },
	PaintingBathers = { Pack = "Props", Source = "Coast Scene Bathers", Kind = "Wall", Size = v(7.07, 5.59, 0.34), Parts = 2 },
	PaintingTocsin = { Pack = "Props", Source = "Le Tocsin", Kind = "Wall", Size = v(5.59, 7.07, 0.40), Parts = 2 },
	PaintingLark = { Pack = "Props", Source = "The Song of the Lark", Kind = "Wall", Size = v(5.59, 7.07, 0.35), Parts = 2 },
	CorkBoard = { Pack = "Props", Source = "CorkBoard", Kind = "Wall", Size = v(5.13, 4.05, 0.25), Parts = 2, Keep = { "PictureFrameC", "Cork" } },
	Bust = { Pack = "Props", Source = "Womans_Bust", Kind = "Floor", Size = v(1.62, 2.47, 1.00), Parts = 1 },
	BustMan = { Pack = "Props", Source = " Sculpture_Mans Bust", Kind = "Floor", Size = v(1.38, 3.00, 1.27), Parts = 1 },
	Book = { Pack = "Props", Source = "Book_03", Kind = "Floor", Size = v(0.81, 0.15, 1.03), Parts = 1 },
	BookDark = { Pack = "Props", Source = "Book_01", Kind = "Floor", Size = v(0.56, 0.20, 0.87), Parts = 1 },
	Journal = { Pack = "Props", Source = "Journal", Kind = "Floor", Size = v(1.18, 0.16, 0.77), Parts = 4 },
	Notepad = { Pack = "Props", Source = "Prop_Notepad", Kind = "Floor", Size = v(0.70, 0.08, 1.02), Parts = 3 },
	Pen = { Pack = "Props", Source = "Pen", Kind = "Floor", Size = v(0.51, 0.06, 0.47), Parts = 2 },
	Cup = { Pack = "Props", Source = "Coffee_Cup_White", Kind = "Floor", Size = v(0.32, 0.31, 0.39), Parts = 1 },
	CoffeeMachine = { Pack = "Props", Source = "CoffeeMachine", Kind = "Floor", Size = v(1.46, 1.86, 1.06), Parts = 3 },
	Bell = { Pack = "Props", Source = "Desk_Bell", Kind = "Floor", Size = v(0.33, 0.21, 0.33), Parts = 2 },
	Kettle = { Pack = "Props", Source = "TeaKettle", Kind = "Floor", Size = v(1.45, 1.16, 1.13), Parts = 2 },
	Bowl = { Pack = "Props", Source = "DecorativeBowl1", Kind = "Floor", Size = v(1.38, 0.39, 1.39), Parts = 1 },
	RubberPlant = { Pack = "Landscaping", Source = "PottedPlant_RubberPlant", Kind = "Floor", Size = v(2.83, 6.50, 2.81), Parts = 3 },
	SnakePlant = { Pack = "Landscaping", Source = "Planter_Snake", Kind = "Floor", Size = v(2.48, 5.97, 2.48), Parts = 3 },
	Philodendron = { Pack = "Landscaping", Source = "SolariumPottedPlant_C", Kind = "Floor", Size = v(3.82, 5.07, 3.26), Parts = 3 },
	Evergreen = { Pack = "Landscaping", Source = "Planter_Chinese_Evergreen", Kind = "Floor", Size = v(3.81, 4.93, 3.66), Parts = 3 },
	RubberPlantRed = { Pack = "Landscaping", Source = "SolariumPottedPlant_G", Kind = "Floor", Size = v(3.90, 6.88, 3.91), Parts = 3 },
	Dracaena = { Pack = "Landscaping", Source = "SolariumPottedPlant_F", Kind = "Floor", Size = v(8.96, 12.90, 8.44), Parts = 4, Child = "dracaena_marginata" },
	Sapling = { Pack = "Landscaping", Source = "SolariumPottedPlant_A", Kind = "Floor", Size = v(8.66, 12.06, 8.63), Parts = 4 },
} :: { [string]: Entry }

-- Library --------------------------------------------------------------------------------------

function StoreAssets.get(): Folder?
	local ok, storage = pcall(function()
		return game:GetService("ServerStorage")
	end)
	if not ok or not storage then
		return nil
	end
	local library = storage:FindFirstChild(StoreAssets.FolderName)
	if
		library
		and library:GetAttribute("ManagedBy") == StoreAssets.FolderName
		and library:GetAttribute("AssetVersion") == StoreAssets.Version
	then
		return library :: Folder
	end
	return nil
end

-- The measured size of a catalogued template (used for the layout, with or without library).
function StoreAssets.size(key: string): Vector3
	local entry = StoreAssets.Catalog[key]
	assert(entry, `StoreAssets: unknown template {key}`)
	return entry.Size
end

function StoreAssets.has(key: string): boolean
	local library = StoreAssets.get()
	return library ~= nil and library:FindFirstChild(key) ~= nil
end

-- Clean-up -------------------------------------------------------------------------------------

-- Children a copied part keeps: its look, nothing that runs or emits.
local VISUAL = { SurfaceAppearance = true, SpecialMesh = true, Decal = true, Texture = true }
local SKIP_NAMES = { clicktrigger = true, hitbox = true, collision = true }
local TINY = 0.16

local function isSeat(part: Instance): boolean
	return part:IsA("Seat") or part:IsA("VehicleSeat")
end

-- The parts of `node` that make up the visible model (and its seats).
function StoreAssets.visibleParts(node: Instance, keep: { string }?): { BasePart }
	local out: { BasePart } = {}
	local candidates: { Instance } = { node }
	for _, d in node:GetDescendants() do
		table.insert(candidates, d)
	end
	for _, d in candidates do
		if not d:IsA("BasePart") then
			continue
		end
		local part = d :: BasePart
		local hidden = false
		local ancestor = part.Parent
		while ancestor and ancestor ~= node.Parent do
			if string.find(string.lower(ancestor.Name), "drawer things", 1, true) then
				hidden = true
			end
			ancestor = ancestor.Parent
		end
		if hidden then
			continue
		end
		local seat = isSeat(part)
		local size = part.Size
		if not seat then
			if part.Transparency >= 0.95 or SKIP_NAMES[string.lower(part.Name)] then
				continue
			end
			if math.max(size.X, size.Y, size.Z) < TINY then
				continue
			end
			if keep and not table.find(keep, part.Name) then
				continue
			end
		end
		table.insert(out, part)
	end
	return out
end

local function bounds(parts: { BasePart }): (Vector3, Vector3)
	local lo = Vector3.new(1e9, 1e9, 1e9)
	local hi = -lo
	for _, p in parts do
		local half = p.Size / 2
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local c = p.CFrame * Vector3.new(x * half.X, y * half.Y, z * half.Z)
					lo = Vector3.new(math.min(lo.X, c.X), math.min(lo.Y, c.Y), math.min(lo.Z, c.Z))
					hi = Vector3.new(math.max(hi.X, c.X), math.max(hi.Y, c.Y), math.max(hi.Z, c.Z))
				end
			end
		end
	end
	return lo, hi
end

-- Finds the catalogued model in a loaded pack.
function StoreAssets.find(container: Instance, entry: Entry): Instance?
	for _, node in container:GetDescendants() do
		if node.Name ~= entry.Source or not (node:IsA("Model") or node:IsA("BasePart")) then
			continue
		end
		if entry.Child and not node:FindFirstChild(entry.Child) then
			continue
		end
		if entry.Height or entry.Width then
			local parts = StoreAssets.visibleParts(node, entry.Keep)
			if #parts == 0 then
				continue
			end
			local lo, hi = bounds(parts)
			if entry.Height and math.abs(hi.Y - lo.Y - entry.Height) > 0.5 then
				continue
			end
			if entry.Width and math.abs(hi.X - lo.X - entry.Width) > 0.5 then
				continue
			end
		end
		return node
	end
	return nil
end

-- A clean template from a pack model: its visible parts, anchored, relative to the template's
-- origin (see Kind), front towards -Z.
function StoreAssets.template(node: Instance, key: string, entry: Entry, sourceId: number): Model?
	local parts = StoreAssets.visibleParts(node, entry.Keep)
	if #parts == 0 then
		return nil
	end
	local lo, hi = bounds(parts)
	local centre = (lo + hi) / 2
	local origin: Vector3
	if entry.Kind == "Wall" then
		origin = Vector3.new(centre.X, centre.Y, hi.Z)
	elseif entry.Kind == "Ceiling" then
		origin = Vector3.new(centre.X, hi.Y, centre.Z)
	else
		origin = Vector3.new(centre.X, lo.Y, centre.Z)
	end
	local normalise = CFrame.Angles(0, math.rad(entry.Turn or 0), 0) * CFrame.new(-origin)
	local model = Instance.new("Model")
	model.Name = key
	local seats = 0
	for _, part in parts do
		local copy = part:Clone()
		for _, child in copy:GetChildren() do
			if not VISUAL[child.ClassName] then
				child:Destroy()
			end
		end
		local size = copy.Size
		local largest = math.max(size.X, size.Y, size.Z)
		copy.Anchored = true
		copy.CanTouch = false
		if isSeat(copy) then
			seats += 1
		elseif entry.Kind == "Rug" or entry.Kind == "Wall" or largest < 1.5 then
			-- Rugs, pictures and small things: no collision, no shadow from tiny pieces.
			copy.CanCollide = false
			copy.CanQuery = false
			if largest < 0.8 or entry.Kind == "Rug" then
				copy.CastShadow = false
			end
		end
		copy.CFrame = normalise * part.CFrame
		copy.Parent = model
	end
	model:SetAttribute("SourceAssetId", sourceId)
	model:SetAttribute("SourceName", entry.Source)
	model:SetAttribute("Kind", entry.Kind)
	model:SetAttribute("Seats", seats)
	return model
end

-- Install --------------------------------------------------------------------------------------

export type Report = { Templates: number, Missing: { string }, Variants: number }

-- Loads the packs and builds the library. `loader` and `metadata` replace InsertService and
-- MarketplaceService (tests). The previous library stays when anything fails.
function StoreAssets.install(loader: ((number) -> Instance)?, metadata: ((number) -> any)?): (Folder, Report)
	assert(not game:GetService("RunService"):IsRunning(), "Stop Play before importing Creator Store assets")
	local storage = game:GetService("ServerStorage")
	local old = storage:FindFirstChild(StoreAssets.FolderName)
	assert(
		not old or old:GetAttribute("ManagedBy") == StoreAssets.FolderName,
		`ServerStorage.{StoreAssets.FolderName} holds other content; rename it first`
	)
	local loadAsset = loader
		or function(id: number): Instance
			return game:GetService("InsertService"):LoadAsset(id)
		end
	local info = metadata
		or function(id: number): any
			return game:GetService("MarketplaceService"):GetProductInfo(id)
		end
	local library = Instance.new("Folder")
	library.Name = StoreAssets.FolderName
	library:SetAttribute("ManagedBy", StoreAssets.FolderName)
	library:SetAttribute("AssetVersion", StoreAssets.Version)
	local variants = Instance.new("Folder")
	variants.Name = "MaterialVariants"
	variants.Parent = library
	local report: Report = { Templates = 0, Missing = {}, Variants = 0 }
	local keys: { string } = {}
	for key in StoreAssets.Catalog do
		table.insert(keys, key)
	end
	table.sort(keys)
	local loaded: Instance? = nil
	local ok, err = pcall(function()
		for _, packName in StoreAssets.PackOrder do
			local pack: Pack = (StoreAssets.Packs :: any)[packName]
			local product = info(pack.Id)
			assert(
				type(product) == "table"
					and type(product.Creator) == "table"
					and product.Creator.Id == pack.CreatorId
					and product.AssetTypeId == 10,
				`{pack.Name} ({pack.Id}) is not an official Roblox model; import stopped`
			)
			local container = loadAsset(pack.Id)
			assert(container, `{pack.Name}: the asset loader returned nothing`)
			loaded = container
			container.Parent = nil
			if packName == "Materials" then
				for _, node in container:GetDescendants() do
					if node:IsA("MaterialVariant") and table.find(StoreAssets.Variants, node.Name) then
						local copy = node:Clone()
						for _, child in copy:GetChildren() do
							child:Destroy()
						end
						copy:SetAttribute("ManagedBy", StoreAssets.FolderName)
						copy.Parent = variants
						report.Variants += 1
					end
				end
			else
				for _, key in keys do
					local entry = StoreAssets.Catalog[key]
					if entry.Pack ~= packName then
						continue
					end
					local node = StoreAssets.find(container, entry)
					local template = if node then StoreAssets.template(node, key, entry, pack.Id) else nil
					if template then
						template.Parent = library
						report.Templates += 1
					else
						table.insert(report.Missing, key)
					end
				end
			end
			container:Destroy()
			loaded = nil
		end
		assert(report.Templates > 0, "no catalogued model was found in the packs")
	end)
	if loaded then
		(loaded :: Instance):Destroy()
	end
	if not ok then
		library:Destroy()
		error(`Interior asset import failed; the previous library was kept: {tostring(err)}`, 0)
	end
	if old then
		old:Destroy()
	end
	library.Parent = storage
	StoreAssets.applyVariants(library)
	return library, report
end

-- Copies the library's material variants into MaterialService (replacing only our own copies).
function StoreAssets.applyVariants(library: Folder): number
	local ok, service = pcall(function()
		return game:GetService("MaterialService")
	end)
	local folder = library:FindFirstChild("MaterialVariants")
	if not ok or not service or not folder then
		return 0
	end
	local count = 0
	for _, variant in folder:GetChildren() do
		local existing = service:FindFirstChild(variant.Name)
		if existing and existing:GetAttribute("ManagedBy") ~= StoreAssets.FolderName then
			continue -- someone else's variant of that name: leave it
		end
		if existing then
			existing:Destroy()
		end
		variant:Clone().Parent = service
		count += 1
	end
	return count
end

-- Installs the library when it is missing. Returns the library or nil and the reason.
function StoreAssets.ensure(): (Folder?, string)
	local library = StoreAssets.get()
	if library then
		StoreAssets.applyVariants(library)
		return library, "present"
	end
	local ok, result, report = pcall(StoreAssets.install)
	if ok then
		local r = report :: Report
		return result, `installed {r.Templates} templates, {r.Variants} material variants`
	end
	return nil, tostring(result)
end

-- Placing --------------------------------------------------------------------------------------

-- Places a copy of the template at `frame` (origin as its Kind says, front along the
-- LookVector), scaled by `scale`. Returns nil when the template is not installed.
function StoreAssets.place(parent: Instance, key: string, frame: CFrame, scale: number?): Model?
	local library = StoreAssets.get()
	local template = if library then library:FindFirstChild(key) else nil
	if not template then
		return nil
	end
	local model = template:Clone() :: Model
	local s = scale or 1
	local n = 0
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			local part = child :: BasePart
			local rel = part.CFrame
			if s ~= 1 then
				part.Size = part.Size * s
				rel = CFrame.new(rel.Position * s) * (rel - rel.Position)
			end
			part.CFrame = frame * rel
			n += 1
		end
	end
	model.Parent = parent
	Parts.add(n)
	return model
end

return StoreAssets
