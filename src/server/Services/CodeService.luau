--!strict
-- CodeService: the CODES panel (polish pass, 2026-10-07). RedeemCode (RemoteFunction) takes the typed code,
-- matches it against GameConfig.Codes.List (ignoring case and spaces), and grants its reward once per player
-- (DataService keeps the redeemed names). Returns (ok, message) for the panel to show.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Guard)
local Analytics = require(script.Parent.Parent.Analytics)

local CodeService = {}

-- "release ", "Re Lease" -> "RELEASE"
local function normalize(text: string): string
	return (string.upper(text):gsub("%s", ""))
end

local function rewardText(reward: GameConfig.CodeReward): string
	local parts = {}
	if reward.Coins then
		table.insert(parts, `{reward.Coins} coins`)
	end
	local def = if reward.Seed then GameConfig.seedDef(reward.Seed) else nil
	if def then
		local count = reward.Count or 1
		table.insert(parts, `{count} {def.DisplayName} seed{if count == 1 then "" else "s"}`)
	end
	return table.concat(parts, " and ")
end

function CodeService.redeem(player: Player, typed: unknown): (boolean, string)
	local codes = GameConfig.Codes
	if not Guard.allow(player, "RedeemCode", codes.Rate.PerSecond, codes.Rate.Burst) then
		return false, "Slow down a little!"
	end
	if typeof(typed) ~= "string" or #typed == 0 or #typed > codes.MaxLength then
		return false, "Type a code first."
	end
	local name = normalize(typed)
	local reward = codes.List[name]
	local seedsOff = reward ~= nil and reward.Seed ~= nil and not GameConfig.Features.SeedShop
	if not reward or seedsOff or (reward.Expires and os.time() > reward.Expires) then
		return false, "That code doesn't work."
	end
	local profile = DataService.get(player)
	if not profile then
		return false, "Your data is still loading."
	end
	if table.find(profile.RedeemedCodes, name) then
		return false, "You already used that code."
	end
	table.insert(profile.RedeemedCodes, name)
	if reward.Coins then
		DataService.add(player, "Coins", reward.Coins)
		Analytics.earned(player, reward.Coins, `Code_{name}`, Enum.AnalyticsEconomyTransactionType.Gameplay)
	end
	if reward.Seed and GameConfig.seedDef(reward.Seed) then
		DataService.addToBag(player, reward.Seed, reward.Count or 1)
	end
	Analytics.custom(player, "CodeRedeemed", name)
	return true, `Redeemed: {rewardText(reward)}!`
end

function CodeService.init()
	Remotes.func("RedeemCode").OnServerInvoke = CodeService.redeem
end

return CodeService
