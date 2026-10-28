--!strict
-- Official Roblox models, imported in Studio only. Store IDs were verified on Creator Store.
-- Keep the mesh/texture assets in the saved place; this repository contains the integration.
local Util = require(script.Parent.Builders.Util)
local Assets = {}
Assets.Version = "creator-store-1"
Assets.Packs = {
	{ Id = 6432306802, Name = "Forest Pack", CreatorId = 1 },
	{ Id = 6370681139, Name = "City Props Pack", CreatorId = 1 },
}
local NAME = "RoNationCreatorAssets"
local VISUAL = { SurfaceAppearance = true, SpecialMesh = true, Texture = true, Decal = true }

local function isGeometry(part: Instance): boolean
	local name = string.lower(part.Name)
	return part:IsA("BasePart") and not name:find("soil") and not name:find("particle")
end

local function partsOf(root: Instance): { BasePart }
	local parts: { BasePart } = {}
	if isGeometry(root) then
		table.insert(parts, root :: BasePart)
	end
	for _, child in root:GetDescendants() do
		if isGeometry(child) then
			table.insert(parts, child :: BasePart)
		end
	end
	return parts
end

local function bounds(parts: { BasePart }): (Vector3, Vector3)
	local low, high = parts[1].ExtentsCFrame.Position, parts[1].ExtentsCFrame.Position
	for _, p in parts do
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local v = p.ExtentsCFrame * Vector3.new(x * p.Size.X / 2, y * p.Size.Y / 2, z * p.Size.Z / 2)
					low = Vector3.new(math.min(low.X, v.X), math.min(low.Y, v.Y), math.min(low.Z, v.Z))
					high = Vector3.new(math.max(high.X, v.X), math.max(high.Y, v.Y), math.max(high.Z, v.Z))
				end
			end
		end
	end
	return low, high
end

local function category(name: string): string?
	local n = string.lower(name):gsub("[^%a]", "")
	if n:find("stump") or n:find("log") or n:find("soil") or n:find("particle") then
		return nil
	end
	if n:find("streetlight") or n:find("lamp") then
		return "Lamp"
	end
	if n:find("fern") then
		return "Fern"
	end
	if n:find("rock") or n:find("boulder") then
		return "Rock"
	end
	if n:find("bush") or n:find("shrub") then
		return "Shrub"
	end
	if n:find("tree") and not n:find("leaves") then
		return "Tree"
	end
	return nil
end

-- Number of templates in one category folder of the library (0 when the folder is missing).
function Assets.count(library: Instance, kind: string): number
	local folder = library:FindFirstChild(kind)
	return if folder then #folder:GetChildren() else 0
end

function Assets.get(): Folder?
	local library = game:GetService("ServerStorage"):FindFirstChild(NAME)
	return if library
			and library:GetAttribute("ManagedBy") == NAME
			and library:GetAttribute("AssetVersion") == Assets.Version
		then library :: Folder
		else nil
end

