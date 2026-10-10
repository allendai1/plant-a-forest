# Field and town (2026-10-09)

The user's call: a forest all around the spawn doesn't tell new players where to go (Build the Pyramid has one pile and one pyramid). So the map gets a front and a back.

## The field (built)

- **The forest is only the west half** of the island, across the World Tree from the town (the spawn, shop, NPCs, gift boards and leaderboards are all on the hub's east side). About 270 trees instead of 540; the east side's forest area is plain grass.
- **Only the 4 acorn dispensers facing the field stay** (the 2 on the town side go), and **the spawn turns to face the World Tree.**
- Seeds per tree double on their own (the server's player count spread over half the trees), so busy servers' forests stay the same size; a solo forest halves (810 acorns), being at the 3-per-tree minimum.
- **Rounds** became 3 rings (63 trees), then 6 (153), then all 9 (270); they were 2, 4, 6 around the whole hub.
- **The old forest (the user's ask, 2026-10-09):** the town's side isn't empty grass: every spot there that would be a plot (not the walkways) gets a full-grown tree of the current world's Common trees, 95-130% size, the same on every client, built again when the world changes. Nothing to plant or touch. It's about as many trees as the half that moved (~270), so the frame rate should match the old full forest; still worth a phone check. Sizes at the top of ForestController (`BACKDROP_SIZE`). When the town is built, its rectangle needs carving out of it.
- **The town side's three trails are gone** (the user's ask: they led nowhere): the trail, its no-planting strip and the bridge at its end, for the trails at 0° and ±60°; the old forest fills their spots. The floating islets stay as scenery. The field's three trails stay.
- All done when the server starts (ForestService.init); the place itself is unchanged. `GameConfig.Field`: `Enabled` (false = the forest all around and six dispensers again), `Facing` (180 = west) and `HalfAngle` (90).

Status: synced to Studio 2026-10-09 evening, not playtested or published.

## The town (planned, not built)

A rectangle east of the round World Tree garden, sketched in chat on 2026-10-09:

- a main street from the spawn straight to the World Tree;
- the training yard: the 8 pads in one row in order, 1x by the garden (close to the acorns, a short walk for the tutorial's training step) to 100x further down the street;
- the shop row on the other side: upgrades, the Forest Ranger, the free gift and the group gift;
- the leaderboards and the tree counter along the street;
- **the spawn at the town's near end, by the garden, facing the tree** (not at the far end: that would be ~400 studs, 25 s, from the acorns).

Cost: about 1.5-2 days of map work (paving and fence, moving every station and board with code, updating tools/build_map.luau to match, a phone check). Waiting for the user's OK on the layout after they see the field.

## The hill (prototype, 2026-10-09)

The user's idea after "it won't be as satisfying as placing blocks on a pyramid": the realm as a terraced hill below the village, filled from the bottom terrace up, so finished trees are below you, the forest climbs toward the village and trips get shorter toward the end. Proposed as part of the [Norse concept](Game%20concept%20(Norse).md).

A look-only model is in the place: `Workspace.HillPreview`, 2,200 studs south of the island (not connected to the game). A 54-stud plateau with Yggdrasil, the seed pile, training stones, longhouses and Valhalla in the canopy; the west half of the realm in 9 terraces 6 studs apart (rings 13-15 planted, ring 12 open, 7-11 ash), with ramps down the three field trails. It's saved with the place if you save; delete the folder to remove it. Making it the real map means raising the hub and town 54 studs (or building the field below them).
