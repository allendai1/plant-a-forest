--!strict
-- TreeCounterService: every tree grown in every server, ever (2026-10-09, the user's pick: trees, not acorns).
-- ForestService calls add() for each tree that becomes full grown. Every FLUSH_SECONDS this server adds its unsent
-- trees to one DataStore number and reads back the total (other servers' trees included). The total plus this
-- server's unsent trees is published as the ReplicatedStorage attribute TreesGrown, so the hub's counter board
-- (TreeCounterController) ticks up with every tree here and jumps once a minute with everyone else's.
-- Studio play sessions use their own store (suffix _Studio), like DataService.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FLUSH_SECONDS = 60
local KEY = "TreesGrown"

local TreeCounterService = {}

local store: DataStore? = nil
local stored = 0 -- the total as last read from the store
local unsent = 0 -- trees grown here since the last write

local function publish()
	ReplicatedStorage:SetAttribute("TreesGrown", stored + unsent)
end

function TreeCounterService.add(count: number)
	unsent += count
	publish()
end

-- Adds the unsent trees to the store (or only reads it when there are none) and keeps the total it returns.
local function flush()
	local s = store
	if not s then
		return
	end
	local sending = unsent
	local ok, result = pcall(function(): any
		if sending == 0 then
			return s:GetAsync(KEY)
		end
		return s:UpdateAsync(KEY, function(old: any)
			return (if typeof(old) == "number" then old else 0) + sending
		end)
	end)
	if not ok then
		warn(`[TreeCounterService] {result}`) -- the trees stay unsent and go with the next try
		return
	end
	unsent -= sending
	stored = if typeof(result) == "number" then result else stored
	publish()
end

function TreeCounterService.init()
	store = DataStoreService:GetDataStore(`GlobalStats{if RunService:IsStudio() then "_Studio" else ""}`)
	publish()
end

function TreeCounterService.start()
	game:BindToClose(function()
		if unsent > 0 then
			flush()
		end
	end)
	while true do
		flush()
		task.wait(FLUSH_SECONDS)
	end
end

return TreeCounterService
