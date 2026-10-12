# Economy review (2026-10-11)

The user asked for a look at everything that earns or costs coins or Robux, free gifts included, and whether prices should change. Sources: `src/shared/GameConfig.luau`, the live prices on Roblox (read with Open Cloud on 2026-10-11) and the earning model in [Progression review](Progression%20review.md). These are model numbers, not play data. Nothing here is applied yet.

## What players earn

| Source | Coins |
|---|---|
| Each plank placed | 1 × the canyon's multiplier (Grand Canyon 1, Bryce 2, Zion 3), +10% per friend in the server, up to +50% |
| Finishing a bridge (everyone online) | 1,500 × the canyon's multiplier |
| A player's share of a bridge | about 1,500–2,400 planks in the Grand Canyon, twice that in Bryce and Zion |

So a bridge pays one player about **3,000–4,000 coins** in the Grand Canyon, about 9,000 in Bryce and about 13,500 in Zion. Bridges in Bryce and Zion take about twice as long. Once a player is past the first bridge or two (10–15 minute bridges), that's roughly **15,000–30,000 coins an hour**. The first bridge takes about 45 minutes.

**Free coins and stats:**

| Free | Coins | Notes |
|---|---|---|
| Tutorial top-up | up to 50 | enough for the first upgrade |
| First section finished | 100 | |
| Starter quests (8) | 1,100 in all | 50 to 300 each |
| Free gift (like, favorite, join group) | 1,250 | plus 1,500 Strength and 1,500 Speed, once ever |
| Code RELEASE | 1,000 | |
| Daily login | 9,000 a week | 250, 500, 750, 1,000, 1,500, 2,000, 3,000; day 2 opens the 5x gym instead for players who don't have it |

A new player gets about 3,500 free coins in the first half hour, enough for Bulk Pickup and Bulk Build to about level 4 each. That's a good start.

## What coins buy

| Upgrade | Coin costs | Total |
|---|---|---|
| Bulk Pickup (12 levels) | 50, 125, 300, 650, 1,300, 2,400, 4,200, 7,000, 11,000, 17,000, 25,000, 36,000 | 105,000 |
| Bulk Build (12 levels) | the same | 105,000 |
| Build Range (4 levels) | 300, 1,500, 6,000, 20,000 | 27,800 |

**Everything coins can buy costs about 238,000 coins**, roughly 10–15 hours of play. After that, coins pile up with nothing to spend them on. Gyms and ranks come from bridges, not coins.

## What Robux buy (live prices)

| Item | Robux | Notes |
|---|---|---|
| Builderman (pass) | 99 | 2x pickup and build speed, 2x bridges |
| BuilderBot™ (pass, still named "God of Construction" on Roblox) | 799 | 5x speed, 3x bridges |
| Gym passes 2x / 5x / 10x / 25x / 50x / 75x / 100x | 19 / 89 / 179 / 360 / 599 / 729 / 989 | the gyms open free at 1 / 3 / 8 / 15 / 25 / 50 / 100 bridges |
| Strength boosts 2x–128x (permanent) | 5, 14, 39, 99, 199, 449, 999 | only the highest counts; 1,804 for all |
| Speed boosts 1.5x–16x (permanent) | 3, 9, 39, 99, 249 | 399 for all |
| Bulk Pickup / Bulk Build levels 1–12 | 9, 19, 39, 79, 149, 239, 379, 599, 949, 1,499, 2,399, 3,799 | **10,158 each for all 12** |
| Build Range levels 1–4 | 9, 19, 39, 79 | |
| Bridge packs +2.5% / +5% / +10% / +25% | 49 / 89 / 159 / 349 | planks for the whole server's bridge |
| Server training boost (2x, 15 min) | 45 | |
| Break time +1 / +5 / +10 / +20 min | 45 / 117 / 225 / 399 | |
| Pick the next canyon | 99 each | |

Roblox shows your own account prices about 10% lower (regional pricing), so these may look like 90 or 720 in Studio.

## Findings

