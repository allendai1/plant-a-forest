# Plant the Forest: Architecture

Status: **approved 2026-10-06**, updated the same day for the giant-sequoia redesign (`docs/DESIGN_CHANGES.md`). This is a source of truth alongside `docs/GDD.md` and `src/shared/GameConfig.luau`. Milestone plans that change it must say so.

Scope: the MVP (tier 1 Meadow Woods, Common trees, Rain). Post-MVP pieces are mentioned only where a choice now makes them cheaper later.

## 1. Principles

- **Server decides, client renders.** Clients send requests (grab, plant at q,r, buy X). Every remote is rate-limited and fully validated on the server. No `InvokeClient`, ever.
- **One entry point per side.** `init.server.luau` and `init.client.luau`; everything else is a ModuleScript. Two-phase startup: every module's `init()` runs (wiring, remote creation) before any `start()` (loops).
- **Pure logic in shared modules.** Formulas in `GameConfig`, hex math in `HexGrid`, target picking in `Targeting`. These can be tested outside Studio.
- **State reaches clients three ways:** attributes for small values (Forest Bar, weather, player stats), one snapshot on join, then batched hex deltas. Nothing is replicated per seed.
- **About 540 big trees:** trees and hex tiles are client-built from data, no per-tree scripts, no per-frame loops over all trees (only the trees bouncing right now).

GameConfig and the GDD were cross-checked: capacity, walk speed, gym ladder, growth stages (tier 1 and tier 2 boundaries), weather and upgrade numbers all agree. No conflicts found.

## 2. Layout and startup

**Sync (decided after M0):** the files in `src/` are the source of truth and are pushed into the Studio place through the Studio MCP connection, not `rojo serve`. `default.project.json` is kept only so `rojo sourcemap` can feed luau-lsp's type checker. Map parts (ForestCenter, walkways, rack, training zones, hub decorations) and the imported mesh assets live in the place itself, so the place must be saved in Studio.

```text
src/
├── shared/                    → ReplicatedStorage.Shared
│   ├── GameConfig.luau        (exists, unchanged)
│   ├── HexGrid.luau           (exists, unchanged)
│   ├── Types.luau             shared types: PlotState, HexBatch, Snapshot, Profile
│   ├── Remotes.luau           remote names + payload types; server creates, client waits
│   ├── Trees.luau             species ids (1 = Leafy, 2 = Pine); mutation ids come with M9
│   └── Targeting.luau         pure: open hexes near a position, sorted by distance
├── server/                    → ServerScriptService.Server
│   ├── init.server.luau       requires Services/*, runs init() then start()
│   ├── Guard.luau             rate-limit buckets + argument checks (isInt, isFinite)
│   └── Services/
│       ├── DataService.luau
│       ├── ForestService.luau
│       ├── CarryService.luau
│       ├── TrainingService.luau
│       ├── EconomyService.luau
│       ├── WeatherService.luau
│       ├── AwakeningService.luau
│       ├── QuestService.luau  (postponed with the quests)
│       ├── PassService.luau   (station game passes; M2b)
│       ├── ProductService.luau (M6: the one ProcessReceipt handler for developer products)
│       └── DevService.luau    (Studio-only test commands; new)
└── client/                    → StarterPlayerScripts.Client
    ├── init.client.luau
    └── Controllers/
        ├── ForestController.luau     (new: mirrors hex state, builds tiles and trees, row and section moments)
        ├── AncientTreeController.luau (M5: the world tree, grows with the bar)
        ├── TargetController.luau
        ├── CarryController.luau
        ├── HUD.luau
        ├── TrainingController.luau   (M2b: bench visibility, run animation, locked-station popup)
        ├── ShopController.luau       (M6b: the shop panel when you stand in the ring by the altar; M7 adds buying)
        ├── WeatherController.luau    (new, M9)
        ├── AwakeningController.luau  (new, M6)
        └── TutorialController.luau   (M10: prompts, the tutorial's arrow targets, the free gift)
```

