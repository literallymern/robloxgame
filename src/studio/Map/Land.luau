--!strict
--!native
-- The shape of the land before roads and the river: base heights, rolling noise, hills,
-- boundary mountains with their passes, and the flattened places (cities, facilities, plots).
-- Pure Luau, tested offline. Reads the numbers from MapLayout.

local Geometry = require(script.Parent.Geometry)

type Rect = Geometry.Rect

export type Land = {
	natural: (x: number, z: number) -> number, -- terrain without places (from a 16-stud lattice)
	height: (x: number, z: number) -> number, -- natural + fine detail, with places flattened
	placeGround: { [string]: number }, -- resolved ground height of every place, by place id
}

local LATTICE = 16 -- studs between lattice points

local Land = {}

-- `yieldEvery` is called now and then during the slow part, so Studio can stay responsive.
function Land.new(layout: any, yieldEvery: (() -> ())?): Land
	local half: number = layout.Bounds.Half
	local smoothstep = Geometry.smoothstep

	-- Base heights: blended anchors plus gentle rolling noise.
	local anchorX: { number }, anchorZ: { number }, anchorH: { number } = {}, {}, {}
	for i, anchor in layout.HeightAnchors do
		anchorX[i], anchorZ[i], anchorH[i] = anchor[1], anchor[2], anchor[3]
	end
	local anchorCount = #anchorX
	local SOFT = 400 * 400 -- softens the blend close to an anchor
	local rollAmp: number = layout.Rolling.Amplitude
	local rollLen: number = layout.Rolling.Wavelength
	local detailAmp: number = layout.Rolling.DetailAmplitude
	local detailLen: number = layout.Rolling.DetailWavelength

	local function base(x: number, z: number): number
		local sumW, sumH = 0, 0
		for i = 1, anchorCount do
			local dx, dz = x - anchorX[i], z - anchorZ[i]
			local d2 = dx * dx + dz * dz + SOFT
			local w = 1 / (d2 * math.sqrt(d2)) -- inverse distance cubed
			sumW += w
			sumH += w * anchorH[i]
		end
		return sumH / sumW + rollAmp * math.noise(x / rollLen + 0.31, z / rollLen + 0.17, 1.7)
	end

	-- Hills: a ridge along the long middle line of their rectangle, falling off over half the
	-- rectangle's width plus the margin. The position is warped by noise so the outline is not
	-- a rectangle, and the height varies along the ridge.
	local hills = layout.Hills
	local function addHills(x: number, z: number, h: number): number
		for i, hill in hills do
			local rect: Rect = hill.Rect
			local halfMin = math.min(rect.MaxX - rect.MinX, rect.MaxZ - rect.MinZ) / 2
			local reach = halfMin + hill.Margin
			local cx, cz = Geometry.rectCentre(rect)
			if math.abs(x - cx) > (rect.MaxX - rect.MinX) / 2 + reach + 200 then
				continue
			end
			if math.abs(z - cz) > (rect.MaxZ - rect.MinZ) / 2 + reach + 200 then
				continue
			end
			local wx = x + 170 * math.noise(x / 620 + 0.17, z / 620 + 0.71, 20 + i)
			local wz = z + 170 * math.noise(x / 620 + 5.23, z / 620 + 1.37, 30 + i)
			local ax, az, bx, bz
			if rect.MaxX - rect.MinX >= rect.MaxZ - rect.MinZ then
				ax, az, bx, bz = rect.MinX + halfMin, cz, rect.MaxX - halfMin, cz
			else
				ax, az, bx, bz = cx, rect.MinZ + halfMin, cx, rect.MaxZ - halfMin
			end
			local d = Geometry.segmentDistance(ax, az, bx, bz, wx, wz)
			if d < reach then
				local shape = smoothstep(1 - d / reach)
				-- Rotated coordinates for the second octave hide the regular grid of Perlin noise.
				local u, v = 0.8 * x - 0.6 * z, 0.6 * x + 0.8 * z
				local n = math.noise(x / 480 + 0.11 * i, z / 480 + 0.23, 4.2 + i)
					+ 0.35 * math.noise(u / 210 + 0.37, v / 210 + 0.05 * i, 6.9 + i)
				local top = hill.Peak * (1 + 0.28 * n)
				if top > h then
					h += (top - h) * shape
				end
			end
		end
		return h
	end

	-- Boundary mountains: a ring outside the playable area, opened at the passes. The inner foot
	-- wanders with noise, and ridged noise gives the peaks.
	local mountains = layout.Mountains
	local inner0: number = layout.Bounds.Playable - mountains.StartInside
	local span: number = mountains.StartInside + mountains.FullOutside
	local passes = mountains.Passes
	local function passOpen(edge: string, along: number): number
		local open = 0
		for _, pass in passes do
			if pass.Edge == edge then
				local a = math.abs(along - pass.Centre)
				local o = if a <= pass.Flat then 1 else 1 - smoothstep((a - pass.Flat) / pass.Slope)
				open = math.max(open, o)
			end
		end
		return open
	end
	local function addMountains(x: number, z: number, h: number): number
		local foot = inner0 + 200 * math.noise(x / 760 + 0.67, z / 760 + 0.29, 12.1)
		local ring = 0
		if x > foot then
			ring = math.max(ring, smoothstep((x - foot) / span) * (1 - passOpen("East", z)))
		end
		if -x > foot then
			ring = math.max(ring, smoothstep((-x - foot) / span) * (1 - passOpen("West", z)))
		end
		if z > foot then
			ring = math.max(ring, smoothstep((z - foot) / span) * (1 - passOpen("South", x)))
		end
		if -z > foot then
			ring = math.max(ring, smoothstep((-z - foot) / span) * (1 - passOpen("North", x)))
		end
		if ring <= 0 then
			return h
		end
		local r1 = 1 - math.abs(math.noise(x / 700 + 0.13, z / 700 + 0.41, 8.3)) * 2
		local r2 = 1 - math.abs(math.noise(x / 260 + 0.29, z / 260 + 0.07, 9.7)) * 2
		local ridged = Geometry.clamp01(0.6 * r1 + 0.4 * r1 * r2 + 0.1)
		local top = mountains.MinPeak + mountains.ExtraPeak * ridged
		if top > h then
			h += (top - h) * ring
		end
		return h
	end

	local function exactNatural(x: number, z: number): number
		return addMountains(x, z, addHills(x, z, base(x, z)))
	end

	-- Precompute the natural terrain on a lattice; it is smooth, so bilinear lookup is enough.
	local n = math.floor(2 * half / LATTICE) + 1
	local lattice: { number } = table.create(n * n)
	for iz = 0, n - 1 do
		local z = -half + iz * LATTICE
		for ix = 0, n - 1 do
			lattice[iz * n + ix + 1] = exactNatural(-half + ix * LATTICE, z)
		end
		if yieldEvery and iz % 32 == 0 then
			yieldEvery()
		end
	end

	local function natural(x: number, z: number): number
		local fx = (x + half) / LATTICE
		local fz = (z + half) / LATTICE
		local ix = math.clamp(math.floor(fx), 0, n - 2)
		local iz = math.clamp(math.floor(fz), 0, n - 2)
		local tx, tz = fx - ix, fz - iz
		local i = iz * n + ix + 1
		local a, b, c, d = lattice[i], lattice[i + 1], lattice[i + n], lattice[i + n + 1]
		return a + (b - a) * tx + (c - a) * tz + (a - b - c + d) * tx * tz
	end

	-- Places: flattened to their ground height and blended back over their margin.
	local placeGround: { [string]: number } = {}
	local places = layout.Places
	local placeCount = #places
	local pMinX: { number }, pMaxX: { number }, pMinZ: { number }, pMaxZ: { number } = {}, {}, {}, {}
	local pMargin: { number }, pGround: { number } = {}, {}
	local pRect: { Rect } = {}
	for i, place in places do
		local rect: Rect = place.Rect
		local ground: number
		if place.GroundY == nil then
			local cx, cz = Geometry.rectCentre(rect)
			ground = math.floor(natural(cx, cz) + 0.5)
		else
			ground = place.GroundY
		end
		placeGround[place.Id] = ground
		pRect[i] = rect
		pMinX[i], pMaxX[i] = rect.MinX - place.Margin, rect.MaxX + place.Margin
		pMinZ[i], pMaxZ[i] = rect.MinZ - place.Margin, rect.MaxZ + place.Margin
		pMargin[i], pGround[i] = place.Margin, ground
	end

	local function height(x: number, z: number): number
		-- Inside a place the ground is exactly flat (the last place in the list wins).
		for i = placeCount, 1, -1 do
			local r = pRect[i]
			if x >= r.MinX and x <= r.MaxX and z >= r.MinZ and z <= r.MaxZ then
				return pGround[i]
			end
		end
		local h = natural(x, z) + detailAmp * math.noise(x / detailLen + 0.53, z / detailLen + 0.71, 3.1)
		for i = 1, placeCount do
			if x >= pMinX[i] and x <= pMaxX[i] and z >= pMinZ[i] and z <= pMaxZ[i] then
				local d = Geometry.rectDistance(pRect[i], x, z)
				local margin = pMargin[i]
				if d < margin then
					h += (pGround[i] - h) * (1 - smoothstep(d / margin))
				end
			end
		end
		return h
	end

	return {
		natural = natural,
		height = height,
		placeGround = placeGround,
	}
end

return Land