-- Flatten only visual geometry, copying textures but never scripts, sounds or demo controllers.
function Assets.extract(pack: Instance, id: number, library: Folder): number
	local candidates = {}
	local roots = { pack }
	for _, node in pack:GetDescendants() do
		table.insert(roots, node)
	end
	for _, node in roots do
		if not node:IsA("Model") and not node:IsA("Folder") and not node:IsA("BasePart") then
			continue
		end
		local kind = category(node.Name)
		if not kind then
			continue
		end
		local collection = false
		for _, child in node:GetChildren() do
			if (child:IsA("Model") or child:IsA("Folder")) and category(child.Name) == kind then
				collection = true
			end
		end
		if collection then
			continue
		end
		local parts = partsOf(node)
		if #parts == 0 or #parts > (if kind == "Lamp" then 16 else 12) then
			continue
		end
		local low, high = bounds(parts)
		local height = high.Y - low.Y
		if height < (if kind == "Tree" then 5 elseif kind == "Lamp" then 4 else 0.2) or height > 160 then
			continue
		end
		if kind == "Tree" and math.max(high.X - low.X, high.Z - low.Z) > height * 2 then
			continue
		end
		table.insert(candidates, { Node = node, Kind = kind, Parts = parts, Low = low, High = high })
	end
	local count = 0
	for _, candidate in candidates do
		local nested = false
		local ancestor = candidate.Node.Parent
		while ancestor and ancestor ~= pack.Parent do
			for _, other in candidates do
				if other.Node == ancestor and other.Kind == candidate.Kind then
					nested = true
				end
			end
			ancestor = ancestor.Parent
		end
		if nested then
			continue
		end
		local model = Instance.new("Model")
		model.Name = candidate.Node.Name
		model:SetAttribute("SourceAssetId", id)
		model:SetAttribute("SourceName", candidate.Node.Name)
		model:SetAttribute("Category", candidate.Kind)
		model:SetAttribute("SourceHeight", candidate.High.Y - candidate.Low.Y)
		local centre = (candidate.Low + candidate.High) / 2
		local origin = Vector3.new(centre.X, candidate.Low.Y, centre.Z)
		for _, part in candidate.Parts do
			local n = string.lower(part.Name)
			if
				n:find("trunk") or (candidate.Kind == "Lamp" and (n:find("pole") or n:find("post") or n:find("base")))
			then
				origin = Vector3.new(part.Position.X, origin.Y, part.Position.Z)
				break
			end
		end
		local rotation = CFrame.new()
		if candidate.Kind == "Lamp" then
			local reach, arm = 0, Vector3.new(0, 0, -1)
			for _, part in candidate.Parts do
				local delta = Vector3.new(part.Position.X - origin.X, 0, part.Position.Z - origin.Z)
				if
					part.Position.Y > candidate.Low.Y + (candidate.High.Y - candidate.Low.Y) * 0.7
					and delta.Magnitude > reach
				then
					reach, arm = delta.Magnitude, delta
				end
			end
			if reach > 0.1 then
				rotation = CFrame.Angles(0, -math.atan2(-arm.X, -arm.Z), 0)
			end
		end
		for _, part in candidate.Parts do
			local n = string.lower(part.Name)
			if n:find("soil") or n:find("particle") then
				continue
			end
			local clone = part:Clone()
			for _, child in clone:GetChildren() do
				if not VISUAL[child.ClassName] then
					child:Destroy()
				else
					for _, descendant in child:GetDescendants() do
						descendant:Destroy()
					end
				end
			end
			clone.Anchored, clone.CanCollide, clone.CanTouch, clone.CanQuery = true, false, false, false
			clone.CFrame = rotation * (clone.CFrame - origin)
			clone.Parent = model
		end
		if #model:GetChildren() == 0 then
			model:Destroy()
			continue
		end
		model.Parent = library:FindFirstChild(candidate.Kind)
		count += 1
	end
	return count
end

