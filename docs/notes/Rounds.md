# Rounds (2026-10-09)

The idea: a server's first forests are small and grow, so new players finish a forest (the Forest Awakening, the reward, their first forest toward a station unlock) within one short visit. From the launch-day data: only 24 of 257 new players finished a forest, and the first ring alone took about 8 minutes ([Analytics 2026-10-09](Analytics%202026-10-09.md)).

## How it works

- **Each forest still starts empty** after the break (option 1 of the two we discussed; the finished rings don't stay).
- **Forest 1 of a server: the 3 rings next to the hub** (63 trees, since the forest became a half: [Field and town](Field%20and%20town.md)), forest 2 the inner 6 (153), and from forest 3 on all 9 (270). Around the whole hub it was 2, 4, 6 rings (78, 180, 306 trees).
- Forests now always **open from the hub outward** (the short walks from the acorn dispenser). The outer-first / hub-first test is ignored while rounds are on.
- **Seeds per tree don't change** (they still follow the server's player count), so a round's Forest Bar target is just its trees × that. Alone: about 234 acorns for forest 1, against 1,620 for a full forest.
- **In the small rounds every ring is open at once** (`Rounds.OpenWholeRound`, added after the user's playtest: the new outer rings stayed shut until the inner ones were full again). You still plant the closest open tile, so the rings by the acorns fill first. Full-size forests (the 4th on) keep opening ring by ring.
- **The rings outside the round look like wasteland,** like every unplanted tile ([Wasteland](Wasteland.md)); they were hidden at first. When the next forest is bigger, a banner says "The forest grows! 4 rings to plant".
- The forest reward and forest credit are unchanged.
- The round is per server, not per player: someone joining a server on forest 5 gets a full-size forest.

## Settings

`GameConfig.Rounds`: `Enabled` (false = the old behavior), `Rings = { 3, 6 }` (the rings of forests 1, 2; after the list, all of them) and `OpenWholeRound` (true).

## Analytics

Every forest event's "world + layout" field now says the round instead of the layout: "World 1 Round 1", "World 2 Round 2", "World 1 Round 3", then "Round 4+" for every full-size forest. Compare ForestCompleted minutes and LeftAt per round, and watch the Onboarding "Completed a forest" step and the 1- and 3-forest ForestMilestones.

## Status

Synced to Studio 2026-10-09 evening. The user playtested rounds (they work; the closed outer rings led to the whole-round change, synced afterwards and not yet playtested). **Not published yet.**
