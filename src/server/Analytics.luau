--!strict
-- Analytics: AnalyticsService events for the soft launch (2026-10-07). Server only; every call is wrapped,
-- so analytics can never break gameplay. Events show on the Creator Hub after about a day.
-- - Onboarding funnel (newcomers only: players with no forest completed yet; each step once per session):
--   Joined, PickedUpSeeds, PlantedSeed, Trained, BoughtUpgrade, CompletedForest.
-- - Coins economy: sources (planting, summed per player and sent once a minute because every seed pays,
--   the forest reward, the free gift) and sinks (upgrades, special seeds), each with the balance after.
-- - Custom events: SeedBought and SpecialSeedPlanted, with the seed id as a field.
-- - Playtime funnels (2026-10-07), checked every CHECK_SECONDS: SessionLength (this visit, one funnel per
--   join) and LifetimePlaytime (the saved PlayTimeSeconds attribute, one funnel per player). ForestMilestones
--   (the forests that unlock station tiers) is logged by AwakeningService through forestMilestone().
-- - ForestLoop (one funnel per player per forest): InServer, PlantedAcorn, Planted50, Completed, SawRoulette,
--   PlantedNextForest (logged on the forest they completed, when they first plant in the next one).
--   ForestService calls forestStarted() and forestPlanted(); AwakeningService forestCompleted() and roulette().
-- - RobuxShop (one funnel per shop opening): Opened (the client's RobuxShopOpened), Prompted and Purchased
--   (Roblox's prompt-finished events, for prompts within SHOP_SESSION_SECONDS of opening the shop).
-- - LockedStation (one funnel per locked try): Tried (stationLocked(), from TrainingService), Prompted and
--   Purchased (the station pass's prompt). A prompt counts for whichever of the two was started last.
-- - LeftGame (custom event, when a loaded player leaves): the visit's minutes, sliced by capacity, forests
--   completed and upgrade levels bought, each grouped into a few bands (custom fields need few values).
-- - The break after a forest (AwakeningService calls breakStarted() and breakEnded()): each player's activity
--   is sampled every second (Spring, Training, AFK or Walking) and purchases are noted (Upgrade, Seed,
--   Robux). At the end, BreakActivity per player: seconds there, their main activity, what they bought and
--   how much of it was in the Spring. Leaving during the break logs LeftDuringBreak with the main activity.
-- - The forest report (2026-10-08, the user's ask: is a forest too long, and why?), once per completed forest:
--   ForestCompleted (value: minutes from the forest's start), ForestBoughtSeeds (seeds bought into its bar), and
--   ForestStatMedian / ForestStatAverage for each stat that sets the pace (the Stat field: Strength, Speed,
--   Capacity, WalkSpeed, PickupPerPress, PlantPerPress, PlantingRange, HandsSpeed, SeedsPlanted, SeedsPerTree), over the players
--   who planted in it. Each is sliced by the server's player count (a band) and the world.
-- - Rings and trees (2026-10-08): RingCompleted (value: minutes the ring took; fields: which ring and its size, the
--   player-count band, world and layout), TreeGap per player per forest (value: average seconds between the trees
--   they finished, i.e. planted the last seed of; fields: how many, the player-count band, world and layout) and
--   LeftAt on every leave (value: the visit's minutes; fields: where in the forest, i.e. the open ring and how far
--   along it was, or the break; world and layout; the player-count band).
-- - Every forest event carries the server's layout (ForestState Layout: the A/B test, GameConfig.Experiments).
-- - The first minutes (2026-10-09): LeftAt names the tutorial step instead of the ring while the player is in
--   the tutorial, TutorialStepSeconds times each step, LockedTry says which locked station and which tutorial
--   step, and visits are timed from the join (they used to start at the first playtime check, up to 30 s late).

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Guard)

local PLANTING_FLUSH_SECONDS = 60 -- AnalyticsService allows 120 + 20 per player calls a minute
local CHECK_SECONDS = 30 -- how often the playtime funnels are checked
local SESSION_MINUTES = { 1, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120 }
local LIFETIME_MINUTES = { 10, 30, 60, 120, 300, 600, 1200, 3000 }
local FOREST_MILESTONES = { 1, 3, 8, 15, 25, 50, 100 } -- the station unlocks (GameConfig.Stats.GymMultipliers)
local SHOP_SESSION_SECONDS = 300 -- a purchase prompt this soon after opening the shop counts for its funnel
local LOCKED_SESSION_SECONDS = 120 -- the same for a locked station; trying it again sooner isn't a new funnel
local SHOP_OPEN_RATE = { PerSecond = 1, Burst = 3 }
-- LeftGame bands: each value goes in the band of the biggest edge it reaches.
local CAPACITY_BANDS = { 1, 10, 25, 50, 100, 250, 500, 1000 }
local FOREST_BANDS = { 0, 1, 3, 8, 15, 25, 50, 100 } -- the station unlocks
local UPGRADE_BANDS = { 0, 1, 5, 10, 15, 20, 30 } -- the three upgrades' levels added up (max 34)
local UPGRADES = { "BulkPickupLevel", "BulkPlantLevel", "PlantingRangeLevel" }
local BREAK_SAMPLE_SECONDS = 1
local AFK_SECONDS = 20 -- standing (almost) still this long, off the stations and out of the Spring, is AFK
local AFK_STUDS = 2 -- moving less than this in a sample counts as standing still
local CURRENCY = "Coins"
local STEPS = {
	Joined = 1,
	PickedUpSeeds = 2,
	PlantedSeed = 3,
	Trained = 4,
	BoughtUpgrade = 5,
	CompletedForest = 6,
}
export type Step = "Joined" | "PickedUpSeeds" | "PlantedSeed" | "Trained" | "BoughtUpgrade" | "CompletedForest"

local Analytics = {}

local logged: { [Player]: { [string]: boolean } } = {}
local planting: { [Player]: number } = {} -- planting coins not sent yet
type Session = { id: string, started: number, sessionStep: number, lifetimeStep: number }
local sessions: { [Player]: Session } = {}
local joinedAt: { [Player]: number } = {} -- the visit's clock starts here, not at the first playtime check
local stepStartedAt: { [Player]: number } = {} -- when they reached their tutorial step (or joined)
-- ForestLoop: the forest now running, and each player's progress in it.
local forestRound = HttpService:GenerateGUID(false)
type ForestProgress = {
	round: string,
	planted: number,
	completed: string?,
	firstPlantAt: number?, -- when they first planted in this forest
	lastTreeAt: number?, -- when they last finished a tree in it
	trees: number,
	gapSum: number,
	gapReported: boolean,
}
local forestProgress: { [Player]: ForestProgress } = {}
local forestStartedAt = os.clock() -- the first forest starts with the server
local forestBoughtSeeds = 0
local PLAYER_BANDS = { 1, 2, 5, 10, 20, 30, 40, 50 }
local TREE_BANDS = { 1, 2, 5, 10, 20, 50 }
local PROGRESS_BANDS = { 0, 25, 50, 75 } -- percent of the open ring's trees full grown
local ringStartedAt = os.clock()
local ringIndex = 1 -- the open ring, counted in opening order
-- RobuxShop and LockedStation: the purchase funnel each player has open, if any.
type Purchase = { funnel: string, id: string, at: number, multiplier: number? }
local purchases: { [Player]: Purchase } = {}
-- The break: what each player is doing (nil when no break is on).
type BreakLog = { seconds: { [string]: number }, bought: { [string]: boolean }, lastPosition: Vector3?, still: number }
local breakLogs: { [Player]: BreakLog }? = nil

local function coins(player: Player): number
	local value = player:GetAttribute("Coins")
	return if typeof(value) == "number" then value else 0
end

local function safely(f: () -> ())
	xpcall(f, function(err)
		warn(`[Analytics] {err}`)
	end)
end

-- One onboarding step, for players who haven't completed a forest yet (CompletedForest is logged just
-- before the count goes up, so it's the first one), once per step per session.
function Analytics.onboarding(player: Player, step: Step)
	local forests = player:GetAttribute("ForestsCompleted")
	if typeof(forests) == "number" and forests > 0 then
		return
	end
	local done = logged[player]
	if not done then
		done = {}
		logged[player] = done
	end
	if done[step] then
		return
	end
	done[step] = true
	safely(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, STEPS[step], step)
	end)
end

-- Coins earned (after they were added). Planting coins are summed and sent once a minute.
function Analytics.earned(player: Player, amount: number, sku: string, transaction: Enum.AnalyticsEconomyTransactionType)
	if amount <= 0 then
		return
	end
	safely(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			CURRENCY,
			amount,
			coins(player),
			transaction.Name,
			sku
		)
	end)
end

function Analytics.plantingCoins(player: Player, amount: number)
	planting[player] = (planting[player] or 0) + amount
end

local function boughtDuringBreak(player: Player, kind: string)
	local logs = breakLogs
	local log = logs and logs[player]
	if log then
		log.bought[kind] = true
	end
end

-- Coins spent (after they were taken).
function Analytics.spent(player: Player, amount: number, sku: string)
	boughtDuringBreak(player, if string.sub(sku, 1, 5) == "Seed_" then "Seed" else "Upgrade")
	safely(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Sink,
			CURRENCY,
			amount,
			coins(player),
			Enum.AnalyticsEconomyTransactionType.Shop.Name,
			sku
		)
	end)
end

-- A counted custom event with one field (e.g. which seed).
function Analytics.custom(player: Player, name: string, field: string?)
	safely(function()
		local fields = if field then { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = field } else nil
		AnalyticsService:LogCustomEvent(player, name, 1, fields)
	end)
end

-- "1 min", "2 h": a funnel step's name.
local function minutesName(minutes: number): string
	return if minutes < 60 then `{minutes} min` else `{minutes // 60} h`
end

-- Logs every step of a minutes ladder the player has reached since `done` (the last step logged).
local function climb(player: Player, funnel: string, funnelId: string, ladder: { number }, minutes: number, done: number): number
	local step = done
	while ladder[step + 1] and minutes >= ladder[step + 1] do
		step += 1
		local name = minutesName(ladder[step])
		safely(function()
			AnalyticsService:LogFunnelStepEvent(player, funnel, funnelId, step, name)
		end)
	end
	return step
end

local function checkPlaytime(player: Player)
	local session = sessions[player]
	if not session then
		-- First check once the save has loaded: start this visit's funnel, and skip lifetime steps passed in
		-- earlier visits.
		local before = player:GetAttribute("PlayTimeSeconds")
		if typeof(before) ~= "number" then
			return
		end
		local lifetime = before / 60
		local passed = 0
		while LIFETIME_MINUTES[passed + 1] and lifetime >= LIFETIME_MINUTES[passed + 1] do
			passed += 1
		end
		session = {
			id = HttpService:GenerateGUID(false),
			started = joinedAt[player] or os.clock(),
			sessionStep = 0,
			lifetimeStep = passed,
		}
		sessions[player] = session
	end
	local s = session :: Session
	s.sessionStep = climb(player, "SessionLength", s.id, SESSION_MINUTES, (os.clock() - s.started) / 60, s.sessionStep)
	local total = player:GetAttribute("PlayTimeSeconds")
	if typeof(total) == "number" then
		s.lifetimeStep = climb(player, "LifetimePlaytime", tostring(player.UserId), LIFETIME_MINUTES, total / 60, s.lifetimeStep)
	end
end

-- Called when a player's forest count goes up: logs it if it's one of the station-unlock milestones.
function Analytics.forestMilestone(player: Player, forests: number)
	local step = table.find(FOREST_MILESTONES, forests)
	if step then
		safely(function()
			AnalyticsService:LogFunnelStepEvent(player, "ForestMilestones", tostring(player.UserId), step, `{forests} forests`)
		end)
	end
end

local function step(player: Player, funnel: string, id: string, index: number, name: string)
	safely(function()
		AnalyticsService:LogFunnelStepEvent(player, funnel, id, index, name)
	end)
end

-- The tutorial (TutorialService): one funnel per player, a step each time they reach a new one, and
-- TutorialStepSeconds (2026-10-09): the seconds this visit spent on the step just finished (0 when several finish
-- at once; the first one after joining counts from the join).
function Analytics.tutorialStep(player: Player, index: number, name: string)
	step(player, "Tutorial", tostring(player.UserId), index, name)
	local started = stepStartedAt[player] or os.clock()
	stepStartedAt[player] = os.clock()
	safely(function()
		AnalyticsService:LogCustomEvent(player, "TutorialStepSeconds", os.clock() - started, {
			[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = GameConfig.Tutorial.Steps[index - 1] or "Intro",
		})
	end)
end

-- The starter quests (QuestService): one funnel per player, a step for each quest claimed.
function Analytics.questClaimed(player: Player, index: number, id: string)
	step(player, "Quests", tostring(player.UserId), index, id)
end

-- ForestLoop -----------------------------------------------------------------------------------------
local function forestId(player: Player, round: string): string
	return `{round}-{player.UserId}`
end

-- This player's progress in the running forest (logging InServer the first time we see them in it).
local function progressOf(player: Player): ForestProgress
	local old = forestProgress[player]
	if old and old.round == forestRound then
		return old
	end
	local p: ForestProgress = {
		round = forestRound,
		planted = 0,
		completed = if old then old.completed else nil,
		trees = 0,
		gapSum = 0,
		gapReported = false,
	}
	forestProgress[player] = p
	step(player, "ForestLoop", forestId(player, forestRound), 1, "InServer")
	return p
end

function Analytics.forestStarted()
	forestRound = HttpService:GenerateGUID(false)
	forestStartedAt = os.clock()
	forestBoughtSeeds = 0
	ringStartedAt = os.clock()
	ringIndex = 1
	for _, player in Players:GetPlayers() do
		progressOf(player)
	end
end

-- Seeds the player planted by hand (not bought into the bar).
function Analytics.forestPlanted(player: Player, seeds: number)
	local p = progressOf(player)
	local before = p.planted
	p.planted += seeds
	p.firstPlantAt = p.firstPlantAt or os.clock()
	if before == 0 and p.planted > 0 then
		step(player, "ForestLoop", forestId(player, p.round), 2, "PlantedAcorn")
		local previous = p.completed
		if previous and previous ~= p.round then
			step(player, "ForestLoop", forestId(player, previous), 6, "PlantedNextForest")
			p.completed = nil
		end
	end
	if before < GameConfig.Stats.ForestCreditSeeds and p.planted >= GameConfig.Stats.ForestCreditSeeds then
		step(player, "ForestLoop", forestId(player, p.round), 3, "Planted50")
	end
end

-- "10-24", "1000+": the band a value falls in.
local function band(value: number, edges: { number }): string
	for i = #edges, 1, -1 do
		if value >= edges[i] then
			local nextEdge = edges[i + 1]
			if not nextEdge then
				return `{edges[i]}+`
			end
			return if nextEdge - 1 == edges[i] then tostring(edges[i]) else `{edges[i]}-{nextEdge - 1}`
		end
	end
	return tostring(edges[1])
end

local function field(n: number): string
	return (Enum.AnalyticsCustomFieldKeys :: any)[`CustomField0{n}`].Name
end

-- "World 1 OuterFirst": the world and the layout (the A/B test) of the running forest.
local function variant(): string
	local state = ReplicatedStorage:FindFirstChild("ForestState")
	local tierId = state and state:GetAttribute("TierId")
	local layout = state and state:GetAttribute("Layout")
	return `World {if tierId ~= nil then tostring(tierId) else "?"} {if layout ~= nil then tostring(layout) else "?"}`
end

-- "Tutorial Train" while the player is still in the tutorial (step 0 is the story intro), else nil.
local function tutorialWhere(player: Player): string?
	local index = player:GetAttribute("TutorialStep")
	if typeof(index) ~= "number" or index >= GameConfig.Tutorial.DoneStep then
		return nil
	end
	return `Tutorial {GameConfig.Tutorial.Steps[index] or "Intro"}`
end

local function playersBand(): string
	return `Players {band(#Players:GetPlayers(), PLAYER_BANDS)}`
end

-- A ring of the forest is complete (ForestService, in opening order: 1 is the first ring of the forest).
function Analytics.ringCompleted(index: number, trees: number)
	local minutes = (os.clock() - ringStartedAt) / 60
	ringStartedAt = os.clock()
	ringIndex = index + 1
	local reporter = Players:GetPlayers()[1]
	if not reporter then
		return
	end
	safely(function()
		AnalyticsService:LogCustomEvent(reporter, "RingCompleted", minutes, {
			[field(1)] = `Ring {index} ({trees} trees)`,
			[field(2)] = playersBand(),
			[field(3)] = variant(),
		})
	end)
end

-- The player planted the last seed of a tree (ForestService).
function Analytics.treeFinished(player: Player)
	local p = progressOf(player)
	local now = os.clock()
	local from = p.lastTreeAt or p.firstPlantAt or now
	p.gapSum += now - from
	p.trees += 1
	p.lastTreeAt = now
end

-- TreeGap for a player's forest, once (at the forest's end, or when they leave before it).
local function reportTreeGap(player: Player)
	local p = forestProgress[player]
	if not p or p.round ~= forestRound or p.gapReported or p.trees == 0 then
		return
	end
	p.gapReported = true
	safely(function()
		AnalyticsService:LogCustomEvent(player, "TreeGap", p.gapSum / p.trees, {
			[field(1)] = `Trees {band(p.trees, TREE_BANDS)}`,
			[field(2)] = playersBand(),
			[field(3)] = variant(),
		})
	end)
end

-- LeftAt: where in the forest a player left, with the visit's minutes.
local function leftAt(player: Player, minutes: number)
	local state = ReplicatedStorage:FindFirstChild("ForestState")
	local tutorial = tutorialWhere(player) -- in the tutorial: which step (2026-10-09; was always the ring)
	local where = tutorial or "Break"
	if not tutorial and not breakLogs and state then
		local done, trees = state:GetAttribute("RingDone"), state:GetAttribute("RingTrees")
		local percent = if typeof(done) == "number" and typeof(trees) == "number" and trees > 0 then 100 * done / trees else 0
		where = `Ring {ringIndex} {band(percent, PROGRESS_BANDS)}%`
	end
	safely(function()
		AnalyticsService:LogCustomEvent(player, "LeftAt", minutes, {
			[field(1)] = where,
			[field(2)] = variant(),
			[field(3)] = playersBand(),
		})
	end)
end

-- Seeds bought straight into the bar (ForestService.addSeeds), for the forest report.
function Analytics.forestBought(seeds: number)
	forestBoughtSeeds += seeds
end

local function median(values: { number }): number
	local sorted = table.clone(values)
	table.sort(sorted)
	local middle = (#sorted + 1) / 2
	return (sorted[math.floor(middle)] + sorted[math.ceil(middle)]) / 2
end

-- The forest report (see the top of this file). Logged on one of the planters: custom events need a player.
local function forestReport()
	local everyone = Players:GetPlayers()
	local planters = {}
	for _, player in everyone do
		local planted = player:GetAttribute("ForestPlanted")
		if typeof(planted) == "number" and planted > 0 then
			table.insert(planters, player)
		end
	end
	local group = if #planters > 0 then planters else everyone
	local reporter = group[1]
	if not reporter then
		return
	end
	local function attr(player: Player, name: string): number
		local value = player:GetAttribute(name)
		return if typeof(value) == "number" then value else 0
	end
	local stats: { { name: string, of: (Player) -> number } } = {
		{
			name = "Strength",
			of = function(p)
				return attr(p, "Strength")
			end,
		},
		{
			name = "Speed",
			of = function(p)
				return attr(p, "Speed")
			end,
		},
		{
			name = "Capacity",
			of = function(p)
				return GameConfig.capacity(attr(p, "Strength"))
			end,
		},
		{
			name = "WalkSpeed",
			of = function(p)
				local walk = GameConfig.walkSpeed(attr(p, "Speed"))
				local cap = attr(p, "WalkCap")
				return if cap > 0 then math.min(walk, cap) else walk
			end,
		},
		{
			name = "PickupPerPress",
			of = function(p)
				return GameConfig.upgradeValue("BulkPickup", attr(p, "BulkPickupLevel"))
			end,
		},
		{
			name = "PlantPerPress",
			of = function(p)
				return GameConfig.upgradeValue("BulkPlant", attr(p, "BulkPlantLevel"))
			end,
		},
		{
			name = "PlantingRange",
			of = function(p)
				return GameConfig.upgradeValue("PlantingRange", attr(p, "PlantingRangeLevel"))
			end,
		},
		{
			name = "HandsSpeed",
			of = function(p)
				return math.max(1, attr(p, "HandsSpeed"))
			end,
		},
		{
			name = "SeedsPlanted",
			of = function(p)
				return attr(p, "ForestPlanted")
			end,
		},
		{
			name = "SeedsPerTree", -- the forest's size (GameConfig.ForestSize): the same for everyone
			of = function()
				local state = ReplicatedStorage:FindFirstChild("ForestState")
				local perHex = state and state:GetAttribute("SeedsPerHex")
				return if typeof(perHex) == "number" then perHex else 0
			end,
		},
	}
	local field1, field2, field3 =
		Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
		Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
		Enum.AnalyticsCustomFieldKeys.CustomField03.Name
	local players = `Players {band(#everyone, PLAYER_BANDS)}`
	local world = variant()
	local minutes = (os.clock() - forestStartedAt) / 60
	AnalyticsService:LogCustomEvent(reporter, "ForestCompleted", minutes, {
		[field1] = players,
		[field2] = `Planters {band(#planters, PLAYER_BANDS)}`,
		[field3] = world,
	})
	AnalyticsService:LogCustomEvent(reporter, "ForestBoughtSeeds", forestBoughtSeeds, { [field1] = players, [field2] = world })
	for _, stat in stats do
		local values, sum = {}, 0
		for _, player in group do
			local value = stat.of(player)
			table.insert(values, value)
			sum += value
		end
		local fields = { [field1] = stat.name, [field2] = players, [field3] = world }
		AnalyticsService:LogCustomEvent(reporter, "ForestStatMedian", median(values), fields)
		AnalyticsService:LogCustomEvent(reporter, "ForestStatAverage", sum / #values, fields)
	end
end

function Analytics.forestCompleted()
	safely(forestReport)
	for _, player in Players:GetPlayers() do
		reportTreeGap(player)
	end
	for _, player in Players:GetPlayers() do
		local p = progressOf(player)
		p.completed = p.round
		step(player, "ForestLoop", forestId(player, p.round), 4, "Completed")
	end
end

function Analytics.roulette()
	for _, player in Players:GetPlayers() do
		local p = progressOf(player)
		step(player, "ForestLoop", forestId(player, p.round), 5, "SawRoulette")
	end
end

-- RobuxShop and LockedStation ------------------------------------------------------------------------
-- A player tried a station that's locked for them (TrainingService).
function Analytics.stationLocked(player: Player, multiplier: number)
	local open = purchases[player]
	if open and open.funnel == "LockedStation" and open.multiplier == multiplier then
		if os.clock() - open.at < LOCKED_SESSION_SECONDS then
			return -- still the same try (benches and treadmills report it again and again)
		end
	end
	local id = HttpService:GenerateGUID(false)
	purchases[player] = { funnel = "LockedStation", id = id, at = os.clock(), multiplier = multiplier }
	step(player, "LockedStation", id, 1, "Tried")
	-- LockedTry (2026-10-09): which station, and whether they were still in the tutorial (lost on the way to the 1x?)
	Analytics.custom(player, "LockedTry", `{multiplier}x {tutorialWhere(player) or "After tutorial"}`)
end

local function shopOpened(player: Player)
	if not Guard.allow(player, "RobuxShopOpened", SHOP_OPEN_RATE.PerSecond, SHOP_OPEN_RATE.Burst) then
		return
	end
	local id = HttpService:GenerateGUID(false)
	purchases[player] = { funnel = "RobuxShop", id = id, at = os.clock() }
	step(player, "RobuxShop", id, 1, "Opened")
end

-- A Roblox purchase prompt closed: Prompted (and Purchased) for the funnel the player has open.
local function promptFinished(player: Player?, purchased: boolean, isStationPass: boolean)
	if player and purchased then
		boughtDuringBreak(player, "Robux")
	end
	local open = player and purchases[player]
	if not (player and open) then
		return
	end
	local window = if open.funnel == "LockedStation" then LOCKED_SESSION_SECONDS else SHOP_SESSION_SECONDS
	if os.clock() - open.at > window or (open.funnel == "LockedStation" and not isStationPass) then
		return
	end
	step(player, open.funnel, open.id, 2, "Prompted")
	if purchased then
		step(player, open.funnel, open.id, 3, "Purchased")
		purchases[player] = nil -- the next purchase starts a new funnel
	end
end

local function isStationPass(passId: number): boolean
	for _, id in GameConfig.StationPasses do
		if id == passId then
			return true
		end
	end
	return false
end

Players.PlayerAdded:Connect(function(player)
	joinedAt[player] = os.clock()
	stepStartedAt[player] = os.clock()
	progressOf(player) -- InServer for players who join mid-forest, planting or not
end)
Remotes.event("RobuxShopOpened").OnServerEvent:Connect(shopOpened)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
	promptFinished(player, purchased, isStationPass(passId))
end)
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, _: number, purchased: boolean)
	promptFinished(Players:GetPlayerByUserId(userId), purchased, false)
end)

