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
-- Since the bridge they're plank bundles (CarryController): the size is the bundle's height, which grows about like a
-- stack of planks for small counts (one plank 0.45 thick, 6 about 1.4) and slows down for big ones (Curve); the
-- bundle's length and width grow only a little with it. Was MinSize 1.6, MaxSize 24 and a cube-root curve: 6 planks
-- were a 9-stud block (the user's note, 2026-10-10).
GameConfig.AcornStack = {
	PerAcorn = 500, -- seeds in a full acorn (planks in a full bundle)
	MinSize = 0.45, -- one plank
	MaxSize = 10, -- a full bundle
	Curve = 0.5, -- the growth's power: 1/3 was like volume (big fast), 1/2 grows more like a stack
	MaxStack = 10, -- the most acorns in a stack: the top one stands for "lots"
}

-- The acorn sizes (studs, bottom first) that show `seeds`.
function GameConfig.acornStack(seeds: number): { number }
	local stack = GameConfig.AcornStack
	local sizes = {}
	local left = math.max(0, math.floor(seeds))
	while left > 0 and #sizes < stack.MaxStack do
		local n = math.min(left, stack.PerAcorn)
		local grown = ((n - 1) / (stack.PerAcorn - 1)) ^ stack.Curve
		table.insert(sizes, stack.MinSize + (stack.MaxSize - stack.MinSize) * grown)
		left -= n
	end
	return sizes
end

---------------------------------------------------------------------------
-- Bridge grid (Build Across the Grand Canyon, 2026-10-10; was the forest's hex grid)
---------------------------------------------------------------------------
-- The bridge is a grid of square slots (the old "plots"): Columns across, Rows from the near rim to the far rim,
-- starting at the part tagged BridgeStart (its LookVector points across the canyon). A slot is finished when it
-- holds its planks (the old "seeds per tree"), and a row is the old "ring": one row is open at a time, from the rim
-- out. Code and attributes still say plot, seeds, ring and forest; the player sees slots, planks, rows and bridge.
GameConfig.Grid = {
	Columns = 8, -- slots across the bridge: 80 studs (3, then 5 until 2026-10-10, the user's calls)
	SlotStuds = 10, -- a slot's size, across and along the bridge
	-- 3,000 studs to the far rim (300 rows; 90 until the real-canyon map, 2026-10-10: the gap is the Toroweap stretch
	-- of the Grand Canyon, tools/canyon_heightmap.py). The first bridges are shorter (Rounds).
	Rows = 300,
	-- The next row opens once RingUnlockFill of the open row's slots are finished (1.0 = every slot).
	RingUnlockFill = 1.0,
	-- A slot this many rows past the open row opens early once the slot behind it is finished, so the bridge creeps
	-- out behind finished slots. 0 = only the open row.
	AheadRings = 1,
	PlanksPerSlot = 8, -- planks drawn on a full slot: one more per growth stage (visual only)
	-- Conveyor belts (2026-10-10, the user's idea): two lanes of finished rows move you, one out toward the far rim and
	-- one back to camp. The whole belt runs at one speed (2026-10-10, the user's call: it used to speed up with distance),
	-- set from how far the bridge has got: a player walking at BaseWalk on it reaches the end in about TripSeconds
	-- whatever the bridge's length (speed = length / TripSeconds - BaseWalk, at least 0, at most Max), so a quarter-built
	-- and a three-quarter-built bridge take about the same trip. Faster walkers still arrive sooner. The outward belt
	-- slows to a stop over the last RampStuds before the unfinished end, so nobody is carried off it. Client-side
	-- (BridgeController). Lanes 3 (out) and 6 (back) of 8: walking lanes on both edges and in the middle. They never
	-- run slower than MinSpeed (2026-10-10, the user's call: until about row 65 they stood still and looked broken).
	-- Much faster since 2026-10-11 (the user's call: a new player joining a far-along bridge took far too long to reach
	-- its end and place a first plank): about 7 s end to end (was 20), up to 450 studs/s (was 250), slowing over the last
	-- 120 studs (was 40, too sudden at these speeds). The Hint for riding them: TutorialController beltTip, once the
	-- built bridge is TipStuds long, until you've ridden each belt TipRides times.
	Belts = {
		Out = 3,
		Back = 6,
		TripSeconds = 6.1, -- 7 until the user's "15% faster" (2026-10-11)
		BaseWalk = 32,
		MinSpeed = 35,
		Max = 520,
		RampStuds = 120,
		TipStuds = 200,
		TipRides = 2,
		Width = 1.5, -- the belt deck's width in slots: 50% wider than its lane (2026-10-11, players slid off it)
	},
	-- The arch under the deck (2026-10-10, the user's asks: the Navajo Bridge's steel lattice, then a modern bridge, after
	-- the Hoover Dam Bypass's concrete arch): one arch from rim to rim, Depth studs below the deck where it meets the rims
	-- (inside the cliffs: it comes out of the rock about 175 studs out) and Crown studs below it in the middle, two
	-- concrete ribs RibInset in from the deck's edges, each rib RibEnd deep at the walls and RibCrown at the top. A
	-- finished row gets its piece of the arch, the deck beam, columns and struts (BridgeController). Visual only.
	Arch = { Depth = 520, Crown = 30, RibInset = 10, RibEnd = 44, RibCrown = 16 }, -- ribs deeper since the concrete arch (were 26, 8, 30, 9)
	-- The unfinished end (2026-10-10, the user's ask): an invisible floor reaches EdgeAheadRows rows past the furthest
	-- finished slot, across the whole width, with invisible walls EdgeWallStuds tall across its end and along its sides,
	-- so builders can step out over the slots they're filling without falling into the canyon. It moves out as the
	-- bridge grows and goes once the bridge is done (BridgeController).
	EdgeAheadRows = 1,
	EdgeWallStuds = 30,
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
	-- The map it's built on (2026-10-11): a ServerStorage.Maps folder, swapped in by MapService when this canyon is next.
	Map: string,
	Town: string, -- the town across the canyon, named in the story and the Spring's banner (its sign: tools/build_town.luau)
	Called: string, -- the canyon's name in a sentence ("Across the Grand Canyon lies ...")
	Place: string, -- where the real canyon is, under its name on the loading screen (MapLoadingController)
}

-- Tiers (worlds): the same forest, re-themed. A new server starts at tier 1; after every forest's break a
-- roulette picks the next one by Weight (the user's request, 2026-10-07: 80/20 with two).
-- The Forest Bar target: plantable hexes * the forest's seeds per tree, which scales with the server's players
-- when the forest starts (ForestSize, 2026-10-08; it used to be fixed at SeedsPerHex), up to SeedsPerHex.
---------------------------------------------------------------------------
GameConfig.Tiers = {
	{
		Id = 1,
		Name = "Grand Canyon", -- was "Sherwood Forest" (the bridge, 2026-10-10; before that "Meadow Woods")
		-- 540 plots -> 54,000 seeds. History: 44 (23,760), then 100, then 200 (108,000: a busy Build the Pyramid
		-- server of ~70 players does its 171,000 in 5-6 min), then back to 100 for this first, most common world
		-- only (2026-10-08, the user's call: an easier number for first-time players). The other worlds keep 200.
		-- A fixed bridge since 2026-10-11 (the user's call: a fixed number per map, about 20,000 planks): 8 planks a slot x
		-- 2,400 slots = 19,200, whatever the server's size (ForestSize.ScaleWithPlayers off). Was 100, scaled down per server.
		SeedsPerHex = 8,
		SeedsPerPlayer = 1500, -- the forest's seeds per player in the server (ForestSize)
		Weight = 50, -- how often the roulette picks it (50/30/10 since 2026-10-08; was 60/30/10, the user's calls)
		CoinMultiplier = 1, -- coins per seed planted
		Commons = { "Leafy", "Pine" }, -- what the free acorns grow (Trees.Species names)
		WorldTree = "Ancient",
		Map = "GrandCanyon",
		Town = "Springtown",
		Called = "the Grand Canyon",
		Place = "Toroweap Overlook, Arizona",
	},
	{
		Id = 2,
		Name = "Verdon Gorge", -- 2026-10-11 (the user's pick, replacing "Bryce Canyon"; before that "Kyoto Forest")
		SeedsPerHex = 17, -- 40,800 planks: about twice the Grand Canyon's, like before (was 200, scaled per server)
		SeedsPerPlayer = 3000, -- the later worlds are meant to be harder
		Weight = 30,
		CoinMultiplier = 2,
		Commons = { "WildSakura", "WildBamboo" },
		WorldTree = "AncientSakura", -- a bonsai-like cherry blossom World Tree with falling petals (2026-10-07)
		Map = "Verdon", -- the Grand Canyon du Verdon in Provence, above La Mescla
		Town = "Moustiers",
		Called = "the Verdon Gorge",
		Place = "Provence, France",
	},
	{
		Id = 3,
		Name = "Zion Canyon", -- was "Great Smoky Mountains": autumn; fits fall and Halloween (2026-10-07, docs/plans/Worlds.md)
		SeedsPerHex = 17, -- 40,800 planks, like the Verdon Gorge
		SeedsPerPlayer = 3000,
		Weight = 10,
		CoinMultiplier = 3,
		Commons = { "Maple", "Birch" },
		WorldTree = "AncientMaple", -- a giant maple with falling orange leaves
		Map = "Zion", -- the real Zion Canyon at Zion Lodge (2026-10-11)
		Town = "Springdale", -- the real town at Zion's gate
		Called = "Zion Canyon",
		Place = "Zion National Park, Utah",
	},
} :: { TierDef }

-- Each map's building material (2026-10-11, the user's ask: not wooden planks everywhere), keyed by Tiers[].Map: the
-- bridge's deck and the pieces landing on its slots (BridgeController), the planks players carry (CarryController) and
-- the camp's pile (MapService). Visual only. They were all wood until then.
export type Deck = { Color: Color3, Material: Enum.Material }
GameConfig.Decks = {
	GrandCanyon = { Color = Color3.fromRGB(200, 196, 188), Material = Enum.Material.Concrete }, -- concrete slabs, like its arch
	Zion = { Color = Color3.fromRGB(122, 128, 134), Material = Enum.Material.DiamondPlate }, -- steel deck plates
	Verdon = { Color = Color3.fromRGB(66, 68, 74), Material = Enum.Material.Asphalt }, -- a motorway, like the Millau Viaduct's
} :: { [string]: Deck }

-- Each map's loading-screen picture (2026-10-11, the user's ask): its finished bridge from the side, shot in a playtest
-- (assets/loading/<Map>.png, uploaded as "Loading <Map> v1"). MapLoadingController shows it behind "HEADING TO ...".
GameConfig.LoadingArt = {
	GrandCanyon = "rbxassetid://115867595401804",
	Zion = "rbxassetid://137169909481215",
	Verdon = "rbxassetid://124553784255450",
} :: { [string]: string }

-- The material for a map (Workspace.Map CurrentMap), the Grand Canyon's when unknown.
function GameConfig.deckFor(map: unknown): Deck
	return GameConfig.Decks[if typeof(map) == "string" then map else "GrandCanyon"] or GameConfig.Decks.GrandCanyon
end

-- The live canyon's tier from ForestState TierId (tier 1 when unset), e.g. for its Town's name on the client.
function GameConfig.tierFor(id: unknown): TierDef
	return GameConfig.Tiers[if typeof(id) == "number" then id else 1] or GameConfig.Tiers[1]
end

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
	RackPromptStuds = 26, -- 26 since the one big lumber pile (2026-10-10; was 18): its whole edge is in reach
	-- The server's reach check: the prompt's own reach (MaxActivationDistance from where it sits) plus this, for lag
	-- and a step while holding. Since 2026-10-10: it measured from the tagged pile's edge, and the big pile's prompt
	-- reached stacks beyond that one, so grabs there silently failed.
	RackSlackStuds = 4,
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
export type Boost = { Multiplier: number, ProductId: number, PassId: number }

-- Permanent boosts that multiply the Strength or Speed gained from training (benches, treadmills,
-- the Ancient Spring). Only the highest one counts. The HUD sells the next one up.
-- Developer products since 2026-10-08 (the user's call: game passes only for the Forest Ranger and the
-- training areas). A purchase is saved in the profile (StrengthBoostBought / SpeedBoostBought). PassId is
-- the old game pass, now off sale: anyone who bought it keeps that boost (PassService).
GameConfig.Boosts = {
	-- 32x-128x Strength and 4x-16x Speed added 2026-10-07 (the user's tiers; new prices are defaults to adjust).
	Strength = {
		{ Multiplier = 2, ProductId = 3717371274, PassId = 2013536261 }, -- 5 Robux
		{ Multiplier = 4, ProductId = 3717371278, PassId = 2013674263 }, -- 14
		{ Multiplier = 8, ProductId = 3717371279, PassId = 2014892259 }, -- 39
		{ Multiplier = 16, ProductId = 3717371280, PassId = 2013842259 }, -- 99
		{ Multiplier = 32, ProductId = 3717371283, PassId = 2016758271 }, -- 199
		{ Multiplier = 64, ProductId = 3717371284, PassId = 2014298454 }, -- 449
		{ Multiplier = 128, ProductId = 3717371287, PassId = 2016440281 }, -- 999
	} :: { Boost },
	Speed = {
		{ Multiplier = 1.5, ProductId = 3717371291, PassId = 2012936265 }, -- 3
		{ Multiplier = 2, ProductId = 3717371293, PassId = 2014322263 }, -- 9
		{ Multiplier = 4, ProductId = 3717371294, PassId = 2013782265 }, -- 39
		{ Multiplier = 8, ProductId = 3717371295, PassId = 2016032296 }, -- 99
		{ Multiplier = 16, ProductId = 3717371297, PassId = 2013458453 }, -- 249
	} :: { Boost },
}

-- The gnome (2026-10-09, the user's call, like Build the Pyramid dressing everyone as a pyramid worker): every player
-- is a forest gnome, the whole avatar replaced (OutfitService). The user's picks: the Gnome Cap Fitted, the Man Face
-- (a dynamic head, its mood and brows), gnome skin and no shirt or pants; the white Chin Beard is the default from the
-- cap's creator. Character pass outfits (the Forest Ranger) go on top, their hat in place of the cap. Catalog ids;
-- Roblox lets a game put any catalog item on players for free. Enabled = false gives everyone their own avatar again.
GameConfig.Gnome = {
	Enabled = true,
	-- A construction crew since the bridge (2026-10-10, the user's ask): a hard hat (was the Gnome Cap Fitted, 15349453580)
	-- and a hi-vis vest; the gnome's face, beard and skin stay.
	-- Roblox's own Builders Club Hard Hat (yellow) since 2026-10-11 (the user's call; was the Construction Worker Helmet,
	-- 14570885448): it shares its helmet with the Turbo and Outrageous ones, so the ranks can wear their looks (Ranks[].Hat).
	Hat = 1080951,
	Vest = 14438332755, -- Highway Worker's Hi-Vis Vest (orange), a front accessory
	-- No beard since 2026-10-10 (the user's call; was the white Chin Beard, 15349673453). Blue jeans instead of bare legs.
	Pants = 129458426, -- "Jeans" by Roblox (classic pants)
	Head = 10725826963, -- Man Face - Head (bundle 949)
	Mood = 10725833199, -- Man Face - Mood
	Brows = 10725837187, -- Man Face - Brows
	Skin = Color3.fromRGB(240, 190, 150), -- the whole body: a warm, rosy gnome skin
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
	BridgeMultiplier: number?, -- bridges credited per finished bridge (AwakeningService; 1 without it)
	-- Coins to buy the character instead of its pass (2026-10-11, the user's call: a coin route, with Robux the
	-- shortcut). Same perks either way. Each needs the character before it (bought either way); saved as
	-- CharacterBought (EconomyService BuyCharacter, PassService).
	CoinPrice: number?,
}
GameConfig.HandsPasses = {
	{
		Multiplier = 2,
		PassId = 2014628378,
		-- Classic Builderman since 2026-10-10 (the user's call): the orange Turbo Builders Club hard hat (11844853, by
		-- Roblox), the dark ROBLOX jacket over a red shirt (112994945824909) and jeans (103556544337033), both by Cedar
		-- Apparel. Was the Canyon Ranger / Forest Ranger / Park Ranger; its kit is in ServerStorage.PlantTreesMap.
		Name = "Builderman",
		Title = "Builderman",
		Outfit = "Builderman",
		-- 2x bridges since 2026-10-10 (the user's call): every bridge finished counts 2 toward the owner's bridges (the
		-- gym unlocks, titles, badges and the Top Bridges board).
		BridgeMultiplier = 2,
		Pitch = "2x faster pickup and building, 2x bridges",
		CoinPrice = 100_000,
	}, -- 129 Robux (99 until 2026-10-11, the user's call)
	{
		Multiplier = 5, -- was 3 until 2026-10-07 (the user's call)
		PassId = 2014682392,
		-- God of Hammers since 2026-10-11 (the user's call): a yellow construction-robot suit after the user's picture
		-- (hard hat with a headlamp, a face screen with glowing eyes, chunky plates, a sledgehammer on the back); a
		-- Thor-style armor the same day and the God of Construction's golden armor before that, the shelved Lord of the
		-- Forest before that (its NPC in ServerStorage.SavedForLater). Built in Blender
		-- (tools/blender/build_god_of_hammers.py), welded onto the body (Assets.Outfits.God, OutfitService).
		-- BuilderBot™ since 2026-10-11 (the user's call: a corporate robot's brand name, ™ on the T); the outfit key, the
		-- feature flag and the files keep the God of Hammers names.
		Name = "BuilderBot™",
		Title = "BuilderBot™",
		Outfit = "God",
		Feature = "GodOfHammers",
		BridgeMultiplier = 3,
		Pitch = "5x faster pickup and building, 3x bridges",
		CoinPrice = 400_000,
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
-- Ranks by forests completed (2026-10-07, the user's pick, "Forest keepers"; builder titles since the bridge, 2026-10-10): shown over every player's head
-- as [rank] over [name] (NameplateController). The thresholds line up with the station unlocks (1/3/8/15/25/50/
-- 100), then five more up to 1,000 (2026-10-11, the user's call; they ran to 5,000). Color: the rank's text color; Rainbow: a shifting rainbow instead.
-- Hat: the crew hard hat's look at that rank (OutfitService, the Hats window; 2026-10-11, the user's asks). Every one is
-- Roblox's Builders Club Hard Hat helmet in a two-color paint, a main color and an accent on its brim and ridge like
-- Roblox's own: an ordinary yellow site helmet first, then Roblox's Builders Club, Turbo and (higher up) Outrageous
-- textures, and between them textures painted from tools/hardhat_accent_mask.png (which part of the helmet's texture is
-- the brim and ridge, read off the Builders Club hat in Studio). Material: metal, glass, neon. Rainbow: the color
-- cycles over the texture (a white shell, a dark accent). Pass outfits wear their own hat.
export type RankHat = { Texture: string, Material: Enum.Material?, Rainbow: boolean? }
export type Rank = { Forests: number, Name: string, Color: Color3, Rainbow: boolean?, Hat: RankHat }
local M = Enum.Material
GameConfig.Ranks = {
	{
		Forests = 0,
		Name = "Apprentice",
		Color = Color3.fromRGB(190, 230, 160),
		Hat = { Texture = "rbxassetid://128227323943984" },
	}, -- yellow / amber
	{
		Forests = 1,
		Name = "Plank Hauler",
		Color = Color3.fromRGB(130, 215, 95),
		Hat = { Texture = "http://www.roblox.com/asset/?id=112346870" },
	}, -- Builders Club (1080951)
	{
		Forests = 3,
		Name = "Carpenter",
		Color = Color3.fromRGB(80, 195, 75),
		Hat = { Texture = "http://www.roblox.com/asset/?id=11844713" },
	}, -- Turbo (11844853)
	{ Forests = 8, Name = "Builder", Color = Color3.fromRGB(60, 175, 105), Hat = { Texture = "rbxassetid://138876048972164" } }, -- blue / white
	{ Forests = 15, Name = "Foreman", Color = Color3.fromRGB(200, 145, 80), Hat = { Texture = "rbxassetid://89869483720162" } }, -- white / red
	{
		Forests = 25,
		Name = "Engineer",
		Color = Color3.fromRGB(225, 195, 125),
		Hat = { Texture = "rbxassetid://113749201428670" },
	}, -- green / yellow
	{
		Forests = 50,
		Name = "Master Builder",
		Color = Color3.fromRGB(80, 205, 175),
		Hat = { Texture = "rbxassetid://71705459068954" },
	}, -- black / orange
	{
		Forests = 100,
		Name = "Bridge Keeper",
		Color = Color3.fromRGB(95, 165, 255),
		Hat = { Texture = "rbxassetid://112295885532635", Material = M.Metal },
	}, -- bronze / brown
	{
		Forests = 175,
		Name = "Canyon Crosser",
		Color = Color3.fromRGB(175, 115, 255),
		Hat = { Texture = "rbxassetid://109820992493650", Material = M.Metal },
	}, -- silver / blue
	{
		Forests = 300,
		Name = "Canyon Guardian",
		Color = Color3.fromRGB(255, 125, 205),
		Hat = { Texture = "http://www.roblox.com/asset/?id=17169223" },
	}, -- Outrageous (17408283)
	{
		Forests = 500,
		Name = "Spirit of the Canyon",
		Color = Color3.fromRGB(255, 170, 60),
		Hat = { Texture = "rbxassetid://140648761940990", Material = M.Glass },
	}, -- ice / white
	{
		Forests = 750,
		Name = "Grand Architect",
		Color = Color3.fromRGB(120, 255, 225),
		Hat = { Texture = "rbxassetid://89852165013451", Material = M.Neon },
	}, -- purple / gold
	{
		Forests = 1000,
		Name = "Legend of the Canyon",
		Color = Color3.fromRGB(255, 220, 90),
		Rainbow = true,
		Hat = { Texture = "rbxassetid://122588147674118", Material = M.Neon, Rainbow = true },
	}, -- rainbow / dark
} :: { Rank }

-- The rank's place in Ranks for a forests-completed count (the highest one reached).
function GameConfig.rankIndexFor(forests: number): number
	local best = 1
	for i, rank in GameConfig.Ranks do
		if forests >= rank.Forests then
			best = i
		end
	end
	return best
end

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
	-- Forests, lifetime seeds planted, Strength and Speed, in that order (the user's call, 2026-10-08; it was
	-- Strength, Seeds, Speed earlier that day, and Most Forests in the middle before).
	Stats = { "ForestsCompleted", "SeedsPlanted", "Strength", "Speed" },
	Titles = {
		ForestsCompleted = "Top Bridges",
		SeedsPlanted = "Top Planks",
		Strength = "Top Strength",
		Speed = "Top Speed",
	},
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
-- Since 2026-10-11 (the user's call) each is a share of the current bridge (its Target), not a fixed count: the bridge
-- grows with the server (2,400 planks solo, 76,800 at 50 players), and +10,000 was four solo bridges. The buttons show
-- the planks live (barBoostPlanks) and grey out when the pack is bigger than what's left. Each still about 10%
-- cheaper per plank than the last.
GameConfig.BarBoosts = {
	{ Share = 0.025, ProductId = 3716976602 }, -- 49 Robux
	{ Share = 0.05, ProductId = 3716976605 }, -- 89
	{ Share = 0.1, ProductId = 3716976607 }, -- 159
	{ Share = 0.25, ProductId = 3716976609 }, -- 349
}

-- A bar pack's planks for a bridge of `target` planks: its share, to the nearest 10 from 100 up, at least 1.
function GameConfig.barBoostPlanks(share: number, target: number): number
	local planks = share * target
	return if planks >= 100 then math.floor(planks / 10 + 0.5) * 10 else math.max(1, math.floor(planks + 0.5))
end

-- "BOOST Server Training!" in the Robux shop: everyone's training gains times Multiplier; each
-- purchase adds Seconds.
GameConfig.ServerBoost = { Multiplier = 2, Seconds = 900, ProductId = 3716976610 } -- 45 Robux

-- Auto Build (2026-10-11, the user's call, after docs/notes/Economy review.md): one game pass that picks up planks while
-- you stand at the pile (CarryService, the server) and places them while you're in reach of an open slot
-- (CarryController, like holding E), at the player's normal pace. They still walk the planks out themselves.
-- Published as the AutoBuild attribute (PassService). Created at 199 Robux.
GameConfig.AutoBuild = { PassId = 2025243018, CheckSeconds = 0.05 }

-- Upgrade levels for Robux (the second button in the altar shop): ids[n] buys level n.
-- Every level has one since 2026-10-07 (levels 6+ were added then). Bulk Pickup and Bulk Build since 2026-10-11 (the
-- user's call, docs/notes/Economy review.md: about 1 Robux per 150 coins of the level's coin cost, after the coin costs
-- were cut): 5, 9, 14, 19, 29, 39, 49, 69, 99, 129, 179, 249 Robux (were 9 ... 3,799). Build Range: 9, 19, 39, 79.
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
	-- Lucky Planks levels 1-10 (2026-10-11, the user's ask): 49, 99, 199, 349, 599, 999, 1,699, 2,999, 4,999, 9,999 Robux
	-- (the top ones extremely high, like the coin costs).
	LuckyPlanks = {
		3718031285,
		3718031292,
		3718031295,
		3718031298,
		3718031303,
		3718031309,
		3718031313,
		3718031317,
		3718031322,
		3718031327,
	},
	PlantingRange = { -- 4 levels since 2026-10-09; products 5-10 (3716976641, 3717159432-39) are off sale
		3716976635,
		3716976636,
		3716976638,
		3716976639,
	},
} :: { [string]: { number } }

-- The daily login reward (2026-10-11, the user's ask): a 7-day streak, Rewards[day] coins, claimed once per UTC day.
-- Missing a day starts again at day 1; after day 7 it goes round again.
-- Gyms: a day that unlocks a gym tier for good instead of its coins (2026-10-11, the user's call: day 2 opens the 5x gym,
-- normally 3 bridges or its 89-Robux pass, to bring new players back). Only while that gym isn't open to them yet
-- (by bridges or an earlier streak); then the day pays its coins.
GameConfig.Daily = {
	Rewards = { 250, 500, 750, 1000, 1500, 2000, 3000 },
	Gyms = { [2] = 5 } :: { [number]: number },
	ClaimRate = { PerSecond = 1, Burst = 2 },
}

-- The UTC day number for a time (seconds since 1970): the daily reward's calendar.
function GameConfig.dayOf(seconds: number): number
	return math.floor(seconds / 86400)
end

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

-- The edge of the walkable world (2026-10-10, the user's call): invisible walls (tools/build_boundary.luau, Workspace.Map
-- .Boundary) a little inside the terrain's area (tools/canyon_heightmap.py X_MIN..X_MAX, Z_MIN..Z_MAX), since past it
-- the canyon is look-only scenery that players fell through. Within WarnStuds of a wall a banner turns players back,
-- at most once every WarnSeconds (BoundaryController).
GameConfig.Boundary = {
	X0 = -4920,
	X1 = 700,
	Z0 = -1940,
	Z1 = 1940,
	WarnStuds = 80,
	WarnSeconds = 8,
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
	-- The free gift (one since 2026-10-11, the user's ask): like the game, favorite it and join the group, then Claim;
	-- once per player ever. Only the favorite (Roblox's prompt) and the group (the server) are checked. 1,250 = what the
	-- three separate gifts paid (500 favorite, 500 group, 250 like); a default the user can change.
	FreeGiftCoins = 1250,
	-- And free stats with it (2026-10-11, the user's ask; the amounts are the reference game's): 1,500 each is about 6.5
	-- minutes on a 1x station (one rep a RepSeconds), taking a new player from 1 to about 32 planks a trip and walk
	-- speed 32 to about 63.
	FreeGiftStrength = 1500,
	FreeGiftSpeed = 1500,
	GiftRate = { PerSecond = 1, Burst = 2 }, -- ClaimFreeGift rate limit per player
	GroupId = 336242048, -- the community the gift asks players to join
	-- The first tree a player ever finishes (planting its last acorn): confetti and these coins, about two first
	-- upgrades (2026-10-09, the user's call: most new players left before any win).
	FirstTreeCoins = 100,
	ShopRingSlackStuds = 4, -- latency slack on the server's "standing in the shop ring" check
}

-- The starter quests (docs/plans/Quests.md, 2026-10-09): one at a time, in order, from the end of the tutorial. Each
-- counts one of the player's saved numbers (Stat; "UpgradeLevels" = the three upgrades' levels added up), pays Reward
-- coins when claimed at Goal, and the next one starts. Lifetime numbers, so progress made earlier counts.
export type Quest = { Id: string, Text: string, Stat: string, Goal: number, Reward: number }
GameConfig.Quests = {
	{ Id = "GrowTrees", Text = "Finish 3 bridge sections", Stat = "TreesFinished", Goal = 3, Reward = 50 },
	{ Id = "Strength100", Text = "Reach 100 Strength", Stat = "Strength", Goal = 100, Reward = 75 },
	{ Id = "Speed50", Text = "Reach 50 Speed", Stat = "Speed", Goal = 50, Reward = 75 },
	{ Id = "Plant250", Text = "Place 250 planks", Stat = "SeedsPlanted", Goal = 250, Reward = 100 },
	{ Id = "Ring", Text = "Help finish a row", Stat = "RingsHelped", Goal = 1, Reward = 150 },
	{ Id = "Upgrades3", Text = "Buy 3 upgrades", Stat = "UpgradeLevels", Goal = 3, Reward = 150 },
	{ Id = "Strength1000", Text = "Reach 1,000 Strength", Stat = "Strength", Goal = 1000, Reward = 200 },
	{ Id = "Forest", Text = "Finish a bridge", Stat = "ForestsCompleted", Goal = 1, Reward = 300 },
} :: { Quest }
GameConfig.QuestClaimRate = { PerSecond = 2, Burst = 3 } -- ClaimQuest rate limit per player

-- A quest's progress from the player's numbers (`value` reads one: the profile on the server, attributes on clients).
function GameConfig.questProgress(quest: Quest, value: (name: string) -> number): number
	if quest.Stat == "UpgradeLevels" then
		return value("BulkPickupLevel") + value("BulkPlantLevel") + value("PlantingRangeLevel")
	end
	return value(quest.Stat)
end

-- Player settings (the Settings button): SetSetting's rate limit per player.
GameConfig.Settings = {
	Rate = { PerSecond = 4, Burst = 4 },
}

-- The first-time experience (docs/plans/M10.md). The tutorial step comes from saved progress.
-- Since 2026-10-07 (the user's request) it's a fixed sequence, saved as TutorialStep (TutorialService):
-- 0 the story intro, then each step in Steps (1-7), then DoneStep. Players who had planted before it existed
-- start at DoneStep.
GameConfig.Tutorial = {
	TrainedStrength = 20, -- the Train step ends here (carrying 3; was 10, carrying 2)
	TrainedSpeed = 20, -- the TrainSpeed step ends here (about 5 s on the 1x treadmill)
	ShopCoins = 50, -- the cheapest upgrade: the Shop step tops a new player's coins up to this
	ShopUpgrade = "BulkPickup", -- the upgrade the Shop step spotlights (2026-10-09, the user's call)
	-- In order; the step number is the index. TutorialService checks when each is done.
	-- 5 steps since 2026-10-10 (the user's call): "fill up on planks" and "place them all" repeated steps 1-2 and were
	-- cut (launch data: a third of new players left mid-tutorial). Saves past the end land on DoneStep (DataService).
	-- 7 since 2026-10-11 (the user's call): after the shop, fill up on planks (the new Bulk Pickup at work), then
	-- "Start building!" until the first plank goes on. Saves from before (Version < 3) at 6+ count as finished.
	Steps = { "PickUp", "Plant", "Train", "TrainSpeed", "Shop", "PickUpMore", "Build" },
	DoneStep = 8,
	IntroRate = { PerSecond = 1, Burst = 2 }, -- TutorialIntroDone rate limit per player
	-- After the tutorial: a player who plants RemindTrips loads in a row without training gets a gentle tip for
	-- RemindSeconds ("Tip: train to carry more and walk faster", arrow to their best station), at most once every
	-- RemindCooldown seconds (the user's idea, 2026-10-07).
	RemindTrips = 4,
	RemindSeconds = 12,
	RemindCooldown = 300,
	RemindMaxStrength = 200, -- no tip once Strength is over this (the user's ask, 2026-10-08)
}

-- The upgrades sold at the shop, in the order the shop lists them (M7).
GameConfig.ShopUpgrades = { "BulkPickup", "BulkPlant", "PlantingRange", "LuckyPlanks" }

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
-- Rounds (2026-10-09, the user's idea, from the launch-day data: only 24 of 257 new players finished a forest). A
-- server's first forests are smaller: forest 1 opens only the 2 rings next to the hub, forest 2 the inner 4, forest 3
-- the inner 6, and from forest 4 every ring. Each forest still starts empty after the break, and seeds per tree are
-- the same as a full forest's (ForestSize), so a round's target is just its trees x that. The rings outside the
-- round are hidden (plain ground) and fade in when a round grows. On: forests always open from the hub out (the
-- layout A/B test is ignored) and every forest analytics event says "Round N" instead of the layout.
-- The field (2026-10-09, the user's call: a forest all around the spawn wasn't clear about where to go, unlike Build
-- the Pyramid's one pile and one pyramid). The forest is only the half of the island across the World Tree from the
-- town (the spawn, shop, NPCs, gift boards and leaderboards, all on the hub's +X side): plots whose angle around the
-- hub is within HalfAngle degrees of Facing (degrees from +X). Only the acorn dispensers facing the field stay (4 of
-- the 6), and the spawn turns to face the World Tree (ForestService.init, at runtime: the place itself is unchanged).
-- Enabled = false brings back the forest all around, with all six dispensers.
GameConfig.Field = {
	-- Off since the rectangular construction site (2026-10-10): the one plank pile stands in the middle of camp, which
	-- this would count as the town's side and remove; the map script aims the spawn itself.
	Enabled = false,
	Facing = 180,
	HalfAngle = 90,
}

-- Is a point at this angle around the hub (degrees from +X) in the field?
function GameConfig.inField(angle: number): boolean
	local field = GameConfig.Field
	return not field.Enabled or math.abs((angle - field.Facing + 180) % 360 - 180) <= field.HalfAngle + 1e-6
end

GameConfig.Rounds = {
	-- Off since 2026-10-10 (the user's call): every bridge goes all the way across, and the conveyor belts keep the long
	-- trips short. On: a server's first bridges are only Rings[1], Rings[2] rows long.
	Enabled = false,
	-- The rows of the server's bridge 1, 2 while on; after the list, all of them (Grid.Rows). The map has no buttes for
	-- these short bridges to end on any more (they were taken out with the rounds).
	Rings = { 40, 120 },
	-- Every row of a small round open at once: off for the bridge (you can only reach the end you're standing at).
	OpenWholeRound = false,
}

GameConfig.Experiments = {
	LayoutTest = false, -- off for the bridge: it always grows from the rim out
	-- 1 = every server outer-first (2026-10-08, the user's call: too few players to split yet; was 0.8). Lower it
	-- (for example 0.8) to run the test.
	OuterFirstShare = 1,
}

GameConfig.Features = {
	SeedShop = false,
	-- The God of Hammers character (its NPC and shop card), on pass 2014682392 (the God of Construction until
	-- 2026-10-11, the shelved Lord of the Forest before: off 2026-10-07 to 2026-10-11).
	GodOfHammers = true,
	-- The tutorial's story intro (the camera sweep over the island to the World Tree; switched off 2026-10-09, the
	-- user's call). Off: a new player loads at the first tutorial step (TutorialStep 1) instead of 0.
	TutorialIntro = true, -- back on 2026-10-10 with the Springtown story (off from 2026-10-09: the old one was about the World Tree)
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
	-- To everyone online when the bridge is finished, times the canyon's CoinMultiplier (1,500 / 3,000 / 4,500), with +1
	-- bridges completed. 1,500 since 2026-10-11 (the user: 500 felt low; a player's plank share pays ~1,500-2,400).
	RewardCoins = 1500,
	-- The Ancient Spring: standing inside this radius of the hub center during the break trains
	-- Strength and Speed together, RepAmount * your best unlocked station * the spring multiplier each per rep.
	-- 43 since 2026-10-08 (was 72): the World Tree and its rune circle are drawn at 60% to fit the training
	-- pads in the garden around it (AncientTreeController FINAL_SCALE); the pads start 54 studs out.
	SpringRadiusStuds = 43,
	-- Where the Spring is (2026-10-10, the user's ask): on the far rim's landing, this far past the end of a full bridge,
	-- so the reward for finishing is walking across it. ForestService publishes it as ForestState SpringCenter.
	SpringBeyondStuds = 60,
	-- Up the tree (2026-10-09, the user's idea, like Build the Pyramid's well inside the finished pyramid): the
	-- Spring is a round platform SpringRadiusStuds wide this high up in the World Tree's canopy, reached by a wooden
	-- ramp spiraling around the trunk (TreeClimbService). Both are there only during the break. 0 = the Spring on the
	-- ground around the trunk again, with no climb. 110: just under Sherwood's canopy (about 121 up), inside the
	-- maple's and the cherry blossom's.
	SpringHeightStuds = 0, -- 0 since the bridge (2026-10-10): no World Tree to climb, the Spring is at the hub's center (was 110)
	-- The ramp: its middle this far from the trunk (outside the platform), this wide, rising this much per stud
	-- walked (0.28: about 390 studs of ramp, 1.3 turns; ~25 s at a new player's walk speed), starting at this angle
	-- (radians from the hub's +X side, toward the spawn) and winding clockwise seen from above.
	Climb = { Radius = 49, Width = 10, Slope = 0.28, StartAngle = 0 },
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
	Costs: { number }, -- Costs[n]: coins for level n
	MaxLevel: number,
	ValuePerLevel: { number }, -- index 0 is "no upgrade", so ValuePerLevel[level + 1]
}

-- Coins per level, a list since 2026-10-11 (the user's call, compared with another game's 75/200/500/1,100/2,100/4,000/
-- 7,500/12,000): each step grows a little less than the last (2.5x easing to ~1.4x), so the early levels stay cheap and
-- the top is reachable in a few dozen bridges. Was round(BaseCost * Growth ^ (n - 1)): Bulk 50 x2.5 a level (1.19M at
-- level 12, 2.0M in all), Range 300 x8 (153,600 at level 4).
-- Robux levels (UpgradeProducts) cover every level.
local BULK_COSTS = { 50, 125, 300, 650, 1300, 2400, 4200, 7000, 11000, 17000, 25000, 36000 }
GameConfig.Upgrades = {
	BulkPickup = { -- seeds grabbed per press at the rack
		DisplayName = "Bulk Pickup",
		Costs = BULK_COSTS,
		MaxLevel = 12,
		ValuePerLevel = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 }, -- +1 per level
	},
	BulkPlant = { -- seeds planted per press
		DisplayName = "Bulk Build",
		Costs = BULK_COSTS,
		MaxLevel = 12,
		ValuePerLevel = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 }, -- +1 per level
	},
	QuickHands = { -- planting animation speed multiplier
		DisplayName = "Quick Hands",
		Costs = { 100, 300, 900, 2700, 8100 }, -- unused (no Quick Hands upgrade yet)
		MaxLevel = 5,
		ValuePerLevel = { 1, 1.15, 1.3, 1.45, 1.6, 1.75 },
	},
	-- Extra studs of targeting range: each level reaches one more tree (trees are ~27.7 studs apart; the base 30
	-- reaches the next tree). 4 big levels since 2026-10-09 (the user's call: 10 levels of +4 studs were hardly felt).
	PlantingRange = {
		DisplayName = "Build Range",
		Costs = { 300, 1500, 6000, 20000 },
		MaxLevel = 4,
		-- +10 studs a level since the bridge (2026-10-10): one more row of 10-stud sections (was +28, one more tree).
		ValuePerLevel = { 0, 10, 20, 30, 40 },
	},
	-- Lucky Planks (2026-10-11, the user's idea, docs/notes/Economy review.md): each plank placed has this chance to come
	-- back to your hands, so a load goes further (50% means every other plank comes back: twice the planks per trip). The
	-- user's ladder: 5% at level 1, then +5% a level to 50% at 10 (it was 0.5% steps, then 2% steps), with the top
	-- levels priced extremely high (5M coins for 50%). The roll is ForestService's. Robux levels too (UpgradeProducts).
	LuckyPlanks = {
		DisplayName = "Lucky Planks",
		Costs = { 5000, 15000, 40000, 90000, 180000, 350000, 650000, 1200000, 2500000, 5000000 },
		MaxLevel = 10,
		ValuePerLevel = { 0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5 },
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
	return def.Costs[level]
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
	-- Off since 2026-10-11 (the user's call): every bridge is its world's fixed size (Tiers[].SeedsPerHex), so more players
	-- build it faster. SeedsPerPlayer and MinSeedsPerHex only count when this is on.
	ScaleWithPlayers = false,
	-- 1 since 2026-10-10 (the user's call, docs/notes/Progression review.md): the bridge has 2,400 slots, so 3 made a
	-- solo bridge 7,200 planks (about 2.5 hours for a new player); 1 gives a solo player 2,400, the same share as each
	-- player in a 2-player server. (5 until 2026-10-09, then 3, for the forest's 540 trees.)
	MinSeedsPerHex = 1,
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

-- Where the climb up the World Tree starts, on the ground (Awakening.Climb): for the first-break guide's arrow.
function GameConfig.climbStart(center: Vector3): Vector3
	local climb = GameConfig.Awakening.Climb
	return center + Vector3.new(math.cos(climb.StartAngle), 0, math.sin(climb.StartAngle)) * climb.Radius
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
