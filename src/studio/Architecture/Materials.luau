--!strict
-- Material presets for buildings in Kagundi: an African highland capital with German and French
-- colonial-era architecture. Real surfaces instead of plastic: plaster, limestone, granite,
-- clay roof tiles, ceramic tiles, carpet, oiled wood, leather, brushed metal, glass.
-- Colours are muted and slightly warm; Parts.vary adds small differences between pieces.
-- Interiors use mid-tone paints (Materials.Paint) instead of near-white plaster: under the
-- interior lights and the bright global ambient, white rooms looked flat and glaring. Wooden
-- floors name the official Roblox wood floor material variants (StoreAssets.luau); without them
-- they show plain wood in the same colour.

local Parts = require(script.Parent.Parts)

type Options = Parts.Options

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function m(material: Enum.Material, colour: Color3, extra: any?): Options
	local o: Options = { Material = material, Color = colour }
	if extra then
		for key, value in extra :: any do
			(o :: any)[key] = value
		end
	end
	return o
end

local M = Enum.Material

local Materials = {}

-- Walls and ceilings.
Materials.Wall = table.freeze({
	White = m(M.Plaster, rgb(238, 235, 226)),
	Warm = m(M.Plaster, rgb(234, 224, 204)),
	Cream = m(M.Plaster, rgb(232, 220, 190)),
	Grey = m(M.Plaster, rgb(206, 206, 202)),
	Sage = m(M.Plaster, rgb(176, 190, 168)),
	Terracotta = m(M.Plaster, rgb(196, 132, 100)),
	Blue = m(M.Plaster, rgb(160, 180, 196)),
	Ochre = m(M.Plaster, rgb(214, 178, 112)),
	Tile = m(M.CeramicTiles, rgb(226, 228, 224)),
	TileBlue = m(M.CeramicTiles, rgb(170, 196, 210)),
	Panel = m(M.Wood, rgb(120, 82, 54)),
	Concrete = m(M.Concrete, rgb(170, 168, 162)),
})
Materials.Ceiling = m(M.Plaster, rgb(224, 220, 210))

-- Interior paints (matt plaster in mid tones) and panelling.
Materials.Paint = table.freeze({
	Linen = m(M.Plaster, rgb(212, 205, 190)), -- warm off-white
	Stone = m(M.Plaster, rgb(200, 192, 176)), -- warm stone grey
	Greige = m(M.Plaster, rgb(184, 176, 162)),
	Sand = m(M.Plaster, rgb(204, 188, 158)),
	Cream = m(M.Plaster, rgb(220, 207, 180)),
	Sage = m(M.Plaster, rgb(156, 166, 146)),
	Moss = m(M.Plaster, rgb(108, 118, 98)),
	Slate = m(M.Plaster, rgb(112, 122, 130)),
	Teal = m(M.Plaster, rgb(86, 108, 112)),
	Oxblood = m(M.Plaster, rgb(112, 60, 54)),
	Ochre = m(M.Plaster, rgb(188, 158, 110)),
	Charcoal = m(M.Plaster, rgb(70, 72, 74)),
})
Materials.Panel = table.freeze({
	Oak = m(M.Wood, rgb(140, 100, 64)),
	Walnut = m(M.Wood, rgb(92, 62, 42)),
	Mahogany = m(M.Wood, rgb(98, 50, 38)),
	Painted = m(M.Wood, rgb(214, 208, 194)),
	Sage = m(M.Wood, rgb(140, 152, 132)),
})

-- Floor finishes.
Materials.Floor = table.freeze({
	CarpetGrey = m(M.Carpet, rgb(92, 94, 98)),
	CarpetBlue = m(M.Carpet, rgb(58, 66, 82)),
	CarpetRed = m(M.Carpet, rgb(100, 46, 46)), -- muted burgundy, not signal red
	CarpetGreen = m(M.Carpet, rgb(60, 76, 62)),
	CarpetSand = m(M.Carpet, rgb(148, 134, 110)),
	CarpetMoss = m(M.Carpet, rgb(84, 90, 70)),
	CarpetTaupe = m(M.Carpet, rgb(116, 104, 92)),
	CarpetNavy = m(M.Carpet, rgb(42, 50, 68)),
	Terrazzo = m(M.Marble, rgb(188, 182, 170)),
	Marble = m(M.Marble, rgb(212, 206, 194)),
	MarbleDark = m(M.Marble, rgb(118, 112, 104)),
	TileWhite = m(M.CeramicTiles, rgb(208, 208, 202)),
	TileGrey = m(M.CeramicTiles, rgb(140, 142, 140)),
	TileTerracotta = m(M.CeramicTiles, rgb(160, 92, 66)),
	Parquet = m(M.Wood, rgb(164, 116, 74), { MaterialVariant = "Wood Floor Herringbone MV" }),
	ParquetDark = m(M.Wood, rgb(116, 80, 54), { MaterialVariant = "Wood Floor Herringbone MV" }),
	Planks = m(M.Wood, rgb(150, 108, 72), { MaterialVariant = "Wood Floor MV" }),
	Concrete = m(M.Concrete, rgb(146, 146, 142)),
	Linoleum = m(M.Rubber, rgb(138, 144, 134)),
})

