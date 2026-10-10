--!strict
-- LeaderboardService: the global leaderboards (polish pass, 2026-10-07) and the in-server player list.
-- - Global: each stat in GameConfig.Leaderboards.Stats has an OrderedDataStore (keyed by UserId). Players'
--   values are written every WriteSeconds (only when changed) and when they leave; the top Size are read every
--   ReadSeconds and published as JSON in ReplicatedStorage.Leaderboards.<Stat> (a StringValue:
--   [{ id, name, value }]). LeaderboardController draws them on the lobby boards.
-- - In-server: a leaderstats folder (Forests, Seeds, Strength, Speed) so Roblox's player list shows and sorts them.
-- Studio play sessions use their own stores (suffix _Studio), like DataService.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local SUFFIX = if RunService:IsStudio() then "_Studio" else ""
-- The player list's columns: attribute -> column name (the first one sorts the list).
-- Forests, Seeds (lifetime seeds planted), Strength and Speed since 2026-10-08, like the lobby boards.
local PLAYER_LIST = {
	{ attribute = "ForestsCompleted", name = "Forests" },
	{ attribute = "SeedsPlanted", name = "Seeds" },
	{ attribute = "Strength", name = "Strength" },
	{ attribute = "Speed", name = "Speed" },
}

type Entry = { id: number, name: string, value: number }

local LeaderboardService = {}

local stores: { [string]: OrderedDataStore } = {}
local written: { [Player]: { [string]: number } } = {} -- the last value saved per stat
local names: { [number]: string } = {} -- display names, asked once per user
local folder: Folder

local function storeOf(stat: string): OrderedDataStore
	local store = stores[stat]
	if not store then
		store = DataStoreService:GetOrderedDataStore(`Top_{stat}{SUFFIX}`)
		stores[stat] = store
	end
	return store
end

local function write(player: Player)
	local mine = written[player]
	if not mine then
		return
	end
	for _, stat in GameConfig.Leaderboards.Stats do
		local value = player:GetAttribute(stat)
		if typeof(value) == "number" then
			local whole = math.floor(value)
			if whole > 0 and mine[stat] ~= whole then
				local ok, err = pcall(function()
					storeOf(stat):SetAsync(tostring(player.UserId), whole)
				end)
				if ok then
					mine[stat] = whole
				else
					warn(`[LeaderboardService] couldn't save {stat}: {err}`)
				end
			end
		end
	end
end

-- Display names for these users (one web call for all the ones not cached yet).
local function lookUpNames(ids: { number })
	local missing = {}
	for _, id in ids do
		if not names[id] then
			table.insert(missing, id)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, missing)
	if ok and typeof(infos) == "table" then
		for _, info in infos do
			names[info.Id] = info.DisplayName
		end
	end
end

local function read(stat: string)
	local ok, pages = pcall(function()
		return storeOf(stat):GetSortedAsync(false, GameConfig.Leaderboards.Size)
	end)
	if not ok then
		warn(`[LeaderboardService] couldn't read {stat}: {pages}`)
		return
	end
	local page = (pages :: DataStorePages):GetCurrentPage()
	local ids = {}
	for _, row in page do
		local id = tonumber(row.key)
		if id then
			table.insert(ids, id)
		end
	end
	lookUpNames(ids)
	local entries: { Entry } = {}
	for _, row in page do
		local id = tonumber(row.key)
		if id then
			table.insert(entries, { id = id, name = names[id] or `Player {id}`, value = row.value })
		end
	end
	local value = folder:FindFirstChild(stat) :: StringValue
	value.Value = HttpService:JSONEncode(entries)
end

local function onPlayerAdded(player: Player)
	written[player] = {}
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	-- Roblox's player list doesn't keep the creation order (it showed Speed, Strength, Forests, Seeds), so each
	-- column gets a Priority value (lower shows first) and the first one is marked IsPrimary (the list sorts by it).
	for i, column in PLAYER_LIST do
		local value = Instance.new("NumberValue")
		value.Name = column.name
		local priority = Instance.new("NumberValue")
		priority.Name = "Priority"
		priority.Value = i
		priority.Parent = value
		if i == 1 then
			local primary = Instance.new("BoolValue")
			primary.Name = "IsPrimary"
			primary.Value = true
			primary.Parent = value
		end
		local function sync()
			local attribute = player:GetAttribute(column.attribute)
			value.Value = if typeof(attribute) == "number" then math.floor(attribute) else 0
		end
		player:GetAttributeChangedSignal(column.attribute):Connect(sync)
		sync()
		value.Parent = stats
	end
	stats.Parent = player
end

function LeaderboardService.init()
	folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	for _, stat in GameConfig.Leaderboards.Stats do
		local value = Instance.new("StringValue")
		value.Name = stat
		value.Value = "[]"
		value.Parent = folder
	end
	folder.Parent = ReplicatedStorage
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		write(player) -- attributes are still there while PlayerRemoving runs
		written[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			write(player)
		end
	end)
end

function LeaderboardService.start()
	local board = GameConfig.Leaderboards
	task.spawn(function()
		while true do
			task.wait(board.WriteSeconds)
			for _, player in Players:GetPlayers() do
				write(player)
			end
		end
	end)
	while true do
		for _, stat in board.Stats do
			read(stat)
		end
		task.wait(board.ReadSeconds)
	end
end

return LeaderboardService
