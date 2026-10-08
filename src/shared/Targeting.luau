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

return Targeting
