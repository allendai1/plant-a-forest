--!strict
-- PromptController: draws every ProximityPrompt set to Style Custom (the acorn piles and benches; set
-- by tools/build_map.luau), after Build the Pyramid's (docs/plans/GUI.md): a dark rounded panel with a
-- gold edge, the key in a dark square, the object's name big and the action under it in grey.
-- Keyboard shows the prompt's key, gamepad its button, and on touch screens the whole panel is the
-- button (pressing and holding it holds the prompt, so holding at a pile keeps grabbing).
-- The acorn piles' "Pick Up" prompt sits at the bottom middle of the screen instead of on the pile, and
-- can be clicked or tapped (held to keep grabbing) as well as E. It pops with a sound on every pickup.

local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Sounds = require(script.Parent.Parent.Sounds)
local UIStyle = require(script.Parent.Parent.UIStyle)

local WIDTH = 420 -- room for the panel, which sizes to its text and stays centered
local HEIGHT = 100 -- 86 until 2026-10-08 (the user wanted more room above and below the key and text)
local PULSE_SECONDS = 1.2 -- the pick-up prompt's glow: dark to its brightest, then back over the same time
local PULSE_COLOR = Color3.fromRGB(150, 120, 70) -- its brightest (times the yellow gradient)
local KEY_SIZE = 62
local SCREEN_Y = 0.86 -- the pile prompt's bottom edge, as a fraction of the screen height
local SCREEN_Y_TOUCH = 0.7 -- phones: above the Forest Bar, which sits at the bottom there
local PICKUP_POP = 1.25 -- the pile prompt bumps to this size on each pickup
local PICKUP_SOUND_ID = "rbxassetid://140323850218372" -- Creator Store "Pop Sound Effect", 0.2 s, free
local PICKUP_VOLUME = 0.175 -- halved, then 30% lower (the user, 2026-10-08): it lands on the acorn merges and read as too loud
local PICKUP_PITCH_FROM, PICKUP_PITCH_STEP, PICKUP_PITCH_MAX = 1, 0.025, 1.4 -- rises over a run of grabs
local PICKUP_RUN_SECONDS = 0.8 -- grabs closer together than this count as one run

local PromptController = {}

local localPlayer = Players.LocalPlayer
local pickupPop: UIScale? = nil -- the shown pile prompt's scale, while one is shown
local pickupScale = 1
local pickupSound: Sound
local lastPickup = 0
local pickupPitch = PICKUP_PITCH_FROM

-- Is this the prompt of an acorn pile (a SeedRack)?
local function isPile(prompt: ProximityPrompt): boolean
	local model = prompt:FindFirstAncestorWhichIsA("Model")
	while model do
		if CollectionService:HasTag(model, "SeedRack") then
			return true
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return false
end

-- One pickup: the pile prompt bumps and pops, a little higher in pitch through a run of grabs.
local function onPickup()
	local pop = pickupPop
	if not pop then
		return
	end
	pop.Scale = pickupScale * PICKUP_POP
	TweenService:Create(pop, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = pickupScale }):Play()
	local now = os.clock()
	pickupPitch = if now - lastPickup < PICKUP_RUN_SECONDS
		then math.min(pickupPitch + PICKUP_PITCH_STEP, PICKUP_PITCH_MAX)
		else PICKUP_PITCH_FROM
	lastPickup = now
	local sound = pickupSound:Clone()
	sound.PlaybackSpeed = pickupPitch
	sound.Parent = SoundService -- not in a part, so it plays at full volume
	sound:Play()
	task.delay(1, sound.Destroy, sound)
