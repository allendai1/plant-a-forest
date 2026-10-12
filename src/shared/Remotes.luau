--!strict
-- Remotes: the one list of every RemoteEvent and RemoteFunction (docs/ARCHITECTURE.md section 5).
-- The server creates them at startup with createAll(); everything else only looks them up.
-- DevCommand is left out on purpose: DevService creates it in Studio only.
-- Payload types are added next to each name in the milestone that first uses that remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type EventName =
	"PlantSeeds" -- C->S: q, r
	| "BuyUpgrade"
	| "HexBatch" -- S->C: Types.HexBatch
	| "AwakeningReward" -- S->C: { coins: number, planted: number?, needed: number? } (coins 0 = no forest credit)
	| "ClaimFreeGift" -- C->S, no payload: the free gift, after favoriting and joining the group (the server checks the group)
	| "LeaveBench" -- C->S, no payload
	| "StationLocked" -- S->C: multiplier, forestsNeeded
	| "SetWalkCap" -- C->S: cap (studs per second; 0 = no limit)
	| "BuySeed" -- C->S: seedId (docs/plans/SeedShop.md)
	| "PlantSpecial" -- C->S: seedId, q, r
	| "SetSetting" -- C->S: name ("GuideArrow" | "Music" | "Effects"), on (boolean): the Settings toggles
	| "RobuxShopOpened" -- C->S, no payload: analytics only (the RobuxShop funnel)
	| "TutorialIntroDone" -- C->S, no payload: the story intro was watched or skipped (TutorialStep 0 -> 1)
	| "DropSeeds" -- C->S, no payload: drop everything you carry (lobby only, CarryService)
	| "ClaimQuest" -- C->S, no payload: claim the current starter quest (QuestService)
	| "EquipHat" -- C->S: rank index (1..#Ranks, a rank reached) or 0 = always the newest (OutfitService)
	| "ClaimDaily" -- C->S, no payload: today's daily reward (DailyService)
	| "BuyCharacter" -- C->S: a GameConfig.HandsPasses index, bought with coins (EconomyService)
	| "LuckyPlanks" -- S->C: { position, count, ... }: planks that came back to your hands, by the slot they were placed in

-- GetForest: () -> Types.Snapshot? (nil when rate-limited)
-- RedeemCode: (code: string) -> (ok: boolean, message: string), the CODES panel (CodeService)
export type FunctionName = "GetForest" | "RedeemCode"

local EVENTS: { EventName } = {
	"PlantSeeds",
	"BuyUpgrade",
	"HexBatch",
	"AwakeningReward",
	"ClaimFreeGift",
	"LeaveBench",
	"StationLocked",
	"SetWalkCap",
	"BuySeed",
	"PlantSpecial",
	"SetSetting",
	"RobuxShopOpened",
	"TutorialIntroDone",
	"DropSeeds",
	"ClaimQuest",
	"EquipHat",
	"ClaimDaily",
	"BuyCharacter",
	"LuckyPlanks",
}

local FUNCTIONS: { FunctionName } = { "GetForest", "RedeemCode" }

local FOLDER_NAME = "Remotes"

local Remotes = {}

local folder: Instance? = nil

local function getFolder(): Instance
	if not folder then
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	end
	return folder :: Instance
end

-- Server only, called once by init.server.luau before any service runs.
function Remotes.createAll()
	assert(RunService:IsServer(), "Remotes.createAll is server-only")
	assert(not ReplicatedStorage:FindFirstChild(FOLDER_NAME), "Remotes already created")

	local newFolder = Instance.new("Folder")
	newFolder.Name = FOLDER_NAME
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = newFolder
	end
	for _, name in FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = newFolder
	end
	newFolder.Parent = ReplicatedStorage
	folder = newFolder
end

function Remotes.event(name: EventName): RemoteEvent
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: FunctionName): RemoteFunction
	return getFolder():WaitForChild(name) :: RemoteFunction
end

return Remotes
