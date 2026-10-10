--!strict
-- DataService: player profiles (docs/ARCHITECTURE.md sections 3 and 7, docs/plans/M8.md).
-- Saved with ProfileStore (src/server/Vendor): one session-locked DataStore key per player, autosaved
-- every few minutes, saved when the player leaves and when the server shuts down. If another server
-- takes the profile over, or it can't be loaded, the player is kicked rather than playing on data that
-- could overwrite their save. Every write also sets the matching Player attribute, a display copy for
-- clients. The rest of the game only uses get, set and add, and ProductService uses grantPurchase.
-- The seed shop (docs/plans/SeedShop.md) keeps the seed bag and this restock's purchases in two tables,
-- changed only through bagCount/addToBag and bought/addBought, which set the Bag_<id> and Bought_<id>
-- attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Parent.Guard)
local Analytics = require(script.Parent.Parent.Analytics)

local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore)

export type Profile = {
	Version: number,
	Strength: number,
	Speed: number,
	ForestsCompleted: number,
	Coins: number,
	BulkPickupLevel: number,
	BulkPlantLevel: number,
	PlantingRangeLevel: number,
	SeedsPlanted: number, -- lifetime (M10: the tutorial step comes from it)
	FreeGiftClaimed: number, -- 0 or 1
	SpringGuideSeen: number, -- 1 once they've stood in the Ancient Spring (the first-break guide stops)
	FirstTreeDone: number, -- 1 once they've finished a tree (the first one pays Economy.FirstTreeCoins)
	QuestIndex: number, -- the starter quest they're on (GameConfig.Quests; past the end = all done)
	TreesFinished: number, -- trees they planted the last acorn of, ever (a quest counts it)
	RingsHelped: number, -- rings that finished while they'd planted in them, ever (a quest counts it)
	GroupGiftClaimed: number, -- 0 or 1: joined the group at the group gift board (EconomyService)
	StrengthBoostBought: number, -- the highest Strength boost bought (a developer product; 1 = none)
	SpeedBoostBought: number, -- the highest Speed boost bought (1 = none)
	WalkCap: number, -- the player's own walk speed limit (0 = none)
	GuideArrow: number, -- the guide arrow setting: 1 = shown, 0 = hidden
	TutorialStep: number, -- 0 = story intro not seen, then GameConfig.Tutorial.Steps, DoneStep = finished
	Music: number, -- the music setting: 1 = on, 0 = off (polish pass)
	Effects: number, -- the sound effects setting: 1 = on, 0 = off
	PlayTimeSeconds: number, -- total time played, +PLAYTIME_STEP every PLAYTIME_STEP online (analytics)
	Purchases: { string }, -- PurchaseIds of the last MAX_PURCHASES saved-data product receipts (GUI pass)
	SeedBag: { [string]: number }, -- special seeds owned, by seed id (seed shop)
	ShopRestock: number, -- the restock ShopBought counts belong to
	ShopBought: { [string]: number }, -- seeds bought in that restock, by seed id
	RedeemedCodes: { string }, -- GameConfig.Codes names this player has used (CodeService)
}
export type StatKey =
	"Strength"
	| "Speed"
	| "ForestsCompleted"
	| "Coins"
	| "BulkPickupLevel"
	| "BulkPlantLevel"
	| "PlantingRangeLevel"
	| "SeedsPlanted"
	| "FreeGiftClaimed"
	| "SpringGuideSeen"
	| "FirstTreeDone"
	| "QuestIndex"
	| "TreesFinished"
	| "RingsHelped"
	| "GroupGiftClaimed"
	| "StrengthBoostBought"
	| "SpeedBoostBought"
	| "WalkCap"
	| "GuideArrow"
	| "Music"
	| "Effects"
	| "TutorialStep"
	| "PlayTimeSeconds"
	| "ShopRestock"

