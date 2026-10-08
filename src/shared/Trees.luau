--!strict
-- Trees: tree species ids, shared so the server's pick and the client's models agree.
-- A plot's species is the index into Species (0 = no tree yet). Models live in
-- ReplicatedStorage.Assets.Trees as <Model><stage>, e.g. Leafy3; a species uses its own name's models
-- unless Models maps it to another's.
-- Special trees are the ones the seed shop sells (GameConfig.SeedShop.Seeds, docs/plans/SeedShop.md);
-- every other species is a Common tree, which each world's free acorns grow (GameConfig.Tiers[].Commons).
-- The Sakura & Bamboo world's Common trees look like the shop's Cherry Blossom and Bamboo (same models)
-- but have their own species, so they don't count as special and give no boost.

local GameConfig = require(script.Parent.GameConfig)

local Trees = {}

-- New species go at the end: a plot's species is saved as its index.
Trees.Species =
	{ "Leafy", "Pine", "Palm", "Sakura", "Redwood", "Crystal", "Bamboo", "WildSakura", "WildBamboo", "Maple", "Birch" }
Trees.Models = { WildSakura = "Sakura", WildBamboo = "Bamboo" } :: { [string]: string }

-- Look (not balance): the rarity colors in the shop, the bag, the target outline and the name label.
Trees.RarityColors = {
	Uncommon = Color3.fromRGB(110, 230, 90),
	Rare = Color3.fromRGB(80, 170, 255),
	Epic = Color3.fromRGB(190, 100, 255),
	Legendary = Color3.fromRGB(255, 200, 60),
} :: { [string]: Color3 }

-- The species index of a name (0 if unknown).
function Trees.index(name: string): number
	return table.find(Trees.Species, name) or 0
end

-- The model name prefix a species' stages use (nil for no tree).
function Trees.model(species: number): string?
	local name = Trees.Species[species]
	return if name then Trees.Models[name] or name else nil
end

function Trees.isSpecial(species: number): boolean
	return GameConfig.seedDef(Trees.Species[species] or "") ~= nil
end

return Trees
