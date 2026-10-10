--!strict
-- QuestService: the starter quests (docs/plans/Quests.md, 2026-10-09). One at a time, in GameConfig.Quests order, from
-- the end of the tutorial; the saved QuestIndex is the one you're on (past the end = all done). Progress is your own
-- saved numbers (GameConfig.questProgress), counted where they change (ForestService counts TreesFinished and
-- RingsHelped), so this only handles ClaimQuest: the current quest, once at its goal, pays its coins and moves on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Guard)
local Analytics = require(script.Parent.Parent.Analytics)

local QuestService = {}

local function onClaim(player: Player)
	local rate = GameConfig.QuestClaimRate
	if not Guard.allow(player, "ClaimQuest", rate.PerSecond, rate.Burst) then
		return
	end
	local profile = DataService.get(player)
	if not profile or profile.TutorialStep < GameConfig.Tutorial.DoneStep then
		return
	end
	local index = profile.QuestIndex
	local quest = GameConfig.Quests[index]
	if not quest then
		return -- all done
	end
	local progress = GameConfig.questProgress(quest, function(name: string): number
		local value = (profile :: any)[name]
		return if typeof(value) == "number" then value else 0
	end)
	if progress < quest.Goal then
		return
	end
	-- Moved on before paying, with no yield between, so a second claim can't pay this quest again.
	DataService.set(player, "QuestIndex", index + 1)
	DataService.add(player, "Coins", quest.Reward)
	Analytics.earned(player, quest.Reward, `Quest{index}`, Enum.AnalyticsEconomyTransactionType.Onboarding)
	Analytics.questClaimed(player, index, quest.Id)
end

function QuestService.init()
	Remotes.event("ClaimQuest").OnServerEvent:Connect(onClaim)
end

return QuestService
