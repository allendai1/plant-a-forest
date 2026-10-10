--!strict
-- QuestController: the starter quests on screen (docs/plans/Quests.md, 2026-10-09). After the tutorial, a card at the
-- bottom of the stats column shows the current quest ("Quest 3/8", its text, a progress bar and the reward). Once it's
-- reached, a CLAIM button and a red dot appear; claiming (ClaimQuest; QuestService checks and pays) shows a banner and
-- the next quest. Pressing the card opens the list of all quests: done ones ticked, the current one, the ones to come.
-- Progress is read from the player's attributes (GameConfig.questProgress, the same as the server).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)
local HUD = require(script.Parent.HUD)
local Sounds = require(script.Parent.Parent.Sounds)
local UIStyle = require(script.Parent.Parent.UIStyle)

local TRACKER_WIDTH = 290
local TRACKER_HEIGHT = 96
local LIST_WIDTH = 520
local ROW_HEIGHT = 64
local BAR_BACK = Color3.fromRGB(40, 32, 26)
local BAR_FILL = Color3.fromRGB(120, 220, 90)
local DOT_COLOR = Color3.fromRGB(235, 45, 45)
local DONE_COLOR = Color3.fromRGB(120, 255, 100)
local VIGNETTE_DARKEST = 0.35 -- the quest card's black at its left edge (transparency), fading to nothing at the right
local VIGNETTE_MIDDLE = 0.6

local QuestController = {}

local localPlayer = Players.LocalPlayer
local quests = GameConfig.Quests

local function attribute(name: string): number
	local value = localPlayer:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function progressOf(quest: GameConfig.Quest): number
	return math.min(GameConfig.questProgress(quest, attribute), quest.Goal)
end

-- The quests are on once the tutorial is done, until the last one is claimed.
local function current(): (number, GameConfig.Quest?)
	if attribute("TutorialStep") < GameConfig.Tutorial.DoneStep then
		return 0, nil
	end
	local index = attribute("QuestIndex")
	return index, quests[index]
end

-- A progress bar: a dark track, a green fill and "32 / 50" over it. Returns a setter.
local function bar(parent: Instance, position: UDim2, size: UDim2): (number, number, boolean) -> ()
	local back = Instance.new("Frame")
	back.BackgroundColor3 = BAR_BACK
	back.Position = position
	back.Size = size
	back.ZIndex = 2
	back.Parent = parent
	UIStyle.corner(back, 8)
	UIStyle.stroke(back, 2, UIStyle.BLACK, true)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = BAR_FILL
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 3
	fill.Parent = back
	UIStyle.corner(fill, 8)
	local label = UIStyle.text(back, "", 16)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.ZIndex = 4
	return function(value: number, goal: number, ready: boolean)
		fill.Size = UDim2.fromScale(math.clamp(value / goal, 0, 1), 1)
		fill.BackgroundColor3 = if ready then UIStyle.Colors.Gold[1] else BAR_FILL
		label.Text = `{UIStyle.commas(math.floor(value))} / {UIStyle.commas(goal)}`
	end
end

-- A button's text is drawn by copies under it (UIStyle's outline); lift them with the button so the card can't hide them.
local function lift(button: GuiObject, z: number)
	button.ZIndex = z
	for _, item in button:GetDescendants() do
		if item:IsA("GuiObject") then
			item.ZIndex = z + 1
		end
	end
end

local function claim()
	Remotes.event("ClaimQuest"):FireServer()
end

-- The window with every quest.
local listGui: ScreenGui? = nil
type Row = {
	frame: Frame,
	state: TextLabel,
	setBar: (number, number, boolean) -> (),
	barHolder: Frame,
	button: TextButton,
}
local rows: { Row } = {}

local function refreshList()
	local index, quest = current()
	for i, row in rows do
		local q = quests[i]
		local done = quest == nil and index > 0 or i < index
		local isCurrent = quest ~= nil and i == index
		local ready = isCurrent and progressOf(q) >= q.Goal
		row.frame.BackgroundTransparency = if done or isCurrent then 0 else 0.4
		row.state.Text = if done then "✓ Done" else `+{q.Reward} coins`
		row.state.TextColor3 = if done then DONE_COLOR else UIStyle.GOLD
		row.barHolder.Visible = isCurrent and not ready
		row.button.Visible = ready
		if isCurrent then
			row.setBar(progressOf(q), q.Goal, ready)
		end
	end
end

