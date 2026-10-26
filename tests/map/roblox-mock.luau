--!nocheck
-- Minimal stand-ins for the parts of the Roblox API that the map builders use, so the builders
-- can run outside Studio (tests/map/builders.spec.luau). Strict on purpose: unknown properties,
-- unknown enum items, NaN numbers, oversized parts and badly shaped voxel arrays raise errors,
-- like (or stricter than) Roblox would. It does not simulate physics or rendering.

MockStats = {
	instances = 0,
	parts = 0,
	partsByClass = {},
	writeVoxels = 0,
	fillBlocks = 0,
	cells = 0,
	waterCells = 0,
	tags = {},
	probes = {}, -- [i] = { x, z, solidTop, waterTop }
	materialsUsed = {},
	clears = 0,
}

local function isNaN(n)
	return n ~= n
end

local function checkNumber(n, what)
	if type(n) ~= "number" then
		error(`{what}: expected a number, got {type(n)}`, 3)
	end
	if isNaN(n) or n == math.huge or n == -math.huge then
		error(`{what}: invalid number {n}`, 3)
	end
end

-- Vector3 ---------------------------------------------------------------------------------------------
local V3 = {}
local function v3(x, y, z)
	checkNumber(x, "Vector3.X")
	checkNumber(y, "Vector3.Y")
	checkNumber(z, "Vector3.Z")
	return setmetatable({ X = x, Y = y, Z = z, __type = "Vector3" }, V3)
end
V3.__index = function(v, key)
	if key == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif key == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return v3(v.X / m, v.Y / m, v.Z / m)
	elseif key == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	elseif key == "Cross" then
		return function(a, b)
			return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
		end
	elseif key == "Lerp" then
		return function(a, b, t)
			return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
		end
	end
	error(`{key} is not a valid member of Vector3`, 2)
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
Vector3 = {
	new = function(x, y, z)
		return v3(x or 0, y or 0, z or 0)
	end,
}

-- CFrame (position + rotation columns right, up, back) ---------------------------------------------
local CF = {}
local function cf(p, r, u, b)
	return setmetatable({ p = p, r = r, u = u, b = b, __type = "CFrame" }, CF)
end
local function rotate(c, v)
	return c.r * v.X + c.u * v.Y + c.b * v.Z
end
CF.__index = function(c, key)
	if key == "Position" then
		return c.p
	elseif key == "UpVector" then
		return c.u
	elseif key == "LookVector" then
		return -c.b
	elseif key == "RightVector" then
		return c.r
	end
	error(`{key} is not a valid member of CFrame`, 2)
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then
		return cf(a.p + rotate(a, b.p), rotate(a, b.r), rotate(a, b.u), rotate(a, b.b))
	end
	return a.p + rotate(a, b) -- CFrame * Vector3
end
CF.__add = function(a, v)
	return cf(a.p + v, a.r, a.u, a.b)
end
CF.__sub = function(a, v)
	return cf(a.p - v, a.r, a.u, a.b)
end
local X, Y, Z = v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1)
CFrame = {
	new = function(x, y, z)
		if x == nil then
			return cf(v3(0, 0, 0), X, Y, Z)
		elseif type(x) == "table" then
			return cf(x, X, Y, Z)
		end
		return cf(v3(x, y, z), X, Y, Z)
	end,
	lookAt = function(at, target, up)
		up = up or Y
		local look = (target - at).Unit
		local right = look:Cross(up).Unit
		local newUp = right:Cross(look)
		return cf(at, right, newUp, -look)
	end,
	fromMatrix = function(pos, vx, vy, vz)
		vz = vz or vx:Cross(vy)
		return cf(pos, vx, vy, vz)
	end,
	Angles = function(rx, ry, rz)
		local function rot(axis, a)
			local c, s = math.cos(a), math.sin(a)
			if axis == "x" then
				return cf(v3(0, 0, 0), X, v3(0, c, s), v3(0, -s, c))
			elseif axis == "y" then
				return cf(v3(0, 0, 0), v3(c, 0, -s), Y, v3(s, 0, c))
			end
			return cf(v3(0, 0, 0), v3(c, s, 0), v3(-s, c, 0), Z)
		end
		return rot("x", rx) * rot("y", ry) * rot("z", rz)
	end,
}

