--!strict
-- Checks for Shared/BridgeGrid and Shared/Targeting (bridge slots, 2026-10-10). Not shipped: run it in Studio's Edit
-- mode through the Studio connection; it returns "Targeting: all checks passed" or errors on the first failure.

local Shared = game:GetService("ReplicatedStorage").Shared
local BridgeGrid = require(Shared.BridgeGrid)
local GameConfig = require(Shared.GameConfig)
local Targeting = require(Shared.Targeting)

local grid = GameConfig.Grid
-- A bridge leaving a rim at (-180, 1, 0) toward -X, like the map's.
local FRAME = CFrame.lookAt(Vector3.new(-180, 1, 0), Vector3.new(-181, 1, 0))
local allOpen = function(_q: number, _r: number): boolean
	return true
end

-- Grid math: row 1 is half a slot out from the rim; the columns sit side by side, centered on the bridge's line.
local middle = math.ceil(grid.Columns / 2) -- a whole column next to the bridge's line (or on it, for odd widths)
local first = BridgeGrid.toWorld(middle, 1, FRAME)
assert(math.abs(FRAME:PointToObjectSpace(first).Z + grid.SlotStuds / 2) < 1e-3, "row 1 starts at the rim")
local left, right = BridgeGrid.toWorld(1, 1, FRAME), BridgeGrid.toWorld(grid.Columns, 1, FRAME)
assert(math.abs((right - left).Magnitude - (grid.Columns - 1) * grid.SlotStuds) < 1e-3, "columns are a slot apart")
assert(((left + right) / 2 - (FRAME.Position + FRAME.LookVector * grid.SlotStuds / 2)).Magnitude < 1e-3, "centered on the line")
for _, slot in { { 1, 1 }, { grid.Columns, 7 }, { 2, grid.Rows } } do
	local q, r = BridgeGrid.fromWorld(BridgeGrid.toWorld(slot[1], slot[2], FRAME) + Vector3.new(1, 3, -1), FRAME)
	assert(q == slot[1] and r == slot[2], `fromWorld finds slot {slot[1]},{slot[2]}`)
end
assert(not BridgeGrid.valid(0, 1) and not BridgeGrid.valid(1, 0) and not BridgeGrid.valid(1.5, 2), "outside or fractional")
assert(not BridgeGrid.valid(0 / 0, 1) and not BridgeGrid.valid(1, math.huge), "NaN and infinity are refused")

-- openNear: standing on row 5's middle slot, the closest is that slot, then its neighbors; nothing outside the grid.
local here = BridgeGrid.toWorld(middle, 5, FRAME) + Vector3.new(0, 3, 0)
local near = Targeting.openNear(here, 12, FRAME, allOpen)
assert(near[1].q == middle and near[1].r == 5 and near[1].distance < 1e-3, "the slot underfoot comes first")
for i = 2, #near do
	assert(near[i].distance <= 12 and near[i].distance >= near[i - 1].distance, "sorted by distance, within range")
	assert(BridgeGrid.valid(near[i].q, near[i].r), "only slots inside the grid")
end
local closed = Targeting.openNear(here, 12, FRAME, function(q, r)
	return not (q == middle and r == 5)
end)
assert(closed[1].distance == grid.SlotStuds, "a closed slot is skipped")

-- isOpenPlot: the open row, and the row after it only behind a finished slot.
local grownSet: { [string]: boolean } = {}
local function grown(q: number, r: number): boolean
	return grownSet[BridgeGrid.key(q, r)] == true
end
assert(Targeting.isOpenPlot(1, 4, 4, false, 4, 1, grown), "the open row is open")
assert(not Targeting.isOpenPlot(1, 4, 4, true, 4, 1, grown), "a finished slot isn't")
assert(not Targeting.isOpenPlot(1, 5, 5, false, 4, 1, grown), "the next row waits for the slot behind it")
grownSet[BridgeGrid.key(1, 4)] = true
assert(Targeting.isOpenPlot(1, 5, 5, false, 4, 1, grown), "... and opens once it's finished")
assert(not Targeting.isOpenPlot(2, 5, 5, false, 4, 1, grown), "only behind its own column")
assert(not Targeting.isOpenPlot(1, 5, 5, false, 4, 0, grown), "AheadRings 0: only the open row")
assert(not Targeting.isOpenPlot(1, 3, 3, false, 4, 1, grown), "rows behind the open one are closed")
assert(not Targeting.isOpenPlot(1, 4, 4, false, 0, 1, grown), "nothing is open once the bridge is done")

return "Targeting: all checks passed"
