--!strict
-- 2D geometry helpers for the map builders (x and z in studs).
-- Pure Luau without Roblox types, so the map calculations can be tested outside Studio.

export type Rect = { MinX: number, MaxX: number, MinZ: number, MaxZ: number }

-- A line sampled at even spacing. s[i] is the distance along the line from the first point.
export type Polyline = { xs: { number }, zs: { number }, s: { number }, length: number }

local Geometry = {}

function Geometry.clamp01(t: number): number
	return if t < 0 then 0 elseif t > 1 then 1 else t
end

function Geometry.smoothstep(t: number): number
	t = if t < 0 then 0 elseif t > 1 then 1 else t
	return t * t * (3 - 2 * t)
end

function Geometry.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Geometry.inRect(rect: Rect, x: number, z: number): boolean
	return x >= rect.MinX and x <= rect.MaxX and z >= rect.MinZ and z <= rect.MaxZ
end

-- Distance from a point to a rectangle: 0 inside, straight-line distance outside.
function Geometry.rectDistance(rect: Rect, x: number, z: number): number
	local dx = if x < rect.MinX then rect.MinX - x elseif x > rect.MaxX then x - rect.MaxX else 0
	local dz = if z < rect.MinZ then rect.MinZ - z elseif z > rect.MaxZ then z - rect.MaxZ else 0
	if dx == 0 then
		return dz
	elseif dz == 0 then
		return dx
	end
	return math.sqrt(dx * dx + dz * dz)
end

-- Signed distance: positive inside (distance to the nearest edge), negative outside.
function Geometry.rectInnerDistance(rect: Rect, x: number, z: number): number
	if Geometry.inRect(rect, x, z) then
		return math.min(x - rect.MinX, rect.MaxX - x, z - rect.MinZ, rect.MaxZ - z)
	end
	return -Geometry.rectDistance(rect, x, z)
end

function Geometry.rectCentre(rect: Rect): (number, number)
	return (rect.MinX + rect.MaxX) / 2, (rect.MinZ + rect.MaxZ) / 2
end

-- Distance from point P to segment AB, and the position t (0..1) of the closest point on AB.
function Geometry.segmentDistance(
	ax: number,
	az: number,
	bx: number,
	bz: number,
	px: number,
	pz: number
): (number, number)
	local dx, dz = bx - ax, bz - az
	local lengthSq = dx * dx + dz * dz
	local t = 0
	if lengthSq > 0 then
		t = ((px - ax) * dx + (pz - az) * dz) / lengthSq
		t = if t < 0 then 0 elseif t > 1 then 1 else t
	end
	local cx, cz = ax + dx * t - px, az + dz * t - pz
	return math.sqrt(cx * cx + cz * cz), t
end

-- Where segments AB and CD cross: positions t on AB and u on CD (both 0..1), or nil.
function Geometry.segmentIntersection(
	ax: number,
	az: number,
	bx: number,
	bz: number,
	cx: number,
	cz: number,
	dx: number,
	dz: number
): (number?, number?)
	local rx, rz = bx - ax, bz - az
	local sx, sz = dx - cx, dz - cz
	local denom = rx * sz - rz * sx
	if math.abs(denom) < 1e-9 then
		return nil, nil
	end
	local qx, qz = cx - ax, cz - az
	local t = (qx * sz - qz * sx) / denom
	local u = (qx * rz - qz * rx) / denom
	if t < 0 or t > 1 or u < 0 or u > 1 then
		return nil, nil
	end
	return t, u
end

-- Replaces every inner corner of a polyline with a circular arc of the given radius.
-- Returns the new points and the smallest radius actually used (smaller than `radius`
-- only when two corners are too close together for the full arc).
function Geometry.fillet(points: { { number } }, radius: number, step: number): ({ number }, { number }, number)
	local xs: { number } = { points[1][1] }
	local zs: { number } = { points[1][2] }
	local minRadius = math.huge
	for i = 2, #points - 1 do
		local px, pz = points[i - 1][1], points[i - 1][2]
		local cx, cz = points[i][1], points[i][2]
		local nx, nz = points[i + 1][1], points[i + 1][2]
		local l1 = math.sqrt((cx - px) ^ 2 + (cz - pz) ^ 2)
		local l2 = math.sqrt((nx - cx) ^ 2 + (nz - cz) ^ 2)
		local d1x, d1z = (cx - px) / l1, (cz - pz) / l1
		local d2x, d2z = (nx - cx) / l2, (nz - cz) / l2
		local cross = d1x * d2z - d1z * d2x
		local dot = math.clamp(d1x * d2x + d1z * d2z, -1, 1)
		local angle = math.acos(dot)
		if angle < 1e-4 then
			table.insert(xs, cx)
			table.insert(zs, cz)
			continue
		end
		local r = radius
		local tangent = r * math.tan(angle / 2)
		local limit = math.min(l1, l2) / 2
		if tangent > limit then
			tangent = limit
			r = tangent / math.tan(angle / 2)
		end
		minRadius = math.min(minRadius, r)
		local sx, sz = cx - d1x * tangent, cz - d1z * tangent
		-- Normal towards the inside of the turn.
		local side = if cross > 0 then 1 else -1
		local ox, oz = -d1z * side, d1x * side
		local centreX, centreZ = sx + ox * r, sz + oz * r
		local startAngle = math.atan2(sz - centreZ, sx - centreX)
		local steps = math.max(2, math.ceil(angle * r / step))
		for k = 0, steps do
			local a = startAngle + side * angle * k / steps
			table.insert(xs, centreX + math.cos(a) * r)
			table.insert(zs, centreZ + math.sin(a) * r)
		end
	end
	table.insert(xs, points[#points][1])
	table.insert(zs, points[#points][2])
	return xs, zs, minRadius
end

-- Samples a polyline at even spacing (the last piece may be shorter). Keeps both end points.
function Geometry.resample(xs: { number }, zs: { number }, spacing: number): Polyline
	local cumulative: { number } = { 0 }
	for i = 2, #xs do
		cumulative[i] = cumulative[i - 1] + math.sqrt((xs[i] - xs[i - 1]) ^ 2 + (zs[i] - zs[i - 1]) ^ 2)
	end
	local length = cumulative[#xs]
	local count = math.max(1, math.ceil(length / spacing))
	local outX: { number } = table.create(count + 1)
	local outZ: { number } = table.create(count + 1)
	local outS: { number } = table.create(count + 1)
	local j = 1
	for k = 0, count do
		local s = math.min(length, k * spacing)
		while j < #xs - 1 and cumulative[j + 1] < s do
			j += 1
		end
		local pieceLength = cumulative[j + 1] - cumulative[j]
		local t = if pieceLength > 0 then (s - cumulative[j]) / pieceLength else 0
		table.insert(outX, xs[j] + (xs[j + 1] - xs[j]) * t)
		table.insert(outZ, zs[j] + (zs[j + 1] - zs[j]) * t)
		table.insert(outS, s)
	end
	return { xs = outX, zs = outZ, s = outS, length = length }
end

return Geometry
