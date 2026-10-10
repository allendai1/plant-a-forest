# Design changes: the giant sequoia forest

Status: **approved and applied 2026-10-06.** Worked out from the Studio previews. Applied directly to [docs/GDD.md](GDD.md) (now the master copy), GameConfig, [docs/MVP_PLAN.md](MVP_PLAN.md), [docs/ARCHITECTURE.md](ARCHITECTURE.md) and [CLAUDE.md](../CLAUDE.md). `docs/Balancing.xlsx` still needs updating by hand (see the end of this file).

## Why

The original forest was about 3,000 small trees on an invisible grid. In the previews it felt small, and an invisible grid made it hard to see where trees were missing. The pyramid works because the structure is huge and every missing block is obvious. This version keeps the same loop but makes the forest grand and every open spot obvious.

## The changes

| # | Change | Old | New |
| --- | --- | --- | --- |
| 1 | **Giant sequoias** | ~3,000 small trees | 684 sequoias, about 115 studs tall with 9-stud trunks when full grown |
| 2 | **Bigger hexes** | `HexSize` 5 (trees 8.7 studs apart) | `HexSize` 16 (trees ~28 studs apart) |
| 3 | **Rings** | hub rings 0–5, forest rings 6–33 | hub rings 0–3 (~97 studs radius), forest rings 4–15 (12 rings) |
| 4 | **Seeds per tree** | 8 (tier 1) | 35 (tier 1). Target = 684 plots × 35 = **23,940 seeds**, about the same as before, so the ~12-minute forest still roughly holds |
| 5 | **Visible hex tiles** | empty plots are invisible or mounds; "never grid lines" | every plot is a visible hex tile. Locked: dark. Open and empty: bright with a glowing rim and a soft pulse. Started: mossy with a glowing rim. Finished: mossy, under its tree |
| 6 | **Outside-in rings** | rings open from the hub outward | the outermost ring opens first; the forest closes in on the hub, like a pyramid going from its wide base to its small top |
| 7 | **Ring unlock at 100%** | next ring at 80% | next ring opens when **every** tree in the current ring is full grown (otherwise the last gaps are left far out at the edge) |
| 8 | **Ring complete moment** | none | when a ring's last tree finishes, a celebration plays (see below) |
| 9 | **Ancient Tree grows with the bar** | appears only at the Awakening | a colossal tree in the hub grows as the Forest Bar fills, visible from anywhere; at 100% it awakens for the finale and resets to a sapling with the forest |
| 10 | **Seed rack at the Ancient Tree's roots** | rack somewhere in the hub | a pile of giant acorns at the base of the Ancient Tree; spawn just beyond it, facing the forest |
| 15 | **No paths** | four no-plant paths and a stream | just the central clearing with the Ancient Tree, plus decorations and shops that fit the theme; the forest is all plots |
| 11 | **Planting range** | base 10 studs, upgrade +2 per level | base about 30 studs, so the neighboring plot is reachable; upgrade steps scaled to match (exact numbers in the M4 plan) |
| 12 | **Growth stages** | 4 (sprout, sapling, young, full) | about 6, because 35 seeds per tree needs more visible steps (exact boundaries in the M5 plan) |
| 13 | **Arrow to the nearest open plot** | tutorial only | for everyone, whenever you carry seeds and no open plot is in range |
| 14 | **Camera** | default | Invisicam (trunks fade instead of pulling the camera in), canopies ignored by the camera, max zoom about 60 studs, brighter ambient light under the canopy |

## Ring complete moment

When the last tree in a ring finishes (about 2 to 3 seconds in all):

1. **A wave runs around the ring.** Each tree in the ring sways and does a small bounce one after another, so a ripple travels all the way around the forest. A golden light sweeps along the ring's tiles behind it.
2. **Leaf burst and a rising chime** as the wave closes the loop.
3. **The next ring opens:** its rims light up, as if the glow flows inward from the finished ring.
4. **The Ancient Tree shakes and grows a step**, and the Forest Bar pulses.
5. **A banner:** "Ring 7 of 12 complete!"

This is all client-side, triggered when the `UnlockedRing` attribute changes. It needs no new remote and costs one short tween per tree in the ring (at most about 90 trees).

## What this changes in each file

- **GDD:** Forest layout (hex tiles, ring direction and unlock rule, one tree per hex still true), Map layout (hub size, ring counts, walk times), Trees (sequoias, seeds per hex, growth stages), Forest completion (Ancient Tree grows with the bar, ring complete moment), First-time experience (arrow to the nearest open plot, rack at the Ancient Tree). Remove "never grid lines" and "the grid disappears once planted".
- **GameConfig (done):** `Grid.HexSize` 5 → 16, `Grid.HubRings` 5 → 3, `Grid.ForestRings` 28 → 12, `Grid.RingUnlockFill` 0.8 → 1.0, new `Grid.OutsideIn = true`, `Tiers[1].SeedsPerHex` 8 → 35, `Planting.BaseRangeStuds` 10 → 30. Still to do: the `PlantingRange` upgrade values (M4) and about 6 growth stages (M5). Tier 2's 21 seeds per hex scales to about 92 when tier 2 is built.
- **Balancing.xlsx (by hand):** `HexSize` 16, `HubRings` 3, `ForestRings` 12, 684 plots, 35 seeds per hex, target 23,940, `BaseRangeStuds` 30, ring unlock at 100%, outside-in. Walk times change (the farthest ring is about 12 s from the spawn instead of 8.5 s), so the ~12-minute estimate should be rechecked.
- **ARCHITECTURE.md:** tiles are client-built from the snapshot, like mounds were (one merged hexagon per plot). The hex state already covers everything; the unlocked ring now counts down instead of up.
- **Backlog:** rarity odds were sized for ~3,000 trees per forest (about 1 Legendary each). With 684 trees they need retuning when rarity is built.

