--!strict
-- GroupGiftController: the group gift (2026-10-08, the user's ask). The "FREE GIFT" board by the upgrades
-- (Workspace.Map.Lobby.GroupGiftBoard, its E prompt tagged GroupGiftPrompt) opens Roblox's join-group prompt for
-- the studio's group (GameConfig.Economy.GroupId). If the player joins (or already is a member), the client asks
-- the server for the coins (ClaimGroupGift), which checks the membership itself and pays once ever. The board
-- disappears for a player who has claimed it, like the favorite gift's.

local CollectionService = game:GetService("CollectionService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local HUD = require(script.Parent.HUD)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PROMPT_TAG = "GroupGiftPrompt"

local GroupGiftController = {}

local localPlayer = Players.LocalPlayer

local function claimed(): boolean
	return localPlayer:GetAttribute("GroupGiftClaimed") == 1
end

-- Shows or hides the board on this client (parts, label, glowing circle, prompt).
local function show(prompt: ProximityPrompt, on: boolean)
	prompt.Enabled = on
	local board = prompt:FindFirstAncestorWhichIsA("Model")
	if not board then
		return
	end
	for _, item in board:GetDescendants() do
		-- selene: allow(if_same_then_else) -- separate branches so each narrows to a type with Enabled
		if item:IsA("BasePart") then
			item.LocalTransparencyModifier = if on then 0 else 1
		elseif item:IsA("LayerCollector") then
			item.Enabled = on
		elseif item:IsA("Beam") then
			item.Enabled = on
		end
	end
end

local function refresh()
	for _, prompt in CollectionService:GetTagged(PROMPT_TAG) do
		if prompt:IsA("ProximityPrompt") then
			show(prompt, not claimed())
		end
	end
end

local asking = false
local function askToJoin()
	if asking or claimed() then
		return
	end
	asking = true
	local ok, status = pcall(GroupService.PromptJoinAsync, GroupService, GameConfig.Economy.GroupId)
	if ok and (status == Enum.GroupMembershipStatus.Joined or status == Enum.GroupMembershipStatus.AlreadyMember) then
		Remotes.event("ClaimGroupGift"):FireServer()
	end
	asking = false
end

function GroupGiftController.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if CollectionService:HasTag(prompt, PROMPT_TAG) then
			task.spawn(askToJoin)
		end
	end)
	CollectionService:GetInstanceAddedSignal(PROMPT_TAG):Connect(refresh) -- the board can stream in later
	-- The thanks only for a claim made now (0 -> 1), not when the save loads (nil -> 1) on every join.
	local last = localPlayer:GetAttribute("GroupGiftClaimed")
	localPlayer:GetAttributeChangedSignal("GroupGiftClaimed"):Connect(function()
		if claimed() and last == 0 then
			HUD.banner(`Thanks for joining! +{GameConfig.Economy.GroupGiftCoins} coins`, Color3.fromRGB(255, 160, 205))
		end
		last = localPlayer:GetAttribute("GroupGiftClaimed")
		refresh()
	end)
	refresh()
end

return GroupGiftController