-- Furniture.
Materials.Wood = table.freeze({
	Oak = m(M.Wood, rgb(166, 122, 80)),
	Walnut = m(M.Wood, rgb(96, 64, 42)),
	Mahogany = m(M.Wood, rgb(112, 52, 38)),
	Pine = m(M.WoodPlanks, rgb(196, 160, 112)),
	White = m(M.SmoothPlastic, rgb(232, 230, 224)),
})
Materials.Fabric = table.freeze({
	Grey = m(M.Fabric, rgb(110, 112, 118)),
	Blue = m(M.Fabric, rgb(56, 72, 108)),
	Green = m(M.Fabric, rgb(64, 96, 72)),
	Red = m(M.Fabric, rgb(128, 40, 44)),
	Beige = m(M.Fabric, rgb(196, 180, 150)),
	Charcoal = m(M.Fabric, rgb(52, 54, 58)),
})
Materials.Leather = table.freeze({
	Brown = m(M.Leather, rgb(96, 58, 38)),
	Black = m(M.Leather, rgb(40, 38, 38)),
	Oxblood = m(M.Leather, rgb(98, 32, 32)),
	Tan = m(M.Leather, rgb(150, 102, 64)),
})
Materials.Metal = table.freeze({
	Steel = m(M.Metal, rgb(160, 164, 168)),
	Dark = m(M.Metal, rgb(58, 60, 64)),
	Brass = m(M.Metal, rgb(184, 150, 76)),
	Chrome = m(M.Metal, rgb(204, 208, 212), { Reflectance = 0.2 }),
	Aluminium = m(M.Metal, rgb(178, 182, 186)),
	Bronze = m(M.Metal, rgb(112, 84, 52)),
	Iron = m(M.Metal, rgb(44, 48, 46)),
})
Materials.Plastic = table.freeze({
	White = m(M.SmoothPlastic, rgb(236, 236, 232)),
	Black = m(M.SmoothPlastic, rgb(30, 30, 32)),
	Grey = m(M.SmoothPlastic, rgb(130, 132, 136)),
	Red = m(M.SmoothPlastic, rgb(186, 32, 32)),
	Green = m(M.SmoothPlastic, rgb(30, 140, 70)),
	Beige = m(M.SmoothPlastic, rgb(214, 204, 182)),
})
Materials.Porcelain = m(M.SmoothPlastic, rgb(244, 244, 242))
Materials.Screen = m(M.Glass, rgb(24, 30, 38), { Reflectance = 0.1 })
Materials.Paper = m(M.SmoothPlastic, rgb(240, 238, 230))
Materials.Cardboard = m(M.Cardboard, rgb(176, 140, 96))
Materials.Leaf = m(M.Grass, rgb(70, 116, 58), { CanCollide = false })
Materials.Soil = m(M.Ground, rgb(84, 62, 46))
Materials.Pot = m(M.SmoothPlastic, rgb(170, 98, 66))

-- Glass.
Materials.Glass = table.freeze({
	Window = m(M.Glass, rgb(170, 198, 208), { Transparency = 0.55, Reflectance = 0.08, CastShadow = false }),
	Frosted = m(M.Glass, rgb(226, 232, 234), { Transparency = 0.25, CastShadow = false }),
	Interior = m(M.Glass, rgb(206, 222, 228), { Transparency = 0.65, CastShadow = false }),
	Shop = m(M.Glass, rgb(160, 186, 196), { Transparency = 0.5, Reflectance = 0.12, CastShadow = false }),
})

-- Window and door frames.
Materials.Frame = table.freeze({
	White = m(M.Wood, rgb(236, 234, 228)),
	Green = m(M.Wood, rgb(52, 92, 64)),
	Brown = m(M.Wood, rgb(88, 60, 40)),
	Bronze = m(M.Metal, rgb(96, 74, 48)),
	Grey = m(M.Metal, rgb(92, 96, 100)),
})

-- Roofs.
Materials.Roof = table.freeze({
	ClayTiles = m(M.ClayRoofTiles, rgb(172, 84, 58)),
	Slate = m(M.Slate, rgb(70, 78, 88)),
	Shingles = m(M.RoofShingles, rgb(78, 76, 76)),
	Copper = m(M.Metal, rgb(96, 142, 126)),
	Membrane = m(M.Rubber, rgb(74, 76, 78)),
	Gravel = m(M.Pebble, rgb(146, 140, 132)),
	Zinc = m(M.Metal, rgb(132, 138, 142)),
})

return Materials
