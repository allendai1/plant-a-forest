--!strict
-- UIStyle: the shared look of every screen (docs/plans/GUI.md), after Build the Pyramid's HUD:
-- Gotham Black, white text with a thick black outline and a dark drop shadow (dropShadow), dark-bordered
-- gradient buttons, and one size scale for the whole screen so phones get the same layout, smaller.
-- Icons: put an uploaded image id in Image (e.g. "rbxassetid://123"); until then the emoji shows.
-- Polish pass (2026-10-07): every button clicks (Sounds) and squashes when pressed (clicky), deny() shakes a
-- button with the error sound, flash() lights up a card after a purchase, closeButton() is the shared red X,
-- card() the shared shop card, short() writes big numbers as 1.2K / 3.4M.

local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Sounds = require(script.Parent.Sounds)

local UIStyle = {}

UIStyle.FONT = Enum.Font.GothamBlack -- the closest Roblox font to the pyramid's
UIStyle.ROBUX = utf8.char(0xE002) -- Roblox fonts draw this as the Robux icon
UIStyle.WHITE = Color3.new(1, 1, 1)
UIStyle.BLACK = Color3.new(0, 0, 0)
UIStyle.PANEL = Color3.fromRGB(38, 30, 24)
UIStyle.GOLD = Color3.fromRGB(225, 180, 110)
UIStyle.GREY = Color3.fromRGB(200, 200, 200)
UIStyle.PRICE = Color3.fromRGB(110, 255, 90)
UIStyle.CARD = Color3.fromRGB(60, 48, 38)
-- Build the Pyramid's window look (2026-10-07): lighter in the middle, darker toward the left and right edges.
UIStyle.CARD_EDGE = Color3.fromRGB(112, 82, 48) -- the shop cards: tan/gold
UIStyle.CARD_MIDDLE = Color3.fromRGB(200, 160, 102)
UIStyle.PANEL_EDGE = Color3.fromRGB(32, 27, 23) -- the windows behind them: dark brown-grey
UIStyle.PANEL_MIDDLE = Color3.fromRGB(84, 72, 60)

-- Top and bottom colors of the gradient buttons.
UIStyle.Colors = {
	Green = { Color3.fromRGB(150, 240, 70), Color3.fromRGB(60, 175, 30) },
	Orange = { Color3.fromRGB(255, 165, 60), Color3.fromRGB(225, 85, 20) },
	Red = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(195, 20, 25) },
	Purple = { Color3.fromRGB(175, 90, 255), Color3.fromRGB(95, 25, 210) },
	Blue = { Color3.fromRGB(90, 190, 255), Color3.fromRGB(30, 110, 220) },
	Gold = { Color3.fromRGB(255, 220, 110), Color3.fromRGB(215, 145, 35) },
	Grey = { Color3.fromRGB(150, 150, 150), Color3.fromRGB(90, 90, 90) },
	Teal = { Color3.fromRGB(90, 230, 210), Color3.fromRGB(30, 150, 150) },
}

export type Icon = { Image: string, Emoji: string }

