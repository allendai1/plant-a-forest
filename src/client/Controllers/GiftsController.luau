--!strict
-- GiftsController: the FREE GIFT window (2026-10-11, the user's ask, after another game's: one gift for three steps).
-- The FREE GIFT board in camp (its E prompt tagged GiftPrompt) and the HUD's top "+N" button (TutorialController) open
-- it: the gift box picture, the reward (Speed, Strength and coins), three step cards (1. Like the Game! 2. Favorite the
-- Game! 3. Join the Community!) and one Claim! button. Tapping card 2 opens Roblox's Favorite prompt, card 3 its
-- join-group prompt. Claim only checks (the user's call): with the favorite and the group both done it sends
-- ClaimFreeGift, and the server checks the group itself and pays FreeGiftSpeed, FreeGiftStrength and FreeGiftCoins
-- once ever; otherwise "Conditions not met. Please complete all of these!" and the unfinished cards shake (the message in red under Claim). The like
-- can't be checked by a game (the user's call: only favorite and join are checked).
-- Once claimed, the board disappears on this client (others still see theirs).

local AvatarEditorService = game:GetService("AvatarEditorService")
local CollectionService = game:GetService("CollectionService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local HUD = require(script.Parent.HUD)
local UIStyle = require(script.Parent.Parent.UIStyle)

local PROMPT_TAG = "GiftPrompt"
local THANKS_COLOR = Color3.fromRGB(255, 160, 205)
-- The gift box picture (the user's pick, Creator Store decal 15403372742). Its thumbnail: the decal's own image
-- belongs to another creator and won't load in this game, the thumbnail does.
local GIFT_IMAGE = "rbxthumb://type=Asset&id=15403372742&w=420&h=420"
local STEP = Vector2.new(214, 200)
-- The steps' pictures (the user's images, 2026-10-11): how to like, favorite and join. As thumbnails: the images are
-- the group's (Forest Conservation Studios) and rbxassetid:// wouldn't load them in this place; the thumbnails do.
local STEP_IMAGES = {
	"rbxthumb://type=Asset&id=113612189779475&w=420&h=420",
	"rbxthumb://type=Asset&id=81964212182383&w=420&h=420",
	"rbxthumb://type=Asset&id=111082618878545&w=420&h=420",
}

local GiftsController = {}

local localPlayer = Players.LocalPlayer
local gui: ScreenGui? = nil
local favorited = false -- the favorite prompt worked this session, or GetFavorite says so (it needs inventory access)
local member = false -- in the group (looked up on open and on Claim, or the join prompt)
local refreshSteps: () -> () = function() end

local function claimed(): boolean
	return localPlayer:GetAttribute("FreeGiftClaimed") == 1
end

-- The coins still to be had (the HUD button shows it).
function GiftsController.unclaimedCoins(): number
	return if claimed() then 0 else GameConfig.Economy.FreeGiftCoins
end

function GiftsController.open()
	if gui then
		gui.Enabled = true
	end
end

local busy = false
local NOT_MET = "Conditions not met. Please complete all of these!"
local NOT_MET_COLOR = Color3.fromRGB(255, 110, 100)

-- In the group right now (GetGroupsAsync, not the join-time cached IsInGroup, so a join from the group page counts).
local function lookUpMember(): boolean
	local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, localPlayer.UserId)
	if ok and typeof(groups) == "table" then
		for _, group in groups do
			if typeof(group) == "table" and group.Id == GameConfig.Economy.GroupId then
				return true
			end
		end
	end
	return false
end

-- Card 2: Roblox's Favorite prompt. (In Studio favoriting can't complete, so this only works in the live game.)
local function askFavorite()
	if busy or favorited then
		return
	end
	busy = true
	local prompted = pcall(AvatarEditorService.PromptSetFavorite, AvatarEditorService, game.PlaceId, Enum.AvatarItemType.Asset, true)
	favorited = prompted and AvatarEditorService.PromptSetFavoriteCompleted:Wait() == Enum.AvatarPromptResult.Success
	refreshSteps()
	busy = false
end

-- Card 3: Roblox's join-group prompt.
local function askToJoin()
	if busy or member then
		return
	end
	busy = true
	local ok, status = pcall(GroupService.PromptJoinAsync, GroupService, GameConfig.Economy.GroupId)
	member = ok and (status == Enum.GroupMembershipStatus.Joined or status == Enum.GroupMembershipStatus.AlreadyMember)
	refreshSteps()
	busy = false
