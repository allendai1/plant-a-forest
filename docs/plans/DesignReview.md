# Design review: retention, economy and tutorial (2026-10-07)

Done with the `roblox-game-design` skill's checklists. The numbers come from GameConfig's formulas, modelled in a script: an average trip of about 200 studs each way, 0.15 s a press, the roulette's average coin multiplier of 1.5x (0.6×1 + 0.3×2 + 0.1×3), and 60% of play time spent planting. They're estimates for comparing options, not measurements.

Two fixes were made straight away:
- the free-gift popup no longer appears in the middle of the tutorial
- the tutorial prompts were cut to about 5 words

Everything else below is a recommendation, not built yet.

## 1. Retention by phase

| Phase | What the skill asks for | What we have | Verdict |
| --- | --- | --- | --- |
| **D0–7: understandability** | A first session you grasp at once | A story intro, a 6-step tutorial with an arrow, the forest credit line | Good. See section 3 for its length. |
| **D0–7: novelty** | A memorable hook | A shared Forest Bar, a World Tree that grows, three worlds on a roulette, acorns rolling down the dispensers | Good |
| **D0–7: stability** | No crashes, lag or long loads | Frame rate never measured (M12); no two-player test | **The open risk.** Do it before launch. |
| **D7–30: progression** | Visible goals | Stations at 1/3/8/15/25/50/100 forests (shown on the pads), 34 upgrade levels, leaderboards | Strong |
| **D7–30: mastery** | Something to get better at | Mostly a stat check, by design (like Build the Pyramid) | Fine for the genre |
| **D7–30: return triggers** | A reason to come back tomorrow | None (no daily rewards, the user's call, like Build the Pyramid) | Accepted. Watch D1 and D7 in analytics. |
| **D30–90: social comparison** | Leaderboards, rankings | Global boards for Strength, Speed and Forests; in-server player list | Good |
| **D30–90: live updates** | Fresh content and events | The world rotation; no timed events | **The best upgrade:** a Halloween event in the Smoky Mountains world (below) |
| **D90+: community** | Groups, Discord | Codes are ready to post | Make a group; give a code for joining |

**Recommendations, in order:**
1. **Stability first:** a two-player test and the M12 frame-rate check. The skill calls stability "the gatekeeper of retention".
2. **A Halloween event built on the Smoky Mountains world.** For example, a weekend where the roulette favours Smoky (3x coins) and the World Tree's lanterns turn to pumpkins. Cheap, since the world exists, and it gives players a date to come back for.
3. **A welcome-back line,** instead of daily rewards. On join, show "Next unlock: 10x station, 3 more forests". It's free to build and shows progress to returning players.
4. **A group, plus a code that rewards joining it,** for the D90+ phase.

## 2. Economy

**Sources:** planting (1 coin per acorn × the world's multiplier, plus Friend Boost), the forest reward (500, with credit), the free gift (500), codes (RELEASE 1,000), and the tutorial top-up to 50.

**Sinks:** upgrades only, while the seed shop is off.

**Earnings by play time** (estimated per player, at average roulette luck):

| Played | Capacity | Walk speed | Coins/hour |
| --- | --- | --- | --- |
| 15 min | 12 | 43 | ~3,000 |
| 1 h | 36 | 63 | ~11,700 |
| 3 h | 106 | 121 | ~35,000 |
| 10 h | 305 | 262 | ~68,000 |
| 30 h | 710 | 465 | ~104,000 |
| 100 h | 2,112 | 1,081 | ~139,000 |

**Upgrade costs** (each level is 2.5x the last):
- **Bulk Pickup and Bulk Plant** (12 levels each): 50, 125, 313, 781, 1,953, 4,883, 12,207, 30,518, 76,294, 190,735, 476,837, 1,192,093.
- **Planting Range** (10 levels): 60 … 228,882.
- **Everything maxed:** 4.36M coins.

**What that means:**
- **Early game is well paced.** The first upgrade comes in the tutorial; Bulk 1–5 on both (6,400 coins) by about hour 1–1.5.
- **Mid game:** Bulk 8 on both (about 100K in all) around hour 5.
- **Late game:** both Bulks maxed (about 4M) around hour 45–50. Each of the last two levels is roughly 7–12 hours of earnings. That's a long but readable grind. (We have no Build the Pyramid data for how long its upgrades take to max. The "~53 hours" quoted earlier in the session was our own estimate of its time to 100 pyramids, its top training tier, from the user's clip. It isn't an upgrade figure. Our own time to 100 forests is about 19 hours.)

**Health checks:**
- **Hoarding after about 50 hours:** once everything is maxed, coins have no use while the seed shop is off. This is fine for launch; the fix comes when the seed shop returns, or with a later prestige/rebirth. Watch it in the economy analytics.
- **Planting Range levels 6–10 (about 370K):** they buy little, since the open row is a narrow arc near you. They work as a coin sink but may feel like a bad deal. Option: stop Range at level 5 and add the coins to Bulk. Low priority.
- **Choke points:** none early. The biggest jump in time-to-afford is Bulk 11 to 12 (477K, then 1.19M). Watch for quitting there.
- **Inflation:** low risk. Coins come only from planting, and prices are exponential.

**No changes recommended before launch.**

## 3. Tutorial (against the skill's onboarding checklist)

| Check | Status |
| --- | --- |
| No deaths in the first session | ✓ |
| One mechanic at a time, in context | ✓ (6 steps, one prompt at a time, arrow) |
| No popups during onboarding | **Fixed today:** the free-gift popup could appear 90 s into a visit, in the middle of the tutorial. It now waits until the tutorial is done. |
| Text about 5 words | **Fixed today:** "Grab acorns", "Plant them in the glowing tiles", "Train to carry more (12/20)", "Fill up on acorns (2/3)", "Plant them all", "Buy an upgrade" |
| Skippable story | ✓ (a 12 s intro with Skip) |
| Best asset shown early | ✓ the World Tree in the intro (the forest-complete cutscene usually comes much later) |
| Locked content teased | ✓ station pads with requirements, the world roulette |
| An "aha" moment in the first session | ✓ the first tree grows a stage and coins burst out |
| Objectives always affordable | ✓ the shop step tops coins up to 50 |
| Spawn near the first objective | ✓ the spawn is about 25 studs from a dispenser |
| A short tutorial (field data: under a minute is ideal; several minutes loses players) | **About 1.5–2 minutes, mostly walking.** The first open row is the outermost ring, about 320 studs from a dispenser: about 10 s each way at a new player's speed of 32, and the tutorial makes 2 round trips plus walks to the pad and the shop. |
| Only the UI the tutorial needs | **No:** the full HUD (the Forest Bar's Robux buttons, SHOP, boost passes, Settings and Codes) shows from the start. The skill says a full HUD overstimulates new players. |

**Recommendations:**
1. **A walk-speed boost during the tutorial** (for example 2x until it's done). It cuts about a minute of walking to about 30 s. The skill's field notes say players rarely notice when such a boost ends, but that's developer anecdote, not hard data. Decide from the Tutorial funnel: add it if players drop off at steps 2–3 (the long walks).
2. **Optional, a matter of taste: hide the Robux buttons and boost passes until the tutorial is done,** then reveal them with a pop. It keeps the first two minutes simpler, but Build the Pyramid shows everything from the start.
3. **Optional:** teleport the player to the 1x pad when the Train step starts. It saves a walk, though it's less natural than the speed boost.

## Player types (Bartle)

| Type | What serves them | Gap |
| --- | --- | --- |
| Achievers | Stations, upgrades, badges, leaderboards, Forest Lord | none |
| Socializers | The shared Forest Bar, Friend Boost, outfits others can see | none |
| Explorers | Three worlds and their World Trees | thin; the seed shop (when it returns) and hidden secrets would help |
| Killers | Leaderboards | no PvP, which is fine for a co-op game |