-- Placeholder icons: send the asset ids and set Image.
UIStyle.Icons = {
	AutoBuild = { Image = "rbxassetid://95722617073124", Emoji = "🤖" }, -- BuilderBot's head over a plank (decal 108593281806783)
	LuckyPlanks = { Image = "rbxassetid://72208787359977", Emoji = "🍀" }, -- a plank with a four-leaf clover (decal 103889402964053)
	Coins = { Image = "rbxassetid://120701548196867", Emoji = "💰" }, -- the user's coin since 2026-10-10 (was 98949249976360)
	Speed = { Image = "rbxassetid://111362551254873", Emoji = "⚡" },
	Strength = { Image = "rbxassetid://128313204943236", Emoji = "💪" },
	Forests = { Image = "rbxassetid://81841018627713", Emoji = "🌉" }, -- bridges built: the user's bridge icon (2026-10-10; was the forest icon 82377814437587)
	Friends = { Image = "rbxassetid://15403044988", Emoji = "👥" }, -- the user's pick: Creator Store decal 15403045010
	Shop = { Image = "rbxassetid://120542083299834", Emoji = "🛒" }, -- the user's "Red Shopping Cart" (was a basket)
	ServerBoost = { Image = "rbxassetid://72382428722597", Emoji = "🚀" }, -- a cartoon rocket (decal 116170853967272)
	Settings = { Image = "rbxassetid://77572487902863", Emoji = "⚙️" }, -- the user's "Settings White" (was 80167634570686)
	Codes = { Image = "", Emoji = "🎟️" },
	-- The free gift's box (the user's pick, Creator Store decal 15403372742, GiftsController), also the Daily button's.
	Gift = { Image = "rbxthumb://type=Asset&id=15403372742&w=420&h=420", Emoji = "🎁" },
	Ranger = { Image = "", Emoji = "👷" }, -- the character pass's card (Builderman since 2026-10-10; was the Ranger's 🤠)
	Lord = { Image = "", Emoji = "🔨" }, -- the 2nd pass's card: the God of Hammers since 2026-10-11 (was 👑)
	-- Planks since 2026-10-11 (the user's ask; tools/make_ui_icons.py shop_icons, decals 98337605399520 /
	-- 95487894154939 / 87134502879825). They were the user's acorn picks 120369441988104 / 140485439494131 /
	-- 134531632884543.
	BulkPickup = { Image = "rbxassetid://125636553906762", Emoji = "🪵" }, -- a stack of planks
	BulkPlant = { Image = "rbxassetid://139565934880563", Emoji = "🔨" }, -- a laid deck
	PlantingRange = { Image = "rbxassetid://135184821949647", Emoji = "🎯" }, -- a plank on a ring
	Restock = { Image = "", Emoji = "⏰" },
	Trophy = { Image = "", Emoji = "🏆" },
} :: { [string]: Icon }

local SHADOW_DROP = 0.1 -- how far the shadow sits below the text, as a fraction of the text size (0.14 until 2026-10-07: too thick)
UIStyle.THIN_DROP = 0.07 -- a lighter shadow: the Forest Bar number and the map's signs (the user's request)
local SHADOW_TRANSPARENCY = 0.2
-- Outline of TextScaled labels (StrokeSizingMode ScaledSize): 0.05 since 2026-10-11 (the user, next to Build the
-- Pyramid's UPGRADES sign: 0.1, then 0.07, still looked thick; the shadow's own outline adds to the bottom edge).
local SCALED_STROKE = 0.05
-- Properties the two copies take from the label.
local MIRRORED = {
	"Text",
	"RichText",
	"TextSize",
	"Font",
	"TextScaled",
	"TextWrapped",
	"TextXAlignment",
	"TextYAlignment",
	"TextTruncate",
	"LineHeight",
}

local DESIGN_HEIGHT = 1000 -- the layout's pixel sizes are for a screen this tall
local MIN_SCALE, MAX_SCALE = 0.5, 1.2

-- 950, 1.2K, 34.5M, 1.2B, 3.4T, 5.6Qd: for big numbers on boards and tags.
local SUFFIXES = { "K", "M", "B", "T", "Qd", "Qn" }
function UIStyle.short(n: number): string
	if math.abs(n) < 1000 then
		return tostring(math.floor(n))
	end
	local tier = math.min(math.floor(math.log10(math.abs(n)) / 3), #SUFFIXES)
	local scaled = n / 1000 ^ tier
	local text = if scaled >= 100 then string.format("%d", scaled) else string.format("%.1f", scaled)
	return (text:gsub("%.0$", "")) .. SUFFIXES[tier]
end

function UIStyle.commas(n: number): string
	local text = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (text:gsub("^,", ""))
end

function UIStyle.clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- Every rounded corner goes through here; ROUNDNESS scales them all (0.5 since 2026-10-07: the user found the
-- GUIs too rounded; 1 is the old look).
local ROUNDNESS = 0.5

function UIStyle.corner(parent: Instance, pixels: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.round(pixels * ROUNDNESS))
	corner.Parent = parent
end

-- An outline: around a frame (Border) or around text (Contextual on a TextLabel).
function UIStyle.stroke(parent: Instance, thickness: number, color: Color3?, border: boolean?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = color or UIStyle.BLACK
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	if border then
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	stroke.Parent = parent
	return stroke
end

-- A button's gradient, top to bottom: a brighter band at the top, then its two colors (glossier since 2026-10-07).
function UIStyle.gradient(parent: Instance, colors: { Color3 })
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colors[1]:Lerp(Color3.new(1, 1, 1), 0.25)),
		ColorSequenceKeypoint.new(0.35, colors[1]),
		ColorSequenceKeypoint.new(1, colors[2]),
	})
	gradient.Rotation = 90
	gradient.Parent = parent
