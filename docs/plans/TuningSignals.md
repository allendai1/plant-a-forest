# When to re-tune the stats: signals to check once real players exist (2026-10-07)

The user's plan: launch with the current numbers, then come back here once there are real players and about a week of data, and decide from the data. Analytics show up on the Creator Dashboard about 24 hours after the events. Wait for a few hundred players and about a week, especially for 7-day retention, and change one lever at a time.

## Progression too fast (players run out of things to do)

| Signal | Where | Lever |
| --- | --- | --- |
| The 25/50/100-forest milestones come much sooner than planned (model: about 19 h to 100 forests) | ForestMilestones funnel vs LifetimePlaytime | More acorns per tree (`Tiers[].SeedsPerHex`), or later station unlocks (`Stats.GymMultipliers` ForestsDone) |
| Many leave in the top upgrade band (30+ levels) while their playtime is still short | LeftGame (upgrade band field) | Steeper upgrade prices (`Upgrades[].Growth`, 2.5 now) |
| Coins pile up: earned keeps rising while spending falls off | Economy events (planting income vs upgrade/seed spending) | A new coin sink: the seed shop (`Features.SeedShop`) or more upgrade levels |
| Most players quit at high capacity bands | LeftGame (capacity band) | The late game has nothing left: add a goal, not a slower curve |

## Progression too slow (players give up)

| Signal | Where | Lever |
| --- | --- | --- |
| Many new players never reach a first forest's "Completed" | ForestLoop and Onboarding funnels | Faster early training, fewer acorns per tree, or a smaller first forest |
| A big drop between the 1-, 3- and 8-forest milestones | ForestMilestones funnel | Station unlocks too far apart |
| Players leave at low capacity bands after short sessions | LeftGame + SessionLength | Early Strength gain too slow (`Stats.Capacity` curve, rep amounts) |
| Players try a locked station, then leave | LockedStation funnel, then LeftGame | The next unlock feels too far away |
| A drop right where upgrade prices jump (for example Bulk 11 → 12) | LeftGame upgrade bands | Soften that step |

## Rings, trees and the layout A/B test (logged since 2026-10-08)

**The test:** each server picks its ring order when it starts: `OuterFirstShare` of them open from the outer ring in (`OuterFirst`, the current layout), the rest from the hub out (`InnerFirst`) (`GameConfig.Experiments`). **Paused at launch:** `OuterFirstShare = 1` (every server outer-first) until there are enough players to split; set it to, say, 0.8 to start the test. Every forest event below carries it in its world field ("World 1 OuterFirst"), so filter by it to compare. Turn the test off by setting `LayoutTest = false` (every server then uses `Grid.OutsideIn`).

| Event | Value | Fields | Answers |
| --- | --- | --- | --- |
| RingCompleted | minutes the ring took | "Ring 1 (84 trees)" (in opening order), player-count band, world + layout | Which ring drags |
| TreeGap | a player's average seconds between the trees they finished (planted the last seed of) | how many trees, player-count band, world + layout | Do trees take too long to feel good |
| LeftAt | the visit's minutes | where: "Ring 3 50-74%" (the open ring, how far along) or "Break"; world + layout; player-count band | Where in a forest people quit |
| ForestCompleted, ForestStat*, ForestBoughtSeeds | (above) | now with the layout | Does the layout change forest length |

**Reading the test:** wait for a few hundred completed forests in the smaller (InnerFirst) group before deciding; with 80/20 it fills about 4x slower. Compare, per layout: ForestCompleted minutes at the same player-count band, the LeftAt share before the forest is done (and which ring), TreeGap, and the share who plant in the next forest. Funnels can't carry the layout, so ForestLoop and SessionLength compare only through LeftAt. Change one thing at a time while the test runs.

**Levers:** a slow first ring (outer-first) → InnerFirst, or fewer seeds per tree; long TreeGap → fewer seeds per tree (`Tiers[].SeedsPerHex`) or a bigger early capacity; quitting mid-ring at 0–24% → the ring feels endless (smaller rings or a mid-ring reward).

## Forest size follows the server (2026-10-08)

Seeds per tree = players × `SeedsPerPlayer` (Sherwood 1,500, the other worlds 3,000) ÷ 540, clamped to 5…`SeedsPerHex`, set when each forest starts. Sherwood: solo and 1 player 5 per tree (2,700), 5 players 14 (7,560), 10 players 28 (15,120), 20 players 56 (30,240), 36+ players 100 (54,000). The aim is 20-40 min per forest at any size.

**Tuning it:** ForestCompleted minutes per player-count band (the forest report, with SeedsPerTree). If forests are too quick everywhere, raise `SeedsPerPlayer`; too slow, lower it. If only solo / 2-player servers drag, lower `MinSeedsPerHex`. Nothing structural needs changing when player counts grow: big servers hit the world's `SeedsPerHex` cap (Sherwood from 36 players).

