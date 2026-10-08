--!strict
-- HexGrid: pointy-top hex grid math for the forest plots.
-- Put this ModuleScript in ReplicatedStorage so server and client share it.
--
-- Hexes use axial coordinates (q, r). The center hex is (0, 0).
-- "size" is the distance from a hex's center to its corners, in studs.
-- Neighboring hex centers are sqrt(3) * size studs apart.

local HexGrid = {}

export type Hex = { q: number, r: number }

local SQRT3 = math.sqrt(3)

-- The six neighbor directions, in order around the hex.
local DIRECTIONS: { Hex } = {
	{ q = 1, r = 0 },
	{ q = 1, r = -1 },
	{ q = 0, r = -1 },
	{ q = -1, r = 0 },
	{ q = -1, r = 1 },
	{ q = 0, r = 1 },
}

-- A string key for storing plots in a table, e.g. plots["3,-2"]
function HexGrid.key(q: number, r: number): string
	return `{q},{r}`
end

-- Hex -> world position (flat, on the XZ plane around origin).
function HexGrid.toWorld(q: number, r: number, size: number, origin: Vector3): Vector3
	local x = size * SQRT3 * (q + r / 2)
	local z = size * 1.5 * r
	return origin + Vector3.new(x, 0, z)
end

-- Round fractional axial coordinates to the nearest whole hex.
local function roundAxial(qf: number, rf: number): (number, number)
	local sf = -qf - rf
	local q, r, s = math.round(qf), math.round(rf), math.round(sf)
	local dq, dr, ds = math.abs(q - qf), math.abs(r - rf), math.abs(s - sf)
	if dq > dr and dq > ds then
		q = -r - s
	elseif dr > ds then
		r = -q - s
	end
	return q, r
end

-- World position -> the hex it falls in. Used for "which plot is the player standing near?"
function HexGrid.fromWorld(position: Vector3, size: number, origin: Vector3): (number, number)
	local p = position - origin
	local qf = (SQRT3 / 3 * p.X - 1 / 3 * p.Z) / size
	local rf = (2 / 3 * p.Z) / size
	return roundAxial(qf, rf)
end

-- How many hex steps apart two hexes are.
function HexGrid.distance(aq: number, ar: number, bq: number, br: number): number
	local dq, dr = aq - bq, ar - br
	return (math.abs(dq) + math.abs(dq + dr) + math.abs(dr)) / 2
end

function HexGrid.neighbors(q: number, r: number): { Hex }
	local result = {}
	for _, d in DIRECTIONS do
		table.insert(result, { q = q + d.q, r = r + d.r })
	end
	return result
end

-- All hexes exactly `radius` steps from the center. Ring k has 6 * k hexes.
function HexGrid.ring(radius: number): { Hex }
	if radius == 0 then
		return { { q = 0, r = 0 } }
	end
	local result = {}
	-- Start at the hex `radius` steps in direction 5, then walk the six sides.
	local q, r = DIRECTIONS[5].q * radius, DIRECTIONS[5].r * radius
	for side = 1, 6 do
		for _ = 1, radius do
			table.insert(result, { q = q, r = r })
			q += DIRECTIONS[side].q
			r += DIRECTIONS[side].r
		end
	end
	return result
end

-- Which side of its ring a hex is on: 1..6 in the order ring() walks them, 0 for the center.
-- Each side starts at a corner, so the side hexes between two neighboring corner lines (the walkway
-- spokes) share a side number in every ring: that's one forest section.
function HexGrid.side(q: number, r: number): number
	local radius = HexGrid.distance(q, r, 0, 0)
	if radius == 0 then
		return 0
	end
	for i, hex in HexGrid.ring(radius) do
		if hex.q == q and hex.r == r then
			return (i - 1) // radius + 1
		end
	end
	return 0
end

-- Every ring from the center out to maxRadius.
-- rings[1] is the center hex, rings[2] is ring 1, and so on.
-- Total hexes = 3 * maxRadius * (maxRadius + 1) + 1.
-- Tier 1: maxRadius 15, hub = rings 0 to 3 (left empty), forest = rings 4 to 15.
-- Every tree takes exactly one hex, rare or not.
function HexGrid.rings(maxRadius: number): { { Hex } }
	local result = {}
	for radius = 0, maxRadius do
		table.insert(result, HexGrid.ring(radius))
	end
	return result
end

return HexGrid