-- Small value types ---------------------------------------------------------------------------------
Color3 = {
	new = function(r, g, b)
		for _, n in { r, g, b } do
			checkNumber(n, "Color3.new")
			assert(n >= 0 and n <= 1, "Color3.new: component out of range")
		end
		return { R = r, G = g, B = b, __type = "Color3" }
	end,
	fromRGB = function(r, g, b)
		for _, n in { r, g, b } do
			checkNumber(n, "Color3.fromRGB")
			assert(n >= 0 and n <= 255, "Color3.fromRGB: component out of range")
		end
		return { R = r / 255, G = g / 255, B = b / 255, __type = "Color3" }
	end,
}
UDim2 = {
	fromOffset = function(x, y)
		return { __type = "UDim2", xo = x, yo = y }
	end,
	fromScale = function(x, y)
		return { __type = "UDim2", xs = x, ys = y }
	end,
	new = function(xs, xo, ys, yo)
		return { __type = "UDim2", xs = xs, xo = xo, ys = ys, yo = yo }
	end,
}
ColorSequence = {
	new = function(colour)
		return { __type = "ColorSequence", colour = colour }
	end,
}
Region3 = {
	new = function(min, max)
		return { __type = "Region3", Min = min, Max = max }
	end,
}

-- Enums ----------------------------------------------------------------------------------------------
local TERRAIN_MATERIALS = {}
for _, name in
	{
		"Air",
		"Water",
		"Grass",
		"Slate",
		"Concrete",
		"Brick",
		"Sand",
		"WoodPlanks",
		"Rock",
		"Glacier",
		"Snow",
		"Sandstone",
		"Mud",
		"Basalt",
		"Ground",
		"CrackedLava",
		"Asphalt",
		"Cobblestone",
		"Ice",
		"LeafyGrass",
		"Salt",
		"Limestone",
		"Pavement",
	}
do
	TERRAIN_MATERIALS[name] = true
end
local ENUMS = {
	Material = {
		"Plastic",
		"SmoothPlastic",
		"Neon",
		"Wood",
		"WoodPlanks",
		"Marble",
		"Slate",
		"Concrete",
		"Granite",
		"Brick",
		"Pebble",
		"Cobblestone",
		"Rock",
		"Sandstone",
		"Basalt",
		"CrackedLava",
		"Limestone",
		"Pavement",
		"CorrodedMetal",
		"DiamondPlate",
		"Foil",
		"Metal",
		"Grass",
		"LeafyGrass",
		"Sand",
		"Fabric",
		"Snow",
		"Mud",
		"Ground",
		"Asphalt",
		"Salt",
		"Ice",
		"Glacier",
		"Glass",
		"ForceField",
		"Air",
		"Water",
	},
	PartType = { "Ball", "Block", "Cylinder", "Wedge", "CornerWedge" },
	MeshType = { "Brick", "Cylinder", "Sphere", "Wedge", "FileMesh" },
	SurfaceType = { "Smooth", "Studs", "Inlet", "Universal" },
	Font = { "GothamBold", "Gotham", "SourceSans", "SourceSansBold" },
	NormalId = { "Front", "Back", "Top", "Bottom", "Left", "Right" },
	SurfaceGuiSizingMode = { "FixedSize", "PixelsPerStud" },
	ModelStreamingMode = { "Default", "Atomic", "Persistent", "PersistentPerPlayer" },
}
Enum = {}
for enumName, items in ENUMS do
	local enum = {}
	for _, item in items do
		enum[item] = { Name = item, EnumType = enumName, __type = "EnumItem" }
	end
	Enum[enumName] = setmetatable(enum, {
		__index = function(_, key)
			error(`{key} is not a valid member of "Enum.{enumName}"`, 2)
		end,
	})