end

-- The center glow of cards and windows: `edge` at the left and right, `middle` in between. The frame's own
-- BackgroundColor3 must be white for the colors to show as they are.
function UIStyle.glow(parent: GuiObject, edge: Color3, middle: Color3)
	parent.BackgroundColor3 = UIStyle.WHITE
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, edge),
		ColorSequenceKeypoint.new(0.5, middle),
		ColorSequenceKeypoint.new(1, edge),
	})
	gradient.Parent = parent
end

function UIStyle.padding(parent: Instance, pixels: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, pixels)
	padding.PaddingBottom = UDim.new(0, pixels)
	padding.PaddingLeft = UDim.new(0, pixels)
	padding.PaddingRight = UDim.new(0, pixels)
	padding.Parent = parent
end

function UIStyle.list(parent: Instance, horizontal: boolean, gap: number, align: Enum.HorizontalAlignment?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = align or Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = parent
	return layout
end

-- The pyramid's text look: the label's own text is hidden, and two copies inside it draw it: a dark one
-- a little lower (the drop shadow) and the outlined one in the label's TextColor3 on top. Set Text,
-- TextColor3, TextSize and so on on the label as usual; the copies follow while the game runs.
-- stroke: the outline in pixels, or nil for TextScaled labels (the outline then scales with the text).
-- flat: outline only, no shadow (the user found it too thick on the HUD's stat column).
-- drop: the shadow's offset as a fraction of the text size (default SHADOW_DROP; THIN_DROP is lighter).
-- Runs once per label; tools/build_map.luau uses it on the map's signs too.
function UIStyle.dropShadow(label: TextLabel | TextButton, stroke: number?, flat: boolean?, drop: number?)
	local shift = drop or SHADOW_DROP
	if label:FindFirstChild("Face") then
		return
	end
	local function copy(name: string, color: Color3, transparency: number, z: number, outlined: boolean): TextLabel
		local text = Instance.new("TextLabel")
		text.Name = name
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.TextColor3 = color
		text.TextTransparency = transparency
		text.ZIndex = label.ZIndex + z
		if outlined then
			local outline = Instance.new("UIStroke")
			outline.Color = UIStyle.BLACK
			outline.Transparency = transparency
			outline.LineJoinMode = Enum.LineJoinMode.Round
			if stroke then
				outline.Thickness = stroke
			else
				outline.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
				outline.Thickness = SCALED_STROKE
			end
			outline.Parent = text
		end
		text.Parent = label
		return text
	end
	-- The shadow has no outline of its own (2026-10-07): it's the letters' own size, just lower.
	local shadow = copy("Shadow", UIStyle.BLACK, SHADOW_TRANSPARENCY, 0, false)
	shadow.Visible = not flat
	local face = copy("Face", label.TextColor3, 0, 1, true)
	local function mirror(property: string)
		if property == "TextColor3" then
			face.TextColor3 = label.TextColor3
		elseif table.find(MIRRORED, property) then
			local value = (label :: any)[property];
			(face :: any)[property] = value
			if property == "Text" then
				-- RichText colors stay on the face; the shadow stays dark.
				value = (value :: string):gsub('color="[^"]*"', 'color="#000000"')
			end
			(shadow :: any)[property] = value
		end
		if property == "TextSize" or property == "TextScaled" then
			shadow.Position = if label.TextScaled
				then UDim2.fromScale(0, shift)
				else UDim2.fromOffset(0, math.max(1, math.round(label.TextSize * shift)))
		end
	end
	for _, property in MIRRORED do
		mirror(property)
	end
	local hidden: any = label -- (a TextLabel or TextButton)
	hidden.TextTransparency = 1
	hidden.TextStrokeTransparency = 1
	label.Changed:Connect(mirror)
end

-- A top-to-bottom gradient on a dropShadow label's face (or on a "Face" label itself), lighter at the top and deeper
-- at the bottom, from the label's own color unless `top`/`bottom` are given: Build the Pyramid's sign text
-- (2026-10-11, the user). The color moves into the gradient (the text turns white, which the gradient tints); the
-- original is kept in the GradientBase attribute, so calling it again is safe.
function UIStyle.textGradient(label: TextLabel, top: Color3?, bottom: Color3?)
	local face = if label.Name == "Face" then label else label:FindFirstChild("Face")
	if not (face and face:IsA("TextLabel")) then
		return
	end
	local saved = label:GetAttribute("GradientBase")
	local base = if typeof(saved) == "Color3" then saved else label.TextColor3
	label:SetAttribute("GradientBase", base)
	label.TextColor3 = UIStyle.WHITE
	face.TextColor3 = UIStyle.WHITE
	local gradient = face:FindFirstChild("TextGradient") or Instance.new("UIGradient")
	gradient.Name = "TextGradient"
	gradient.Color = ColorSequence.new(top or base:Lerp(UIStyle.WHITE, 0.45), bottom or base:Lerp(UIStyle.BLACK, 0.25))
	gradient.Rotation = 90
	gradient.Parent = face
end

-- Fades out everything inside `label`: dropShadow text (tweening a label's own TextTransparency does
-- nothing, its text is hidden), outlines and images.
function UIStyle.fadeOut(label: GuiObject, info: TweenInfo)
	for _, item in label:GetDescendants() do
		if item:IsA("TextLabel") then
			TweenService:Create(item, info, { TextTransparency = 1 }):Play()
		elseif item:IsA("ImageLabel") then
			TweenService:Create(item, info, { ImageTransparency = 1 }):Play()
		elseif item:IsA("UIStroke") then
			TweenService:Create(item, info, { Transparency = 1 }):Play()
		end
	end
end

-- White outlined text with a drop shadow. The outline grows with the text size.
function UIStyle.text(parent: Instance, value: string, size: number, color: Color3?, flat: boolean?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = UIStyle.FONT
	label.TextSize = size
	label.TextColor3 = color or UIStyle.WHITE
	label.Text = value
	label.Size = UDim2.fromOffset(0, size)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Parent = parent
	UIStyle.dropShadow(label, math.max(1.5, size / 14), flat)
	return label
end

-- Makes a button feel pressable: a click sound and a quick squash when pressed, and on a mouse a hover
-- sound and a slight grow. Every UIStyle.button gets it; call it on hand-made buttons too.
function UIStyle.clicky(button: GuiButton)
	if button:FindFirstChild("Press") then
		return
	end
	local scale = Instance.new("UIScale")
	scale.Name = "Press"
	scale.Parent = button
	local quick = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local back = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, quick, { Scale = 0.92 }):Play()
	end)
	button.Activated:Connect(function()
		Sounds.play("Click")
		scale.Scale = 0.92
		TweenService:Create(scale, back, { Scale = 1 }):Play()
	end)
	button.MouseEnter:Connect(function()
		if not UIStyle.isTouch() then
			Sounds.play("Hover")
			TweenService:Create(scale, quick, { Scale = 1.04 }):Play()
		end
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, quick, { Scale = 1 }):Play()
	end)
