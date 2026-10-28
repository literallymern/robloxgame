--!strict
-- Building kit for the Gundiville government district: axis-aligned boxes, walls with
-- openings, windows, columns, pediments, roofs, a dome, flags, lamps, trees and furniture.
-- Everything is anchored; positions are world studs. Built on the map builders' Util.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Util = require(script.Parent.Parent.Map.Builders.Util)
local CreatorAssets = require(script.Parent.Parent.Map.CreatorAssets)

local Kit = {}

export type Rect = { MinX: number, MaxX: number, MinZ: number, MaxZ: number }
export type Options = Util.PartOptions

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Palette: cream limestone and white marble for the Congress (see the city reference guide),
-- white plaster with a red tile roof for the Hausali, sandstone and granite for the bank.
Kit.Style = table.freeze({
	Limestone = { Material = Enum.Material.Limestone, Color = rgb(228, 218, 196) } :: Options,
	Marble = { Material = Enum.Material.Marble, Color = rgb(240, 236, 226) } :: Options,
	Granite = { Material = Enum.Material.Granite, Color = rgb(150, 146, 140) } :: Options,
	DarkGranite = { Material = Enum.Material.Granite, Color = rgb(96, 94, 92) } :: Options,
	Plaster = { Material = Enum.Material.SmoothPlastic, Color = rgb(242, 238, 228) } :: Options,
	Ochre = { Material = Enum.Material.SmoothPlastic, Color = rgb(214, 178, 112) } :: Options,
	Sandstone = { Material = Enum.Material.Sandstone, Color = rgb(206, 180, 140) } :: Options,
	Slate = { Material = Enum.Material.Slate, Color = rgb(70, 80, 92) } :: Options,
	Tile = { Material = Enum.Material.Slate, Color = rgb(160, 74, 52) } :: Options,
	Copper = { Material = Enum.Material.Metal, Color = rgb(96, 142, 126) } :: Options,
	Gold = { Material = Enum.Material.Foil, Color = rgb(212, 172, 72) } :: Options,
	Bronze = { Material = Enum.Material.Metal, Color = rgb(112, 84, 52) } :: Options,
	Iron = { Material = Enum.Material.Metal, Color = rgb(44, 48, 46) } :: Options,
	Glass = { Material = Enum.Material.Glass, Color = rgb(70, 96, 118), Reflectance = 0.15 } :: Options,
	Wood = { Material = Enum.Material.WoodPlanks, Color = rgb(122, 84, 54) } :: Options,
	DarkWood = { Material = Enum.Material.Wood, Color = rgb(78, 52, 36) } :: Options,
	Carpet = { Material = Enum.Material.Fabric, Color = rgb(128, 30, 36) } :: Options,
	Floor = { Material = Enum.Material.Marble, Color = rgb(214, 206, 192) } :: Options,
	Asphalt = { Material = Enum.Material.Asphalt, Color = rgb(64, 66, 68) } :: Options,
	Kerb = { Material = Enum.Material.Concrete, Color = rgb(176, 172, 164) } :: Options,
	Paving = { Material = Enum.Material.Pavement, Color = rgb(196, 188, 174) } :: Options,
	Lawn = { Material = Enum.Material.Grass, Color = rgb(88, 132, 64) } :: Options,
	Hedge = { Material = Enum.Material.LeafyGrass, Color = rgb(58, 96, 48) } :: Options,
	Soil = { Material = Enum.Material.Ground, Color = rgb(96, 70, 50) } :: Options,
	Paint = { Material = Enum.Material.SmoothPlastic, Color = rgb(236, 236, 230), Decoration = true } :: Options,
	Water = {
		Material = Enum.Material.Glass,
		Color = rgb(70, 130, 150),
		Transparency = 0.25,
		CanCollide = false,
	} :: Options,
})

local function with(base: Options, extra: Options): Options
	local o = table.clone(base)
	for key, value in extra :: any do
		(o :: any)[key] = value
	end
	return o
end
Kit.with = with

