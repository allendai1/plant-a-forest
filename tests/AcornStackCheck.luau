--!strict
-- Checks for GameConfig.acornStack (the acorn stack over the head, 2026-10-08). Not shipped: run it in Studio's
-- Edit mode through the Studio connection; it returns "AcornStack: all checks passed" or errors on the first failure.

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)
local stack = GameConfig.AcornStack
local close = function(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

assert(#GameConfig.acornStack(0) == 0, "no seeds, no acorn")
local one = GameConfig.acornStack(1)
assert(#one == 1 and close(one[1], stack.MinSize), "one seed is the smallest acorn")
local full = GameConfig.acornStack(stack.PerAcorn)
assert(#full == 1 and close(full[1], stack.MaxSize), "a full acorn is the biggest")
local second = GameConfig.acornStack(stack.PerAcorn + 1)
assert(#second == 2 and close(second[1], stack.MaxSize) and close(second[2], stack.MinSize), "one more starts a second acorn")
assert(GameConfig.acornStack(10)[1] < GameConfig.acornStack(11)[1], "more seeds, a bigger acorn")
local lots = GameConfig.acornStack(stack.PerAcorn * stack.MaxStack * 3)
assert(#lots == stack.MaxStack and close(lots[#lots], stack.MaxSize), "the stack stops at MaxStack full acorns")

return "AcornStack: all checks passed"
