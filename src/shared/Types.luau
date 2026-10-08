--!strict
-- Types that cross the client/server boundary (docs/ARCHITECTURE.md section 6).

-- The GetForest snapshot. Plots are numbered 1..N in HexGrid.rings order.
-- layout: q, r, y per plot (3 numbers each); y is the ground height from the server's raycast.
-- state: seeds, species, mutation, starterUserId, treeSeed per plot (5 numbers each); 0 = none.
export type Snapshot = {
	seq: number,
	layout: { number },
	state: { number },
}

-- A batch of changed plots, sent to every client every Forest.BatchSeconds while anything changed.
-- entries: index, seeds, species, mutation, starterUserId, treeSeed per changed plot (6 numbers each).
-- Each entry is the plot's full state, so applying one twice is harmless; batches with seq <= the
-- snapshot's seq are already included in it.
export type HexBatch = {
	seq: number,
	entries: { number },
}

return {}
