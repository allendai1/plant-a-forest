# MVP build plan

Goal: tier 1 (Meadow Woods) playable start to finish with Common trees (the low-poly leafy tree and pine) and Rain. The redesign of 2026-10-06 is in [docs/DESIGN_CHANGES.md](DESIGN_CHANGES.md). Build in this order; each milestone should run in Studio before the next starts. Numbers come from `src/shared/GameConfig.luau`.

## M0. Project setup

- [x] Rojo project with `src/shared`, `src/server`, `src/client`; strict Luau everywhere
- [x] Linting and formatting set up (Selene, StyLua) if available
- [x] `GameConfig.luau` and `HexGrid.luau` synced into ReplicatedStorage
- [x] A Remotes module defining every RemoteEvent/RemoteFunction in one place

Done when: the project syncs into an empty place and runs with no errors.

## M1. Hex grid and tiles

- [x] ForestService builds the grid with `HexGrid.rings(HubRings + ForestRings)` around a `ForestCenter` part, skipping rings 0–3 (the hub)
- [x] Hexes whose center is inside any part tagged `NoPlant` are skipped (none on the MVP map, which has no paths)
- [x] Each plot is raycast onto the ground on the server; a minimal client ForestController draws a hex tile per plot from the snapshot, locked or open (the outermost ring starts open)
- [x] Server state per hex: ring, position, seeds received, species, mutation, starter UserId, tree seed
- [x] Count plantable hexes and set the tier 1 Forest Bar target = plantable × 35

Done when: on a flat test map, 684 tiles appear (ring 15 open, rings 4–14 locked) and the target (23,940) is printed.

## M2. Stats and training

- [x] Strength and Speed stored on the server per player
- [x] Bench press and treadmill zones: one rep (`RepAmount` × gym multiplier) every `RepSeconds` (0.25 s) while standing in them, per player, server-ticked (no client input)
- [x] Humanoid WalkSpeed = `GameConfig.walkSpeed(Speed)`
- [x] Capacity = `GameConfig.capacity(Strength)`

Done when: standing on the bench press for 1 second (4 reps) raises capacity from 1 to 2, 7 seconds gives 28 Strength (carry 4), and walk speed is 32 at 0 Speed and about 46 at 230.

## M2b. Interactive training stations

- [x] Bench press: press E to start benching (seated and held by the server), jump to leave
- [x] Treadmill: stepping on starts the run animation; Speed while on it
- [x] One bench and one treadmill per multiplier (1x, 2x, 5x, 10x, 25x; 50x, 75x and 100x added after M11), shared by any number of players; on a bench each player sees only one occupant
- [x] Locked stations: requirement message and an unlock popup (game pass per tier, placeholder ids until the passes exist)

Done when: benching and the treadmill pay +1 × the station multiplier per rep, locked stations refuse and show the popup, and leaving, dying and respawning release the player cleanly.

## M3. Seed rack and carrying

