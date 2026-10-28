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
RaycastParams = {
	new = function()
		return {}
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
	elseif key == "Inverse" then
		return function(value)
			return cf(
				v3(-value.r:Dot(value.p), -value.u:Dot(value.p), -value.b:Dot(value.p)),
				v3(value.r.X, value.u.X, value.b.X),
				v3(value.r.Y, value.u.Y, value.b.Y),
				v3(value.r.Z, value.u.Z, value.b.Z)
			)
		end
	elseif key == "ToObjectSpace" then
		return function(value, other)
			return value:Inverse() * other
		end
	elseif key == "PointToObjectSpace" then
		return function(value, point)
			return value:Inverse() * point
		end
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
Vector2 = {
	new = function(x, y)
		checkNumber(x, "Vector2.X")
		checkNumber(y, "Vector2.Y")
		return { X = x, Y = y, __type = "Vector2" }
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
	CollisionFidelity = { "Default", "Hull", "Box", "PreciseConvexDecomposition" },
	RenderFidelity = { "Automatic", "Precise", "Performance" },
	RaycastFilterType = { "Include", "Exclude" },
	HumanoidDisplayDistanceType = { "Viewer", "Subject", "None" },
	HumanoidHealthDisplayType = { "DisplayWhenDamaged", "AlwaysOn", "AlwaysOff" },
	HumanoidRigType = { "R6", "R15" },
	FinishRecordingOperation = { "Cancel", "Commit", "Append" },
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
	Reflectance = "number",
}
local LIGHT = {
	Range = "number",
	Brightness = "number",
	Color = "Color3",
	Shadows = "boolean",
	Enabled = "boolean",
}
local function withLight(extra)
	local props = table.clone(LIGHT)
	for key, value in extra do
		props[key] = value
	end
	return props
end
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
			Enabled = "boolean",
			Size = "UDim2",
			StudsOffsetWorldSpace = "Vector3",
			MaxDistance = "number",
			LightInfluence = "number",
			AlwaysOnTop = "boolean",
		},
		isA = { "BillboardGui", "LayerCollector" },
	},
	WedgePart = { props = {}, base = BASEPART, isA = { "WedgePart", "BasePart", "PVInstance" } },
	UnionOperation = {
		props = { UsePartColor = "boolean", CollisionFidelity = "EnumItem", RenderFidelity = "EnumItem" },
		base = BASEPART,
		isA = { "UnionOperation", "PartOperation", "TriangleMeshPart", "BasePart", "PVInstance" },
	},
	SpecialMesh = {
		props = { MeshType = "EnumItem", TextureId = "string", MeshId = "string" },
		isA = { "SpecialMesh", "DataModelMesh" },
	},
	Seat = {
		props = { Shape = "EnumItem", Disabled = "boolean" },
		base = BASEPART,
		isA = { "Seat", "Part", "FormFactorPart", "BasePart", "PVInstance" },
	},
	Decal = {
		props = { Texture = "string", Face = "EnumItem", Color3 = "Color3", Transparency = "number" },
		isA = { "Decal", "FaceInstance" },
	},
	PointLight = { props = withLight({}), isA = { "PointLight", "Light" } },
	SurfaceLight = { props = withLight({ Face = "EnumItem", Angle = "number" }), isA = { "SurfaceLight", "Light" } },
	Humanoid = {
		props = {
			DisplayDistanceType = "EnumItem",
			HealthDisplayType = "EnumItem",
			BreakJointsOnDeath = "boolean",
			RequiresNeck = "boolean",
			EvaluateStateMachine = "boolean",
		},
		isA = { "Humanoid" },
	},
	Shirt = { props = { ShirtTemplate = "string" }, isA = { "Shirt", "Clothing" } },
	Pants = { props = { PantsTemplate = "string" }, isA = { "Pants", "Clothing" } },
	ShirtGraphic = { props = { Graphic = "string" }, isA = { "ShirtGraphic" } },
	BodyColors = { props = {}, isA = { "BodyColors" } },
	Accessory = { props = {}, isA = { "Accessory", "Accoutrement" } },
	LocalScript = {
		props = { Source = "string" },
		isA = { "LocalScript", "Script", "BaseScript", "LuaSourceContainer" },
	},
	Camera = { props = { CFrame = "CFrame" }, isA = { "Camera" } },
	MeshPart = {
		props = { MeshId = "string", TextureID = "string", DoubleSided = "boolean" },
		base = BASEPART,
		isA = { "MeshPart", "TriangleMeshPart", "BasePart", "PVInstance" },
	},
	SurfaceAppearance = { props = { ColorMap = "string" }, isA = { "SurfaceAppearance" } },
	Script = { props = { Source = "string" }, isA = { "Script", "BaseScript", "LuaSourceContainer" } },
	ModuleScript = { props = { Source = "string" }, isA = { "ModuleScript", "LuaSourceContainer" } },
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
		props = {
			BackgroundTransparency = "number",
			Position = "UDim2",
			Size = "UDim2",
			Image = "string",
			ImageRectOffset = "Vector2",
			ImageRectSize = "Vector2",
		},
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
	assert(
		t == "string" or t == "number" or t == "boolean" or t == "nil" or t == "Vector3",
		`SetAttribute: unsupported type {t}`
	)
	if t == "number" then
		checkNumber(value, "SetAttribute " .. name)
	end
	self.__attributes[name] = value
