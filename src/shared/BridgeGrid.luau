--!strict
-- BridgeGrid: the bridge's slot grid (2026-10-10; replaced the forest's HexGrid). Shared by server and client.
-- A slot is (q, r): q is the column across the bridge (1..Grid.Columns, left to right looking across), r the row out
-- from the near rim (1..Grid.Rows). `frame` is the BridgeStart part's CFrame: at the rim's edge, in the bridge's
-- middle, at deck height, its LookVector pointing across the canyon. Row 1 starts right at the frame.

local GameConfig = require(script.Parent.GameConfig)

local BridgeGrid = {}

-- A string key for storing slots in a table, e.g. plots["2,14"]
function BridgeGrid.key(q: number, r: number): string
	return `{q},{r}`
end

-- The slot's center at deck height.
function BridgeGrid.toWorld(q: number, r: number, frame: CFrame): Vector3
	local grid = GameConfig.Grid
	local across = (q - (grid.Columns + 1) / 2) * grid.SlotStuds
	local along = (r - 0.5) * grid.SlotStuds
	return frame:PointToWorldSpace(Vector3.new(across, 0, -along))
end

-- The slot a world position falls in (may be outside the grid: callers check).
function BridgeGrid.fromWorld(position: Vector3, frame: CFrame): (number, number)
	local grid = GameConfig.Grid
	local p = frame:PointToObjectSpace(position)
	return math.round(p.X / grid.SlotStuds + (grid.Columns + 1) / 2), math.round(-p.Z / grid.SlotStuds + 0.5)
end

-- Is (q, r) a whole-number slot inside the grid? Also rejects NaN and infinities (client input).
function BridgeGrid.valid(q: number, r: number): boolean
	local grid = GameConfig.Grid
	return q == q and r == r and q % 1 == 0 and r % 1 == 0 and q >= 1 and q <= grid.Columns and r >= 1 and r <= grid.Rows
end

-- The slot one row back toward the rim, the one a slot is built out from.
function BridgeGrid.behind(q: number, r: number): (number, number)
	return q, r - 1
end

return BridgeGrid
