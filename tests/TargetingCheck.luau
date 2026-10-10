--!strict
-- Checks for Shared/Targeting (docs/plans/M4.md). Not shipped: run it in Studio's Edit mode through
-- the Studio connection; it returns "Targeting: all checks passed" or errors on the first failure.

local HexGrid = require(game:GetService("ReplicatedStorage").Shared.HexGrid)
local Targeting = require(game:GetService("ReplicatedStorage").Shared.Targeting)

local SIZE = 16
local ORIGIN = Vector3.new(0, 0.4, 0)
local SPACING = SIZE * math.sqrt(3) -- neighbor centers, ~27.7 studs
local allOpen = function(_q: number, _r: number): boolean
	return true
end

local here = HexGrid.toWorld(5, 0, SIZE, ORIGIN) + Vector3.new(0, 3, 0) -- standing on hex (5, 0)

-- Range 30: the hex you stand on first, then its 6 neighbors (all at the same distance).
local near = Targeting.openNear(here, 30, SIZE, ORIGIN, allOpen)
assert(#near == 7, `expected 7 hexes in 30 studs, got {#near}`)
assert(near[1].q == 5 and near[1].r == 0 and near[1].distance < 1e-3, "the hex you stand on should come first")
for i = 2, 7 do
	assert(math.abs(near[i].distance - SPACING) < 1e-3, "neighbors should be one spacing away")
	assert(HexGrid.distance(near[i].q, near[i].r, 5, 0) == 1, "neighbors should be one step away")
end
-- Equal distances are ordered by q, then r, so the client and server pick the same one.
for i = 3, 7 do
	local a, b = near[i - 1], near[i]
	assert(a.q < b.q or (a.q == b.q and a.r < b.r), "ties should be ordered by q then r")
end

-- Range edge: just under one spacing leaves only the hex you stand on.
assert(#Targeting.openNear(here, SPACING - 0.01, SIZE, ORIGIN, allOpen) == 1, "neighbors are just out of range")
assert(#Targeting.openNear(here, SPACING + 0.01, SIZE, ORIGIN, allOpen) == 7, "neighbors are just in range")

-- Closed hexes are skipped: with your own hex full, a neighbor comes first.
local skipOwn = Targeting.openNear(here, 30, SIZE, ORIGIN, function(q: number, r: number): boolean
	return not (q == 5 and r == 0)
end)
assert(#skipOwn == 6 and HexGrid.distance(skipOwn[1].q, skipOwn[1].r, 5, 0) == 1, "a full hex should be skipped")

-- Height is ignored: standing 50 studs up changes nothing.
assert(#Targeting.openNear(here + Vector3.new(0, 50, 0), 30, SIZE, ORIGIN, allOpen) == 7, "height should be ignored")

-- A bigger range reaches part of the second ring (Planting Range level 5: 30 + 20 = 50 studs).
-- Six second-ring hexes are sqrt(3) spacings away (48 studs), the other six are 2 spacings (55.4).
assert(#Targeting.openNear(here, 50, SIZE, ORIGIN, allOpen) == 13, "50 studs should reach 13 hexes")
assert(#Targeting.openNear(here, 56, SIZE, ORIGIN, allOpen) == 19, "56 studs should reach all 19")

-- Two rings (isOpenPlot, 2026-10-09): ring 15 open, outside-in, one ring ahead.
local inner = HexGrid.ring(14)[3]
local outerNeighbor, farInner
for _, n in HexGrid.neighbors(inner.q, inner.r) do
	local d = HexGrid.distance(n.q, n.r, 0, 0)
	if d == 15 then
		outerNeighbor = n
	elseif d == 13 then
		farInner = n
	end
end
assert(outerNeighbor and farInner, "a ring-14 hex touches rings 15 and 13")
local grownSet: { [string]: boolean } = {}
local grown = function(q: number, r: number): boolean
	return grownSet[HexGrid.key(q, r)] == true
end
local function open(hex: HexGrid.Hex, ring: number, ahead: number): boolean
	return Targeting.isOpenPlot(hex.q, hex.r, ring, false, 15, true, ahead, grown)
end
assert(open(outerNeighbor, 15, 1), "the open ring is open")
assert(not open(inner, 14, 1), "ring 14 waits for a full-grown tree outside it")
grownSet[HexGrid.key(outerNeighbor.q, outerNeighbor.r)] = true
assert(open(inner, 14, 1), "a full-grown ring-15 tree opens the plot behind it")
assert(not open(inner, 14, 0), "AheadRings 0 keeps only the open ring")
grownSet[HexGrid.key(inner.q, inner.r)] = true
assert(not open(farInner, 13, 1), "one ring ahead at most")
assert(open(farInner, 13, 2), "two rings ahead with AheadRings 2")
assert(not Targeting.isOpenPlot(inner.q, inner.r, 14, true, 15, true, 1, grown), "a full plot is never open")
assert(not Targeting.isOpenPlot(outerNeighbor.q, outerNeighbor.r, 15, false, 0, true, 1, grown), "done: nothing open")
-- Inner-first (ring 13 open): ring 14 is the ring ahead and opens behind full-grown ring-13 trees.
assert(not Targeting.isOpenPlot(inner.q, inner.r, 14, false, 13, false, 1, grown), "inner-first: waits for ring 13")
grownSet[HexGrid.key(farInner.q, farInner.r)] = true
assert(Targeting.isOpenPlot(inner.q, inner.r, 14, false, 13, false, 1, grown), "inner-first: opens behind ring 13")

return "Targeting: all checks passed"