end

-- Instances --------------------------------------------------------------------------------------------
local COMMON = { Name = "string", Parent = "any", Archivable = "boolean" }
local BASEPART = {
	Anchored = "boolean",
	Size = "Vector3",
	CFrame = "CFrame",
	Material = "EnumItem",
	Color = "Color3",
	Transparency = "number",
	TopSurface = "EnumItem",
	BottomSurface = "EnumItem",
	CanCollide = "boolean",
	CanQuery = "boolean",
	CanTouch = "boolean",
	CastShadow = "boolean",
}
local CLASSES = {
	Workspace = { props = { GlobalWind = "Vector3" }, isA = { "Workspace" } },
	Lighting = {
		props = {
			ClockTime = "number",
			GeographicLatitude = "number",
			Brightness = "number",
			Ambient = "Color3",
			OutdoorAmbient = "Color3",
			ColorShift_Top = "Color3",
			ColorShift_Bottom = "Color3",
			EnvironmentDiffuseScale = "number",
			EnvironmentSpecularScale = "number",
			GlobalShadows = "boolean",
			ShadowSoftness = "number",
			ExposureCompensation = "number",
			FogStart = "number",
			FogEnd = "number",
			FogColor = "Color3",
		},
		isA = { "Lighting" },
	},
	Atmosphere = {
		props = {
			Density = "number",
			Offset = "number",
			Color = "Color3",
			Decay = "Color3",
			Glare = "number",
			Haze = "number",
		},
		isA = { "Atmosphere" },
	},
	BloomEffect = {
		props = { Enabled = "boolean", Intensity = "number", Size = "number", Threshold = "number" },
		isA = { "BloomEffect", "PostEffect" },
	},
	SunRaysEffect = {
		props = { Enabled = "boolean", Intensity = "number", Spread = "number" },
		isA = { "SunRaysEffect", "PostEffect" },
	},
	ColorCorrectionEffect = {
		props = {
			Enabled = "boolean",
			Brightness = "number",
			Contrast = "number",
			Saturation = "number",
			TintColor = "Color3",
		},
		isA = { "ColorCorrectionEffect", "PostEffect" },
	},
	Folder = { props = {}, isA = { "Folder" } },
	Model = { props = { PrimaryPart = "any", ModelStreamingMode = "EnumItem" }, isA = { "Model", "PVInstance" } },
	Part = { props = { Shape = "EnumItem" }, base = BASEPART, isA = { "Part", "BasePart", "PVInstance" } },
	SpawnLocation = {
		props = { Shape = "EnumItem", Neutral = "boolean", Duration = "number", Enabled = "boolean" },
		base = BASEPART,
		isA = { "SpawnLocation", "Part", "BasePart", "PVInstance" },
	},
	BillboardGui = {
		props = {
			Size = "UDim2",
			StudsOffsetWorldSpace = "Vector3",
			MaxDistance = "number",
			LightInfluence = "number",
			AlwaysOnTop = "boolean",
		},
		isA = { "BillboardGui", "LayerCollector" },
	},
	WedgePart = { props = {}, base = BASEPART, isA = { "WedgePart", "BasePart", "PVInstance" } },
	SpecialMesh = { props = { MeshType = "EnumItem" }, isA = { "SpecialMesh", "DataModelMesh" } },
	SpotLight = {
		props = {
			Face = "EnumItem",
			Angle = "number",
			Range = "number",
			Brightness = "number",
			Color = "Color3",
			Shadows = "boolean",
			Enabled = "boolean",
		},
		isA = { "SpotLight", "Light" },
	},
	Attachment = { props = { CFrame = "CFrame" }, isA = { "Attachment" } },
	Beam = {
		props = {
			Attachment0 = "any",
			Attachment1 = "any",
			Width0 = "number",
			Width1 = "number",
			Color = "ColorSequence",
			LightInfluence = "number",
			FaceCamera = "boolean",
			Segments = "number",
			CurveSize0 = "number",
			CurveSize1 = "number",
		},
		isA = { "Beam" },
	},
	Clouds = { props = { Cover = "number", Density = "number", Color = "Color3" }, isA = { "Clouds" } },
	Terrain = {
		props = {
			WaterColor = "Color3",
			WaterTransparency = "number",
			WaterReflectance = "number",
			WaterWaveSize = "number",
			WaterWaveSpeed = "number",
			Decoration = "boolean",
			GlobalWind = "Vector3",
		},
		isA = { "Terrain" },
	},
	Frame = {
		props = {
			BackgroundColor3 = "Color3",
			BackgroundTransparency = "number",
			BorderSizePixel = "number",
			Position = "UDim2",
			Size = "UDim2",
			Rotation = "number",
		},
		isA = { "Frame", "GuiObject" },
	},
	ImageLabel = {
		props = { BackgroundTransparency = "number", Position = "UDim2", Size = "UDim2", Image = "string" },
		isA = { "ImageLabel", "GuiObject" },
	},
	SurfaceGui = {
		props = {
			Face = "EnumItem",
			SizingMode = "EnumItem",
			PixelsPerStud = "number",
			LightInfluence = "number",
			MaxDistance = "number",
		},
		isA = { "SurfaceGui", "LayerCollector" },
	},
	TextLabel = {
		props = {
			Position = "UDim2",
			Size = "UDim2",
			BackgroundTransparency = "number",
			BackgroundColor3 = "Color3",
			BorderSizePixel = "number",
			TextScaled = "boolean",
			Font = "EnumItem",
			TextColor3 = "Color3",
			TextStrokeTransparency = "number",
			Text = "string",
		},
		isA = { "TextLabel", "GuiObject" },
	},
}

