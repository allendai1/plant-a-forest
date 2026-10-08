--!strict
-- SettingsController: the Settings panel, opened by the HUD's Settings button (toggle) or the button under
-- the Speed stat (open). Both settings are saved by the server, and the panel follows their attributes.
-- Walk speed limit: a slider (base speed to your own; the right end = no limit) or typing a number in the box set
-- the player's own limit (SetWalkCap; the server clamps and saves it as WalkCap, 0 = no limit). Moved here from
-- under the Speed stat (2026-10-07); the box since the same day; the slider replaced - / + / MAX on 2026-10-08.
-- Guide arrow: shows or hides the arrow that leads to the nearest open plot, and the tutorial's.
-- Music and Sound effects (polish pass): mute the Music or Effects SoundGroup (Sounds).
-- The three toggles are saved through SetSetting (the GuideArrow / Music / Effects attributes: 1 on, 0 off).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(script.Parent.Parent.Sounds)
local UIStyle = require(script.Parent.Parent.UIStyle)

local SettingsController = {}

local SLIDER_COLOR = Color3.fromHex("#50b4ff") -- the Speed stat's blue
local localPlayer = Players.LocalPlayer
local gui: ScreenGui? = nil

local function attribute(name: string): number
	local value = localPlayer:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function isOn(name: string): boolean
	return localPlayer:GetAttribute(name) ~= 0 -- not loaded yet counts as on
end

function SettingsController.toggle()
	if gui then
		gui.Enabled = not gui.Enabled
	end
end

function SettingsController.open()
	if gui then
		gui.Enabled = true
	end
end

-- One setting: a name, a grey line under it, and its controls on the right.
local function settingRow(panel: Frame, order: number, title: string, detail: string): (Frame, TextLabel)
	local row = Instance.new("Frame")
	row.Name = (title:gsub(" ", ""))
	row.Size = UDim2.new(1, 0, 0, 64)
	UIStyle.glow(row, UIStyle.CARD_EDGE, UIStyle.CARD_MIDDLE) -- the shop cards' look
	row.LayoutOrder = order
	row.Parent = panel
	UIStyle.corner(row, 12)
	UIStyle.stroke(row, 2, nil, true)
	local name = UIStyle.text(row, title, 28)
	name.Position = UDim2.fromOffset(14, 6)
	local line = UIStyle.text(row, detail, 16, UIStyle.GREY)
	line.Position = UDim2.fromOffset(14, 38)
	return row, line
end