Cross-module events use a small signal on the owning module (for example `ForestService.BarFilled`), never `_G`.

Map conventions (built in Studio, found by CollectionService tag): `ForestCenter` (one part, grid origin), `NoPlant` (volumes that block hexes; none on the MVP map), `SeedRack`, `TrainingZone` (attribute `Stat = "Strength" | "Speed"`). `ReplicatedStorage.Assets` holds the Blender meshes (made by `tools/blender/build_assets.py`, imported once in Studio): `Tiles.HexTile` (Slab, Rim, Tufts), `Trees.Leafy1–4` and `Trees.Pine1–4`, and `AncientTree.Ancient1–4` plus `AncientTree.AncientBase`. Each model's pivot is its base center at the origin; clients clone the pieces.

**Lobby (M6b):** `Workspace.Map.Lobby` is built by `tools/build_map.luau` (`build_lobby.luau` until M11, when it also took over the island, waterfalls, floating islands, clouds, Lighting and the plaza decorations; run through the Studio connection; re-runnable) from the Blender meshes in `ReplicatedStorage.Assets.Lobby` (plaza, garden, fence, trail, shop altar, acorn pile, bench press, treadmill) and `Assets.Acorn` (the giant seed). The meshes are exported from `tools/blender/build_assets.py`, uploaded with Open Cloud and inserted by the script. `SeedRack` is now on six acorn piles around the roots (CarryService already hooks every tagged rack). `ShopZone` tags the invisible part inside the shop ring. Each training tier's bench and treadmill sit on a `TierPad <n>x` in the tier's color. The first section to open is the one in front of the `SpawnLocation`.

## 3. Server services