end
function METHODS.GetAttribute(self, name)
	return self.__attributes[name]
end
function METHODS.Clone(self)
	local copy = newInstance(self.__class, CLASSES[self.__class] == nil)
	for key, value in self.__props do
		copy.__props[key] = value
	end
	for key, value in self.__attributes do
		copy.__attributes[key] = value
	end
	if rawget(self, "__extentOffset") then
		rawset(copy, "__extentOffset", rawget(self, "__extentOffset"))
		rawset(copy, "__extentSize", rawget(self, "__extentSize"))
	end
	for _, child in self.__children do
		local cloned = METHODS.Clone(child)
		cloned.Parent = copy
	end
	return copy
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
function METHODS.IsDescendantOf(self, ancestor)
	if ancestor == nil then
		return false
	end
	local current = rawget(self, "__parent")
	while current do
		if current == ancestor then
			return true
		end
		current = rawget(current, "__parent")
	end
	return false
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

-- Models: pivot, bounding box and uniform scaling, enough for the statue builder.
local function modelParts(model)
	local list = {}
	for _, item in METHODS.GetDescendants(model) do
		local class = CLASSES[item.__class]
		if class and class.base then
			table.insert(list, item)
		end
	end
	return list
end
local function corners(part)
	local frame, size = part.__props.CFrame, part.__props.Size
	local out = {}
	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				table.insert(out, frame * v3(x * size.X / 2, y * size.Y / 2, z * size.Z / 2))
			end
		end
	end
	return out
