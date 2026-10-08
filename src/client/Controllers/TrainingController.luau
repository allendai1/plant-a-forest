--!strict
-- TrainingController: the client side of the training stations (docs/plans/M2b.md).
-- Shows one player per bench (you if you're on it, otherwise whoever got on first) by hiding the
-- others locally, poses whoever is shown on each bench (lying back, pressing the bar, faster with more
-- Strength), leaves the bench when you jump, plays the run animation while the server says you're on
-- a treadmill (faster with more Speed), and shows the locked-station popup.
-- The server decides everything that matters; this only renders it.

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)
local UIStyle = require(script.Parent.Parent.UIStyle)

local BENCH_TAG = "BenchStation"
local JUMP_DEBOUNCE = 0.5
-- Animation tempo (looks only): presses per second grow with log10(Strength), from PRESS_MIN up to
-- PRESS_MAX; the run animation plays at your walk speed over RUN_ANIM_STUDS (Roblox's run is made for 16).
-- Comically fast on purpose (the user's call, 2026-10-08; was 0.7 to 2.5, maxed at 1M Strength): 0 -> 1.5,
-- 100 -> 3.5, 10K -> 5.5, 1M -> 7.5, 100M -> 9.5, maxed from about 300M.
local PRESS_MIN, PRESS_PER_DECADE, PRESS_MAX = 1.5, 1.0, 10
local RUN_ANIM_STUDS = 24
local RUN_ANIM_MAX = 3 -- the treadmill run animation's fastest playback (walk speeds now go past 160)
local LIE_LIFT = 0.3 -- raises the lying body so its back rests on the bench top
local SIDES: { { name: string, sign: number } } = { { name = "Left", sign = -1 }, { name = "Right", sign = 1 } }

-- Only the model is kept. With StreamingEnabled the bench's parts (bar, prompt holder) can be unloaded
-- and recreated as new objects, so they're looked up again every time. The bar is moved only here
-- (locally), so a bar that streams back in arrives at rest.
type Bench = { model: Model, occupant: Player?, phase: number, bar: BasePart?, rest: CFrame? }

local TrainingController = {}

local localPlayer = Players.LocalPlayer
local benches: { [string]: Bench } = {}
local hidden: { [Player]: boolean } = {}
local runTrack: AnimationTrack? = nil

local function benchingOf(player: Player): string?
	local name = player:GetAttribute("Benching")
	return if typeof(name) == "string" and name ~= "" then name else nil
end

local function benchedAt(player: Player): number
	local t = player:GetAttribute("BenchedAt")
	return if typeof(t) == "number" then t else math.huge
end

local function setHidden(player: Player, hide: boolean)
	local character = player.Character
	if not character then
		return
	end
	local modifier = if hide then 1 else 0
	for _, item in character:GetDescendants() do
		-- selene: allow(if_same_then_else) -- separate branches keep each type narrowed for luau-lsp
		if item:IsA("BasePart") then
			item.LocalTransparencyModifier = modifier
		elseif item:IsA("Decal") then
			item.LocalTransparencyModifier = modifier
		end
	end
	-- Roblox's name tag stays off (NameplateController draws [rank] [name]); the nameplate hides with the character.
	player:SetAttribute("NameplateHidden", hide)
	hidden[player] = hide
end

-- The bench's bar, noting where it rests whenever a fresh one appears (first sight or streamed back in).
local function barOf(bench: Bench): BasePart?
	local found = bench.model:FindFirstChild("Bar")
	if not (found and found:IsA("BasePart")) then
		return nil
	end
	if found ~= bench.bar then
		bench.bar, bench.rest = found, found.CFrame
	end
	return found
end

local function setJoint(character: Model, partName: string, jointName: string, transform: CFrame)
	local part = character:FindFirstChild(partName)
	local joint = part and part:FindFirstChild(jointName)
	-- Newer avatars use AnimationConstraint joints, older ones Motor6D; both take a Transform.
	-- selene: allow(if_same_then_else) -- separate branches keep each type narrowed for luau-lsp
	if joint and joint:IsA("AnimationConstraint") then
		joint.Transform = transform
	elseif joint and joint:IsA("Motor6D") then
		joint.Transform = transform
	end
end

-- Lying on the back with the legs straight, pressing: at press 0 the upper arms are out to the sides
-- with the forearms straight up (bar at the chest), at 1 both arms are locked out above the shoulders.
-- Set every frame after the Animator, so it replaces the sit animation (R15 only).
local function poseBench(character: Model, press: number)
	setJoint(character, "LowerTorso", "Root", CFrame.new(0, LIE_LIFT, 0) * CFrame.Angles(math.rad(90), 0, 0))
	for _, side in SIDES do
		local name, sign = side.name, side.sign
		setJoint(character, `{name}UpperLeg`, `{name}Hip`, CFrame.identity)
		setJoint(character, `{name}LowerLeg`, `{name}Knee`, CFrame.identity)
		local out = CFrame.Angles(0, 0, sign * math.rad(90) * (1 - press))
		setJoint(character, `{name}UpperArm`, `{name}Shoulder`, out * CFrame.Angles(math.rad(90) * press, 0, 0))
		setJoint(character, `{name}LowerArm`, `{name}Elbow`, CFrame.Angles(math.rad(90) * (1 - press), 0, 0))
	end
end

local function pressesPerSecond(player: Player): number
	local strength = player:GetAttribute("Strength")
	local value = if typeof(strength) == "number" then math.max(strength, 0) else 0
	return math.min(PRESS_MIN + PRESS_PER_DECADE * math.log10(1 + value), PRESS_MAX)
end

-- Every frame: pose each bench's shown occupant and keep its bar in their hands.
local function stepBenches(dt: number)
	for _, bench in benches do
		local bar = barOf(bench)
		local player = bench.occupant
		local character = player and player.Character
		if player and character then
			bench.phase = (bench.phase + dt * pressesPerSecond(player)) % 1
			poseBench(character, (1 - math.cos(bench.phase * 2 * math.pi)) / 2)
			local left, right = character:FindFirstChild("LeftHand"), character:FindFirstChild("RightHand")
			if bar and bench.rest and left and right and left:IsA("BasePart") and right:IsA("BasePart") then
				local handsY = (left.Position.Y + right.Position.Y) / 2
				bar.CFrame = bench.rest + Vector3.new(0, handsY - bench.rest.Position.Y, 0)
			end
		elseif bar and bench.rest and bar.CFrame ~= bench.rest then
			bar.CFrame = bench.rest -- back on the rack
		end
	end
end

-- Who is shown on each bench: the local player if they're on it, otherwise the earliest to sit down.
local function refreshBenches()
	local mine = benchingOf(localPlayer)
	local shown: { [string]: Player } = {}
	if mine then
		shown[mine] = localPlayer
	end
	for _, player in Players:GetPlayers() do
		local name = benchingOf(player)
		if name then
			local current: Player? = shown[name]
			if current == nil or (current ~= localPlayer and benchedAt(player) < benchedAt(current)) then
				shown[name] = player
			end
		end
	end
	for _, player in Players:GetPlayers() do
		if player ~= localPlayer then
			local name = benchingOf(player)
			local hide = false
			if name then
				local visible: Player? = shown[name]
				hide = visible ~= player
			end
			if hide ~= (hidden[player] == true) then
				setHidden(player, hide)
			end
		end
	end
	for name, bench in benches do
		bench.occupant = shown[name]
		local prompt = bench.model:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.Enabled = mine == nil -- no "Bench Press [E]" while already benching
		end
	end
end

local function addBench(model: Instance)
	if not model:IsA("Model") then
		return
	end
	benches[model.Name] = { model = model, occupant = nil, phase = 0, bar = nil, rest = nil }
	-- Parts streaming back in arrive fresh (prompt enabled, bar at rest), so re-apply the current state.
	model.DescendantAdded:Connect(function(item)
		if item:IsA("ProximityPrompt") or item.Name == "Bar" then
			task.defer(refreshBenches)
		end
	end)
	refreshBenches()
end

local function removeBench(model: Instance)
	benches[model.Name] = nil
end

local function watchPlayer(player: Player)
	player:GetAttributeChangedSignal("Benching"):Connect(refreshBenches)
	player.CharacterAdded:Connect(function()
		hidden[player] = nil -- a new character starts visible
		task.defer(refreshBenches)
	end)
end

local function runSpeed(): number
	local speed = localPlayer:GetAttribute("Speed")
	local walk = GameConfig.walkSpeed(if typeof(speed) == "number" then speed else 0)
	local cap = localPlayer:GetAttribute("WalkCap")
	if typeof(cap) == "number" and cap > 0 then
		walk = math.min(walk, cap)
	end
	return math.min(walk / RUN_ANIM_STUDS, RUN_ANIM_MAX) -- legs stop speeding up past this
end

-- Plays the character's own run animation in place while the server says it's on a treadmill, faster
-- the more Speed you have. Played on your own character, so other players see it too.
local function setRunning(on: boolean)
	if not on then
		if runTrack then
			runTrack:Stop()
			runTrack = nil
		end
		return
	end
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local animate = character and character:FindFirstChild("Animate")
	local run = animate and animate:FindFirstChild("run")
	local animation = run and run:FindFirstChildOfClass("Animation")
	if animator and animation and not runTrack then
		local track = animator:LoadAnimation(animation)
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Movement
		track:Play()
		track:AdjustSpeed(runSpeed())
		runTrack = track
	end
end

-- The locked-station popup: the requirement, plus an unlock button once that tier's pass exists.
local popup: Frame? = nil
local popupTitle: TextLabel? = nil
local popupBody: TextLabel? = nil
local buyButton: TextButton? = nil
local popupPassId = 0

local function buildPopup()
	local gui = Instance.new("ScreenGui")
	gui.Name = "StationLocked"
	gui.ResetOnSpawn = false
	gui.Enabled = true
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(440, 250)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	UIStyle.autoScale(holder)
	local frame = UIStyle.panel(holder)
	frame.Size = UDim2.fromScale(1, 1)
	local function text(name: string, y: number, size: number, color: Color3?): TextLabel
		local label = UIStyle.text(frame, "", size, color)
		label.Name = name
		label.AutomaticSize = Enum.AutomaticSize.None
		label.Position = UDim2.fromOffset(20, y)
		label.Size = UDim2.new(1, -40, 0, size * 2.2)
		label.TextWrapped = true
		return label
	end
	local title = text("Title", 16, 36, UIStyle.GOLD)
	title.Size = UDim2.new(1, -40, 0, 40)
	popupTitle = title
	popupBody = text("Body", 66, 24)
	local buy = UIStyle.button(frame, "", UIStyle.Colors.Green, UDim2.fromOffset(280, 54), 28)
	buy.Name = "Buy"
	buy.AnchorPoint = Vector2.new(0.5, 1)
	buy.Position = UDim2.new(0.5, 0, 1, -20)
	buy.Activated:Connect(function()
		if popupPassId ~= 0 then
			MarketplaceService:PromptGamePassPurchase(localPlayer, popupPassId)
		end
	end)
	local close = UIStyle.button(frame, "X", UIStyle.Colors.Red, UDim2.fromOffset(44, 44), 26)
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Activated:Connect(function()
		holder.Visible = false
	end)
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	popup, buyButton = holder, buy
end

local function showLocked(multiplier: number, forestsNeeded: number?)
	if not popup then
		buildPopup()
	end
	local frame, title, body, buy = popup, popupTitle, popupBody, buyButton
	if not (frame and title and body and buy) then
		return
	end
	local needed = forestsNeeded or 0
	title.Text = `{multiplier}x station locked`
	body.Text = `Complete {needed} {if needed == 1 then "forest" else "forests"} to unlock it, or unlock it now.`
	popupPassId = GameConfig.StationPasses[multiplier] or 0
	if popupPassId == 0 then
		buy.Text = "Coming soon"
		buy.AutoButtonColor = false
		UIStyle.recolor(buy, UIStyle.Colors.Grey)
	else
		local passId = popupPassId
		local function label()
			if popupPassId == passId then
				buy.Text = `Unlock  {UIStyle.priceText(passId, Enum.InfoType.GamePass, label)}`
			end
		end
		label()
		buy.AutoButtonColor = true
		UIStyle.recolor(buy, UIStyle.Colors.Green)
	end
	frame.Visible = true
end

function TrainingController.start()
	for _, bench in CollectionService:GetTagged(BENCH_TAG) do
		addBench(bench)
	end
	CollectionService:GetInstanceAddedSignal(BENCH_TAG):Connect(addBench)
	CollectionService:GetInstanceRemovedSignal(BENCH_TAG):Connect(removeBench)

	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player)
		hidden[player] = nil
		task.defer(refreshBenches)
	end)

	local leaveBench = Remotes.event("LeaveBench")
	local lastJump = 0
	UserInputService.JumpRequest:Connect(function() -- keyboard, gamepad and the mobile jump button
		if benchingOf(localPlayer) and os.clock() - lastJump > JUMP_DEBOUNCE then
			lastJump = os.clock()
			leaveBench:FireServer()
		end
	end)

	localPlayer:GetAttributeChangedSignal("Running"):Connect(function()
		setRunning(localPlayer:GetAttribute("Running") == true)
	end)
	localPlayer:GetAttributeChangedSignal("Speed"):Connect(function()
		if runTrack then
			runTrack:AdjustSpeed(runSpeed())
		end
	end)
	-- After the Animator has posed everyone this frame, so the bench pose wins over the sit animation.
	RunService.Stepped:Connect(function(_, dt)
		stepBenches(dt)
	end)
	localPlayer.CharacterAdded:Connect(function()
		runTrack = nil
	end)

	Remotes.event("StationLocked").OnClientEvent:Connect(showLocked)
	refreshBenches()
end

return TrainingController
