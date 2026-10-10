--!strict
-- AwakeningService: what happens when the forest is complete (docs/plans/M6.md).
-- Everyone online who put Stats.ForestCreditSeeds acorns into this forest (ForestService.hasForestCredit, the
-- user's rule since 2026-10-07; AFK players and late joiners get nothing) gets RewardCoins and +1 ForestsCompleted;
-- the others are told how many they planted. The spring multiplier is rolled, and
-- AwakeningEndsAt marks the end of the cutscene plus the break (clients play both from it). Break time bought
-- with Robux (Awakening.BreakTime, ProductService) and the Studio test panel call extend(). When the break ends,
-- the forest resets.
--
-- ForestState attributes: AwakeningEndsAt (server time, 0 when not running), SpringMultiplier (0 when the spring
-- is closed), Extensions (a count of purchases clients watch for the banner), ExtendedBy and ExtendedMinutes
-- (the last one), and the world pick: PickedTier (0 = none yet), PickedBy, Picks (a count for the banner).
-- Worlds: when the break ends, a bought pick starts at once (no roulette). Otherwise the roulette rolls by Weight:
-- ForestState NextTier (its index) and TierRolls (a count clients watch to play the roulette); after
-- Roulette.SpinSeconds + HoldSeconds the forest resets as that tier.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)
local ForestService = require(script.Parent.ForestService)
local Analytics = require(script.Parent.Parent.Analytics)

local CHECK_SECONDS = 0.25

local AwakeningService = {}

local forestState: Instance
local endsAt = 0
local extensions = 0
local pending = 0 -- seconds bought when no break was running; added to the next break
local picks = 0
local rolls = 0
local rng = Random.new()

local function publish()
	forestState:SetAttribute("AwakeningEndsAt", endsAt)
end

-- Break time for the whole server, up to Awakening.MaxBreakMinutes left on the clock. Time that doesn't fit (bought
-- when no break is running, or past the limit: the buttons stop that, but two purchases can cross) is kept for the
-- next break, so nobody pays for nothing.
function AwakeningService.extend(player: Player?, minutes: number)
	local seconds = minutes * 60
	if endsAt == 0 then
		pending += seconds
		return
	end
	local room = GameConfig.Awakening.MaxBreakMinutes * 60 - (endsAt - workspace:GetServerTimeNow())
	local added = math.clamp(seconds, 0, math.max(room, 0))
	pending += seconds - added
	endsAt += added
	extensions += 1
	forestState:SetAttribute("ExtendedBy", if player then player.DisplayName else "Someone")
	forestState:SetAttribute("ExtendedMinutes", minutes)
	forestState:SetAttribute("Extensions", extensions)
	publish()
end

-- A world pick: the next forest will be Tiers[tier] (the last purchase before the break ends wins).
function AwakeningService.pickWorld(player: Player?, tier: number)
	picks += 1
	forestState:SetAttribute("PickedTier", tier)
	forestState:SetAttribute("PickedBy", if player then player.DisplayName else "Someone")
	forestState:SetAttribute("Picks", picks)
end

local function begin()
	local a = GameConfig.Awakening
	Analytics.forestCompleted()
	Analytics.breakStarted()
	for _, player in Players:GetPlayers() do
		if not ForestService.hasForestCredit(player) then
			local planted = player:GetAttribute("ForestPlanted")
			Remotes.event("AwakeningReward"):FireClient(player, {
				coins = 0,
				planted = if typeof(planted) == "number" then planted else 0,
				needed = GameConfig.Stats.ForestCreditSeeds,
			})
			continue
		end
		Analytics.onboarding(player, "CompletedForest") -- before the count goes up: newcomers only
		DataService.add(player, "Coins", a.RewardCoins)
		DataService.add(player, "ForestsCompleted", 1)
		local profile = DataService.get(player)
		if profile then
			Analytics.forestMilestone(player, profile.ForestsCompleted)
		end
		Analytics.earned(player, a.RewardCoins, "ForestReward", Enum.AnalyticsEconomyTransactionType.Gameplay)
		Remotes.event("AwakeningReward"):FireClient(player, { coins = a.RewardCoins })
	end
	local now = workspace:GetServerTimeNow()
	local carried = math.min(pending, a.MaxBreakMinutes * 60 - a.BreakSeconds)
	pending -= carried
	endsAt = now + a.CutsceneSeconds + a.BreakSeconds + carried
	forestState:SetAttribute("SpringMultiplier", GameConfig.springMultiplier(rng:NextNumber()))
	publish()
	print(`[AwakeningService] forest complete, spring {forestState:GetAttribute("SpringMultiplier")}x`)
end

-- Ends the break now (the spring's multiplier, the 2X TRAINING sign and the break screens with it), no roulette.
-- The test panel's "Next world" calls it before starting a fresh forest in the middle of a break.
function AwakeningService.stop()
	endsAt = 0
	forestState:SetAttribute("SpringMultiplier", 0)
	publish()
end

-- Ends the break, spins the roulette for the next world, then resets the forest as that world.
function AwakeningService.finish()
	if endsAt == 0 then
		return
	end
	AwakeningService.stop()
	Analytics.breakEnded()
	local picked = forestState:GetAttribute("PickedTier")
	forestState:SetAttribute("PickedTier", 0)
	local nextTier: number
	if typeof(picked) == "number" and GameConfig.Tiers[picked] then
		nextTier = picked -- bought: no roulette, the picked world starts now (2026-10-08, the user's ask)
	else
		nextTier = GameConfig.pickTier(rng:NextNumber())
		rolls += 1
		forestState:SetAttribute("NextTier", nextTier)
		forestState:SetAttribute("TierRolls", rolls)
		Analytics.roulette()
		task.wait(GameConfig.Roulette.SpinSeconds + GameConfig.Roulette.HoldSeconds)
	end
	ForestService.setTier(nextTier)
	ForestService.reset()
end

-- The spring multiplier while the break is on (cutscene included), else 0. TrainingService reads it.
function AwakeningService.springMultiplier(): number
	if endsAt == 0 then
		return 0
	end
	local value = forestState:GetAttribute("SpringMultiplier")
	return if typeof(value) == "number" then value else 0
end

function AwakeningService.init()
	ForestService.setOnComplete(begin)
end

function AwakeningService.start()
	forestState = ReplicatedStorage:WaitForChild("ForestState")
	forestState:SetAttribute("SpringMultiplier", 0)
	forestState:SetAttribute("Extensions", 0)
	forestState:SetAttribute("PickedTier", 0)
	publish()
	while true do
		task.wait(CHECK_SECONDS)
		if endsAt > 0 and workspace:GetServerTimeNow() >= endsAt then
			AwakeningService.finish()
		end
	end
end

return AwakeningService
