--!strict
-- DailyController: the DAILY REWARD window (2026-10-11, the user's ask). Seven day cards (GameConfig.Daily.Rewards):
-- days already claimed in this streak are ticked, today's glows gold with a Claim button, later ones wait. It opens
-- by itself when you join with a reward waiting (once the tutorial is done), and from the Daily button in the top bar
-- (HUD). Claiming sends ClaimDaily; DailyService checks the day and pays. A day with a gym (GameConfig.Daily.Gyms:
-- day 2, the 5x gym) shows the gym while it isn't open to you yet, and its coins after.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(script.Parent.Parent.Sounds)
local UIStyle = require(script.Parent.Parent.UIStyle)

local CARD = Vector2.new(96, 120)
local TODAY_COLOR = Color3.fromRGB(255, 205, 80)

local DailyController = {}

local localPlayer = Players.LocalPlayer
local gui: ScreenGui? = nil

function DailyController.toggle()
	if gui then
		gui.Enabled = not gui.Enabled
	end
end

local function number(name: string): number
	local value = localPlayer:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

-- The gym a day still offers (nil once that gym is open to you; the server decides the same way).
local function gymOffer(day: number): number?
	local gym = GameConfig.Daily.Gyms[day]
	local needed = gym and GameConfig.forestsForMultiplier(gym)
	if gym and needed and number("DailyGym") < gym and number("ForestsCompleted") < needed then
		return gym
	end
	return nil
end

local function today(): number
	return GameConfig.dayOf(workspace:GetServerTimeNow())
end

-- The streak day the next claim pays (1..#Rewards), and whether it can be claimed today.
local function nextDay(): (number, boolean)
	local last = number("DailyLastDay")
	local streak = number("DailyStreak")
	local rewards = #GameConfig.Daily.Rewards
	if last >= today() then
		return (streak - 1) % rewards + 1, false -- today's is done: show the day just claimed
	end
	local continuing = last == today() - 1
	return (if continuing then streak else 0) % rewards + 1, true
end

function DailyController.start()
	local screen = Instance.new("ScreenGui")
	screen.Name = "Daily"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	screen.DisplayOrder = 2
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	UIStyle.blurBehind(screen)
	local rewards = GameConfig.Daily.Rewards
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(#rewards * (CARD.X + 10) + 30, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.Parent = screen
	UIStyle.windowScale(holder)
	local panel = UIStyle.panel(holder)
	panel.Size = UDim2.fromScale(1, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	UIStyle.padding(panel, 18)
	UIStyle.list(panel, false, 12, Enum.HorizontalAlignment.Center)
	UIStyle.closeButton(holder, DailyController.toggle)
	UIStyle.text(panel, "DAILY REWARD", 44, UIStyle.GOLD).LayoutOrder = 1
	local hint = UIStyle.text(panel, "Come back every day for bigger rewards!", 20, UIStyle.GREY)
	hint.LayoutOrder = 2

	local row = Instance.new("Frame")
	row.LayoutOrder = 3
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.XY
	row.Parent = panel
	UIStyle.list(row, true, 10)
	type Card = { frame: Frame, ring: UIStroke, tick: TextLabel, shade: Frame, icon: GuiObject, amount: TextLabel }
	local cards: { Card } = {}
	for day, coins in rewards do
		local frame = UIStyle.card(row, CARD.Y)
		frame.Size = UDim2.fromOffset(CARD.X, CARD.Y)
		frame.LayoutOrder = day
		local title = UIStyle.text(frame, `Day {day}`, 20)
		title.AnchorPoint = Vector2.new(0.5, 0)
		title.Position = UDim2.new(0.5, 0, 0, 8)
		local icon = UIStyle.icon(frame, UIStyle.Icons.Coins, 40)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		local amount = UIStyle.text(frame, UIStyle.commas(coins), 22, UIStyle.PRICE)
		amount.AnchorPoint = Vector2.new(0.5, 1)
		amount.Position = UDim2.new(0.5, 0, 1, -8)
		local shade = Instance.new("Frame")
		shade.Size = UDim2.fromScale(1, 1)
		shade.BackgroundColor3 = Color3.new(0, 0, 0)
		shade.BackgroundTransparency = 0.5
		shade.ZIndex = 5
		shade.Parent = frame
		UIStyle.corner(shade, 12)
		local tick = UIStyle.text(shade, "✓", 48, UIStyle.PRICE)
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.fromScale(0.5, 0.5)
		local outline = Instance.new("Frame")
		outline.BackgroundTransparency = 1
		outline.Size = UDim2.fromScale(1, 1)
		outline.ZIndex = 6
		outline.Parent = frame
		UIStyle.corner(outline, 12)
		local ring = UIStyle.stroke(outline, 4, TODAY_COLOR, true)
		table.insert(cards, { frame = frame, ring = ring, tick = tick, shade = shade, icon = icon, amount = amount })
	end

	local claim = UIStyle.button(panel, "Claim", UIStyle.Colors.Green, UDim2.fromOffset(220, 56), 30)
	claim.LayoutOrder = 4
	local status = UIStyle.text(panel, "", 20, UIStyle.GREY)
	status.LayoutOrder = 5

	local function refresh()
		local day, open = nextDay()
		for i, card in cards do
			local claimed = i < day or (i == day and not open)
			card.shade.Visible = claimed
			card.tick.Visible = claimed
			card.ring.Enabled = i == day
			-- A gym day: the Strength icon and "5x GYM" in gold while it's on offer.
			local gym = gymOffer(i)
			card.amount.Text = if gym then `{gym}x GYM` else UIStyle.commas(rewards[i])
			card.amount.TextColor3 = if gym then TODAY_COLOR else UIStyle.PRICE
			if card.icon:IsA("ImageLabel") then
				card.icon.Image = if gym then UIStyle.Icons.Strength.Image else UIStyle.Icons.Coins.Image
			end
		end
		claim.Visible = open
		status.Text = if open then "" else "Come back tomorrow for your next reward!"
	end
	claim.Activated:Connect(function()
		local day, open = nextDay()
		if not open then
			UIStyle.deny(claim)
			return
		end
		Remotes.event("ClaimDaily"):FireServer()
		Sounds.play("Purchase")
		-- HUD requires this module (its Daily button), so it's looked up now rather than at load.
		local HUD = require(script.Parent.HUD) :: any
		local gym = gymOffer(day)
		HUD.banner(
			if gym then `Daily reward! The {gym}x gym is yours for good!` else `Daily reward! +{UIStyle.commas(rewards[day])} coins`,
			TODAY_COLOR
		)
	end)
	for _, name in { "DailyLastDay", "DailyStreak", "DailyGym", "ForestsCompleted" } do
		localPlayer:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
	screen.Parent = localPlayer:WaitForChild("PlayerGui")
	gui = screen

	-- Open by itself when there's a reward waiting, once the save has loaded and the tutorial is done (new players have
	-- enough on screen).
	task.spawn(function()
		while localPlayer:GetAttribute("DailyLastDay") == nil or number("TutorialStep") < GameConfig.Tutorial.DoneStep do
			task.wait(1)
		end
		task.wait(2)
		local _, open = nextDay()
		if open then
			refresh()
			screen.Enabled = true
		end
	end)
end

return DailyController
