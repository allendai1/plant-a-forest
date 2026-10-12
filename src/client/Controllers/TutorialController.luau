--!strict
-- TutorialController: the first-time experience (docs/plans/M10.md; story intro and fixed steps 2026-10-07).
-- A new player (TutorialStep 0) first sees the story intro (the Springtown story since 2026-10-10): the camera glides
-- from camp across the canyon to Springtown with captions ("Build a bridge to reach it!"), which can be skipped. Then
-- one prompt at a time ("2/5 Press E to place planks on the highlighted section"), with the arrow (TargetController's
-- guide beam) leading to where to go. TutorialService (server) saves the step and moves it on:
--   1 grab planks (arrow to the pile)   2 place them (the usual arrow to a slot)   3 bench for Strength (the 1x pad)
--   4 run for Speed (the 1x pad)        5 buy an upgrade (arrow to the shop)
-- and then "Tutorial finished!". The steps name the button for the device (2026-10-09, the user's ask).
-- After the tutorial, a training tip: planting Tutorial.RemindTrips loads in a row without training shows "Tip:
-- train to carry more and walk faster" with the arrow to your best unlocked station for a few seconds (at most once
-- every RemindCooldown; starting to train or arriving there ends it).
-- Also the free gifts' "+N" button at the top (until both are claimed), which opens the FREE GIFTS window
-- (GiftsController, 2026-10-11; it opened Roblox's favorite prompt before). Nothing pops it up by itself (the timed
-- popup was removed 2026-10-07, the user's call).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local BridgeGrid = require(Shared.BridgeGrid)
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)
local BridgeController = require(script.Parent.BridgeController)
local HUD = require(script.Parent.HUD)
local GiftsController = require(script.Parent.GiftsController)
local TargetController = require(script.Parent.TargetController)
local Sounds = require(script.Parent.Parent.Sounds)
local UIStyle = require(script.Parent.Parent.UIStyle)

local CHECK_SECONDS = 0.25
local FINISHED_SIZE = 0.75 -- the "Tutorial finished!" banner, as a share of a normal banner's size
local FINISHED_SECONDS = 4 -- and how long it stays (other banners: 3)
-- The story intro: captions in order, each shown for its seconds; meanwhile the camera glides from over camp, along
-- the bridge's line and up over the canyon, to Springtown on the far rim (the user's story, 2026-10-10).
local INTRO_LINES = {
	{ text = "Across {canyon} lies {town}...", seconds = 3.5 }, -- the live canyon's (storyText)
	{ text = "...but there's no way across.", seconds = 3 },
	{ text = "Build a bridge to reach it!", seconds = 4, big = true },
}
local INTRO_FROM = Vector3.new(60, 35, 40) -- over camp (bridge-local: X across, Y up, -Z out across the canyon)...
local INTRO_TO_TOWN = Vector3.new(-40, 45, 130) -- ...to here from Springtown's middle, looking at it
local INTRO_ARC = 260 -- how high the camera rises over the canyon on the way
local BAR_HEIGHT = 0.12 -- the letterbox bars, as a share of the screen height
local SHOP_RING_STUDS = 14 -- this close to the shop's ring counts as in it (its "Buy an upgrade" half)
local ARRIVED_STUDS = 6 -- the arrow hides once you're this close (inside the piles' 10-stud grab reach)

local TutorialController = {}

-- `text` with {canyon} and {town} filled in for the live canyon (GameConfig Tiers[].Town, 2026-10-11).
local function storyText(text: string): string
	local forestState = ReplicatedStorage:FindFirstChild("ForestState")
	local tier = GameConfig.tierFor(forestState and forestState:GetAttribute("TierId"))
	return (string.gsub(string.gsub(text, "{canyon}", tier.Called), "{town}", tier.Town))
end

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

-- The button to press on this device: a phone's on-screen button, a gamepad's button or the keyboard key.
-- UIStyle.inputKind, the same as the pile's prompt, so the two always agree.
local function key(keyboard: string, phone: string, gamepad: string): string
	local kind = UIStyle.inputKind()
	return if kind == "Touch" then phone elseif kind == "Gamepad" then gamepad else keyboard
end

