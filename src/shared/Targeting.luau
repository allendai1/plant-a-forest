--!strict
-- Targeting: the open hexes within reach of a position, closest first (docs/plans/M4.md).
-- Shared by TargetController (the outline) and ForestService (overflow), so both pick the same hex.
-- Pure: callers pass the grid origin and an isOpen(q, r) check. Only the few rings of hexes around the
-- hex under the position are looked at, never the whole forest. Distances are flat (height ignored).

local HexGrid = require(script.Parent.HexGrid)

export type Candidate = { q: number, r: number, distance: number }

local Targeting = {}

local SQRT3 = math.sqrt(3)

function Targeting.openNear(
	position: Vector3,
	range: number,
	hexSize: number,
	origin: Vector3,
	isOpen: (q: number, r: number) -> boolean
): { Candidate }
	local cq, cr = HexGrid.fromWorld(position, hexSize, origin)
	local steps = math.ceil(range / (SQRT3 * hexSize)) + 1
	local found: { Candidate } = {}
	for dq = -steps, steps do
		for dr = math.max(-steps, -dq - steps), math.min(steps, -dq + steps) do
			local q, r = cq + dq, cr + dr
			if isOpen(q, r) then
				local center = HexGrid.toWorld(q, r, hexSize, origin)
				-- Rounded to a thousandth of a stud: Roblox vectors are 32-bit, so hexes that are exactly the
				-- same distance away would otherwise differ in the last digits and the tie-break wouldn't apply.
				local distance = math.round(Vector2.new(center.X - position.X, center.Z - position.Z).Magnitude * 1000) / 1000
				if distance <= range then
					table.insert(found, { q = q, r = r, distance = distance })
				end
			end
		end
	end
	-- Ties are broken by q, then r, so the client and the server always agree on the order.
	table.sort(found, function(a, b)
		if a.distance ~= b.distance then
			return a.distance < b.distance
		elseif a.q ~= b.q then
			return a.q < b.q
		end
		return a.r < b.r
	end)
	return found
end

-- Is the plot at (q, r) in `ring` open for planting? Shared by ForestService (the check) and ForestController (the
-- glowing rims), so both agree. The open ring always is (openRing 0 = none: the forest is done). Since 2026-10-09
-- (the user's two-rings idea) so is a plot up to `aheadRings` rings past it, once the tree just outside it (its
-- neighbor one ring back toward the open ring) is full grown: the forest creeps on behind finished trees.
-- `grown(q, r)` says whether the plot there is full grown (false for no plot). Full plots are never open.
function Targeting.isOpenPlot(
	q: number,
	r: number,
	ring: number,
	full: boolean,
	openRing: number,
	outsideIn: boolean,
	aheadRings: number,
	grown: (q: number, r: number) -> boolean
): boolean
	if full or openRing == 0 then
		return false
	end
	if ring == openRing then
		return true
	end
	local step = if outsideIn then -1 else 1 -- the way the rings open
	local ahead = (ring - openRing) * step
	if ahead < 1 or ahead > aheadRings then
		return false
	end
	for _, n in HexGrid.neighbors(q, r) do
		if HexGrid.distance(n.q, n.r, 0, 0) == ring - step and grown(n.q, n.r) then
			return true
		end
	end
	return false
end

return Targeting
