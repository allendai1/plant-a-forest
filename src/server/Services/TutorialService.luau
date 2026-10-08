--!strict
-- TutorialService: the first-time tutorial's steps (2026-10-07, the user's sequence). The step is saved as
-- TutorialStep (DataService; the attribute drives TutorialController's prompt and arrow):
--   0 the story intro (the client plays it, then sends TutorialIntroDone)
--   1 PickUp      done when you carry acorns
--   2 Plant       done when you've planted one
--   3 Train       done at Tutorial.TrainedStrength (the bench)
--   4 TrainSpeed  done at Tutorial.TrainedSpeed (the treadmill)
--   5 PickUpMore  done when you're full (your new capacity)
--   6 PlantMore   done when you've planted them all
--   7 Shop        done when you own any upgrade level; reaching it tops your coins up to Tutorial.ShopCoins
--   8 DoneStep    finished
-- Several steps can finish at once (e.g. already full when Train ends). Each step reached is logged to the
-- Tutorial analytics funnel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Guard)
local Analytics = require(script.Parent.Parent.Analytics)

local WATCHED = { "Carried", "SeedsPlanted", "Strength", "Speed", "BulkPickupLevel", "BulkPlantLevel", "PlantingRangeLevel" }

local TutorialService = {}

local function number(player: Player, name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

-- Is the step finished?
local function isDone(player: Player, step: string): boolean
	local carried = number(player, "Carried")
	if step == "PickUp" then
		return carried > 0
	elseif step == "Plant" then
		return number(player, "SeedsPlanted") > 0
	elseif step == "Train" then
		return number(player, "Strength") >= GameConfig.Tutorial.TrainedStrength
	elseif step == "TrainSpeed" then
		return number(player, "Speed") >= GameConfig.Tutorial.TrainedSpeed
	elseif step == "PickUpMore" then
		return carried >= GameConfig.capacity(number(player, "Strength"))
	elseif step == "PlantMore" then
		return carried == 0
	elseif step == "Shop" then
		for _, id in GameConfig.ShopUpgrades do
			if number(player, id .. "Level") > 0 then
				return true
			end
		end
		return false
	end
	return true
end

-- Something happened on reaching a step.
local function enter(player: Player, index: number)
	local t = GameConfig.Tutorial
	local name = t.Steps[index] or "Done"
	Analytics.tutorialStep(player, index, name)
	if name == "Shop" then
		local profile = DataService.get(player)
		if profile and profile.Coins < t.ShopCoins then
			local gift = t.ShopCoins - profile.Coins
			DataService.add(player, "Coins", gift)
			Analytics.earned(player, gift, "TutorialGift", Enum.AnalyticsEconomyTransactionType.Onboarding)
		end
	end
end

-- Moves the player on through every step they've finished.
local function evaluate(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local t = GameConfig.Tutorial
	local index = profile.TutorialStep
	local moved = false
	while index >= 1 and index < t.DoneStep and isDone(player, t.Steps[index]) do
		index += 1
		moved = true
		DataService.set(player, "TutorialStep", index)
		enter(player, index)
	end
	if moved then
		print(`[TutorialService] {player.Name} is on tutorial step {index}`)
	end
end

local function onPlayerAdded(player: Player)
	for _, name in WATCHED do
		player:GetAttributeChangedSignal(name):Connect(function()
			evaluate(player)
		end)
	end
end

function TutorialService.init()
	Remotes.event("TutorialIntroDone").OnServerEvent:Connect(function(player: Player)
		local rate = GameConfig.Tutorial.IntroRate
		local profile = DataService.get(player)
		if Guard.allow(player, "TutorialIntroDone", rate.PerSecond, rate.Burst) and profile and profile.TutorialStep == 0 then
			DataService.set(player, "TutorialStep", 1)
			enter(player, 1)
			evaluate(player)
		end
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

-- Studio-only testing (DevService): restart the tutorial from the intro.
function TutorialService.devRestart(player: Player)
	DataService.set(player, "TutorialStep", 0)
end

return TutorialService
