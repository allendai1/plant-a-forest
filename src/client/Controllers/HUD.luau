--!strict
-- HUD: the on-screen readouts, laid out after Build the Pyramid's (docs/plans/M5.md, GUI.md).
-- Top: the Forest Bar (Seeds / Target from ForestState), the four Robux buttons that buy seeds for it,
-- the server training boost timer.
-- Left: coins (with "+N" pops; rises close together are merged into one pop), Speed with walk speed,
-- Strength with capacity, forests completed. Right: the Robux SHOP button and the Strength and Speed
-- boost pass buttons (each sells the next pass up), then Settings and Codes side by side. Bottom left: the
-- Friend Boost.
-- pulseBar() and banner() are played by the section complete moment and others.
-- M6: during the break after a forest, a "Next forest in 1:42" countdown with the Robux button that
-- extends the break for everyone, the Ancient Spring label while you stand in it, and a message when
-- someone extends the break. AwakeningController hides the HUD during the cutscene (setVisible).
-- In Studio only, a test panel at the bottom right.

local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Sounds = require(script.Parent.Parent.Sounds)
local UIStyle = require(script.Parent.Parent.UIStyle)
local CodesController = require(script.Parent.CodesController)
local RobuxShopController = require(script.Parent.RobuxShopController)
local SettingsController = require(script.Parent.SettingsController)

local FILL_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP_MERGE_SECONDS = 0.8 -- coin gains this close together fly as one handful (0.3 crowded the screen when planting nonstop)
local ROLL_SECONDS = 0.35 -- stat numbers count up to a new value over this long
-- Earned coins burst out over a wide area in the middle of the screen, then fly to the coin counter,
-- which bumps as each lands.
local COIN_SIZE = 78 -- pixels at the HUD's design size, once settled
local COIN_POP = 1.4 -- each coin pops in this much bigger, then settles
local COIN_STAGGER = 0.04 -- seconds between coins popping out
local COIN_POP_SECONDS = 0.25
local COIN_HOLD_SECONDS = 0.25
local COIN_FLY_SECONDS = 0.55
local COIN_SPREAD = 380 -- how far (pixels) the burst reaches sideways from the middle; 60% of that up and down
local COIN_MIN, COIN_MAX = 2, 5 -- coins per handful (was 6 to 18; the user found it crowded, 2026-10-08)
-- Landing coins play this: Creator Store "Coin sfx" (FranTHGuy, 1.63 s), the user's pick on 2026-10-08 (it was
-- "plop", 773858658, 0.19 s). Same pitch each time, a tiny wobble.
local COIN_SOUND_ID = "rbxassetid://109742263473623"
local COIN_SOUND_VOLUME = 0.35
local COIN_SOUNDS_MAX = 1 -- sounds per handful (on its first landing); the user wanted one per burst
local COIN_SOUND_GAP = 0.25 -- and never two closer than this, so a fast planting streak doesn't pile them up
local COIN_PITCH = 1
local COIN_PITCH_WOBBLE = 0.05 -- each sound's pitch is 1 plus or minus up to this, so repeats don't sound robotic
-- A planting streak: each sound within COIN_STREAK_SECONDS of the last is COIN_STREAK_STEP higher, up to
-- COIN_STREAK_MAX steps (polish pass, 2026-10-07).
local COIN_STREAK_SECONDS = 1.5
local COIN_STREAK_STEP = 0.04
local COIN_STREAK_MAX = 8
local BANNER_SECONDS = 3
-- Confetti over the whole screen when a ring is complete (2026-10-08, the user's ask).
local CONFETTI_COUNT = 90
local CONFETTI_SECONDS = { 2.2, 3.6 } -- how long a piece takes to fall the screen's height
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 90, 90),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(120, 230, 90),
	Color3.fromRGB(80, 190, 255),
	Color3.fromRGB(200, 120, 255),
	Color3.fromRGB(255, 140, 210),
}
local REFRESH_SECONDS = 0.25
local BAR_COLORS = { UIStyle.Colors.Green, UIStyle.Colors.Orange, UIStyle.Colors.Red, UIStyle.Colors.Purple }
local STRENGTH_HEX = "#ffa030"
local ICON_OVERLAP = -18 -- the right column's labels (SHOP, 2x Speed...) sit this far up over their icons
local LEVEL_UP_GAP = 0.9 -- the level-up sound at most this often, so fast training doesn't turn it into noise
local SPEED_HEX = "#50b4ff"
-- The ring trunk right of the Forest Bar: a tree trunk's cross-section, one ring per forest ring (outer = first).
local TRUNK_SIZE = 108 -- across, in the bar's pixels
local TRUNK_GROW_TOUCH = 1.25 -- phones: the trunk this much bigger, alone at the top of the screen
local TRUNK_HEART = 36 -- the middle disc, with how far along the open ring is (%)
local TRUNK_WOOD = { Color3.fromRGB(226, 190, 140), Color3.fromRGB(198, 156, 108) } -- rings still to come
local TRUNK_GROWN = { Color3.fromRGB(96, 196, 84), Color3.fromRGB(70, 160, 64) } -- finished rings
local TRUNK_OPEN = Color3.fromRGB(255, 232, 160) -- the open ring, glowing like it does in the forest
local TRUNK_FILL = Color3.fromRGB(150, 240, 120) -- its full-grown trees, sweeping clockwise from the top
local TRUNK_NEXT_FADE = 0.45 -- the next ring's early trees: the same fill, this transparent (two rings)
-- Floating "+N" stat popups while training: they pop in somewhere around the middle of the screen,
-- float up and fade out.
local GAIN_AREA = Vector2.new(0.32, 0.22) -- how far from the middle they can appear, as a fraction of the screen
local GAIN_SECONDS = 1 -- each popup's life
local GAIN_RISE = 60 -- pixels it floats up
local GAIN_TEXT = 40
local GAIN_MAX = 14 -- at most this many on screen; extra gains skip their popup
local GAIN_TILT = 14 -- each popup is tilted up to this many degrees either way, and turns a little as it floats

local HUD = {}

local barScale: UIScale? = nil
local bannerLabel: TextLabel? = nil
local bannerShown = 0
local hudGui: ScreenGui? = nil
local flowGui: ScreenGui? = nil -- the flying coins: full screen, no insets, so it's in viewport pixels
local localPlayer = Players.LocalPlayer

local function attribute(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

-- A transparent frame that sizes to its contents.
local function group(parent: Instance, name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Size = UDim2.new()
	frame.Parent = parent
	return frame
end

-- A small Robux price tag on a button's top right corner.
local function priceTag(parent: Instance): TextLabel
	local tag = UIStyle.text(parent, "", 22, UIStyle.PRICE)
	tag.Name = "Price"
	tag.AnchorPoint = Vector2.new(1, 0.5)
	tag.Position = UDim2.new(1, 8, 0, 0)
	tag.ZIndex = 3
	return tag
end

function HUD.pulseBar()
	if barScale then
		local pulse = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 1, true)
		TweenService:Create(barScale, pulse, { Scale = 1.1 }):Play()
	end
end

-- `size` scales it (1 = normal) and `seconds` is how long it stays (BANNER_SECONDS by default).
function HUD.banner(text: string, color: Color3?, size: number?, seconds: number?)
	local banner = bannerLabel
	if not banner then
		return
	end
	bannerShown += 1
	local shown = bannerShown
	banner.Text = text
	banner.TextColor3 = color or Color3.fromRGB(255, 220, 110)
	banner.Visible = true
	local pop = banner:FindFirstChildOfClass("UIScale")
	if pop then
		local scale = size or 1
		pop.Scale = 0.6 * scale
		TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = scale }):Play()
	end
	task.delay(seconds or BANNER_SECONDS, function()
		if bannerShown == shown then
			banner.Visible = false
		end
	end)