end

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		return (prompt.GamepadKeyCode.Name:gsub("^Button", ""))
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	end
	local text = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	return if text ~= "" then text:upper() else prompt.KeyboardKeyCode.Name
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	local scale = UIStyle.screenScale() -- smaller on phones, like the HUD
	local onScreen = isPile(prompt)
	local gui: LayerCollector
	local holder: Instance
	if onScreen then
		local screen = Instance.new("ScreenGui")
		screen.Name = "PickUpPrompt"
		screen.ResetOnSpawn = false
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 1)
		frame.Position = UDim2.fromScale(0.5, if UIStyle.isTouch() then SCREEN_Y_TOUCH else SCREEN_Y)
		frame.Size = UDim2.fromOffset(WIDTH * scale, HEIGHT * scale)
		frame.BackgroundTransparency = 1
		frame.Parent = screen
		gui, holder = screen, frame
	else
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "Prompt"
		billboard.AlwaysOnTop = true
		billboard.Active = true
		billboard.Size = UDim2.fromOffset(WIDTH * scale, HEIGHT * scale)
		billboard.SizeOffset = Vector2.new(prompt.UIOffset.X / WIDTH, prompt.UIOffset.Y / HEIGHT)
		billboard.Adornee = prompt.Parent :: any
		gui, holder = billboard, billboard
	end

	local panel = Instance.new("TextButton")
	panel.Text = ""
	panel.AutoButtonColor = false
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(0, HEIGHT)
	panel.AutomaticSize = Enum.AutomaticSize.X
	panel.BackgroundColor3 = Color3.fromRGB(28, 22, 16)
	panel.BackgroundTransparency = 0.2
	panel.Parent = holder
	UIStyle.corner(panel, HEIGHT // 2 - 8)
	UIStyle.stroke(panel, 3, UIStyle.BLACK, true) -- black like the windows (was gold)
	if onScreen then
		-- The pick-up prompt glows: its dark background pulses slowly into a yellow-to-orange gradient and back
		-- (the user's ask, 2026-10-07). The gradient tints only the panel, not the text on it.
		local glow = Instance.new("UIGradient")
		glow.Color = ColorSequence.new(Color3.fromRGB(255, 235, 120), Color3.fromRGB(255, 160, 40))
		glow.Rotation = 90
		glow.Parent = panel
		TweenService:Create(
			panel,
			TweenInfo.new(PULSE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ BackgroundColor3 = PULSE_COLOR }
		):Play()
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 42), UDim.new(0, 42) -- 42 px each side (were 10/24, then 30; the user's asks 2026-10-07 and -08)
	pad.Parent = panel
	UIStyle.list(panel, true, 14)

	local key = Instance.new("Frame")
	key.Size = UDim2.fromOffset(KEY_SIZE, KEY_SIZE)
	key.BackgroundColor3 = Color3.fromRGB(12, 10, 8)
	key.ClipsDescendants = true
	key.Parent = panel
	UIStyle.corner(key, 12)
	local hold = Instance.new("Frame") -- fills up while a hold-duration prompt is held
	hold.AnchorPoint = Vector2.new(0, 1)
	hold.Position = UDim2.fromScale(0, 1)
	hold.Size = UDim2.fromScale(1, 0)
	hold.BackgroundColor3 = UIStyle.GOLD
	hold.BackgroundTransparency = 0.4
	hold.BorderSizePixel = 0
	hold.Parent = key
	local letter = keyText(prompt, inputType)
	local keyLabel = UIStyle.text(key, letter, if #letter > 2 then 20 else 38)
	keyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	keyLabel.Position = UDim2.fromScale(0.5, 0.5)
	keyLabel.ZIndex = 2

	local words = Instance.new("Frame")
	words.LayoutOrder = 2
	words.BackgroundTransparency = 1
	words.AutomaticSize = Enum.AutomaticSize.XY
	words.Parent = panel
	UIStyle.list(words, false, 0)
	local object = UIStyle.text(words, prompt.ObjectText, 36)
	object.LayoutOrder = 1
	object.Visible = prompt.ObjectText ~= ""
	local action = UIStyle.text(words, prompt.ActionText, 28, UIStyle.GREY)
	action.LayoutOrder = 2
	-- A prompt with only an action ("Pick Up Seeds", "Buy") shows it as one white line (2026-10-07).
	local function styleAction()
		local alone = prompt.ObjectText == ""
		action.TextColor3 = if alone then UIStyle.WHITE else UIStyle.GREY
		action.TextSize = if alone then 32 else 28
	end
	styleAction()

	local connections: { RBXScriptConnection } = {}
	local holdTween: Tween? = nil
	table.insert(
		connections,
		prompt.PromptButtonHoldBegan:Connect(function()
			if prompt.HoldDuration > 0 then
				holdTween = TweenService:Create(hold, TweenInfo.new(prompt.HoldDuration), { Size = UDim2.fromScale(1, 1) });
				(holdTween :: Tween):Play()
			end
		end)
	)
	table.insert(
		connections,
		prompt.PromptButtonHoldEnded:Connect(function()
			if holdTween then
				holdTween:Cancel()
			end
			hold.Size = UDim2.fromScale(1, 0)
		end)
	)
	table.insert(
		connections,
		prompt.Changed:Connect(function()
			object.Text, action.Text = prompt.ObjectText, prompt.ActionText
			object.Visible = prompt.ObjectText ~= ""
			styleAction()
		end)
	)
	if onScreen or inputType == Enum.ProximityPromptInputType.Touch then -- the pile prompt is clickable too
		local held = false
		panel.InputBegan:Connect(function(input)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1 then
				held = true
				prompt:InputHoldBegin()
			end
		end)
		panel.InputEnded:Connect(function(input)
			local kind = input.UserInputType
			if held and (kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1) then
				held = false
				prompt:InputHoldEnd()
			end
		end)
	end

	local pop = Instance.new("UIScale")
	pop.Parent = panel
	pop.Scale = 0.7 * scale
	TweenService:Create(pop, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = scale }):Play()
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	if onScreen then
		pickupPop, pickupScale = pop, scale
	end

	prompt.PromptHidden:Once(function()
		for _, connection in connections do
			connection:Disconnect()
		end
		if pickupPop == pop then
			pickupPop = nil
		end
		gui:Destroy()
	end)
end

function PromptController.start()
	pickupSound = Instance.new("Sound")
	pickupSound.SoundId = PICKUP_SOUND_ID
	pickupSound.Volume = PICKUP_VOLUME
	pickupSound.SoundGroup = Sounds.effects()
	local carried = localPlayer:GetAttribute("Carried")
	localPlayer:GetAttributeChangedSignal("Carried"):Connect(function()
		local now = localPlayer:GetAttribute("Carried")
		if typeof(now) == "number" and typeof(carried) == "number" and now > carried then
			onPickup()
		end
		carried = now
	end)
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			show(prompt, inputType)
		end
	end)
end

return PromptController