-- The current step: the prompt to show and where the arrow should lead (nil: the usual behaviour).
local function currentStep(root: BasePart): (string?, Vector3?)
	local t = GameConfig.Tutorial
	local index = attribute("TutorialStep")
	local name = index and t.Steps[index]
	if not (index and name) then
		return nil, nil -- loading, the intro, or done
	end
	local strength, speed = attribute("Strength") or 0, attribute("Speed") or 0
	-- Short lines, no "3/7" counter (2026-10-11, the user's call: players should read as little as possible). A step
	-- with two things to do shows one at a time (off the bench, then the treadmill; into the shop's ring, then buy).
	local text, spot = "", nil
	if name == "PickUp" then
		text = `{key("Hold E", "Hold Pick Up", "Hold X")} at the planks`
		spot = nearestTagged("SeedRack", root.Position)
	elseif name == "Plant" then
		text = `{key("Press E", "Tap Build", "Press X")} to build`
	elseif name == "Train" then
		text = `{key("Press E", "Tap Train", "Press X")} at a bench  {math.floor(strength)}/{t.TrainedStrength}`
		spot = nearestTagged("TutorialTraining", root.Position)
	elseif name == "TrainSpeed" then
		local benching = localPlayer:GetAttribute("Benching")
		if typeof(benching) == "string" and benching ~= "" then
			text = `{key("Press Space", "Tap Jump", "Press A")} to get up` -- you leave a bench by jumping
		else
			text = `Run on a treadmill  {math.floor(speed)}/{t.TrainedSpeed}`
			spot = nearestTagged("TutorialTraining", root.Position)
		end
	elseif name == "Shop" then
		spot = nearestTagged("ShopZone", root.Position)
		local inRing = spot and (Vector3.new(spot.X, root.Position.Y, spot.Z) - root.Position).Magnitude <= SHOP_RING_STUDS
		text = if inRing then "Buy an upgrade" else "Go to the shop"
	elseif name == "PickUpMore" then
		text = `Grab more planks  {attribute("Carried") or 0}/{GameConfig.capacity(strength)}`
		spot = nearestTagged("SeedRack", root.Position)
	elseif name == "Build" then
		text = "Go build!" -- the usual arrow leads to the bridge
	end
	return text, spot
end

-- The story intro: letterbox bars, captions and the camera's glide to Springtown. Skippable. Tells the server when
-- it's over (watched or skipped).
local function playIntro()
	if not localPlayer.Character then
		localPlayer.CharacterAdded:Wait() -- the camera goes back to the character afterwards
	end
	-- After the join loading screen (ReplicatedFirst.Loading sets Loaded once the terrain and the bridge are in; the
	-- intro used to start before the terrain was there, 2026-10-11). At most 50 s, in case it never says so.
	local waited = os.clock()
	while not localPlayer:GetAttribute("Loaded") and os.clock() - waited < 50 do
		task.wait(0.2)
	end
	task.wait(0.5) -- let the spawn settle
	local forestState = ReplicatedStorage:WaitForChild("ForestState")
	local frameValue = forestState:GetAttribute("BridgeFrame")
	local frame = if typeof(frameValue) == "CFrame" then frameValue else CFrame.identity
	local townValue = forestState:GetAttribute("SpringCenter")
	local town = if typeof(townValue) == "Vector3" then townValue else frame:PointToWorldSpace(Vector3.new(0, 0, -3060))
	pcall(localPlayer.RequestStreamAroundAsync, localPlayer, town) -- the terrain under the town, for the last shot
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
	local skipped = false
	skip.Activated:Connect(function()
		skipped = true
	end)
	local connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - start) / total, 0, 1)
		local ease = t * t * (3 - 2 * t)
		local from = frame:PointToWorldSpace(INTRO_FROM)
		local to = town + frame:VectorToWorldSpace(INTRO_TO_TOWN)
		local eye = from:Lerp(to, ease) + Vector3.new(0, math.sin(math.pi * ease) * INTRO_ARC, 0)
		-- It looks along the bridge's line at first, settling on the town.
		local ahead = frame:PointToWorldSpace(Vector3.new(0, 0, -600)):Lerp(town + Vector3.new(0, 15, 0), math.min(1, ease * 1.4))
		camera.CFrame = CFrame.lookAt(eye, ahead)
	end)
	for _, line in INTRO_LINES do
		if skipped then
			break
		end
		caption.Text = storyText(line.text)
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
	local prompt = UIStyle.text(hintHolder, "", 38, UIStyle.WHITE) -- white (the user, 2026-10-08; was light blue)
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
	-- Just the coin icon and "+N" (the user's call, 2026-10-07): pressing it opens the FREE GIFTS window (GiftsController;
	-- it opened Roblox's favorite prompt until 2026-10-11). N is the coins still to be had.
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
	local giftCoins = UIStyle.text(giftButton, "", 28)
	giftCoins.Name = "Coins"

	giftButton.Activated:Connect(GiftsController.open)

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
			-- Smaller and a second longer than other banners (the user's call, 2026-10-09).
			HUD.banner(
				storyText("Tutorial done! Build to {town}!"),
				Color3.fromRGB(170, 255, 140),
				FINISHED_SIZE,
				FINISHED_SECONDS
			)
			Sounds.play("Fanfare")
		end
		lastStep = step
	end
	localPlayer:GetAttributeChangedSignal("TutorialStep"):Connect(onStep)
	onStep()

	-- The first tree you ever finish (2026-10-09): the server pays Economy.FirstTreeCoins and sets FirstTreeDone 0 -> 1.
	local firstTree = localPlayer:GetAttribute("FirstTreeDone")
	localPlayer:GetAttributeChangedSignal("FirstTreeDone"):Connect(function()
		local now = localPlayer:GetAttribute("FirstTreeDone")
		if firstTree == 0 and now == 1 then
			HUD.banner(`Your first section! +{GameConfig.Economy.FirstTreeCoins} coins`, Color3.fromRGB(170, 255, 140))
			HUD.confetti()
			Sounds.play("Fanfare")
		end
		firstTree = now
	end)

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
		if (attribute("TutorialStep") or 0) < t.DoneStep or (attribute("Strength") or 0) > t.RemindMaxStrength then
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
		return "Train to carry more", spot
	end

	-- The first break after a bridge (2026-10-09, the user's ask): an arrow to the Spring, Springtown's pool, which trains
	-- both stats. Once per player: the server saves SpringGuideSeen the first time they stand in it.
	-- The conveyor belts (2026-10-11, the user's ask): once the built bridge is long enough to be worth it, players are
	-- told to ride the belt out when they carry planks and back when they've placed them all, with the arrow pointing at
	-- the belt's lane. Each belt's hint stops after you've ridden it TipRides times (this session).
	local rides = { Out = 0, Back = 0 }
	local riding: string? = nil
	-- `teaching` (2026-10-11, the user's asks): in the tutorial the belt hints always show. "out" in the steps done on the
	-- bridge (Plant, Build): take the belt out, "Ride to the end!" on it. "back" in the steps done at camp (the planks,
	-- the gym, the shop): take the belt back whenever you're out on the bridge, carrying or not.
	local function beltTip(root: BasePart, teaching: ("out" | "back")?): (string?, Vector3?)
		local belts = GameConfig.Grid.Belts
		if not BridgeController.ready() then
			return nil, nil
		end
		local frame = BridgeController.frame()
		local built = (BridgeController.frontRow() - 1) * GameConfig.Grid.SlotStuds
		local q, row = BridgeGrid.fromWorld(root.Position, frame)
		q = BridgeController.laneAt(root.Position) or q -- the belts are wider than their lanes
		local out = -frame:PointToObjectSpace(root.Position).Z -- studs out from the near rim
		-- Count a ride each time you step onto a belt's lane out on the bridge.
		local lane = if out > 20 and out < built
			then (if q == belts.Out then "Out" elseif q == belts.Back then "Back" else nil)
			else nil
		if lane and lane ~= riding then
			rides[lane] += 1
		end
		riding = lane
		local forestState = ReplicatedStorage:FindFirstChild("ForestState")
		local open = forestState and forestState:GetAttribute("OpenRow")
		if built < belts.TipStuds or not (typeof(open) == "Vector2" and open.Y > 0) then -- nothing to build: no hint
			return nil, nil
		end
		local carried = attribute("Carried") or 0
		local back = math.clamp(row, 1, BridgeController.frontRow() - 1)
		if teaching == "back" then
			if out > 150 and q ~= belts.Back then
				return "Take the conveyor belt back!", BridgeGrid.toWorld(belts.Back, back, frame)
			end
			return nil, nil
		end
		local outOk = teaching == "out" or rides.Out < belts.TipRides
		local backOk = teaching == "out" or rides.Back < belts.TipRides
		if teaching == "out" and carried > 0 and out < built - 150 and q == belts.Out then
			return "Ride to the end!", nil
		elseif carried > 0 and out < built - 150 and q ~= belts.Out and outOk then
			return "Take the conveyor belt out!", BridgeGrid.toWorld(belts.Out, math.max(1, row), frame)
		elseif carried == 0 and out > 150 and q ~= belts.Back and backOk then
			return "Take the conveyor belt back!", BridgeGrid.toWorld(belts.Back, back, frame)
		end
		return nil, nil
	end

	local function springGuide(): (string?, Vector3?)
		local forestState = ReplicatedStorage:FindFirstChild("ForestState")
		local spring = forestState and forestState:GetAttribute("SpringMultiplier")
		local center = forestState and (forestState:GetAttribute("SpringCenter") or forestState:GetAttribute("Center"))
		if attribute("SpringGuideSeen") ~= 0 or typeof(spring) ~= "number" or spring <= 0 or typeof(center) ~= "Vector3" then
			return nil, nil
		end
		return `Sit in the Spring: {spring}x Boost!`, center
	end

	while true do
		task.wait(CHECK_SECONDS)
		local giftCoins = GiftsController.unclaimedCoins()
		giftButton.Visible = giftCoins > 0 and not introPlaying
		local coinsLabel = giftButton:FindFirstChild("Coins") :: TextLabel
		coinsLabel.Text = `+{UIStyle.commas(giftCoins)}`
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local text, spot = nil, nil
		if root and root:IsA("BasePart") and not introPlaying then
			text, spot = springGuide()
			local step = attribute("TutorialStep") or 0
			local stepName = GameConfig.Tutorial.Steps[step]
			local teaching: ("out" | "back")? = if stepName == "Plant" or stepName == "Build"
				then "out"
				elseif stepName then "back"
				else nil
			local tip, tipSpot = beltTip(root, teaching) -- run every check, so rides are counted
			if not text and tip and (teaching or step >= GameConfig.Tutorial.DoneStep) then
				text, spot = tip, tipSpot -- before "Press E to build" / "Go build!", and after the tutorial
			end
			if not text then
				text, spot = currentStep(root)
			end
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