1. **The Robux prices of Bulk levels 6–12 are far too high since coin costs were cut** (2026-10-11). Level 12 is 3,799 Robux for something that costs 36,000 coins, about 1.5–2 hours of play. The Robux ladder was set when level 12 cost 1.19M coins. Almost nobody will buy those levels now.
2. **Product names on Roblox are out of date, and players see them in the purchase popup:** "Planting Range level N" (the game says Build Range), "Bulk Plant level N" (Bulk Build), "Pick Sherwood Forest / Kyoto Forest / Great Smoky Mountains" (Grand Canyon, Bryce, Zion), and the "God of Construction" pass (BuilderBot™).
3. **Unused products are still on sale:** Build Range levels 5–10 (the game uses 4) and the five seed products from Plant Trees! (the seed shop is off). Nobody can reach them in the game, but they should go off sale so they can't be bought by mistake.
4. **Coins run out of uses after about 238,000 coins** (10–15 hours). Long-time players earn coins with nothing to spend them on, so coin rewards stop feeling like rewards.
5. **Builderman's 2x bridges is very strong for 99 Robux.** It halves the time to every gym (the 100x gym at 50 bridges instead of 100) and every rank. It also doubles the owner's count on the Top Bridges board, so that board partly measures who paid.
6. **The stat boosts are cheap starter buys, by design.** A permanent 2x Strength for 5 Robux or 1.5x Speed for 3 is a good way to get the first purchase. The higher steps (64x, 128x) are where the money is. These look fine.
7. **The gym passes are a reasonable ladder.** The daily day-2 gift opens the 5x gym, so the 89-Robux 5x pass will sell less to players who come back on day 2. That was the user's choice to bring players back.
8. **A bridge pack's value depends on the server's size.** +25% of a solo bridge is 600 planks, while +25% of a 50-player bridge is 19,200, for the same 349 Robux. The buttons show the planks live, so it's honest, but it's poor value in small servers.
9. **The daily reward gets small later on.** 9,000 coins a week is about half an hour of mid-game play. It's fine for new players, weak for regulars.

## Recommendations

