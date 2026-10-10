# A bigger map: what it would take (2026-10-09)

The user's idea: make "harder" worlds harder by a bigger forest (more trees, longer walks) instead of more acorns per tree. This is the cost estimate, nothing is built. Earlier notes: the "bigger map" section of [Worlds.md](Worlds.md).

## Where things stand

- **One map for every world.** Plots and rows are built once when a server starts; a new world (`setTier`) only changes the tree species, the World Tree, coins and acorns per tree. The client builds the tiles once.
- **The island is exactly the forest's size.** Measured in Studio: the island is 860 × 832 studs; ring 15's tiles reach about 430 studs out along the trails and 376 between them. The trails end at 440, where the rope bridges start; the islets are at 530–590; the invisible edge floor runs from 355 to 650.
- **The code is already size-generic.** `GameConfig.Grid.ForestRings` drives plots, rings, the target, the ring numbers, the ring trunk and analytics. What's fixed is the map: the Blender meshes and a few radii in `tools/build_map.luau`.

## Sizes

| Forest | Rings | Plots | Outer ring (trail / between trails) | First trip from a dispenser | Trees vs now |
| --- | --- | --- | --- | --- | --- |
| Now | 7–15 | 540 | 416 / 360 | ~320 studs | — |
| +1 ring | 7–16 | 630 | 443 / 384 | ~345 | +17% |
| **+2 rings (suggested)** | 7–17 | 726 | 471 / 408 | ~375 | +34% |
| +3 rings | 7–18 | 828 | 499 / 432 | ~400 | +53% |

The island would grow about 13% (+2 rings) or 20% (+3) across.

## The two ways to do it

**A. Every world bigger.** Change `ForestRings` 9 → 11 and rebuild the map. No new code paths. Sherwood gets bigger too, so its acorn numbers need retuning so it stays the easy world.

**B. Only the harder worlds bigger.** The island is built at the big size; in Sherwood the outer two rings aren't plantable and show as plain meadow. Extra code on top of A:
- ForestService rebuilds its rows (and RingCount) when the world changes, from a new `Tiers[].ForestRings`
- the client shows or hides the outer tiles per world (today it builds them once)
- the arrow, targeting and ring numbers already follow the server's rings

B is about half a day more than A and keeps Sherwood's short first trips for new players.

## The work (A; B adds the list above)

**Map: Blender** (`tools/blender/build_assets.py`, then re-upload with `tools/upload_fbx.py`, free):
- `ISLAND_RINGS` 15 → 17: the island top, the walk plate (`Island_Walk` → WalkFloor), the dirt band and the cliff rock; the underside cone radii (405 / 330 / 220 / 110) scaled up ~13%
- `PATH_END` 440 → ~495: the six trail meshes, and their lantern posts (`range(6, 17)` → `range(6, 19)`)
- clouds can stay (they sit 300–1,350 studs out)

**Map: Studio** (`tools/build_map.luau` and parts saved only in the place):
- `BRIDGE_START` 440 → ~495, so the bridges and the 3 reachable islets move out ~55 studs
- the 6 waterfalls start at the new between-trail edge (376 → ~424)
- the two far islets (560 / 590 → ~615 / ~645)
- the invisible edge floor and wall (`EDGE_INNER, EDGE_OUTER` 355 / 650 → ~400 / ~710)
- `Map.Walkways` (the no-plant strips under the trails, saved in the place, 336 long ending at 436) lengthened to ~495, or the trail hexes in the new rings become plots
- `Map.ForestFloor` (the invisible ground the plots raycast onto) is 2,047 across: already big enough

**Game code and numbers:**
- `Grid.ForestRings` 9 → 11
- acorns: with more plots the same total spreads thinner (trees finish faster), so `SeedsPerPlayer` per world needs a new pass; the full-server cap rises (100 × 726 = 72,600 in Sherwood) and so does the solo floor (5 × 726 = 3,630)
- the forest-complete cutscene's camera orbit (AwakeningController, 280 → 470 studs) reframed
- `tests/ForestSizeCheck.luau` (hard-codes 540 plots), and the docs that quote 540 / 9 rings

**Performance (the real risk):** about 6.7 MeshParts per plot, so a full forest goes from ~3,640 to ~4,900 MeshParts. Desktop has about 2× headroom (60 fps, 5–7 ms CPU), but **no real phone has been measured even at 540**. Before shipping: a phone test with a full forest; the first lever if it struggles is turning off tree shadows (M12).

## Effort

- **A:** about a day: Blender regeneration and upload (~2–3 h), build_map and the Studio parts (~2 h), numbers and cutscene (~1 h), playtest and fixes (~2 h). Plus your phone test.
- **B:** A plus about half a day.

## Gameplay effects to expect

- Outer-first, the first ring is now ring 17 (96 trees) and the first trips are ~18% longer: worse for brand-new players unless Sherwood stays small (B).
- More trees and rings: more ring celebrations, Speed matters more.
- The ring trunk's bands get thinner (4 → 3.3 px at 11 rings): still readable.
