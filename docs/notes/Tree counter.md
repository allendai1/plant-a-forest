# Tree counter (2026-10-09)

A board in the hub counting every tree grown in every server ("TREES GROWN ... by everyone playing Plant Trees!"), with your own count under it. The user's pick: count trees grown, not acorns.

- **How it works:** each full-grown tree counts once (ForestService). Every 60 seconds a server adds its new trees to one DataStore number (`GlobalStats` / `TreesGrown`; Studio uses `GlobalStats_Studio`) and reads back the total. The board counts up with every tree in your server and jumps once a minute with everyone else's. `src/server/Services/TreeCounterService.luau`, `src/client/Controllers/TreeCounterController.luau`.
- **"You: N"** is your TreesFinished: the trees you planted the last acorn of (the same number the "Grow 3 trees" quest uses), not every tree you helped with.
- **The board:** `Workspace.Map.Lobby.TreeCounter`, a 1.5x copy of a leaderboard at the end of their row (next to the upgrades station), tagged TreeCounterBoard. Move it anywhere; any part with that tag shows the counter on its front face.
- It starts at 0 at launch; trees grown before it existed aren't counted.

Status: synced to Studio 2026-10-09 evening (the board exists only in the Studio place until you save), not playtested or published.
