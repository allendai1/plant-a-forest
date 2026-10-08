--!strict
-- BadgeAwardService: Roblox badges (polish pass, 2026-10-07). Ids live in GameConfig.Badges (0 = not created
-- on the Creator Dashboard yet, skipped). Welcome on join, the forest badges when ForestsCompleted reaches
-- their count (also for players who passed it before the badge existed), and award() for other services
-- (ForestService: SpecialTree). Each badge is asked about at most once per player per server.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local FOREST_BADGES =
	{ { key = "FirstForest", forests = 1 }, { key = "Forests10", forests = 10 }, { key = "Forests100", forests = 100 } }

local BadgeAwardService = {}

local done: { [Player]: { [string]: boolean } } = {}

function BadgeAwardService.award(player: Player, key: string)
	local id = GameConfig.Badges[key]
	local mine = done[player]
	if not id or id == 0 or not mine or mine[key] then
		return
	end
	mine[key] = true
	task.spawn(function()
		local ok, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, id)
		if ok and not has then
			local awarded, err = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
			if not awarded then
				warn(`[BadgeAwardService] couldn't award {key}: {err}`)
				mine[key] = nil -- try again next time
			end
		elseif not ok then
			mine[key] = nil
		end
	end)
end

local function checkForests(player: Player)
	local forests = player:GetAttribute("ForestsCompleted")
	if typeof(forests) ~= "number" then
		return
	end
	for _, badge in FOREST_BADGES do
		if forests >= badge.forests then
			BadgeAwardService.award(player, badge.key)
		end
	end
end

local function onPlayerAdded(player: Player)
	done[player] = {}
	BadgeAwardService.award(player, "Welcome")
	player:GetAttributeChangedSignal("ForestsCompleted"):Connect(function()
		checkForests(player)
	end)
	checkForests(player) -- the save may already be loaded
end

function BadgeAwardService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		done[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return BadgeAwardService
