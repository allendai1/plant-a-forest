--!strict
-- EconomyService: the upgrade shop (docs/plans/M7.md). Coins live in DataService's profile (since M5).
-- BuyUpgrade: the player must be standing in the shop ring by the altar; the server checks the upgrade,
-- its level and the price, then takes the coins and raises the level in one step (no yields between).
-- Other services read a player's upgrades through upgradeValue() and plantRange().
-- ClaimFreeGift: the free gift (coins, Strength, Speed) once per player ever, for favoriting and joining the group
-- (the server checks the group; it can't check favorites, so it trusts that). See onClaimFreeGift.
-- BuySeed (docs/plans/SeedShop.md): in the seed stall's ring, a seed in this restock's stock that the player hasn't
-- bought out yet, for its coin price, into their seed bag.
-- BuyCharacter (2026-10-11, the user's call): a character (GameConfig.HandsPasses) for its CoinPrice instead of its pass,
-- from anywhere; each needs the one before it, owned either way. Saved as CharacterBought (the highest index), which
-- PassService counts like the pass.

local CollectionService = game:GetService("CollectionService")
local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PassService = require(script.Parent.PassService)
local Guard = require(script.Parent.Parent.Guard)
local Analytics = require(script.Parent.Parent.Analytics)

local SHOP_ZONE_TAG = "ShopZone" -- the altar's ring: upgrades
local SEED_SHOP_ZONE_TAG = "SeedShopZone" -- the seed stall's ring: seeds
local RING_HEIGHT = 8 -- the ring counts up to this far above it

local LEVEL_KEYS: { [string]: DataService.StatKey } = {
	BulkPickup = "BulkPickupLevel",
	BulkPlant = "BulkPlantLevel",
	PlantingRange = "PlantingRangeLevel",
	LuckyPlanks = "LuckyPlanksLevel",
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

local function onBuyCharacter(player: Player, index: unknown)
	if not Guard.allow(player, "BuyCharacter", 1, 2) then
		return
	end
	if typeof(index) ~= "number" or index ~= math.floor(index) then
		return
	end
	local step = GameConfig.HandsPasses[index]
	local profile = DataService.get(player)
	if not (step and step.CoinPrice and profile) or not table.find(GameConfig.availableHandsPasses(), step) then
		return
	end
	if PassService.ownsCharacter(player, index) then
		return -- already theirs
	end
	if index > 1 and not PassService.ownsCharacter(player, index - 1) then
		return -- the character before it first
	end
	if profile.Coins < step.CoinPrice then
		return
	end
	DataService.set(player, "Coins", profile.Coins - step.CoinPrice)
	DataService.set(player, "CharacterBought", math.max(profile.CharacterBought, index))
	Analytics.spent(player, step.CoinPrice, `Character_{step.Outfit}`)
end

-- ClaimFreeGift (one gift since 2026-10-11, the user's ask: like, favorite, join): FreeGiftCoins, FreeGiftStrength and
-- FreeGiftSpeed once per player ever.
-- The client sends it after Roblox's favorite prompt worked and the player is in the group. Likes and favorites can't
-- be checked by a game, so those are on trust; the membership is looked up here (GetGroupsAsync, not the cached
-- IsInGroup, so a join made a moment ago counts).
local function inGroup(player: Player): boolean
	local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
	if not ok or typeof(groups) ~= "table" then
		return false
	end
	for _, group in groups do
		if typeof(group) == "table" and group.Id == GameConfig.Economy.GroupId then
			return true
		end
	end
	return false
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
	if not inGroup(player) or DataService.get(player) ~= profile or profile.FreeGiftClaimed ~= 0 then
		return -- not in it, or they left or claimed while we were looking
	end
	DataService.set(player, "FreeGiftClaimed", 1)
	DataService.add(player, "Coins", GameConfig.Economy.FreeGiftCoins)
	DataService.add(player, "Strength", GameConfig.Economy.FreeGiftStrength)
	DataService.add(player, "Speed", GameConfig.Economy.FreeGiftSpeed)
	Analytics.earned(player, GameConfig.Economy.FreeGiftCoins, "FreeGift", Enum.AnalyticsEconomyTransactionType.Onboarding)
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
	Remotes.event("BuySeed").OnServerEvent:Connect(onBuySeed)
	Remotes.event("BuyCharacter").OnServerEvent:Connect(onBuyCharacter)
end

return EconomyService
