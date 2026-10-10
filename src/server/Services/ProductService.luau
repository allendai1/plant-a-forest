--!strict
-- ProductService: the game's one MarketplaceService.ProcessReceipt handler (docs/plans/M6.md, GUI.md).
-- Developer products are granted only here, from the receipt Roblox sends the server:
-- - Awakening.BreakTime: break time for the whole server (kept for the next break if none is running)
-- - Awakening.WorldPicks: picks the next forest's world for everyone
-- - BarBoosts: seeds straight into the Forest Bar (ForestService.addSeeds)
-- - ServerBoost: 2x training for everyone for a while (TrainingService.addServerBoost)
-- - UpgradeProducts: one upgrade level, saved through DataService.grantPurchase
-- - Boosts[].ProductId: a permanent Strength or Speed boost, saved the same way (PassService publishes it)
-- - SeedShop.Seeds[].ProductId: one special seed into the seed bag, saved the same way (docs/plans/SeedShop.md)
-- Studio's test panel feeds fake receipts through ProductService.process.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local AwakeningService = require(script.Parent.AwakeningService)
local DataService = require(script.Parent.DataService)
local ForestService = require(script.Parent.ForestService)
local TrainingService = require(script.Parent.TrainingService)

local LEVEL_KEYS: { [string]: DataService.StatKey } = {
	BulkPickup = "BulkPickupLevel",
	BulkPlant = "BulkPlantLevel",
	PlantingRange = "PlantingRangeLevel",
}

local ProductService = {}

-- ponytail: server-wide products (extensions, bar seeds, server boost) remember handled receipts in
-- server memory only; they only change this server, so a resend after a crash can't double anything saved.
local handled: { [string]: boolean } = {}

-- One upgrade level: the next one up (a level bought with coins meanwhile still counts). At max level
-- the player gets that level's coin price instead.
local function grantUpgrade(player: Player, upgradeId: string, level: number)
	local key: DataService.StatKey? = LEVEL_KEYS[upgradeId]
	local profile = DataService.get(player)
	local def = GameConfig.Upgrades[upgradeId]
	if not (key and profile and def) then
		return
	end
	if profile[key] < def.MaxLevel then
		DataService.set(player, key, profile[key] + 1)
	else
		DataService.add(player, "Coins", GameConfig.upgradeCost(upgradeId, level) or 0)
	end
end

local function upgradeOf(productId: number): (string?, number)
	for upgradeId, ids in GameConfig.UpgradeProducts do
		local level = table.find(ids, productId)
		if level then
			return upgradeId, level
		end
	end
	return nil, 0
end

local BOOST_KEYS: { [string]: DataService.StatKey } = {
	Strength = "StrengthBoostBought",
	Speed = "SpeedBoostBought",
}

-- Which boost a product is: its stat ("Strength" / "Speed") and multiplier.
local function boostOf(productId: number): (string?, number)
	for stat, ladder in GameConfig.Boosts :: { [string]: { GameConfig.Boost } } do
		for _, step in ladder do
			if step.ProductId == productId then
				return stat, step.Multiplier
			end
		end
	end
	return nil, 0
end

local function seedOf(productId: number): string?
	for _, def in GameConfig.SeedShop.Seeds do
		if def.ProductId == productId then
			return def.Id
		end
	end
	return nil
end

local function barSeedsOf(productId: number): number?
	for _, boost in GameConfig.BarBoosts do
		if boost.ProductId == productId then
			return boost.Seeds
		end
	end
	return nil
end

function ProductService.process(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local purchaseId, productId, userId = receipt.PurchaseId, receipt.ProductId, receipt.PlayerId
	if typeof(purchaseId) ~= "string" or typeof(productId) ~= "number" or typeof(userId) ~= "number" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if handled[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local player = Players:GetPlayerByUserId(userId)
	local upgradeId, level = upgradeOf(productId)
	if upgradeId then
		if
			player
			and DataService.grantPurchase(player, purchaseId, function()
				grantUpgrade(player, upgradeId, level)
			end)
		then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local boostStat, multiplier = boostOf(productId)
	local boostKey: DataService.StatKey? = if boostStat then BOOST_KEYS[boostStat] else nil
	if boostKey then
		local key: DataService.StatKey = boostKey
		if
			player
			and DataService.grantPurchase(player, purchaseId, function()
				-- ponytail: a lower boost bought after a higher one (two prompts at once) changes nothing; the shop
				-- only offers the next one up, so refunding it isn't worth the code.
				local profile = DataService.get(player)
				if profile then
					DataService.set(player, key, math.max(profile[key] :: number, multiplier))
				end
			end)
		then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local seedId = seedOf(productId)
	if seedId then
		if
			player
			and DataService.grantPurchase(player, purchaseId, function()
				DataService.addToBag(player, seedId, 1)
			end)
		then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local seeds = barSeedsOf(productId)
	local minutes, world = nil, table.find(GameConfig.Awakening.WorldPicks, productId)
	for _, pack in GameConfig.Awakening.BreakTime do
		if pack.ProductId == productId then
			minutes = pack.Minutes
		end
	end
	if minutes then
		AwakeningService.extend(player, minutes)
	elseif world then
		AwakeningService.pickWorld(player, world)
	elseif productId == GameConfig.ServerBoost.ProductId then
		TrainingService.addServerBoost(player)
	elseif seeds and player then
		ForestService.addSeeds(player, seeds)
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet -- not a product this server knows, or no buyer
	end
	handled[purchaseId] = true
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ProductService.init()
	MarketplaceService.ProcessReceipt = ProductService.process
end

return ProductService