- [x] Seed rack prompt in the hub: each press grabs `BulkPickup` seeds (1 by default), up to capacity; holding E repeats every `HoldRepeatSeconds` (run by the server from the prompt's press and release)
- [x] Giant seed placeholder over the head, scaled by the number of seeds carried (using the `GiantSeedMilestones` thresholds), with a count label (replaced on 2026-10-06 by acorns circling the head, [docs/plans/AcornOrbit.md](plans/AcornOrbit.md))
- [x] Carried count lives on the server

Done when: one player can fill to capacity by holding E, and the giant seed visibly grows at 5 and 15 seeds.

## M4. Targeting and planting

- [x] Client TargetController picks the closest open hex (empty or unfinished, in the open ring) within `BaseRangeStuds` + Planting Range; PC mouse hover can pick another hex in range (mobile: a tap on the game view plants into the nearest)
- [x] Target indicator: hex outline on the tile and a floating "12 / 40" meter, local player only; outline turns gold when the next press finishes the tree; nothing shown when out of range
- [x] Arrow to the nearest open plot whenever the player carries seeds and nothing is in range
- [x] Plant remote sends the hex key; the server validates distance, ring unlocked, hex unfinished, seeds carried, and rate limit
- [x] Each press plants `BulkPlant` seeds (1 by default); overflow goes to the next-closest open hex; holding E repeats
- [x] The first seed in an empty hex records the starter UserId
- [x] Rings open outside-in: the next ring inward opens when every tree in the current ring is full grown

- [x] Hex updates replicate in batches, not one remote per seed (moved here from M5; the meter needs them)

Done when: two clients can plant into the same tree, and a spoofed remote (wrong distance, locked ring, no seeds, full hex, spam) is rejected.

## M5. Growth, Forest Bar and coins

- [x] Tree models: the low-poly leafy tree and pine, 8 stages each since 2026-10-06, 4 before (meshes from `tools/blender/build_assets.py`); `GameConfig.growthStage` picks the stage
- [x] Tile states: open tiles pulse, started tiles turn mossy with a glowing rim, finished tiles mossy
- [x] Every seed: squash-and-stretch bounce, +1 coin to the planter
- [x] Finishing seed: leaf burst and chime placeholder
- [x] Ring complete moment: the wave around the ring, golden sweep, the next ring lights up, banner (after M5: replaced by a small row moment and the big section complete moment, see [docs/DESIGN_CHANGES.md](DESIGN_CHANGES.md))
- [x] Forest Bar replicated via an attribute; HUD bar shows seeds / target; the Ancient Tree in the hub grows with the bar
- [ ] ~~Starter's name shows when walking near a tree~~ (postponed 2026-10-06; the starter UserId is still stored per plot)

Done when: a full trip shows bounces on every seed and a stage swap at every stage boundary, finishing a ring plays the ring complete moment, and the bar and the Ancient Tree match the server count.

## M6. Forest Awakening

- [x] When the bar fills: a skippable cutscene of the Ancient Tree awakening, then a 2-minute break (trees sway, placeholder animals); changed from a 2-minute locked sequence, see [docs/plans/M6.md](plans/M6.md)
- [x] Everyone online gets +500 coins and +1 forests completed (changed from a 50-seed chest)
- [ ] ~~Server-wide 2x coins for 10 minutes~~ (left out for now)
- [x] The Ancient Spring: 2x/3x/5x Strength and Speed during the break; Robux extensions of the break (doubling prices, up to 8 minutes)
- [x] The forest resets (MVP: back to tier 1; tier 2 comes in phase 2) and the Ancient Tree shrinks back to a sapling
- [x] Stronger training stations unlock from forests completed (M2b reads ForestsCompleted, so this only needs the +1)
- [x] Studio test panel: fill the row, the section or the forest, +50 seeds, extend and end the break

Done when: filling the bar in a test (use a test command to speed it up) plays the sequence, grants credit correctly and resets the grid.

## M7. Upgrades

- [x] Upgrade shop UI for Bulk Pickup, Bulk Plant and Planting Range (Quick Hands dropped from the MVP)
- [x] Costs from `GameConfig.upgradeCost`; purchases validated on the server (and only while standing in the shop ring)

Done when: buying each level deducts the right coins and changes the behavior.

## M8. Saving

- [x] Player profile: Strength, Speed, coins, upgrade levels, forests completed (tutorial progress is added with the tutorial in M10)
- [x] Schema version, session locking, autosave every few minutes, save on leave and on shutdown (ProfileStore)

Done when: stats survive rejoining and a forced shutdown, and two servers can't both write the same profile.

## M9. Rain and the Wet mutation (postponed to after launch, 2026-10-06)

Postponed by the user: weather comes from the garden games, not Build the Pyramid, and onboarding matters more before launch. It becomes the first update, with the rest of the weather events.


- [ ] Weather loop: an event every 10 minutes lasting 2.5 minutes; MVP picks Rain only
- [ ] A tree started (first seed) during Rain has a 20% chance to become Wet; seeds into a Wet tree pay 2x coins
- [ ] Rain visuals and a dripping look on Wet trees
- [ ] Server-wide banner when the weather starts

Done when: trees started during Rain show the Wet look about 1 in 5 times, and coins double for them.

## M10. First-time experience

- [x] Arrow plus one-line prompts: grab a seed → plant it → (after 3 plants) go train → spend coins on upgrades
- [x] Free gift popup (like and favorite; no group yet): 500 coins, once
- [ ] ~~Quest list~~ (postponed by the user, 2026-10-06)

Done when: a new player plants their first seed within 20 seconds without reading anything long.

## M11. Art pass (moved up from after the MVP, 2026-10-06)

- [x] The floating island: cliffs under the outer ring, waterfalls, floating islands with bridges from the trail ends, clouds and sky
- [x] Tiles like the reference (dirt with a grass border, grassy once planted), grass verges along the trails
- [x] The empty plaza districts: gift board, fountain, flower garden
- [x] Blender animals for the break; leaf and bark tints from each tree's seed
- [ ] 60 fps with a full forest: moved to M12 (measured 15 fps at maximum graphics quality, 60 at automatic from the spawn)

Done when: screenshots match the references, everything still works, and Studio holds 60 fps with a full forest. Plan: [docs/plans/M11.md](plans/M11.md).

## M12. Performance pass (moved after the art pass, 2026-10-06)

- [x] Full forest of 540 trees and their tiles on a test server with StreamingEnabled (60 fps in Studio at max quality, 2026-10-08)
- [ ] Measure memory, frame time and network traffic on a low-end device or emulator
- [ ] Fix the worst offenders before adding more visuals
- [x] Studio at maximum graphics quality with a full forest and the break: 60 fps (2026-10-08; the old 15 fps was Studio's background-window cap)

Done when: a full forest runs smoothly on mobile.

## After the MVP

- **Phase 1, weather update:** Snowfall, Thunderstorm, Meteor shower and Golden hour; weather totems.
- **Phase 2, second tier:** Cherry Blossom Valley (same map re-themed, seeds per hex rescaled, about 92), the loop back to tier 1, leaderboards.
- **Backlog:** see the end of [docs/GDD.md](GDD.md).