| Service | Owns | Exposes to other services |
| --- | --- | --- |
| **DataService** | Player profiles via **ProfileStore** (single module copied from loleris's official GitHub repo into `src/server/Vendor/` in M8; no Wally): loading, session locking, autosave, release on leave and shutdown. Mirrors profile fields to Player attributes. Migrations by schema version. | `get(player)`, `onLoaded` signal. All profile writes go through it so attributes stay in sync. |
| **ForestService** | The grid and all plot state. Builds plots from `HexGrid.rings(HubRings + ForestRings)` around `ForestCenter`, skips the hub rings (0–3) and hexes whose center is inside a `NoPlant` volume, raycasts each plot onto the ground. Rows (one section's plots in one ring; the section is `HexGrid.side`, between two walkway spokes) and the open row: the section the `SeedRack` is in goes first, outside-in, then the next section around the hub; the next row opens when `RingUnlockFill` (1.0) of the current row's trees are full grown. Forest Bar count and target. Per-forest seeds by UserId (for Awakening credit). The `PlantSeeds` and `GetForest` handlers, overflow, mutation roll, species and tree-seed pick on the first seed. Batch flushing. Reset. | `plant` result signals (`SeedPlanted(player, plot, mutation)`, `TreeFinished(plot, contributors)`), `BarFilled`, `reset()`, `seedsThisForest(userId)`, `setLocked(bool)`. |
| **CarryService** | Carried seed count per player (server memory, not saved), mirrored to `Carried`. The seed rack's ProximityPrompt: `Triggered` (on the server) grabs and starts a server-side repeat every `HoldRepeatSeconds`, `TriggerEnded` stops it; each grab checks reach (`RackRangeStuds`), capacity and the minimum gap between grabs. | `get(player)`, `take(player, n)`. |
| **TrainingService** | Benches (`BenchStation` models): the bench's ProximityPrompt fires on the server, which checks reach and the unlock, then holds the character on the bench (root anchored) and sets `Benching` until `LeaveBench`, death or leaving. Treadmills (`TreadmillStation` zone parts): standing inside one trains Speed and sets `Running`. A loop every `TrainingCheckSeconds` (0.05 s) runs a per-player timer that pays one rep (`RepAmount × the station's Multiplier`) per full `RepSeconds` (0.25 s); getting off drops the unfinished rep. A station is unlocked when the player has enough forests for its multiplier or owns that tier's pass; otherwise it sends `StationLocked`. Sets `Humanoid.WalkSpeed = walkSpeed(Speed)`, limited by the player's own `WalkCap` setting when it's set, on spawn and on Speed or WalkCap change. Applies the camera settings to each player on join (Invisicam, max zoom from GameConfig). | none |
| **EconomyService** (M7) | Coins live in DataService's profile (`DataService.add(player, "Coins", n)`); EconomyService owns the upgrade shop. `BuyUpgrade` is accepted only while the player stands in the `ShopZone` ring. Per-seed payout `CoinsPerSeed × mutation multiplier × Awakening boost`. Upgrade levels and the `BuyUpgrade` handler. Per-player upgrade values (Bulk Pickup, Bulk Plant, Planting Range; Quick Hands is out of the MVP). | `addCoins`, `upgradeValue(player, id)`, `plantRange(player)`. |
| **WeatherService** | The weather loop (every `IntervalSeconds`, lasts `DurationSeconds`, picks an enabled event by `PickWeight`; MVP: Rain). | `current(): WeatherDef?` |
| **AwakeningService** (M6) | Forest complete: called by ForestService (`setOnComplete`) after the batch with the last tree. Gives everyone online `RewardCoins` and +1 `ForestsCompleted`, rolls the spring multiplier, and sets `AwakeningEndsAt` (cutscene + break). Robux extensions add `ExtendSeconds` up to `MaxBreakSeconds`; one that can't apply is kept for the next break. When the break ends it calls `ForestService.reset()` (MVP: tier 1 again). Nothing needs locking: every plot is full during the break. | `extend(player)`, `finish()`, `springMultiplier()` |
| **ProductService** (M6, GUI pass) | `MarketplaceService.ProcessReceipt`: grants developer products from Roblox's receipt only, each PurchaseId once. Server-wide products (break extensions, Forest Bar seeds via `ForestService.addSeeds`, the server training boost via `TrainingService.addServerBoost`) remember PurchaseIds in server memory; upgrade levels go through `DataService.grantPurchase`, which saves the PurchaseId in the profile and waits for the save. | `process(receipt)` (DevService fakes receipts with it) |
| **FriendService** (GUI pass) | Friend Boost: counts each player's Roblox friends in the server (`IsFriendsWithAsync`, once per pair on join) and sets the `FriendBoost` attribute (+10% per friend, max +50%). ForestService multiplies planting coins by it. | `boost(player)` |
| **QuestService** (postponed) | Will check the quests against profile counters and pay each once. Postponed with the quest list (M10). | none |
| **PassService** (M2b, GUI pass) | Which game passes each player owns (station tiers and the Strength/Speed boost ladders): checked with `UserOwnsGamePassAsync` on join, granted on the server-side `PromptGamePassPurchaseFinished`. Publishes the highest owned boost as the `StrengthBoost` / `SpeedBoost` attributes; TrainingService multiplies gains by it. | `owns(player, multiplier)`, `boost(player, stat)` |
| **DevService** | `DevCommand` remote, created **only** when `RunService:IsStudio()`. M2b adds `grantPass`. Fill forest to a fraction, finish forest, set stats, add coins, start weather. | none |

Per-player data the server holds but doesn't save: carried seeds, rate-limit buckets, seeds this forest (kept by UserId until reset, so leaving and rejoining the same server keeps credit).

## 4. Client controllers

| Controller | Owns |
| --- | --- |
| **ForestController** | Client mirror of every plot (from the snapshot, then batches). Builds a hex tile per plot and the trees in a local `workspace.ForestView` folder. Tile look follows its state (locked, open, started, finished). Picks the stage with `GameConfig.growthStage`; places each tree with deterministic jitter/rotation/scale from `Random.new(treeSeed)`. On each delta: bounce tween, tile state change, swap model on stage change (8 stages: popped in from the old model's size, a small leaf puff, and a rising note when the seeds were your own), leaf burst + chime on finish. Plays the row complete moment when `OpenRow` moves to the next row, and the section complete moment when it moves to the next section. Canopies are `CanQuery = false` so the camera ignores them; trees never collide, so players run straight through them (changed after M10). (The starter's name label is postponed.) |
| **AncientTreeController** (M5) | The world tree and its `AncientBase` at the hub center. Each of its 4 models covers a quarter of `Seeds / Target` and scales smoothly inside it, starting at the previous model's full height. `shake()` for the ring moment. |
| **TargetController** | The local target: closest open hex in range (via `Targeting` over the ~40 hexes near the player, not the whole forest). PC mouse hover overrides it with another open hex in range (mobile has no picking: a tap on the game view plants into the nearest target). Draws the hex outline and the "12 / 40" meter (gold when the next press finishes it). When the player carries seeds and no open plot is in range, shows an arrow to the nearest open plot. Exposes `getTarget()` and whether any target exists (plant button dims). |
| **CarryController** | Acorns circling **every** player's head, built from their `Carried` attribute (since 2026-10-06; was one giant seed): small acorns for 1–5 seeds, and every 6 of a tier merge into the next (`GameConfig.AcornOrbit`, `acornCounts`), with merge and split animations, a puff, and a thunk for your own. Anchored, non-colliding parts moved by one RenderStepped `BulkMoveTo`, only for players within 150 studs of the camera; rebuilt when a head respawns or streams back in. M4 adds the plant action input (E / gamepad / mobile button) here: with a target → `PlantSeeds(q, r)`, repeating while held. The rack and benches use ProximityPrompts instead. |
| **HUD** | Build-the-Pyramid-style layout (GUI pass, `UIStyle` for the shared look): Forest Bar (`Seeds / Target`) with the 4 Robux seed buttons, the server boost timer and the "Full!" hint; coins with "+N" pops, Speed/walk speed, Strength/capacity and forests completed on the left; SHOP and the boost pass buttons on the right; Friend Boost; break UI; banners. |
| **RobuxShopController** (GUI pass) | The SHOP button's Robux-only panel: "BOOST Server Training!", the boost pass ladders, the training station passes. |
| **PromptController** (GUI pass) | Draws every ProximityPrompt with `Style = Custom` (acorn piles, benches): dark panel, gold edge, key square, object and action text; tap-and-hold on touch screens. |
| **WeatherController** (M9) | Rain visuals while `Weather == "Rain"`; drip effect on Wet trees (asks ForestController for them). |
| **AwakeningController** (M6) | From `AwakeningEndsAt`: the skippable cutscene around the awakening Ancient Tree, the "Forest complete!" and spring messages, the break (every tree sways through `ForestController.setSway`, placeholder animals walk in along the walkways, birds circle) and the white flash at the reset. Late joiners skip the cutscene. |
| **TutorialController** (M10) | Works out the tutorial step from saved progress (`SeedsPlanted`, Strength, Coins, upgrade levels), shows one prompt line, and points TargetController's guide arrow (`setGuideTarget`) at the nearest `SeedRack`, the `TutorialTraining` pad or the `ShopZone`. The free gift button and a one-time popup (`ClaimFreeGift`). |

No client prediction in the MVP: the local bounce arrives after the round trip plus up to one batch interval. If that feels laggy in M5, add a local-only bounce on press.

## 5. Remotes

All live in `ReplicatedStorage.Remotes`, created by the server at `init()` from the list in `Shared/Remotes.luau`. Every client→server handler starts with `Guard.allow(player, name, rate, burst)`, then type → range → permission → plausibility checks, and silently drops bad requests (rejections are counted for logging, never auto-banned).

| Remote | Type | Direction | Payload | Server-side checks / behavior |
| --- | --- | --- | --- | --- |
| `PlantSeeds` | RemoteEvent | C→S | `q: number, r: number` | Rate limit (see open question 2). Both finite integers. Plot exists and is plantable. Plot is in the open row (its section and ring match `OpenRow`). Plot not full. Horizontal distance root → plot ≤ `BaseRangeStuds + PlantingRange value + tolerance`. `carried ≥ 1`. Forest not locked (Awakening). Then plants `min(BulkPlant value, carried)` seeds: fills the target, overflow goes to the next-closest open hex to the player within range (server picks with `Targeting`), until seeds run out or nothing is open. Per seed: bar +1, coins to planter, first seed sets starter UserId, species, tree seed and the mutation roll. |
| `BuyUpgrade` | RemoteEvent | C→S | `upgradeId: string` | Rate limit (`Economy.BuyRate`). String and one of `GameConfig.ShopUpgrades`. Standing in the shop ring (M7). `level < MaxLevel`. `coins ≥ upgradeCost(id, level + 1)`. Deduct and level up with no yield between check and write. Result shows via attributes. |
| `GetForest` | RemoteFunction | C→S | none → `Snapshot` | Rate limit (about 1 per 5 s). Returns only public forest data. |
| `HexBatch` | RemoteEvent | S→C (all) | `{ seq, entries }` | (M4) Fired at most once per batch interval, only when something changed. |
| `AwakeningReward` | RemoteEvent | S→C (one) | `{ coins: number }` | (M6) Sent to each player online when the forest completes; shown when the cutscene ends. (`ForestReset` was dropped in M6: the reset reaches clients as one normal `HexBatch` with every plot.) |
| ~~`TutorialProgress`~~ | | | | Dropped in M10: the tutorial step comes from saved progress. |
| `ClaimFreeGift` | RemoteEvent | C→S | none | (M10) Rate limit. Not already claimed (profile `FreeGiftClaimed`, 0/1). Handled by EconomyService. Grants 500 coins once and marks it claimed in the same step. No like/favorite/group verification. |
| `DevCommand` | RemoteEvent | C→S | `command: string, value: number?` | Exists only in Studio. Whitelisted command names, value range-checked. |
| `LeaveBench` | RemoteEvent | C→S | none | (M2b) Rate limit. Ignored unless the player is benching; then releases them. |
| `SetWalkCap` | RemoteEvent | C→S | cap (number; 0 = no limit) | (2026-10-07) Rate limit. Rejects anything that isn't a number between 0 and `WalkCap.Max` (NaN and infinities included); rounds it and raises it to at least `WalkSpeed.Base`; saves it as `WalkCap`. |
| `DropSeeds` | RemoteEvent | C→S | none | (2026-10-08) Rate limit (`Drop.Rate`). Ignored unless the player carries seeds and their root is within `Drop.LobbyRadiusStuds` of the hub center (flat); then sets their carried count to 0 and stops a held grab. |
| `BuySeed` | RemoteEvent | C→S | `seedId: string` | (seed shop, `docs/plans/SeedShop.md`) Rate limit (`SeedShop.BuyRate`). A known seed id. Standing in the shop ring. In this restock's stock (`GameConfig.seedStock` of the server's restock number) and not yet bought out by this player (`ShopBought`). `coins ≥ Price`. Deducts, counts the purchase and adds the seed to `SeedBag` with no yield between. Handled by EconomyService. |
| `PlantSpecial` | RemoteEvent | C→S | `seedId: string, q: number, r: number` | (seed shop) Rate limit (`SeedShop.PlantRate`). A known special seed. The same plot checks as `PlantSeeds` (open row, not full, in range, alive). The plot isn't already special. Under `PerForestLimit` this forest. A seed in the bag. Then takes the seed and plants it as one seed: the plot becomes that species with the player as `starterUserId`. Handled by ForestService. |
| `StationLocked` | RemoteEvent | S→C (one) | `multiplier: number, forestsNeeded: number` | (M2b) Sent when the server refuses a locked station, so the client shows the requirement and the unlock popup. Starting a bench uses Roblox's ProximityPrompt (Triggered fires on the server), so there's no custom start remote. |

The seed rack (M3) and the benches (M2b) use ProximityPrompts, whose events fire on the server, so they need no custom remotes; `GrabSeeds` was dropped in M3.

Weather banners, the Awakening start and coin pops need no remotes: clients react to attribute changes.

## 6. How forest state reaches clients

**Attributes on `ReplicatedStorage.ForestState`** (a Folder the server creates):

| Attribute | Meaning |
| --- | --- |
| `TierId` | 1 in the MVP |
| `Seeds` | Forest Bar count; updated at each batch flush so it always matches the hexes clients see |
| `Target` | `forestTarget(plantable, SeedsPerHex)` |
| `OpenRow` | Vector2 (section, ring) of the one row open for planting, (0, 0) when the forest is complete. Replaced `UnlockedRing` after M5. Set at the batch flush, right after the HexBatch with the finishing seeds |
| `StartSide` | the section that opens first (the one the seed rack is in); banners count sections from it |
| `Center` | the grid origin (the `ForestCenter` part's position), so clients can place tiles without that part being streamed in |
| `AwakeningEndsAt` | server time (`workspace:GetServerTimeNow()`) when the break ends (cutscene + break + extensions), 0 when not running |
| `AwakeningCapAt` | the latest the break can be extended to |
| `SpringMultiplier` | this break's spring multiplier, 0 when the spring is closed |
| `Extensions` / `ExtendedBy` | extensions bought this break (which product is next) and who bought the last one |
| `Weather` / `WeatherEndsAt` | `""` or `"Rain"`; end time |
| `ServerTreeBoost` | (seed shop) everyone's training multiplier from full-grown Redwoods and Crystal Trees, 1 to 2; back to 1 at the reset |
| `TreeBoostBy` / `TreeBoostSeed` / `TreeBoosts` | (seed shop) who owns the tree that last raised it, its seed id, and a count clients watch for the banner |

**Snapshot on join** (`GetForest`). Plots are numbered once at startup in `HexGrid.rings` order after filtering; the numbering is the same for every tier. The snapshot holds:

- `seq`: the batch sequence number at the time of the snapshot
- `layout`: flat array `q, r, y` per plot index (y from the server's terrain raycast, so clients never raycast or depend on streamed terrain)
- `state`: flat array `seeds, species, mutation, starterUserId, treeSeed` per plot index (0 = none)

540 plots × 8 numbers, well within remote limits.

**Batched deltas** (`HexBatch`). ForestService marks plots dirty as seeds land and flushes every batch interval (proposed 0.1 s): `{ seq, entries }`, where `entries` is a flat array of `index, seeds, species, mutation, starterUserId, treeSeed` for each changed plot (full state, so applying one is idempotent). The client buffers batches that arrive before its snapshot and discards any with `seq ≤ snapshot.seq`. The bounce count comes from the client's old vs new seeds. If M11 shows bandwidth trouble, switch entries to a `buffer`; the format stays the same.

**Rendering.** Tiles and trees are client-created, so StreamingEnabled (on for the map) doesn't stream them. One part per tile plus a few parts per placeholder tree is about 4,000 parts for a full forest, so the MVP renders them all. If M11 measurements need it, ForestController groups plots into chunks and shows/hides chunks by distance a few times per second.

**Player attributes** (on each `Player`, so others can see them too): `Strength`, `Speed`, `Coins`, `Carried`, `ForestsCompleted`, `InSpring` (M6), `BulkPickupLevel`, `BulkPlantLevel`, `PlantingRangeLevel`, `TutorialStep`, quest flags, and (M2b) `Benching` (station name or ""), `BenchedAt` (server time) and `Running` (on an unlocked treadmill). Seed shop: `Bag_<id>` and `Bought_<id>` per seed, `ShopRestock`, `TreeBoost` (the player's own capped tree boost, 0.5 = +50%) and `SpecialsPlanted` (this forest). Capacity and walk speed are computed from these with `GameConfig`; they aren't replicated separately. These are display copies; the server reads its own tables, never attributes.

## 7. Saved player profile

One DataStore key per player (`Player_<UserId>`), session-locked, autosaved every few minutes, saved on leave and in `BindToClose`.

```lua
-- As saved since M8 (DataService's TEMPLATE). Flat upgrade levels, named like their attributes.
export type Profile = {
	Version: number, -- 1; DataService.migrate brings older saves up to date on load
	Strength: number,
	Speed: number,
	Coins: number,
	BulkPickupLevel: number,
	BulkPlantLevel: number,
	PlantingRangeLevel: number,
	ForestsCompleted: number, -- drives the gym multiplier
	SeedsPlanted: number, -- lifetime (M10); the tutorial step comes from it
	FreeGiftClaimed: number, -- 0 or 1 (M10)
	WalkCap: number, -- the player's own walk speed limit, 0 = none (2026-10-07)
	Purchases: { string }, -- the last 50 PurchaseIds of saved-data products (GUI pass: upgrade levels, seed shop: seeds)
	SeedBag: { [string]: number }, -- special seeds owned, by seed id (seed shop)
	ShopRestock: number, -- the restock ShopBought belongs to
	ShopBought: { [string]: number }, -- seeds bought in that restock, by seed id
	-- Later, with the quests (ProfileStore fills in defaults for existing saves): TreesHelped, QuestsDone
}
```

Saved with ProfileStore (`src/server/Vendor/ProfileStore.luau`, unchanged from loleris's repository) in the store `PlayerData` (`PlayerData_Studio` when playing in Studio). It autosaves every 300 s. If another server takes a profile over, or it can't be loaded, the player is kicked with a "please rejoin" message.

Not saved: carried seeds (session-only; still held on the server, lost on leave), seeds this forest, forest and weather state, the coin boost, and the seed shop's tree boosts and per-forest planting counts (kept by UserId in server memory, ended by the forest reset). The forest lives only as long as the server.

## 8. Proposed GameConfig additions

GameConfig stays unchanged for now. These numbers are needed later and will be added in the milestone that uses them (and flagged for `Balancing.xlsx`):

| Value | Proposed | Milestone |
| --- | --- | --- |
| `Planting.RackRangeStuds` | 12 | M3 (added) |
| `Planting.RangeToleranceStuds` (latency slack on the server distance check) | 4 | M4 (added) |
| `Forest.BatchSeconds` | 0.1 | M4 (added) |
| `Forest.NameLabelRangeStuds` | 40 | postponed with the name label |
| `Camera.MaxZoomStuds` | 150 (60 until 2026-10-08) | M2 |
| `Awakening` (cutscene 8 s, break 120 s, reward 500, spring odds, extensions) | see GameConfig | M6 (added) |
| `Data.AutosaveSeconds` | 180 | M8 |
| `Economy.FreeGiftCoins` | 500 | M10 |
| Quest coin rewards | ? | M10 |

## 9. Decisions and open questions

**Decided (2026-10-06):**

- Giant seed size follows the seeds currently carried, not capacity.
- The forest opens one row at a time: section by section from the rack's section, outside-in within a section; the next row opens when 100% of the current row's trees are full grown (2026-10-06, after M5; replaced whole rings opening outside-in).
- Forest complete (M6, replaces the Awakening intermission): a skippable cutscene, then a 2-minute break with the Ancient Spring; everyone online when the bar fills gets the reward.
- Free gift: a one-time 500 coins, no verification.
- Forest reward: 500 coins and +1 forests completed, no chest. The 10-minute 2x coins boost is left out for now.
- Quick Hands is dropped from the MVP shop. Its entry stays in GameConfig, unused. The plant rate limit (M4) is set from `HoldRepeatSeconds` alone.
- Saving uses ProfileStore.
- Carried seeds are session-only (server-held, not saved).
- Deferred: "help finish 10 trees" counting (M10), weather timing start-to-start vs gap (M9).
- Hex tiles (replacing the earlier mounds) are built on each client, like trees. The server only raycasts plot heights and sends them in the snapshot. Revisit only if M11 shows phone memory is tight.

No open questions remain for the architecture.
