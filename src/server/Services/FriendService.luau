--!strict
-- FriendService: the Friend Boost (docs/plans/GUI.md). Each Roblox friend in the same server adds
-- FriendBoost.PerFriend to the player's planting coins, up to FriendBoost.Max. Friendships are asked
-- once per pair when someone joins; the FriendBoost attribute is the bonus as a fraction (0.2 = +20%).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local FriendService = {}

local friends: { [Player]: { [Player]: boolean } } = {}

local function publish(player: Player)
	local count = 0
	local mine = friends[player]
	if mine then
		for other in mine do
			if other.Parent == Players then
				count += 1
			end
		end
	end
	local f = GameConfig.FriendBoost
	player:SetAttribute("FriendBoost", math.min(count * f.PerFriend, f.Max))
end

function FriendService.boost(player: Player): number
	local value = player:GetAttribute("FriendBoost")
	return if typeof(value) == "number" then value else 0
end

local function onPlayerAdded(player: Player)
	friends[player] = {}
	publish(player)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			task.spawn(function()
				local ok, isFriend = pcall(player.IsFriendsWithAsync, player, other.UserId)
				local mine, theirs = friends[player], friends[other]
				if ok and isFriend and mine and theirs then
					mine[other] = true
					theirs[player] = true
					publish(player)
					publish(other)
				end
			end)
		end
	end
end

function FriendService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		local mine = friends[player]
		friends[player] = nil
		if mine then
			for other in mine do
				local theirs = friends[other]
				if theirs then
					theirs[player] = nil
					publish(other)
				end
			end
		end
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return FriendService