end

-- A shower of confetti falling over the whole screen: small colored pieces that tumble and drift as they fall,
-- in their own ScreenGui above everything (Hide UI doesn't hide it), each gone once it's off the bottom.
local confettiGui: ScreenGui? = nil
local confettiRng = Random.new()
function HUD.confetti()
	local gui = confettiGui
	if not gui then
		local made = Instance.new("ScreenGui")
		made.Name = "Confetti"
		made.IgnoreGuiInset = true
		made.ResetOnSpawn = false
		made.DisplayOrder = 20
		made.Parent = localPlayer:WaitForChild("PlayerGui")
		confettiGui = made
		gui = made
	end
	local screen = gui :: ScreenGui
	for _ = 1, CONFETTI_COUNT do
		local piece = Instance.new("Frame")
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = CONFETTI_COLORS[confettiRng:NextInteger(1, #CONFETTI_COLORS)]
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Size = UDim2.fromOffset(confettiRng:NextInteger(7, 11), confettiRng:NextInteger(12, 18))
		local x = confettiRng:NextNumber()
		piece.Position = UDim2.fromScale(x, -confettiRng:NextNumber(0.02, 0.5)) -- staggered above the top
		piece.Rotation = confettiRng:NextNumber(0, 360)
		piece.Parent = screen
		local seconds = confettiRng:NextNumber(CONFETTI_SECONDS[1], CONFETTI_SECONDS[2])
		local fall = TweenInfo.new(seconds, Enum.EasingStyle.Linear)
		TweenService:Create(piece, fall, {
			Position = UDim2.fromScale(x + confettiRng:NextNumber(-0.12, 0.12), 1.08),
			Rotation = piece.Rotation + confettiRng:NextNumber(-720, 720),
		}):Play()
		Debris:AddItem(piece, seconds + 0.1)
	end
end

function HUD.setVisible(on: boolean)
	if hudGui then
		hudGui.Enabled = on
	end
	if flowGui then
		flowGui.Enabled = on
	end
end

-- A label that counts up (or down) to each new value instead of jumping.
local function roller(label: TextLabel, start: number): (number, number?) -> ()
	local shown = Instance.new("NumberValue")
	shown.Value = start
	label.Text = UIStyle.commas(start)
	shown.Changed:Connect(function(value)
		label.Text = UIStyle.commas(value)
	end)
	return function(target: number, seconds: number?)
		local roll = TweenInfo.new(seconds or ROLL_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(shown, roll, { Value = target }):Play() -- a newer tween replaces the running one
	end
end

-- A quick scale bump on a GUI object (its own UIScale, made the first time).
local function bump(target: GuiObject, size: number)
	local scale = target:FindFirstChild("Bump") :: UIScale?
	if not scale then
		local made = Instance.new("UIScale")
		made.Name = "Bump"
		made.Parent = target
		scale = made
	end
	local s = scale :: UIScale
	s.Scale = size
	TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local coinSound = Instance.new("Sound")
coinSound.SoundId = COIN_SOUND_ID
coinSound.Volume = COIN_SOUND_VOLUME
coinSound.SoundGroup = Sounds.effects()

-- One coin's clink (skipped when the last one was under COIN_SOUND_GAP ago).
local lastClink = -math.huge
local streak = 0
local function clink()
	local now = os.clock()
	if now - lastClink < COIN_SOUND_GAP then
		return
	end
	streak = if now - lastClink < COIN_STREAK_SECONDS then math.min(streak + 1, COIN_STREAK_MAX) else 0
	lastClink = now
	local sound = coinSound:Clone()
	local wobble = 1 + (math.random() * 2 - 1) * COIN_PITCH_WOBBLE
	sound.PlaybackSpeed = COIN_PITCH * (1 + streak * COIN_STREAK_STEP) * wobble
	sound.Parent = SoundService -- not in a part, so it plays at full volume
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

-- Where the coins burst out: the middle of the screen, a little above center, in viewport pixels.
local function coinSource(): Vector2
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize * Vector2.new(0.5, 0.45) else Vector2.zero
end

-- "+12" or "+1.5": whole numbers with commas, fractions (from 1.5x boosts) to one decimal.
local function gainText(amount: number): string
	if math.abs(amount - math.round(amount)) < 0.05 then
		return `+{UIStyle.commas(math.round(amount))}`
	end
	return string.format("+%.1f", amount)
end

local gainsShown = 0
-- One floating "[icon] +N" for a Strength or Speed gain.
local function gainPopup(stat: "Strength" | "Speed", amount: number)
	local layer = flowGui
	if not layer or not layer.Enabled or gainsShown >= GAIN_MAX then
		return
	end
	gainsShown += 1
	local k = UIStyle.screenScale()
	local camera = workspace.CurrentCamera
	local screen = if camera then camera.ViewportSize else Vector2.new(1000, 1000)
	local spot = screen * (Vector2.new(0.5, 0.45) + Vector2.new(math.random() * 2 - 1, math.random() * 2 - 1) * GAIN_AREA)
	local popup = Instance.new("Frame")
	popup.Name = "GainPopup"
	popup.BackgroundTransparency = 1
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.AutomaticSize = Enum.AutomaticSize.XY
	popup.Position = UDim2.fromOffset(spot.X, spot.Y)
	local tilt = (math.random() * 2 - 1) * GAIN_TILT
	popup.Rotation = tilt
	popup.Parent = layer
	UIStyle.list(popup, true, 4)
	UIStyle.icon(popup, if stat == "Strength" then UIStyle.Icons.Strength else UIStyle.Icons.Speed, GAIN_TEXT * 1.15 * k)
	local label = UIStyle.text(popup, gainText(amount), math.round(GAIN_TEXT * k)) -- white, like the stat numbers
	label.LayoutOrder = 2
	local pop = Instance.new("UIScale")
	pop.Scale = 0.4
	pop.Parent = popup
	TweenService:Create(pop, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local float = TweenInfo.new(GAIN_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(popup, float, {
		Position = UDim2.fromOffset(spot.X, spot.Y - GAIN_RISE * k),
		Rotation = tilt * 1.6, -- leans a little further as it rises
	}):Play()
	task.delay(GAIN_SECONDS * 0.5, UIStyle.fadeOut, popup, TweenInfo.new(GAIN_SECONDS * 0.5))
	task.delay(GAIN_SECONDS, function()
		popup:Destroy()
		gainsShown -= 1
	end)
end

-- Pops `amount` coins out in the middle of the screen and flies them to `target` (the coin icon). Each coin that
-- lands calls onLand with its share of the amount; the shares add up to `amount`.
local function flyCoins(amount: number, target: GuiObject, onLand: (number) -> ())
	local layer = flowGui
	if not layer then
		onLand(amount)
		return
	end
	local k = UIStyle.screenScale()
	local source = coinSource()
	local count = math.clamp(math.floor(math.sqrt(amount) / 2) + 1, COIN_MIN, COIN_MAX)
	local share = math.floor(amount / count)
	local landed = 0
	local soundEvery = math.ceil(count / COIN_SOUNDS_MAX) -- e.g. 18 coins: a sound on landings 1, 5, 9, 13, 17
	-- (No "+N" text over the coins since 2026-10-08, the user's call: the counter shows the coins arriving.)

	for i = 1, count do
		local mine = if i == count then amount - share * (count - 1) else share
		task.delay((i - 1) * COIN_STAGGER, function()
			local coin = UIStyle.icon(layer, UIStyle.Icons.Coins, COIN_SIZE * k)
			coin.AnchorPoint = Vector2.new(0.5, 0.5)
			coin.Position = UDim2.fromOffset(source.X, source.Y)
			coin.Size = UDim2.fromOffset(0, 0)
			local angle = math.random() * 2 * math.pi
			local reach = COIN_SPREAD * k * (0.35 + math.random() * 0.65)
			local burst = source + Vector2.new(math.cos(angle), math.sin(angle) * 0.6) * reach
			local pop = TweenInfo.new(COIN_POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			local big = COIN_SIZE * k * COIN_POP
			TweenService:Create(coin, pop, {
				Size = UDim2.fromOffset(big, big),
				Position = UDim2.fromOffset(burst.X, burst.Y),
				Rotation = math.random(-25, 25),
			}):Play()
			task.wait(COIN_POP_SECONDS)
			local settle = TweenInfo.new(COIN_HOLD_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(coin, settle, { Size = UDim2.fromOffset(COIN_SIZE * k, COIN_SIZE * k) }):Play()
			task.wait(COIN_HOLD_SECONDS)
			-- Fly along a curve that swings up and over to the counter, speeding up as it goes.
			local goal = target.AbsolutePosition + target.AbsoluteSize / 2 - layer.AbsolutePosition
			local bend = (burst + goal) / 2 + Vector2.new(0, -math.abs(goal.X - burst.X) * 0.35)
			local t = Instance.new("NumberValue")
			t.Changed:Connect(function(u)
				local a, b = burst:Lerp(bend, u), bend:Lerp(goal, u)
				local at = a:Lerp(b, u)
				coin.Position = UDim2.fromOffset(at.X, at.Y)
				local size = COIN_SIZE * k * (1 - 0.35 * u)
				coin.Size = UDim2.fromOffset(size, size)
			end)
			local flyInfo = TweenInfo.new(COIN_FLY_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local fly = TweenService:Create(t, flyInfo, { Value = 1 })
			fly.Completed:Connect(function()
				coin:Destroy()
				t:Destroy()
				landed += 1
				if (landed - 1) % soundEvery == 0 then
					clink()
				end
				onLand(mine)
			end)
			fly:Play()
		end)
	end
end

local function buildBanner(gui: ScreenGui)
	local holder = group(gui, "BannerHolder")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.32)
	UIStyle.autoScale(holder)
	local banner = UIStyle.text(holder, "", 52, Color3.fromRGB(255, 220, 110))
	banner.Name = "Banner"
	banner.Visible = false
	Instance.new("UIScale").Parent = banner
	bannerLabel = banner
end

-- The top: Forest Bar, bar buttons, server boost timer.
local function buildTop(gui: ScreenGui)
	local forestState = ReplicatedStorage:WaitForChild("ForestState")
	local top = group(gui, "Top")
	-- Phones: at the bottom like the pyramid's mobile layout, the bar under its buttons.
	local touch = UIStyle.isTouch()
	top.AnchorPoint = Vector2.new(0.5, if touch then 1 else 0)
	top.Position = UDim2.new(0.5, 0, 1, -8)
	if not touch then
		-- Up in Roblox's top bar row, between its buttons, like Build the Pyramid's (the user's ask, 2026-10-07).
		-- The HUD's safe insets start below that row, so move up by its height.
		local function place()
			top.Position = UDim2.new(0.5, 0, 0, 6 - GuiService.TopbarInset.Height)
		end
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
		place()
	end
	UIStyle.autoScale(top)
	UIStyle.list(top, false, 10, Enum.HorizontalAlignment.Center)

	local bar = Instance.new("Frame")
	bar.Name = "ForestBar"
	bar.Size = UDim2.fromOffset(if touch then 500 else 640, 60) -- narrower on phones, clear of Friend Boost
	bar.BackgroundColor3 = Color3.fromRGB(80, 66, 56)
	bar.BackgroundTransparency = 0.15
	bar.LayoutOrder = if touch then 5 else 1
	bar.Parent = top
	UIStyle.corner(bar, 16)
	UIStyle.stroke(bar, 7, nil, true) -- 7 since 2026-10-08 (was 5; the user wanted it a bit thicker)
	local scale = Instance.new("UIScale")
	scale.Parent = bar
	barScale = scale
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = UIStyle.WHITE
	fill.Parent = bar
	UIStyle.corner(fill, 14)
	local fillGradient = Instance.new("UIGradient")
	-- Light green into dark forest green along the fill (the user's ask, 2026-10-08; was cream to tan, then cream
	-- to forest green).
	fillGradient.Color = ColorSequence.new(Color3.fromRGB(150, 230, 110), Color3.fromRGB(30, 110, 40))
	fillGradient.Parent = fill
	local count = UIStyle.text(bar, "", 46)
	count.Name = "Count"
	count.AnchorPoint = Vector2.new(0.5, 0.5)
	count.Position = UDim2.fromScale(0.5, 0.5)
	count.ZIndex = 2

	local function refreshBar()
		local seeds = forestState:GetAttribute("Seeds")
		local target = forestState:GetAttribute("Target")
		if typeof(seeds) ~= "number" or typeof(target) ~= "number" or target <= 0 then
			return
		end
		count.Text = `{UIStyle.commas(seeds)} / {UIStyle.commas(target)}`
		-- Plain progress (2026-10-08: the ring tick marks were removed, the user's call, and with them the equal
		-- share of the bar each ring had).
		TweenService:Create(fill, FILL_TWEEN, { Size = UDim2.fromScale(math.clamp(seeds / target, 0, 1), 1) }):Play()
	end
	forestState:GetAttributeChangedSignal("Seeds"):Connect(refreshBar)
	forestState:GetAttributeChangedSignal("Target"):Connect(refreshBar)
	refreshBar()

	-- The buttons under the bar, like Build the Pyramid's: seeds while a forest is growing; during the break,
	-- break time (+1/+5/+10/+50 MIN), or with the "PICK!" toggle the worlds, to pick the next forest.
	local buttons = group(top, "BarBoosts")
	buttons.LayoutOrder = 2
	UIStyle.list(buttons, true, if touch then 10 else 16)
	local buttonSize = if touch then UDim2.fromOffset(112, 44) else UDim2.fromOffset(124, 46)
	local textSize = if touch then 27 else 30
	local function productButton(order: number, text: string, colors: { Color3 }, productId: number): TextButton
		local button = UIStyle.button(buttons, text, colors, buttonSize, textSize)
		button.LayoutOrder = order
		local tag = priceTag(button)
		local function showPrice()
			tag.Text = UIStyle.priceText(productId, Enum.InfoType.Product, showPrice)
		end
		showPrice()
		button.Activated:Connect(function()
			MarketplaceService:PromptProductPurchase(localPlayer, productId)
		end)
		return button
	end
	local seedButtons, timeButtons, worldButtons = {}, {}, {}
	for i, boost in GameConfig.BarBoosts do
		table.insert(seedButtons, productButton(i + 1, `+{UIStyle.commas(boost.Seeds)}`, BAR_COLORS[i], boost.ProductId))
	end
	-- A time button only sells while the break has room for it (Awakening.MaxBreakMinutes on the clock).
	local function roomFor(minutes: number): boolean
		local left = attribute(forestState, "AwakeningEndsAt") - workspace:GetServerTimeNow()
		return left + minutes * 60 <= GameConfig.Awakening.MaxBreakMinutes * 60
	end
	for i, pack in GameConfig.Awakening.BreakTime do
		local button = UIStyle.button(buttons, `+{pack.Minutes} MIN`, BAR_COLORS[i], buttonSize, textSize)
		button.LayoutOrder = i + 1
		local tag = priceTag(button)
		local function showPrice()
			tag.Text = UIStyle.priceText(pack.ProductId, Enum.InfoType.Product, showPrice)
		end
		showPrice()
		button.Activated:Connect(function()
			if roomFor(pack.Minutes) then
				MarketplaceService:PromptProductPurchase(localPlayer, pack.ProductId)
			else
				UIStyle.deny(button)
			end
		end)
		task.spawn(function()
			local full: boolean? = nil
			while true do
				local now = not roomFor(pack.Minutes)
				if now ~= full then
					full = now
					UIStyle.recolor(button, if now then UIStyle.Colors.Grey else BAR_COLORS[i])
				end
				task.wait(REFRESH_SECONDS)
			end
		end)
		table.insert(timeButtons, button)
	end
	for i, productId in GameConfig.Awakening.WorldPicks do
		local tier = GameConfig.Tiers[i]
		local button = productButton(i + 1, tier.Name, BAR_COLORS[i], productId)
		button.Size = UDim2.fromOffset(if touch then 150 else 176, buttonSize.Y.Offset)
		button.TextSize = if touch then 18 else 20
		table.insert(worldButtons, button)
	end
	-- "PICK!": the forest icon, switching the break's buttons between time and worlds.
	local pick = Instance.new("TextButton")
	pick.Name = "Pick"
	pick.LayoutOrder = 1
	pick.Text = ""
	pick.BackgroundTransparency = 1
	pick.Size = UDim2.fromOffset(buttonSize.Y.Offset + 10, buttonSize.Y.Offset)
	pick.Parent = buttons
	UIStyle.clicky(pick)
	local pickIcon = UIStyle.icon(pick, UIStyle.Icons.Forests, buttonSize.Y.Offset)
	pickIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	pickIcon.Position = UDim2.fromScale(0.5, 0.5)
	local pickLabel = UIStyle.text(pick, "PICK!", 20, Color3.fromRGB(255, 220, 110))
	pickLabel.AnchorPoint = Vector2.new(0.5, 0)
	pickLabel.Position = UDim2.new(0.5, 0, 0, -10)
	pickLabel.ZIndex = 3
	local picking = false
	local function showButtons()
		local breakOn = attribute(forestState, "AwakeningEndsAt") > 0
		pick.Visible = breakOn
		pickLabel.Text = if picking then "TIME" else "PICK!"
		for _, button in seedButtons do
			button.Visible = not breakOn
		end
		for _, button in timeButtons do
			button.Visible = breakOn and not picking
		end
		for _, button in worldButtons do
			button.Visible = breakOn and picking
		end
	end
	pick.Activated:Connect(function()
		picking = not picking
		showButtons()
	end)
	forestState:GetAttributeChangedSignal("AwakeningEndsAt"):Connect(function()
		if attribute(forestState, "AwakeningEndsAt") == 0 then
			picking = false -- the next break starts on the time buttons
		end
		showButtons()
	end)
	showButtons()

	-- What the open ring needs (the user found "fill the whole ring" wasn't obvious, 2026-10-08): a tree trunk's
	-- cross-section right of the bar, one ring per forest ring from the outside in, like the forest. Finished rings
	-- are green, the open ring glows and fills clockwise as its trees finish growing, and the middle shows how far
	-- along it is in percent. Replaced a "Grow every tree in the glowing ring: 8 / 84" line (the user's idea, the
	-- same day). Hidden during the break.
	local trunk = Instance.new("Frame")
	trunk.Name = "RingTrunk"
	trunk.Size = UDim2.fromOffset(TRUNK_SIZE, TRUNK_SIZE)
	trunk.BackgroundTransparency = 1 -- no bark disc behind the rings (the user's call, 2026-10-08)
	trunk.ZIndex = 3
	if touch then
		-- Phones: on its own at the top middle of the screen (2026-10-08, the user's ask; it was right of the bar at
		-- the bottom). The break's countdown uses that spot, but the trunk is hidden during the break.
		local holder = Instance.new("Frame")
		holder.Name = "RingTrunkHolder"
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0)
		holder.Size = UDim2.fromOffset(TRUNK_SIZE, TRUNK_SIZE)
		holder.Parent = gui
		UIStyle.autoScale(holder, TRUNK_GROW_TOUCH)
		-- At the very top, up in Roblox's top bar row (between its buttons), like the computer layout's bar: the HUD's
		-- safe insets start below that row, so move up by its height.
		local function place()
			holder.Position = UDim2.new(0.5, 0, 0, 4 - GuiService.TopbarInset.Height)
		end
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
		place()
		trunk.Parent = holder
	else
		trunk.Position = UDim2.new(1, 12, 0, 0) -- right of the bar, level with its top (the screen's top edge)
		trunk.Parent = bar
	end
	local function disc(parent: Instance, across: number, z: number): Frame
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
		frame.Size = UDim2.fromOffset(across, across)
		frame.BorderSizePixel = 0
		frame.ZIndex = z
		frame.Parent = parent
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = frame
		return frame
	end
	-- Half of the open ring's sweep (side 1 right, 0 left): a filled disc clipped to that half, with a gradient
	-- that's opaque on one side of a line through the middle, so turning it sweeps the half in. The next ring's
	-- disc covers the middle, leaving only this ring's band.
	local function sweepHalf(across: number, side: number, z: number): (Frame, UIGradient)
		local clip = Instance.new("Frame")
		clip.Name = "Sweep"
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.AnchorPoint = Vector2.new(0, 0.5)
		clip.Position = UDim2.new(0.5, (side - 1) * across / 2, 0.5, 0)
		clip.Size = UDim2.fromOffset(across / 2, across)
		clip.ZIndex = z
		clip.Parent = trunk
		local half = disc(clip, across, z)
		half.AnchorPoint = Vector2.zero
		half.Position = UDim2.fromOffset(-side * across / 2, 0)
		half.BackgroundColor3 = TRUNK_FILL
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(0.501, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = half
		return clip, gradient
	end
	type TrunkRing = { disc: Frame, sweeps: { Frame }, right: UIGradient, left: UIGradient }
	local trunkRings: { TrunkRing } = {}
	local percent: TextLabel? = nil
	local function buildTrunk(rings: number)
		for _, child in trunk:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(trunkRings)
		local outer = TRUNK_SIZE / 2
		local width = (outer - TRUNK_HEART / 2) / rings
		for i = 1, rings do
			local z = 3 + 2 * i
			local across = 2 * math.round(outer - (i - 1) * width) -- even, so the halves land on whole pixels
			local ring = disc(trunk, across, z)
			ring.Name = `Ring{i}`
			if i == 1 then
				UIStyle.stroke(ring, 3, nil, true) -- the black edge, like the bar's
			end
			local rightClip, right = sweepHalf(across, 1, z + 1)
			local leftClip, left = sweepHalf(across, 0, z + 1)
			table.insert(trunkRings, { disc = ring, sweeps = { rightClip, leftClip }, right = right, left = left })
		end
		local heart = disc(trunk, TRUNK_HEART, 5 + 2 * rings) -- over the last ring's sweep
		heart.Name = "Heart"
		heart.BackgroundColor3 = Color3.fromRGB(120, 80, 50)
		local label = UIStyle.text(heart, "", 15)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		for _, part in { label :: Instance, unpack(label:GetDescendants()) } do
			if part:IsA("GuiObject") then
				part.ZIndex += 6 + 2 * rings
			end
		end
		percent = label
	end
	local function refreshTrunk()
		local rings = attribute(forestState, "RingCount")
		trunk.Visible = rings > 0 and attribute(forestState, "AwakeningEndsAt") == 0
		if rings <= 0 then
			return
		end
		if #trunkRings ~= rings then
			buildTrunk(rings)
		end
		-- Which ring is open, counted like the forest's "Ring 3 of 9" (OpenRow is 0 once every ring is done).
		local row = forestState:GetAttribute("OpenRow")
		local openRing = if typeof(row) == "Vector2" then row.Y else 0
		local grid = GameConfig.Grid
		local open = if openRing == 0
			then rings + 1
			elseif forestState:GetAttribute("OutsideIn") ~= false then grid.HubRings + grid.ForestRings - openRing + 1
			else openRing - grid.HubRings
		local trees = attribute(forestState, "RingTrees")
		local grown = attribute(forestState, "RingDone")
		local turn = if trees > 0 then 360 * math.clamp(grown / trees, 0, 1) else 0
		-- Two rings (2026-10-09): the next ring's band fills too, fainter, as its early trees finish.
		local nextTrees = attribute(forestState, "NextRingTrees")
		local nextTurn = if nextTrees > 0 then 360 * math.clamp(attribute(forestState, "NextRingDone") / nextTrees, 0, 1) else 0
		-- The trunk's rings sit like the forest's: outer-first forests count from its edge, inner-first ones
		-- (the layout A/B test) from its heart, like a real tree's growth rings.
		local inward = forestState:GetAttribute("OutsideIn") ~= false
		for disc, ring in trunkRings do
			local i = if inward then disc else rings - disc + 1 -- this disc's ring, in opening order
			ring.disc.BackgroundColor3 = if i < open
				then TRUNK_GROWN[disc % 2 + 1]
				elseif i == open then TRUNK_OPEN
				else TRUNK_WOOD[disc % 2 + 1]
			local isNext = i == open + 1 and nextTurn > 0
			local t = if isNext then nextTurn else turn
			for _, sweep in ring.sweeps do
				sweep.Visible = i == open or isNext
			end
			for _, gradient in { ring.right, ring.left } do
				local half = gradient.Parent :: Frame
				half.BackgroundTransparency = if isNext then TRUNK_NEXT_FADE else 0
			end
			ring.right.Rotation = math.clamp(t, 0, 180)
			ring.left.Rotation = math.clamp(t, 180, 360)
		end
		-- The open ring's progress in percent, rounded down so it reads 100% only once it's done (the user's
		-- pick over the trees left, 2026-10-08).
		if percent then
			percent.Text = if open <= rings and trees > 0 then `{math.floor(100 * grown / trees)}%` else ""
		end
	end
	for _, name in { "RingCount", "OpenRow", "RingDone", "RingTrees", "NextRingDone", "NextRingTrees", "AwakeningEndsAt" } do
		forestState:GetAttributeChangedSignal(name):Connect(refreshTrunk)
	end
	refreshTrunk()

	local boostTimer = UIStyle.text(top, "", 28, Color3.fromRGB(255, 220, 110))
	boostTimer.Name = "ServerBoost"
	boostTimer.LayoutOrder = if touch then -1 else 3
	boostTimer.Visible = false

	-- Forest credit: until you've put ForestCreditSeeds acorns into this forest, a line says how many more.
	local needed = GameConfig.Stats.ForestCreditSeeds
	local credit = UIStyle.text(top, "", 24, Color3.fromRGB(170, 255, 140))
	credit.Name = "ForestCredit"
	credit.LayoutOrder = if touch then -3 else 5
	local earned = attribute(localPlayer, "ForestPlanted") >= needed -- no banner for credit earned before this
	local function refreshCredit()
		local planted = attribute(localPlayer, "ForestPlanted")
		local breakOn = attribute(forestState, "AwakeningEndsAt") > 0
		local inTutorial = attribute(localPlayer, "TutorialStep") < GameConfig.Tutorial.DoneStep -- one hint at a time
		credit.Visible = planted < needed and not breakOn and not inTutorial and localPlayer:GetAttribute("ForestPlanted") ~= nil
		credit.Text = `Plant {needed - planted} more acorns to earn this forest ({planted}/{needed})`
		if planted >= needed and not earned and not breakOn then
			HUD.banner("You'll earn this forest!", Color3.fromRGB(170, 255, 140))
		end
		earned = planted >= needed
	end
	localPlayer:GetAttributeChangedSignal("ForestPlanted"):Connect(refreshCredit)
	localPlayer:GetAttributeChangedSignal("TutorialStep"):Connect(refreshCredit)
	forestState:GetAttributeChangedSignal("AwakeningEndsAt"):Connect(refreshCredit)
	refreshCredit()

	-- Banners for everyone when someone buys seeds or the server boost.
	forestState:GetAttributeChangedSignal("BarBoosts"):Connect(function()
		local by = forestState:GetAttribute("BarBoostBy")
		HUD.banner(`{by} added {UIStyle.commas(attribute(forestState, "BarBoostSeeds"))} seeds!`)
	end)
	forestState:GetAttributeChangedSignal("ServerBoosts"):Connect(function()
		local by = forestState:GetAttribute("ServerBoostBy")
		HUD.banner(`{by} boosted everyone's training to {GameConfig.ServerBoost.Multiplier}x!`)
	end)
	task.spawn(function()
		while true do
			local left = attribute(forestState, "ServerBoostEndsAt") - workspace:GetServerTimeNow()
			boostTimer.Visible = left > 0
			boostTimer.Text = `{GameConfig.ServerBoost.Multiplier}x Server Training {UIStyle.clock(left)}`
			task.wait(REFRESH_SECONDS)
		end
	end)
end

-- One stat on the left: icon, big number, optional small line under it.
local function statRow(parent: Instance, order: number, icon: UIStyle.Icon, sub: boolean): (TextLabel, TextLabel?, GuiObject)
	local row = group(parent, `Stat{order}`)
	row.LayoutOrder = order
	UIStyle.list(row, true, 10)
	local art = UIStyle.icon(row, icon, 72)
	local column = group(row, "Text")
	column.LayoutOrder = 2
	UIStyle.list(column, false, 0)
	local number = UIStyle.text(column, "0", 60, nil, true)
	number.LayoutOrder = 1
	-- The small line under the number: its words ("Capacity: ") and its value ("0/989") are separate labels, so
	-- the value alone can pop on a level-up (2026-10-07). The value label is what's returned.
	local small: TextLabel? = nil
	if sub then
		local line = group(column, "Sub")
		line.LayoutOrder = 2
		UIStyle.list(line, true, 0)
		local words = UIStyle.text(line, "", 22, nil, true)
		words.Name = "Words"
		words.LayoutOrder = 1
		local value = UIStyle.text(line, "", 22, nil, true)
		value.Name = "Value"
		value.LayoutOrder = 2
		small = value
	end
	return number, small, art
end

-- Sets a small line made by statRow: its words and its value.
local function setSub(value: TextLabel, words: string, text: string)
	local label = (value.Parent :: Instance):FindFirstChild("Words") :: TextLabel
	label.Text = words
	value.Text = text
end

-- Right after the Walk Speed line: a small edit icon that opens the walk speed limit in Settings (the line itself
-- does too). It replaced a "Speed limit" button under the line (2026-10-08, the user's ask).
local EDIT_ICON = "rbxassetid://76019418992436" -- the user's pick (2026-10-08)
local function walkSetting(walk: TextLabel)
	local line = walk.Parent :: Instance -- the "Walk Speed: 179" row (words and value)
	local gap = Instance.new("Frame") -- some room between the numbers and the icon
	gap.Name = "Gap"
	gap.BackgroundTransparency = 1
	gap.Size = UDim2.fromOffset(8, 1)
	gap.LayoutOrder = 3
	gap.Parent = line
	local button = Instance.new("ImageButton")
	button.Name = "WalkSetting"
	button.LayoutOrder = 4
	button.BackgroundTransparency = 1
	button.Image = EDIT_ICON
	button.Size = UDim2.fromOffset(22, 22)
	button.Parent = line
	UIStyle.clicky(button)
	button.Activated:Connect(SettingsController.toggle) -- clicking again closes it
	local toggle = Instance.new("TextButton")
	toggle.Name = "Toggle"
	toggle.BackgroundTransparency = 1
	toggle.Text = ""
	toggle.Size = UDim2.fromScale(1, 1)
	toggle.ZIndex = 5
	toggle.Parent = walk
	toggle.Activated:Connect(SettingsController.toggle)
end

local function buildLeft(gui: Frame)
	local left = group(gui, "Stats")
	left.AnchorPoint = Vector2.new(0, 0.5)
	left.Position = UDim2.new(0, 14, 0.5, 0)
	UIStyle.autoScale(left)
	UIStyle.list(left, false, 8)
	local icons = UIStyle.Icons
	local coins, _, coinIcon = statRow(left, 1, icons.Coins, false)
	local speed, walk = statRow(left, 2, icons.Speed, true)
	if walk then
		walkSetting(walk)
	end
	local strength, capacity = statRow(left, 3, icons.Strength, true)
	local forests = statRow(left, 4, icons.Forests, false)
	local rollSpeed = roller(speed, attribute(localPlayer, "Speed"))
	local rollStrength = roller(strength, attribute(localPlayer, "Strength"))
	-- A floating "+N" for every Strength or Speed gain (not for the save loading: that's from nil), and the
	-- StatUp sound when it raises your capacity or walk speed by at least 1. The level-up's effect on your
	-- character (sparkles, ring, light pillar, flash) and the Capacity / Walk Speed line growing and shrinking
	-- were removed on 2026-10-08 (the user's call).
	local lastEffect = 0
	local function levelUpEffect()
		local now = os.clock()
		if now - lastEffect >= LEVEL_UP_GAP then
			lastEffect = now
			Sounds.play("StatUp")
		end
	end
	local function level(stat: "Strength" | "Speed", value: number): number
		return if stat == "Strength" then GameConfig.capacity(value) else math.round(GameConfig.walkSpeed(value))
	end
	local lastPop = 0
	local function watchGains(stat: "Strength" | "Speed")
		local last = localPlayer:GetAttribute(stat)
		localPlayer:GetAttributeChangedSignal(stat):Connect(function()
			local now = localPlayer:GetAttribute(stat)
			if typeof(now) == "number" and typeof(last) == "number" and now > last then
				gainPopup(stat, now - last)
				-- The training pop, with the popup so they line up, like Build the Pyramid's. One per rep: the
				-- Spring raises both stats at once, so a second update within half a rep doesn't pop again.
				local clock = os.clock()
				if clock - lastPop > GameConfig.Stats.RepSeconds / 2 then
					lastPop = clock
					Sounds.play("Gain")
				end
				if level(stat, now) > level(stat, last) then
					levelUpEffect()
				end
			end
			last = now
		end)
	end
	watchGains("Strength")
	watchGains("Speed")
	local rollForests = roller(forests, attribute(localPlayer, "ForestsCompleted"))

	local function refresh()
		local carried = attribute(localPlayer, "Carried")
		rollSpeed(attribute(localPlayer, "Speed"))
		rollStrength(attribute(localPlayer, "Strength"))
		rollForests(attribute(localPlayer, "ForestsCompleted"))
		if walk and capacity then
			local earned = math.round(GameConfig.walkSpeed(attribute(localPlayer, "Speed")))
			local cap = attribute(localPlayer, "WalkCap")
			setSub(walk, "Walk Speed: ", if cap > 0 and cap < earned then `{cap}/{earned}` else `{earned}`)
			setSub(
				capacity,
				"Capacity: ",
				`{UIStyle.commas(carried)}/{UIStyle.commas(GameConfig.capacity(attribute(localPlayer, "Strength")))}`
			)
		end
	end
	for _, name in { "Strength", "Speed", "Carried", "ForestsCompleted", "WalkCap" } do
		localPlayer:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()

	-- Coins: the counter shows what has landed. Coins still flying (inFlight) are added as each one lands,
	-- with a bump of the icon and number. Spending rolls straight down. The first value (the save loading)
	-- is shown as it is, without coins flying in.
	local rollCoins = roller(coins, attribute(localPlayer, "Coins"))
	local loaded = localPlayer:GetAttribute("Coins") ~= nil
	local last = attribute(localPlayer, "Coins")
	local inFlight = 0
	local gained = 0
	local function land(share: number)
		inFlight -= share
		rollCoins(last - inFlight, 0.25)
		bump(coinIcon, 1.6)
		bump(coins, 1.3)
	end
	localPlayer:GetAttributeChangedSignal("Coins"):Connect(function()
		local now = attribute(localPlayer, "Coins")
		local delta = now - last
		last = now
		if not loaded then
			loaded = true
			rollCoins(now, 0)
		elseif delta > 0 then
			inFlight += delta
			if gained == 0 then
				task.delay(POP_MERGE_SECONDS, function()
					local amount = gained
					gained = 0
					while hudGui and not hudGui.Enabled do -- wait out the cutscene, then fly
						task.wait(0.2)
					end
					flyCoins(amount, coinIcon, land)
				end)
			end
			gained += delta
		else
			rollCoins(now - inFlight)
		end
	end)
end

-- A boost pass button: sells the next pass of the ladder, or shows MAX.
local function boostButton(parent: Instance, order: number, stat: "Strength" | "Speed", icon: UIStyle.Icon, hex: string)
	local button = Instance.new("TextButton")
	button.Name = `{stat}Boost`
	button.LayoutOrder = order
	button.BackgroundTransparency = 1
	button.Text = ""
	button.AutomaticSize = Enum.AutomaticSize.XY
	button.Size = UDim2.new()
	button.Parent = parent
	UIStyle.clicky(button)
	-- The label overlaps the icon's bottom, like Build the Pyramid's (the user's ask, 2026-10-07).
	UIStyle.list(button, false, ICON_OVERLAP, Enum.HorizontalAlignment.Center)
	local art = UIStyle.icon(button, icon, 84)
	art.LayoutOrder = 1
	art.ZIndex = 0 -- under the label
	local tag = priceTag(art)
	local label = UIStyle.text(button, "", 28)
	label.LayoutOrder = 2
	label.RichText = true

	local ladder = GameConfig.Boosts[stat]
	local nextPass: GameConfig.Boost? = nil
	local function refresh()
		local owned = localPlayer:GetAttribute(`{stat}Boost`)
		local have = if typeof(owned) == "number" then owned else 1
		nextPass = nil
		for _, step in ladder do
			if step.Multiplier > have then
				nextPass = step
				break
			end
		end
		local shown = nextPass or ladder[#ladder]
		label.Text = `{shown.Multiplier}x <font color="{hex}">{stat}</font>`
		-- Maxed out: no price tag, and pressing it does nothing (no "MAX" tag, the user's call, 2026-10-07).
		tag.Visible = nextPass ~= nil
		if nextPass then
			tag.Text = UIStyle.priceText(nextPass.ProductId, Enum.InfoType.Product, refresh)
		end
	end
	localPlayer:GetAttributeChangedSignal(`{stat}Boost`):Connect(refresh)
	refresh()
	button.Activated:Connect(function()
		if nextPass then
			MarketplaceService:PromptProductPurchase(localPlayer, nextPass.ProductId)
		end
	end)
end

local function buildRight(gui: Frame)
	local right = group(gui, "Right")
	-- Phones: from the top down, so it ends above the jump and plant buttons.
	local touch = UIStyle.isTouch()
	right.AnchorPoint = Vector2.new(1, if touch then 0 else 0.5)
	right.Position = if touch then UDim2.new(1, -14, 0, 8) else UDim2.new(1, -14, 0.5, 0)
	UIStyle.autoScale(right)
	UIStyle.list(right, false, 26, Enum.HorizontalAlignment.Center) -- close, but clear of the price tags above each icon

	local shop = Instance.new("TextButton")
	shop.Name = "Shop"
	shop.LayoutOrder = 1
	shop.BackgroundTransparency = 1
	shop.Text = ""
	shop.AutomaticSize = Enum.AutomaticSize.XY
	shop.Size = UDim2.new()
	shop.Parent = right
	UIStyle.clicky(shop)
	UIStyle.list(shop, false, ICON_OVERLAP, Enum.HorizontalAlignment.Center)
	local shopArt = UIStyle.icon(shop, UIStyle.Icons.Shop, 96)
	shopArt.LayoutOrder = 1
	shopArt.ZIndex = 0 -- under the label
	UIStyle.text(shop, "SHOP", 32).LayoutOrder = 2
	shop.Activated:Connect(RobuxShopController.toggle)

	boostButton(right, 2, "Speed", UIStyle.Icons.Speed, SPEED_HEX)
	boostButton(right, 3, "Strength", UIStyle.Icons.Strength, STRENGTH_HEX)

	-- Settings and Codes are TopbarPlus buttons in Roblox's top bar, on the left next to the chat button (since
	-- 2026-10-07, the user's request). TopbarPlus v3 lives in ReplicatedStorage.Icon (a Studio-only package, not in src/).
	local Icon = (require :: any)(ReplicatedStorage:WaitForChild("Icon"))
	local function topbarButton(name: string, order: number, onClick: () -> ())
		local icon = Icon.new():setName(name):setOrder(order):align("Left"):oneClick()
		icon.selected:Connect(function()
			Sounds.play("Click")
			onClick()
		end)
		return icon
	end
	topbarButton("Settings", 1, SettingsController.toggle):setImage(UIStyle.Icons.Settings.Image):setCaption("Settings")
	-- Codes is hidden until there are codes to give out (the user's call, 2026-10-07); CodesController still works.
	local SHOW_CODES = false
	if SHOW_CODES then
		topbarButton("Codes", 2, CodesController.toggle):setLabel("Codes"):setCaption("Redeem a code")
	end
	-- Hide UI (2026-10-07, the user's ask): hides the side HUD (stats, SHOP and boosts, Friend Boost, the break
	-- countdown), which all sit in `gui` here, the "Side" frame, and the Forest Bar with its buttons ("Top"). The top
	-- bar's buttons stay.
	local function showHud(on: boolean)
		gui.Visible = on
		local top = (gui.Parent :: Instance):FindFirstChild("Top")
		if top and top:IsA("GuiObject") then
			top.Visible = on
		end
	end
	local hide = Icon.new():setName("HideUI"):setOrder(3):align("Left"):setLabel("Hide UI"):setCaption("Hide the UI")
	hide.selected:Connect(function()
		Sounds.play("Click")
		showHud(false)
		hide:setLabel("Show UI")
	end)
	hide.deselected:Connect(function()
		Sounds.play("Click")
		showHud(true)
		hide:setLabel("Hide UI")
	end)
end

-- Bottom left, on phones too (like the pyramid). The friends icon is a button that opens Roblox's invite-friends
-- prompt (2026-10-08, the user's ask).
local function inviteFriends() -- (UIStyle.clicky plays the click)
	local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, localPlayer)
	if ok and can then
		pcall(SocialService.PromptGameInvite, SocialService, localPlayer)
	end
end

local function buildFriends(gui: Frame)
	local row = group(gui, "FriendBoost")
	row.AnchorPoint = Vector2.new(0, 1)
	row.Position = UDim2.new(0, 14, 1, -14)
	UIStyle.autoScale(row)
	UIStyle.list(row, true, 8)
	local invite = Instance.new("ImageButton")
	invite.Name = "Invite"
	invite.BackgroundTransparency = 1
	invite.Image = UIStyle.Icons.Friends.Image
	invite.ScaleType = Enum.ScaleType.Fit
	invite.Size = UDim2.fromOffset(50, 50)
	invite.Parent = row
	UIStyle.clicky(invite)
	invite.Activated:Connect(function()
		task.spawn(inviteFriends)
	end)
	local label = UIStyle.text(row, "", 34, nil, true)
	label.LayoutOrder = 2
	local function refresh()
		local percent = math.round(attribute(localPlayer, "FriendBoost") * 100)
		label.Text = if percent > 0 then `+{percent}%` else "0%" -- just the number by the friends icon (2026-10-07)
	end
	localPlayer:GetAttributeChangedSignal("FriendBoost"):Connect(refresh)
	refresh()
end

-- The break after a forest: the countdown. (The spring's "2x boost" line was removed 2026-10-08, the user: the
-- "2X TRAINING" sign over the World Tree already says it.)
local function buildBreak(gui: Frame)
	local forestState = ReplicatedStorage:WaitForChild("ForestState")
	local bottom = group(gui, "Break")
	-- Phones: at the top, since the Forest Bar takes the bottom there.
	local touch = UIStyle.isTouch()
	bottom.AnchorPoint = Vector2.new(0.5, if touch then 0 else 1)
	bottom.Position = if touch then UDim2.new(0.5, 0, 0, 8) else UDim2.new(0.5, 0, 1, -20)
	bottom.Visible = false
	UIStyle.autoScale(bottom)
	UIStyle.list(bottom, false, 10, Enum.HorizontalAlignment.Center)
	local row = group(bottom, "Row")
	row.LayoutOrder = 2
	UIStyle.list(row, true, 14)
	local countdown = UIStyle.text(row, "", 40)
	countdown.Name = "Countdown"
	countdown.LayoutOrder = 1
	local function refresh()
		local endsAt = attribute(forestState, "AwakeningEndsAt")
		local running = endsAt > 0
		bottom.Visible = running
		if running then
			local picked = GameConfig.Tiers[attribute(forestState, "PickedTier")]
			local left = endsAt - workspace:GetServerTimeNow()
			countdown.Text = `Next forest in {UIStyle.clock(left)}`
				.. (if picked then `: {picked.Name}` else "")
				.. `  ({math.ceil(left / 60)}/{GameConfig.Awakening.MaxBreakMinutes} MIN)`
		end
	end
	forestState:GetAttributeChangedSignal("Extensions"):Connect(function()
		local by = forestState:GetAttribute("ExtendedBy")
		local minutes = attribute(forestState, "ExtendedMinutes")
		if typeof(by) == "string" then
			HUD.banner(`{by} added {minutes} minute{if minutes == 1 then "" else "s"} to the break!`)
		end
	end)
	forestState:GetAttributeChangedSignal("Picks"):Connect(function()
		local by = forestState:GetAttribute("PickedBy")
		local world = GameConfig.Tiers[attribute(forestState, "PickedTier")]
		if typeof(by) == "string" and world then
			HUD.banner(`{by} picked {world.Name} for the next forest!`, Color3.fromRGB(170, 255, 140))
		end
	end)
	while true do
		refresh()
		task.wait(REFRESH_SECONDS)
	end
end

-- Studio only: buttons for the DevCommand test commands (docs/plans/M6.md section 4, GUI.md).
local function buildDevPanel(gui: ScreenGui)
	if not RunService:IsStudio() then
		return
	end
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DevCommand", 10)
	if not (remote and remote:IsA("RemoteEvent")) then
		return
	end
	local panel = Instance.new("Frame")
	panel.Name = "TestPanel"
	-- Bottom right; top left on phones, where the plant button sits bottom right.
	local touch = UIStyle.isTouch()
	panel.AnchorPoint = Vector2.new(if touch then 0 else 1, if touch then 0 else 1)
	panel.Position = if touch then UDim2.fromOffset(120, 8) else UDim2.new(1, -12, 1, -12)
	panel.Size = UDim2.fromOffset(150, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = UIStyle.PANEL
	panel.BackgroundTransparency = 0.3
	panel.Parent = gui
	UIStyle.corner(panel, 8)
	UIStyle.list(panel, false, 3)
	UIStyle.padding(panel, 5)

	local leaveOne = false
	local items: { TextButton } = {}
	local function add(text: string, colors: { Color3 }, onClick: (TextButton) -> ()): TextButton
		local b = UIStyle.button(panel, text, colors, UDim2.new(1, 0, 0, 22), 14)
		b.LayoutOrder = #items + 1
		b.Visible = #items == 0
		b.Activated:Connect(function()
			onClick(b)
		end)
		table.insert(items, b)
		return b
	end
	local function leave(): number
		return if leaveOne then 1 else 0
	end
	local function fire(command: string, value: number): (TextButton) -> ()
		return function()
			remote:FireServer(command, value)
		end
	end
	local c = UIStyle.Colors
	add("Test panel +", c.Grey, function(b)
		local open = b.Text == "Test panel +"
		b.Text = if open then "Test panel –" else "Test panel +"
		for i = 2, #items do
			items[i].Visible = open
		end
	end)
	add("Fill ring", c.Green, function()
		remote:FireServer("fillOpenRow", leave())
	end)
	add("Fill forest", c.Green, function()
		remote:FireServer("fillAll", leave())
	end)
	add("Leave 1 tree: off", c.Grey, function(b)
		leaveOne = not leaveOne
		b.Text = if leaveOne then "Leave 1 tree: on" else "Leave 1 tree: off"
		UIStyle.recolor(b, if leaveOne then c.Teal else c.Grey)
	end)
	add("+1,000 coins", c.Gold, function()
		remote:FireServer("setCoins", attribute(localPlayer, "Coins") + 1000)
	end)
	add("+50 seeds", c.Teal, function()
		remote:FireServer("setCarried", attribute(localPlayer, "Carried") + 50)
	end)
	add("Next world (new forest)", c.Purple, function()
		local tier = attribute(ReplicatedStorage:WaitForChild("ForestState"), "TierId")
		remote:FireServer("setTier", tier % #GameConfig.Tiers + 1)
	end)
	if GameConfig.Features.SeedShop then
		add("+1 of each special seed", c.Teal, function()
			for i in GameConfig.SeedShop.Seeds do
				remote:FireServer("grantSeed", i)
			end
		end)
	end
	add("Save my stats", c.Teal, fire("saveSnapshot", 0))
	add("Load saved stats", c.Teal, fire("loadSnapshot", 0))
	add("Reset to new player", c.Red, fire("resetProfile", 0))
	add("Replay tutorial intro", c.Blue, fire("restartTutorial", 0))
	-- The starter quests (QuestController): back to quest 1, or on to the next (past the last = all done, then 1 again).
	add("Restart quests", c.Blue, fire("setQuestIndex", 1))
	add("Skip quest", c.Blue, function()
		remote:FireServer("setQuestIndex", attribute(localPlayer, "QuestIndex") % (#GameConfig.Quests + 1) + 1)
	end)
	add("Extend break +1 min", c.Gold, fire("extendBreak", 1))
	add("Pick Kyoto Forest", c.Gold, fire("pickWorld", 2))
	add("End break", c.Gold, fire("endAwakening", 0))
	add(`Fake buy +{GameConfig.BarBoosts[1].Seeds} seeds`, c.Purple, fire("buyBar", 1))
	add("Fake server boost", c.Purple, fire("buyServerBoost", 0))
	add("Clear boost passes", c.Purple, function()
		remote:FireServer("grantStrengthBoost", 1)
		remote:FireServer("grantSpeedBoost", 1)
	end)
	add("Friend boost 20%", c.Purple, fire("setFriendBoost", 20))
	add("Clear station passes", c.Red, fire("clearStationPasses", 0))
	add("Clear Ranger pass", c.Red, fire("grantHands", 1)) -- this session only: back to the plain gnome
	-- Hotkeys for filming in Freecam (Shift+P), which hides this panel: R fills the ring, F the forest.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			remote:FireServer("fillOpenRow", leave())
		elseif input.KeyCode == Enum.KeyCode.F then
			remote:FireServer("fillAll", leave())
		end
	end)
end

function HUD.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	-- Everything but the top (the Forest Bar) goes in one full-screen frame, so the Hide UI button can hide it.
	local side = Instance.new("Frame")
	side.Name = "Side"
	side.BackgroundTransparency = 1
	side.Size = UDim2.fromScale(1, 1)
	side.Parent = gui
	buildLeft(side)
	buildRight(side)
	buildFriends(side)
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	hudGui = gui
	local flow = Instance.new("ScreenGui")
	flow.Name = "CoinFlow"
	flow.ResetOnSpawn = false
	flow.IgnoreGuiInset = true
	flow.ScreenInsets = Enum.ScreenInsets.None
	flow.DisplayOrder = 3 -- over the HUD and the shops
	flow.Parent = gui.Parent
	flowGui = flow
	buildBanner(flow) -- on the top layer, so banners show over the shops too
	task.spawn(buildTop, gui)
	task.spawn(buildBreak, side)
	task.spawn(buildDevPanel, gui)
end

return HUD