local function typeOf(value)
	if type(value) == "table" and value.__type then
		return value.__type
	end
	return type(value)
end

local Inst = {}
local function newInstance(className, isService)
	local class = CLASSES[className]
	if not class and not isService then
		error(`Instance.new: unknown class "{className}" in this mock`, 2)
	end
	MockStats.instances += 1
	local object = setmetatable({
		__class = className,
		__props = { Name = className },
		__children = {},
		__attributes = {},
		__parent = nil,
		__destroyed = false,
	}, Inst)
	if class and class.base then
		MockStats.parts += 1
		MockStats.partsByClass[className] = (MockStats.partsByClass[className] or 0) + 1
		object.__props.Size = v3(4, 1, 2)
		object.__props.CFrame = CFrame.new()
		object.__props.Transparency = 0
	end
	return object
end

local METHODS = {}
function METHODS.SetAttribute(self, name, value)
	assert(type(name) == "string", "SetAttribute: name must be a string")
	local t = typeOf(value)
	assert(t == "string" or t == "number" or t == "boolean" or t == "nil", `SetAttribute: unsupported type {t}`)
	if t == "number" then
		checkNumber(value, "SetAttribute " .. name)
	end
	self.__attributes[name] = value
end
function METHODS.GetAttribute(self, name)
	return self.__attributes[name]
end
function METHODS.GetChildren(self)
	return table.clone(self.__children)
end
function METHODS.GetDescendants(self)
	local out = {}
	local function walk(node)
		for _, child in node.__children do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end
function METHODS.FindFirstChildOfClass(self, className)
	for _, child in self.__children do
		if child.__class == className then
			return child
		end
	end
	return nil
end
function METHODS.SetMaterialColor(self, material, colour)
	assert(self.__class == "Terrain", "SetMaterialColor is a Terrain method")
	assert(typeOf(material) == "EnumItem" and TERRAIN_MATERIALS[material.Name], "SetMaterialColor: bad material")
	assert(typeOf(colour) == "Color3", "SetMaterialColor: bad colour")
	MockStats.materialColours = (MockStats.materialColours or 0) + 1
