--!strict
-- TutorialController: the first-time experience (docs/plans/M10.md; story intro and fixed steps 2026-10-07).
-- A new player (TutorialStep 0) first sees the story intro: a short cinematic over the island to the World
-- Tree with captions ("Help re-plant the trees to bring back the World Tree!"), which can be skipped. Then one
-- prompt at a time ("2/6 Plant them in the glowing tiles"), with the blue arrow (TargetController's guide beam)
-- leading to where to go. TutorialService (server) saves the step and moves it on:
--   1 grab acorns (arrow to a pile)   2 plant them (the usual arrow to a plot)   3 bench for Strength (the 1x pad)
--   4 run for Speed (the 1x pad)      5 fill up again (arrow to a pile)         6 plant them all
--   7 buy an upgrade (arrow to the shop)
-- and then "Tutorial complete!".
-- After the tutorial, a training tip: planting Tutorial.RemindTrips loads in a row without training shows "Tip:
-- train to carry more and walk faster" with the arrow to your best unlocked station for a few seconds (at most once
-- every RemindCooldown; starting to train or arriving there ends it).
-- Also the free gift (simplified 2026-10-07, the user's call): no panel of our own. A gift button (until it's
-- claimed) and the gift board's E prompt in the lobby (GiftPrompt) open Roblox's own Favorite prompt; nothing pops it
-- up by itself (the timed popup was removed 2026-10-07, the user's call). When the player confirms (or has already
-- favorited the game), the client asks the server for the coins (ClaimFreeGift), which pays once ever.

local AvatarEditorService = game:GetService("AvatarEditorService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)
local HUD = require(script.Parent.HUD)
local TargetController = require(script.Parent.TargetController)
local Sounds = require(script.Parent.Parent.Sounds)
local UIStyle = require(script.Parent.Parent.UIStyle)

local CHECK_SECONDS = 0.25
-- The story intro: captions in order, each shown for its seconds; the camera sweeps in over all of them.
local INTRO_LINES = {
	{ text = "Long ago, a great forest covered this island.", seconds = 3.5 },
	{ text = "Then the trees were lost, and the World Tree began to fade.", seconds = 4 },
	{ text = "Help re-plant the trees to bring back the World Tree!", seconds = 4.5, big = true },
}
local INTRO_FROM = { distance = 300, height = 140 } -- the camera starts far out and high...
local INTRO_TO = { distance = 75, height = 30 } -- ...and ends close to the World Tree
local INTRO_TURN = math.rad(70) -- how far it circles meanwhile
local INTRO_LOOK_HEIGHT = 18 -- it looks at the World Tree this high up
local BAR_HEIGHT = 0.12 -- the letterbox bars, as a share of the screen height
local ARRIVED_STUDS = 6 -- the arrow hides once you're this close (inside the piles' 10-stud grab reach)

local TutorialController = {}

local localPlayer = Players.LocalPlayer

local function attribute(name: string): number?
	local value = localPlayer:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

-- The nearest tagged spot (pile, pad, shop ring), looked up each time: map parts can stream in and out.
local function nearestTagged(tag: string, from: Vector3): Vector3?
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, item in CollectionService:GetTagged(tag) do
		local position = if item:IsA("Model") then item:GetPivot().Position elseif item:IsA("BasePart") then item.Position else nil
		if position and (position - from).Magnitude < bestDistance then
			best, bestDistance = position, (position - from).Magnitude
		end
	end
	return best
end

