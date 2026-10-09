--!strict
-- GameConfig: every tunable number in Plant the Forest lives here.
-- Server and client both require this module, so it belongs in ReplicatedStorage.
-- Values mirror docs/Balancing.xlsx and docs/GDD.md. Change numbers here, never inline in game code.

local GameConfig = {}

---------------------------------------------------------------------------
-- Server
---------------------------------------------------------------------------
GameConfig.Server = {
	MaxPlayers = 50, -- set this in the place's Game Settings; listed here for reference
}

---------------------------------------------------------------------------
-- Stats and training
---------------------------------------------------------------------------
GameConfig.Stats = {
	-- Every RepSeconds on a station (benching after pressing E, or standing on a treadmill) pays
	-- RepAmount * that station's multiplier.
	-- Measured in Build the Pyramid: ~10 in 2.5 s at 1x, 100 in 13 s and 50 in 6.5 s at 2x (+2 per rep).
	-- The server checks who is on a station every TrainingCheckSeconds. Planting never raises stats.
	-- 0.266 since 2026-10-07: Build the Pyramid's measured pace (btp3 clip: +40 a rep, 150 a second; was 0.25).
	RepSeconds = 0.266,
	RepAmount = 1,
	-- Every frame (was 0.05): reps of 0.266 s would otherwise land on 0.25 / 0.30 s steps and the pops would stutter.
	TrainingCheckSeconds = 1 / 60,

	-- Seeds per trip = round(max(1 + A * ((1 + Strength / K) ^ Q - 1), Sqrt * sqrt(Strength))), minimum 1.
	-- Fitted to recorded Build the Pyramid stats: 7 Strength -> 2, 55 -> 6, 1000 -> 27, 2386 -> 38,
	-- 105428 -> 171 (refit 2026-10-07; was A 19.3, K 37, Q 0.256, which gave 130 at 105428).
	-- Above about 400K Strength their capacity is a plain square root (added 2026-10-07): 120.82M -> 5200,
	-- 567.83M -> 11252, 12.841B -> 53439, all within 0.2% of Sqrt * sqrt(Strength).
	Capacity = { A = 7.57, K = 17.4, Q = 0.362, Sqrt = 0.4725 },

	-- Walk speed = Base + A * ((1 + Speed / K) ^ Q - 1), with no ceiling (players can set their own,
	-- WalkCap). Fitted to pyramid readings: 0 -> 32, 9 -> 33, 579 -> 52, 60070 -> 164 (refit 2026-10-07;
	-- the old curve stopped under 60).
	WalkSpeed = { Base = 32, A = 13.57, K = 36.2, Q = 0.32 },

	-- One bench and one treadmill per step: a station's multiplier unlocks at ForestsDone forests
	-- (credit requires ForestCreditSeeds in that forest), or with that tier's game pass.
	GymMultipliers = {
		{ ForestsDone = 0, Multiplier = 1 },
		{ ForestsDone = 1, Multiplier = 2 },
		{ ForestsDone = 3, Multiplier = 5 },
		{ ForestsDone = 8, Multiplier = 10 },
		{ ForestsDone = 15, Multiplier = 25 },
		{ ForestsDone = 25, Multiplier = 50 }, -- 50x, 75x and 100x added after M11
		{ ForestsDone = 50, Multiplier = 75 },
		{ ForestsDone = 100, Multiplier = 100 },
	},
	-- Acorns you must plant in a forest to get its reward and count it. 0 since 2026-10-07: everyone in the server
	-- when it completes gets credit, AFK players included (the user's call: they still help retention). Was 50.
	ForestCreditSeeds = 0,
}

-- The seeds you carry ride over your head as one acorn that grows with them; a full acorn (PerAcorn seeds)
-- stays full and the next one starts growing on top of it, so strong players carry a silly tower (the user's
-- call, 2026-10-08; replaced the acorns circling the head, docs/plans/AcornOrbit.md). Sizes are the acorn's
-- height in studs, growing with the cube root of its seeds (so it's like the seeds' volume). Visual only.
GameConfig.AcornStack = {
	PerAcorn = 500, -- seeds in a full acorn
	MinSize = 1.6, -- one seed
	MaxSize = 24, -- a full acorn
	MaxStack = 10, -- the most acorns in a stack: the top one stands for "lots"
}

-- The acorn sizes (studs, bottom first) that show `seeds`.
function GameConfig.acornStack(seeds: number): { number }
	local stack = GameConfig.AcornStack
	local sizes = {}
	local left = math.max(0, math.floor(seeds))
	while left > 0 and #sizes < stack.MaxStack do
		local n = math.min(left, stack.PerAcorn)
		local grown = ((n - 1) / (stack.PerAcorn - 1)) ^ (1 / 3)
		table.insert(sizes, stack.MinSize + (stack.MaxSize - stack.MinSize) * grown)
		left -= n
	end
	return sizes
end

---------------------------------------------------------------------------
-- Forest grid (same map and grid for every tier)
---------------------------------------------------------------------------
GameConfig.Grid = {
	HexSize = 16, -- studs, center to corner; neighboring trees are ~27.7 studs apart
	HubRings = 6, -- rings 0..6 are the hub (the lobby around the Ancient Tree; no planting)
	ForestRings = 9, -- rings 7..15: 594 hexes, 540 plots after the 6 walkway spokes (NoPlant parts)
	-- The walkways split the forest into 6 sections. One row (a section's plots in one ring) is open
	-- at a time: the section the seed rack is in first, then the next one around the hub. Inside a
	-- section the rows open from the outside in (OutsideIn): ring 15 first, the next ring inward once
	-- RingUnlockFill of the current row's trees are full grown (1.0 = every tree).
	OutsideIn = true,
	RingUnlockFill = 1.0,
	NoPlantTag = "NoPlant", -- CollectionService tag on volumes that block hexes (center-only check)
	TreeJitterFraction = 0.25, -- max random offset from hex center, as a fraction of HexSize
}

---------------------------------------------------------------------------
export type TierDef = {
	Id: number,
	Name: string,
	SeedsPerHex: number,
	SeedsPerPlayer: number, -- the forest's seeds per player in the server (ForestSize)
	Weight: number,
	CoinMultiplier: number,
	Commons: { string },
	WorldTree: string, -- the World Tree's models in Assets.AncientTree: <WorldTree>1-4 (AncientTreeController)
}

-- Tiers (worlds): the same forest, re-themed. A new server starts at tier 1; after every forest's break a
-- roulette picks the next one by Weight (the user's request, 2026-10-07: 80/20 with two).
-- The Forest Bar target: plantable hexes * the forest's seeds per tree, which scales with the server's players
-- when the forest starts (ForestSize, 2026-10-08; it used to be fixed at SeedsPerHex), up to SeedsPerHex.
---------------------------------------------------------------------------
GameConfig.Tiers = {
	{
		Id = 1,
		Name = "Sherwood Forest", -- was "Meadow Woods" (renamed after real forests, 2026-10-07)
		-- 540 plots -> 54,000 seeds. History: 44 (23,760), then 100, then 200 (108,000: a busy Build the Pyramid
		-- server of ~70 players does its 171,000 in 5-6 min), then back to 100 for this first, most common world
		-- only (2026-10-08, the user's call: an easier number for first-time players). The other worlds keep 200.
		SeedsPerHex = 100, -- the most a tree takes (a full server); ForestSize scales it down for small ones
		SeedsPerPlayer = 1500, -- the forest's seeds per player in the server (ForestSize)
		Weight = 60, -- how often the roulette picks it (60/30/10 since the third world, the user's call)
		CoinMultiplier = 1, -- coins per seed planted
		Commons = { "Leafy", "Pine" }, -- what the free acorns grow (Trees.Species names)
		WorldTree = "Ancient",
	},
	{
		Id = 2,
		Name = "Kyoto Forest", -- was "Sakura Bamboo Valley"
		SeedsPerHex = 200, -- each world has its own (ForestState SeedsPerHex tells the clients)
		SeedsPerPlayer = 3000, -- the later worlds are meant to be harder
		Weight = 30,
		CoinMultiplier = 2,
		Commons = { "WildSakura", "WildBamboo" },
		WorldTree = "AncientSakura", -- a bonsai-like cherry blossom World Tree with falling petals (2026-10-07)
	},
	{
		Id = 3,
		Name = "Great Smoky Mountains", -- autumn; fits fall and Halloween (2026-10-07, docs/plans/Worlds.md)
		SeedsPerHex = 200,
		SeedsPerPlayer = 3000,
		Weight = 10,
		CoinMultiplier = 3,
		Commons = { "Maple", "Birch" },
		WorldTree = "AncientMaple", -- a giant maple with falling orange leaves
	},
} :: { TierDef }

-- The roulette after each break (docs/plans/SeedShop.md, "Worlds"): it spins for SpinSeconds, shows
-- the pick for HoldSeconds, then the next forest starts as that tier.
GameConfig.Roulette = { SpinSeconds = 6, HoldSeconds = 2.5 }

---------------------------------------------------------------------------
-- Planting and growth
---------------------------------------------------------------------------
GameConfig.Planting = {
	BaseRangeStuds = 30, -- target the closest open hex within this distance (neighbors are ~27.7 apart)
	-- Holding E repeats a grab or plant this often (Hands passes make it faster). Build the Pyramid's pace,
	-- measured in two clips of the user's (0.146 and 0.15 s a press, no passes, any capacity), 2026-10-07.
	HoldRepeatSeconds = 0.15,
	-- Holding E only starts repeating after this long, like a keyboard's key repeat, so a quick tap is always one
	-- grab or plant (2026-10-07: with a Hands pass the repeat is 0.05 s, and a tap lasts longer than that, so one
	-- tap planted two). After the first repeat it runs at the usual pace.
	HoldDelaySeconds = 0.25,
	-- The dispenser's pick-up prompt shows within RackPromptStuds of the tower's middle, from any side (2026-10-07:
	-- was 10 from the basket on one side, so players had to stand right in front). The server allows a little more.
	RackPromptStuds = 18,
	RackRangeStuds = 22, -- server-side reach check for the seed rack, from its middle
	PlantRateSlack = 1.2, -- the server allows this many times the player's own pace (lag), no more
	PlantBurst = 3, -- short bursts above the rate limit are allowed
	RangeToleranceStuds = 4, -- latency slack on the server's planting distance check
}

GameConfig.Forest = {
	SnapshotRate = { PerSecond = 0.2, Burst = 2 }, -- GetForest rate limit per player
	BatchSeconds = 0.1, -- changed plots go out to every client in one HexBatch this often
}

GameConfig.Stations = {
	PromptStuds = 10, -- the bench's "Bench Press [E]" prompt shows within this distance
	BenchReachStuds = 14, -- server-side reach check when a bench prompt fires (prompt distance plus lag slack)
	LeaveRate = { PerSecond = 4, Burst = 4 }, -- LeaveBench rate limit per player
}

-- Game pass per locked station tier (multiplier -> pass id). A pass unlocks only its own tier.
-- 0 = not created yet: the unlock popup shows "Coming soon" instead of a Buy button.
GameConfig.StationPasses = {
	[2] = 2011100259, -- "2x Training", 19 Robux (prices set 2026-10-07)
	[5] = 2011256254, -- "5x Training", 89 Robux
	[10] = 2009828258, -- "10x Training", 179 Robux
	[25] = 2010956251, -- "25x Training", 360 Robux
	[50] = 2013122256, -- "50x Training", 599 Robux
	[75] = 2013122257, -- "75x Training", 729 Robux
	[100] = 2012822258, -- "100x Training", 989 Robux
} :: { [number]: number }

---------------------------------------------------------------------------
-- Robux items around the HUD (docs/plans/GUI.md). Prices live on the Creator Dashboard; the ones in
-- the comments are what they were created at.
---------------------------------------------------------------------------
export type BoostPass = { Multiplier: number, PassId: number }

-- Permanent passes that multiply the Strength or Speed gained from training (benches, treadmills,
-- the Ancient Spring). Only the highest one owned counts. The HUD sells the next one up.
GameConfig.BoostPasses = {
	-- 32x-128x Strength and 4x-16x Speed added 2026-10-07 (the user's tiers; new prices are defaults to adjust).
	Strength = {
		{ Multiplier = 2, PassId = 2013536261 }, -- 5 Robux
		{ Multiplier = 4, PassId = 2013674263 }, -- 14
		{ Multiplier = 8, PassId = 2014892259 }, -- 39
		{ Multiplier = 16, PassId = 2013842259 }, -- 99
		{ Multiplier = 32, PassId = 2016758271 }, -- 199
		{ Multiplier = 64, PassId = 2014298454 }, -- 449
		{ Multiplier = 128, PassId = 2016440281 }, -- 999
	} :: { BoostPass },
	Speed = {
		{ Multiplier = 1.5, PassId = 2012936265 }, -- 3
		{ Multiplier = 2, PassId = 2014322263 }, -- 9
		{ Multiplier = 4, PassId = 2013782265 }, -- 39 (was the 3x Speed pass at 25; renamed so its owners got 4x)
		{ Multiplier = 8, PassId = 2016032296 }, -- 99
		{ Multiplier = 16, PassId = 2013458453 }, -- 249
	} :: { BoostPass },
}

-- Hands passes (like Build the Pyramid's quick and ultra place/pickup, 2026-10-07): pick up and plant this
-- many times faster than HoldRepeatSeconds. Only the fastest one owned counts. Since the polish pass they're
-- characters: owners wear the outfit (OutfitService; Assets.Outfits.<Outfit>, accessories), an NPC of each
-- stands by the upgrade altar, and the Robux shop shows them as character cards.
-- Title: the name with its article, for "Become {Title}".
-- Feature: a GameConfig.Features flag; while it's false the character isn't shown or sold (owners keep the speed).
export type HandsPass = {
	Multiplier: number,
	PassId: number,
	Name: string,
	Title: string,
	Outfit: string,
	Pitch: string,
	Feature: string?,
}
GameConfig.HandsPasses = {
	{
		Multiplier = 2,
		PassId = 2014628378,
		Name = "Forest Ranger", -- was "Park Ranger" (renamed 2026-10-08, the user's call)
		Title = "a Forest Ranger",
		Outfit = "Ranger",
		Pitch = "2x faster pickup and planting",
	}, -- 99 Robux
	{
		Multiplier = 5, -- was 3 until 2026-10-07 (the user's call)
		PassId = 2014682392,
		Name = "Lord of the Forest", -- was "Forest Lord" (renamed 2026-10-07, the user's call)
		Title = "the Lord of the Forest",
		Outfit = "Lord",
		Feature = "LordOfTheForest", -- saved for a later update (2026-10-07)
		Pitch = "5x faster pickup and planting",
	}, -- 799 Robux
} :: { HandsPass }

-- Codes (the CODES button): each can be redeemed once per player. Names are matched ignoring case and
-- spaces. A reward gives Coins and/or Count seeds of Seed (a SeedShop id). Expires: os.time() after which it
-- stops working (nil = never). Add a code here and sync; remove it to retire it.
export type CodeReward = { Coins: number?, Seed: string?, Count: number?, Expires: number? }
GameConfig.Codes = {
	Rate = { PerSecond = 1, Burst = 3 }, -- RedeemCode rate limit per player
	MaxLength = 32,
	List = {
		RELEASE = { Coins = 1000 },
		SEEDS = { Seed = "Palm", Count = 2 },
		SAKURA = { Seed = "Sakura", Count = 1 },
	} :: { [string]: CodeReward },
}

-- Global leaderboards (LeaderboardService, boards in the lobby): these profile stats, top Size each, saved to
-- OrderedDataStores every WriteSeconds and read every ReadSeconds.
-- Ranks by forests completed (2026-10-07, the user's pick, "Forest keepers"): shown over every player's head
-- as [rank] over [name] (NameplateController). The thresholds line up with the station unlocks (1/3/8/15/25/50/
-- 100), then keep going for the long haul. Color: the rank's text color; Rainbow: a shifting rainbow instead.
export type Rank = { Forests: number, Name: string, Color: Color3, Rainbow: boolean? }
GameConfig.Ranks = {
	{ Forests = 0, Name = "Seedling", Color = Color3.fromRGB(190, 230, 160) },
	{ Forests = 1, Name = "Sprout", Color = Color3.fromRGB(130, 215, 95) },
	{ Forests = 3, Name = "Gardener", Color = Color3.fromRGB(80, 195, 75) },
	{ Forests = 8, Name = "Planter", Color = Color3.fromRGB(60, 175, 105) },
	{ Forests = 15, Name = "Woodsman", Color = Color3.fromRGB(200, 145, 80) },
	{ Forests = 25, Name = "Ranger", Color = Color3.fromRGB(225, 195, 125) },
	{ Forests = 50, Name = "Forester", Color = Color3.fromRGB(80, 205, 175) },
	{ Forests = 100, Name = "Grove Keeper", Color = Color3.fromRGB(95, 165, 255) },
	{ Forests = 250, Name = "Elder Druid", Color = Color3.fromRGB(175, 115, 255) },
	{ Forests = 500, Name = "Forest Guardian", Color = Color3.fromRGB(255, 125, 205) },
	{ Forests = 1000, Name = "Spirit of the Wild", Color = Color3.fromRGB(255, 170, 60) },
	{ Forests = 2500, Name = "World Tree Warden", Color = Color3.fromRGB(120, 255, 225) },
	{ Forests = 5000, Name = "Mother Nature", Color = Color3.fromRGB(255, 220, 90), Rainbow = true },
} :: { Rank }

-- The rank for a forests-completed count (the highest one reached).
function GameConfig.rankFor(forests: number): Rank
	local best = GameConfig.Ranks[1]
	for _, rank in GameConfig.Ranks do
		if forests >= rank.Forests then
			best = rank
		end
	end
	return best
end

GameConfig.Leaderboards = {
	-- Strength, lifetime seeds planted and Speed since 2026-10-08 (the user's call; was Most Forests in the middle).
	Stats = { "Strength", "SeedsPlanted", "Speed" },
	Titles = { Strength = "Top Strength", SeedsPlanted = "Top Seeds", Speed = "Top Speed" },
	Size = 100, -- the top 100 players (the user's call, 2026-10-08; was 50; GetSortedAsync allows at most 100)
	WriteSeconds = 120,
	ReadSeconds = 120,
}

-- Badges (BadgeAwardService). Created 2026-10-07 with the Open Cloud key (legacy-universe.badge scope), inside the
-- free daily quota, with Roblox's default icon (swap icons on the Creator Dashboard). 0 = never awarded.
GameConfig.Badges = {
	Welcome = 2846367147217306, -- "Welcome to the Forest": joined
	FirstForest = 210310046510924, -- "First Forest": completed a forest
	Forests10 = 871600761108305, -- "Forest Keeper": 10 forests
	Forests100 = 1019413497501786, -- "World Tree Legend": 100 forests
	SpecialTree = 2450395858087283, -- "Rare Bloom": planted a special seed
} :: { [string]: number }

-- Developer products under the Forest Bar: seeds go straight into the open row's trees, as the buyer's own
-- planting (their coins). The user's packs since 2026-10-07 (were 300/1,500/3,000/15,000 at 45/117/225/630, Build
-- the Pyramid's shares; then 500/1,000/2,000/5,000), doubled with the forest (108,000) so each is the same share of
-- a forest, at the same prices; each about 10% cheaper per seed than the last. Names on Roblox renamed to match.
GameConfig.BarBoosts = {
	{ Seeds = 1000, ProductId = 3716976602 }, -- 49 Robux ("+1,000 Forest seeds")
	{ Seeds = 2000, ProductId = 3716976605 }, -- 89
	{ Seeds = 4000, ProductId = 3716976607 }, -- 159
	{ Seeds = 10000, ProductId = 3716976609 }, -- 349
}

-- "BOOST Server Training!" in the Robux shop: everyone's training gains times Multiplier; each
-- purchase adds Seconds.
GameConfig.ServerBoost = { Multiplier = 2, Seconds = 900, ProductId = 3716976610 } -- 45 Robux

-- Upgrade levels for Robux (the second button in the altar shop): ids[n] buys level n.
-- Every level has one since 2026-10-07 (levels 6+ were added then): 9, 19, 39, 79, 149, then about 1.6x a level:
-- 239, 379, 599, 949, 1,499, 2,399, 3,799 Robux (Planting Range stops at level 10).
GameConfig.UpgradeProducts = {
	BulkPickup = {
		3716976612,
		3716976613,
		3716976616,
		3716976622,
		3716976625,
		3717159400,
		3717159402,
		3717159403,
		3717159404,
		3717159406,
		3717159407,
		3717159409,
	},
	BulkPlant = {
		3716976627,
		3716976628,
		3716976631,
		3716976633,
		3716976634,
		3717159413,
		3717159415,
		3717159419,
		3717159424,
		3717159426,
		3717159429,
		3717159430,
	},
	PlantingRange = {
		3716976635,
		3716976636,
		3716976638,
		3716976639,
		3716976641,
		3717159432,
		3717159434,
		3717159436,
		3717159438,
		3717159439,
	},
} :: { [string]: { number } }

-- Planting coins +PerFriend for each Roblox friend in the same server, up to Max.
GameConfig.FriendBoost = { PerFriend = 0.1, Max = 0.5 }

-- A player's own walk speed limit (Settings' Speed limit slider and box), never under WalkSpeed.Base.
-- 0 = no limit (their full earned speed).
GameConfig.WalkCap = {
	Max = 100_000, -- the server rejects bigger values
	Rate = { PerSecond = 8, Burst = 8 }, -- SetWalkCap rate limit per player
}

-- Dropping the seeds you carry (Q, 2026-10-08, the user's ask), anywhere (it was lobby only at first, the same day).
GameConfig.Drop = {
	Rate = { PerSecond = 2, Burst = 3 }, -- DropSeeds rate limit per player
}

GameConfig.Camera = {
	-- 150 since 2026-10-08 (the user wanted more zoom out; was 60, below the canopies). Obstacles fade (Invisicam)
	-- instead of pulling the camera in.
	MaxZoomStuds = 150,
}

GameConfig.Dev = {
	MaxStatValue = 10_000_000, -- Studio-only DevCommand values must be between 0 and this
	CommandRate = { PerSecond = 5, Burst = 10 },
}

GameConfig.Growth = {
	-- 8 model stages (docs/plans/TreeStages.md), packed toward the start so early seeds change the tree
	-- often. Stage k starts once a tree has StageStarts[k] of its seeds (rounded up, at least 1 seed);
	-- the last stage (full grown) is the last seed. At 200 seeds they start at seeds 1, 10, 24, 42, 70, 106,
	-- 148 and 200: seedling, sprout, sapling, small, young, growing, mature, full grown.
	StageStarts = { 0, 0.05, 0.12, 0.21, 0.35, 0.53, 0.74, 1.0 },
	BounceSeconds = 0.25, -- squash-and-stretch per seed
}

---------------------------------------------------------------------------
-- Economy and upgrades
---------------------------------------------------------------------------
GameConfig.Economy = {
	CoinsPerSeed = 1, -- multiplied by the tree's mutation multiplier
	AwakeningBoost = { CoinMultiplier = 2, DurationSeconds = 600 }, -- unused since M6 (left out for now)
	BuyRate = { PerSecond = 4, Burst = 4 }, -- BuyUpgrade rate limit per player
	FreeGiftCoins = 500, -- the free gift (like and favorite), once per player ever (M10)
	GiftRate = { PerSecond = 1, Burst = 2 }, -- ClaimFreeGift rate limit per player
	ShopRingSlackStuds = 4, -- latency slack on the server's "standing in the shop ring" check
}

-- Player settings (the Settings button): SetSetting's rate limit per player.
GameConfig.Settings = {
	Rate = { PerSecond = 4, Burst = 4 },
}

-- The first-time experience (docs/plans/M10.md). The tutorial step comes from saved progress.
-- Since 2026-10-07 (the user's request) it's a fixed sequence, saved as TutorialStep (TutorialService):
-- 0 the story intro, then each step in Steps (1-6), then DoneStep. Players who had planted before it existed
-- start at DoneStep.
GameConfig.Tutorial = {
	TrainedStrength = 20, -- the Train step ends here (carrying 3; was 10, carrying 2)
	TrainedSpeed = 20, -- the TrainSpeed step ends here (about 5 s on the 1x treadmill)
	ShopCoins = 50, -- the cheapest upgrade: the Shop step tops a new player's coins up to this
	-- In order; the step number is the index. TutorialService checks when each is done.
	-- TrainSpeed added 2026-10-07 (the user's call): train Speed too, not only Strength. A player saved at the old
	-- DoneStep (7) lands on Shop, which finishes at once if they own any upgrade.
	Steps = { "PickUp", "Plant", "Train", "TrainSpeed", "PickUpMore", "PlantMore", "Shop" },
	DoneStep = 8,
	IntroRate = { PerSecond = 1, Burst = 2 }, -- TutorialIntroDone rate limit per player
	-- After the tutorial: a player who plants RemindTrips loads in a row without training gets a gentle tip for
	-- RemindSeconds ("Tip: train to carry more and walk faster", arrow to their best station), at most once every
	-- RemindCooldown seconds (the user's idea, 2026-10-07).
	RemindTrips = 4,
	RemindSeconds = 12,
	RemindCooldown = 300,
}

-- The upgrades sold at the shop, in the order the shop lists them (M7).
GameConfig.ShopUpgrades = { "BulkPickup", "BulkPlant", "PlantingRange" }

---------------------------------------------------------------------------
-- Feature flags: whole features that are built but can be switched off for a release (2026-10-07). Flip one
-- and sync; nothing else needs changing.
-- SeedShop: the seed stall, special seeds and their tree boosts. Off for the MVP (the user's call): the stall
-- and its ring are taken out of the map, buying and planting special seeds are refused, codes that give
-- seeds don't work, and the seed bag / restock line aren't shown. Saved seed bags are kept for later.
---------------------------------------------------------------------------
-- A/B tests (2026-10-08). LayoutTest: each server picks at random whether its forests open from the outer ring in
-- (OuterFirst, OuterFirstShare of servers) or from the hub out (InnerFirst), publishes it as ForestState Layout /
-- OutsideIn, and every forest analytics event records it (docs/plans/TuningSignals.md). Off: every server uses
-- Grid.OutsideIn.
GameConfig.Experiments = {
	LayoutTest = true,
	-- 1 = every server outer-first (2026-10-08, the user's call: too few players to split yet; was 0.8). Lower it
	-- (for example 0.8) to run the test.
	OuterFirstShare = 1,
}

GameConfig.Features = {
	SeedShop = false,
	-- The Lord of the Forest character (the NPC, its stand and shop card; the pass is off sale on Roblox too). Saved
	-- for a later update (2026-10-07). To release: set true, rerun nothing, and put pass 2014682392 back on sale.
	LordOfTheForest = false,
}

-- The character passes on show and for sale (HandsPasses whose Feature flag isn't off).
function GameConfig.availableHandsPasses(): { HandsPass }
	local list = {}
	for _, pass in GameConfig.HandsPasses do
		if not pass.Feature or GameConfig.Features[pass.Feature] ~= false then
			table.insert(list, pass)
		end
	end
	return list
end

---------------------------------------------------------------------------
-- The seed shop (docs/plans/SeedShop.md): special seeds for coins, in a stock that changes every
-- RestockSeconds (the same stock in every server, from seedStock). Planting one turns a Common tree in the
-- open row into that special tree; once it's full grown, its owner trains faster (OwnerBoost, +0.5 = +50%)
-- and the rarest also speed up everyone's training (ServerBoost), until the forest resets.
---------------------------------------------------------------------------
export type SeedDef = {
	Id: string, -- the species name in Trees.Species; its model is Assets.Seeds.<Id>Seed
	DisplayName: string,
	Rarity: string, -- a key of Trees.RarityColors
	OwnerBoost: number,
	ServerBoost: number,
	Price: number, -- coins
	StockChance: number, -- chance to be in a restock
	StockMin: number,
	StockMax: number,
	ProductId: number, -- "Buy for R$" developer product (0 = not created)
}

GameConfig.SeedShop = {
	RestockSeconds = 300,
	PerForestLimit = 3, -- special seeds each player can plant per forest
	-- Rebalanced 2026-10-07 (the user's go-ahead): smaller boosts and caps, about 3x the prices. Was caps +300%
	-- and 2x, boosts +25/50/50/100/200% (server +0.25x/+0.5x) at 250/750/900/2,000/6,000 coins.
	OwnerBoostCap = 0.75, -- a player's own tree boosts add up to at most +75%
	ServerBoostCap = 0.2, -- server-wide tree boosts add up to at most +0.2 (1.2x, under the Robux server boost)
	BuyRate = { PerSecond = 4, Burst = 4 },
	PlantRate = { PerSecond = 4, Burst = 4 },
	Seeds = { -- in shop order
		{
			Id = "Palm",
			DisplayName = "Palm",
			Rarity = "Uncommon",
			OwnerBoost = 0.05,
			ServerBoost = 0,
			Price = 600,
			StockChance = 0.8,
			StockMin = 1,
			StockMax = 3,
			ProductId = 3717008517, -- 19 Robux
		},
		{
			Id = "Sakura",
			DisplayName = "Cherry Blossom",
			Rarity = "Rare",
			OwnerBoost = 0.1,
			ServerBoost = 0,
			Price = 1800,
			StockChance = 0.45,
			StockMin = 1,
			StockMax = 2,
			ProductId = 3717008518, -- 49 Robux
		},
		{
			Id = "Bamboo",
			DisplayName = "Bamboo",
			Rarity = "Rare",
			OwnerBoost = 0.1,
			ServerBoost = 0,
			Price = 2000,
			StockChance = 0.35,
			StockMin = 1,
			StockMax = 2,
			ProductId = 3717012082, -- 49 Robux
		},
		{
			Id = "Redwood",
			DisplayName = "Redwood",
			Rarity = "Epic",
			OwnerBoost = 0.2,
			ServerBoost = 0.05,
			Price = 6000,
			StockChance = 0.15,
			StockMin = 1,
			StockMax = 1,
			ProductId = 3717008521, -- 99 Robux
		},
		{
			Id = "Crystal",
			DisplayName = "Crystal Tree",
			Rarity = "Legendary",
			OwnerBoost = 0.4,
			ServerBoost = 0.1,
			Price = 18000,
			StockChance = 0.04,
			StockMin = 1,
			StockMax = 1,
			ProductId = 3717008522, -- 249 Robux
		},
	} :: { SeedDef },
}

---------------------------------------------------------------------------
-- Forest complete (docs/plans/M6.md): everyone online gets the reward, a cutscene plays, then a break
-- with the Ancient Spring open before the next forest starts.
---------------------------------------------------------------------------
export type SpringOdds = { Multiplier: number, Weight: number }

GameConfig.Awakening = {
	CutsceneSeconds = 8,
	BreakSeconds = 120, -- after the cutscene; Robux extensions add to it
	RewardCoins = 500, -- to everyone online when the bar fills, with +1 forests completed
	-- The Ancient Spring: standing inside this radius of the hub center during the break trains
	-- Strength and Speed together, RepAmount * your best unlocked station * the spring multiplier each per rep.
	-- 43 since 2026-10-08 (was 72): the World Tree and its rune circle are drawn at 60% to fit the training
	-- pads in the garden around it (AncientTreeController FINAL_SCALE); the pads start 54 studs out.
	SpringRadiusStuds = 43,
	-- Rolled once per break for the whole server; Weight is out of the total of all weights.
	SpringOdds = {
		{ Multiplier = 2, Weight = 75 },
		{ Multiplier = 3, Weight = 15 },
		{ Multiplier = 5, Weight = 10 },
	} :: { SpringOdds },
	-- During the break the Forest Bar's buttons sell break time for the whole server, like Build the Pyramid's
	-- (2026-10-07): +1/+5/+10/+50 minutes, up to MaxBreakMinutes left on the clock (Build the Pyramid allows 60;
	-- the user's pick is 30). Prices live on Roblox: 45, 117, 225, 399 Robux. (These reuse
	-- the old escalating +1:00 extension products; 3716952644 and 3716952647 were taken off sale.)
	MaxBreakMinutes = 30,
	BreakTime = {
		{ Minutes = 1, ProductId = 3716952621 },
		{ Minutes = 5, ProductId = 3716952635 },
		{ Minutes = 10, ProductId = 3716952636 },
		{ Minutes = 20, ProductId = 3716952641 }, -- was +50 at 630 until the 30-minute cap
	},
	-- The "PICK!" button switches those buttons to the worlds: buying one makes it the next forest for everyone
	-- (the roulette lands on it). WorldPicks[i] sells Tiers[i]; 99 Robux each. The last purchase wins.
	WorldPicks = { 3717157966, 3717157968, 3717157970 },
}

export type UpgradeDef = {
	DisplayName: string,
	BaseCost: number,
	Growth: number,
	MaxLevel: number,
	ValuePerLevel: { number }, -- index 0 is "no upgrade", so ValuePerLevel[level + 1]
}

-- Cost of level n = round(BaseCost * Growth ^ (n - 1)).
-- 2026-10-07 (the user's call): more levels, each 2.5x the last, so coins stay useful for the whole climb to
-- the 100x station. Was 5 levels each at 4x (Bulk 50/200/800/3,200/12,800, Range 60/180/540/1,620/4,860).
-- Bulk: 50, 125, 313, 781, 1,953, 4,883, 12,207, 30,518, 76,294, 190,735, 476,837, 1,192,093 (2.0M in all).
-- Range: 60, 150, 375, 938, 2,344, 5,859, 14,648, 36,621, 91,553, 228,882 (381K in all).
-- Robux levels (UpgradeProducts) cover every level.
GameConfig.Upgrades = {
	BulkPickup = { -- seeds grabbed per press at the rack
		DisplayName = "Bulk Pickup",
		BaseCost = 50,
		Growth = 2.5,
		MaxLevel = 12,
		ValuePerLevel = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 }, -- +1 per level
	},
	BulkPlant = { -- seeds planted per press
		DisplayName = "Bulk Plant",
		BaseCost = 50,
		Growth = 2.5,
		MaxLevel = 12,
		ValuePerLevel = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 }, -- +1 per level
	},
	QuickHands = { -- planting animation speed multiplier
		DisplayName = "Quick Hands",
		BaseCost = 100,
		Growth = 3,
		MaxLevel = 5,
		ValuePerLevel = { 1, 1.15, 1.3, 1.45, 1.6, 1.75 },
	},
	PlantingRange = { -- extra studs of targeting range (+4 per level)
		DisplayName = "Planting Range",
		BaseCost = 60,
		Growth = 2.5,
		MaxLevel = 10,
		ValuePerLevel = { 0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40 },
	},
} :: { [string]: UpgradeDef }

---------------------------------------------------------------------------
-- Weather (MVP ships Rain only; the rest are phase 1 after MVP)
---------------------------------------------------------------------------
export type WeatherDef = {
	Mutation: string,
	CoinMultiplier: number,
	ChancePerTree: number, -- rolled when a tree's first seed lands during the event
	PickWeight: number,
	Enabled: boolean,
}

GameConfig.Weather = {
	IntervalSeconds = 600,
	DurationSeconds = 150,
	Events = {
		Rain = { Mutation = "Wet", CoinMultiplier = 2, ChancePerTree = 0.20, PickWeight = 40, Enabled = true },
		Snowfall = { Mutation = "Frozen", CoinMultiplier = 3, ChancePerTree = 0.12, PickWeight = 25, Enabled = false },
		Thunderstorm = { Mutation = "Shocked", CoinMultiplier = 5, ChancePerTree = 0.06, PickWeight = 20, Enabled = false },
		MeteorShower = { Mutation = "Cosmic", CoinMultiplier = 10, ChancePerTree = 0.03, PickWeight = 10, Enabled = false },
		GoldenHour = { Mutation = "Golden", CoinMultiplier = 20, ChancePerTree = 0.01, PickWeight = 5, Enabled = false },
	} :: { [string]: WeatherDef },
}

---------------------------------------------------------------------------
-- Formulas
---------------------------------------------------------------------------
function GameConfig.capacity(strength: number): number
	local c = GameConfig.Stats.Capacity
	strength = math.max(strength, 0)
	local value = math.max(1 + c.A * ((1 + strength / c.K) ^ c.Q - 1), c.Sqrt * math.sqrt(strength))
	return math.max(1, math.round(value))
end

function GameConfig.walkSpeed(speed: number): number
	local w = GameConfig.Stats.WalkSpeed
	return w.Base + w.A * ((1 + math.max(speed, 0) / w.K) ^ w.Q - 1)
end

-- Forests needed to unlock the station with this multiplier (nil if it isn't on the ladder).
function GameConfig.forestsForMultiplier(multiplier: number): number?
	for _, step in GameConfig.Stats.GymMultipliers do
		if step.Multiplier == multiplier then
			return step.ForestsDone
		end
	end
	return nil
end

function GameConfig.upgradeCost(upgradeId: string, level: number): number?
	local def = GameConfig.Upgrades[upgradeId]
	if not def or level < 1 or level > def.MaxLevel then
		return nil
	end
	return math.round(def.BaseCost * def.Growth ^ (level - 1))
end

function GameConfig.upgradeValue(upgradeId: string, level: number): number
	local def = GameConfig.Upgrades[upgradeId]
	local clamped = math.clamp(level, 0, def.MaxLevel)
	return def.ValuePerLevel[clamped + 1]
end

-- Returns 0 (empty mound), else the model stage 1..#StageStarts (the last one is full grown).
function GameConfig.growthStage(seeds: number, seedsPerHex: number): number
	if seeds <= 0 then
		return 0
	end
	local starts = GameConfig.Growth.StageStarts
	local stage = 1
	for k = 2, #starts do
		-- The tiny slack keeps exact products (0.5 * 44) from rounding up past the seed they land on.
		if seeds >= math.max(1, math.ceil(starts[k] * seedsPerHex - 1e-9)) then
			stage = k
		end
	end
	return stage
end

-- The spring multiplier for a roll in [0, 1).
function GameConfig.springMultiplier(roll: number): number
	local odds = GameConfig.Awakening.SpringOdds
	local total = 0
	for _, entry in odds do
		total += entry.Weight
	end
	local pick = roll * total
	for _, entry in odds do
		pick -= entry.Weight
		if pick < 0 then
			return entry.Multiplier
		end
	end
	return odds[#odds].Multiplier
end

-- The forest's size follows the server (2026-10-08, the user's call: small servers never finished a forest). When a
-- forest starts, each tree takes enough seeds for SeedsPerPlayer per player in the server, at least MinSeedsPerHex
-- and at most the world's SeedsPerHex, so a forest takes about the same time with 3 players or 50 (aim: 20-40 min
-- for new players). It stays fixed while that forest grows. Off: always the world's SeedsPerHex.
GameConfig.ForestSize = {
	ScaleWithPlayers = true,
	MinSeedsPerHex = 5, -- a solo forest: 540 trees x 5 = 2,700 seeds
}

-- Seeds per tree for a forest of `plots` trees in world `tier` with `players` in the server.
function GameConfig.seedsPerHexFor(tier: TierDef, players: number, plots: number): number
	local size = GameConfig.ForestSize
	if not size.ScaleWithPlayers or plots <= 0 then
		return tier.SeedsPerHex
	end
	local wanted = math.ceil(players * tier.SeedsPerPlayer / plots)
	return math.clamp(wanted, size.MinSeedsPerHex, tier.SeedsPerHex)
end

function GameConfig.forestTarget(plantableHexes: number, seedsPerHex: number): number
	return plantableHexes * seedsPerHex
end

-- The tier the roulette lands on for a roll in [0, 1), by Weight.
function GameConfig.pickTier(roll: number): number
	local total = 0
	for _, tier in GameConfig.Tiers do
		total += tier.Weight
	end
	local pick = roll * total
	for i, tier in GameConfig.Tiers do
		pick -= tier.Weight
		if pick < 0 then
			return i
		end
	end
	return #GameConfig.Tiers
end

-- Seconds between a player's grabs or plants while holding E, for their Hands speed (1 = no pass).
function GameConfig.pressSeconds(handsSpeed: number): number
	return GameConfig.Planting.HoldRepeatSeconds / math.max(1, handsSpeed)
end

function GameConfig.seedDef(id: string): SeedDef?
	for _, def in GameConfig.SeedShop.Seeds do
		if def.Id == id then
			return def
		end
	end
	return nil
end

-- The restock number at a server time (workspace:GetServerTimeNow(), on the server and the clients).
function GameConfig.restockIndex(serverTime: number): number
	return math.floor(serverTime / GameConfig.SeedShop.RestockSeconds)
end

-- How many of each seed restock n has (0 = not in stock). The same n gives the same stock on every
-- server and client: Random with a given seed is the same everywhere. Every seed always draws both
-- numbers, so changing one seed's odds doesn't reshuffle the others.
function GameConfig.seedStock(restock: number): { [string]: number }
	local rng = Random.new(restock)
	local stock = {}
	for _, def in GameConfig.SeedShop.Seeds do
		local roll = rng:NextNumber()
		local amount = rng:NextInteger(def.StockMin, def.StockMax)
		stock[def.Id] = if roll < def.StockChance then amount else 0
	end
	return stock
end

return GameConfig