end
function METHODS.GetPivot(self)
	assert(self.__class == "Model", "GetPivot: only models in this mock")
	local primary = self.__props.PrimaryPart
	if primary then
		return primary.__props.CFrame
	end
	local pivot = rawget(self, "__pivot")
	if not pivot then
		local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
		for _, part in modelParts(self) do
			for _, c in corners(part) do
				for i, axis in { "X", "Y", "Z" } do
					lo[i] = math.min(lo[i], c[axis])
					hi[i] = math.max(hi[i], c[axis])
				end
			end
		end
		assert(lo[1] < math.huge, "GetPivot: model without parts")
		pivot = CFrame.new((lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2)
		rawset(self, "__pivot", pivot)
	end
	return pivot
end
function METHODS.PivotTo(self, target)
	assert(typeOf(target) == "CFrame", "PivotTo: expected a CFrame")
	local delta = target * METHODS.GetPivot(self):Inverse()
	for _, part in modelParts(self) do
		part.__props.CFrame = delta * part.__props.CFrame
	end
	if not self.__props.PrimaryPart then
		rawset(self, "__pivot", target)
	end
end
function METHODS.GetBoundingBox(self)
	local pivot = METHODS.GetPivot(self)
	local rotation = pivot - pivot.p
	local inverse = rotation:Inverse()
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, part in modelParts(self) do
		for _, c in corners(part) do
			local l = inverse * c
			for i, axis in { "X", "Y", "Z" } do
				lo[i] = math.min(lo[i], l[axis])
				hi[i] = math.max(hi[i], l[axis])
			end
		end
	end
	assert(lo[1] < math.huge, "GetBoundingBox: model without parts")
	local centre = v3((lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2)
	return rotation + rotation * centre, v3(hi[1] - lo[1], hi[2] - lo[2], hi[3] - lo[3])
end
function METHODS.GetScale(self)
	return rawget(self, "__scale") or 1
end
function METHODS.ScaleTo(self, scale)
	checkNumber(scale, "ScaleTo")
	assert(scale > 0, "ScaleTo: scale must be positive")
	local factor = scale / METHODS.GetScale(self)
	local pivot = METHODS.GetPivot(self)
	local inverse = pivot:Inverse()
	for _, part in modelParts(self) do
		local relative = inverse * part.__props.CFrame
		part.__props.CFrame = pivot * cf(relative.p * factor, relative.r, relative.u, relative.b)
		part.Size = part.__props.Size * factor
	end
	rawset(self, "__scale", scale)
	MockStats.scaled = (MockStats.scaled or 0) + 1
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
	elseif key == "ExtentsCFrame" and self.__props.CFrame then
		local offset, original = rawget(self, "__extentOffset"), rawget(self, "__extentSize")
		if offset then
			local size = self.__props.Size
			return self.__props.CFrame
				* CFrame.new(
					offset.X * size.X / original.X,
					offset.Y * size.Y / original.Y,
					offset.Z * size.Z / original.Z
				)
		end
		return self.__props.CFrame
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

workspace = service("Workspace", {
	Raycast = function(_, origin, direction, params)
		local surface = MockStats.groundSurface
		assert(surface, "Raycast fixture requires a saved terrain surface")
		local h, _, water = surface(origin.X, origin.Z)
		local y = if water and not params.IgnoreWater then water else h
		if y > origin.Y or y < origin.Y + direction.Y then
			return nil
		end
		local normal = Vector3.new(0, 1, 0)
		if not water or params.IgnoreWater then
			local east, west = surface(origin.X + 3, origin.Z), surface(origin.X - 3, origin.Z)
			local south, north = surface(origin.X, origin.Z + 3), surface(origin.X, origin.Z - 3)
			normal = Vector3.new(-(east - west) / 6, 1, -(south - north) / 6).Unit
		end
		return {
			Position = Vector3.new(origin.X, y, origin.Z),
			Instance = terrain,
			Normal = normal,
			Material = if water and not params.IgnoreWater then Enum.Material.Water else Enum.Material.Grass,
		}
	end,
})
rawset(workspace, "__props", { Name = "Workspace" })
terrain.Parent = workspace
rawget(terrain, "__props").Name = "Terrain"

local camera = newInstance("Camera", false)
rawget(camera, "__props").Name = "Camera"
rawget(workspace, "__props").CurrentCamera = camera
camera.Parent = workspace

-- A small R6-style character standing at the origin and facing +X (so turning it is tested),
-- with clothing, a face, a hat and a script, like a real avatar model.
function MockMakeCharacter()
	local model = newInstance("Model", false)
	model.Name = "Character"
	local turn = CFrame.Angles(0, -math.pi / 2, 0) -- LookVector -Z turned to +X
	local function part(name, x, y, z, sx, sy, sz, className)
		local p = newInstance(className or "Part", false)
		p.Name = name
		p.Size = v3(sx, sy, sz)
		p.CFrame = turn * CFrame.new(x, y, z)
		p.Anchored = false
		p.CanCollide = true
		p.Parent = model
		return p
	end
	local root = part("HumanoidRootPart", 0, 3, 0, 2, 2, 1)
	root.Transparency = 1
	part("Torso", 0, 3, 0, 2, 2, 1)
	local head = part("Head", 0, 4.5, 0, 2, 1, 1)
	part("Left Arm", -1.5, 3, 0, 1, 2, 1)
	part("Right Arm", 1.5, 3, 0, 1, 2, 1)
	part("Left Leg", -0.5, 1, 0, 1, 2, 1)
	part("Right Leg", 0.5, 1, 0, 1, 2, 1, "MeshPart").TextureID = "rbxassetid://1"
	model.PrimaryPart = root
	local face = newInstance("Decal", false)
	face.Name = "face"
	face.Texture = "rbxassetid://2"
	face.Parent = head
	local hat = newInstance("Accessory", false)
	hat.Parent = model
	local handle = part("Handle", 0, 5.3, 0, 1.6, 0.6, 1.6)
	handle.Parent = hat
	local mesh = newInstance("SpecialMesh", false)
	mesh.TextureId = "rbxassetid://3"
	mesh.Parent = handle
	for _, className in { "Shirt", "Pants", "BodyColors", "Humanoid" } do
		newInstance(className, false).Parent = model
	end
	local animate = newInstance("LocalScript", false)
	animate.Name = "Animate"
	animate.Parent = model
	return model
end

local players = service("Players", {
	CreateHumanoidModelFromUserId = function(_, userId)
		checkNumber(userId, "userId")
		MockStats.avatarRequests = (MockStats.avatarRequests or 0) + 1
		if MockStats.avatarFails then
			error("HTTP 403 (Forbidden) [mock]")
		end
		return MockMakeCharacter()
	end,
	GetHumanoidDescriptionFromUserId = function()
		error("HTTP 403 (Forbidden) [mock]")
	end,
})
local history = service("ChangeHistoryService", {
	TryBeginRecording = function()
		MockStats.recordings = (MockStats.recordings or 0) + 1
		return "mock-recording"
	end,
	FinishRecording = function(_, id, operation)
		assert(id == "mock-recording", "FinishRecording: unknown recording")
		MockStats.lastRecording = operation.Name
	end,
})

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
local serverStorage = service("ServerStorage")
local geometry = service("GeometryService", {
	UnionAsync = function(_, main, parts, options)
		assert(main:IsA("BasePart") and #parts > 0, "UnionAsync requires multiple primitives")
		assert(options and options.SplitApart == false, "Canopy unions must remain one reusable part")
		local low, high = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
		local all = { main }
		for _, part in parts do
			table.insert(all, part)
		end
		local inverse = main.CFrame:Inverse()
		for _, part in all do
			assert(
				part:IsA("BasePart") and part:FindFirstChildOfClass("SpecialMesh") == nil,
				"CSG requires actual solid primitives"
			)
			local frame, size = part.CFrame, part.Size
			if part:IsA("Part") and part.Shape == Enum.PartType.Ball then
				local diameter = math.min(size.X, size.Y, size.Z)
				size = Vector3.new(diameter, diameter, diameter)
				MockStats.ballInputs = (MockStats.ballInputs or 0) + 1
			elseif part:IsA("PartOperation") then
				MockStats.solidInputs = (MockStats.solidInputs or 0) + 1
			end
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						local corner = inverse * (frame * Vector3.new(x * size.X / 2, y * size.Y / 2, z * size.Z / 2))
						for i, axis in { "X", "Y", "Z" } do
							low[i] = math.min(low[i], corner[axis])
							high[i] = math.max(high[i], corner[axis])
						end
					end
				end
			end
		end
		local result = newInstance("UnionOperation", false)
		result.CFrame = main.CFrame -- CSG keeps reference space, not the physical centre
		result.Size = Vector3.new(high[1] - low[1], high[2] - low[2], high[3] - low[3])
		rawset(
			result,
			"__extentOffset",
			Vector3.new((low[1] + high[1]) / 2, (low[2] + high[2]) / 2, (low[3] + high[3]) / 2)
		)
		rawset(result, "__extentSize", result.Size)
		result.Material, result.Color = main.Material, main.Color
		result:SetAttribute("MockInputPrimitiveCount", #all)
		MockStats.unionCalls = (MockStats.unionCalls or 0) + 1
		return { result }
	end,
})

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
		elseif name == "ServerStorage" then
			return serverStorage
		elseif name == "GeometryService" then
			return geometry
		elseif name == "Players" then
			return players
		elseif name == "ChangeHistoryService" then
			return history
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
