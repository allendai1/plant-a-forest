--!strict
-- WorldRouletteController: the roulette that picks the next world after each forest's break, and the
-- bonus world's name under the Forest Bar (the user's request, 2026-10-07).
-- When ForestState TierRolls goes up, the server has picked NextTier (AwakeningService). A strip of world
-- cards, as many of each as its share of the pool, spins past a gold marker for Roulette.SpinSeconds and
-- stops on the picked world, ticking as cards pass; the pool with each world's chance and coin
-- multiplier shows underneath. The server starts the next forest Roulette.HoldSeconds after it stops.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Trees = require(ReplicatedStorage.Shared.Trees)
local HUD = require(script.Parent.HUD)
local Sounds = require(script.Parent.Parent.Sounds)
local UIStyle = require(script.Parent.Parent.UIStyle)

-- Look (not balance).
local CARD, GAP = 150, 12 -- card width and the gap between cards
local WINDOW = 700 -- the visible part of the strip
local CARDS = 44 -- cards on the strip
local WIN_INDEX = 38 -- the card the strip stops on
local TICK_ID = "rbxasset://sounds/clickfast.wav"
local TIER_COLORS = {
	[1] = Color3.fromRGB(95, 175, 75),
	[2] = Color3.fromRGB(245, 140, 190),
	[3] = Color3.fromRGB(235, 130, 45),
} :: { [number]: Color3 }
local MARKER_COLOR = Color3.fromRGB(255, 210, 70)

local WorldRouletteController = {}

local localPlayer = Players.LocalPlayer
local forestState: Instance
local spinning = false

local function attribute(name: string): number
	local value = forestState:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function totalWeight(): number
	local total = 0
	for _, tier in GameConfig.Tiers do
		total += tier.Weight
	end
	return total
end

local function coinsText(tier: GameConfig.TierDef): string
	return `{tier.CoinMultiplier}x coins`
end

-- A world's full-grown tree, turning slightly toward the camera, in a ViewportFrame.
local function treePicture(parent: Instance, index: number, pixels: number): ViewportFrame
	local frame = Instance.new("ViewportFrame")
	frame.Size = UDim2.fromOffset(pixels, pixels)
	frame.BackgroundTransparency = 1
	frame.Ambient = Color3.fromRGB(170, 170, 170)
	frame.LightDirection = Vector3.new(-1, -1.5, -1)
	frame.Parent = parent
	local species = Trees.index(GameConfig.Tiers[index].Commons[1])
	local trees = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Trees")
	local template = trees:FindFirstChild(`{Trees.model(species)}{#GameConfig.Growth.StageStarts}`)
	if template and template:IsA("Model") then
		local model = template:Clone()
		model:PivotTo(CFrame.Angles(0, math.rad(30), 0))
		model.Parent = frame
		local box, size = model:GetBoundingBox()
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(0, size.Y * 0.1, math.max(size.X, size.Y) * 1.55), box.Position)
		camera.Parent = frame
		frame.CurrentCamera = camera
	end
	return frame
end

local function card(parent: Instance, index: number, x: number): Frame
	local tier = GameConfig.Tiers[index]
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(CARD, CARD)
	frame.Position = UDim2.fromOffset(x, 0)
	frame.BackgroundColor3 = TIER_COLORS[index] or UIStyle.GREY
	frame.Parent = parent
	UIStyle.corner(frame, 14)
	UIStyle.stroke(frame, 3, nil, true)
	local picture = treePicture(frame, index, CARD - 46)
	picture.AnchorPoint = Vector2.new(0.5, 0)
	picture.Position = UDim2.new(0.5, 0, 0, 2)
	local name = UIStyle.text(frame, tier.Name, 13)
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -22)
	local coins = UIStyle.text(frame, coinsText(tier), 16, Color3.fromRGB(255, 230, 120))
	coins.AnchorPoint = Vector2.new(0.5, 1)
	coins.Position = UDim2.new(0.5, 0, 1, -4)
	return frame
end