end
function METHODS.FindFirstChild(self, name)
	for _, child in self.__children do
		if child.__props.Name == name then
			return child
		end
	end
	return nil
end
function METHODS.WaitForChild(self, name)
	return METHODS.FindFirstChild(self, name) or error(`WaitForChild would wait forever for {name}`)
end
function METHODS.IsA(self, className)
	if className == "Instance" or className == self.__class then
		return true
	end
	local class = CLASSES[self.__class]
	return class ~= nil and table.find(class.isA, className) ~= nil
end
function METHODS.Destroy(self)
	local old = rawget(self, "__parent")
	if old then
		local siblings = old.__children
		table.remove(siblings, table.find(siblings, self))
	end
	rawset(self, "__parent", nil)
	rawset(self, "__destroyed", true)
end

Inst.__index = function(self, key)
	local methods = rawget(self, "__methods")
	local method = METHODS[key] or (methods and methods[key])
	if method then
		return method
	end
	if key == "Parent" then
		return rawget(self, "__parent")
	elseif key == "ClassName" then
		return self.__class
	elseif key == "Position" and self.__props.CFrame and CLASSES[self.__class] and CLASSES[self.__class].base then
		return self.__props.CFrame.p
	end
	local value = self.__props[key]
	if value ~= nil then
		return value
	end
	local child = METHODS.FindFirstChild(self, key)
	if child then
		return child
	end
	local class = CLASSES[self.__class]
	if class and (class.props[key] or (class.base and class.base[key]) or COMMON[key]) then
		return nil
	end
	error(`{key} is not a valid member of {self.__class} "{self.__props.Name}"`, 2)
end
Inst.__newindex = function(self, key, value)
	if self.__destroyed then
		error("cannot change a destroyed instance", 2)
	end
	if key == "Parent" then
		local old = rawget(self, "__parent")
		if old then
			local siblings = old.__children
			table.remove(siblings, table.find(siblings, self))
		end
		rawset(self, "__parent", value)
		if value then
			table.insert(value.__children, self)
		end
		return
	end
	local class = CLASSES[self.__class]
	local expected = COMMON[key] or (class and (class.props[key] or (class.base and class.base[key])))
	if not expected then
		error(`{key} is not a valid member of {self.__class}`, 2)
	end
	if expected ~= "any" and typeOf(value) ~= expected then
		error(`{self.__class}.{key}: expected {expected}, got {typeOf(value)}`, 2)
	end
	if expected == "number" then
		checkNumber(value, `{self.__class}.{key}`)
	end
	if key == "Size" and class and class.base then
		for _, axis in { "X", "Y", "Z" } do
			local n = value[axis]
			if n <= 0 or n > 2048 then
				error(`{self.__class}.Size.{axis} = {n} is outside 0..2048`, 2)
			end
		end
	end
	if key == "Material" and value.EnumType ~= "Material" then
		error("Material must be an Enum.Material item", 2)
	end
	self.__props[key] = value
end

Instance = {
	new = function(className)
		return newInstance(className, false)
	end,
}

-- Services -------------------------------------------------------------------------------------------------
local function service(name, methods)
	local object = newInstance(name, true)
	rawset(object, "__methods", methods or {})
	return object
end

local function checkTerrainMaterial(material)
	if typeOf(material) ~= "EnumItem" or material.EnumType ~= "Material" then
		error("terrain material must be an Enum.Material item", 3)
	end
	if not TERRAIN_MATERIALS[material.Name] then
		error(`{material.Name} cannot be used for terrain`, 3)
	end
	MockStats.materialsUsed[material.Name] = true
end