end

-- Claim!: only checks. Both done -> the claim; otherwise the message and the unfinished cards shake (the message in red under Claim).
local cards: { [number]: GuiObject } = {}
local notMetLabel: TextLabel? = nil
local notMetShown = 0
local function showNotMet()
	local label = notMetLabel
	if not label then
		return
	end
	notMetShown += 1
	local shown = notMetShown
	label.Visible = true
	task.delay(4, function()
		if notMetShown == shown then
			label.Visible = false
		end
	end)
end
local function claim()
	if busy or claimed() then
		return
	end
	busy = true
	member = member or lookUpMember()
	if not favorited then
		local ok, isFavorite = pcall(AvatarEditorService.GetFavorite, AvatarEditorService, game.PlaceId, Enum.AvatarItemType.Asset)
		favorited = ok and isFavorite == true
	end
	refreshSteps()
	if favorited and member then
		Remotes.event("ClaimFreeGift"):FireServer()
	else
		showNotMet()
		for order, done in { [2] = favorited, [3] = member } do
			if not done and cards[order] then
				UIStyle.deny(cards[order])
			end
		end
	end
	busy = false
end

-- One step card: its number and name, its picture, and a status line. isDone nil: the like (can't be checked, no
-- status to show). ask: what tapping the card does.
local function step(parent: Instance, order: number, title: string, isDone: (() -> boolean)?, ask: (() -> ())?, todo: string?): () -> ()
	local card = UIStyle.card(parent, STEP.Y)
	card.Size = UDim2.fromOffset(STEP.X, STEP.Y)
	card.LayoutOrder = order
	cards[order] = card
	local name = UIStyle.text(card, `{order}. {title}`, 20)
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.new(0.5, 0, 0, 10)
	local picture = Instance.new("ImageLabel")
	picture.BackgroundTransparency = 1
	picture.AnchorPoint = Vector2.new(0.5, 0)
	picture.Position = UDim2.new(0.5, 0, 0, 38)
	picture.Size = UDim2.new(1, -14, 1, -72)
	picture.Image = STEP_IMAGES[order]
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Parent = card
	UIStyle.corner(picture, 8)
	local status = UIStyle.text(card, "", 20, UIStyle.GREY)
	status.AnchorPoint = Vector2.new(0.5, 1)
	status.Position = UDim2.new(0.5, 0, 1, -10)
	if ask then
		local tap = Instance.new("TextButton")
		tap.Name = "Tap"
		tap.Text = ""
		tap.BackgroundTransparency = 1
		tap.Size = UDim2.fromScale(1, 1)
		tap.ZIndex = 10
		tap.Parent = card
		tap.Activated:Connect(function()
			task.spawn(ask)
		end)
	end
	return function()
		if not isDone then
			status.Text = "On the game page"
			return
		end
		local done = isDone()
		status.Text = if done then "✓ Done" else todo or "Not yet"
		status.TextColor3 = if done then UIStyle.PRICE else UIStyle.GOLD
	end
end

-- Shows or hides the gift spot (the board and its prompt) on this client.
local function showSpot(prompt: ProximityPrompt, on: boolean)
	prompt.Enabled = on
	local spot = prompt:FindFirstAncestorWhichIsA("Model")
	if not spot then
		return
	end
	for _, item in spot:GetDescendants() do
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

local function refreshSpot()
	local open = not claimed()
	for _, prompt in CollectionService:GetTagged(PROMPT_TAG) do
		if prompt:IsA("ProximityPrompt") then
			showSpot(prompt, open)
		end
	end
	if gui and not open then
		gui.Enabled = false
	end
end

