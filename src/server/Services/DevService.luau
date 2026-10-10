--!strict
-- DevService: Studio-only test commands (docs/ARCHITECTURE.md section 5).
-- Outside Studio it does nothing, so live servers never have the DevCommand remote.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local ForestService = require(script.Parent.ForestService)
local AwakeningService = require(script.Parent.AwakeningService)
local PassService = require(script.Parent.PassService)
local ProductService = require(script.Parent.ProductService)
local TutorialService = require(script.Parent.TutorialService)
local Guard = require(script.Parent.Parent.Guard)

local STATS: { [string]: DataService.StatKey } = {
	setStrength = "Strength",
	setSpeed = "Speed",
	setForestsCompleted = "ForestsCompleted",
	setCoins = "Coins",
	setBulkPickupLevel = "BulkPickupLevel",
	setBulkPlantLevel = "BulkPlantLevel",
	setPlantingRangeLevel = "PlantingRangeLevel",
	setTutorialStep = "TutorialStep", -- 8 = done (GameConfig.Tutorial.DoneStep)
	setFirstTreeDone = "FirstTreeDone", -- 0: your next finished tree is your "first" again
	setSpringGuideSeen = "SpringGuideSeen", -- 0: the first-break guide shows again
	setQuestIndex = "QuestIndex", -- the starter quest you're on (1-8; 9 = all done)
}

local UPGRADE_BUYS: { [string]: string } = {
	buyBulkPickup = "BulkPickup",
	buyBulkPlant = "BulkPlant",
	buyPlantingRange = "PlantingRange",
}

local DevService = {}

-- "Save my stats" / "Load saved stats" (the user's request, 2026-10-07): every number in your profile (stats,
-- coins, upgrade levels, forests, tutorial step, settings), kept in a Studio-only store so it survives sessions.
local snapshots = DataStoreService:GetDataStore("DevSnapshots_Studio")

local fakeReceipts = 0
local lastReceipt: { [string]: any }? = nil

