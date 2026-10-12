--!strict
-- DailyService: the daily login reward (2026-10-11, the user's ask). Once per UTC day (GameConfig.dayOf) a player can
-- claim GameConfig.Daily.Rewards[day of their streak]. Claiming the day after the last claim adds to the streak;
-- any later starts it again at day 1; after the last day it goes round. Saved as DailyStreak and DailyLastDay (the
-- attributes tell the client what to show: DailyController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Guard)
local Analytics = require(script.Parent.Parent.Analytics)

local DailyService = {}

local function onClaim(player: Player)
	local rate = GameConfig.Daily.ClaimRate
	if not Guard.allow(player, "ClaimDaily", rate.PerSecond, rate.Burst) then
		return
	end
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local today = GameConfig.dayOf(os.time())
	if profile.DailyLastDay >= today then
		return -- already claimed today
	end
	local streak = if profile.DailyLastDay == today - 1 then profile.DailyStreak + 1 else 1
	local rewards = GameConfig.Daily.Rewards
	local day = (streak - 1) % #rewards + 1
	-- Saved before paying, with no yield between, so a second claim can't pay today again.
	DataService.set(player, "DailyLastDay", today)
	DataService.set(player, "DailyStreak", streak)
	local gym = GameConfig.Daily.Gyms[day]
	local needed = gym and GameConfig.forestsForMultiplier(gym)
	if gym and needed and profile.DailyGym < gym and profile.ForestsCompleted < needed then
		DataService.set(player, "DailyGym", gym) -- that gym, for good, instead of the coins
		Analytics.custom(player, "DailyGym", tostring(gym))
		return
	end
	local coins = rewards[day]
	DataService.add(player, "Coins", coins)
	Analytics.earned(player, coins, "DailyReward", Enum.AnalyticsEconomyTransactionType.Gameplay)
end

function DailyService.init()
	Remotes.event("ClaimDaily").OnServerEvent:Connect(onClaim)
end

return DailyService
