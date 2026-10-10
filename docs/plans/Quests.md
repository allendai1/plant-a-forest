# Quests: a starter chain (plan, 2026-10-09)

**Goal:** give new players a short goal every few minutes after the tutorial, so the first 30 minutes always have a next step and a reward. The analytics showed most new players leaving after about 4 minutes, before any ring finished ([Analytics 2026-10-09](../notes/Analytics%202026-10-09.md)). This picks up the quest list postponed in [M10](M10.md).

## Design

- **One quest at a time, in a fixed order** (a chain, not a list): one clear next goal, like the tutorial's one line. It starts when the tutorial ends.
- **Shown** on the left under the stats: "Quest 3/8 · Reach 100 Strength", a progress bar (40 / 100) and the reward (+75 coins).
- **On completion:** coins, a banner ("Quest complete! +75 coins"), the level-up sound, and the next quest appears. Paid once, ever (saved).
- **After the last quest:** the panel hides. (Daily or repeating quests could come later.)

| # | Quest | Counts | Reward |
| --- | --- | --- | --- |
| 1 | Grow 3 trees | trees you finished (planted the last acorn) | 50 |
| 2 | Reach 100 Strength | Strength | 75 |
| 3 | Reach 50 Speed | Speed | 75 |
| 4 | Plant 250 acorns | acorns planted, ever | 100 |
| 5 | Help finish a ring | rings completed while you'd planted in them | 150 |
| 6 | Buy 3 upgrades | upgrade levels, added up | 150 |
| 7 | Reach 1,000 Strength | Strength | 200 |
| 8 | Complete a forest | forests completed | 300 |

Total 1,100 coins over roughly the first 30–60 minutes. The numbers are defaults in `GameConfig.Quests`, easy to change.

## Files

| File | Change |
| --- | --- |
| `src/shared/GameConfig.luau` | `Quests`: the chain (id, text, the stat it counts, goal, reward) |
| `src/server/Services/DataService.luau` | saved `QuestIndex` (the current quest; 0 = not started) and two counters, `TreesFinished` and `RingsHelped` |
| `src/server/Services/QuestService.luau` | **new**: watches the counted values, pays and moves on (several can complete at once); starts the chain when the tutorial ends |
| `src/server/Services/ForestService.luau` | counts `TreesFinished` (next to the first-tree reward) and `RingsHelped` (players who planted in a ring when it completes) |
| `src/client/Controllers/QuestController.luau` | **new**: the quest panel and the completion banner |
| `src/server/Analytics.luau` | a `Quests` funnel (step = quest reached), to see where the chain loses people |

No new remotes: everything is server-side and shown through attributes.

## Test plan

- Each quest completes at its goal, pays once, and the next one shows; progress and the current quest survive rejoining.
- Several at once (for example a veteran: Strength quests done immediately) move straight past without paying twice.
- Phones: the panel doesn't overlap the stats, the Plant button or the Pick Up panel.

## Open questions

1. The quest list and rewards above: change any?
2. Existing players (already past the tutorial): start the chain for them too (they'd quickly complete the early ones), or only new players?

## What changed from the plan (built 2026-10-09)

- **Claim instead of automatic** (my recommendation; the user asked to see it built, not yet approved as final): a reached quest shows a CLAIM button and a red dot on the card; `ClaimQuest` (rate-limited) pays and moves `QuestIndex` on before paying, so a second claim can only pay the next quest if it's reached too.
- **A list window:** pressing the card opens "Quests" with all eight (✓ Done, the current one with its bar or CLAIM, the rest with their rewards). There's no separate QUESTS button: the card is the button.
- **Existing players get the chain too** (default), from quest 1; lifetime numbers count, so veterans can claim several in a row.
- **Analytics:** a `Quests` funnel, one step per quest claimed.
- **Verified in a playtest:** the card under the stats ("QUEST 1/8 Grow 3 trees 0 / 3 +50 coins"); after finishing 3 trees, 3 / 3 with CLAIM and the red dot; claiming paid 50 and showed "Quest complete! +50 coins"; quest 2 (already reached) paid 75 on the next claim; the list window (screenshot checked). Your Studio save is now on quest 3.
