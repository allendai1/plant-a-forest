--!strict
-- Checks for the seed shop's shared data (docs/plans/SeedShop.md). Not shipped: run it in Studio's Edit mode
-- through the Studio connection; it returns "SeedShop: all checks passed" or errors on the first failure.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Trees = require(ReplicatedStorage.Shared.Trees)

local shop = GameConfig.SeedShop

-- Every seed is a special species with its 8 stage models, a seed model, a rarity color and a product.
for _, def in shop.Seeds do
	assert(GameConfig.seedDef(def.Id) == def, `seedDef should find {def.Id}`)
	assert(Trees.isSpecial(Trees.index(def.Id)), `{def.Id} should be a special species`)
	assert(Trees.RarityColors[def.Rarity], `{def.Id}: unknown rarity {def.Rarity}`)
	assert(def.StockMin >= 1 and def.StockMax >= def.StockMin, `{def.Id}: bad stock range`)
	assert(def.ProductId ~= 0, `{def.Id}: no Robux product`)
	for stage = 1, #GameConfig.Growth.StageStarts do
		assert(ReplicatedStorage.Assets.Trees:FindFirstChild(`{def.Id}{stage}`), `missing model {def.Id}{stage}`)
	end
	assert(ReplicatedStorage.Assets.Seeds:FindFirstChild(def.Id .. "Seed"), `missing seed model {def.Id}Seed`)
end
assert(GameConfig.seedDef("Leafy") == nil and GameConfig.seedDef("") == nil, "only special seeds are sold")
-- Every world's Common trees exist, have their 8 models and aren't special (no boost).
for _, tier in GameConfig.Tiers do
	for _, name in tier.Commons do
		local species = Trees.index(name)
		assert(species > 0 and not Trees.isSpecial(species), `{tier.Name}: {name} should be a Common species`)
		for stage = 1, #GameConfig.Growth.StageStarts do
			local model = Trees.model(species) :: string
			assert(ReplicatedStorage.Assets.Trees:FindFirstChild(`{model}{stage}`), `missing model {model}{stage}`)
		end
	end
end

-- The roulette's pick follows the weights (80/20 with two worlds).
assert(GameConfig.pickTier(0) == 1 and GameConfig.pickTier(0.79) == 1, "rolls under 80% pick world 1")
assert(GameConfig.pickTier(0.8) == 2 and GameConfig.pickTier(0.999) == 2, "rolls from 80% pick world 2")

-- The stock: the same restock always rolls the same, within each seed's range, and it changes between
-- restocks. Over many restocks each seed is in stock about as often as its StockChance.
local inStock: { [string]: number } = {}
local changes = 0
local RESTOCKS = 4000
local first = GameConfig.restockIndex(1_790_000_000)
for n = first, first + RESTOCKS - 1 do
	local a, b = GameConfig.seedStock(n), GameConfig.seedStock(n)
	local differs = false
	for _, def in shop.Seeds do
		assert(a[def.Id] == b[def.Id], "the same restock should roll the same stock")
		local amount = a[def.Id]
		assert(amount == 0 or (amount >= def.StockMin and amount <= def.StockMax), `{def.Id}: {amount} out of range`)
		if amount > 0 then
			inStock[def.Id] = (inStock[def.Id] or 0) + 1
		end
		if amount ~= GameConfig.seedStock(n + 1)[def.Id] then
			differs = true
		end
	end
	if differs then
		changes += 1
	end
end
assert(changes > RESTOCKS / 2, "most restocks should differ from the next one")
for _, def in shop.Seeds do
	local share = (inStock[def.Id] or 0) / RESTOCKS
	assert(math.abs(share - def.StockChance) < 0.03, `{def.Id} in stock {share}, expected about {def.StockChance}`)
end

-- The restock number steps once every RestockSeconds.
local t = first * shop.RestockSeconds
assert(GameConfig.restockIndex(t) == first, "restock at its start time")
assert(GameConfig.restockIndex(t + shop.RestockSeconds - 0.01) == first, "same restock until the next starts")
assert(GameConfig.restockIndex(t + shop.RestockSeconds) == first + 1, "next restock")

return "SeedShop: all checks passed"