local function buildList(): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "Quests"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	screen.DisplayOrder = 2 -- over the HUD
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	UIStyle.blurBehind(screen)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(LIST_WIDTH, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.Parent = screen
	UIStyle.autoScale(holder)
	local panel = UIStyle.panel(holder)
	panel.Size = UDim2.fromScale(1, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	UIStyle.padding(panel, 18)
	UIStyle.list(panel, false, 10)
	UIStyle.text(panel, "Quests", 44, UIStyle.GOLD).LayoutOrder = 0
	UIStyle.closeButton(holder, function()
		screen.Enabled = false
	end)
	for i, q in quests do
		local frame = UIStyle.card(panel, ROW_HEIGHT)
		frame.LayoutOrder = i
		local name = UIStyle.text(frame, `{i}. {q.Text}`, 24)
		name.AnchorPoint = Vector2.new(0, 0.5)
		name.Position = UDim2.new(0, 14, 0.5, 0)
		local state = UIStyle.text(frame, "", 20, UIStyle.GOLD)
		state.AnchorPoint = Vector2.new(1, 0.5)
		state.Position = UDim2.new(1, -14, 0.5, -12)
		local barHolder = Instance.new("Frame")
		barHolder.BackgroundTransparency = 1
		barHolder.AnchorPoint = Vector2.new(1, 0)
		barHolder.Position = UDim2.new(1, -14, 0.5, 2)
		barHolder.Size = UDim2.fromOffset(150, 20)
		barHolder.Parent = frame
		local setBar = bar(barHolder, UDim2.new(), UDim2.fromScale(1, 1))
		local button = UIStyle.button(frame, "CLAIM", UIStyle.Colors.Green, UDim2.fromOffset(110, 30), 18)
		button.AnchorPoint = Vector2.new(1, 0)
		button.Position = UDim2.new(1, -14, 0.5, 0)
		button.Visible = false
		lift(button, 5)
		button.Activated:Connect(claim)
		table.insert(rows, { frame = frame, state = state, setBar = setBar, barHolder = barHolder, button = button })
	end
	screen.Parent = localPlayer:WaitForChild("PlayerGui")
	return screen
end

function QuestController.toggle()
	local screen = listGui or buildList()
	listGui = screen
	screen.Enabled = not screen.Enabled
	if screen.Enabled then
		refreshList()
	end
end

-- The card under the stats. HUD builds the stats column ("Stats"); the card joins it as its last row.
local function buildTracker(): (Frame, () -> ())
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local stats = playerGui:FindFirstChild("Stats", true)
	while not (stats and stats:IsA("Frame")) do
		task.wait(0.5)
		stats = playerGui:FindFirstChild("Stats", true)
	end
	-- A dark vignette, not a tan card, so it sits with the stats (plain icons and outlined text; the user's call): black,
	-- fading out to the right and at the bottom edge.
	local card = Instance.new("Frame")
	card.BackgroundColor3 = UIStyle.BLACK
	card.BackgroundTransparency = 0
	card.BorderSizePixel = 0
	card.Parent = stats
	UIStyle.corner(card, 14)
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, VIGNETTE_DARKEST),
		NumberSequenceKeypoint.new(0.6, VIGNETTE_MIDDLE),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = card
	card.Name = "Quest"
	card.Size = UDim2.fromOffset(TRACKER_WIDTH, TRACKER_HEIGHT)
	card.LayoutOrder = 10
	-- Pressing anywhere on the card opens the list (the CLAIM button sits over it).
	local open = Instance.new("TextButton")
	open.Name = "Open"
	open.BackgroundTransparency = 1
	open.Text = ""
	open.Size = UDim2.fromScale(1, 1)
	open.ZIndex = 1
	open.Parent = card
	open.Activated:Connect(QuestController.toggle)
	local title = UIStyle.text(card, "", 18, UIStyle.GOLD)
	title.Position = UDim2.fromOffset(12, 8)
	title.ZIndex = 2
	local reward = UIStyle.text(card, "", 18, UIStyle.PRICE)
	reward.AnchorPoint = Vector2.new(1, 0)
	reward.Position = UDim2.new(1, -12, 0, 8)
	reward.ZIndex = 2
	local text = UIStyle.text(card, "", 24)
	text.Position = UDim2.fromOffset(12, 30)
	text.ZIndex = 2
	local setBar = bar(card, UDim2.fromOffset(12, 64), UDim2.new(1, -24, 0, 20))
	local button = UIStyle.button(card, "CLAIM", UIStyle.Colors.Green, UDim2.fromOffset(120, 34), 20)
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -10, 1, -6)
	lift(button, 5)
	button.Activated:Connect(claim)
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(1, -4, 0, 4)
	dot.Size = UDim2.fromOffset(20, 20)
	dot.BackgroundColor3 = DOT_COLOR
	dot.ZIndex = 6
	dot.Parent = card
	UIStyle.corner(dot, 10)
	UIStyle.stroke(dot, 2, UIStyle.WHITE, true)

	local function refresh()
		local index, quest = current()
		card.Visible = quest ~= nil
		if not quest then
			return
		end
		local value = progressOf(quest)
		local ready = value >= quest.Goal
		title.Text = `QUEST {index}/{#quests}`
		reward.Text = `+{quest.Reward} coins`
		text.Text = quest.Text
		setBar(value, quest.Goal, ready)
		button.Visible = ready
		dot.Visible = ready
	end
	return card, refresh
end

function QuestController.start()
	local watched = {
		"TutorialStep",
		"QuestIndex",
		"Strength",
		"Speed",
		"SeedsPlanted",
		"TreesFinished",
		"RingsHelped",
		"ForestsCompleted",
		"BulkPickupLevel",
		"BulkPlantLevel",
		"PlantingRangeLevel",
	}
	-- A claim moves QuestIndex on: celebrate the quest just finished (not the save loading, which comes from nil).
	local lastIndex = localPlayer:GetAttribute("QuestIndex")
	localPlayer:GetAttributeChangedSignal("QuestIndex"):Connect(function()
		local now = localPlayer:GetAttribute("QuestIndex")
		local done = if typeof(lastIndex) == "number"
				and typeof(now) == "number"
				and now > lastIndex
			then quests[lastIndex]
			else nil
		if done then
			HUD.banner(`Quest complete! +{done.Reward} coins`, DONE_COLOR)
			Sounds.play("LevelUp")
		end
		lastIndex = now
	end)
	local _, refresh = buildTracker()
	for _, name in watched do
		localPlayer:GetAttributeChangedSignal(name):Connect(function()
			refresh()
			if listGui and listGui.Enabled then
				refreshList()
			end
		end)
	end
	refresh()
end

return QuestController
