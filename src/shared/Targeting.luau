--!strict
-- Targeting: the open bridge slots within reach of a position, closest first (docs/plans/M4.md; bridge slots since
-- 2026-10-10). Shared by TargetController (the outline) and ForestService (overflow), so both pick the same slot.
-- Pure: callers pass the bridge frame and an isOpen(q, r) check. Only the slots around the one under the position
-- are looked at, never the whole bridge. Distances are flat (height ignored).

local BridgeGrid = require(script.Parent.BridgeGrid)
local GameConfig = require(script.Parent.GameConfig)

export type Candidate = { q: number, r: number, distance: number }

local Targeting = {}

function Targeting.openNear(
	position: Vector3,
	range: number,
	frame: CFrame,
	isOpen: (q: number, r: number) -> boolean
): { Candidate }
	local grid = GameConfig.Grid
	local cq, cr = BridgeGrid.fromWorld(position, frame)
	local steps = math.ceil(range / grid.SlotStuds) + 1
	local found: { Candidate } = {}
	for q = math.max(1, cq - steps), math.min(grid.Columns, cq + steps) do
		for r = math.max(1, cr - steps), math.min(grid.Rows, cr + steps) do
			if isOpen(q, r) then
				local center = BridgeGrid.toWorld(q, r, frame)
				-- Rounded to a thousandth of a stud: Roblox vectors are 32-bit, so slots that are exactly the
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

-- Is the slot at (q, r) in row `ring` open for planks? Shared by ForestService (the check) and BridgeController (the
-- ghost outlines), so both agree. The open row always is (openRing 0 = none: the bridge is done). So is a slot up to
-- `aheadRings` rows past it, once the slot behind it is finished: the bridge creeps out behind finished slots.
-- `grown(q, r)` says whether the slot there is finished (false for no slot). Finished slots are never open.
function Targeting.isOpenPlot(
	q: number,
	r: number,
	ring: number,
	full: boolean,
	openRing: number,
	aheadRings: number,
	grown: (q: number, r: number) -> boolean
): boolean
	if full or openRing == 0 then
		return false
	end
	if ring == openRing then
		return true
	end
	local ahead = ring - openRing
	if ahead < 1 or ahead > aheadRings then
		return false
	end
	return grown(BridgeGrid.behind(q, r))
end

return Targeting