**Fix now (they don't need play data):**
- **Re-price the Robux Bulk levels** to match the new coin costs, at about 1 Robux per 150 coins with a small premium on the cheap levels: 5, 9, 14, 19, 29, 39, 49, 69, 99, 129, 179, 249 (889 each for all 12, was 10,158). Build Range 9 / 19 / 39 / 79 already fits; leave it.
- **Rename the products on Roblox** to the names the game uses, and rename the BuilderBot™ pass with a new icon.
- **Take the unused products off sale** (Build Range 5–10, the five seeds).

**Add a coin sink (needs building):**
- **The characters for coins:** Builderman 75,000, BuilderBot™ 750,000 (BuilderBot™ only after Builderman). Coin buyers get the same perks; Robux is the shortcut. The NPC's sign shows progress ("48,200 / 75,000 coins, or 99 Robux now").

**Decide after launch, with data** ([TuningSignals](../plans/TuningSignals.md)):
- **Builderman's price** (99 now; 149–199 if it sells to almost every buyer), or have Top Bridges count real bridges only.
- **The daily reward's size:** for example a bigger day 7, or rewards that grow with the player's rank.
- **The first bridge's length:** see [Progression review](Progression%20review.md).

**Leave as they are:** the stat boosts, the gym passes, the break time, the canyon picks, the server boost, the free gift and the starter quests.

## Applied (2026-10-11, the user's calls)

- **Bulk Pickup and Bulk Build levels re-priced on Roblox:** 5, 9, 14, 19, 29, 39, 49, 69, 99, 129, 179, 249 Robux (were 9 ... 3,799).
- **Renamed on Roblox:** "Bulk Plant level N" → "Bulk Build level N", "Planting Range level 1-4" → "Build Range level 1-4", the canyon picks → "Pick Grand Canyon / Bryce Canyon / Zion Canyon", the "God of Construction" pass → "BuilderBot™" (new description; its icon is still the old one).
- **Off sale:** Planting Range levels 5-10 and the five seed products.
- **Builderman pass 99 → 129 Robux.**
- **The characters for coins:** Builderman **100,000**, BuilderBot™ **400,000** (the user's prices), BuilderBot™ only once you have Builderman (either way). Same perks as the pass. Saved as `CharacterBought` (the highest `GameConfig.HandsPasses` index bought with coins); `PassService.ownsCharacter` counts it like the pass; `EconomyService` BuyCharacter checks the order and the coins. Each NPC has a second prompt, **F: Buy for 100K coins** (E still buys with Robux); the sign reads "R$129 · 100K coins"; the Robux shop's character cards have a coin button next to the Robux one (grey until you can afford it). A buy that can't go through says why ("51,800 more coins needed", "Get Builderman first"). Test panel: `setCharacterBought`. The Studio-only "fill the bridge" filming hotkey moved from F to G.
- **Checked in a playtest:** BuilderBot™ refused before Builderman; Builderman took exactly 100,000; BuilderBot™ refused with 50,000; then took exactly 400,000; a second buy did nothing; the outfit went on at once; the signs and prompts read right.
- **Lucky Planks (new upgrade, the user's idea):** each plank placed has a chance to come back to your hands. **10 levels: 5% at level 1, then +5% a level up to 50%** (the user's ladder; 50% = every other plank comes back, twice the planks per trip, so the top is priced extremely high). Coins: 5K, 15K, 40K, 90K, 180K, 350K, 650K, 1.2M, 2.5M, 5M (about 10M in all). Robux levels: 49, 99, 199, 349, 599, 999, 1,699, 2,999, 4,999, 9,999 (products 3718031285-3718031327, `GameConfig.UpgradeProducts.LuckyPlanks`). The roll is in ForestService's PlantSeeds; a lucky plank still counts as placed and pays its coins. A gold "Lucky! +N" rises from the slot it was placed in (the user's ask), merged per slot over 0.4 s. 4th row in the upgrade shop. Saved as `LuckyPlanksLevel`; test panel `setLuckyPlanksLevel`. Checked: at 10%, 45 of 445 placed planks came back (10.1%); the pop shows at the slot.
- **Auto Build pass (new, 2025243018, 199 Robux, the user's ask: auto-collect and auto-place in one pass):** standing at the pile, the server picks up for you at your normal pace (CarryService); carrying planks with an open slot in reach, the client places for you at your normal pace, the same request a held E sends (CarryController). You still walk the planks out. Card in the Robux shop's Boosts tab, under the server boost. Attribute `AutoBuild`; test panel `grantAuto` 1/0. Checked: 125 planks (full) in 3 s at the pile with no input, 86 placed in 4 s at the bridge with no input; with the pass off, nothing.
- **A fixed bridge per map (2026-10-11, the user's call, after the bridge-size discussion below):** `ForestSize.ScaleWithPlayers` off. The Grand Canyon is always **19,200 planks** (8 a slot x 2,400 slots; the user asked for 20,000, the nearest whole number per slot), Bryce and Zion **40,800** (17 a slot, about twice, as before). More players build it faster. Checked in a playtest: target 19,200.

## Bridge size: how long a first bridge takes (2026-10-11)

The model (training time included, a server of new players only, so a worst case; veterans finish much faster):
- **The old player-scaled bridge** (about 1,500 planks per player, min 1 per slot): at 21 players (70% of the 30 cap) a new player's first bridge was 24 min with the free gift, 40 min training to 2,500 Strength first; alone or with two, 36 / 54 min. It was only sized when a bridge started (a fresh server's first was always 2,400), so a bridge that started full could trap a few remaining players.
- **Fixed 20,000** (now 19,200): 21 players 14 / 28 min, 15 players 20 / 35, 10 players 30 / 47, 5 players 60 / 81, 3 players 1.7 / 2.1 h, alone 5 / 5.9 h. Quiet hours and launch week will have the small-server cases.
- 1,000 Strength carries 26 planks and takes 4.3 min on the 1x bench; the free gift's +1,500 carries 32. Training past about 5,000 on 1x costs more time than it saves on a first bridge.
- **Auto Build switch in Settings (2026-10-11, the user's ask):** pass owners get an "Auto Build ON/OFF" row (saved as `AutoBuildOn`, on by default; hidden without the pass). Off stops both the server's auto pick-up and the client's auto placing. The Settings window is 25% bigger on computers (the user: a bit small). Checked: off, nothing picked up in 3 s at the pile; on, 125 again.
- **Lucky Planks icon (2026-10-11, the user's ask):** a wood plank with a four-leaf clover on it and two gold sparkles, in the same outlined cartoon style as the other upgrade icons (`tools/make_ui_icons.py`, `tools/out/icon_lucky_planks.png`; decal 103889402964053, image 72208787359977; framed tight so it fills the slot like the others, `UIStyle.Icons.LuckyPlanks`).
- **Robux shop icons (2026-10-11, the user's ask: no emojis):** "BOOST Server Training!" is a cartoon rocket (the user's pick after a barbell version; decal 116170853967272, image 72382428722597); Auto Build is BuilderBot's head (yellow hard hat, black screen, cyan eyes) over a plank (decal 108593281806783, image 95722617073124). Same outlined cartoon style, drawn by `tools/make_ui_icons.py` (`server_boost_icon`, `auto_build_icon`); ids in `UIStyle.Icons`. Checked in a playtest.