-- A random world for a filler card, by weight (the client's own pick: only the winning card matters).
local function fillerTier(rng: Random): number
	return GameConfig.pickTier(rng:NextNumber())
end

local function spin(gui: ScreenGui, winner: number)
	spinning = true
	gui.Enabled = true
	local holder = gui:FindFirstChild("Holder") :: Frame
	local window = holder:FindFirstChild("Window", true) :: Frame
	local old = window:FindFirstChild("Strip")
	if old then
		old:Destroy()
	end
	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.fromOffset(CARDS * (CARD + GAP), CARD)
	strip.Parent = window
	local rng = Random.new()
	local cards: { Frame } = {}
	for i = 1, CARDS do
		table.insert(cards, card(strip, if i == WIN_INDEX then winner else fillerTier(rng), (i - 1) * (CARD + GAP)))
	end
	local title = holder:FindFirstChild("Title", true) :: TextLabel
	title.Text = "Choosing the next world..."

	-- Stop with the marker somewhere on the winning card, not always dead center.
	local landing = (WIN_INDEX - 1) * (CARD + GAP) + CARD / 2 + rng:NextNumber(-0.35, 0.35) * CARD
	local startX = WINDOW / 2 - CARD / 2 -- the first card under the marker
	local t = Instance.new("NumberValue")
	local lastCard = 0
	t.Changed:Connect(function(u)
		local travelled = u * (landing - CARD / 2)
		strip.Position = UDim2.fromOffset(startX - travelled, 0)
		local under = math.floor((travelled + CARD / 2) / (CARD + GAP))
		if under ~= lastCard then
			lastCard = under
			local tick = Instance.new("Sound")
			tick.SoundId = TICK_ID
			tick.Volume = 0.35
			tick.SoundGroup = Sounds.effects()
			tick.Parent = SoundService
			tick:Play()
			Debris:AddItem(tick, 1)
		end
	end)
	strip.Position = UDim2.fromOffset(startX, 0)
	local info = TweenInfo.new(GameConfig.Roulette.SpinSeconds, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local tween = TweenService:Create(t, info, { Value = 1 })
	tween:Play()
	tween.Completed:Wait()
	t:Destroy()

	local tier = GameConfig.Tiers[winner]
	title.Text = `Next world: {tier.Name}!`
	Sounds.play(if tier.CoinMultiplier > 1 then "LevelUp" else "Notify")
	local won = cards[WIN_INDEX]
	local pop = Instance.new("UIScale")
	pop.Parent = won
	TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 1, true), { Scale = 1.12 })
		:Play()
	HUD.banner(if tier.CoinMultiplier > 1 then `Next world: {tier.Name}! {coinsText(tier)}!` else `Next world: {tier.Name}!`)
	task.wait(GameConfig.Roulette.HoldSeconds)
	gui.Enabled = false
	spinning = false
end

local function build(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "WorldRoulette"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 4 -- over the HUD and the shops
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.42)
	holder.Size = UDim2.fromOffset(WINDOW + 40, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	UIStyle.autoScale(holder)
	local panel = UIStyle.panel(holder)
	panel.Size = UDim2.fromScale(1, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	UIStyle.padding(panel, 18)
	UIStyle.list(panel, false, 12, Enum.HorizontalAlignment.Center)
	local title = UIStyle.text(panel, "", 40, UIStyle.GOLD)
	title.Name = "Title"
	title.LayoutOrder = 1

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.Size = UDim2.fromOffset(WINDOW, CARD + 8)
	window.BackgroundColor3 = Color3.fromRGB(25, 20, 16)
	window.ClipsDescendants = true
	window.LayoutOrder = 2
	window.Parent = panel
	UIStyle.corner(window, 12)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.Parent = window
	-- The marker: a gold line down the middle.
	local line = Instance.new("Frame")
	line.Name = "Marker"
	line.AnchorPoint = Vector2.new(0.5, 0)
	line.Position = UDim2.new(0.5, 0, 0, -4)
	line.Size = UDim2.new(0, 4, 1, 8)
	line.BackgroundColor3 = MARKER_COLOR
	line.BorderSizePixel = 0
	line.ZIndex = 5
	line.Parent = window

	-- The pool: every world with its chance and coin multiplier.
	local pool = Instance.new("Frame")
	pool.Name = "Pool"
	pool.BackgroundTransparency = 1
	pool.AutomaticSize = Enum.AutomaticSize.XY
	pool.LayoutOrder = 3
	pool.Parent = panel
	UIStyle.list(pool, true, 22)
	local total = totalWeight()
	for i, tier in GameConfig.Tiers do
		local entry = UIStyle.text(
			pool,
			`{tier.Name}: {math.round(tier.Weight / total * 100)}% · {coinsText(tier)}`,
			20,
			TIER_COLORS[i] or UIStyle.GREY
		)
		entry.LayoutOrder = i
	end
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	return gui
end

-- "Kyoto Forest · 2x coins" in a bonus world, nothing in a normal (1x) world (the user's call, 2026-10-07). It's a
-- line in the HUD's top group, under the Forest Bar's buttons (above them on phones, where the group sits at the
-- bottom), so it stays with the bar instead of floating mid-screen (2026-10-08, the user's ask).
local function buildWorldLabel()
	local top = localPlayer:WaitForChild("PlayerGui"):WaitForChild("HUD"):WaitForChild("Top")
	local label = UIStyle.text(top, "", 26)
	label.Name = "WorldLabel"
	label.LayoutOrder = if UIStyle.isTouch() then -4 else 6
	local function refresh()
		local index = math.max(1, attribute("TierId"))
		local tier = GameConfig.Tiers[index]
		label.Visible = tier ~= nil and tier.CoinMultiplier > 1
		if tier then
			label.Text = `{tier.Name} · {coinsText(tier)}`
			label.TextColor3 = TIER_COLORS[index] or UIStyle.WHITE
		end
	end
	forestState:GetAttributeChangedSignal("TierId"):Connect(refresh)
	refresh()
end

function WorldRouletteController.start()
	forestState = ReplicatedStorage:WaitForChild("ForestState")
	task.spawn(buildWorldLabel) -- waits for the HUD
	local gui = build()
	forestState:GetAttributeChangedSignal("TierRolls"):Connect(function()
		local winner = attribute("NextTier")
		if not spinning and GameConfig.Tiers[winner] then
			spin(gui, winner)
		end
	end)
end

return WorldRouletteController