function GiftsController.start()
	local screen = Instance.new("ScreenGui")
	screen.Name = "FreeGifts"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	screen.DisplayOrder = 2
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	UIStyle.blurBehind(screen)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(3 * STEP.X + 2 * 12 + 36, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.Parent = screen
	UIStyle.windowScale(holder)
	local panel = UIStyle.panel(holder)
	panel.Size = UDim2.fromScale(1, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	UIStyle.padding(panel, 18)
	UIStyle.list(panel, false, 12, Enum.HorizontalAlignment.Center)
	UIStyle.closeButton(holder, function()
		screen.Enabled = false
	end)
	UIStyle.text(panel, "FREE GIFT!", 44, UIStyle.GOLD).LayoutOrder = 1

	-- The gift box and what's in it.
	local top = Instance.new("Frame")
	top.LayoutOrder = 2
	top.BackgroundTransparency = 1
	top.AutomaticSize = Enum.AutomaticSize.XY
	top.Parent = panel
	local topList = UIStyle.list(top, true, 18)
	topList.VerticalAlignment = Enum.VerticalAlignment.Center
	local box = Instance.new("ImageLabel")
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromOffset(160, 160)
	box.Image = GIFT_IMAGE
	box.ScaleType = Enum.ScaleType.Fit
	box.Parent = top
	local reward = Instance.new("Frame")
	reward.LayoutOrder = 2
	reward.BackgroundTransparency = 1
	reward.AutomaticSize = Enum.AutomaticSize.XY
	reward.Parent = top
	UIStyle.list(reward, false, 4)
	local economy = GameConfig.Economy
	for i, line in {
		{ UIStyle.Icons.Speed, `{UIStyle.commas(economy.FreeGiftSpeed)} Speed!`, Color3.fromRGB(90, 190, 255) },
		{ UIStyle.Icons.Strength, `{UIStyle.commas(economy.FreeGiftStrength)} Strength!`, Color3.fromRGB(255, 180, 60) },
		{ UIStyle.Icons.Coins, `{UIStyle.commas(economy.FreeGiftCoins)} Coins!`, UIStyle.PRICE },
	} do
		local row = Instance.new("Frame")
		row.LayoutOrder = i
		row.BackgroundTransparency = 1
		row.AutomaticSize = Enum.AutomaticSize.XY
		row.Parent = reward
		local rowList = UIStyle.list(row, true, 8)
		rowList.VerticalAlignment = Enum.VerticalAlignment.Center
		UIStyle.icon(row, line[1], 40)
		UIStyle.text(row, line[2], 36, line[3]).LayoutOrder = 2
	end
	UIStyle.text(reward, "Do all 3 steps, then Claim!", 22, UIStyle.GREY).LayoutOrder = 4

	-- The three steps.
	local steps = Instance.new("Frame")
	steps.LayoutOrder = 3
	steps.BackgroundTransparency = 1
	steps.AutomaticSize = Enum.AutomaticSize.XY
	steps.Parent = panel
	UIStyle.list(steps, true, 12)
	local refreshers = {
		step(steps, 1, "Like the Game!", nil),
		step(steps, 2, "Favorite the Game!", function()
			return favorited
		end, askFavorite, "Tap to favorite"),
		step(steps, 3, "Join the Community!", function()
			return member
		end, askToJoin, "Tap to join"),
	}
	refreshSteps = function()
		for _, refresh in refreshers do
			refresh()
		end
	end
	refreshSteps()

	local button = UIStyle.button(panel, "Claim!", UIStyle.Colors.Green, UDim2.fromOffset(260, 64), 36)
	button.LayoutOrder = 4
	local notMet = UIStyle.text(panel, NOT_MET, 22, NOT_MET_COLOR)
	notMet.LayoutOrder = 5
	notMet.Visible = false
	notMetLabel = notMet
	button.Activated:Connect(function()
		if busy or claimed() then
			UIStyle.deny(button)
		else
			task.spawn(claim)
		end
	end)
	screen.Parent = localPlayer:WaitForChild("PlayerGui")
	gui = screen

	-- The group step shows ✓ for members already (looked up again each time the window opens: they may have joined on
	-- the group page meanwhile).
	screen:GetPropertyChangedSignal("Enabled"):Connect(function()
		if screen.Enabled and not member then
			task.spawn(function()
				member = lookUpMember()
				refreshSteps()
			end)
		end
	end)
	task.spawn(function()
		member = member or lookUpMember()
		refreshSteps()
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if CollectionService:HasTag(prompt, PROMPT_TAG) then
			GiftsController.open()
		end
	end)
	CollectionService:GetInstanceAddedSignal(PROMPT_TAG):Connect(refreshSpot) -- the board can stream in later
	-- The thanks only for a claim made now (0 -> 1), not when the save loads (nil -> 1) on every join.
	local last = localPlayer:GetAttribute("FreeGiftClaimed")
	localPlayer:GetAttributeChangedSignal("FreeGiftClaimed"):Connect(function()
		if claimed() and last == 0 then
			HUD.banner("Thanks! Enjoy your free gift!", THANKS_COLOR)
		end
		last = localPlayer:GetAttribute("FreeGiftClaimed")
		refreshSpot()
	end)
	refreshSpot()
end

return GiftsController
