# Plant the Forest

A Roblox co-op incremental game. Up to 50 players carry seeds from a central hub into a shared forest of big low-poly trees on visible hex tiles. Every seed instantly grows a tree a step and fills the server's Forest Bar, while the Ancient Tree in the hub grows with the bar. When the bar fills, the Forest Awakening plays and the same forest re-themes into the next tier. It's modeled on the Roblox game Build the Pyramid.

**Picking up in a new session? Read [docs/HANDOFF.md](docs/HANDOFF.md) first:** current status, how to sync to Studio, gotchas and what's next.

**The Obsidian vault:** this folder is also the user's Obsidian vault, and [docs/notes/](docs/notes/Index.md) is the notebook you share with them. At the start of every session read [docs/notes/Index.md](docs/notes/Index.md), list the folder for notes the user added without indexing (add them to the index), and open the notes that bear on the task. When the user asks you to note or remember something about the project, write it there: one topic per note, normal Markdown links with relative paths (not `[[wikilinks]]`), and a line in the index.

## Sources of truth

- [docs/GDD.md](docs/GDD.md): the full game design. Read it before starting any system.
- `src/shared/GameConfig.luau`: every tunable number and the stat formulas. Never hard-code a balance number anywhere else; add it here.
- [docs/MVP_PLAN.md](docs/MVP_PLAN.md): the build order. Work one milestone at a time and tick its checkboxes when done.
- `docs/Balancing.xlsx`: the spreadsheet the numbers came from. If you change a number in GameConfig, say so, so the sheet can be updated.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/DESIGN_CHANGES.md](docs/DESIGN_CHANGES.md): the approved architecture and the redesign (big trees, hex tiles, sections filled row by row, low-poly art).

If the GDD and GameConfig disagree, stop and ask which is right.

## What's in scope right now