local VERSION = 2 -- bump when a field is renamed or reshaped, and add a step to migrate()
local TEMPLATE: Profile = {
	Version = VERSION,
	Strength = 0,
	Speed = 0,
	ForestsCompleted = 0,
	Coins = 0,
	BulkPickupLevel = 0,
	BulkPlantLevel = 0,
	PlantingRangeLevel = 0,
	SeedsPlanted = 0,
	FreeGiftClaimed = 0,
	SpringGuideSeen = 0,
	FirstTreeDone = 0,
	QuestIndex = 1,
	TreesFinished = 0,
	RingsHelped = 0,
	GroupGiftClaimed = 0,
	StrengthBoostBought = 1,
	SpeedBoostBought = 1,
	WalkCap = 0,
	GuideArrow = 1,
	Music = 1,
	Effects = 1,
	TutorialStep = 0,
	PlayTimeSeconds = 0,
	Purchases = {},
	SeedBag = {},
	ShopRestock = 0,
	ShopBought = {},
	RedeemedCodes = {},
}
-- Studio play sessions save to their own store, so tests never touch the real game's saves.
local STORE_NAME = if RunService:IsStudio() then "PlayerData_Studio" else "PlayerData"
local LOAD_FAILED = "Couldn't load your data. Please rejoin."
local SESSION_TAKEN = "Your data was opened on another server. Please rejoin."
local MAX_PURCHASES = 50
-- ponytail: up to a minute of each visit isn't counted (the last part before leaving); fine for analytics.
local PLAYTIME_STEP = 60
local PURCHASE_SAVE_SECONDS = 15

local DataService = {}

local store = ProfileStore.New(STORE_NAME, TEMPLATE)
local sessions: { [Player]: any } = {} -- the ProfileStore profile of each loaded player
local profiles: { [Player]: Profile } = {} -- its Data table, which is what gets saved

-- Brings an older save up to VERSION, one step at a time. Nothing to migrate yet.
local function migrate(data: Profile)
	if data.Version < 2 then
		-- Planting Range went from 10 levels of +4 studs to 4 levels of +28 (one tree each) on 2026-10-09. Rounded up,
		-- so nobody loses reach: old levels 1-7 become 1, 8-10 become 2.
		data.PlantingRangeLevel =
			math.min(math.ceil(data.PlantingRangeLevel * 4 / 28), GameConfig.Upgrades.PlantingRange.MaxLevel)
	end
	data.Version = VERSION
end

local function load(player: Player)
	local session = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players -- stop trying if they left while it loaded
		end,
	})
	if session == nil then
		if player.Parent == Players then
			player:Kick(LOAD_FAILED)
		end
		return
	end
	session:AddUserId(player.UserId) -- GDPR: links the save to the player
	session:Reconcile() -- fills in fields added to TEMPLATE since this save was made
	local data = session.Data :: Profile
	migrate(data)
	-- ponytail: a save from before FirstTreeDone with 50+ acorns planted almost surely finished a tree already, so
	-- it gets no "first tree" reward; a few with fewer may get it late.
	if data.FirstTreeDone == 0 and data.SeedsPlanted >= 50 then
		data.FirstTreeDone = 1
	end
	if data.TutorialStep == 0 and data.SeedsPlanted > 0 then
		data.TutorialStep = GameConfig.Tutorial.DoneStep -- played before the tutorial had saved steps
	elseif data.TutorialStep == 0 and not GameConfig.Features.TutorialIntro then
		data.TutorialStep = 1 -- skip the story intro
	end
	session.OnSessionEnd:Connect(function()
		sessions[player] = nil
		profiles[player] = nil
		player:Kick(SESSION_TAKEN) -- harmless when they're already leaving
	end)
	if player.Parent ~= Players then
		session:EndSession()
		return
	end
	sessions[player] = session
	profiles[player] = data
	for key, value in data :: any do
		if typeof(value) == "number" and key ~= "Version" then
			player:SetAttribute(key, value)
		end
	end
	for _, def in GameConfig.SeedShop.Seeds do
		player:SetAttribute(`Bag_{def.Id}`, data.SeedBag[def.Id] or 0)
		player:SetAttribute(`Bought_{def.Id}`, data.ShopBought[def.Id] or 0)
	end
	Analytics.onboarding(player, "Joined")
end

function DataService.get(player: Player): Profile?
	return profiles[player]
end