end

-- "No": shakes the button side to side with the error sound (can't afford it, sold out, ...).
function UIStyle.deny(target: GuiObject)
	Sounds.play("Error")
	local start = target.Position
	task.spawn(function()
		for _, dx in { -8, 8, -6, 6, -3, 3, 0 } do
			target.Position = start + UDim2.fromOffset(dx, 0)
			task.wait(0.03)
		end
		target.Position = start
	end)
end

-- A quick white glow over a card (a purchase went through).
function UIStyle.flash(card: GuiObject)
	local glow = Instance.new("Frame")
	glow.Name = "Flash"
	glow.Size = UDim2.fromScale(1, 1)
	glow.BackgroundColor3 = UIStyle.WHITE
	glow.BackgroundTransparency = 0.3
	glow.ZIndex = 20
	glow.Parent = card
	local corner = card:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = glow
	end
	local fade = TweenService:Create(glow, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
	fade.Completed:Connect(function()
		glow:Destroy()
	end)
	fade:Play()
end

-- A shop card: a rounded tan box glowing lighter in the middle, with a thick black edge, or `edge` (a rarity color).
function UIStyle.card(parent: Instance, height: number, edge: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.Parent = parent
	UIStyle.corner(frame, 12)
	UIStyle.stroke(frame, 4, edge, true)
	UIStyle.glow(frame, UIStyle.CARD_EDGE, UIStyle.CARD_MIDDLE)
	return frame
end

-- The red X at a panel's top right corner (half outside it).
function UIStyle.closeButton(holder: GuiObject, onClose: () -> ()): TextButton
	local close = UIStyle.button(holder, "X", UIStyle.Colors.Red, UDim2.fromOffset(48, 48), 28)
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.new(1, -6, 0, 6)
	close.ZIndex = 5
	close.Activated:Connect(onClose)
	return close
end

-- A bordered gradient button with outlined text.
function UIStyle.button(parent: Instance, value: string, colors: { Color3 }, size: UDim2, textSize: number): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.BackgroundColor3 = UIStyle.WHITE
	button.AutoButtonColor = true
	button.Font = UIStyle.FONT
	button.TextSize = textSize
	button.TextColor3 = UIStyle.WHITE
	button.Text = value
	button.Parent = parent
	UIStyle.corner(button, 10)
	UIStyle.gradient(button, colors)
	UIStyle.stroke(button, 3, nil, true)
	UIStyle.dropShadow(button, math.max(1.5, textSize / 14))
	UIStyle.clicky(button)
	return button
end

function UIStyle.recolor(button: GuiObject, colors: { Color3 })
	local gradient = button:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(colors[1], colors[2])
	end
end

-- A dark panel with a thick black edge (popups and the shops; gold until 2026-10-07, the user's call).
-- The construction look (2026-10-11, the user's ask): every window sits on a band of black and yellow hazard stripes,
-- like caution tape round its edge. The band is a frame of tiled stripes behind the window, a little bigger than it.
-- It can't be inside the window (the window's list layout would lay it out like content), so it sits at the top of the
-- window's ScreenGui, under everything, and follows the window's on-screen size, place and visibility every frame.
local HAZARD_STRIPES = "rbxassetid://78813724066207" -- assets/textures/hazard_tape.png: black and white, tinted yellow
local HAZARD_YELLOW = Color3.fromRGB(250, 196, 30) -- the BuilderBot armor's yellow
-- 0.026 since 2026-10-11 (the user: slightly thinner; was 0.035, min 9, tile 0.12).
local HAZARD_RIM = 0.026 -- the band's width, as a share of the window's smaller side (at least HAZARD_MIN pixels)
local HAZARD_MIN = 7
local HAZARD_TILE = 0.1 -- one stripe tile, as a share of the window's smaller side

local function shownOnScreen(object: GuiObject): boolean
	local at: Instance? = object
	while at and not at:IsA("LayerCollector") do
		if at:IsA("GuiObject") and not at.Visible then
			return false
		end
		at = at.Parent
	end
	return at ~= nil
end

local function hazardRim(window: GuiObject)
	local rim = Instance.new("ImageLabel")
	rim.Name = "HazardRim"
	rim.Image = HAZARD_STRIPES
	rim.ImageColor3 = HAZARD_YELLOW
	rim.ScaleType = Enum.ScaleType.Tile
	rim.BackgroundColor3 = UIStyle.BLACK
	rim.ZIndex = -1 -- under the window and everything else in its ScreenGui
	rim.Visible = false
	UIStyle.corner(rim, 26)
	UIStyle.stroke(rim, 3, UIStyle.BLACK, true)
	RunService.RenderStepped:Connect(function()
		local gui = window:FindFirstAncestorWhichIsA("LayerCollector")
		if not (gui and gui:IsA("ScreenGui")) then
			rim.Visible = false
			return
		end
		if rim.Parent ~= gui then
			rim.Parent = gui
		end
		local size = window.AbsoluteSize
		local show = gui.Enabled and size.X > 0 and size.Y > 0 and shownOnScreen(window)
		rim.Visible = show
		if not show then
			return
		end
		local side = math.min(size.X, size.Y)
		local band = math.max(HAZARD_MIN, math.round(side * HAZARD_RIM))
		local at = window.AbsolutePosition - gui.AbsolutePosition
		rim.Position = UDim2.fromOffset(at.X - band, at.Y - band)
		rim.Size = UDim2.fromOffset(size.X + band * 2, size.Y + band * 2)
		local tile = math.round(side * HAZARD_TILE)
		rim.TileSize = UDim2.fromOffset(tile, tile)
	end)
	window.Destroying:Connect(function()
		rim:Destroy()
	end)
end

function UIStyle.panel(parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 0.04
	frame.Parent = parent
	UIStyle.glow(frame, UIStyle.PANEL_EDGE, UIStyle.PANEL_MIDDLE)
	UIStyle.corner(frame, 18)
	UIStyle.stroke(frame, 5, UIStyle.BLACK, true)
	hazardRim(frame)
	return frame
end

-- An icon slot: the image once it has an id, else the emoji.
function UIStyle.icon(parent: Instance, icon: Icon, pixels: number): GuiObject
	local slot: GuiObject
	if icon.Image ~= "" then
		local image = Instance.new("ImageLabel")
		image.Image = icon.Image
		image.ScaleType = Enum.ScaleType.Fit
		slot = image
	else
		local emoji = Instance.new("TextLabel")
		emoji.Text = icon.Emoji
		emoji.TextScaled = true
		emoji.Font = Enum.Font.SourceSans
		slot = emoji
	end
	slot.BackgroundTransparency = 1
	slot.Size = UDim2.fromOffset(pixels, pixels)
	slot.Parent = parent
	return slot
end

-- A UIScale that keeps the layout's proportions on any screen height.
-- Phones and tablets: the HUD uses the pyramid's mobile layout (Forest Bar at the bottom).
-- ScreenGuis keep the default ScreenInsets (CoreUISafeInsets), so nothing goes under a notch or the top bar.
-- In Studio, the phone view can report a keyboard too, so there a touch screen counts as a phone when the view is
-- phone-sized (its short side under PHONE_SHORT_SIDE). Until 2026-10-11 any touch screen in Studio did, so a
-- touchscreen laptop got the phone layout (the user's report: the Forest Bar at the bottom on a laptop).
local PHONE_SHORT_SIDE = 600
function UIStyle.isTouch(): boolean
	if not UserInputService.TouchEnabled then
		return false
	end
	if not UserInputService.KeyboardEnabled then
		return true
	end
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
	return RunService:IsStudio() and math.min(view.X, view.Y) < PHONE_SHORT_SIDE
end

-- Whose button names to show: a gamepad's while one is in use, a phone's on touch screens (even when its keys
-- move you, in Studio's phone view), else the keyboard's. The pile prompt and the tutorial both go by this.
function UIStyle.inputKind(): "Gamepad" | "Touch" | "Keyboard"
	local last = UserInputService:GetLastInputType()
	if string.find(last.Name, "Gamepad") then
		return "Gamepad"
	end
	return if last == Enum.UserInputType.Touch or UIStyle.isTouch() then "Touch" else "Keyboard"
end

-- The layout's size factor for the current screen height.
function UIStyle.screenScale(): number
	local camera = Workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else DESIGN_HEIGHT
	return math.clamp(height / DESIGN_HEIGHT, MIN_SCALE, MAX_SCALE)
end

-- grow: an extra size factor on top of the screen's (the upgrade shop opens bigger, 2026-10-07).
function UIStyle.autoScale(target: GuiObject, grow: number?)
	local scale = Instance.new("UIScale")
	scale.Parent = target
	local function update()
		scale.Scale = UIStyle.screenScale() * (grow or 1)
	end
	local function watch()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)
	watch()
end

-- Windows (the pop-ups: shop, daily, hats, gifts...) on phones: the HUD's scale times WINDOW_PHONE_GROW, as far as
-- the window still fits in WINDOW_FIT of the screen's safe area (the user, 2026-10-11: on phones the windows' text was
-- hard to read; landscape phones sit at MIN_SCALE, so a size-18 label was 9 pixels). Elsewhere just autoScale's.
local WINDOW_PHONE_GROW = 1.6
local WINDOW_FIT = 0.94
-- Computers (2026-10-11, the user's ask, after a reference game whose shops fill over half the screen): windows grow
-- WINDOW_DESKTOP_GROW times on top of their own grow, as far as they fit in WINDOW_DESKTOP_FIT of the screen (the height
-- share leaves the top bar clear).
local WINDOW_DESKTOP_GROW = 1.3
local WINDOW_DESKTOP_FIT = Vector2.new(0.9, 0.7) -- 0.7: the upgrade shop (centred on the whole screen) clears the plank packs
function UIStyle.windowScale(target: GuiObject, grow: number?)
	local touch = UIStyle.isTouch()
	local scale = Instance.new("UIScale")
	scale.Parent = target
	local function update()
		local s = UIStyle.screenScale() * (if touch then WINDOW_PHONE_GROW else (grow or 1) * WINDOW_DESKTOP_GROW)
		local fit = if touch then Vector2.new(WINDOW_FIT, WINDOW_FIT) else WINDOW_DESKTOP_FIT
		local gui = target:FindFirstAncestorWhichIsA("LayerCollector")
		-- Its size at scale 1, roughly (text and strokes don't scale exactly, so this runs again as it settles).
		local natural = target.AbsoluteSize / scale.Scale
		local area = if gui then gui.AbsoluteSize else Vector2.zero
		if natural.X <= 0 or natural.Y <= 0 or area.X <= 0 or area.Y <= 0 then
			return -- not laid out yet: AbsoluteSize changes once it is
		end
		s = math.min(s, fit.X * area.X / natural.X, fit.Y * area.Y / natural.Y)
		if math.abs(scale.Scale - s) > 0.001 then
			scale.Scale = s
		end
	end
	target:GetPropertyChangedSignal("AbsoluteSize"):Connect(update) -- its content grows or it's first laid out
	task.defer(function()
		local gui = target:FindFirstAncestorWhichIsA("LayerCollector")
		if gui then
			gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
			if gui:IsA("ScreenGui") then
				gui:GetPropertyChangedSignal("Enabled"):Connect(function()
					task.defer(update)
				end)
			end
		end
	end)
	local function watch()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)
	watch()
end

-- Blurs the game behind a window while its ScreenGui is enabled, like Build the Pyramid's menus (2026-10-07).
-- Windows share one BlurEffect in Lighting (only on this client); it stays while any of them is open.
-- (A screen-edge vignette was tried here and removed: the user meant the text bands below.)
local BLUR_SIZE = 16
local BLUR_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local blurOpen = 0
local blur: BlurEffect? = nil
function UIStyle.blurBehind(gui: ScreenGui)
	local shown = false
	local function apply()
		if gui.Enabled == shown then
			return
		end
		shown = gui.Enabled
		blurOpen += if shown then 1 else -1
		if not blur then
			local made = Instance.new("BlurEffect")
			made.Name = "WindowBlur"
			made.Size = 0
			made.Parent = game:GetService("Lighting")
			blur = made
		end
		TweenService:Create(blur :: BlurEffect, BLUR_TWEEN, { Size = if blurOpen > 0 then BLUR_SIZE else 0 }):Play()
	end
	gui:GetPropertyChangedSignal("Enabled"):Connect(apply)
	apply()
end

-- A dark band behind a sign's text, fading out at both ends, so the text sits on a soft dark strip (the user's
-- "vignette" for the lobby signs, 2026-10-07). Centered in its parent; draws behind the text (ZIndex 0).
-- Of the sign's width, centered, past its edges (signs don't clip): 1.3 since 2026-10-11 with shorter fades, so the
-- dark middle covers the whole word (the user: PLANKS's letters ran out of it; at 0.8 with quarter fades only the middle
-- 40% was dark).
local BAND_WIDTH = 1.3
local BAND_FADE = 0.12 -- each end fades out over this share of the band
local BAND_HEIGHT = 1.6 -- of the sign's height, centered: room above and below the text (1 was tight)
local BAND_DARKEST = 0.75 -- transparency in the middle (0 = solid black; 0.35, then 0.6, were too dark)
-- The animated rainbow (2026-10-08): six colors, and rainbowSequence(phase) is the whole rainbow across a gradient,
-- turned by `phase` (0..1, wrapping). Animate a UIGradient by setting its Color to this with a growing phase: the
-- colors cycle in place. (Sliding the gradient's Offset instead showed a long stretch of one end color past the edge.)
UIStyle.RAINBOW = {
	Color3.fromRGB(255, 80, 120),
	Color3.fromRGB(255, 170, 60),
	Color3.fromRGB(255, 240, 80),
	Color3.fromRGB(110, 255, 120),
	Color3.fromRGB(80, 190, 255),
	Color3.fromRGB(190, 110, 255),
}
function UIStyle.rainbowAt(t: number): Color3
	local colors = UIStyle.RAINBOW
	local x = (t % 1) * #colors
	local i = math.floor(x)
	return colors[i + 1]:Lerp(colors[(i + 1) % #colors + 1], x - i)
end
local RAINBOW_KEYS = 12
function UIStyle.rainbowSequence(phase: number): ColorSequence
	local keys = {}
	for k = 0, RAINBOW_KEYS do
		local along = k / RAINBOW_KEYS
		table.insert(keys, ColorSequenceKeypoint.new(along, UIStyle.rainbowAt(along - phase)))
	end
	return ColorSequence.new(keys)
end

function UIStyle.band(parent: Instance): Frame
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.BackgroundColor3 = UIStyle.BLACK
	band.BorderSizePixel = 0
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Position = UDim2.fromScale(0.5, 0.5)
	band.Size = UDim2.fromScale(BAND_WIDTH, BAND_HEIGHT)
	band.ZIndex = 0
	band.Parent = parent
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(BAND_FADE, BAND_DARKEST),
		NumberSequenceKeypoint.new(1 - BAND_FADE, BAND_DARKEST),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = band
	return band
end

-- Robux prices from Roblox, asked once per item. Returns nil until known; onReady runs when it arrives.
local PRICE_RETRY_SECONDS = 30 -- after a failed lookup (GetProductInfo is throttled)
local prices: { [number]: number } = {}
local asking: { [number]: { () -> () } } = {}
local retryAt: { [number]: number } = {}
function UIStyle.price(id: number, infoType: Enum.InfoType, onReady: (() -> ())?): number?
	if id == 0 then
		return nil
	end
	local known = prices[id]
	if known then
		return known
	end
	if os.clock() < (retryAt[id] or 0) then
		return nil
	end
	local waiting = asking[id]
	if waiting then
		if onReady then
			table.insert(waiting, onReady)
		end
		return nil
	end
	asking[id] = if onReady then { onReady } else {}
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
		if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
			prices[id] = info.PriceInRobux
			local callbacks = asking[id]
			asking[id] = nil
			if callbacks then
				for _, callback in callbacks do
					task.spawn(callback)
				end
			end
		else
			asking[id] = nil
			retryAt[id] = os.clock() + PRICE_RETRY_SECONDS
		end
	end)
	return nil
end

function UIStyle.priceText(id: number, infoType: Enum.InfoType, onReady: (() -> ())?): string
	local price = UIStyle.price(id, infoType, onReady)
	return if price then `{UIStyle.ROBUX}{UIStyle.commas(price)}` else `{UIStyle.ROBUX}…`
end

return UIStyle