## Decisions

1. **Paths:** removed. The map is the central clearing with the Ancient Tree, decorations and shops that fit the theme, and 684 plots around it.
2. **Ring complete reward:** yes, finishing a ring should pay bonuses, but that goes in the backlog. The MVP plays the moment only.
3. **GDD:** edited directly in [docs/GDD.md](GDD.md), which is now the master copy.

## Art direction update (2026-10-06)

After the style reference image (a floating island of hex tiles around a glowing central tree):

1. **Low-poly style, not sequoias.** Trees are stylized low-poly (faceted, flat shaded) instead of giant sequoias. Full-grown sizes are about 42 × 40 studs (leafy, tall × wide) and 45 × 24 (pine): modeled larger, then scaled to 60% (`FOREST_TREE_SCALE`) so one tree fits about one tile like in the reference. The Ancient Tree is about 354 × 384 (see 7 below). Everything is generated in Blender by `tools/blender/build_assets.py`.
2. **8 growth stages** (changed 2026-10-06 from 4, the user's request; [docs/plans/TreeStages.md](plans/TreeStages.md)). Seedling, sprout, sapling, small, young, growing, mature, full grown, packed toward the start: with 44 seeds the model changes at seeds 1, 3, 6, 10, 16, 24, 33 and 44 (`GameConfig.Growth.StageStarts`). Each stage change adds a small leaf puff, and a rising note for your own seeds.
3. **Two Common species:** a round leafy tree and a pine.
4. **The Ancient Tree's look:** thick stylized trunk, roots around its base, a large two-tone low-poly canopy, subtle cyan/green glowing accents, and stones, flowers and grass around it.
5. **Walkways come back** as decoration: wooden walkways and lanterns between rings and out from the hub. Layout still to be decided.
6. **Floating island:** the map edge is a floating island with cliffs, waterfalls and small islets, instead of hills.
7. **A grand world tree:** the Ancient Tree is about 354 studs tall and 384 wide full grown, with a 60-stud trunk, roots kept inside the hub (72-stud reach) and an umbrella canopy high above the inner rings. Its 4 models are about 55, 125, 230 and 354 tall, and the game scales it smoothly between them with the bar. The ground decoration is a separate `AncientBase` model that never scales.

## Walkway spokes (2026-10-06)

Six straight walkways run out from the hub along the grid's three natural lines through the center. They cover the 6 corner hexes of every ring, so 72 of the 684 hexes become walkway: **612 plots**. Seeds per hex goes from 35 to **39**, keeping the target near 24,000 (612 × 39 = **23,868**). The model changes at seeds 10, 20 and 39. The walkway parts are tagged `NoPlant`, so M1's center-only check blocks those hexes with no code change. For the spreadsheet: 612 plots, 39 seeds per hex, target 23,868.

## Bigger hub and training rate (M2, 2026-10-06)

- **Bigger hub (option A):** hub rings 0–4 (about 105 studs radius) so the spawn, rack, Training Grove, shop and gift board fit in a band around the world tree's 72-stud roots. The forest keeps its outer edge: rings 5–15, 660 hexes, 66 under walkways, **594 plots**. Seeds per hex 39 → **40**, target **23,760**. Stage changes at seeds 11, 21 and 40.
- **Training rate from the pyramid:** a rep every **0.25 s** worth **+1 × gym multiplier** (4 per second at 1x; +2 per rep at 2x). Measured: ~10 in 2.5 s at 1x, 100 Strength in 13 s and 50 Speed in 6.5 s at 2x. Each player has their own timer; stepping off drops the unfinished rep. Training is 4 times faster than the spreadsheet assumed, so carry 2 comes after about 1 second and carry 6 after about 12.
- **For the spreadsheet:** hub rings 4, forest rings 11, 594 plots, 40 seeds per hex, target 23,760; training 4 per second at 1x (rep 0.25 s, +1 per rep). Recheck the ~12-minute forest estimate.

## Interactive training stations (M2b, 2026-10-06)

- **Bench press:** press E (tap on mobile) to start; it keeps paying until you jump off. **Treadmill:** stepping on starts the run animation automatically.
- **One station per multiplier** (1x, 2x, 5x, 10x, 25x, and since after M11 50x, 75x, 100x), shared by any number of players. On a bench each player sees only one occupant (themselves, or whoever sat down first); treadmill users overlap.
- **Multipliers live on the stations** and unlock with forests (2x at 1, 5x at 3, 10x at 8, 25x at 15, 50x at 25, 75x at 50, 100x at 100), or with a **Robux game pass per tier**. A pass unlocks only its own tier. Trying a locked station shows the requirement and an unlock popup. Pass ids are placeholders (`GameConfig.StationPasses`) until the passes are created on the Creator Dashboard.

## Sections filled row by row (after M5, 2026-10-06)

**Why:** a whole ring is 84 trees (over 3,000 seeds) before anything completes. Filling one section at a time, row by row, gives a win every 4–14 trees and a whole finished wedge of forest early in every forest.

- **Sections:** the six walkway spokes split the forest into six wedge-shaped sections of 99 plots (rows of 14, 13 ... 4 plots from ring 15 in to ring 5).
- **One row open at a time:** one section's plots in one ring. The next row inward opens when every tree in the current row is full grown (still `RingUnlockFill` 1.0).
- **Order:** the section the seed rack is in goes first, then the next one around the hub. Each new section starts again at the outer edge.
- **Moments:** finishing a row plays a small moment (a quick wave with a golden sweep along the row, one chime, the next row lighting up). Finishing a section plays the big one (the wave over the whole section toward the hub, a rising chime, the next section's first row lighting up, the Ancient Tree shaking, the bar pulsing, and the banner "Section 2 of 6 complete!"). This replaces the ring complete moment.
- **Trade-off:** trips no longer get steadily shorter over a forest. They follow a sawtooth, starting at the outer edge again for each of the six sections, and the finale is in the last section rather than all around the hub.
- **Code:** `HexGrid.side(q, r)` gives a hex's section. ForestService orders the 66 rows and replicates the open one as the `OpenRow` attribute (section, ring), plus `StartSide`, replacing `UnlockedRing`. The Studio command `fillOpenRing` is now `fillOpenRow`.
- **For the spreadsheet:** the unlock rule changed from rings to rows (6 sections × 11 rows, outside-in within a section). No numbers changed.

Verified in Studio: 66 rows, 99 plots in every section; the first open row was the 14 plots of the rack's section (rack at 330°, row from 303° to 357°). Finishing it opened the next 13 inward with the row moment and no banner. Finishing the section's last row (ring 5) played the section moment with "Section 1 of 6 complete!" and the Ancient Tree shaking, and opened the neighboring section's outer 14 plots, with the bar at 3,960 (99 × 40).

## Bigger hub (after M6, 2026-10-06)

**Why:** the full-grown Ancient Tree's roots fill most of the old hub (72 of its ~105 studs), leaving no real space for training, the shop or the spawn.

- **Hub rings 4 → 6** (about 180 studs in radius), **forest rings 11 → 9** (rings 7–15). The map's outer edge doesn't move.
- **540 plots** (594 hexes minus 54 under the walkways), 6 sections of 90 plots, rows of 14 down to 6.
- **Seeds per tree 40 → 44**, so the bar target stays exactly **23,760**. Stages: 1–11 sprout, 12–22 sapling, 23–43 young tree, 44 full grown.
- The lobby's look (glyphs and vines on the tree, the root garden, a stone plaza, fences and lanterns, the shop altar with its ring, six acorn racks around the roots, tier pads for training) was built in M6b ([docs/plans/M6b.md](plans/M6b.md)). The first section to open is now the one in front of the spawn, since there are seed racks all around the tree.
- **For the spreadsheet:** hub rings 6, forest rings 9, 540 plots, 44 seeds per hex, target 23,760.

## Seed shop: special trees boost training, not coins (2026-10-07, the user's request)

- **Replaces the backlog's rarity plan.** That plan was a roll on the first seed, with rarer trees paying more coins per seed.
- **What replaces it:** a Grow a Garden-style seed shop ([docs/plans/SeedShop.md](plans/SeedShop.md)).
- **Why boosts instead of coins:** a tree only takes 44 seeds, which a strong player plants in one press, and coins only buy upgrades (about 41,000 coins maxes them). A training boost stays worth having at every level, and the shop gives veterans something to spend coins on.
- **Numbers:** Palm +25%, Cherry Blossom +50%, Redwood +100% (+0.25x for everyone), Crystal Tree +200% (+0.5x for everyone). Your own trees are capped at +300%, everyone's at 2x, and you can plant 3 special seeds per forest.

## Acorns circling the head instead of one giant seed (2026-10-06, the user's request)

The giant seed over your head (GDD) is replaced by acorns circling your head ([docs/plans/AcornOrbit.md](plans/AcornOrbit.md)).
- **The tiers:** 1–5 seeds show as small acorns; every 6 of a tier merge into one acorn of the next: large at 6, huge at 36, giant at 216.
- **Placement:** small acorns circle at head height, and bigger ones ride above the head like a crown.
- **The count:** no number shows above the acorns; the exact count is in the HUD's "Capacity: n/max".
- **Merging:** has a puff, and a thunk for your own acorns.
