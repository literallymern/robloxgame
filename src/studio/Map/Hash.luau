--!strict
--!native
-- Repeatable pseudo-random numbers from whole-number coordinates. Every build places the same
-- trees, rocks and signs in the same spots, without a Random object (so it also runs offline).

local Hash = {}

-- a * b modulo 2^32 for 32-bit whole numbers, without losing precision in a double.
local function mul32(a: number, b: number): number
	local lo = a % 65536
	local hi = (a - lo) / 65536
	return ((hi * b % 65536) * 65536 + lo * b) % 4294967296
end

-- Mixes a 32-bit number thoroughly (a well-known integer hash with low bias).
function Hash.u32(x: number): number
	x = bit32.bxor(x, bit32.rshift(x, 16))
	x = mul32(x, 0x7feb352d)
	x = bit32.bxor(x, bit32.rshift(x, 15))
	x = mul32(x, 0x846ca68b)
	x = bit32.bxor(x, bit32.rshift(x, 16))
	return x
end

-- A number in [0, 1) for the cell (ix, iz) and a salt (use a different salt per purpose).
function Hash.unit(ix: number, iz: number, salt: number): number
	local h = Hash.u32((ix % 65536) * 65536 + iz % 65536)
	h = Hash.u32(bit32.bxor(h, mul32(salt % 4294967296 + 1, 0x9e3779b9)))
	return h / 4294967296
end

-- A number in [lo, hi).
function Hash.range(ix: number, iz: number, salt: number, lo: number, hi: number): number
	return lo + (hi - lo) * Hash.unit(ix, iz, salt)
end

return Hash