local function rightButton(row: Frame, text: string, colors: { Color3 }, width: number, offset: number): TextButton
	local button = UIStyle.button(row, text, colors, UDim2.fromOffset(width, 44), if #text > 2 then 22 else 28)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -offset, 0.5, 0)
	return button
end

local function buildWalkSpeed(panel: Frame): () -> ()
	local base = GameConfig.Stats.WalkSpeed.Base
	local row, line = settingRow(panel, 2, "Speed limit", "")
	row.Size = UDim2.new(1, 0, 0, 108)
	local function earned(): number
		return math.round(GameConfig.walkSpeed(attribute("Speed")))
	end
	local function current(): number
		local cap = attribute("WalkCap")
		return if cap > 0 then math.min(cap, earned()) else earned()
	end
	local function send(cap: number)
		Remotes.event("SetWalkCap"):FireServer(if cap >= earned() then 0 else cap)
	end
	-- Type a speed: anything from the base walk speed up (over your own speed means no limit).
	local box = Instance.new("TextBox")
	box.Name = "WalkBox"
	box.AnchorPoint = Vector2.new(1, 0)
	box.Position = UDim2.new(1, -10, 0, 10)
	box.Size = UDim2.fromOffset(84, 44)
	box.BackgroundColor3 = Color3.fromRGB(20, 16, 12)
	box.Font = UIStyle.FONT
	box.TextSize = 22
	box.TextColor3 = UIStyle.WHITE
	box.ClearTextOnFocus = true
	box.Parent = row
	UIStyle.corner(box, 8)
	UIStyle.stroke(box, 2, nil, true)

	-- Or drag: the slider runs from the base walk speed (left) to your own speed (right end = no limit). The
	-- limit is sent when you let go, so dragging doesn't spam SetWalkCap (2026-10-08, the user's request).
	local track = Instance.new("Frame")
	track.Name = "WalkSlider"
	track.Position = UDim2.fromOffset(24, 78)
	track.Size = UDim2.new(1, -48, 0, 12)
	track.BackgroundColor3 = Color3.fromRGB(20, 16, 12)
	track.Parent = row
	UIStyle.corner(track, 6)
	UIStyle.stroke(track, 2, nil, true)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = SLIDER_COLOR
	fill.Parent = track
	UIStyle.corner(fill, 6)
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(28, 28)
	knob.BackgroundColor3 = UIStyle.WHITE
	knob.ZIndex = 2
	knob.Parent = track
	local roundKnob = Instance.new("UICorner")
	roundKnob.CornerRadius = UDim.new(0.5, 0) -- a full circle (UIStyle.corner rounds less)
	roundKnob.Parent = knob
	UIStyle.stroke(knob, 3, nil, true)
	-- A taller invisible button over the track, so the knob is easy to grab (and it sinks the touch).
	local grab = Instance.new("TextButton")
	grab.Name = "Grab"
	grab.Text = ""
	grab.AutoButtonColor = false
	grab.BackgroundTransparency = 1
	grab.AnchorPoint = Vector2.new(0, 0.5)
	grab.Position = UDim2.new(0, -14, 0.5, 0)
	grab.Size = UDim2.new(1, 28, 0, 40)
	grab.ZIndex = 3
	grab.Parent = track

	local dragged: number? = nil -- the speed under your finger while dragging
	local function show(speed: number)
		local span = earned() - base
		local fraction = if span > 0 then math.clamp((speed - base) / span, 0, 1) else 1
		fill.Size = UDim2.fromScale(fraction, 1)
		knob.Position = UDim2.fromScale(fraction, 0.5)
		if not box:IsFocused() then
			box.Text = tostring(speed)
		end
	end
	local function refresh()
		local capped = attribute("WalkCap") > 0 and current() < earned()
		line.Text = if capped then `{current()} of your {earned()}` else `No limit: {earned()}`
		show(dragged or current())
	end
	local function dragTo(x: number)
		local fraction = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		dragged = math.round(base + fraction * math.max(earned() - base, 0))
		show(dragged :: number)
	end
	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	grab.InputBegan:Connect(function(input)
		if isPress(input) then
			dragTo(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragged
			and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)
		then
			dragTo(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragged and isPress(input) then
			send(dragged :: number)
			dragged = nil
		end
	end)
	box.FocusLost:Connect(function()
		local typed = tonumber(box.Text)
		if typed and typed == typed then -- not NaN
			send(math.clamp(math.round(typed), base, GameConfig.WalkCap.Max))
		end
		refresh() -- a bad entry goes back to the current speed
	end)
	return refresh
end

-- An ON / OFF setting saved as the attribute `name`.
local function buildToggle(panel: Frame, order: number, name: string, title: string, detail: string): () -> ()
	local row = settingRow(panel, order, title, detail)
	local switch = rightButton(row, "", UIStyle.Colors.Green, 100, 10)
	switch.Name = name
	switch.Activated:Connect(function()
		Remotes.event("SetSetting"):FireServer(name, not isOn(name))
	end)
	local function refresh()
		local on = isOn(name)
		switch.Text = if on then "ON" else "OFF"
		UIStyle.recolor(switch, if on then UIStyle.Colors.Green else UIStyle.Colors.Grey)
	end
	localPlayer:GetAttributeChangedSignal(name):Connect(refresh)
	refresh()
	return refresh
end

-- The sound toggles act on their SoundGroup.
local function applySound()
	Sounds.music().Volume = if isOn("Music") then 1 else 0
	Sounds.effects().Volume = if isOn("Effects") then 1 else 0
end

function SettingsController.start()
	local screen = Instance.new("ScreenGui")
	screen.Name = "Settings"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	UIStyle.blurBehind(screen) -- the game blurs behind the window, like the upgrade shop
	screen.DisplayOrder = 2 -- over the HUD
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- the close button's text draws over the button
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(500, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.Parent = screen
	UIStyle.autoScale(holder)
	local panel = UIStyle.panel(holder)
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	UIStyle.padding(panel, 18)
	UIStyle.list(panel, false, 14)
	UIStyle.text(panel, "Settings", 44, UIStyle.GOLD).LayoutOrder = 1
	UIStyle.closeButton(holder, SettingsController.toggle)

	local refreshWalk = buildWalkSpeed(panel)
	buildToggle(panel, 3, "GuideArrow", "Guide arrow", "Points to the nearest open plot")
	buildToggle(panel, 4, "Music", "Music", "Background music")
	buildToggle(panel, 5, "Effects", "Sound effects", "Clicks, coins, footsteps and more")
	for _, name in { "Speed", "WalkCap" } do
		localPlayer:GetAttributeChangedSignal(name):Connect(refreshWalk)
	end
	refreshWalk()
	for _, name in { "Music", "Effects" } do
		localPlayer:GetAttributeChangedSignal(name):Connect(applySound)
	end
	applySound()

	screen.Parent = localPlayer:WaitForChild("PlayerGui")
	gui = screen
end

return SettingsController
