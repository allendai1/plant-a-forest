# Handoff: where Plant the Forest stands

Written 2026-10-06; last updated 2026-10-08 at the end of the soft-launch polish session. Read this after [CLAUDE.md](../CLAUDE.md), then [docs/DESIGN_CHANGES.md](DESIGN_CHANGES.md) (what changed from the original GDD and why) and the latest plan in `docs/plans/`.

## Where we left off (2026-10-08, late: soft-launch polish)

**State:** feature-complete MVP, polished and published by the user (last publish was before the final round below, so **republish**). Every script in Studio matches the repo (checked by comparing each script's `#Source` with the file size). Studio-only edits that exist only in the saved place: the seed stall put away in `ServerStorage.SavedForLater`, the Ranger-copy shopkeeper, the four lobby leaderboards (user-placed, r about 146), the group gift bulletin board. **The user must save and publish** to keep them.

**Git:** https://github.com/allendai1/plant-a-forest.git, branch `main`. Last push `a3776ed` (polish pass + M12 desktop numbers). **Uncommitted since then** (all synced to Studio): the group gift (GroupGiftController, ClaimGroupGift, GroupGiftClaimed), FallService, the four-stat leaderboards, the locked-station buy prompt, footsteps removed, mobile Plant/Drop/trunk/shop changes, prompt padding, Sherwood weight 50, sound volume tweaks, tutorial ring hint. Commit and push only when the user asks.

**Working rules learned this session** (also in memory): never use computer-use on the user's machine; verify with the Studio MCP and ask the user to check visuals and phone layouts. Don't start playtests while the user may be in Studio unless asked. Studio's Device Simulator reports a keyboard, so `UIStyle.isTouch()` is false there and the phone layout can't be previewed in it; the user tests phones themselves.

**Open items before ads:**
1. **Two-player test** of the shared features (the user said they'd do it).
2. **Real-phone check** of the latest mobile layout: dark round Plant button up-left of the jump button, Drop button right of the Forest Bar, ring trunk at the top middle in the top-bar row (1.25x), bigger shop, Pick Up panel padding. Also frame rate with a full forest on a phone (desktop: 60 fps at max quality, [docs/plans/M12.md](plans/M12.md)).
3. **Player list column order:** Roblox showed Speed, Strength, Forests, Seeds regardless of creation order; Priority/IsPrimary values were added per column (LeaderboardService). Unconfirmed; if it still misorders, the fix is a custom player list.
4. **Balancing.xlsx:** world weights 50/30/10, group gift 500 coins, plus the earlier 2026-10-08 numbers.
5. Purchases and the Creator Dashboard are done (the user's word).

**Defaults the user may change:** group gift 500 coins (`GameConfig.Economy.GroupGiftCoins`); fall respawn below y -50 (FallService FALL_Y); world weights 50/30/10 (the 10 means Kyoto is 33%, not 30%).

**Tools:** `tools/studio_sync.py --fetch <files>` with `python -m http.server 34877 --bind 127.0.0.1` running from the repo root (stop it when done); `tools/upload_png.py`, `tools/upload_fbx.py` (Open Cloud, free; never spend Robux).

## Status

| Milestone | State | Plan and results |
| --- | --- | --- |
| Architecture | approved | [docs/ARCHITECTURE.md](ARCHITECTURE.md) |
| M0 Project setup | done | [docs/plans/M0.md](plans/M0.md) |
| M1 Hex grid and tiles | done | [docs/plans/M1.md](plans/M1.md) |
| M2 Stats and training | done | [docs/plans/M2.md](plans/M2.md) |
| M2b Interactive stations (press E bench, auto treadmill, per-station multipliers, Robux unlock popup) | done | [docs/plans/M2b.md](plans/M2b.md) |
| M3 Seed rack and carrying | done | [docs/plans/M3.md](plans/M3.md) |
| M4 Targeting and planting | done | [docs/plans/M4.md](plans/M4.md) |
| M5 Growth, Forest Bar and coins (starter name label postponed) | done | [docs/plans/M5.md](plans/M5.md) |
| M6 Forest complete (cutscene, break, Ancient Spring, Robux extensions, test panel) | done | [docs/plans/M6.md](plans/M6.md) |
| M6b Lobby (glyphs and vines, plaza, fence, trails, shop altar and ring, acorn racks, tier pads) | done | [docs/plans/M6b.md](plans/M6b.md) |
| M7 Upgrades (the shop at the altar ring) | done | [docs/plans/M7.md](plans/M7.md) |
| M8 Saving (ProfileStore) | done | [docs/plans/M8.md](plans/M8.md) |
| M9 Rain and the Wet mutation | postponed to after launch (the user's call) | [docs/MVP_PLAN.md](MVP_PLAN.md) |
| M10 First-time experience (tutorial prompts and arrow, free gift; quests postponed) | done | [docs/plans/M10.md](plans/M10.md) |
| M11 Art pass (moved before performance) | done, except the fps check (moved to M12) | [docs/plans/M11.md](plans/M11.md) |
| Post-M11 polish (the user's requests: training tiers to 100x, pads, effects, lighting, bench and run animations) | done | "Changes after M11" below |
| GUI pass (Build-the-Pyramid-style HUD, Robux shop, boost passes, Forest Bar seed products, Friend Boost, custom E prompt, Robux upgrade levels, phone layout) | done; the friends and server boost icons are still emoji | [docs/plans/GUI.md](plans/GUI.md) |
| Polish after the GUI pass (2026-10-06/07, the user's requests one by one) | done; each has its own section below | [docs/plans/TreeStages.md](plans/TreeStages.md), [docs/plans/AcornOrbit.md](plans/AcornOrbit.md) |
| Seed shop (special trees that boost training, the user's request) | done 2026-10-07; two-player checks still open | [docs/plans/SeedShop.md](plans/SeedShop.md) |
| Polish pass (shops UI, sound, Park Ranger / Forest Lord, codes, seed shop rebalance, leaderboards, badges) | done 2026-10-07; badges need creating on the dashboard, icons still emoji | [docs/plans/Polish.md](plans/Polish.md) |
| Launch prep (2026-10-08: forest sizing, analytics, lobby and HUD changes; see "Where we left off") | done | this file, [docs/plans/TuningSignals.md](plans/TuningSignals.md) |
| **M12 Performance pass** | **in progress**: tile collision removed; frame-rate measurement needs Studio rendering | [docs/plans/M12.md](plans/M12.md) |

Each plan file ends with a "What changed from the plan" section that lists exactly what was verified and what wasn't.

## The game as it is now

- **Map:** a floating island (M11) with a central hub (hex rings 0–6, about 180 studs radius) around the world tree, and 9 forest rings (7–15) of visible hexagon tiles. That's 540 plots (594 hexes minus 54 under six walkway spokes) × 44 seeds = a target of 23,760.
  - **Hub:** a stone plaza inside a fence with gates at the six trails (M6b).
  - **Around the island:** cliffs, six waterfalls, clouds, and floating islets reached by rope bridges from the trail ends.
  - **Plaza decorations:** the free-gift board (225°; its ring opens the gift popup) and a fountain (285°). The flower garden and the trail-side flowers were removed at the user's request.
- **One row open at a time:** the walkways split the forest into 6 sections of 90 plots. The section the seed rack is in goes first, row by row from its outer edge (14 plots) in to the hub (6 plots), then the next section around. A row moment plays per row and the big section moment per section. The open row is the `OpenRow` attribute (section, ring).
- **Training:** press E at a bench press (it continues until you jump off), or step onto a treadmill. One rep every 0.25 s pays +1 × the station's multiplier.
  - **Tiers:** one bench and one treadmill per tier (1x/2x/5x/10x/25x/50x/75x/100x), unlocked by forests completed or a per-tier game pass (all created; ids in `GameConfig.StationPasses`). Your own account owns every pass in your game, so locks only show for other players (or Studio's test players).
  - **Pads:** each tier sits on a round pad, 4 pads between the trails at 60° and 120°, 4 between 120° and 180°.
  - **Adding a tier:** a `GymMultipliers` step and a pass in GameConfig, then a row in `TIERS` in `tools/build_map.luau`, which copies the 25x stations for it (including the treadmill Zone's own `Multiplier` attribute).
- **Seeds:** walk up to any of the six acorn piles around the tree's roots (97 studs out at 30° + 60k).
  - **Grabbing:** a Pick Up button shows at the bottom of the screen; hold E or the button to grab up to capacity.
  - **What you carry:** acorns circle your head (see "Acorns circling the head" below).
- **Planting:** the closest open plot within 30 studs is outlined, with a meter. E, the gamepad X button, the mobile button or a tap on the game view plants 1 per press (holding repeats). Overflow goes to the open plot closest to you. When nothing is in range, an arrow points to the nearest open plot.
- **Art:**
  - **The assets:** low-poly, generated by `tools/blender/build_assets.py`, uploaded with Open Cloud and stored in `ReplicatedStorage.Assets`:
    - `Tiles.HexTile`: dirt with a grass border, grassy with flowers once planted
    - `Trees.Leafy1–8 / Pine1–8`: 8 growth stages since 2026-10-06
    - `AncientTree.Ancient1–4 + AncientBase`: the world tree, about 354 studs tall full grown
    - `Lobby.*`: plaza, fence, trail, shop altar, acorn pile, bench press, treadmill, gift board, fountain, `FenceDecor`
    - `Map.*`: island, clouds, islets, bridge
    - `Animals.*`: deer, fox, bunny and bird, for the break
  - **Who builds what:** the client builds the trees (ForestController) and the Ancient Tree (AncientTreeController). `tools/build_map.luau` builds everything else in `Workspace.Map`.

## Changes after M11 (the user's requests, 2026-10-06)

All in `tools/build_map.luau` unless noted, and already rebuilt in Studio:
- **Removed:** the flower garden and the flowers along the trails, from the map script, the Blender script (`flower_garden`, `LobbyPath_Flowers`) and the stored assets. The user deleted them in Studio first and didn't like the look.
- **Training tiers 50x, 75x and 100x** (GameConfig `GymMultipliers` and `StationPasses`), unlocked at 25, 50 and 100 forests or with passes at 699, 899 and 1,099 Robux. Colors red, pink and emerald.
- **Round pads** (`PAD_SIZE` 24): a flat cylinder floor edged with the gift board's ring mesh in the tier's color. Plain parts the map script makes are SmoothPlastic (Plastic showed studs).
- **Bigger stations:**
  - Treadmills (`TREAD_SCALE`) and bench presses (`BENCH_SCALE`) are 1.5x the Blender models; the treadmill's Zone and belt arrows scale with them.
  - The bench seat sits `SEAT_TOWARD_BAR` toward the bar, so a lying player's chest is under it and their head stays on the pad.
  - Barbell plates are black on every tier.
- **Layered tier effects** (`tierEffects`, hung on each pad's ring). Each tier adds one layer to the tiers below:

  | Tier | Adds |
  | --- | --- |
  | 2x | glitter |
  | 5x | twinkling stars |
  | 10x | rising motes |
  | 25x | embers and a light |
  | 50x | rim flames and a straight light column as wide as the ring |
  | 75x | mist, a taller column and a brighter light |
  | 100x | rainbow sparks and a rainbow column |

  Particles use LightEmission 0.3 and LightInfluence 0 (fully glowing particles vanish on the pale pavers), except the fire and sparks, which glow with Brightness 4 to 5.
- **Less bright:**
  - Lighting Brightness 2, ExposureCompensation −0.25, and the colour grading's brightness boost removed.
  - Bloom 0.2 / 18 / threshold 1.4.
  - Every neon part in `Workspace.Map` and `ReplicatedStorage.Assets` darkened to 65% (`NEON_DIM`). The colour each was dimmed to is stored in its `NeonDimmed` attribute, so reruns don't darken them again.
- **Animations** (`src/client/Controllers/TrainingController.luau`):
  - **Bench:** whoever is shown on a bench lies on their back and presses. The pose is set in code every frame (the avatar joints' `Transform`, no animation asset), and the bar follows the hands. Presses per second grow with log10(Strength), from 0.7 to 2.5.
  - **Treadmill:** the run animation plays at walk speed ÷ 24 (the player's own walk-speed limit included), so 1.33x for a new player, capped at 3x since the 2026-10-07 walk-speed refit.

## GUI pass (2026-10-06)

See [docs/plans/GUI.md](plans/GUI.md).
- **Shared look:** `src/client/UIStyle.luau`:
  - the font (Gotham Black) and colors
  - `dropShadow`, the pyramid's two-label text with an outline and a dark copy underneath
  - gradient buttons
  - a UIScale based on screen height
  - price lookups
  - `UIStyle.Icons`: the user's images for coins, speed, strength and forests; emoji for friends, shop and the server boost
- **Map signs:** `tools/build_map.luau` restyles them at the end of a rebuild.
- **Robux items:** ids are in GameConfig (`Boosts`, `BarBoosts`, `ServerBoost`, `UpgradeProducts`, `FriendBoost`).
- **Prompts:** set to `Style = Custom` and drawn by PromptController.
- **Postponed:** the user postponed the two "characters" (quicker pickup and place) from the pyramid's shop, to design later.

## Fall-through fix (2026-10-06)

- **The bug:** players fell through a ring of gaps just outside the plaza fence (160–174 studs from the center).
- **Why:** the hub's grass (`HubClearing`) ends at 160, and the walk plate's plaza cut-out is wider. The visible grass there is `ForestFloor`, which is walk-through.
- **The fix:** `HubEdgeFloor`, an invisible, collidable copy of HubClearing out to 180. It's tagged `WalkFloor`, so ForestService's plot raycasts ignore it. It's in `tools/build_map.luau` and placed in Studio.
- **Checked:** a raycast scan finds no gaps left inside 360 studs, and standing on the old gaps works. The island's outer edge (from about 370 out) is open on purpose.

## Trails and the fence ring (2026-10-06, the user's picks)

- **Trails:**
  - **Width:** 32 studs (`PATH_WIDTH` in `tools/blender/build_assets.py`). That covers the zig-zag of the walkway's removed hexes; the neighbouring plots' corners tuck under the stones.
  - **Height:** placed at `TILE_TOP + 0.05`, above the tiles' raised edges (1.75). A grout bed (`PathBed`, top 1.85) hides those edges in the joints.
  - **Solid:** `LobbyPath_Stone` collides, so players walk on the stones.
  - **Removed:** the old grass strip and edge rocks, which would sit inside plots now.
  - **Lanterns:** on the road's edge.
- **Fence ring:** `FenceDecor` (bushes, then rocks in the spaces between them) fills the grass between the round fence and rings 7–8, clear of the trails. It isn't collidable.
- **Uploaded:** both in asset 88707636672468, imported and placed with a full `build_map` run.

## Tree stages: 4 → 8 (2026-10-06)

See [docs/plans/TreeStages.md](plans/TreeStages.md).
- **Models:** `Leafy1–8` / `Pine1–8` in `Assets.Trees`.
- **Stage starts:** `GameConfig.Growth.StageStarts`, at seeds 1, 3, 6, 10, 16, 24, 33 and 44.
- **Stage changes:** a smoother pop, a leaf puff, and a "bling" for your own seeds on stages 2, 4 and 6 (ForestController `STAGE_SOUND_ID` = Creator Store "bling_diamond_pickup_2", 4612374393, same pitch each time; `STAGE_BLING_EVERY` = 2). The user tried a rising scale and chose this. The full-grown chime is back at pitch 1.
- **Pad signs:** "Requirements: N" plus the tree icon.

## Coin flow and rolling numbers (2026-10-06)

In `HUD.luau`:
- **Coin flow:** earned coins (gains within 0.3 s merged) burst out over a wide area in the middle of the screen (6–18 coins, popping in 1.4x big, then settling) with a big "+N", then fly in an arc to the coin icon. This happens on the `CoinFlow` ScreenGui, which is full screen with no insets, so it works in viewport pixels.
  - **Landing:** the counter adds each coin's share as it lands, and the icon and the number bump.
  - **Spending:** rolls the number straight down.
  - **The first value** (the save loading) appears without a flight.
  - **During the cutscene:** flights wait until the HUD shows again.
- **Rolling numbers:** Speed, Strength and forests count up to each new value over 0.35 s instead of jumping.
- **Stat popups** (floating text): every Strength or Speed gain shows "[icon] +N" somewhere around the middle of the screen. It pops in, floats up and fades over 1 s. At most 14 show at once, and loading your save doesn't trigger one. The constants are `GAIN_*` in HUD.luau.
- **Coin sound:** `COIN_SOUND_ID` = Creator Store "plop" (WesFluff, 773858658, 0.19 s).
  - **Why this one:** it's the closest match to the user's reference recording, a short soft thump around 2.2 kHz. Sounds were measured with AudioAnalyzer in a playtest; the recording was decoded with miniaudio.
  - **How often:** one per burst, on its first landing, and never two within 0.25 s (`COIN_SOUNDS_MAX`, `COIN_SOUND_GAP`).
  - **Pitch:** 1 ± 5%.
- **Forest icon:** now 137125846833438 ("forest-two-trees", `UIStyle.Icons.Forests`). It's also on the training pad signs.

## Acorns circling the head (2026-10-06)

The giant seed is replaced by acorns circling the head (see [docs/plans/AcornOrbit.md](plans/AcornOrbit.md)).
- **Config:** `GameConfig.AcornOrbit` and `GameConfig.acornCounts`.
- **Code:** CarryController.
- **How it looks:**
  - **Small acorns** for 1–5 seeds, then every 6 of a tier merge: large at 6, huge at 36, giant at 216.
  - **Placement:** the bigger tiers ride above the head like a crown, with no number shown.
  - **Merges and splits** animate, with a puff. The merge sound was removed at the user's request.

## Pick Up button and shop icon (2026-10-06)

- **The Pick Up button:** an acorn pile's prompt is no longer drawn on the pile.
  - **Where:** a "Pick Up" button shows at the bottom middle of the screen while you're in range (higher on phones, above the Forest Bar). The code is PromptController's `isPile` / `onPickup`.
  - **Using it:** E works as before. Clicking or tapping and holding the button keeps grabbing.
  - **Feedback:** every pickup bumps the button and plays a pop: Creator Store "Pop Sound Effect", 140323850218372, rising in pitch over a run of grabs. Benches keep their prompt on the bench.
- **Shop icon:** the SHOP button uses the user's "shopping-basket-classic" image (100081844801656).

## Locked stations and thinner sign shadows (2026-10-07)

- **The bug:** the 50x, 75x and 100x treadmill Zones still had `Multiplier = 25` from the 25x zone they were copied from. Anyone with the 25x unlock could run on them, paid at 25x.
- **The fix:** fixed in Studio, and `tools/build_map.luau` now sets the zone's Multiplier on every run.
- **Testing locks in Studio:** your own account owns every pass, so every station is unlocked for you. The test panel's **Clear station passes** (`clearStationPasses`) forgets them for the session, so the locks can be tested.
- **Verified with 4 forests:**
  - **10x treadmill:** no Speed, no run animation, and the "10x station locked" popup shows.
  - **10x bench:** E doesn't seat you, and the popup shows.
- **Lighter shadows:** `UIStyle.THIN_DROP` (0.07 instead of 0.14), used on the Forest Bar number and every map sign (UPGRADES, SEEDS, FREE GIFT, the pad signs).

## Stat refit and walk speed setting (2026-10-07)

- **Refits:** the capacity and walk speed curves now match every Build the Pyramid reading, including the new ones (Strength 105,428 → 171; Speed 60,070 → 164).
  - **Walk speed has no ceiling** anymore; the old curve stopped under 60.
  - **The treadmill run animation** is capped at 3x so legs don't blur.
- **The walk speed setting:** clicking the "Walk Speed" line in the HUD shows − / + / MAX buttons, in steps of 5.
  - **What it sets:** the player's own limit (`WalkCap`, saved; 0 = none), applied by TrainingService. The line reads "Walk Speed: 80 (max 216)" while limited.
  - **Server checks:** `SetWalkCap` is validated (rate limit, number range, at least `WalkSpeed.Base`).
- **Stat popups:** they tilt up to 14° and lean further as they float.
- **Pickup pop:** half volume (0.25).

## Seed shop (2026-10-07)

See [docs/plans/SeedShop.md](plans/SeedShop.md). Grow a Garden-style:
- **Restock:** a 5-minute restock, the same stock in every server (`GameConfig.seedStock`).
- **Seeds:** four special seeds (Palm, Cherry Blossom, Redwood, Crystal Tree), saved in a seed bag.
- **Planting:** a seed turns an open Common tree into a special one, up to 3 per player per forest.
- **Boosts:** full-grown special trees boost their owner's training, and Redwood and Crystal also everyone's, until the forest resets.
- **Code:**
  - **Server:** `ForestService` (planting and boosts), `EconomyService` (buying), `DataService` (bag), `TrainingService` (`gain()` applies the boosts).
  - **Client:** `SeedBagController` (bag and boost line), `ShopController` (Seeds tab).
- **Art:** `build_assets.py` has `palm`, `sakura`, `redwood`, `crystal` and their `*_seed` functions; `build_all()` builds them. Lineups are in `docs/plans/*_lineup.png`.
- **Studio test panel:** "+1 of each special seed".
- **Spreadsheet:** the seed table (prices, odds, boosts, caps) needs adding to `docs/Balancing.xlsx` by hand.

## Lobby fixes (2026-10-07, the user's requests)

All in `tools/build_map.luau`, rebuilt in Studio:
- **Fence:** walk-through everywhere. The invisible `FenceWall` parts along it are gone, and only the gate lights remain. Players don't need to jump: a character walks up every ledge between the plaza, the trails and the tiles (up to 1.2 studs), as tested with `MoveTo`.
- **Treadmills:** each has an invisible collidable `Deck` level with the belt top (1.96). Runners stand on the belt instead of sinking to the pad. Tested: feet at 1.96, and training still pays.
- **Fountain:** removed, with the benches that were part of its model. Its spot at 285° (`FOUNTAIN_ANGLE`) is free.

## Seed stall, bamboo, worlds and settings (2026-10-07, later)

See the end of [docs/plans/SeedShop.md](plans/SeedShop.md).
- **Seed stall:** the seeds have their own stall at 285°, where the fountain was. The altar only sells upgrades.
- **Bamboo:** a new shop seed.
- **Worlds:**
  - **The roulette:** after every break it picks the next world: Meadow Woods 80%, Sakura Bamboo Valley 20% with 2x coins and wild sakura and bamboo trees.
  - **Settings:** `GameConfig.Tiers` (Weight, CoinMultiplier, Commons) and `GameConfig.Roulette`.
  - **Code:** `WorldRouletteController`.
- **Settings button:** the walk speed limit and the guide arrow toggle.

## Target highlight and locked sections (2026-10-07, the user's requests)

- **Target** (`TargetController`):
  - **Outline:** taller, and it pulses.
  - **Fill:** a thin copy of the tile's slab glows over the target tile (`Fill` in `Workspace.TargetIndicator`).
  - **Arrow:** a bobbing ▼ (`TargetArrow`, AlwaysOnTop) floats 13 studs above it.
  - **Colors:** all follow the outline's color: white, gold when the press finishes the tree, the seed's rarity color, or red.
- **Locked sections** (`ForestController.refreshPlot`):
  - **Other sections:** slate grey tiles (`SECTION_LOCKED_COLOR`).
  - **Current section:** its not-yet-open rows stay brown.
  - **Open row:** brown with the pulsing rim, as before.
  - **Checked by counting tiles:** 14 open, 76 brown, 450 grey.
- **Not checked by eye:** Studio wasn't rendering (RenderStepped 0/s), so neither change has been seen on screen yet.
- **Guide arrow:** a new chevron texture (78690048206615, drawn by `guide_arrow` in `tools/make_particle_textures.py`, white and tinted blue), one every 7 studs (`GUIDE_SPACING`), scrolling toward the plot. A beam runs the image's *height* along its length (top = Attachment0), so the chevron points up in the image. The first version pointed sideways; this one was checked on screen. Unused: 139222094517681.

## World Tree label (2026-10-07, "for now")

`AncientTreeController` puts a "World Tree" label (map-sign style, cyan) on an invisible `LabelAnchor`:
- **Height:** 8 studs above the tree's top while it's small, and never higher than 45 studs.
- **Visibility:** it shows through the trunk (AlwaysOnTop), within 250 studs.
- **Checked:** the label exists and sits at 24.8 studs over the sapling. It hasn't been seen on screen, because Studio wasn't rendering.

## Soft-launch prep (2026-10-07)

Readiness review: NOT READY yet. The blockers are performance (M12), a 2-player test, one real test purchase of each product kind, and the Creator Dashboard setup.
- **Analytics** (`src/server/Analytics.luau`, server only, every call wrapped):
  - **Onboarding funnel:** Joined, PickedUpSeeds, PlantedSeed, Trained, BoughtUpgrade, CompletedForest. Newcomers only (no forest completed), each step once per session.
  - **Coins economy:** sources (planting, summed per player per minute; the forest reward; the free gift) and sinks (upgrades, seeds).
  - **Custom events:** SeedBought and SpecialSeedPlanted (seed id field).
  - **Verified in Studio:** "AnalyticsService: ... event fired" for the economy, custom and onboarding events.
- **Playtime funnels** (2026-10-07, `Analytics.luau`, checked every 30 s once the save has loaded):
  - **SessionLength:** 1/3/5/10/15/20/30/45/60/90/120 min, one funnel per visit.
  - **LifetimePlaytime:** 10/30 min, then 1/2/5/10/20/50 h, one funnel per player, from the new saved field `PlayTimeSeconds` (+60 every minute online).
  - **ForestMilestones:** 1/3/8/15/25/50/100 forests, the station unlocks, logged by AwakeningService.
  - **Verified in Studio:** the session "1 min" step, the "3 forests" milestone, and PlayTimeSeconds going up by 60.
- **Loop and purchase funnels** (2026-10-07, `Analytics.luau`):
  - **ForestLoop**, per player per forest: InServer (on join or forest start), PlantedAcorn, Planted50, Completed, SawRoulette, PlantedNextForest.
  - **RobuxShop**, per shop opening: Opened (client remote `RobuxShopOpened`), Prompted, Purchased (from Roblox's prompt-finished events within 5 min).
  - **LockedStation**, per locked try: Tried (TrainingService), Prompted, Purchased (that station pass, within 2 min).
  - **Verified in Studio:** the full ForestLoop (8 events, in order), RobuxShop Opened and LockedStation Tried.
  - **Not verified:** Prompted and Purchased. They need clicking through a Roblox purchase prompt.
- **Leaving and break custom events** (2026-10-07, `Analytics.luau`):
  - **LeftGame** (on leaving): value = minutes this visit; fields = capacity band, forests band, upgrade levels band.
  - **BreakActivity** (per player when the break after a forest ends, just before the roulette): value = seconds present. The fields:
    - "Mostly Spring/Training/Walking/AFK", sampled every second. AFK means less than 2 studs of movement for 20 s, off the stations and out of the Spring.
    - "Bought Robux+Seed+Upgrade" or "Bought nothing".
    - Spring share: 0%, 1-49% or 50%+.
  - **LeftDuringBreak:** the same first two fields, for a player who leaves mid-break.
  - **Verified in Studio:** BreakActivity fired before the roulette, and LeftDuringBreak plus LeftGame fired when the playtest stopped mid-break. The field values themselves can't be read back in Studio.
- **Treadmill kit:** the stray "TreadmillSpawn by Jose" free model was deleted (read first: no backdoor).
- **Tile collision:** tiles no longer collide (see [docs/plans/M12.md](plans/M12.md)).

## Bulk upgrades +1 per level (2026-10-07, the user's call)

Bulk Pickup and Bulk Plant now give 1 → 2 → 3 → 4 → 5 → 6 per press (they were 1/2/4/8/16/all). Prices and the Robux levels are unchanged. For the spreadsheet: `GameConfig.Upgrades` ValuePerLevel.

## Slower base pace and Hands passes (2026-10-07, the user's call, after Build the Pyramid)

- **Base pace:** holding E grabs or plants once every 0.25 s (`Planting.HoldRepeatSeconds`, was 0.12).
- **Hands passes** (`GameConfig.HandsPasses`) make it faster; the best one owned counts:
  - **Quick Hands:** 2x, 49 Robux, pass 2014628378.
  - **Ultra Hands:** 3x, 149 Robux, pass 2014682392.
- **Where the pace applies:** `PassService.handsSpeed` (the `HandsSpeed` attribute) drives the pile's server loop (`CarryService`), the client's hold loop (`CarryController`) and the plant rate limit (`ForestService`: `PlantRateSlack` 1.2 × the player's pace, burst 3).
- **Robux shop:** a "Planting Speed" card. Studio test command: `grantHands 2|3` (1 removes).
- **Verified:** without a pass the server accepted 17 plant requests out of 50 a second over 3 s, which is burst 3 + 4.8/s. With Ultra Hands it accepted 27 before the test tree filled up, so that number is a lower bound.
- **Build the Pyramid clip** (the user's, 0–3 min): this matches it.
  - **Pickup and put-down:** about 0.23–0.3 s per press.
  - **Training:** about 4 Strength or Speed a second at 1x.
  - **Capacity:** our fitted curve is within ±1 at every reading (Strength 9 → 2, 72 → 7, 135 → 10, 187 → 12, 247 → 14, 280 → 15).
  - **Walk speed:** Speed 32 → 35 and 63 → 37, which ours matches.

## 100 acorns per tree (2026-10-07, the user's pick to evaluate)

- **The change:** `Tiers[].SeedsPerHex` 44 → 100, so the forest target is 54,000 (was 23,760). Growth stages start at seeds 1, 5, 12, 21, 35, 53, 74 and 100.
- **Bar boosts:** rescaled to +300 / +1,500 / +3,000 / +15,000 (same share of the bar as Build the Pyramid's), and the four products renamed on Roblox to match.
- **Why:** the Build the Pyramid clip's server built about 5,750 blocks a minute, so its 171,700 take about 30 min. With the same players our 23,760 took about 4 min, so unlocks and forest rewards came about 7x faster.
- **The model** at the clip's pace: a forest takes about 9.4 min. 100 forests (the 100x station) take about 19 h of play (pyramid about 53 h, old 44 about 11 h). The break is about 20% of a round.
- **Watch:** small servers of new players take a long time per forest (10 such players: over an hour). Late-game trips are mostly holding E (capacity 1,363 at 6 per press and 4 presses a second is about a minute each way), which the capacity-scaling Bulk proposal would fix.
- **For the spreadsheet:** 100 seeds per hex, target 54,000.

## Pace matched to Build the Pyramid, no Bulk scaling (2026-10-07)

- **Pace:** `Planting.HoldRepeatSeconds` is 0.15 s, Build the Pyramid's measured pace (0.146 s and 0.15 s per press in two of the user's clips, no passes, at 35 and 171 capacity). It was 0.12, then briefly 0.25 from a bad first measurement. Quick and Ultra Hands make it 2x and 3x faster.
- **Bulk:** a flat 1–6 per press, like the pyramid (its +2 and +5 steps were exact).
- **Capacity scaling:** built and then removed at the user's call ("no scaling right now"), with its `tests/BulkCheck.luau`.

## Ranks over players' heads (2026-10-07, the user's pick: "Forest keepers")

- **The ladder** (`GameConfig.Ranks`, `GameConfig.rankFor`), by forests completed:
  - Seedling 0, Sprout 1, Gardener 3, Planter 8, Woodsman 15, Ranger 25, Forester 50, Grove Keeper 100
  - Elder Druid 250, Forest Guardian 500, Spirit of the Wild 1,000, World Tree Warden 2,500, Mother Nature 5,000 (rainbow)
- **Matches the stations:** the first steps line up with the station unlocks.
- **NameplateController:** [rank] in its color over [name], on every character, your own included. It replaces Roblox's name tag (TrainingController no longer turns it back on; a hidden benching double hides its nameplate through the local `NameplateHidden` attribute).
- **Rank-up:** your own rank-up shows a "Rank up! You're now a …!" banner with the level-up sound.
- **Verified in a playtest:** each rank and color at 0/3/25/100/5,000 forests, the rainbow at 5,000, the default tag off, and the banner at 15.
- **Not added:** a rank column in the player list.

## Pass tiers and prices (2026-10-07, the user's prices)

- **New passes:** Strength 32x/64x/128x (199/449/999) and Speed 8x/16x (99/249). The 3x Speed pass became 4x Speed (39), so its owners moved up. The new prices are defaults, not the user's.
- **Repriced:** Park Ranger 99, Forest Lord 799 (was 499 earlier the same day). The Forest Lord was then renamed **Lord of the Forest** (on Roblox and in `GameConfig.HandsPasses`, which gained a `Title` field: "Become the Lord of the Forest"). Its outfit key stays `Lord`. Stations: 2x 19, 5x 89, 10x 179, 25x 360, 50x 599, 75x 729, 100x 989.
- **Code:** all set through the API; GameConfig `BoostPasses` holds the new ids.
- **Robux shop:** boost cards show a window of 4 tiers (`WINDOW_STEPS`).
- **Forest Bar seed packs:** +500 / +1,000 / +2,000 / +5,000 for 49 / 89 / 159 / 349 Robux (were 300/1,500/3,000/15,000 at 45/117/225/630). The products were renamed and given a description saying the buyer gets the coins and forest credit; the amounts are in `GameConfig.BarBoosts`.
- **Balance note:** 128x Strength stacks with the 100x station. If capacity gets out of hand, it shows in [docs/plans/TuningSignals.md](plans/TuningSignals.md).

## Monetization audit (2026-10-07)

See [docs/plans/MonetizationAudit.md](plans/MonetizationAudit.md). The receipt handling passes the skill's checklist; duplicate receipts were tested and grant once.
- **Fixed:** pass ownership checks now keep retrying instead of giving up after 3 tries.
- **Open:**
  - Forest Bar seeds bought during the break are held in server memory (option: hide those buttons during the break)
  - the seed products are still on sale while the seed shop is off
  - real purchase tests: free Studio test purchases first, then the cheapest live ones from an alt

## Re-tuning waits for real data (2026-10-07, the user's call)

Stats, prices and the tutorial stay as they are for launch. After launch, check [docs/plans/TuningSignals.md](plans/TuningSignals.md): which analytics signal means too fast or too slow, and which GameConfig lever to turn. Open gap: a forest-length event isn't built yet.

## Free gift = favorite the game (2026-10-07, the user's call)

- **No own panel any more.** The pink "🎁 Favorite: 500 coins" button, stepping into the gift board's ring, and an automatic prompt once a visit 90 s in (only after the tutorial) all open Roblox's own Favorite prompt directly.
- **Coins:** the client claims them (`ClaimFreeGift`, once ever) only when Roblox reports the favorite succeeded (`PromptSetFavoriteCompleted` = Success), or when `GetFavorite` says the player had already favorited.
- **Likes:** they can't be prompted or detected by a game, so they're no longer mentioned.
- **Verified:** the button shows and the old panel is gone. The Roblox prompt itself still needs a real click to test.

## Design review (2026-10-07)

[docs/plans/DesignReview.md](plans/DesignReview.md) covers retention by phase, an economy model (coins per hour and upgrade timing) and a tutorial audit.
- **Fixed straight away:** the free-gift popup no longer shows mid-tutorial, and the tutorial prompts are cut to about 5 words.
- **Open recommendations:**
  - a walk-speed boost during the tutorial
  - hide the Robux buttons until the tutorial is done
  - a Halloween event in the Smoky Mountains world
  - a "next unlock" welcome-back line
  - a group with a join code

## Tile colors back to one look (2026-10-07, the user's call)

Every unplanted tile now has the open-row brown and grass border. The slate grey for other sections and the darker brown for rows not open yet are gone; the user found them ugly. The open row still stands out by its pulsing rim, the target highlight and the guide arrow (ForestController `refreshPlot`).

## Third world: Great Smoky Mountains (2026-10-07, the user's pick)

- **The world:** autumn Maple and Birch trees, a giant maple World Tree with falling orange leaves, and 3x coins. Roulette odds are Sherwood 60, Kyoto 30, Smoky 10.
- **Details:** [docs/plans/Worlds.md](plans/Worlds.md). That doc also holds the later, not urgent, bigger-map notes and the future seed trees.

## Acorn dispensers replace the acorn piles (2026-10-07, the user's request)

- **The model:** the six seed racks are now acorn dispensers (`docs/plans/acorn_dispenser.png`), about 33 studs tall:
  - a hoop-banded hopper heaped with acorns, on log legs
  - a little green roof with a glowing lantern on top (PointLight), easy to spot from the forest
  - a spiral slide winding down around the legs to a basket at hand height, facing out
- **Where it comes from:** Blender `acorn_dispenser()`, uploaded as asset 128689635657728. `tools/build_map.luau` places `Lobby.AcornDispenser` at the six rack spots facing out (`Lobby.AcornPile` is the fallback). The prompt sits on the basket.
  - Only the legs and plinth collide.
  - Hidden markers `AcornDispenser_Slide01..12` trace the slide.
- **Rolling acorns:** `DispenserController` (client) rolls 2 small acorns per grab down the markers' path into the basket, spinning, when your Carried goes up within 16 studs of a dispenser. At most 10 roll at once, and only you see your own.
- **Getting lost:** out in the forest (over 160 studs from the World Tree) with nothing to carry, the guide arrow now points to the nearest dispenser (TargetController).
- **Server reach** (CarryService `inReach`) is now measured from the prompt's part (the basket), not the model's pivot. The basket stands 6 studs out from the tower, so players at the prompt's range were refused before.
- **Verified in a playtest:**
  - All six racks are placed, each with 12 slide markers and the prompt on the basket.
  - Carried going up near a dispenser launches 2 acorns at the top of the slide.
  - The reach math: 8 studs from the basket is 14.7 from the pivot.
- **Not verified:** a real E grab and the roll itself, since Studio wasn't rendering, so prompts and RenderStepped don't run.

## Guide arrow leads back to where you planted (2026-10-07, the user's request)

- **What it does now:** when you carry acorns and no plot is in reach, the blue guide arrow points to the plot you last planted into while it's still open. Once that tree is full grown, it points to the open plot closest to that spot. Before your first plant, it points to the open plot closest to you, as before.
- **Code:** CarryController calls `TargetController.notePlanted(target)` on every plant request.
- **The toggle** already existed: Settings → Guide arrow ON/OFF (it hides the tutorial's arrow too).
- **Not verified in a playtest:** TargetController runs on RenderStepped, and Studio wasn't rendering (0 frames a second).

## The upgrade shop is a ranger station (2026-10-07, the user's request)

- **The booth:** the stone altar is replaced by a log-cabin ranger station (`docs/plans/ranger_station.png`):
  - plank deck, log walls, a green pitched roof on front posts
  - a waist-high counter with a sack of acorns, a map and a lantern
  - shelves of sacks and crates behind
  - the "UPGRADES" sign over the counter, and the same glowing ring in front (it still opens the upgrade shop)
- **Where it comes from:** Blender `ranger_station()`, uploaded as asset 130737606748210 (v1 81360743433182 is unused). `tools/build_map.luau` places `Lobby.RangerStation` where the altar was; `Lobby.ShopAltar` is only the fallback. Colors are in `COLORS` (Logs, PlankLight, Roof, Burlap) and `SPECIAL_LOOK`.
- **The shopkeeper:** a plain R15 avatar behind the counter, `Workspace.Map.Shopkeeper`, for the user to dress in Studio.
  - build_map only makes it when it's missing, so map rebuilds keep the user's edits.
  - It's tagged `IdleNpc`, and OutfitService plays Roblox's idle animation on every `IdleNpc` model.
- **The character NPCs:** Park Ranger and Forest Lord moved out to either side of the ring (`NPC_BACK` 1, `NPC_SIDE` 13).
- **Verified in a playtest:** the ring opens the shop, the shopkeeper's idle track plays, a player walking at the booth stops at the counter, and the NPCs stand clear.

## Kyoto Forest's World Tree (2026-10-07, the user's request and reference photo)

- **The tree:** `AncientSakura1-4`, a bonsai-like cherry blossom after the user's photo (`docs/plans/kyoto_world_tree.png`):
  - a dark S-curved trunk on a flared root base
  - a lopsided crown that sweeps out to one side and droops at its far end
  - two low branches with small clusters
  - pale pink and white blossom with coral-red specks
  - no markings on the trunk or roots (the user's call, after trying the Ancient Tree's runes and then glowing veins); only glowing pink orbs under the full-grown crown
- **Where it comes from:** Blender `ancient_sakura()`, uploaded as asset 100391191414509 (v3; v1 81023371482166 and v2 99698461520165 are unused). `tools/build_map.luau` files it in `Assets.AncientTree` with its colors (`SAKURA_ANCIENT`).
- **Per world:** `GameConfig.Tiers[].WorldTree` names each world's tree (`Ancient` or `AncientSakura`).
- **AncientTreeController:**
  - shows the current world's tree, and swaps it when the world changes, once the tree has shrunk to a sapling
  - recolors the rune circle and label pink in Kyoto, and uses pink for the forest-complete glow
  - adds falling petals and pink sparkles over the crown, more as the tree grows (`VARIANT_LOOK`, `PETAL_RATE`)
- **Verified in a playtest:** switching to Kyoto swapped in the sakura tree, with the petal emitter. Its growth couldn't be watched, because Studio wasn't rendering (RenderStepped 0/s), so client tweens don't run. That's a test-environment limit, and the original tree didn't grow in that state either. The full-grown look was checked in Blender with the in-game colors.

## World names (2026-10-07, the user's pick)

The worlds are named after real forests: **Sherwood Forest** (tier 1, was "Meadow Woods": leafy trees and pines) and **Kyoto Forest** (tier 2, was "Sakura Bamboo Valley": cherry blossom and bamboo, 2x coins). The names are in `GameConfig.Tiers[].Name`; the roulette cards and the world label read them. Older notes in this file still use the old names.

## Tutorial with a story intro (2026-10-07, the user's request)

- **Story intro:** a new player first sees a skippable cinematic: letterbox bars, the camera sweeping over the bare island to the World Tree, and three captions ending on "Help re-plant the trees to bring back the World Tree!" in gold. It's `playIntro` in TutorialController.
- **Then fixed steps** with a "2/6" counter and the blue arrow:
  1. grab acorns
  2. plant them
  3. train to 20 Strength
  4. fill up again (now 3)
  5. plant them all
  6. buy an upgrade
  7. "Tutorial complete! Now help grow the forest!" with the fanfare
- **Coins top-up:** reaching the shop step tops a player's coins up to 50, the cheapest upgrade.
- **Saving:** the step is saved as `TutorialStep` (0 intro, 1–6, 7 done). Players who had planted before this existed start at 7.
- **Server:** `TutorialService` moves the step on from the player's attributes. It also logs a new `Tutorial` analytics funnel (8 of 10 funnels used).
- **New remote:** `TutorialIntroDone` (rate-limited, 0 → 1 only).
- **While the tutorial runs,** the forest credit line and the gift button (during the intro) are hidden.
- **Config:** `GameConfig.Tutorial` (Steps, DoneStep, TrainedStrength 20, which was 10, and ShopCoins).
- **Studio:** test panel "Replay tutorial intro" (`restartTutorial`), and `setTutorialStep <n>` (7 = done).
- **Verified:** the full run on a reset Studio profile: intro, a real acorn planted for step 2, coins topped to 50 at step 6, a real upgrade bought, "Tutorial complete!". Afterwards the test account's main stats were restored (its Studio seed bag and lifetime SeedsPlanted were reset by the test).

## Forest credit and longer upgrades (2026-10-07, the user's calls after the core loop review)

- **Forest credit:**
  - **The rule:** +1 forest and the 500-coin reward now need 50 acorns put into that forest (`Stats.ForestCreditSeeds`). Hand planting and Robux bar boosts both count.
  - **Code:** ForestService counts per UserId (kept across a rejoin, cleared on reset; the `ForestPlanted` attribute) and `hasForestCredit()`. AwakeningService only rewards players who have it.
  - **Players without credit:** they get "Forest complete! Plant 50 acorns next time to earn it" and still get the Spring.
  - **The HUD:** a green line under the Forest Bar, "Plant 32 more acorns to earn this forest (18/50)", until you reach 50. Then a "You'll earn this forest!" banner.
  - **Studio test panel:** "Forest credit: 0 / 50" (`setForestPlanted`).
  - **Verified:** a forest filled with 0 planted gave nothing; with 50 it gave +1 forest and +500 coins.
- **Upgrades:**
  - Bulk Pickup and Bulk Plant go to level 12 (1 to 13 per press) and Planting Range to level 10 (+40 studs). Each level costs 2.5x the last.
  - Bulk: 50 → 1,192,093, about 2M per upgrade in all. Range: 60 → 228,882, 381K in all.
  - Robux levels exist only for levels 1–5, and the Robux button hides past them.
  - For the spreadsheet: `GameConfig.Upgrades`.
- **Banners** now draw over open shops.

## Seed shop feature flag (2026-10-07, the user's call)

`GameConfig.Features.SeedShop` is **false**: the seed shop is built but left out of the MVP.
- **When off:**
  - EconomyService moves the seed stall and its ring from `Workspace.Map.Lobby` to ServerStorage at start.
  - `BuySeed` and `PlantSpecial` are refused, and codes that give seeds answer "That code doesn't work".
  - The client shows no seed bag or restock line, and no rare-seed banner. The Studio test panel hides its seed button.
- **Kept:** saved seed bags, and the Robux seed products' receipt handling (nothing can prompt them).
- **To release it:** set it to true and sync, and move `SeedStall` and `SeedShopZone` from `ServerStorage.SavedForLater` back into `Workspace.Map.Lobby` (put away in the place file on 2026-10-08 so it's gone in Edit too; tools/build_map.luau skips the stall while it's away).
- **Verified in a playtest with it off:** no stall, no bag UI, the SAKURA code refused, and BuySeed / PlantSpecial didn't change the bag.

## Badges (2026-10-07)

All 5 were created with the API key (scope `legacy-universe.badge`), inside the free daily quota (5, now 0), with `expectedCost = 0` so a paid one would fail instead of charging. **Never spend Robux.** Ids are in `GameConfig.Badges`. They use Roblox's default icon; swap the icons on the Creator Dashboard. Verified: a playtest awarded Welcome and First Forest to the test account.

## Polish pass (2026-10-07)

See [docs/plans/Polish.md](plans/Polish.md) (screenshots in `docs/plans/polish/`). In short:
- **Shops:** new UIStyle helpers (`clicky`, `deny`, `flash`, `card`, `closeButton`, `short`). The Robux shop has tabs (Boosts / Characters / Stations).
- **Sound:** `src/client/Sounds.luau` (ids and the Effects/Music groups), `FootstepController`, `MusicController`, and Music / Sound effects toggles (`SetSetting`, which replaced `SetGuideArrow`).
- **Characters:** the Hands passes are now the Park Ranger (2x) and the Forest Lord (3x). `OutfitService` dresses owners, places the NPCs by the altar and makes the shop previews.
  - **Rebuilding the outfits:** Blender `outfits()`, then the upload, then `tools/build_outfits.luau`, which reads `ServerStorage.OutfitMeshes`.
- **New services:** `CodeService` (`RedeemCode`, `GameConfig.Codes`), `LeaderboardService` (OrderedDataStores plus leaderstats; boards in `tools/build_map.luau`, drawn by `LeaderboardController`) and `BadgeAwardService` (`GameConfig.Badges`, all 0 until created).
- **Seed shop rebalance:** owner boosts +5/10/10/20/40%, server boosts +0.05x/+0.1x, caps +75% and 1.2x, prices 600/1,800/2,000/6,000/18,000.
- **For the spreadsheet:** the seed table above, and `AcornOrbit.MergeAt` 4 (was 6).
- **Waiting on the user:**
  - (done: the 5 badges are created and their ids are in `GameConfig.Badges`; icons are Roblox's default)
  - pick the real launch codes
  - (done 2026-10-07: the two passes are renamed on Roblox to "Park Ranger" / "Forest Lord" with new descriptions; prices unchanged)
  - badges by API: add `legacy-universe.badge` to the key (manage-and-spend-robux to create, write to edit). `POST https://apis.roblox.com/legacy-badges/v1/universes/{universeId}/badges`; the free quota was 5 on 2026-10-07 (`GET https://badges.roblox.com/v1/universes/{id}/free-badges-quota`); past it, each badge costs Robux
  - icons
  - listen to the new sounds
  - a phone emulator check

## How to work on it (important)

- **No Rojo, no git.** The files in `src/` are the source of truth and get pushed into the open Studio place ("Plant a Forest", placeId 93453899201090) through the Roblox Studio MCP connection. The user saves the place in Studio afterwards.
- **Syncing:**
  1. Start `python -m http.server 34877 --bind 127.0.0.1` from the repo root in the background.
  2. Run `python tools/studio_sync.py --fetch <files>`.
  3. Paste its short output into `execute_luau` (Edit datamodel). Studio downloads each file and checks its byte count.
  4. Stop the server when done.
  5. To confirm, compare every script's `#Source` with `wc -c` on disk.
- **Rebuilding the map:** with the same server running, `loadstring(HttpService:GetAsync("http://127.0.0.1:34877/tools/build_map.luau", true))()` in Edit. It's re-runnable and takes most of the MCP's time limit, so run it once per call. If GameConfig changed in this Studio session, first replace `ReplicatedStorage.Shared.GameConfig` with a `:Clone()` of itself. Edit mode caches `require`, and the map script would otherwise read the old numbers (this put "Free" on the new pads once).
- **Checks before syncing:**
  1. `stylua src && stylua --check src`
  2. `selene src`
  3. `rojo sourcemap default.project.json -o sourcemap.json`
  4. `luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --defs=.luau-lsp/globalTypes.d.luau --ignore "src/server/Vendor/**" src`
- **Tests in Studio:** start and stop play with the MCP, and drive the client with `execute_luau` (Client datamodel), e.g. teleporting the character or firing remotes. `tests/TargetingCheck.luau` can be fetched and run with `loadstring` in the Edit datamodel.
- **Studio-only `DevCommand` (command, value):**
  - `setStrength`, `setSpeed`, `setForestsCompleted`
  - `grantPass <multiplier>`
  - `setCarried`
  - `fillOpenRow <plots to leave empty>`, `fillSection <plots to leave empty>`, `fillAll <plots to leave empty>` (M6)
  - `extendBreak`, `endAwakening` (M6)
  - **Easier: the Studio test panel** at the bottom right in play mode (collapsed; click "Test panel +") has buttons for most of these (M6)
  - `setCoins`, `setBulkPickupLevel`, `setBulkPlantLevel`, `setPlantingRangeLevel` (M7; `setBulkPlant` was removed)
  - `fillForest <fraction of the bar>` (M5)
  - GUI pass:
    - `grantStrengthBoost <multiplier>` and `grantSpeedBoost <multiplier>` (sets the saved boost and forgets the old boost passes; 1 = none)
    - `buyStrengthBoost <step>` and `buySpeedBoost <step>` (a fake receipt for that boost product, 1 = first)
    - fake receipts through the real handler: `buyBar <1-4>`, `buyServerBoost`, `buyBulkPickup <level>`, `buyBulkPlant <level>`, `buyPlantingRange <level>`
    - `resendReceipt` (sends the last fake receipt again, to check it isn't granted twice)
    - `setFriendBoost <percent>`
  - `clearStationPasses`: forget your station passes for the session, so the locks show (2026-10-07)

## Art pipeline (M6b)

1. Edit `tools/blender/build_assets.py` and run it in Blender through the Blender connection: `exec(open(path).read(), g); g["build_all"]()`.
2. Export with `export_fbx(path, only=(prefixes...))` to `assets/fbx/`.
3. Upload the FBX as a Model with Open Cloud: `POST https://apis.roblox.com/assets/v1/assets` (multipart `request` + `fileContent`, type `model/fbx`), then poll `assets/v1/operations/<id>`.
4. In Studio (Edit), `InsertService:LoadAsset(id)`, rename it `Import_<id>` and parent it to ServerStorage.
5. Run `tools/build_map.luau` (was `build_lobby.luau`; serve the repo with `python -m http.server 34877 --bind 127.0.0.1 --directory <repo>` and `loadstring` it from `HttpService:GetAsync` in Edit). It moves the meshes into `ReplicatedStorage.Assets`, colors them and rebuilds the lobby, the island, waterfalls, floating islands, clouds, Lighting and the plaza decorations.

**Keep every mesh under 2048 studs.** If one is bigger, Roblox shrinks the whole FBX to fit, so everything in it imports too small (this happened in M11: the far cloud ring shrank the island and tiles to 0.78). Split big meshes, and upload very wide decor as its own FBX.

Blender +X becomes Roblox −X in the imports, so the script turns things with `toward(angle)`.

## Gotchas learned the hard way

- **StreamingEnabled:** client code must never keep references to map parts. Parts get unloaded and come back as new objects (this broke the bench bar and prompt once). Keep the model and look parts up again.
- **Testing:**
  - **Server position lag:** right after a client teleports the character, the server still has the old position for a moment, so the first prompt press or plant can be refused. Real players walk, so this isn't a game bug.
  - **Don't anchor the character on the client during tests:** its position then stops reaching the server.
  - **Simulated input:** `ContextActionService:CallFunction` isn't allowed from the MCP, but the MCP's `user_mouse_input` and `user_keyboard_input` send real clicks and key presses to the Client, so the plant input can be tested for real.
  - **Screenshots:** Studio's screen capture leaves out `AlwaysOnTop` billboards (the meter and the arrow marker). At automatic graphics quality, small parts far from the camera aren't drawn, so an overview shot looks like an empty green island. Set `settings().Rendering.QualityLevel = Enum.QualityLevel.Level21` on the Client first, and put it back to `Automatic` afterwards.
  - **Particles in screenshots:** Roblox pauses emitters far from the camera, and the screen capture jumps the camera there instantly. Teleport the character next to what you're shooting and wait a couple of seconds first.
  - **Studio ids change on reconnect:** if the MCP says the `studio_id` isn't connected, call `list_roblox_studios` and use the new id; the place keeps its state.
  - **The user may be playing in Studio while tests run.** That moves the character and plants seeds. If results look odd, check for movement input (`Humanoid.MoveDirection`) and measure specific plots from a `GetForest` snapshot, not totals.
- **Avatar joints are AnimationConstraints** (Roblox's newer avatar joints), not Motor6Ds. Both take a `Transform`. TrainingController poses benching players by setting it every `Stepped`, after the Animator, which replaces the sit animation without an uploaded animation asset.
- **Luau typing:** strict typing sometimes needs explicit annotations on unions of string literals, e.g. `local stat: DataService.StatKey? = ...`. Roblox vectors are 32-bit, so round distances before comparing for ties.
- **Editing files with Python on Windows:** open files with `newline=""`, or the line endings turn CRLF and StyLua flags every line. Long Python heredocs in bash can break on quoting; write the script to the scratchpad and run it instead.

## Waiting on the user

- **Save the place in Studio** after every session's changes (the map, assets and scripts live only in the open place until saved).
- **Spreadsheet (`docs/Balancing.xlsx`)** needs these numbers by hand (all are listed in [docs/DESIGN_CHANGES.md](DESIGN_CHANGES.md)):
  - hex size 16
  - hub rings 4 and forest rings 11
  - 540 plots × 44 seeds = target 23,760 (hub rings 6, forest rings 9, after M6)
  - base planting range 30, and the Planting Range upgrade at 0/4/8/12/16/20
  - the forest opening one row at a time (6 sections × 11 rows, outside-in within a section, next row at 100%)
  - training at a rep every 0.25 s, +1 per rep at 1x (4 per second)
  - the 2026-10-07 refits to new pyramid readings:
    - capacity: `1 + 7.57 × ((1 + Strength/17.4)^0.362 − 1)` (105,428 → 171)
    - walk speed: `32 + 13.57 × ((1 + Speed/36.2)^0.32 − 1)`, no ceiling (60,070 → 164)
  - the Awakening at 120 s, the chest at 500 coins and the free gift at 500 coins
  - training tiers 50x, 75x and 100x, unlocked at 25, 50 and 100 forests (passes 699, 899, 1,099 Robux)
- **Not yet verified by a person:**
  - two-player tests: bench visibility and the lying bench pose as another player sees it, seeing each other's circling acorns, planting into the same tree, the "X added seeds" and server boost banners for the other player
  - real Robux purchases (only fake receipts were tested), and the Friend Boost with a real friend
  - the phone layout on a real iPhone (the notch); checked only in Studio's emulator
  - hearing the sounds: the coin plop, the stage bling and the pickup pop were checked by measurement, not by ear
  - jump to leave the bench
  - mobile tap and button
  - gamepad X
- **Later art:** a scrolling belt texture for the treadmills, music, and icons for friends and the server boost (still emoji; set `Image` in `UIStyle.Icons`).
- **Spreadsheet, also:** the 8 tree stages (seeds 1, 3, 6, 10, 16, 24, 33, 44).
- **Unused uploads the user can delete** on the Creator Dashboard: the acorn ring model 135981131411076 (tried and undone).
- **Left alone on purpose:** the user's own `Sequoia2` model and loose parts in Workspace.

## Next: planning M12 (performance pass)

From [docs/MVP_PLAN.md](MVP_PLAN.md) M12: a full forest of 540 trees and their tiles on a test server with StreamingEnabled, phone memory and frame rate, and many players.

**Starting point:**
- **The M11 measurements:** with a full forest and the break, Studio ran at 15 fps at maximum graphics quality. At automatic quality it ran at 60 from the spawn and 28 from above, with 3,683 parts.
- **Added since, worth measuring:**
  - about 30 particle emitters and 4 point lights on the tier pads
  - 3 light-column beams
  - the per-frame bench pose loop (only for occupied benches)
  - the acorn orbit: one RenderStepped `BulkMoveTo` over every visible acorn, within 150 studs; each acorn is 2 parts
  - 8 tree stages: twice as many model swaps per forest (measured 60 fps at automatic quality with 539 full trees)
  - the GUI: coin bursts (up to 18 frames), stat popups (up to 14), rolling numbers
  - walk speed has no ceiling now (200+ for strong players), so StreamingEnabled has to keep up with fast movement

The user asked not to worry about performance until M12.

Postponed: weather (M9), quests (M10), the starter's name label (M5), the 2x coins boost (M6), the pyramid shop's two "characters" (quicker pickup and place), and hold-to-repeat or a slider for the walk speed setting.

Tried and undone: one continuous ring of acorns around the garden instead of six piles (2026-10-07, the user changed their mind).

## Ancient Spring multiplies your best station (2026-10-07)

Per the user: standing in the Spring now pays, for Strength and Speed each, `RepAmount × your best unlocked station × the spring multiplier` per rep (then × boost passes and the server boost as before). Best unlocked = the highest station unlocked by forests or a station pass (`bestUnlocked` in TrainingService). Before, it was just `RepAmount × spring`, which a 2x Spring made worse than the second station. Verified in a playtest: 11 forests (10x best), passes cleared, 2x Spring → 320 Strength in 4 s (4 reps/s × 10 × 2).

## Park Ranger and Lord of the Forest are real models now (2026-10-07)

The two character NPCs used to be built by OutfitService at server start. They're now models in `Workspace.Map` ("Park Ranger", "Lord of the Forest"), tagged `CharacterNpc` (with an `Outfit` attribute: Ranger / Lord) and `IdleNpc`, so the user can dress them in Studio like the Shopkeeper. `tools/build_map.luau` makes them only when missing (reruns keep the user's edits). At runtime OutfitService only adds the pass prompt, the name label and the `Assets.Outfits.<Outfit>Preview` copy (taken from the dressed model, so the shop cards show the user's look). Pass owners still wear just the accessories in `Assets.Outfits.Ranger` / `Lord`. Verified in a playtest: both prompts sell the right pass, labels, idle animation, both previews.

### Ranger catalog look and display stands (2026-10-07)

- The Park Ranger NPC wears the user's catalog picks: Park Ranger shirt 6360872845, pants 6360874352, Park Ranger Hat 12309127610 (replaces the modeled RangerHat), and the dynamic head "Shedletsky's Slightly Annoyed Face" (head 72457329282324, mood 14618207727). Badge and backpack stay.
- Ranger pass owners get the same shirt, pants and hat: they're in `Assets.Outfits.Ranger` (tools/build_outfits.luau loads them from the catalog via its CATALOG table). OutfitService moves the player's own shirt/pants into a `OwnClothes` folder in the character while an outfit's clothing is worn, and puts them back when the outfit changes (verified: none → Ranger → Lord → none gives back the player's own clothes).
- Both NPCs stand on a round slate platform with a neon rim in their label color (`Lobby.<Outfit>Stand` / `StandRim`, rebuilt by build_map every run).
- Lord of the Forest is all catalog now (user's picks): Druidic Helmet 112264404673495, Royal Knight Cape Forest Guardian 78153442307246, Green Anime Cloak 14458613654 (layered jacket). The modeled crown, cape and shoulders (and the crown's sparkles) were removed from `Assets.Outfits.Lord` and from tools/build_outfits.luau. The NPC was rebuilt from a HumanoidDescription so the layered cloak wraps the body; owners get the three through OutfitService (verified in a playtest).

## Capacity: square-root tail (2026-10-07)

`GameConfig.capacity` is now the bigger of the old curve and `Stats.Capacity.Sqrt (0.4725) × √Strength`, matching three high Build the Pyramid readings (120.82M → 5,200, 567.83M → 11,252, 12.841B → 53,439). Unchanged below about 400K Strength; 1M → 472 (was 393), 10M → 1,494 (was 914). Balancing.xlsx needs the same change. Details: [docs/plans/TuningSignals.md](plans/TuningSignals.md).

## 200 acorns per tree (2026-10-07)

- **The change:** `Tiers[].SeedsPerHex` 100 → 200 in all three worlds, so the forest target is 108,000. Growth stages start at seeds 1, 10, 24, 42, 70, 106, 148 and 200.
- **Why:** the user corrected the pace: a busy Build the Pyramid server (~70 players, whales and new players) finishes its 171,000 in 5–6 min, about 400 blocks a minute per player (the old "30 min" came from a smaller clip server). At that per-player pace a full 50-player server of ours takes about 5.3 min at 200 (about 2.7 at 100).
- **Not changed:** the Forest Bar seed products (+500/1,000/2,000/5,000) are now half the share of a forest they were; the forest credit stays at 50 acorns.
- **Watch:** small servers take twice as long per forest as before. Forest length analytics (not built yet) would show it.
- **For the spreadsheet:** 200 seeds per hex, target 108,000.

## Labels above the buildings; AFK players get forest credit (2026-10-07)

- **SEEDS labels** float 3 studs above each dispenser's top, centered on its tower (the model's pivot; the bounding box is pulled off-center by the basket and slide). **UPGRADES sign** floats centered 4 studs above the ranger station's roof (`SIGN_LOCAL` 0.7, 18.5, 0). Both in tools/build_map.luau and applied in Studio.
- **Forest credit for everyone:** `Stats.ForestCreditSeeds` 50 → 0 (the user's call: AFK players still help retention). Everyone in the server when a forest completes gets the 500 coins and +1 forest. The HUD credit line and the "plant 50 next time" message never show now; the ForestLoop funnel's Planted50 step no longer fires (later steps back-fill it). The test panel's two forest-credit buttons were removed. Verified in a playtest: 0 acorns planted → forests 11 → 12 and 500 coins.

## UI and sound tweaks (2026-10-07, late)

- **Free gift button:** just the coin icon and "+500" (was "🎁 Favorite: 500 coins"); pressing it still opens Roblox's favorite prompt.
- **Forest Bar packs doubled with the forest:** +1,000 / +2,000 / +4,000 / +10,000 at the same 49 / 89 / 159 / 349 Robux (`GameConfig.BarBoosts`); the four products were renamed on Roblox ("+1,000 Forest seeds" …, descriptions no longer mention forest credit).
- **Speed limit:** Settings has a box to type a speed (between −/+ and MAX); a bad entry goes back to the current value, anything at or over your own speed means no limit. The row is titled "Speed limit" now so the controls fit.
- **Less rounded GUIs:** `UIStyle.corner` scales every radius by `ROUNDNESS` (0.5). The target meter's corner goes through it too.
- **Sounds:** `Gain` (10066931761) on each training "+N" popup, `StatUp` (76834925120308) when capacity or walk speed goes up; level-up sparkles and ring on your character (HUD `levelUpEffect`). The default text drop shadow is 0.1 of the text size (was 0.14).
- **Friend Boost icon:** image 15403044988 (Creator Store decal 15403045010).
- **Training click like Build the Pyramid's** (btp3 clip: one identical click per rep, every ~0.27 s, nothing else): the HUD now plays `Gain` once per `Stats.RepSeconds` while you're benching, running or in the Spring, timed on the client instead of on each stat update (which arrive unevenly). The StatUp level-up sound is no longer played (the sparkles and ring stay). Verified: clicks 0.25 s apart (0.23–0.27).
- **Forest Bar at the very top** on desktop: moved up by `GuiService.TopbarInset.Height`, into Roblox's top-bar row (verified: 6 px from the screen top). Phones keep it at the bottom.
- **Save / load / reset stats** buttons in the Studio test panel (DevService `saveSnapshot` / `loadSnapshot` in the `DevSnapshots_Studio` DataStore, `resetProfile`).
- **The user moved the ranger station** ~30 studs in Studio. The ShopZone was moved into its ring and now lives inside the RangerStation model (build_map parents it there too). Note: rerunning build_map puts the station back at SHOP_ANGLE/SHOP_R unless those are updated.
- **Training pop matched to the btp3 clip (measured):** `Gain` is "bubble-pop-06" 121434237134952 at volume 0.35, pitch 1 (its average pitch is 727 Hz vs the clip's 722, ~40 ms loud like the clip's). It plays with each "+N" popup (one per rep; the Spring's two stats pop once). `Stats.RepSeconds` 0.25 → 0.266 (the clip's pace: training is ~6% slower than before) and `TrainingCheckSeconds` 0.05 → 1/60 so reps land evenly. Verified: 19 pops in 5 s, average 0.266 s apart (0.25–0.28; the clip 0.24–0.28). Balancing.xlsx: rep 0.266 s.
- **Character display signs** (after Build the Pyramid's Pharaoh stand): new client `CharacterDisplayController` puts a sign over each CharacterNpc: the live Robux price (green), the name in big letters in the stand's color, and "Nx Quick Pickup · Nx Quick Plant", plus colored sparkles rising around the NPC. OutfitService's old plain name label was removed. Note: in a Studio playtest GetProductInfo reported 90 / 720 for the 99 / 799 passes (Roblox's default prices are 99 / 799); the sign shows whatever Roblox returns for that player, the same as the purchase prompt.
- **Free gift:** the timed favorite popup (90 s into a visit) was removed (`Tutorial.GiftPopupSeconds` deleted). The favorite prompt only opens from the +500 button or the lobby gift board's ring.
- **TopbarPlus v3** (the user imported it): moved to `ReplicatedStorage.Icon` (Studio-only package, not in src/; its READ_ME example script and folder in Workspace were deleted). Settings (the user's settings image, caption "Settings") and Codes (label "Codes") are now TopbarPlus buttons on the left of Roblox's top bar, next to the chat button (HUD `topbarButton`, one-click buttons that toggle the panels); the old Settings/Codes row under the boost buttons is gone. TopbarPlus ships no icons of its own beyond its example images.
- **Codes hidden** (no codes yet): HUD `SHOW_CODES = false`; set it true to bring the top-bar button back. **Friend Boost** reads just "0%" / "+20%" by the friends icon.
- **Text shadows** have no outline of their own now (UIStyle.dropShadow): the shadow is the letters' own size, 0.1 of the text size lower. The Forest Bar number's special thinner offset was removed. The map's signs (baked by build_map) keep the old look until build_map is rerun.
- **Nameplates like Build the Pyramid's:** the forest icon with the player's forest count on it on top, then the rank (32 px, its color) and the name (30 px, white, outlined); was rank 26 / name 20. The plate grows up from 2.4 studs over the head (SizeOffset 0, 0.5).

## Break time and world picks under the Forest Bar (2026-10-07)

Like Build the Pyramid's: during the break the four seed buttons under the Forest Bar become **+1 / +5 / +10 / +50 MIN** of break time for everyone (45 / 117 / 225 / 630 Robux, `Awakening.BreakTime`; no cap any more), and a **"PICK!"** button (the forest icon) switches them to the three worlds (`Awakening.WorldPicks`, 99 Robux each): buying one makes it the next forest for everyone (the roulette lands on it; the last pick wins; the countdown shows "Next forest in 7:06: Great Smoky Mountains"). Banners: "X added 5 minutes to the break!", "X picked Kyoto Forest for the next forest!".
- **Products:** the old escalating +1:00 extensions 3716952621/635/636/641 were renamed and repriced to "+1/+5/+10/+50 MIN break"; 3716952644 and 3716952647 are off sale. New: Pick Sherwood Forest 3717157966, Pick Kyoto Forest 3717157968, Pick Great Smoky Mountains 3717157970.
- **Server:** `AwakeningService.extend(player, minutes)` (time bought outside a break is kept for the next one) and `pickWorld(player, tier)` (ForestState PickedTier/PickedBy/Picks; `finish()` uses the pick, then clears it). ProductService maps the products; DevService `extendBreak` (value = minutes) and `pickWorld` (value = tier); test panel buttons "Extend break +1 min" and "Pick Kyoto Forest". `ExtendSeconds`, `MaxBreakSeconds`, `ExtendProductIds` and the AwakeningCapAt attribute are gone.
- Seed buttons are hidden during the break, which also closes the MonetizationAudit finding about seeds bought while the forest is full.
- Verified in a playtest: seed buttons before the break; time buttons and PICK during it; +5 min added 300 s; a pick of world 3 made the roulette's NextTier 3 and was cleared after.
- **Forest icon** is now the user's "forest-icon" 82377814437587 (HUD, nameplate badge, PICK! button).
- **Break cap 30 minutes** (`Awakening.MaxBreakMinutes`; Build the Pyramid's is 60): a time button turns grey (and shakes if pressed) when it wouldn't fit; time that doesn't fit after a purchase is kept for the next break (also capped). The countdown shows "(3/30 MIN)". The +50 MIN pack became **+20 MIN at 399 Robux** (product 3716952641 renamed and repriced). Packs now 1/5/10/20 at 45/117/225/399.
- **Bigger upgrade shop with blur:** the upgrade shop opens 25% bigger on desktop (`GROW`, `UIStyle.autoScale(target, grow)`), and it, the Robux shop and Settings blur the game behind them (`UIStyle.blurBehind`, one shared BlurEffect in Lighting on the client).
- **Upgrade Robux levels 6+** (pending Studio sync when written): 19 new products, every level now buyable with Robux: 9, 19, 39, 79, 149, then 239, 379, 599, 949, 1,499, 2,399, 3,799 (Range stops at 10). The upgrade shop's "Step out of the ring to close." line is gone (the line only shows short messages now).
- **Tutorial trains Speed too:** a new step 4 "Run on the treadmill to walk faster (x/20)" (`Tutorial.TrainedSpeed`), after "Lift weights to carry more (x/20)". Steps are now 7, DoneStep 8; a player saved at the old 7 lands on the Shop step, which finishes at once if they own an upgrade. The Tutorial funnel's step numbers shifted by one from step 4 on.
- **Training pads' "Requirements:" icon:** the baked map signs still had the old forest image; swap 137125846833438 → 82377814437587 on them (done by a one-off in Studio; build_map already uses UIStyle.Icons.Forests).
- **Training tip after the tutorial:** planting `Tutorial.RemindTrips` (4) loads in a row without gaining Strength or Speed shows "Tip: train to carry more and walk faster" for 12 s, with the guide arrow to the best station unlocked by forests (TierPad floors), at most once every 5 minutes; training clears it (TutorialController `trainingTip`). Verified: hidden after 3 loads, shown after 4, gone once Strength went up.
- **Menu vignette:** every window that blurs (upgrade/seed shop, Robux shop, Settings, Codes) also darkens the screen's edges: `UIStyle.blurBehind` adds a full-screen "Vignette" ImageLabel (image 72780894519383, from `tools/make_particle_textures.py vignette`, decal 80633964834719) behind the window, fading in over 0.2 s and reaching under the top bar. Verified on the upgrade shop: full screen (1590×793 from the very top), blur 16.
- **Vignette redone with gradients** (the image version didn't show for the user): four black edge frames fading inward (`VIGNETTE_DEPTH` 0.32 of the screen, `VIGNETTE_EDGE` 0.25 transparency at the border), corners darkest. The vignette image/decal is no longer used.
- **Window border black:** `UIStyle.panel` edge is 5 px black (was 4 px gold), for every window.
- **Character signs shrink with distance:** sized in studs (7 wide, 2 over the head) with the pixel layout scaled to fit (`CharacterDisplayController`); verified 264 px wide at 15 studs, 79 px at 50.
- **Lobby sign bands (the user's "vignette"):** what the user meant was a dark strip behind sign text, fading out at both ends (like Build the Pyramid's stat rows). `UIStyle.band(gui)` adds it; build_map calls it on every lobby sign (UPGRADES, the SEEDS labels, the training pads, FREE GIFT, the seed stall) and the 18 placed signs got one in Studio. The screen-edge vignette from earlier was removed (blur kept); its image and tool function are gone.
- **Textured tile dirt:** the hex slab uses Roblox's Ground material (ForestController `SLAB_MATERIAL`, set on the client's slab template), with lighter colors to make up for the texture: open 205,150,98 and moss 140,215,95 (were 150,103,64 and 104,168,68). The user picked it from five test tiles (smooth, Ground, Sand, Mud, light Ground).
- **Sign bands lighter:** `BAND_DARKEST` 0.75 (the 18 placed bands updated in Studio). Studio's screen capture works again in Edit mode (useful for visual checks; Play mode still doesn't render).
- **Level-up effect, bigger:** when capacity or walk speed goes up, the StatUp sound (76834925120308) plays again, with the sparkles and ring plus a rising light pillar, a flash of light and the new value floating up over the head ("Capacity 254!" / "Walk Speed 290!") in the stat's color. At most once every 0.9 s (`LEVEL_UP_GAP`). Verified: 5 level-ups in 5 s of Spring training, each with sound, pillar and text. The per-rep training pop is unchanged.
- **Level-up: no floating text;** instead the HUD's "Capacity: x/y" or "Walk Speed: n" line pops to 1.3x and settles back (`LEVEL_UP_POP`). The sound, sparkles, ring, pillar and flash stay.
- **Character prompts** just say "E  Buy" (ObjectText empty, ActionText "Buy"); the sign above shows the details.
- **HUD line pops, smoother:** each of Capacity and Walk Speed pops on its own (HUD `popLine`, not tied to the effect's 0.9 s limit): grows to 1.25 over 0.12 s, eases back over 0.22 s, and a pop still playing isn't restarted. Verified in the Spring: both lines peaked at 1.25 with a smooth ramp up and down.
- **Only the number pops:** statRow's small line is two labels, "Words" ("Capacity: ") and "Value" ("0/989"), set with `setSub`; the level-up pop is on the Value label. Verified: "Capacity: [0/1,263]" and "Walk Speed: [40 (max 257)]", and only the values popped.
- **E prompt padding:** the custom prompt panel's side padding is 22 left / 40 right (was 10 / 24).
- **Build the Pyramid window look:** cards are tan with a lighter middle (`UIStyle.glow`, CARD_EDGE 112,82,48 → CARD_MIDDLE 200,160,102) and a 4 px black edge; windows are dark brown-grey with a lighter middle (PANEL_EDGE → PANEL_MIDDLE); buttons have a brighter top band (3-stop `UIStyle.gradient`). Settings rows and seed-bag slots use the card glow; the Robux shop's boost card uses a purple glow. Previewed in Studio (StarterGui preview, removed).
- **Pick-up prompt pulse:** the "Pick Up Seeds" prompt's background pulses from dark into a yellow-orange gradient and back (1.2 s each way; PromptController `PULSE_*`).
- **Shop trigger = the blue ring:** the ShopZone now covers the ranger station's whole glowing ring (30 studs, centered on RangerStation_Glow) instead of a 13-stud circle at its front edge; build_map sizes it from the Glow part and places the NPC stands from the old front spot.
- **Upgrade shop 40% bigger** on desktop (`GROW` 1.4).
- **Pick-up reach from any side:** the dispenser prompt sits on a "PromptSpot" attachment in the tower's middle (was on the basket, on one side) and shows within `Planting.RackPromptStuds` 18; the server's `RackRangeStuds` is 22 from the rack's middle. Note: Roblox only shows a prompt that's in front of the camera, so a test with a misplaced camera can look like a miss. build_map makes the spot too.
- **Mobile Plant button:** placed just left of the jump button (CarryController `placeButton`, measured from TouchGui.JumpButton; re-placed when the screen turns). Not tested on a touch device.
- **Shop window centered** on the whole screen (Shop ScreenInsets None, holder at 0.5): verified its middle is the screen's middle.
- **Robux shop boost cards** show only the next tier ("2x"), or "128x (max)" when everything's owned (no ladder).
- **Right column like Build the Pyramid's:** SHOP and the boost labels overlap the bottom of their icons (`ICON_OVERLAP` -18), 26 px between the three; a maxed boost shows no price tag (and pressing it does nothing). Checked with play-mode screenshots: Studio's screen capture works in Play mode now too.
- **Row arrow:** a giant chevron (the guide arrow's white, black-outlined image, cropped and flipped to point down) floats 36 studs over the middle of the open row's unfinished plots, 32 studs wide, bobbing 5 studs (TargetController `buildRowArrow`, a client-side "RowArrow" part). It follows the unfinished plots as the row fills, and hides during the break or when nothing is open. Seen clearly from 210 studs away in a playtest screenshot.
- **Row arrow follows the trip loop:** in the lobby it marks the open strip; once you're in the forest (past HUB_RADIUS 160) it moves 46 studs over your nearest acorn dispenser; within 24 studs of a dispenser it's hidden and goes back to marking the strip for the next trip (TargetController `toDispenser`). Verified the whole loop: lobby → strip, forest → dispenser, back in the lobby → still the dispenser, at the dispenser → hidden, lobby again → strip.
- **One tap = one plant/grab:** with a Hands pass the hold repeat is 0.05 s, shorter than a normal tap, so a tap planted (or grabbed) twice. Holding now waits `Planting.HoldDelaySeconds` (0.25) before repeating, then runs at the usual pace (CarryController plant loop, CarryService grab loop). Verified with simulated keys and the 3x pass: a 100 ms tap planted 1, a 700 ms hold planted 10.
- **Row arrow removed** (the user's call: the guide arrow already shows the way). **Lord of the Forest is 5x** (was 3x): `HandsPasses[2].Multiplier` 5, its pitch and the pass description on Roblox updated.
- **Hex dirt back to smooth** (SmoothPlastic, the original colors); the Ground texture was dropped.

## Whole rings instead of sections (2026-10-07)

The open row is now a whole ring (the user's call after weighing it: everyone can work the part nearest their dispenser, no crowding on one strip, like Build the Pyramid's layers). ForestService builds one row per ring, outside-in (9 rings: 84 plots in ring 15 down to 36 in ring 7); OpenRow is (0, ring), (0, 0) when complete; new ForestState RingCount. Client: `isOpenPlot` is by ring; the row and section moments became one ring moment (a 2 s wave around the ring, rising chime, Ancient Tree shake, bar pulse, "Ring 3 of 9 complete!"); the Forest Bar shows "Ring 3/9" at its left. Removed: StartSide, the section order, `devFillSection` / the "Fill section" test button ("Fill row" is now "Fill ring"). Verified: 84 open tiles at the start, the counter 1/9 → 2/9 → 3/9 as rings were filled, and the banner on screen.
- **Ring ticks instead of "Ring 3/9":** ForestState `RingMarks` ("0.1556,0.3000,...", where each ring ends as a fraction of the forest; the outer rings are bigger, so the marks get closer together) and the HUD draws a thin dark tick at each in the Forest Bar.
- **Even ring ticks, white:** the Forest Bar gives every ring an equal ninth (HUD `barShare`: the fill within a ring's share is how far along that ring is, from RingMarks), so the 8 white ticks sit at even 1/9 steps and the fill reaches a tick exactly when its ring completes. The number in the bar still shows the real acorn total. Verified: ticks at 0.111 … 0.889; with 2 rings done and most of the 3rd, the fill was 0.302.
- **Ticks evenly thick:** each tick is placed on whole screen pixels and sized/positioned as a *fraction* of the bar (Roblox rounds pixel offsets to whole numbers, so scaled offsets came out 2 or 3 px wide). Redrawn when the bar's size or place changes (a 0.5 s check). Verified: all 8 ticks exactly 3 px wide on whole pixels, gaps 56–57 px.
- **Hide UI button:** a TopbarPlus toggle next to Settings ("Hide UI" / "Show UI"). The HUD's side parts (stats, SHOP and boosts, Friend Boost, the break countdown) now live in one full-screen "Side" frame that it hides; the Forest Bar and its buttons, the top bar and the +500 gift stay. Verified by clicking it in a playtest (screenshot), and clicking again brought the side back.
- **Lord of the Forest saved for later:** `GameConfig.Features.LordOfTheForest = false` with `HandsPass.Feature`; `GameConfig.availableHandsPasses()` drives the Robux shop's character cards and the NPC signs, and OutfitService moves a switched-off character's NPC and stand to ServerStorage at start. Pass 2014682392 is **off sale** on Roblox (put it back on sale when releasing). Owners keep the 5x speed. Verified: no Lord NPC/stand, the shop shows only Park Ranger.
- **Hide UI hides the Forest Bar too** (the "Top" group with its buttons); only the top-bar buttons stay.
- **Free gift board: E prompt, no ring.** The pink ring (GiftBoard_Glow) and the GiftZone trigger are gone; the gift box has a "Claim Free Gift" ProximityPrompt (tag GiftPrompt, 12 studs). TutorialController opens Roblox's Favorite prompt on PromptTriggered and hides the prompt once FreeGiftClaimed is 1. build_map does the same. Verified: the prompt shows at 6 studs from the box. (Studio's screen capture leaves out AlwaysOnTop billboards, so the custom E prompts don't appear in captures; the bench prompt doesn't either.)
- **Lord of the Forest avatar** moved out of Workspace.Map into ServerStorage.SavedForLater (its stands were already gone). Put it back in Workspace.Map when releasing the character.
- **Free gift claim:** once claimed (FreeGiftClaimed 1) the +500 button and the gift prompt hide (verified with a simulated claim: button and prompt gone, +500 coins; stats restored after). The GetFavorite "already favorited" shortcut was removed (it needs inventory access permission, so it always failed). Favoriting cannot complete in Studio, so a real claim only happens in the live game.
- **Lobby paving stones textured:** the plaza and walkway pavers (palette Paver / PaverDark) use the Slate material (was SmoothPlastic), in Studio and build_map. Compared with Limestone and Pavement, which looked almost smooth.
- **Pavers now Ground** (the user picked it over Slate).
- **Sign bands taller:** `BAND_HEIGHT` 1.6 of the sign, centered (was the sign's own height), so there's room above and below the text; the 18 placed bands updated in Studio.

## Sherwood back to 100 acorns per tree (2026-10-08)

The first world (Sherwood, 60% of the roulette) is 100 per tree, target 54,000 (the user's call: an easier number for first-time players); Kyoto and the Smoky Mountains stay at 200 (108,000). The server publishes ForestState `SeedsPerHex`; ForestController recomputes its growth-stage seed ranges and TargetController's "12 / 100" meter reads it, so worlds can differ. The Forest Bar packs stay +1,000/2,000/4,000/10,000 (in Sherwood each is twice the share of a forest). Note for tuning: Sherwood forests take half as long, so forest-count unlocks come faster. Verified: Sherwood 100 per tree, target 54,000, bar "0 / 54,000", meter "0 / 100"; after `setTier 2` Kyoto 200 per tree, 108,000. Balancing.xlsx: Sherwood 100 per hex.
- **Calmer coin bursts:** no "+N" text over the coins; 2–5 coins per handful (was 6–18; `math.floor(sqrt(amount)/2)+1`); gains within 0.8 s fly as one handful (was 0.3). Verified holding E for 3 s with the 5x pass: 160 acorns planted, 15 coins flew (at most 8 on screen at once), no "+N".
- **Ring hint:** under the Forest Bar, "Grow every tree in the glowing ring: 54 / 84" (ForestState RingDone / RingTrees, set by ForestService in flush), hidden during the break; the ring banner adds "Next: the glowing ring". Verified on screen after filling 54 of the first ring's 84 trees.
- **Textured fence:** the lobby fence's rails use Wood and its pillars Slate. Roblox materials need mesh UVs to tile on upright faces, and no Blender asset had any, so `build_assets.py` gained `box_uv(obj, tile)` (box-projected UVs, one repeat per 6 studs), applied to LobbyFence_Wood and _Stone. The fence was re-exported (assets/fbx/lobby_fence_uv.fbx), uploaded as model 90509647607592, and its meshes were swapped into the placed fence and the Assets.Lobby template in Studio (positions kept; no map rebuild). build_map's `TEXTURED` table sets the two materials. Other assets can get textures the same way (add box_uv, re-export, swap).

- **Dispenser roof removed (2026-10-08).** acorn_dispenser in build_assets.py no longer makes the roof, roof posts, lamp pole or lamp. New model 105572996912233: only AcornDispenser_Logs was swapped (ApplyMesh, then Size set to 11.73 x 16.53 x 9.41 and lowered to keep its base), and the Roof/Lamp parts were deleted on the 6 racks and the Assets template. Garden stone textured (Slate, model 93819814489898).

- **Level-up effect removed (2026-10-08).** The sparkles, ring, light pillar and flash on your character are gone; a level-up still plays StatUp and pops the HUD line (HUD levelUpEffect).
- **Speed limit slider (2026-10-08).** Settings > Speed limit is a slider (base walk speed to your own; the right end = no limit) plus the type-in box; the - / + / MAX buttons and GameConfig.WalkCap.Step are gone. It sends SetWalkCap once, on release.

- **Ring trunk (2026-10-08).** The "Grow every tree in the glowing ring: x / y" line is replaced by a tree-trunk cross-section right of the Forest Bar (HUD RingTrunk): one ring per forest ring, outer = first; finished rings green, the open ring glows and fills clockwise (RingDone / RingTrees, two clipped half-discs with turning UIGradients), the middle shows the trees left. No background, a black edge on the outer ring. Hidden in the break.
- Ring trunk middle: the open ring's progress in percent (rounded down), not the trees left (2026-10-08).
- **Bigger carried acorns (2026-10-08).** AcornOrbit gets two more tiers: colossal (256 seeds, 28 studs, ring 16 out / 36 up) and titanic (1,024, 60 studs, ring 30 out / 80 up); silly on purpose. Up to 3 titanic show.
- **Acorn stack (2026-10-08, replaces the circling acorns and the colossal/titanic tiers).** One acorn over the head grows with the seeds (GameConfig.AcornStack: 1.6 studs at 1 seed to 24 at PerAcorn 500, cube-root growth); a full one stays and the next grows on top, with a puff; at most MaxStack 10. CarryController eases sizes, spins and sways the stack. Check: tests/AcornStackCheck.luau (Edit mode, require a Clone of GameConfig). AcornOrbit and acornCounts are gone.
- **Bench press tempo (2026-10-08).** TrainingController PRESS_MIN/PER_DECADE/MAX 1.5/1.0/10 (was 0.7/0.3/2.5, maxed at 1M Strength): comically fast on purpose, speeding up to about 300M.
- **No footsteps on treadmills (2026-10-08).** FootstepController skips anyone with the Running attribute (it used to step in place).
- **No stat line pop (2026-10-08).** The Capacity / Walk Speed lines no longer grow and shrink on a level-up (popLine and LEVEL_UP_POP removed); the StatUp sound stays.
- **Dispensers all Wood (2026-10-08).** box_uv on every AcornDispenser piece (model 106415501237413), meshes swapped on the 6 racks and the Assets template, Material Wood; build_map TEXTURED lists them.
- **UPGRADES board text (2026-10-08).** build_map adds UpgradesBoard (invisible part over the plank sign at station-local (-6.2, 11.2, 0), 8.5 x 2) with a SurfaceGui on both faces.
- **Dispensers 1.5x (2026-10-08).** build_map scales each SeedRack dispenser by DISPENSER_SCALE 1.5 about its pivot (applied in Studio too, SEEDS labels re-aimed); DispenserController rolls acorns at the rack's GetScale(). Pickup reach unchanged (prompt 18 studs from the tower, server 22 from the pivot; the basket is now ~9 out).
- **Dispenser ring (2026-10-08).** AcornDispenser_Glow: a teal neon ring (Glow look, like the shop's) on the ground around each dispenser, radius 7.33 modeled, centered 1.33 toward the basket (11 studs, 2 out at 1.5x) so it clears the garden wall; model 123416686217503 had it at 8.3 centered, the parts were resized in Studio.
- **Gym in the garden (2026-10-08).** The 8 tier pads (and their TrainingGrove bench + treadmill) moved from the plaza (r 120, angles 70-170) into the root garden: r 66, angles 22.5 + 45k (1x nearest the spawn, offset from the trail entrances). Moved in Studio as rigid groups (not a full build_map run, which would undo hand edits like the moved ranger station); build_map PAD_R / TIERS updated to match. To make room the World Tree draws at FINAL_SCALE 0.6 (AncientTreeController: full grown ~212 tall, roots ~46 out with bloom; AncientBase rune circle scaled too; sapling unchanged via SAPLING_SCALE 0.5), AwakeningController LOOK_HEIGHT 100, GameConfig Awakening.SpringRadiusStuds 72 -> 43 (for the spreadsheet).
- **Forest Bar fill gradient (2026-10-08).** Light green (150,230,110) -> dark forest green (30,110,40) along the fill (was cream to tan, then cream to forest green).
- **World Tree label (2026-10-08).** Rides LABEL_ABOVE (8) over the tree's top at every size (LABEL_MAX_HEIGHT cap removed), 220 x 44 like the UPGRADES sign, MaxDistance 500.
- **SEEDS labels (2026-10-08).** Bottom edge (SizeOffset 0, 0.5) 0.5 studs above the barrel's acorns (max top of AcornDispenser_Wood/Nuts), centered on the tower; build_map and Studio.
- **Nameplates in studs (2026-10-08).** NameplateController: PLATE_STUDS 7.5 wide (the old look at the default zoom), the 320 x 120 layout scaled by a UIScale, so they shrink when zoomed out; MAX_DISTANCE 200.
- **More zoom (2026-10-08).** GameConfig.Camera.MaxZoomStuds 60 -> 150.
- **Drop seeds (2026-10-08).** Q / gamepad Y / tapping the "Drop Seeds" button (CarryController, bottom center under the pick-up prompt) fires DropSeeds; CarryService empties your hands only within GameConfig.Drop.LobbyRadiusStuds 150 of the hub center. The button shows only while you carry seeds in the lobby. The seeds just vanish (no pile is left behind).
- **World Tree label band (2026-10-08).** UIStyle.band behind the label, like SEEDS / UPGRADES.
- **Glow rings (2026-10-08, like BTP's).** GlowRingController draws every GlowRing-tagged part (RangerStation_Glow, AcornDispenser_Glow; build_map tags them, templates stay untagged) as a soft ring texture (glow_ring, tools/make_particle_textures.py, decal 89571232641592 / image 139917524501692) on a SurfaceGui in the part's color, spinning 18 deg/s, with 12 sparkle emitters rising around the band; the neon mesh is hidden locally. Only rings within 220 studs of the camera spin and emit.
- **Forest Bar ticks removed (2026-10-08, the user's call).** HUD drawTicks/barShare/ringEnds gone; the fill is plain Seeds / Target again. ForestService no longer sets RingMarks.
- **Glow ring wall (2026-10-08, like BTP's clip).** GlowRingController adds a 2.2-stud glowing wall on each ring: 4 quarter-circle Beams (FaceCamera off, attachments X along the ring for the Bezier handles, Y down = WALL_FLIP so the texture's bright edge is at the foot), texture glow_wall (decal 103636328548536 / image 111090819332847, saved turned 90 deg because a Beam runs an image's height along its length), TextureSpeed 0.35. The rising wisps use the streak texture (decal 139417367427250 / image 93866342930684), VelocityParallel. Unused uploads: glow_wall unturned decal 135173296937836.
- **Glow ring particles removed (2026-10-08, the user's call).** GlowRingController is now just the spinning ground glow and the scrolling wall; the streak texture (image 93866342930684) is unused.
- **Forest report analytics (2026-10-08).** Analytics.forestCompleted also logs ForestCompleted (minutes), ForestBoughtSeeds and ForestStatMedian / ForestStatAverage (Stat field: Strength, Speed, Capacity, WalkSpeed, PickupPerPress, PlantPerPress, PlantingRange, HandsSpeed, SeedsPlanted; over the planters), sliced by player-count band and world: 20 events per forest. ForestService.addSeeds calls Analytics.forestBought. Verified in a playtest (all 20 fired, no warnings). How to read it: docs/plans/TuningSignals.md.
- **Layout A/B test and ring/tree analytics (2026-10-08).** GameConfig.Experiments (LayoutTest, OuterFirstShare 0.8): ForestService picks each server's ring order at init (ForestState OutsideIn / Layout); ForestController, HUD (ring numbers, and the trunk counts from its heart for InnerFirst) read it. New events RingCompleted, TreeGap, LeftAt; every forest event carries world + layout. Verified in playtests: both layouts open the right first ring and number correctly, and all events fire without warnings. How to read: docs/plans/TuningSignals.md.
- **Layout test paused (2026-10-08).** OuterFirstShare = 1: every server is outer-first; the framework and the layout tag on events stay. Lower the share to start the test.
- **Forest size follows the server (2026-10-08).** GameConfig.ForestSize (ScaleWithPlayers, MinSeedsPerHex 5) and Tiers[].SeedsPerPlayer (1,500 / 3,000 / 3,000); GameConfig.seedsPerHexFor. ForestService sizes each forest at server start and at reset (sizeForest; setTier too), never mid-forest. Analytics forest report gets SeedsPerTree. Check: tests/ForestSizeCheck.luau (passes). Playtest: solo = 5 per tree, 2,700. For the spreadsheet: the target is no longer fixed.
- **Forest sizing decision (2026-10-08).** Launch with head-count sizing only (no strength weighting, private servers included); what to watch and the mild fix are in docs/plans/TuningSignals.md.
- **Tree-finished chime quieter (2026-10-08).** ForestController FINISH_CHIME_VOLUME 0.2 (the ring chimes keep 0.6).
- **Park Ranger aura and salute (2026-10-08).** HandsPass Aura (Ranger lime 110,255,80): OutfitService addAura puts surface-emitted flames on torso/arms/legs, sparks and a light on the NPC (not on the shop preview). The Ranger's Animation attribute = Salute emote rbxassetid://10714389988 (catalog 3360689775), set in Studio. NPC poses now play on each client (new NpcPoseController, IdleNpc tag); the server-side idle in OutfitService never reached clients and was removed.
- **Ring banner and confetti (2026-10-08).** The ring moment says just "Ring N complete!" and calls HUD.confetti(): 90 colored pieces tumbling down the whole screen in their own ScreenGui (Confetti, DisplayOrder 20), on every client.
- **Drop anywhere (2026-10-08).** DropSeeds no longer checks the lobby (client button and server); GameConfig.Drop.LobbyRadiusStuds removed.
- **Forest Bar border 7 px (2026-10-08, was 5).**
- **Animals removed (2026-10-08, the user's call).** AwakeningController no longer spawns the deer, foxes, bunnies and birds during the break. The models in ReplicatedStorage.Assets.Animals are unused (delete them from the place; build_map's import step and build_assets.py still know them).
- **World label in the top bar (2026-10-08).** "Kyoto Forest · 2x coins" is now a line in HUD.Top (under the bar buttons; above them on phones) instead of its own ScreenGui floating 168 px down; it hides with Hide UI. Assets.Animals deleted from the place. Verified in a playtest with the ring banner and confetti.
- **Ranger greets instead of looping (2026-10-08).** NpcPoseController: every IdleNpc loops the idle; one with an Animation attribute plays it once (Action priority) when the local player comes within 14 studs, again after they go past 22 and return. Verified in a playtest.
- **Ranger aura now lives in the place (2026-10-08).** The 7 AuraFlames emitters (UpperTorso, upper/lower arms, upper legs), AuraSparks and AuraLight (both on UpperTorso) are real instances in Workspace.Map["Park Ranger"], editable in Studio; OutfitService no longer creates them and HandsPass.Aura is gone.
- **Glow rings built into the place (2026-10-08).** New Shared/GlowRing.build(mesh): hides the neon ring mesh and adds a sibling GlowRingFx part (tag GlowRing) with Ground (SurfaceGui) > Glow (ImageLabel) and 4 Wall beams; visible and editable in Edit. build_map calls it for RangerStation_Glow and each AcornDispenser_Glow (after the 1.5x scale). GlowRingController only spins Ground.Glow near the camera. Built on the 7 rings in Studio and verified in a playtest (7 effects, spinning, no duplicates).
- **New music, equalized (2026-10-08).** MusicController plays the user's 4 picks (Ethereal Forest Pt. 3, Morning Forest Birds, Forest Explorer's Journey, River Forest Flute; all DistrokidOfficial) from a random start, each at LEVEL / its measured loudness (29.6: volumes 0.19 / 0.17 / 0.16 / 0.39). Measure a new track the same way (PlaybackLoudness at volume 0.1, five spots) and add it with its loudness.
- **Sounds (2026-10-08).** StatUp = 112485797063762 (was 76834925120308); Hover = 119354387183704 (was 139800881181209).
- **Break music (2026-10-08).** MusicController: "Bright Forest" (90928113744956, loudness 198.5) added to the playlist; during the break (AwakeningEndsAt > 0) the playlist pauses and "Happy Adventure" (APM, 9047876673, loudness 213.9) loops (DUCKED under the cutscene fanfare first), then the playlist resumes where it was. Sounds are ForestMusic and BreakMusic in SoundService. Verified in a playtest (client-side break).
- **Forest complete clip (2026-10-08).** Sounds.ForestComplete = "Where Dreams Come True (B)" (APM, 1840544226, 12.4 s, 0.5), played by AwakeningController when the forest finishes (Fanfare stays for the tutorial). The break music waits DUCKED for max(cutscene, 12.4 s) before coming up.
- **Park Ranger water aura (2026-10-08).** From the Toolbox model Workspace.Auras["Water-Aura-01"] (no scripts; 6 flipbook emitters, texture 16664715772): recolored green (40,220,90) and mapped R6 -> R15 as 11 emitters named "Aura" on the Ranger NPC (Head, Upper/LowerTorso, upper/lower arms and legs); the earlier flames and sparks are gone, AuraLight stays. OutfitService wearAura copies every "Aura" emitter from the outfit's NPC onto the same parts of pass owners (tag OutfitAura, refreshed on every dress), so editing the NPC's aura in Studio changes the players' too. Verified in a playtest (11 emitters on a Ranger-outfit player). Note: owners of the Lord pass wear the Lord outfit, which has no aura.
- **Aura outline (2026-10-08).** Each Ranger "Aura" emitter has a sibling "AuraOutline": black, LightEmission 0, 1.3x size, ZOffset 0.5 behind, so the green reads against green. OutfitService copies every emitter named Aura... to pass owners.
- **Ranger aura recolored (2026-10-08).** Aura emitters back to the water aura's blue (21,126,255), AuraOutline white, AuraLight blue. Studio-only change (players copy it from the NPC).
- **Forest Ranger (2026-10-08).** HandsPass renamed Park Ranger -> Forest Ranger (Name, Title; the NPC model is now Workspace.Map["Forest Ranger"]; build_map tracks NPCs by Outfit, so a rebuild keeps it). The pass on Roblox (2014628378) was renamed to Forest Ranger through Open Cloud the same day (description too; still on sale at 99). The character sign has a UIStyle.band behind its three lines. AuraOutline is now light blue (130,205,255) around the blue aura.
- **Spring boost clarity (2026-10-08).** The break popup now says "Stand by the World Tree for a Nx boost!"; the HUD's gold spring line shows the whole break ("Nx boost by the World Tree", or "Nx boost: Strength and Speed" while inside). New gold SpringRing (Map.Lobby, 2 x SpringRadiusStuds across) with a GlowRingFx marked BreakOnly: GlowRingController shows it only while AwakeningEndsAt > 0. build_map makes it too. Verified in a playtest.
- **GUI previews in StarterGui (2026-10-08).** The 9 game ScreenGuis (HUD, Shop, RobuxShop, Settings, Codes, Tutorial, WorldRoulette, DropSeeds, CoinFlow) are copied into StarterGui as "<name> (preview)" (attribute GuiPreview; only HUD enabled) for looking at in Edit; init.client.luau deletes them from PlayerGui, the controllers still build the real GUIs, so editing a preview changes nothing. Refresh: tools/gui_snapshot_capture.luau (client -> server -> DataStore DevGuiPreview_Studio) then tools/gui_snapshot_build.luau in Edit. Delete the previews any time.
- **World Tree walk-through (2026-10-08).** AncientTreeController: no part collides or is queryable (the trunk used to).
- **Training pads glow (2026-10-08).** Each TierPad's Edge goes through GlowRing.build (in its color); build_map too.
- **Ranger shine (2026-10-08).** AuraCore and AuraRays on the Forest Ranger's UpperTorso, from the Toolbox model Workspace.Anime["Shiny-01"] (no scripts), dimmer (core Brightness 2, LightEmission 0.7; rays 0.6 and fainter). Copied to pass owners with the other Aura... emitters.
- **Forest tile preview (2026-10-08).** tools/forest_preview.luau lays the 540 plots' slabs and borders into Workspace.ForestPreview (found like ForestService.buildPlots) so the hexes show in Edit; ForestService.init destroys the folder at server start. Rerun after map or grid changes.
- **Ranger shine fix (2026-10-08).** AuraCore and AuraRays use black-background textures, so LightEmission must stay 1 (dark squares showed at 0.6/0.7); dimmed with Brightness (core 1.5, rays 0.6) and Transparency instead.
- **"2X TRAINING" spring sign (2026-10-08).** New SpringSignController: a BillboardGui (40 studs wide, AlwaysOnTop, 30 studs over the hub center) shown while the break runs with SpringMultiplier > 0, reading "{N}X TRAINING" with a scrolling rainbow UIGradient on the text face, a gentle pulse and rotating sun rays behind (sun_rays texture, decal 98479872249909 / image 83538665602246, tools/make_particle_textures.py). Synced; not yet seen in a playtest (Studio wouldn't start play).
- **Spring sign pulse (2026-10-08).** The text no longer scales (text renders at whole font sizes, so it stepped); the sun rays breathe instead (size +-12%, transparency 0.05-0.4).
- **100x tier look (2026-10-08).** (The glow vfx sparkle/super glow, rainbow ring pulses and a center lightning flicker were tried and undone.) Treadmill 100x's Zone has an Attachment LightningTrail at the belt's back end (zone-local 0, -1.5, 5.4; the console is at -Z) with Bolts: the PDS kit's LightningTrail decal (14050985655), streaming backward (EmissionDirection Back, VelocityParallel, 14-22 studs/s, 12/s). The 100x pad's title has the Rainbow attribute (new RainbowTextController sweeps a rainbow through any TextLabel with Rainbow = true) and its GlowRingFx has Rainbow (GlowRingController sweeps a rainbow across the ground glow and flows colors around the wall); build_map sets both for 100x. The unused bolt texture image 74476262546899 (tools/make_particle_textures.py lightning) is spare.
- **Rainbow fix (2026-10-08).** Rainbows (RainbowTextController, SpringSignController, GlowRingController) no longer slide UIGradient.Offset (past the edge it clamped to one end color, so stretches looked all red); they set Color = UIStyle.rainbowSequence(phase) each frame (shared UIStyle.RAINBOW / rainbowAt / rainbowSequence). Faster: text 0.7 turns/s, ring 0.5. 100x treadmill Bolts Rotation 90 (the decal's bolt runs sideways).
- **Leaderboards: Strength, Seeds, Speed (2026-10-08).** GameConfig.Leaderboards.Stats = Strength, SeedsPlanted (lifetime, "Top Seeds", planting icon), Speed (was Most Forests in the middle); a new OrderedDataStore Top_SeedsPlanted fills as players save. The player list (leaderstats) shows Strength, Seeds, Speed (was Strength, Forests). The three lobby boards were all set to Strength in the place; re-set left to right (build_map has the order). Verified in a playtest.
- **Leaderboards top 100 with avatars and your place (2026-10-08).** Leaderboards.Size 100 (GetSortedAsync max). Each row: rank, round AvatarHeadShot (rbxthumb), name cut off with "..." before the value, value. A "You" row pinned at each board's bottom shows your rank or "#100+" and your current value. Rows are only ~330 px wide.
- **Treadmill 100x Zone restored (2026-10-08).** It had gone missing in the place (the 100x treadmill trained no one); recreated from the 75x one (TreadmillStation tag, Multiplier 100), verified training in a playtest. The lightning on it was removed again at the user's request.
- **Pad signs higher (2026-10-08).** The 8 tier pads' "Nx / Requirements" BillboardGuis sit 13 studs up (was 9), in Studio and build_map.
- **Pad sign layout (2026-10-08).** 270 x 64 (was 230 x 56), title 58%, "Requirements" text 23 (was 17) with a 26 px icon, and a slimmer band (0.8 x 1.15 of the sign, other signs keep 1.6 tall). Studio and build_map.
- **Lobby trails grounded (2026-10-08).** The trails stay raised (top ~1.95, over the hex tiles' 1.75 edges) but each PathBed now reaches down to the ground (0.6), so they read as solid walkways instead of floating over the grass between the plaza and the forest, and a PathRamp wedge (paver look, 7 studs) climbs from the plaza (0.9) onto each trail at the gate. Studio and build_map.
- **Music at 30% (2026-10-08).** MusicController LEVEL 29.6 -> 8.9 (tracks now play at volume ~0.04-0.12; break music 0.04), DUCKED 0.06 -> 0.02.
- **Walk speed line (2026-10-08).** Reads "Walk Speed: 97/534" when limited (was "97 (max 534)"); the "Speed limit" button under it became a small edit icon (image 76019418992436) after an 8 px gap, toggling Settings (click again to close).
- **Forest Ranger ring (2026-10-08).** Workspace.Map.RangerRing (a Model beside the NPC, not inside it: the shop card copies the NPC) holds a white 9-stud Ring part turned into a GlowRingFx at y 0.95 on the plaza. Studio only; Map (not Lobby), so map rebuilds keep it.
- GUI previews in StarterGui refreshed (2026-10-08).
- **Glow ring wall scales with size (2026-10-08).** GlowRing wall height = min(1.5, 0.08 x ring width): the 9-stud Ranger ring gets 0.72; the shop, dispenser, pad and Spring rings (18+ studs) keep 1.5.
- **Plain Forest Ranger (2026-10-08).** All effects removed from the NPC (the blue water aura and its outline, the shine core and rays, the light; 25 instances) and CharacterDisplayController no longer adds sparkles. Pass owners' aura came from the NPC's Aura... emitters, so they get none now (OutfitService wearAura copies nothing). The white RangerRing stays.
- **Free gift ring and hiding (2026-10-08).** A pink 10-stud GiftRing glow ring inside the GiftBoard model (Studio and build_map). TutorialController hides the whole GiftBoard on that player's client once FreeGiftClaimed is set (saved, so it stays hidden on later visits; checked every CHECK_SECONDS): parts via LocalTransparencyModifier, the label and ring disabled. Verified both states in a playtest.
- **Ranger sign in the place (2026-10-08).** CharacterDisplayController.buildSign makes the sign (Band, Price, PassName, Boosts; scale-based TextScaled lines, no UIScale script) and decorate() reuses an existing CharacterSign, only filling Price (setText updates the Face/Shadow copies). Built into the Ranger in Studio (he now lives in Workspace.Map.Model with RangerRing; the user moved them). Verified: one sign in play with the live price.
- **Mobile Drop and Plant (2026-10-08).** Touch: a plain "Drop" button right of the pick-up prompt (CarryController PICKUP_HALF_WIDTH/HEIGHT); the Plant action button sits up-left of the jump button.
- **Plant sound (2026-10-08).** Sounds.Plant = "footstep grass 3" (110522236020035, 0.39 s, volume 0.5), played by CarryController on your own plant press only (acorns or a held special seed), pitch 0.9-1.1, at most one per 0.12 s. Synced.
- **World Tree see-through (2026-10-08).** Standing within SpringRadiusStuds (43) of the trunk, up to 30 studs above the hub, fades the tree (not its base) to LocalTransparencyModifier 0.75 for that player only (AncientTreeController INSIDE_FADE). Verified in a playtest: 0 outside, 0.75 inside, 0 again after leaving.
- **Other 2026-10-08 tweaks:** "Full! Go plant." HUD hint removed; tutorial step text white; tutorial-complete sound = SuccessSfx 136993031050456; the training pop (Sounds.Gain) 0.35 -> 0.28. All synced.
- **Shopkeeper is a Forest Ranger (2026-10-08).** `Workspace.Map.Lobby.RangerStation.Shopkeeper` is now a copy of the Forest Ranger with no scripts, Animator, animations, sign, tags or attributes, standing where the plain avatar stood. build_map's "make a shopkeeper if missing" check now searches the whole Map. Also: the break's bottom "2x boost: Strength and Speed" line removed (the 2X TRAINING sign says it); forest-complete clip 0.5 -> 0.35; pickup pop 0.25 -> 0.175.
- **Invite friends button (2026-10-08).** The friends icon at the bottom left (HUD buildFriends, "Invite") is an ImageButton that opens Roblox's invite prompt (SocialService.PromptGameInvite after CanSendGameInviteAsync). Verified in a playtest: the Invite Friends dialog opens.
- **Pre-release pass (2026-10-08).** stylua/selene/luau-lsp clean (selene: one style warning in HUD, shadowed `disc`); all 54 scripts in Studio match the repo; DevCommand only exists in Studio; Studio data stores are separate (_Studio); no stray server scripts; GUI previews are removed from PlayerGui on join; a full forest -> break -> reset into Kyoto ran with no errors.
- **Footsteps removed; mobile buttons (2026-10-08).** FootstepController now only mutes Roblox's default running sound (the surface steps were removed, the user's call). Mobile Plant button: sized to 90% of the jump button (Roblox's default was 45 px) and dimmed to 0.3 instead of 0.6 with nothing to plant; it had looked missing because it was small and nearly invisible on the plaza. Verified in the iPhone 16 Device Simulator. Phone Drop button: 58 px tall (was 86), text 26 (was 32).
- **Mobile Drop button, trunk, tutorial ring hint (2026-10-08).** Phones: Drop is now a round ContextActionService button like Plant (title "Drop", 90% of the jump button), level with the jump button just left of it, shown while carrying (CarryController placeNearJump/dropSpot); Plant moved a full width left of the jump button (clear of the Strength label). Computers keep the "Q Drop Seeds" bar. Phones: the ring trunk sits alone at the top middle (HUD RingTrunkHolder; hidden in the break, when the countdown uses that spot). Tutorial step 2 now reads "Plant them in the glowing ring: fill the outer rings first" (inner when ForestState OutsideIn is false). Not seen on a real phone yet: Studio's Device Simulator reports a keyboard, so UIStyle.isTouch() is false there.
- **Mobile button look; prompt padding (2026-10-08).** Phone Plant and Drop buttons: no image (Roblox's bubble is cleared whenever it swaps back in on press), a black fill at 0.45 transparency with a round UICorner and a soft white UIStroke, like the jump button; Plant fades to 0.75 with its label at 0.4 when there's nothing to plant (set every frame). The custom prompt panel (Pick Up Seeds, benches) is 100 px tall (was 86) with 42 px side padding (was 30).
- **Locked station -> Roblox buy prompt (2026-10-08).** TrainingController's showLocked now calls MarketplaceService:PromptGamePassPurchase for GameConfig.StationPasses[multiplier] directly (at most once per 2 s); the custom "station locked" popup with its Unlock button is gone. The server still sends StationLocked once per treadmill visit and on each locked bench press. Verified in a playtest at the 100x treadmill: the Roblox purchase dialog opened directly.
- **Shop on phones, group gift, fall respawn (2026-10-08).** RobuxShop: on phones the window scales to fill up to 94% of the screen height / 92% width (PHONE_FILL); Stations cards are 190 tall (STATION_CARD, was 118) with a 46 title, 22 "or N forests" line and a 70-tall buy button (text 30); the page line is 24. Group gift: Workspace.Map.Lobby.GroupGiftBoard (a GiftBoard clone at (106, y, -32), right of the upgrades station, facing +X; also made by build_map) with a "Join Group" prompt tagged GroupGiftPrompt; GroupGiftController opens GroupService:PromptJoinAsync(GameConfig.Economy.GroupId = 336242048) and on Joined/AlreadyMember fires ClaimGroupGift; EconomyService checks GetGroupsAsync and pays GroupGiftCoins (500, a default) once (saved GroupGiftClaimed); the board hides once claimed. FallService: a character below y -50 is put back on the SpawnLocation (checked every 0.25 s), so falling never kills.
- **Group gift is a bulletin board; phone Drop by the bar (2026-10-08).** GroupGiftBoard is now a small wooden bulletin board (Board 11x7 with a SurfaceGui "FREE GIFT / Join our group: +500 coins!", two posts, a cap, a 14-stud pink GlowRing, the Join Group prompt on the Board), replacing the gift-box clone; build_map makes the same. Verified in a playtest: the join prompt opens, ClaimGroupGift paid +500 once (a second claim paid nothing), and the board hid. (The Studio test profile now has GroupGiftClaimed = 1: use the test panel's "Reset to new player" to see the board again.) Phone Drop: a small dark "Drop" button inside the Forest Bar frame at Position (1, 10, 0.5, 0), as tall as the bar, shown while carrying (CarryController phoneDropButton); no Roblox action button for Drop any more.
- **Leaderboards: Forests added, order Forests, Seeds, Strength, Speed (2026-10-08).** GameConfig.Leaderboards.Stats/Titles and LeaderboardService PLAYER_LIST in that order; a fourth lobby board (Stat ForestsCompleted) was cloned one step past the old Strength end in Studio and the Stats reassigned (the "SEEDS" label cap moved with the Seeds board); build_map has four boards at 312/324/336/348. Verified: the four boards draw left to right Top Forests, Top Seeds, Top Strength, Top Speed. The Roblox player list showed its columns as Speed, Strength, Forests, Seeds whatever the creation order; each column now carries a Priority NumberValue (1-4) and the first an IsPrimary BoolValue (the old PlayerList honored these). Not yet confirmed that the current list does.
- **Training tip stops past Strength 200; PC drop hint (2026-10-08).** `Tutorial.RemindMaxStrength` (200): the "Tip: train to carry more and walk faster" reminder never shows once Strength is over it (TutorialController `trainingTip`). On computers the big "Q Drop Seeds" bar under the pick-up prompt is replaced by small "Q to drop" text (size 16) in the bottom right corner, still only while carrying; it's no longer clickable. Phones keep their Drop button. Synced; verified in a playtest: the hint sits 8 px from the bottom right corner, shown only while carrying.
- **Test panel "Next world" ends the break (2026-10-08).** DevService `setTier` now calls the new `AwakeningService.stop()` first (endsAt 0, SpringMultiplier 0; `finish()` uses it too), so a forest filled with the test panel and then skipped no longer keeps its spring multiplier and 2X TRAINING sign into the next world. Normal play was never affected (finish() already cleared it). Verified in a playtest: during the break spring 2x; after Next world AwakeningEndsAt 0, SpringMultiplier 0, the sign off, tier 2.
- **Coin sound (2026-10-08).** HUD COIN_SOUND_ID = 109742263473623 ("Coin sfx", 1.63 s, the user's pick; was "plop" 773858658). Volume 0.35, one per handful, at most one per 0.25 s, unchanged. Each copy is now destroyed when it ends (was Debris after 1 s, which cut the 1.63 s clip short). Pitch still climbs 4% per sound in a streak (gaps under 1.5 s), up to +32%. Synced; the user to judge by ear.
- **Edge floor (2026-10-08).** Running off the island no longer drops you (FallService sent fallers to the spawn, a shortcut home). `Workspace.Map.EdgeFloor`: 64 invisible slabs (top 1.5, just under the walk plate's 1.55) from 355 out to 650 studs, each with an invisible 60-stud wall at 650; tagged WalkFloor. In build_map and placed in Studio. Verified in a playtest: a character ran from r 330 past the edge on the slabs (FloorMaterial Plastic, y steady) and stopped at r 648. FallService stays as the backstop. The islets (~550) are now reachable on foot.
- **Bought world skips the roulette (2026-10-08).** AwakeningService.finish(): with a PickedTier the next forest starts as that world as soon as the break ends; no NextTier/TierRolls, so clients play no wheel and the roulette's wait is skipped. Unpicked breaks spin as before. Synced; verified in a playtest: with world 2 bought the break ended straight into tier 2 (TierRolls unchanged, no wheel); with no pick the wheel showed and TierRolls went up. (Test-panel DevCommand needs a number value even for endAwakening.)
- **Group gift thanks only on a real claim (2026-10-08).** "Thanks for joining! +500 coins" showed on every join for players who had claimed before: the save loading set GroupGiftClaimed nil -> 1, which fired the banner. GroupGiftController now shows it only on 0 -> 1 (same guard as ShopController's level banners). No coins were ever paid twice. Synced; verified: no banner on join with GroupGiftClaimed 1, banner on 0 -> 1.
- **Switched-off character gives nothing (2026-10-08).** PassService.handsSpeed now reads GameConfig.availableHandsPasses(), so owning the Lord of the Forest pass while `Features.LordOfTheForest` is false gives neither 5x pickup/planting nor the Lord outfit (OutfitService dresses from HandsSpeed). Verified in a playtest on the user's account (owns both passes): HandsSpeed 2, wearing the Forest Ranger outfit only.
- **Full-grown tree is silent (2026-10-08).** The placeholder ping (electronicpingshort.wav) when a tree reaches full grown was removed (ForestController); the leaf burst stays. The ring-complete rising notes still use that ping. Synced.
- **Boosts are developer products (2026-10-08, the user's call: game passes only for the Forest Ranger and the training areas).** 12 products created through Open Cloud at the passes' prices (Strength 2x-128x: 3717371274/78/79/80/83/84/87; Speed 1.5x-16x: 3717371291/93/94/95/97), ids in `GameConfig.Boosts` (was `BoostPasses`; each step keeps its old `PassId`). The 12 boost passes are off sale (Lord of the Forest was already); on sale now: Forest Ranger and the 7 training passes. A purchase goes through ProductService and `DataService.grantPurchase` into new profile fields `StrengthBoostBought` / `SpeedBoostBought` (default 1; a lower step bought after a higher one changes nothing). PassService publishes `StrengthBoost` / `SpeedBoost` = the higher of that and any old boost pass owned, so earlier buyers keep theirs (your own account owns them all, so in Studio and live you show 128x / 16x until the test panel resets it). HUD button and SHOP card prompt the product. Verified in a playtest: fake 4x Strength receipt -> bought 4, StrengthBoost 4, the HUD button moved on to 8x; test profile reset to 1 after. Roblox shows these (and the old passes) ~10% under the set prices to the user's account (36 for 39, 900 for 999): Roblox-side pricing, not the code.
- **Training pass icons (2026-10-09).** `assets/icons/training_{2,5,10,25,50,75,100}x.png` (512x512, transparent corners): a glossy disc in that pad's color (build_map TIERS) with a 3D dumbbell and the multiplier in white Arial Black with a dark outline; our own design in the style of Build the Pyramid's gym pass icons, not a copy. Rendered with EEVEE in a separate "PassIcons" scene added to the open Blender file (trees.blend; the tree scene is untouched; not saved by me). Uploaded to the 7 training passes through Open Cloud (PATCH game-passes/{id}, -F imageFile=@file); each pass got its own new icon asset, in Roblox moderation (Pending/InReview) when uploaded. (PowerShell gotcha: an [ordered] hashtable with int keys indexes by position, which first put two icons on the wrong passes; fixed by re-uploading all 7.)
- **Story intro off (2026-10-09).** `GameConfig.Features.TutorialIntro = false`: a new save starts at TutorialStep 1 (DataService load), so the camera sweep and its captions are skipped; the steps are unchanged. The test panel's "Replay tutorial intro" still plays it.
- **Version line (2026-10-09).** Settings shows "Version N" (`game.PlaceVersion`, 0 in Studio) at the bottom, to spot an outdated server against the place's Version History.
- **Two rings (2026-10-09, the user's idea).** `Grid.AheadRings` 1: besides the open ring, a plot one ring further in opens once the tree just outside it is full grown; the ring after that waits for the open ring to finish (so no spikes toward the hub). One shared rule, `Targeting.isOpenPlot`, used by ForestService (planting, overflow, bought seeds) and ForestController (rims; a tree finishing refreshes its neighbors). `devFillOpenRow` fills only the open ring. ForestState NextRingDone / NextRingTrees: the ring trunk fills the next ring's band too, at `TRUNK_NEXT_FADE` 0.45 transparency. `AheadRings = 0` restores the old one-ring rule. Checked: tests/TargetingCheck.luau passes in Studio; type check and selene clean. **Not yet playtested.**
- **Uniform tiles experiment (2026-10-09, the user's idea).** `GameConfig.Forest.UniformTiles = true`: ForestController colors every slab and border MOSS_COLOR, widens slabs 3% (UNIFORM_SLAB_GROW) so the 0.5-stud gaps close, and shows no glowing rims; the target outline, guide arrow, tufts/flowers and ring wave stay. `false` = the normal tiles. Synced; not yet seen in a playtest.
- **Tree preview on the target (2026-10-09, the user's idea, like Build the Pyramid's block preview).** While you carry acorns (not a special seed), an empty target tile shows this world's first Common tree at `PREVIEW_STAGE` 1 (about 4.6 studs tall), white (`PREVIEW_COLOR`) at `PREVIEW_TRANSPARENCY` 0.6 with a white Highlight outline (a tree-colored first version read as a real planted sapling), standing at the tile's center (TargetController `showPreview`, ForestController `previewTemplate`). Synced; not yet seen in a playtest.
- **Preview of the next stage (2026-10-09, the user's ask).** On a started tree the target preview is that tree's next growth stage, at the real tree's pivot and size (`plot.treePivot`, `plot.treeSize`); nothing on a full-grown tree. `PREVIEW_TRANSPARENCY` now 0.4 (0.6 was too faint). Synced; not yet seen in a playtest.
- **Preview outline black (2026-10-09, the user's call).** The preview's Highlight outline is `PREVIEW_OUTLINE` black at OutlineTransparency 0 (was white); the fill stays white at 0.4.
- **Preview black; progress bar (2026-10-09, the user's calls).** The tree preview is black (`PREVIEW_COLOR`) with a black outline. The target's "12 / 40" label is now a slim bar (`METER_SIZE` 110x14 px) 2.5 studs above the tile (`METER_HEIGHT`, under the tree, always on top), filling green (`METER_COLOR`), gold when the next press finishes the tree; it shows text only while holding a special seed. Verified in a playtest: 2 of 5 seeds filled 40%, no errors. Also verified the two-ring rule: a ring-14 tile behind a full-grown tree targets and plants; one behind unfinished trees doesn't (target falls to ring 15, server refuses). With UniformTiles on, nothing shows which ring-14 tiles are open (open question to the user: glow only open tiles?).
- **Uniform tiles reverted (2026-10-09, the user's call).** The experiment and its `Forest.UniformTiles` flag were removed; tiles are back to dirt/moss with grass borders and glowing rims on open plots.
- **Tutorial teaches the buttons; shop spotlight; new end line (2026-10-09, the user's asks).** TutorialController `key()` picks the device's button (phone: the on-screen button, gamepad: X, else E): "Hold E at an acorn pile to grab acorns", "Press E to plant in the glowing tiles" (was the glowing-ring line), "Press E at a bench to carry more (x/20)", "Step on a treadmill to walk faster (x/20)", "Step into the shop's ring and buy an upgrade". During the Shop step, ShopController `refreshSpotlight` puts a pulsing gold ring and "Buy this first!" on the cheapest upgrade (a new player: Bulk Pickup, 50 coins, ties go to the first) and shades the other cards. End banner: "Tutorial finished! Work together with others to grow the forest!". Verified in a playtest (texts on steps 1-4 and 7, the spotlight with 2 cards shaded, no errors; the step was put back to 8).
- **Spotlight always Bulk Pickup (2026-10-09, the user's call).** `GameConfig.Tutorial.ShopUpgrade = "BulkPickup"` replaces "the cheapest upgrade" in ShopController `refreshSpotlight`.
- **Smaller, longer end banner (2026-10-09, the user's call).** `HUD.banner(text, color, size?, seconds?)`; "Tutorial finished!" uses `FINISHED_SIZE` 0.75 and `FINISHED_SECONDS` 4 (TutorialController; other banners 1 and 3).
- **Arms up while carrying (2026-10-09, the user's ask, like Build the Pyramid).** TrainingController `poseCarriers` (every client, every player with Carried > 0 and not benching, each Stepped after the Animator, R15 shoulder/elbow Transforms): `CARRY_ARM_UP` 175°, `CARRY_ARM_OUT` 12°, `CARRY_ELBOW_IN` 8° (60° left the hands beside the head). Hands end about level with the top of the head, at the acorn's tip (CarryController HEAD_GAP 0.4). Checked on screen in a playtest.
- **First-break guide (2026-10-09, the user's ask).** During a forest break (ForestState SpringMultiplier > 0), a player whose saved `SpringGuideSeen` is 0 gets the prompt "The forest is grown! Stand inside the World Tree to train {m}x" and the arrow to the hub center (TutorialController `springGuide`, ahead of the tutorial steps and the training tip). TrainingService saves `SpringGuideSeen = 1` the first time they stand in the Ancient Spring, so it never shows again. Verified in a playtest: prompt at the break, gone and saved (1) once inside. Your Studio save now has it at 1.
- **No automatic Robux popup at locked stations (2026-10-09, the user's call, from the analytics: 44 of ~190 new players got it, 0 bought).** TrainingController `showLocked` now shows a banner "25x training unlocks at 15 forests (or in the SHOP)" instead of PromptGamePassPurchase; the passes stay in the Robux shop's Stations tab. Verified in a playtest on the 25x treadmill (no prompt, the banner shows).
- **First-win changes (2026-10-09, from the analytics).**
  - **First tree:** the first tree a player ever finishes (planting its last acorn) pays `Economy.FirstTreeCoins` 100 and shows confetti, "Your first tree! +100 coins" and the fanfare (ForestService `finish`, saved `FirstTreeDone`; TutorialController celebrates on 0 -> 1). Saves from before with 50+ acorns planted count as done.
  - **Smaller solo trees:** `ForestSize.MinSeedsPerHex` 5 -> 3 (solo forest 1,620 acorns, first ring 252).
  - **Bench:** "Jump to get off" (phones: "Tap Jump to get off") shows while you're on a bench (TrainingController `showBenchHint`), and tutorial step 4 starts with "Press Space / Tap Jump / Press A to get off the bench, then step on a treadmill" while you're still on it.
  - **Test panel commands:** `setFirstTreeDone`, `setSpringGuideSeen`.
  - **Verified in a playtest:** solo target 1,620 at 3 per tree; the bench hint on the 1x bench; with FirstTreeDone 0, finishing a tree gave +100 coins and the banner.
- **Starter quests (2026-10-09, [docs/plans/Quests.md](plans/Quests.md)).** GameConfig `Quests` (8, with `questProgress`), saved `QuestIndex` / `TreesFinished` / `RingsHelped` (ForestService counts the last two), QuestService (`ClaimQuest` remote), QuestController (the card at the bottom of the stats column, the list window), a `Quests` analytics funnel. Verified in a playtest.
- **Quest card restyled (2026-10-09, the user's call).** A dark vignette instead of the tan card (black, `VIGNETTE_DARKEST` 0.35 transparent on the left, fading out to the right), to match the plain stats column; the list window keeps the shop-style cards. New test command `setQuestIndex` (9 = all done). Checked on screen.
- **Test panel: "Restart quests" and "Skip quest"** (2026-10-09) send `setQuestIndex` 1, or the next quest (past the last = all done, then 1).
- **Planting Range reworked: one more tree per level (2026-10-09, the user's call).** `Upgrades.PlantingRange` is 4 levels of +28 studs (30 → 58 → 86 → 114 → 142: reach 1 → 5 trees), costing 300 / 2,400 / 19,200 / 153,600 coins (BaseCost 300, Growth 8); the shop says "Reach 2 trees → Reach 3 trees". Robux levels use the first 4 products (9 / 19 / 39 / 79 Robux; products 5-10 unused). Saves migrate (DataService VERSION 2): old level L becomes ceil(4L / 28), so 1-7 → 1 and 8-10 → 2, nobody loses reach. While carrying acorns, every other open plot in range is faintly lit (TargetController `showReach`, `REACH_TRANSPARENCY` 0.82). Not yet synced or playtested when written (Studio was in a playtest).
- **Spring field and "INSIDE" (2026-10-09, the user's asks).**
  - **The gold ring around the World Tree** already shows only during the break (GlowRingController BreakOnly; checked in a playtest: off with no break). It shows in Edit mode, and the live servers predate it.
  - **Tall field:** its glowing wall is now 50 studs tall instead of 1.5 (`GlowRing.build(source, height?)`; build_map `SPRING_WALL_HEIGHT` 50). The wall in the saved place was raised directly, so build_map didn't need re-running.
  - **INSIDE:** the spring sign reads "2X TRAINING" with "INSIDE" under it (SpringSignController, `INSIDE_SIZE` 60).
  - **Verified in a playtest** during a break: the field is visible around the tree, and the sign is on with both lines. In the screenshot the first-break guide line ("The forest is grown! …") happened to cover the sign.
  - **Save the place** to keep the taller wall.
- **Smooth spring field (2026-10-09, the user's ask: too many lines).** New texture `field_wall` (tools/make_particle_textures.py, assets/textures/field_wall.png; decal 90102674279582, image 95604426031102): an even glow fading up, no streaks. Set on the spring wall's 4 beams in the saved place and in build_map (`SPRING_WALL_TEXTURE`); the small rings keep the streaky glow_wall. Checked on screen in Edit mode. Save the place.