local terrain = service("Terrain", {
	Clear = function()
		MockStats.clears += 1
	end,
	FillBlock = function(_, frame, size, material)
		assert(typeOf(frame) == "CFrame" and typeOf(size) == "Vector3", "FillBlock: bad arguments")
		checkTerrainMaterial(material)
		assert(size.X > 0 and size.Y > 0 and size.Z > 0, "FillBlock: empty block")
		MockStats.fillBlocks += 1
	end,
	WriteVoxels = function(_, region, resolution, materials, occupancy)
		assert(resolution == 4, "WriteVoxels: resolution must be 4")
		local min, max = region.Min, region.Max
		for _, axis in { "X", "Y", "Z" } do
			assert(min[axis] % 4 == 0 and max[axis] % 4 == 0, `WriteVoxels: region not aligned on {axis}`)
		end
		local nx, ny, nz = (max.X - min.X) / 4, (max.Y - min.Y) / 4, (max.Z - min.Z) / 4
		assert(#materials == nx and #occupancy == nx, "WriteVoxels: wrong X size")
		for x = 1, nx do
			assert(#materials[x] == ny and #occupancy[x] == ny, "WriteVoxels: wrong Y size")
			for y = 1, ny do
				local mRow, oRow = materials[x][y], occupancy[x][y]
				assert(#mRow == nz and #oRow == nz, "WriteVoxels: wrong Z size")
				for z = 1, nz do
					local m, o = mRow[z], oRow[z]
					checkTerrainMaterial(m)
					checkNumber(o, "occupancy")
					assert(o >= 0 and o <= 1, "occupancy outside 0..1")
					if m.Name == "Water" then
						MockStats.waterCells += 1
					end
				end
			end
		end
		MockStats.cells += nx * ny * nz
		MockStats.writeVoxels += 1
		-- Probes: rebuild the surface height of a few columns from the voxels.
		for _, probe in MockStats.probes do
			if probe.x >= min.X and probe.x < max.X and probe.z >= min.Z and probe.z < max.Z then
				local ix = math.floor((probe.x - min.X) / 4) + 1
				local iz = math.floor((probe.z - min.Z) / 4) + 1
				local solidTop, waterTop = min.Y, nil
				for y = 1, ny do
					local m, o = materials[ix][y][iz], occupancy[ix][y][iz]
					if m.Name == "Water" then
						waterTop = min.Y + (y - 1) * 4 + o * 4
					elseif m.Name ~= "Air" and o > 0 then
						solidTop = min.Y + (y - 1) * 4 + o * 4
					end
				end
				probe.solidTop, probe.waterTop = solidTop, waterTop
			end
		end
	end,
})

workspace = service("Workspace")
rawset(workspace, "__props", { Name = "Workspace" })
terrain.Parent = workspace
rawget(terrain, "__props").Name = "Terrain"

local collection = service("CollectionService", {
	AddTag = function(_, instance, tag)
		MockStats.tags[tag] = (MockStats.tags[tag] or 0) + 1
		local tags = rawget(instance, "__tags") or {}
		tags[tag] = true
		rawset(instance, "__tags", tags)
	end,
	HasTag = function(_, instance, tag)
		local tags = rawget(instance, "__tags")
		return tags ~= nil and tags[tag] == true
	end,
})
local runService = service("RunService", {
	IsRunning = function()
		return false
	end,
})
local lighting = service("Lighting")

game = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return __requireNode("ReplicatedStorage")
		elseif name == "Workspace" then
			return workspace
		elseif name == "CollectionService" then
			return collection
		elseif name == "RunService" then
			return runService
		elseif name == "Lighting" then
			return lighting
		end
		error(`GetService: {name} is not in this mock`)
	end,
}

task = {
	wait = function()
		return 0
	end,
}

function warn(...)
	print("WARN", ...)
end

-- Adds the default template objects a new Baseplate place has.
function MockAddTemplate()
	local baseplate = Instance.new("Part")
	baseplate.Name = "Baseplate"
	baseplate.Parent = workspace
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Parent = workspace
end