-- The current step: the prompt to show and where the arrow should lead (nil: the usual behaviour).
local function currentStep(root: BasePart): (string?, Vector3?)
	local t = GameConfig.Tutorial
	local index = attribute("TutorialStep")
	local name = index and t.Steps[index]
	if not (index and name) then
		return nil, nil -- loading, the intro, or done
	end
	local carried, strength, speed = attribute("Carried") or 0, attribute("Strength") or 0, attribute("Speed") or 0
	local capacity = GameConfig.capacity(strength)
	local text, spot = "", nil
	if name == "PickUp" then
		text, spot = "Grab acorns", nearestTagged("SeedRack", root.Position)
	elseif name == "Plant" then
		text = "Plant them in the glowing tiles"
	elseif name == "Train" then
		text = `Lift weights to carry more ({math.floor(strength)}/{t.TrainedStrength})`
		spot = nearestTagged("TutorialTraining", root.Position)
	elseif name == "TrainSpeed" then
		text = `Run on the treadmill to walk faster ({math.floor(speed)}/{t.TrainedSpeed})`
		spot = nearestTagged("TutorialTraining", root.Position)
	elseif name == "PickUpMore" then
		text, spot = `Fill up on acorns ({carried}/{capacity})`, nearestTagged("SeedRack", root.Position)
	elseif name == "PlantMore" then
		text = "Plant them all"
	elseif name == "Shop" then
		text, spot = "Buy an upgrade", nearestTagged("ShopZone", root.Position)
	end
	return `{index}/{#t.Steps}  {text}`, spot
end