**Decided for launch (2026-10-08, with the user):** size by head count only; a player's strength doesn't change the forest. Getting stronger has to make you faster against a fixed target, so the forest must not grow with power (that would make progression pointless). Known effects, accepted:

- **A veteran carries a server.** With 10 players (15,120 seeds), a capacity-5,000 veteran plants about 90% and the forest takes ~3 min. New players get fast rewards (cutscene, +500, forest credit, first unlocks) but plant less.
- **A veteran alone in a fresh public server** finishes small forests in a minute or two, until the server fills (the next forest is sized for the new crowd). Their gain is mostly forest credit; +500 coins is trivial to them.
- **Private servers** use the same rule. Not given the full size on purpose: a few friends in a private server would face a 54,000-seed forest.

**Watch:** in servers with a big gap between the stat average and median (the forest report), do new players leave sooner (LeftAt, by player-count band) or plant very little (median SeedsPlanted)? Are forests in small servers much shorter than in busy ones (ForestCompleted by band)? **If so, the mild fix:** count strong players as more than one, with a low cap (for example a capacity-5,000 player counts as 3), which grows the forest a little without erasing their speed advantage. If veterans farm empty or private servers for forest credit (many forests per hour per player), consider requiring a small planted share for credit.




| Signal | Where | Lever |
| --- | --- | --- |
| Mostly "AFK" or "Walking" during breaks | BreakActivity | The Spring isn't worth standing in: raise `Awakening.SpringOdds` multipliers |
| Many players leave during the break | LeftDuringBreak | The break is too long (`Awakening.BreakSeconds`), or nothing in it is worth doing |

## Tutorial

A big drop at one step of the Tutorial funnel means that step is the problem. Steps 2–3 are the long walks; the fix ready for that is a walk-speed boost during the tutorial (`docs/plans/DesignReview.md`). Step 3 is the 20-Strength training target.

## Forest length (logged since 2026-10-08)

Forest length is the most direct sign of whether the stats curve and the forest target fit together (Sherwood 54,000 at 100 per tree, the other worlds 108,000; a busy Build the Pyramid server of ~70 players does its 171,000 in 5–6 min). Once per completed forest (`src/server/Analytics.luau`, the forest report):

- **ForestCompleted:** value = minutes from the forest's start; fields: the player-count band, the planters band, the world.
- **ForestBoughtSeeds:** seeds bought straight into the bar (the +1,000…+10,000 products), which shorten a forest without anyone planting.
- **ForestStatMedian / ForestStatAverage:** for the players who planted in it, one each per stat in the Stat field: Strength, Speed, Capacity, WalkSpeed (after their own speed limit), PickupPerPress, PlantPerPress, PlantingRange, HandsSpeed (Park Ranger pass), SeedsPlanted. Sliced by the player-count band and the world.

**How to read it:** compare ForestCompleted's average minutes across player-count bands (a 5-player server should take about 10x as long as a 50-player one). If forests drag, the median stats show why: a low median Capacity or PickupPerPress means trips carry too little, a low WalkSpeed means trips take too long. Median against average shows whether a few strong players do most of the work (average far above median).

## Background for the decision

- **Model estimates** (`docs/plans/DesignReview.md`): about 12K coins an hour at 1 h, 68K at 10 h and 139K at 100 h. Upgrades max out (4.36M coins) at about 45–50 h. A whale (max Bulk + Forest Lord) fills a forest alone in about 7–20 min.
- **Build the Pyramid comparison:** our capacity curve matches their readings up to 105K Strength, but not above. Three high readings, 120.82M → 5,200, 567.83M → 11,252 and 12.841B → 53,439 (2026-10-07), all sit on capacity ≈ 0.4725 × √Strength (within 0.2%; ours gives 12,277 at 12.841B, 4.4x low), so it's their curve steepening, not a bonus. Ours gives 2,262 and 3,966 there (2.3x and 2.8x low). `max(our curve, 0.4725 × √Strength)` fits all seven readings (it takes over from ours around 400K Strength). **Applied 2026-10-07** at the user's request: `Stats.Capacity.Sqrt = 0.4725` in GameConfig, capacity = the bigger of the two. With per-press Bulk capped at 13, a much bigger capacity doesn't make forests much faster.
- **Training pace (btp3 clip, 2026-10-07):** a player at +40 a rep gained 2,109 Strength in 14 s, so about 150 a second, or 3.77 reps a second (a rep every ~0.266 s). Ours is a rep every 0.25 s (`Stats.RepSeconds`), about 6% faster. The same clip shows Strength 247,552 → capacity 253 (ours 235, 7% low) and 249,364 → 254.
