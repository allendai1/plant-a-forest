--!strict
-- Checks for GameConfig.seedsPerHexFor (the forest's size follows the server, 2026-10-08). Not shipped: run it in
-- Studio's Edit mode through the Studio connection; it returns "ForestSize: all checks passed" or errors.

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)
local sherwood, kyoto = GameConfig.Tiers[1], GameConfig.Tiers[2]
local PLOTS = 540
local min = GameConfig.ForestSize.MinSeedsPerHex

assert(GameConfig.seedsPerHexFor(sherwood, 0, PLOTS) == min, "an empty server gets the smallest forest")
assert(GameConfig.seedsPerHexFor(sherwood, 1, PLOTS) == min, "solo is the floor")
assert(GameConfig.seedsPerHexFor(sherwood, 10, PLOTS) == math.ceil(10 * sherwood.SeedsPerPlayer / PLOTS), "scales with players")
assert(GameConfig.seedsPerHexFor(sherwood, 50, PLOTS) == sherwood.SeedsPerHex, "a full server is capped at the world's size")
assert(
	GameConfig.seedsPerHexFor(sherwood, 5, PLOTS) < GameConfig.seedsPerHexFor(sherwood, 20, PLOTS),
	"more players, bigger trees"
)
assert(GameConfig.seedsPerHexFor(kyoto, 10, PLOTS) > GameConfig.seedsPerHexFor(sherwood, 10, PLOTS), "later worlds are bigger")

return "ForestSize: all checks passed"