function Assets.install(loader: any?, metadata: any?): Folder
	assert(not game:GetService("RunService"):IsRunning(), "Stop Play before importing Creator Store assets")
	local storage = game:GetService("ServerStorage")
	local old = storage:FindFirstChild(NAME)
	assert(not old or old:GetAttribute("ManagedBy") == NAME, "Creator asset folder is occupied by custom content")
	local loadAsset = loader
		or function(id: number): Instance
			return game:GetService("InsertService"):LoadAsset(id)
		end
	local info = metadata
		or function(id: number): any
			return game:GetService("MarketplaceService"):GetProductInfo(id)
		end
	local library = Instance.new("Folder")
	library.Name = NAME
	library:SetAttribute("ManagedBy", NAME)
	library:SetAttribute("AssetVersion", Assets.Version)
	for _, kind in { "Tree", "Shrub", "Fern", "Rock", "Lamp" } do
		local f = Instance.new("Folder")
		f.Name, f.Parent = kind, library
	end
	local loaded: Instance? = nil
	local modelNames = {}
	local okay, err = pcall(function()
		for _, pack in Assets.Packs do
			local product = info(pack.Id)
			assert(
				product.Creator and product.Creator.Id == pack.CreatorId and product.AssetTypeId == 10,
				`Store identity mismatch for {pack.Name}; import stopped`
			)
			loaded = loadAsset(pack.Id)
			assert(loaded, "Asset loader returned no container")
			loaded.Parent = nil
			for _, node in loaded:GetDescendants() do
				if (node:IsA("Model") or node:IsA("Folder")) and #modelNames < 40 then
					table.insert(modelNames, node.Name)
				end
			end
			local count = Assets.extract(loaded :: Instance, pack.Id, library)
			print(`[Ro-Nation:Assets] {pack.Name} ({pack.Id}): {count} visual templates selected.`)
			loaded:Destroy()
			loaded = nil
		end
		assert(
			Assets.count(library, "Tree") > 0 and Assets.count(library, "Lamp") > 0,
			`No complete tree or lamp models recognized. Pack model names: {table.concat(modelNames, ", ")}`
		)
	end)
	if loaded then
		loaded:Destroy()
	end
	if not okay then
		library:Destroy()
		error(`Creator Store import failed; previous library retained: {tostring(err)}`)
	end
	if old then
		old:Destroy()
	end
	library.Parent = storage
	for _, folder in library:GetChildren() do
		print(`[Ro-Nation:Assets] {folder.Name}: {#folder:GetChildren()} imported templates.`)
	end
	return library
end

function Assets.place(
	kind: string,
	variant: number,
	parent: Instance,
	position: Vector3,
	height: number,
	yaw: number
): Model?
	local library = Assets.get()
	local folder = if library then library:FindFirstChild(kind) else nil
	local choices: { Instance } = if folder then folder:GetChildren() else {}
	if #choices == 0 then
		return nil
	end
	table.sort(choices, function(a: Instance, b: Instance)
		return a.Name < b.Name
	end)
	local template = choices[1 + (variant - 1) % #choices]
	local model = template:Clone() :: Model
	local factor = height / (template:GetAttribute("SourceHeight") :: number)
	local frame = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("AssetVersion", Assets.Version)
	model:SetAttribute("GroundPosition", position)
	local highest: BasePart? = nil
	for _, child in model:GetChildren() do
		local part = child :: BasePart
		local localFrame = part.CFrame
		part.Size *= factor
		part.CFrame = frame * (CFrame.new(localFrame.Position * factor) * (localFrame - localFrame.Position))
		if not highest or part.Position.Y > highest.Position.Y then
			highest = part
		end
	end
	if kind == "Tree" then
		Util.cylinder(
			model,
			"TrunkCollision",
			position - Vector3.new(0, 0.5, 0),
			position + Vector3.new(0, height * 0.3, 0),
			math.max(0.6, height * 0.035),
			{ Transparency = 1, CastShadow = false }
		)
	elseif kind == "Lamp" and highest then
		-- Imported mesh axes can point sideways; a world-aligned emitter always shines down.
		-- Keep the PBR fixture itself intact instead of turning the entire mesh into Neon.
		local emitter = Util.part(
			model,
			"LightEmitter",
			CFrame.new(highest.Position.X, position.Y + height - 0.25, highest.Position.Z),
			Vector3.new(0.35, 0.05, 0.35),
			{ Color = Color3.fromRGB(235, 225, 199), Decoration = true }
		)
		emitter:SetAttribute("RoNationLamp", true)
		local light = Instance.new("SpotLight")
		light.Face, light.Range, light.Angle, light.Brightness, light.Enabled = Enum.NormalId.Bottom, 48, 120, 2, false
		light.Color, light.Shadows = Color3.fromRGB(255, 225, 185), false
		light:SetAttribute("RoNationStreetLight", true)
		light.Parent = emitter
	end
	model.Parent = parent
	return model
end

return Assets
