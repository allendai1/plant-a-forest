# Progression review (2026-10-10)

The user asked for an evaluation of how training and the bridge progress together in Build Across the Grand Canyon!. These are model numbers from `src/shared/GameConfig.luau`, not playtests:
- **Training:** a rep every 0.266 s.
- **Carrying and walking:** the capacity and walk speed curves.
- **The bridge:** 2,400 slots (300 rows × 8), with the planks per slot set by the server's size.
- **A trip:** the pile is 78 studs from the bridge, the belts make a trip about 20 s each way, and loading or placing costs 0.15 s per press.
- **Coins:** spent on Bulk levels as they come.

The modelled player trains with the next three bridges in mind. The script was a scratch file and isn't kept.

## What a bridge takes

| Players | Planks per slot | Bridge | Each player's share |
|---|---|---|---|
| 1 | 3 | 7,200 | 7,200 |
| 3 | 3 | 7,200 | 2,400 |
| 10 | 7 | 16,800 | 1,680 |
| 30 | 19 | 45,600 | 1,520 |
| 50 | 32 | 76,800 | 1,536 |

`SeedsPerPlayer` 1,500 was set for the forest's 540 trees. The bridge has 2,400 slots, so under about 5 players the floor (`ForestSize.MinSeedsPerHex` = 3) decides the size instead. A solo player builds 7,200 planks, almost 5 times a normal share.

## How long it takes a new player

A server full of new players, from the tutorial's 20 Strength and 20 Speed:

| Players | Bridge 1 | Bridge 2 | Bridges 5-6 | After 12 bridges |
|---|---|---|---|---|
| 1 | 152 min | 48 min | 27 min | 8.1 h, 10x gym |
| 3 | 66 min | 24 min | 12 min | 3.7 h, 10x gym |
| 10 | 48 min | 22 min | 10 min | 2.9 h, 10x gym |
| 30 | 46 min | 21 min | 10 min | 2.8 h, 10x gym |

With `MinSeedsPerHex` = 1, a solo player takes 66 min for the first bridge (2,400 planks) and 3 players take 56 min. Bigger servers don't change.

Veterans in a server shorten this a lot, because the bridge's size depends on how many players there are, not how strong they are. These figures are the worst case: a server of new players.

## Findings

1. **Small servers get oversized bridges.** The 3-plank floor makes 1-4 player servers build 7,200 planks. Alone, a new player's first bridge is about 2.5 hours. The comment on `ForestSize` aims for 20-40 minutes.
2. **The first bridge is the long wall.** Even in a full server it's about 45 minutes before the first reward and the 2x gym. Everything after it speeds up quickly (bridge 2 is about half; by bridge 5, 10-12 minutes). In Build the Pyramid the first pyramid takes minutes.
3. **Training pays well early, then levels off.** 1x training to 1,000 Strength takes 4.4 minutes and lifts carrying from 3 to 26. Past about 5,000 Strength (carry 52) each extra plank of capacity costs more and more training. That's healthy, but the 2x, 5x and 10x gyms (1, 3 and 8 bridges) are what really speed a player up.
4. **Pressing E becomes the trip for strong players.** Loading and placing cost 0.15 s per press, and Bulk adds only +1 plank per press per level. It reaches 13 at level 12, which costs 1.2M coins. Example: carry 300 at Bulk 1 is about 90 s of holding E per trip, against about 45 s of travel. Anyone who buys big Strength boosts early hits this first.
5. **Speed still matters on the belts, but less than Strength.** The belt adds the same speed for everyone, so a fast walker still arrives sooner: walk 50 to 200 cuts a 2,000-stud trip from about 18 s to 8 s. Load size is the bigger lever.
6. **The gym ladder is long at the top.** 25x needs 15 bridges, 50x 25, 75x 50 and 100x 100 (about 17-25 hours at 10-15 minute bridges). The Robux passes cover impatience. The later worlds (Bryce and Zion) have bridges twice as big, so they slow the ladder even though they pay 2-3x coins.
7. **Coins and upgrades:** a player's share pays about 1,500-2,400 coins plus 500 per bridge. Bulk levels 1-7 come within about 10 bridges, but levels 9-12 (76K-1.2M coins) are far out of reach without Robux.

## Applied (2026-10-10, the user's calls)

- **`ForestSize.MinSeedsPerHex` 3 → 1:** 1 rather than 2 because 2 and 1 only differ for a player alone (2 or more players already need 2 per slot). With 1, a solo player's bridge is 2,400 planks, the same share as each player in a 2-player server. Checked: a solo server's target is 2,400.
- **The belts run at least `Grid.Belts.MinSpeed` (10 studs/s):** before, they stood still until about row 65 (a bridge under 640 studs: a 32-speed walker crosses it in under 20 s anyway) and looked broken. Checked: at row 6 they run at 10 and the outward one eases off near the end.

## Recommendations (not applied yet)

- **A shorter first bridge for new players:** for example `SeedsPerPlayer` 1,500 → 1,000 (about a third less for everyone in bigger servers), or a bigger reward partway (coins at 25/50/75% built), so the first 45 minutes have milestones.
- **Bigger presses for big loads:** for example a press moves at least `capacity / 20` planks, so loading never takes more than about 3 s. This changes a core rule (one press, one plank, Bulk adds more), so it's the user's call.
- **Leave** the training curves and the gym ladder until real play data is in ([TuningSignals](../plans/TuningSignals.md)).