-- Break activity -------------------------------------------------------------------------------------
local function breakLogOf(player: Player): BreakLog?
	local logs = breakLogs
	if not logs then
		return nil
	end
	local log = logs[player]
	if not log then
		log = { seconds = {}, bought = {}, lastPosition = nil, still = 0 }
		logs[player] = log
	end
	return log
end

local function activity(player: Player, log: BreakLog): string
	if player:GetAttribute("InSpring") == true then
		return "Spring"
	end
	local benching = player:GetAttribute("Benching")
	if (typeof(benching) == "string" and benching ~= "") or player:GetAttribute("Running") == true then
		return "Training"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return "AFK"
	end
	local last = log.lastPosition
	log.still = if last and (root.Position - last).Magnitude < AFK_STUDS then log.still + BREAK_SAMPLE_SECONDS else 0
	log.lastPosition = root.Position
	return if log.still >= AFK_SECONDS then "AFK" else "Walking"
end

local function mainActivity(log: BreakLog): (string, number)
	local best, bestSeconds, total = "None", -1, 0
	for name, seconds in log.seconds do
		total += seconds
		if seconds > bestSeconds then
			best, bestSeconds = name, seconds
		end
	end
	return best, total
end

local function boughtText(log: BreakLog): string
	local kinds = {}
	for _, kind in { "Robux", "Seed", "Upgrade" } do
		if log.bought[kind] then
			table.insert(kinds, kind)
		end
	end
	return if #kinds > 0 then `Bought {table.concat(kinds, "+")}` else "Bought nothing"
