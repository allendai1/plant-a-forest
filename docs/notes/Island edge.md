# Island edge

**Problem:** running off the island's edge teleported you back to the spawn, which was quicker than walking back, so it worked as a shortcut.

**Fix (2026-10-08):** past the edge there's now an **invisible floor** at ground height, so players just keep running instead of falling. An **invisible wall** stops them about 650 studs from the center (the edge is 365 to 405 studs out, depending on direction).

- Built from 64 invisible slabs and walls in `Workspace.Map.EdgeFloor`, also added to the map script (`tools/build_map.luau`).
- The old "fell off, back to spawn" safety stays as a backup, but players shouldn't reach it now.
- Side effects: it looks like running on air past the edge, and the two small floating islets are now reachable on foot.
- Verified in a playtest: a character ran off the edge, stayed at the same height, and stopped at the wall.
- If you'd rather stop players right at the edge, the wall can move in.