The MVP is **tier 1 (Meadow Woods) only**, Common trees from the free acorns (plus the seed shop's special trees, below), and no weather (Rain and the Wet mutation were postponed to after launch on 2026-10-06). See the MVP checklist in [docs/MVP_PLAN.md](docs/MVP_PLAN.md).

The seed shop and its special trees were built on 2026-10-07 at the user's request ([docs/plans/SeedShop.md](docs/plans/SeedShop.md)). They're switched off for the MVP by the feature flag `GameConfig.Features.SeedShop` (false); flip it to release them.

The Lord of the Forest character is also switched off for now (`GameConfig.Features.LordOfTheForest`, false; its pass is off sale on Roblox) and saved for a later update.

Do **not** build these yet; they're in the backlog: Seed Pouch, Lucky Soil, starter rewards, pre-set rare hexes, Mythic trees, ring completion bonuses, Quick Hands, trading, personal groves, a Tree Book. Tier 2 and the other four weather events come after the MVP.

## Core rules that are easy to get wrong

- **Every seed counts instantly.** On each seed: the Forest Bar ticks up, 1 coin (times mutation) goes to the player who delivered it, and the tree bounces one step. There is no waiting and no watering.
- **A hex needs many seeds.** Each world sets its own (`Tiers[].SeedsPerHex`, published as ForestState SeedsPerHex): Sherwood 100 (an easier first world, 2026-10-08), Kyoto and the Smoky Mountains 200. One big tree per hex. Use `GameConfig.growthStage(seeds, seedsPerHex)` for the 8 model stages (seedling to full grown, `GameConfig.Growth.StageStarts`; docs/plans/TreeStages.md).
- **Trees are shared.** Anyone's seeds can grow any unfinished tree. Store the UserId of the player who *started* it (the first seed) for the name label.
- **Players plant where they stand.** The target is the closest open hex (empty or unfinished) within planting range in the open row. The mouse and taps don't choose a hex (since 2026-10-07): it's always the closest. Overflow from a press goes to the next-closest open hex. Show an outline and a progress meter on the target only for the local player. Hex tiles are visible; an arrow points to the nearest open plot when none is in range.
- **One press moves one seed** at the rack and at the forest; holding E repeats. Bulk Pickup and Bulk Plant raise the per-press amount.
- **Training.** Press E at a bench press to start benching (it continues until you jump off); stepping onto a treadmill starts running automatically. One rep every 0.25 s worth +1 times that station's multiplier (one bench and treadmill per tier: 1x, 2x, 5x, 10x, 25x, 50x, 75x, 100x), ticked by the server per player. Stations unlock with forests or that tier's game pass. Planting never gives stats.
- **The Forest Bar target follows the server** (since 2026-10-08; it used to be fixed): when a forest starts, seeds per tree = the players in the server × the world's `SeedsPerPlayer` ÷ the plots, at least `ForestSize.MinSeedsPerHex` (3; 5 until 2026-10-09) and at most the world's `SeedsPerHex` (`GameConfig.seedsPerHexFor`). It stays fixed while that forest grows. Target = plantable hexes × that.
- **The forest opens one ring at a time** (since 2026-10-07; it was one section's slice of a ring, section by section). The whole ring is open, from the outer edge (ring 15, 84 plots) in to the hub (ring 7, 36 plots). Since 2026-10-08 that order can be A/B tested (paused at launch: every server is outer-first until there are enough players; `OuterFirstShare` sets the split) (`GameConfig.Experiments`, ForestState `Layout` / `OutsideIn`); code must read the server's order from ForestState, not `Grid.OutsideIn`. The next ring opens only when every tree in the current ring is full grown; since 2026-10-09 a plot up to `Grid.AheadRings` (1) rings further in opens early once the tree just outside it is full grown (`Targeting.isOpenPlot`, shared by server and client). Finishing a ring plays the ring moment (a wave around it, chimes, the Ancient Tree shakes, "Ring 3 of 9 complete!"); the ring trunk circle right of the Forest Bar shows the rings (the bar's tick marks were removed on 2026-10-08).

## Architecture

- Strict Luau (`--!strict` in every file). Files in `src/` are the source of truth and are pushed into Studio through the Studio MCP connection, not `rojo serve`; `default.project.json` only feeds `rojo sourcemap` for luau-lsp.
- `src/shared` → ReplicatedStorage: GameConfig, HexGrid, shared types, remote definitions.
- `src/server` → ServerScriptService: services (ForestService, CarryService, TrainingService, EconomyService, DataService, WeatherService, AwakeningService).
- `src/client` → StarterPlayerScripts: controllers (TargetController, CarryController, HUD, Tutorial).
- **The server owns everything that matters.** Clients only send requests ("grab", "plant at hex q,r", "buy upgrade X"). The server validates distance, the open row, hex state, carried seeds and coins, and rate-limits every remote.
- Forest state lives in ForestService on the server. Replicate the Forest Bar with an attribute; replicate hex changes in small batched updates, not one remote per seed.
- Trees are built on the client from (species, seed number, stage), using the low-poly meshes generated by `tools/blender/build_assets.py` (2 Common and 4 special species × 8 stages, plus the Ancient Tree).
- Plan for about 540 big trees plus their tiles: StreamingEnabled, a few MeshParts per tree, no per-tree scripts, no per-frame loops over all trees.

If the `roblox-dev` plugin skills are available, use them: `roblox-architecture` for layout, `roblox-security` for every remote, `roblox-datastores` for saving, `roblox-performance` for the tree count, `luau-strict-typing` for types, and `roblox-testing` for test remotes.

## Plan before you build (always)

Never write game code for a milestone until its plan has been approved.

**Once, before M0: the architecture overview.** If [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) doesn't exist yet, write it first and stop for approval. It covers:

- every server service and client controller, and what each one owns
- every remote: its name, direction, payload and the server-side checks it gets
- how forest state reaches clients (the Forest Bar attribute, batched hex updates)
- what's in the saved player profile

Once approved, treat it as a source of truth alongside the GDD. If a later milestone needs to change it, say so in that milestone's plan.

**Before every milestone: a milestone plan.** Write it to `docs/plans/M<number>.md` (for example [docs/plans/M4.md](docs/plans/M4.md)), then stop and wait for approval. Keep it short and include:

1. **Goal:** one or two sentences, in the words of [docs/MVP_PLAN.md](docs/MVP_PLAN.md).
2. **Design check:** how each part maps to the GDD, quoting the rule where it matters (for example: plant into the closest open hex, not the nearest unfinished tree).
3. **Files:** every file you'll create or change, and what goes in each.
4. **Remotes and data:** any new remotes or saved fields, and whether they match [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
5. **Open questions:** anything the GDD doesn't answer. Ask these instead of guessing.
6. **Test plan:** how you'll check the milestone's "Done when" line, including any multi-client or exploit tests.

Only start coding after the user approves, and stick to the approved plan. If something forces a change mid-build, stop and explain before continuing.

## After each milestone

- Run the "Done when" test in Studio (or a multi-client test for anything shared) and say exactly what you verified and what you couldn't.
- Tick the milestone's boxes in [docs/MVP_PLAN.md](docs/MVP_PLAN.md).
- Add a short "What changed from the plan" note at the bottom of that milestone's plan file.
- Stop and wait before starting the next milestone.

## Working style

- Keep modules small and pure where possible (formulas in GameConfig, hex math in HexGrid) so they can be tested outside Studio.
- When a design question comes up that the GDD doesn't answer, ask instead of guessing. Open questions are listed at the end of the GDD.
- Do one milestone at a time unless the user explicitly asks for more.