function DataService.set(player: Player, key: StatKey, value: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile[key] = value
	player:SetAttribute(key, value)
end

function DataService.add(player: Player, key: StatKey, amount: number)
	local profile = profiles[player]
	if profile then
		DataService.set(player, key, profile[key] + amount)
	end
end

function DataService.bagCount(player: Player, seedId: string): number
	local profile = profiles[player]
	return if profile then profile.SeedBag[seedId] or 0 else 0
end

-- Adds (or with a negative amount, takes) seeds in the player's bag.
function DataService.addToBag(player: Player, seedId: string, amount: number)
	local profile = profiles[player]
	if profile then
		local count = math.max(0, (profile.SeedBag[seedId] or 0) + amount)
		profile.SeedBag[seedId] = count
		player:SetAttribute(`Bag_{seedId}`, count)
	end
end

-- Seeds of this kind the player bought in restock n (counts from an older restock don't count). A
-- server whose clock is still on an older restock than the saved one counts it as bought out.
function DataService.bought(player: Player, restock: number, seedId: string): number
	local profile = profiles[player]
	if not profile or profile.ShopRestock < restock then
		return 0
	elseif profile.ShopRestock > restock then
		return math.huge
	end
	return profile.ShopBought[seedId] or 0
end

function DataService.addBought(player: Player, restock: number, seedId: string, amount: number)
	local profile = profiles[player]
	if not profile or profile.ShopRestock > restock then
		return
	end
	if profile.ShopRestock < restock then -- a new restock: start counting again
		table.clear(profile.ShopBought)
		DataService.set(player, "ShopRestock", restock)
		for _, def in GameConfig.SeedShop.Seeds do
			player:SetAttribute(`Bought_{def.Id}`, 0)
		end
	end
	local count = (profile.ShopBought[seedId] or 0) + amount
	profile.ShopBought[seedId] = count
	player:SetAttribute(`Bought_{seedId}`, count)
end

-- A developer product that changes saved data: runs grant() once per PurchaseId, records the id in the
-- profile, and waits until a save holds it. false = not saved yet; Roblox sends the receipt again later
-- and the recorded id stops it from being granted twice.
function DataService.grantPurchase(player: Player, purchaseId: string, grant: () -> ()): boolean
	local session = sessions[player]
	local profile = profiles[player]
	if not (session and profile) then
		return false
	end
	if not table.find(profile.Purchases, purchaseId) then
		grant()
		table.insert(profile.Purchases, purchaseId)
		if #profile.Purchases > MAX_PURCHASES then
			table.remove(profile.Purchases, 1)
		end
	end
	session:Save()
	local deadline = os.clock() + PURCHASE_SAVE_SECONDS
	while session:IsActive() and os.clock() < deadline do
		local saved = session.LastSavedData
		if saved and table.find(saved.Purchases or {}, purchaseId) then
			return true
		end
		task.wait(0.5)
	end
	return false
end

-- Studio-only testing (DevService): back to a brand-new player's values.
function DataService.devReset(player: Player)
	for key, value in TEMPLATE :: any do
		if typeof(value) == "number" and key ~= "Version" then
			DataService.set(player, key, value)
		end
	end
	for _, def in GameConfig.SeedShop.Seeds do
		DataService.addToBag(player, def.Id, -math.huge)
	end
end

function DataService.init()
	-- The Settings toggles: settings that only change saved data (1 = on, 0 = off).
	local toggles: { [string]: StatKey } = { GuideArrow = "GuideArrow", Music = "Music", Effects = "Effects" }
	Remotes.event("SetSetting").OnServerEvent:Connect(function(player: Player, name: unknown, on: unknown)
		local rate = GameConfig.Settings.Rate
		local key: StatKey? = if typeof(name) == "string" then toggles[name] else nil
		if Guard.allow(player, "SetSetting", rate.PerSecond, rate.Burst) and key and typeof(on) == "boolean" then
			DataService.set(player, key, if on then 1 else 0)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	task.spawn(function()
		while true do
			task.wait(PLAYTIME_STEP)
			for player in profiles do
				DataService.add(player, "PlayTimeSeconds", PLAYTIME_STEP)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		sessions[player] = nil
		profiles[player] = nil
		if session then
			session:EndSession() -- saves and releases the session lock
		end
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
end

return DataService