-- The story intro: letterbox bars, captions and a camera sweep in to the World Tree. Skippable. Tells the
-- server when it's over (watched or skipped).
local function playIntro()
	if not localPlayer.Character then
		localPlayer.CharacterAdded:Wait() -- the camera goes back to the character afterwards
	end
	task.wait(1) -- let the spawn settle and the map stream in
	local forestState = ReplicatedStorage:WaitForChild("ForestState")
	local centerValue = forestState:GetAttribute("Center")
	local center = if typeof(centerValue) == "Vector3" then centerValue else Vector3.zero
	pcall(localPlayer.RequestStreamAroundAsync, localPlayer, center)
	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialIntro"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = 10
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- the Skip button's text draws over the button
	local bars = {}
	for i, anchor in { 0, 1 } do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0, anchor)
		bar.Position = UDim2.fromScale(0, anchor)
		bar.Size = UDim2.fromScale(1, 0)
		bar.BackgroundColor3 = UIStyle.BLACK
		bar.BorderSizePixel = 0
		bar.Parent = gui
		bars[i] = bar
	end
	local captionHolder = Instance.new("Frame")
	captionHolder.AnchorPoint = Vector2.new(0.5, 1)
	captionHolder.Position = UDim2.new(0.5, 0, 1 - BAR_HEIGHT, -24)
	captionHolder.AutomaticSize = Enum.AutomaticSize.XY
	captionHolder.BackgroundTransparency = 1
	captionHolder.Parent = gui
	UIStyle.autoScale(captionHolder)
	local caption = UIStyle.text(captionHolder, "", 40)
	local skip = UIStyle.button(gui, "Skip", UIStyle.Colors.Grey, UDim2.fromOffset(110, 44), 24)
	skip.AnchorPoint = Vector2.new(1, 1)
	skip.Position = UDim2.new(1, -20, 1, -20)
	skip.ZIndex = 5
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	for _, bar in bars do
		TweenService:Create(bar, TweenInfo.new(0.6), { Size = UDim2.fromScale(1, BAR_HEIGHT) }):Play()
	end

	local camera = workspace.CurrentCamera
	HUD.setVisible(false)
	camera.CameraType = Enum.CameraType.Scriptable
	local total = 0
	for _, line in INTRO_LINES do
		total += line.seconds
	end
	local start = os.clock()
	local startAngle = math.rad(200)
	local skipped = false
	skip.Activated:Connect(function()
		skipped = true
	end)
	local connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - start) / total, 0, 1)
		local ease = 1 - (1 - t) ^ 2
		local distance = INTRO_FROM.distance + (INTRO_TO.distance - INTRO_FROM.distance) * ease
		local height = INTRO_FROM.height + (INTRO_TO.height - INTRO_FROM.height) * ease
		local angle = startAngle + INTRO_TURN * ease
		local eye = center + Vector3.new(math.cos(angle) * distance, height, math.sin(angle) * distance)
		camera.CFrame = CFrame.lookAt(eye, center + Vector3.new(0, INTRO_LOOK_HEIGHT, 0))
	end)
	for _, line in INTRO_LINES do
		if skipped then
			break
		end
		caption.Text = line.text
		caption.TextSize = if line.big then 52 else 40
		caption.TextColor3 = if line.big then Color3.fromRGB(255, 220, 110) else UIStyle.WHITE
		local pop = Instance.new("UIScale")
		pop.Scale = 0.85
		pop.Parent = caption
		TweenService:Create(pop, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		if line.big then
			Sounds.play("LevelUp")
		end
		local shown = os.clock()
		while not skipped and os.clock() - shown < line.seconds do
			task.wait(0.05)
		end
		pop:Destroy()
	end
	connection:Disconnect()
	camera.CameraType = Enum.CameraType.Custom
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	HUD.setVisible(true)
	gui:Destroy()
	Remotes.event("TutorialIntroDone"):FireServer()
end

-- The free gift: Roblox's Favorite prompt; the coins when the player favorites (or already has).
local asking = false
local function askFavorite()
	if asking or attribute("FreeGiftClaimed") ~= 0 then
		return
	end
	asking = true
	-- (No "already favorited?" check first: AvatarEditorService.GetFavorite needs the player to grant inventory
	-- access, so it always failed. Roblox's Favorite prompt itself handles a game that's already a favorite.)
	-- In Studio favoriting can't complete, so the claim only happens in the live game.
	local prompted =
		pcall(AvatarEditorService.PromptSetFavorite, AvatarEditorService, game.PlaceId, Enum.AvatarItemType.Asset, true)
	if prompted then
		local result = AvatarEditorService.PromptSetFavoriteCompleted:Wait()
		if result == Enum.AvatarPromptResult.Success then
			Remotes.event("ClaimFreeGift"):FireServer()
			HUD.banner(`Thanks for favoriting! +{GameConfig.Economy.FreeGiftCoins} coins`, Color3.fromRGB(255, 160, 205))
		end
	end
	asking = false
end

local function buildGui(): (TextLabel, TextButton)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Tutorial"
	gui.ResetOnSpawn = false

	-- The hint sits under the Forest Bar and its buttons.
	local hintHolder = Instance.new("Frame")
	hintHolder.AnchorPoint = Vector2.new(0.5, 0)
	hintHolder.Position = UDim2.fromScale(0.5, 0.2)
	hintHolder.AutomaticSize = Enum.AutomaticSize.XY
	hintHolder.BackgroundTransparency = 1
	hintHolder.Parent = gui
	UIStyle.autoScale(hintHolder)
	local prompt = UIStyle.text(hintHolder, "", 38, Color3.fromRGB(120, 200, 255))
	prompt.Name = "Prompt"
	prompt.Visible = false

	-- Top right, under Roblox's own buttons; top left on phones, where the SHOP column starts at the top.
	local touch = UIStyle.isTouch()
	local giftHolder = Instance.new("Frame")
	giftHolder.AnchorPoint = Vector2.new(if touch then 0 else 1, 0)
	giftHolder.Position = if touch then UDim2.fromOffset(14, 8) else UDim2.new(1, -14, 0, 8)
	giftHolder.Size = UDim2.fromOffset(170, 50)
	giftHolder.BackgroundTransparency = 1
	giftHolder.Parent = gui
	UIStyle.autoScale(giftHolder)
	giftHolder.Size = UDim2.fromOffset(150, 50)
	-- Just the coin icon and "+500" (the user's call, 2026-10-07): pressing it opens Roblox's favorite prompt.
	-- No background (the user's call): a plain button, so the button style's text copies don't join the row.
	local giftButton = Instance.new("TextButton")
	giftButton.Name = "GiftButton"
	giftButton.Text = ""
	giftButton.BackgroundTransparency = 1
	giftButton.Size = UDim2.fromScale(1, 1)
	giftButton.Visible = false
	giftButton.Parent = giftHolder
	UIStyle.clicky(giftButton)
	local giftRow = Instance.new("UIListLayout")
	giftRow.FillDirection = Enum.FillDirection.Horizontal
	giftRow.HorizontalAlignment = Enum.HorizontalAlignment.Center
	giftRow.VerticalAlignment = Enum.VerticalAlignment.Center
	giftRow.Padding = UDim.new(0, 6)
	giftRow.Parent = giftButton
	UIStyle.icon(giftButton, UIStyle.Icons.Coins, 34)
	UIStyle.text(giftButton, `+{GameConfig.Economy.FreeGiftCoins}`, 28)

	giftButton.Activated:Connect(askFavorite)

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	return prompt, giftButton
end

function TutorialController.start()
	local prompt, giftButton = buildGui()
	-- The story intro for a new player, once the save says so; and the "complete" moment at the end.
	local lastStep = localPlayer:GetAttribute("TutorialStep")
	local introPlaying = false
	local function onStep()
		local step = localPlayer:GetAttribute("TutorialStep")
		if step == 0 and not introPlaying then
			introPlaying = true
			task.spawn(function()
				playIntro()
				introPlaying = false
			end)
		elseif step == GameConfig.Tutorial.DoneStep and typeof(lastStep) == "number" and lastStep < step then
			HUD.banner("Tutorial complete! Now help grow the forest!", Color3.fromRGB(170, 255, 140))
			Sounds.play("Fanfare")
		end
		lastStep = step
	end
	localPlayer:GetAttributeChangedSignal("TutorialStep"):Connect(onStep)
	onStep()

	-- The training tip: loads planted (Carried back to 0) since you last gained Strength or Speed.
	local trips, tipUntil, nextTip = 0, 0, 0
	local lastCarried = attribute("Carried") or 0
	localPlayer:GetAttributeChangedSignal("Carried"):Connect(function()
		local carried = attribute("Carried") or 0
		if carried == 0 and lastCarried > 0 then
			trips += 1
		end
		lastCarried = carried
	end)
	for _, stat in { "Strength", "Speed" } do
		local last = attribute(stat) or 0
		localPlayer:GetAttributeChangedSignal(stat):Connect(function()
			local now = attribute(stat) or 0
			if now > last then
				trips, tipUntil = 0, 0 -- trained: no tip needed
			end
			last = now
		end)
	end
	-- Your best station by forests (station passes aren't known here; this is only where the arrow points).
	local function bestPad(): Vector3?
		local forests = attribute("ForestsCompleted") or 0
		local lobby = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Lobby")
		local best: Vector3? = nil
		for _, station in GameConfig.Stats.GymMultipliers do
			local pad = lobby and lobby:FindFirstChild(`TierPad {station.Multiplier}x`)
			local floor = pad and pad:FindFirstChild("Floor")
			if forests >= station.ForestsDone and floor and floor:IsA("BasePart") then
				best = floor.Position
			end
		end
		return best
	end
	local function trainingTip(root: BasePart): (string?, Vector3?)
		local t = GameConfig.Tutorial
		if (attribute("TutorialStep") or 0) < t.DoneStep then
			return nil, nil
		end
		local clock = os.clock()
		if trips >= t.RemindTrips and clock >= nextTip then
			trips, tipUntil, nextTip = 0, clock + t.RemindSeconds, clock + t.RemindCooldown
		end
		if clock >= tipUntil then
			return nil, nil
		end
		local spot = bestPad() or nearestTagged("TutorialTraining", root.Position)
		return "Tip: train to carry more and walk faster", spot
	end

	-- The gift board's E prompt (GiftPrompt) opens the Favorite prompt; it's hidden once the gift is claimed.
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(triggered)
		if CollectionService:HasTag(triggered, "GiftPrompt") and attribute("FreeGiftClaimed") == 0 then
			task.spawn(askFavorite)
		end
	end)
	while true do
		task.wait(CHECK_SECONDS)
		local claimed = attribute("FreeGiftClaimed")
		giftButton.Visible = claimed == 0 and not introPlaying

		for _, giftPrompt in CollectionService:GetTagged("GiftPrompt") do
			if giftPrompt:IsA("ProximityPrompt") then
				giftPrompt.Enabled = claimed == 0
			end
		end
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local text, spot = nil, nil
		if root and root:IsA("BasePart") and not introPlaying then
			text, spot = currentStep(root)
			if not text then
				text, spot = trainingTip(root)
			end
			if spot and (Vector3.new(spot.X, root.Position.Y, spot.Z) - root.Position).Magnitude <= ARRIVED_STUDS then
				spot = nil -- you're there
			end
		end
		prompt.Text = text or ""
		prompt.Visible = text ~= nil
		TargetController.setGuideTarget(spot)
	end
end

return TutorialController