-- A fake receipt through the real handler (Studio can't complete real purchases).
local function fakeBuy(player: Player, productId: number?): boolean
	if not productId then
		return false
	end
	fakeReceipts += 1
	lastReceipt = { PurchaseId = `dev-{fakeReceipts}-{os.time()}`, ProductId = productId, PlayerId = player.UserId }
	task.spawn(function()
		print(`[DevService] receipt {productId}: {ProductService.process(lastReceipt :: any)}`)
	end)
	return true
end

local function run(player: Player, command: string, value: number): boolean
	local key: DataService.StatKey? = STATS[command]
	if key then
		local upgrade = GameConfig.Upgrades[(key:gsub("Level$", ""))]
		DataService.set(player, key, math.floor(if upgrade then math.min(value, upgrade.MaxLevel) else value))
		return true
	elseif command == "resetProfile" then -- back to a brand-new player's values
		DataService.devReset(player)
		return true
	elseif command == "saveSnapshot" then
		local data = DataService.get(player)
		if not data then
			return false
		end
		local copy = {}
		for name, stat in data :: any do
			if typeof(stat) == "number" and name ~= "Version" then
				copy[name] = stat
			end
		end
		local ok, err = pcall(snapshots.SetAsync, snapshots, tostring(player.UserId), copy)
		if not ok then
			warn(`[DevService] couldn't save the snapshot: {err}`)
		end
		return ok
	elseif command == "loadSnapshot" then
		local data = DataService.get(player)
		local ok, saved = pcall(snapshots.GetAsync, snapshots, tostring(player.UserId))
		if not (data and ok and typeof(saved) == "table") then
			warn("[DevService] no saved snapshot to load")
			return false
		end
		for name, stat in saved do
			if typeof((data :: any)[name]) == "number" and typeof(stat) == "number" then
				DataService.set(player, name :: any, stat)
			end
		end
		return true
	elseif command == "grantPass" and GameConfig.StationPasses[value] then
		PassService.grant(player, value)
		return true
	elseif command == "clearStationPasses" then
		PassService.revokeStations(player)
		return true
	elseif command == "grantHands" then -- value = 2 or 5 (the passes' multipliers); 1 takes them away
		PassService.grantHands(player, value)
		return true
	elseif command == "grantStrengthBoost" or command == "grantSpeedBoost" then -- value 1 takes them away
		PassService.grantBoost(player, if command == "grantStrengthBoost" then "Strength" else "Speed", value)
		return true
	elseif command == "buyBar" then -- value = which button (1-4)
		local boost = GameConfig.BarBoosts[value]
		return fakeBuy(player, boost and boost.ProductId)
	elseif command == "buyStrengthBoost" or command == "buySpeedBoost" then -- value = the boost's step (1 = first)
		local step = GameConfig.Boosts[if command == "buyStrengthBoost" then "Strength" else "Speed"][value]
		return fakeBuy(player, step and step.ProductId)
	elseif command == "buyServerBoost" then
		return fakeBuy(player, GameConfig.ServerBoost.ProductId)
	elseif UPGRADE_BUYS[command] then -- value = the level's product
		return fakeBuy(player, GameConfig.UpgradeProducts[UPGRADE_BUYS[command]][value])
	elseif command == "grantSeed" and GameConfig.SeedShop.Seeds[value] then -- value = which seed (1-4)
		DataService.addToBag(player, GameConfig.SeedShop.Seeds[value].Id, 1)
		return true
	elseif command == "buySeed" and GameConfig.SeedShop.Seeds[value] then -- the seed's Robux product, faked
		return fakeBuy(player, GameConfig.SeedShop.Seeds[value].ProductId)
	elseif command == "setTier" and GameConfig.Tiers[value] then -- start a fresh forest in this world
		AwakeningService.stop() -- a break still running would keep the last forest's spring multiplier
		ForestService.setTier(value)
		ForestService.reset()
		return true
	elseif command == "resendReceipt" and lastReceipt then -- the same PurchaseId again: must not grant twice
		local receipt = lastReceipt
		task.spawn(function()
			print(`[DevService] resent receipt {receipt.ProductId}: {ProductService.process(receipt)}`)
		end)
		return true
	elseif command == "setFriendBoost" then -- value = percent
		player:SetAttribute("FriendBoost", value / 100)
		return true
	elseif command == "setCarried" then
		CarryService.devSet(player, value)
		return true
	elseif command == "fillOpenRow" then -- the open ring; value = how many open plots to leave empty
		ForestService.devFillOpenRow(value)
		return true
	elseif command == "fillAll" then -- value = how many plots of the last row to leave empty
		ForestService.devFillAll(value)
		return true
	elseif command == "extendBreak" then -- value = minutes, as if bought
		AwakeningService.extend(player, value)
		return true
	elseif command == "pickWorld" and GameConfig.Tiers[value] then -- value = tier index, as if bought
		AwakeningService.pickWorld(player, value)
		return true
	elseif command == "restartTutorial" then -- back to the story intro (stats unchanged)
		TutorialService.devRestart(player)
		return true
	elseif command == "setForestPlanted" then -- value = acorns put into this forest (forest credit)
		ForestService.devSetPlanted(player, value)
		return true
	elseif command == "endAwakening" then
		AwakeningService.finish()
		return true
	elseif command == "fillForest" and value <= 1 then -- value = fraction of the Forest Bar
		ForestService.devFillForest(value)
		return true
	end
	return false
end

function DevService.init()
	if not RunService:IsStudio() then
		return
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = "DevCommand"
	remote.OnServerEvent:Connect(function(player: Player, command: unknown, value: unknown)
		local rate = GameConfig.Dev.CommandRate
		if not Guard.allow(player, "DevCommand", rate.PerSecond, rate.Burst) then
			return
		end
		if typeof(command) ~= "string" or typeof(value) ~= "number" then
			return
		end
		-- value ~= value rejects NaN; the range check rejects infinities and negatives.
		if value ~= value or value < 0 or value > GameConfig.Dev.MaxStatValue then
			return
		end
		if run(player, command, value) then
			print(`[DevService] {player.Name}: {command} {value}`)
		end
	end)
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
end

return DevService
