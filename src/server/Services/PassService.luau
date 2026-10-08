--!strict
-- PassService: which game passes each player owns (docs/plans/M2b.md, GUI.md).
-- Ownership is only ever decided here on the server: checked with Roblox on join, and granted when
-- the server-side PromptGamePassPurchaseFinished event reports a completed purchase.
-- Station passes unlock one training tier. Boost passes (GameConfig.BoostPasses) multiply Strength or
-- Speed gains; the highest owned one is published as the StrengthBoost / SpeedBoost attribute (1 = none).
-- Hands passes (GameConfig.HandsPasses) speed up picking up and planting: HandsSpeed attribute (1 = none).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local CHECK_ATTEMPTS = 3
local RECHECK_SECONDS = 60

export type BoostStat = "Strength" | "Speed"

local PassService = {}

local owned: { [Player]: { [number]: boolean } } = {} -- pass id -> owned

local function allPassIds(): { number }
	local ids = {}
	for _, passId in GameConfig.StationPasses do
		table.insert(ids, passId)
	end
	for _, ladder in { GameConfig.BoostPasses.Strength, GameConfig.BoostPasses.Speed } do
		for _, step in ladder do
			table.insert(ids, step.PassId)
		end
	end
	for _, step in GameConfig.HandsPasses do
		table.insert(ids, step.PassId)
	end
	return ids
end

function PassService.boost(player: Player, stat: BoostStat): number
	local mine = owned[player]
	local best = 1
	for _, step in GameConfig.BoostPasses[stat] do
		if mine and mine[step.PassId] then
			best = math.max(best, step.Multiplier)
		end
	end
	return best
end

-- How many times faster than the base pace this player picks up and plants (1 = no Hands pass).
function PassService.handsSpeed(player: Player): number
	local mine = owned[player]
	local best = 1
	for _, step in GameConfig.HandsPasses do
		if mine and mine[step.PassId] then
			best = math.max(best, step.Multiplier)
		end
	end
	return best
end

local function publish(player: Player)
	player:SetAttribute("StrengthBoost", PassService.boost(player, "Strength"))
	player:SetAttribute("SpeedBoost", PassService.boost(player, "Speed"))
	player:SetAttribute("HandsSpeed", PassService.handsSpeed(player))
end

local function grantId(player: Player, passId: number)
	local mine = owned[player]
	if mine then
		mine[passId] = true
		publish(player)
	end
end

-- A failed lookup means "not known yet", not "not owned": after CHECK_ATTEMPTS quick tries it keeps asking every
-- RECHECK_SECONDS while the player is in the server, so a paying player isn't left without their pass all session.
local function check(player: Player, passId: number)
	while player.Parent == Players do
		for attempt = 1, CHECK_ATTEMPTS do
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
			if ok then
				if has then
					grantId(player, passId)
				end
				return
			end
			task.wait(attempt)
		end
		warn(`[PassService] couldn't check pass {passId} for {player.Name}; trying again in {RECHECK_SECONDS} s`)
		task.wait(RECHECK_SECONDS)
	end
end

local function onPlayerAdded(player: Player)
	owned[player] = {}
	publish(player)
	for _, passId in allPassIds() do
		if passId ~= 0 then
			task.spawn(check, player, passId)
		end
	end
end

-- Does the player own the station pass for this training tier?
function PassService.owns(player: Player, multiplier: number): boolean
	local mine = owned[player]
	local passId = GameConfig.StationPasses[multiplier]
	return mine ~= nil and passId ~= nil and mine[passId] == true
end

-- Studio-only testing (DevService): pretend the player owns this tier's station pass.
function PassService.grant(player: Player, multiplier: number)
	local passId = GameConfig.StationPasses[multiplier]
	if passId then
		grantId(player, passId)
	end
end

-- Studio-only testing (DevService): pretend the player owns this boost pass (by its multiplier).
-- Multiplier 1 takes every boost pass of that stat away again.
-- Studio-only testing (DevService): forget the station passes, so the stations lock like for a player
-- without them (your own account owns every pass of your game).
function PassService.revokeStations(player: Player)
	local mine = owned[player]
	if mine then
		for _, passId in GameConfig.StationPasses do
			mine[passId] = nil
		end
	end
end

function PassService.grantBoost(player: Player, stat: BoostStat, multiplier: number)
	local mine = owned[player]
	if not mine then
		return
	end
	for _, step in GameConfig.BoostPasses[stat] do
		if multiplier == 1 then
			mine[step.PassId] = nil
		elseif step.Multiplier == multiplier then
			mine[step.PassId] = true
		end
	end
	publish(player)
end

-- Studio-only testing (DevService): pretend the player owns this Hands pass; 1 takes them away.
function PassService.grantHands(player: Player, multiplier: number)
	local mine = owned[player]
	if not mine then
		return
	end
	for _, step in GameConfig.HandsPasses do
		if multiplier == 1 then
			mine[step.PassId] = nil
		elseif step.Multiplier == multiplier then
			mine[step.PassId] = true
		end
	end
	publish(player)
end

function PassService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	-- Fired by Roblox on the server, so it can be trusted (a client can't fake it).
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		if purchased and table.find(allPassIds(), passId) then
			grantId(player, passId)
		end
	end)
end

return PassService