-- A plain folder. The district is marked once at its root (GeneratedBy = "BuildGundiville");
-- nothing inside carries the BuildMap mark, so BuildMap reruns and terrain refreshes treat the
-- district as construction to keep and protect.
function Kit.folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- A model for one building, with its display name as an attribute.
function Kit.model(parent: Instance, name: string, building: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("Building", building)
	model.Parent = parent
	return model
end

local count = 0
local footingGround: number? = nil
local footingY: number? = nil

-- When the district stands above its planned ground (see Ground.luau), boxes that reach down to
-- the ground continue down to `footing`, so no gap shows where the terrain is lower. Call with
-- nil to switch it off.
function Kit.setFooting(ground: number?, footing: number?)
	footingGround, footingY = ground, footing
end

-- Number of BaseParts built since the last reset (the district budget is checked with it).
function Kit.resetCount()
	count = 0
end
function Kit.partCount(): number
	return count
end
function Kit.add(n: number)
	count += n
end

-- Axis-aligned box between two corners.
function Kit.box(
	parent: Instance,
	name: string,
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number,
	options: Options?
): Part
	local lo = Vector3.new(math.min(x0, x1), math.min(y0, y1), math.min(z0, z1))
	local hi = Vector3.new(math.max(x0, x1), math.max(y0, y1), math.max(z0, z1))
	if footingGround and footingY and lo.Y <= footingGround + 1e-3 and lo.Y > footingY then
		lo = Vector3.new(lo.X, footingY, lo.Z)
	end
	local size = hi - lo
	assert(size.X > 0 and size.Y > 0 and size.Z > 0, `Kit.box {name}: empty box`)
	count += 1
	return Util.part(parent, name, CFrame.new((lo + hi) / 2), size, options)
end

function Kit.slab(parent: Instance, name: string, r: Rect, y0: number, y1: number, options: Options?): Part
	return Kit.box(parent, name, r.MinX, y0, r.MinZ, r.MaxX, y1, r.MaxZ, options)
end

function Kit.rect(minX: number, maxX: number, minZ: number, maxZ: number): Rect
	return { MinX = minX, MaxX = maxX, MinZ = minZ, MaxZ = maxZ }
end

-- The overlap of two rectangles, or nil when they only touch or do not meet.
function Kit.intersect(a: Rect, b: Rect): Rect?
	local minX, maxX = math.max(a.MinX, b.MinX), math.min(a.MaxX, b.MaxX)
	local minZ, maxZ = math.max(a.MinZ, b.MinZ), math.min(a.MaxZ, b.MaxZ)
	if maxX - minX < 0.01 or maxZ - minZ < 0.01 then
		return nil
	end
	return { MinX = minX, MaxX = maxX, MinZ = minZ, MaxZ = maxZ }
end

function Kit.inset(r: Rect, d: number): Rect
	return { MinX = r.MinX + d, MaxX = r.MaxX - d, MinZ = r.MinZ + d, MaxZ = r.MaxZ - d }
end

-- Splits `pieces` so that nothing remains inside `cutter`. Rectangles only touch afterwards.
function Kit.subtract(pieces: { Rect }, cutter: Rect): { Rect }
	local out: { Rect } = {}
	for _, r in pieces do
		if cutter.MaxX <= r.MinX or cutter.MinX >= r.MaxX or cutter.MaxZ <= r.MinZ or cutter.MinZ >= r.MaxZ then
			table.insert(out, r)
			continue
		end
		local x0, x1 = math.max(r.MinX, cutter.MinX), math.min(r.MaxX, cutter.MaxX)
		if cutter.MinZ > r.MinZ then
			table.insert(out, { MinX = r.MinX, MaxX = r.MaxX, MinZ = r.MinZ, MaxZ = cutter.MinZ })
		end
		if cutter.MaxZ < r.MaxZ then
			table.insert(out, { MinX = r.MinX, MaxX = r.MaxX, MinZ = cutter.MaxZ, MaxZ = r.MaxZ })
		end
		local z0, z1 = math.max(r.MinZ, cutter.MinZ), math.min(r.MaxZ, cutter.MaxZ)
		if x0 > r.MinX then
			table.insert(out, { MinX = r.MinX, MaxX = x0, MinZ = z0, MaxZ = z1 })
		end
		if x1 < r.MaxX then
			table.insert(out, { MinX = x1, MaxX = r.MaxX, MinZ = z0, MaxZ = z1 })
		end
	end
	return out
end

function Kit.subtractAll(pieces: { Rect }, cutters: { Rect }): { Rect }
	local out = pieces
	for _, cutter in cutters do
		out = Kit.subtract(out, cutter)
	end
	return out
end

export type Opening = { From: number, To: number, Bottom: number, Top: number }

-- A straight wall along the X axis (`axis` = "X", at Z = `at`) or the Z axis (at X = `at`),
-- from `a` to `b`, `thickness` thick, between heights y0 and y1, with rectangular openings
-- (doorways, arches) given in the same coordinates. Returns the number of parts.
function Kit.wall(
	parent: Instance,
	name: string,
	axis: "X" | "Z",
	a: number,
	b: number,
	at: number,
	thickness: number,
	y0: number,
	y1: number,
	openings: { Opening }?,
	options: Options?
): number
	local list = table.clone(openings or {})
	table.sort(list, function(p: Opening, q: Opening)
		return p.From < q.From
	end)
	local built = 0
	local function piece(s0: number, s1: number, h0: number, h1: number)
		if s1 - s0 < 0.01 or h1 - h0 < 0.01 then
			return
		end
		if axis == "X" then
			Kit.box(parent, name, s0, h0, at - thickness / 2, s1, h1, at + thickness / 2, options)
		else
			Kit.box(parent, name, at - thickness / 2, h0, s0, at + thickness / 2, h1, s1, options)
		end
		built += 1
	end
	local cursor = math.min(a, b)
	local finish = math.max(a, b)
	for _, o in list do
		local from, to = math.max(o.From, cursor), math.min(o.To, finish)
		if to <= from then
			continue
		end
		piece(cursor, from, y0, y1)
		piece(from, to, y0, math.max(y0, o.Bottom))
		piece(from, to, math.min(y1, o.Top), y1)
		cursor = to
	end
	piece(cursor, finish, y0, y1)
	return built
end

-- A face of a building: the outer surface of a wall, perpendicular to X or Z.
export type Face = { Axis: "X" | "Z", At: number, Out: number } -- Out = +1 or -1 (outward)

local function faceBox(
	parent: Instance,
	name: string,
	face: Face,
	s0: number,
	s1: number,
	y0: number,
	y1: number,
	d0: number,
	d1: number,
	options: Options?
): Part
	-- d0..d1: distance from the wall surface, positive outwards
	local p0, p1 = face.At + face.Out * d0, face.At + face.Out * d1
	if face.Axis == "X" then -- surface perpendicular to X: s runs along Z
		return Kit.box(parent, name, p0, y0, s0, p1, y1, s1, options)
	end
	return Kit.box(parent, name, s0, y0, p0, s1, y1, p1, options)
end
Kit.faceBox = faceBox

export type WindowSpec = {
	Width: number,
	Height: number,
	Spacing: number,
	Sills: { number }, -- bottom Y of each row of windows
	Skip: { { number } }?, -- along-face ranges without windows (entrances, risalits)
	Lintel: boolean?,
	Glass: Options?,
	Trim: Options?,
	Shutters: Options?, -- open shutters: a coloured panel half a window wide on each side
}

-- Rows of windows on a face between s0 and s1 (along the face). Glass sits slightly proud of
-- the wall, with a sill below and optionally a lintel above. Returns the number of windows.
function Kit.windows(parent: Instance, face: Face, s0: number, s1: number, spec: WindowSpec): number
	local n = math.floor((s1 - s0) / spec.Spacing)
	if n < 1 then
		return 0
	end
	local start = (s0 + s1) / 2 - (n - 1) * spec.Spacing / 2
	local built = 0
	for i = 0, n - 1 do
		local s = start + i * spec.Spacing
		local skipped = false
		local skip: { { number } } = spec.Skip or {}
		for _, range in skip do
			if s + spec.Width / 2 > range[1] and s - spec.Width / 2 < range[2] then
				skipped = true
			end
		end
		if skipped then
			continue
		end
		for _, y in spec.Sills do
			local a, b = s - spec.Width / 2, s + spec.Width / 2
			faceBox(parent, "Window", face, a, b, y, y + spec.Height, -0.2, 0.15, spec.Glass or Kit.Style.Glass)
			if spec.Shutters then
				local w = spec.Width / 2
				faceBox(parent, "Shutters", face, a - w, b + w, y, y + spec.Height, -0.2, 0.08, spec.Shutters)
			end
			faceBox(parent, "Sill", face, a - 0.6, b + 0.6, y - 0.7, y, -0.2, 0.9, spec.Trim or Kit.Style.Marble)
			if spec.Lintel then
				faceBox(
					parent,
					"Lintel",
					face,
					a - 0.4,
					b + 0.4,
					y + spec.Height,
					y + spec.Height + 0.9,
					-0.2,
					0.6,
					spec.Trim or Kit.Style.Marble
				)
			end
			built += 1
		end
	end
	return built
end

-- A round column standing on a square base, with a square capital.
function Kit.column(
	parent: Instance,
	x: number,
	z: number,
	y0: number,
	y1: number,
	diameter: number,
	options: Options?
): number
	local o = options or Kit.Style.Marble
	local b = diameter * 0.65
	Kit.box(parent, "ColumnBase", x - b, y0, z - b, x + b, y0 + 1, z + b, o)
	count += 1
	Util.cylinder(parent, "Column", Vector3.new(x, y0 + 1, z), Vector3.new(x, y1 - 1.2, z), diameter, o)
	local c = diameter * 0.7
	Kit.box(parent, "Capital", x - c, y1 - 1.2, z - c, x + c, y1, z + c, o)
	return 3
end

-- A triangular gable (pediment) on a face: base from s0 to s1 at height y, `height` tall,
-- from d0 to d1 in front of the face. Two wedges.
function Kit.pediment(
	parent: Instance,
	face: Face,
	s0: number,
	s1: number,
	y: number,
	height: number,
	d0: number,
	d1: number,
	options: Options?
): number
	local mid = (s0 + s1) / 2
	local half = (s1 - s0) / 2
	local p = face.At + face.Out * (d0 + d1) / 2
	local depth = math.abs(d1 - d0)
	for _, side in { -1, 1 } do
		-- The wedge is high at its back (+Z local) and low at the front (LookVector).
		local centreS = mid + side * half / 2
		local centre = if face.Axis == "Z"
			then Vector3.new(centreS, y + height / 2, p)
			else Vector3.new(p, y + height / 2, centreS)
		local look = if face.Axis == "Z" then Vector3.new(side, 0, 0) else Vector3.new(0, 0, side)
		Util.wedge(parent, "Pediment", CFrame.lookAt(centre, centre + look), Vector3.new(depth, height, half), options)
		count += 1
	end
	return 2
end

-- A gable roof over a rectangle, ridge along `ridge` ("X" or "Z"), from height y up by `height`.
function Kit.gableRoof(
	parent: Instance,
	r: Rect,
	y: number,
	height: number,
	ridge: "X" | "Z",
	overhang: number,
	options: Options?
): number
	local e = Kit.inset(r, -overhang)
	local cx, cz = (e.MinX + e.MaxX) / 2, (e.MinZ + e.MaxZ) / 2
	for _, side in { -1, 1 } do
		if ridge == "X" then
			local halfDepth = (e.MaxZ - e.MinZ) / 2
			local centre = Vector3.new(cx, y + height / 2, cz + side * halfDepth / 2)
			Util.wedge(
				parent,
				"Roof",
				CFrame.lookAt(centre, centre + Vector3.new(0, 0, side)),
				Vector3.new(e.MaxX - e.MinX, height, halfDepth),
				options
			)
		else
			local halfWidth = (e.MaxX - e.MinX) / 2
			local centre = Vector3.new(cx + side * halfWidth / 2, y + height / 2, cz)
			Util.wedge(
				parent,
				"Roof",
				CFrame.lookAt(centre, centre + Vector3.new(side, 0, 0)),
				Vector3.new(e.MaxZ - e.MinZ, height, halfWidth),
				options
			)
		end
		count += 1
	end
	return 2
end

export type Gap = { Side: string, From: number, To: number } -- Side: "North", "South", "West" or "East"

-- A horizontal band (string course, cornice) around the outside of a rectangular building,
-- `proud` studs in front of its walls and 0.5 into them, so the interior stays free. `gaps`
-- leave out stretches of a side (portals). North = -Z, as everywhere on the map.
function Kit.band(
	parent: Instance,
	name: string,
	r: Rect,
	y0: number,
	y1: number,
	proud: number,
	options: Options?,
	gaps: { Gap }?
): number
	local t = proud + 0.5
	local function holes(side: string): { Opening }
		local list: { Opening } = {}
		local all: { Gap } = gaps or {}
		for _, g in all do
			if g.Side == side then
				table.insert(list, { From = g.From, To = g.To, Bottom = y0 - 1, Top = y1 + 1 })
			end
		end
		return list
	end
	local x0, x1 = r.MinX - proud, r.MaxX + proud
	local built = Kit.wall(parent, name, "X", x0, x1, r.MinZ - proud + t / 2, t, y0, y1, holes("North"), options)
	built += Kit.wall(parent, name, "X", x0, x1, r.MaxZ + proud - t / 2, t, y0, y1, holes("South"), options)
	built += Kit.wall(parent, name, "Z", r.MinZ + 0.5, r.MaxZ - 0.5, x0 + t / 2, t, y0, y1, holes("West"), options)
	built += Kit.wall(parent, name, "Z", r.MinZ + 0.5, r.MaxZ - 0.5, x1 - t / 2, t, y0, y1, holes("East"), options)
	return built
end

-- A glowing ceiling panel with a point light (interiors; always on).
function Kit.ceilingLight(parent: Instance, x: number, z: number, y: number, size: number, range: number): Part
	local h = size / 2
	local lamp = Kit.box(
		parent,
		"CeilingLight",
		x - h,
		y - 0.5,
		z - h,
		x + h,
		y,
		z + h,
		{ Material = Enum.Material.Neon, Color = rgb(255, 240, 214), CastShadow = false, CanCollide = false }
	)
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = 1.1
	light.Color = rgb(255, 236, 206)
	light.Shadows = false
	light.Parent = lamp
	return lamp
end

-- A low parapet with a coping along the edge of a flat roof (a simple balustrade).
function Kit.parapet(parent: Instance, r: Rect, y: number, height: number, options: Options?): number
	local t = 1.2
	local o = options or Kit.Style.Limestone
	Kit.box(parent, "Parapet", r.MinX, y, r.MinZ, r.MaxX, y + height, r.MinZ + t, o)
	Kit.box(parent, "Parapet", r.MinX, y, r.MaxZ - t, r.MaxX, y + height, r.MaxZ, o)
	Kit.box(parent, "Parapet", r.MinX, y, r.MinZ + t, r.MinX + t, y + height, r.MaxZ - t, o)
	Kit.box(parent, "Parapet", r.MaxX - t, y, r.MinZ + t, r.MaxX, y + height, r.MaxZ - t, o)
	return 4
end

-- A vertical cylinder (axis up) from y0 to y1.
function Kit.drum(parent: Instance, name: string, x: number, z: number, y0: number, y1: number, d: number, o: Options?)
	count += 1
	return Util.cylinder(parent, name, Vector3.new(x, y0, z), Vector3.new(x, y1, z), d, o)
end

-- An ellipsoid (sphere mesh) centred at `centre`.
function Kit.ellipsoid(parent: Instance, name: string, centre: Vector3, size: Vector3, o: Options?): Part
	count += 1
	return Util.ellipsoid(parent, name, CFrame.new(centre), size, o)
end

local Assets = require(ReplicatedStorage.Shared.Config.Assets)

-- An image on the front face of a thin, invisible board (flag, emblem). `look` is the direction
-- the image faces. Size: width x height of the image.
function Kit.image(
	parent: Instance,
	name: string,
	centre: Vector3,
	look: Vector3,
	width: number,
	height: number,
	image: string
): Part
	local board = Util.part(
		parent,
		name,
		CFrame.lookAt(centre, centre + look),
		Vector3.new(width, height, 0.1),
		{ Transparency = 1, Decoration = true }
	)
	count += 1
	local decal = Instance.new("Decal")
	decal.Texture = image
	decal.Face = Enum.NormalId.Front
	decal.Parent = board
	return board
end

local FLAG_PIXELS = Vector2.new(1024, 609) -- size of the uploaded flag image

-- A flagpole with the national flag. `out` is the direction the flag flies from the pole.
function Kit.flagpole(parent: Instance, base: Vector3, height: number, flagWidth: number, out: Vector3): number
	local pole = Kit.Style.Iron
	Util.cylinder(parent, "Flagpole", base, base + Vector3.new(0, height, 0), math.max(0.35, height / 90), pole)
	Kit.ellipsoid(parent, "Finial", base + Vector3.new(0, height + 0.3, 0), Vector3.new(0.9, 0.9, 0.9), Kit.Style.Gold)
	count += 1
	local flagHeight = flagWidth * FLAG_PIXELS.Y / FLAG_PIXELS.X
	local dir = Vector3.new(out.X, 0, out.Z).Unit
	local centre = base + Vector3.new(0, height - 0.6 - flagHeight / 2, 0) + dir * (flagWidth / 2 + 0.3)
	-- The flag board faces sideways (perpendicular to the direction it flies).
	local facing = Vector3.new(-dir.Z, 0, dir.X)
	local flag = Kit.image(parent, "Flag", centre, facing, flagWidth, flagHeight, Assets.Images.Flag)
	flag:SetAttribute("NationalFlag", true)
	-- The back shows the flag mirrored, as on a real flag, so the hoist is at the pole from both
	-- sides. A negative ImageRectSize draws the image flipped horizontally.
	local back = Instance.new("SurfaceGui")
	back.Name = "FlagBack"
	back.Face = Enum.NormalId.Back
	back.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	back.PixelsPerStud = 50
	back.LightInfluence = 1
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = Assets.Images.Flag
	image.ImageRectOffset = Vector2.new(FLAG_PIXELS.X, 0)
	image.ImageRectSize = Vector2.new(-FLAG_PIXELS.X, FLAG_PIXELS.Y)
	image.Parent = back
	back.Parent = flag
	return 3
end

-- The round national emblem on a face, `diameter` across, centred at (s, y) on the face.
function Kit.emblem(parent: Instance, face: Face, s: number, y: number, diameter: number, d: number?): Part
	local p = face.At + face.Out * (d or 0.3)
	local centre = if face.Axis == "Z" then Vector3.new(s, y, p) else Vector3.new(p, y, s)
	local look = if face.Axis == "Z" then Vector3.new(0, 0, face.Out) else Vector3.new(face.Out, 0, 0)
	local emblem = Kit.image(parent, "Emblem", centre, look, diameter, diameter, Assets.Images.Emblem)
	emblem:SetAttribute("NationalEmblem", true)
	return emblem
end

-- Text on the front face of `board` (one line per entry).
function Kit.inscription(board: BasePart, lines: { string }, colour: Color3, face: Enum.NormalId?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.MaxDistance = 400
	for i, line in lines do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.04, (i - 1) / #lines)
		label.Size = UDim2.fromScale(0.92, 1 / #lines)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = colour
		label.TextStrokeTransparency = 1
		label.Text = line
		label.Parent = gui
	end
	gui.Parent = board
end

-- A street light that the environment controller switches on at dusk (same attributes as the
-- road lights). `arms` are directions; one lantern per arm. Uses the City Props Pack lamp when
-- the Creator Store library was imported (StudioTools.UseCreatorStoreAssets).
function Kit.lamp(parent: Instance, base: Vector3, height: number, arms: { Vector3 }, variant: number?): number
	if CreatorAssets.get() then
		-- The imported street light has one arm; it points along the first requested arm. (Two
		-- copies on one spot would make their identical poles flicker.)
		local arm = arms[1]
		local model = CreatorAssets.place("Lamp", variant or 1, parent, base, height, math.atan2(-arm.X, -arm.Z))
		if model then
			model.Name = "StreetLamp"
			local built = 0
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					built += 1
				end
			end
			count += built
			return built
		end
	end
	local metal = Kit.Style.Iron
	Util.cylinder(parent, "LampPost", base - Vector3.new(0, 0.5, 0), base + Vector3.new(0, height, 0), 0.7, metal)
	Kit.box(parent, "LampFoot", base.X - 0.8, base.Y, base.Z - 0.8, base.X + 0.8, base.Y + 1.6, base.Z + 0.8, metal)
	count += 1
	local built = 2
	for _, arm in arms do
		local dir = Vector3.new(arm.X, 0, arm.Z).Unit
		local top = base + Vector3.new(0, height - 0.6, 0)
		local tip = top + dir * 3.2
		Util.strip(parent, "LampArm", top, tip, 0.3, 0.3, metal)
		local head = Util.part(
			parent,
			"Lantern",
			CFrame.lookAt(tip - Vector3.new(0, 0.9, 0), tip - Vector3.new(0, 0.9, 0) + dir),
			Vector3.new(1.3, 1.6, 1.3),
			{ Material = Enum.Material.Glass, Color = rgb(250, 238, 200), CastShadow = false }
		)
		head:SetAttribute("RoNationLamp", true)
		local light = Instance.new("SpotLight")
		light:SetAttribute("RoNationStreetLight", true)
		light.Enabled = false -- switched by the environment controller at dusk
		light.Face = Enum.NormalId.Bottom
		light.Angle = 120
		light.Range = 40
		light.Brightness = 2
		light.Color = rgb(255, 224, 180)
		light.Shadows = false
		light.Parent = head
		count += 2
		built += 2
	end
	return built
end

-- A tree: a Forest Pack tree when the Creator Store library was imported, otherwise a clipped
-- round crown on a straight trunk (formal avenue trees).
function Kit.tree(parent: Instance, base: Vector3, height: number, variant: number): number
	if CreatorAssets.get() then
		local model = CreatorAssets.place("Tree", variant, parent, base, height, variant * 1.7)
		if model then
			local built = 0
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					built += 1
				end
			end
			count += built
			return built
		end
	end
	local trunk = { Material = Enum.Material.Wood, Color = rgb(96, 74, 56) }
	Util.cylinder(parent, "Trunk", base - Vector3.new(0, 0.5, 0), base + Vector3.new(0, height * 0.55, 0), 1.3, trunk)
	local green = { Material = Enum.Material.Grass, Color = rgb(70 + variant % 3 * 6, 112, 58), CanCollide = false }
	local crown = height * 0.5
	Kit.ellipsoid(
		parent,
		"Crown",
		base + Vector3.new(0, height * 0.62, 0),
		Vector3.new(crown, crown * 0.8, crown),
		green
	)
	Kit.ellipsoid(
		parent,
		"Crown",
		base + Vector3.new(0, height * 0.82, 0),
		Vector3.new(crown * 0.7, crown * 0.6, crown * 0.7),
		green
	)
	count += 1
	return 3
end

-- A park bench facing `facing` (seat can be sat on).
function Kit.bench(parent: Instance, base: Vector3, facing: Vector3): number
	local dir = Vector3.new(facing.X, 0, facing.Z).Unit
	local frame = CFrame.lookAt(base, base + dir)
	local seat = Instance.new("Seat")
	seat.Name = "Bench"
	seat.Anchored = true
	seat.Size = Vector3.new(5, 0.4, 1.6)
	seat.CFrame = frame * CFrame.new(0, 1.6, 0)
	seat.Material = Enum.Material.WoodPlanks
	seat.Color = rgb(124, 86, 56)
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Parent = parent
	local back = Util.part(
		parent,
		"BenchBack",
		frame * CFrame.new(0, 2.7, 0.85),
		Vector3.new(5, 1.6, 0.3),
		{ Material = Enum.Material.WoodPlanks, Color = rgb(124, 86, 56) }
	)
	back.CFrame = back.CFrame * CFrame.Angles(math.rad(-10), 0, 0)
	for _, side in { -2.1, 2.1 } do
		Util.part(parent, "BenchLeg", frame * CFrame.new(side, 0.7, 0.1), Vector3.new(0.3, 1.4, 1.6), Kit.Style.Iron)
	end
	count += 4
	return 4
end

-- A rectangular hedge or planter box.
function Kit.planter(parent: Instance, r: Rect, y: number, height: number, plant: Options?): number
	Kit.slab(parent, "Planter", r, y, y + 0.8, Kit.Style.Granite)
	Kit.slab(parent, "Hedge", Kit.inset(r, 0.4), y + 0.8, y + height, plant or Kit.Style.Hedge)
	return 2
end

return Kit