end

function Analytics.breakStarted()
	breakLogs = {}
end

function Analytics.breakEnded()
	local logs = breakLogs
	breakLogs = nil
	if not logs then
		return
	end
	for player, log in logs do
		local main, total = mainActivity(log)
		if total > 0 and player.Parent == Players then
			local spring = (log.seconds.Spring or 0) / total
			local springBand = if spring == 0 then "Spring 0%" elseif spring < 0.5 then "Spring 1-49%" else "Spring 50%+"
			safely(function()
				AnalyticsService:LogCustomEvent(player, "BreakActivity", total, {
					[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = `Mostly {main}`,
					[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = boughtText(log),
					[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = springBand,
				})
			end)
		end
	end
end

local function leftDuringBreak(player: Player)
	local logs = breakLogs
	local log = logs and logs[player]
	if not (logs and log) then
		return
	end
	logs[player] = nil
	local main, total = mainActivity(log)
	safely(function()
		AnalyticsService:LogCustomEvent(player, "LeftDuringBreak", total, {
			[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = `Mostly {main}`,
			[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = boughtText(log),
		})
	end)
end

task.spawn(function()
	while true do
		task.wait(BREAK_SAMPLE_SECONDS)
		if breakLogs then
			for _, player in Players:GetPlayers() do
				local log = breakLogOf(player)
				if log then
					local doing = activity(player, log)
					log.seconds[doing] = (log.seconds[doing] or 0) + BREAK_SAMPLE_SECONDS
				end
			end
		end
	end
end)

local function number(player: Player, attribute: string): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 0
end

-- The player's stats as they leave (only once their save had loaded).
local function leftGame(player: Player)
	if typeof(player:GetAttribute("Strength")) ~= "number" then
		return
	end
	local session = sessions[player]
	local minutes = if session then math.round((os.clock() - session.started) / 60) else 0
	local upgrades = 0
	for _, attribute in UPGRADES do
		upgrades += number(player, attribute)
	end
	local capacity = `Capacity {band(GameConfig.capacity(number(player, "Strength")), CAPACITY_BANDS)}`
	local forests = `Forests {band(number(player, "ForestsCompleted"), FOREST_BANDS)}`
	local upgradeBand = `Upgrades {band(upgrades, UPGRADE_BANDS)}`
	safely(function()
		AnalyticsService:LogCustomEvent(player, "LeftGame", minutes, {
			[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = capacity,
			[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = forests,
			[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = upgradeBand,
		})
	end)
end

local function flushPlanting(player: Player)
	local amount = planting[player]
	planting[player] = nil
	if amount then
		Analytics.earned(player, amount, "Planting", Enum.AnalyticsEconomyTransactionType.Gameplay)
	end
end

task.spawn(function()
	while true do
		task.wait(PLANTING_FLUSH_SECONDS)
		for player in planting do
			flushPlanting(player)
		end
	end
end)

task.spawn(function()
	while true do
		for _, player in Players:GetPlayers() do
			checkPlaytime(player)
		end
		task.wait(CHECK_SECONDS)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	leftDuringBreak(player)
	leftGame(player)
	reportTreeGap(player)
	local session = sessions[player]
	leftAt(player, if session then (os.clock() - session.started) / 60 else 0)
	flushPlanting(player)
	logged[player] = nil
	sessions[player] = nil
	joinedAt[player] = nil
	stepStartedAt[player] = nil
	forestProgress[player] = nil
	purchases[player] = nil
end)

return Analytics
