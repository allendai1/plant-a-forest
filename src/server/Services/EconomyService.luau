--!strict
-- EconomyService: the upgrade shop (docs/plans/M7.md). Coins live in DataService's profile (since M5).
-- BuyUpgrade: the player must be standing in the shop ring by the altar; the server checks the upgrade,
-- its level and the price, then takes the coins and raises the level in one step (no yields between).
-- Other services read a player's upgrades through upgradeValue() and plantRange().
-- ClaimFreeGift (M10): FreeGiftCoins once per player ever. The client sends it after Roblox's Favorite prompt
-- reports a favorite (the server can't check favorites itself, so it trusts that; it's only 500 coins, once).
-- BuySeed (docs/plans/SeedShop.md): in the seed stall's ring, a seed in this restock's stock that the player hasn't
-- bought out yet, for its coin price, into their seed bag.

local CollectionService = game:GetService("CollectionService")
local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Guard)
local Analytics = require(script.Parent.Parent.Analytics)

local SHOP_ZONE_TAG = "ShopZone" -- the altar's ring: upgrades
local SEED_SHOP_ZONE_TAG = "SeedShopZone" -- the seed stall's ring: seeds
local RING_HEIGHT = 8 -- the ring counts up to this far above it

local LEVEL_KEYS: { [string]: DataService.StatKey } = {
	BulkPickup = "BulkPickupLevel",
	BulkPlant = "BulkPlantLevel",
	PlantingRange = "PlantingRangeLevel",
}

local EconomyService = {}

function EconomyService.level(player: Player, upgradeId: string): number
	local profile = DataService.get(player)
	local key = LEVEL_KEYS[upgradeId]
	return if profile and key then profile[key] else 0
end

-- The player's value for an upgrade (seeds per press, or extra studs of range).
function EconomyService.upgradeValue(player: Player, upgradeId: string): number
	return GameConfig.upgradeValue(upgradeId, EconomyService.level(player, upgradeId))
end

function EconomyService.plantRange(player: Player): number
	return GameConfig.Planting.BaseRangeStuds + EconomyService.upgradeValue(player, "PlantingRange")
end

-- Is the player standing in a ring with this tag? Uses the server's own copy of their position.
local function inShopRing(player: Player, tag: string): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	for _, zone in CollectionService:GetTagged(tag) do
		if zone:IsA("BasePart") then
			local offset = root.Position - zone.Position
			local radius = math.max(zone.Size.Y, zone.Size.Z) / 2 + GameConfig.Economy.ShopRingSlackStuds
			if Vector2.new(offset.X, offset.Z).Magnitude <= radius and math.abs(offset.Y) <= RING_HEIGHT then
				return true
			end
		end
	end
	return false
end

local function onBuyUpgrade(player: Player, upgradeId: unknown)
	local rate = GameConfig.Economy.BuyRate
	if not Guard.allow(player, "BuyUpgrade", rate.PerSecond, rate.Burst) then
		return
	end
	if typeof(upgradeId) ~= "string" or not table.find(GameConfig.ShopUpgrades, upgradeId) then
		return
	end
	if not inShopRing(player, SHOP_ZONE_TAG) then
		return
	end
	local profile = DataService.get(player)
	local key: DataService.StatKey? = LEVEL_KEYS[upgradeId]
	if not profile or not key then
		return
	end
	local level = profile[key]
	local cost = GameConfig.upgradeCost(upgradeId, level + 1) -- nil past the top level
	if not cost or profile.Coins < cost then
		return
	end
	DataService.set(player, "Coins", profile.Coins - cost)
	DataService.set(player, key, level + 1)
	Analytics.spent(player, cost, `{upgradeId}_{level + 1}`)
	Analytics.onboarding(player, "BoughtUpgrade")
end

local function onBuySeed(player: Player, seedId: unknown)
	local rate = GameConfig.SeedShop.BuyRate
	if not Guard.allow(player, "BuySeed", rate.PerSecond, rate.Burst) then
		return
	end
	local def = if typeof(seedId) == "string" then GameConfig.seedDef(seedId) else nil
	if not GameConfig.Features.SeedShop or not def or not inShopRing(player, SEED_SHOP_ZONE_TAG) then
		return
	end
	local profile = DataService.get(player)
	if not profile or profile.Coins < def.Price then
		return
	end
	local restock = GameConfig.restockIndex(workspace:GetServerTimeNow())
	if DataService.bought(player, restock, def.Id) >= GameConfig.seedStock(restock)[def.Id] then
		return -- not in stock, or this player bought them all
	end
	DataService.set(player, "Coins", profile.Coins - def.Price)
	DataService.addBought(player, restock, def.Id, 1)
	DataService.addToBag(player, def.Id, 1)
	Analytics.spent(player, def.Price, `Seed_{def.Id}`)
	Analytics.custom(player, "SeedBought", def.Id)
end

local function onClaimFreeGift(player: Player)
	local rate = GameConfig.Economy.GiftRate
	if not Guard.allow(player, "ClaimFreeGift", rate.PerSecond, rate.Burst) then
		return
	end
	local profile = DataService.get(player)
	if not profile or profile.FreeGiftClaimed ~= 0 then
		return
	end
	DataService.set(player, "FreeGiftClaimed", 1)
	DataService.add(player, "Coins", GameConfig.Economy.FreeGiftCoins)
	Analytics.earned(player, GameConfig.Economy.FreeGiftCoins, "FreeGift", Enum.AnalyticsEconomyTransactionType.Onboarding)
end

-- ClaimGroupGift (2026-10-08): GroupGiftCoins once per player ever, if they're in the group. The client asks after
-- Roblox's join-group prompt; the server looks the membership up itself (GetGroupsAsync, not the cached IsInGroup,
-- so a join made a moment ago counts).
local function onClaimGroupGift(player: Player)
	local rate = GameConfig.Economy.GiftRate
	if not Guard.allow(player, "ClaimGroupGift", rate.PerSecond, rate.Burst) then
		return
	end
	local profile = DataService.get(player)
	if not profile or profile.GroupGiftClaimed ~= 0 then
		return
	end
	local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
	if not ok or typeof(groups) ~= "table" then
		return
	end
	local member = false
	for _, group in groups do
		if typeof(group) == "table" and group.Id == GameConfig.Economy.GroupId then
			member = true
			break
		end
	end
	if not member or DataService.get(player) ~= profile or profile.GroupGiftClaimed ~= 0 then
		return -- not in it, or they left or claimed while we were looking
	end
	DataService.set(player, "GroupGiftClaimed", 1)
	DataService.add(player, "Coins", GameConfig.Economy.GroupGiftCoins)
	Analytics.earned(player, GameConfig.Economy.GroupGiftCoins, "GroupGift", Enum.AnalyticsEconomyTransactionType.Onboarding)
end

function EconomyService.init()
	if not GameConfig.Features.SeedShop then
		-- The feature is off: the seed stall and its ring leave the map (kept in ServerStorage).
		local lobby = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Lobby")
		for _, name in { "SeedStall", "SeedShopZone" } do
			local item = lobby and lobby:FindFirstChild(name)
			if item then
				item.Parent = game:GetService("ServerStorage")
			end
		end
	end
	Remotes.event("BuyUpgrade").OnServerEvent:Connect(onBuyUpgrade)
	Remotes.event("ClaimFreeGift").OnServerEvent:Connect(onClaimFreeGift)
	Remotes.event("ClaimGroupGift").OnServerEvent:Connect(onClaimGroupGift)
	Remotes.event("BuySeed").OnServerEvent:Connect(onBuySeed)
end

return EconomyService
