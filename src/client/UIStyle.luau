--!strict
-- UIStyle: the shared look of every screen (docs/plans/GUI.md), after Build the Pyramid's HUD:
-- Gotham Black, white text with a thick black outline and a dark drop shadow (dropShadow), dark-bordered
-- gradient buttons, and one size scale for the whole screen so phones get the same layout, smaller.
-- Icons: put an uploaded image id in Image (e.g. "rbxassetid://123"); until then the emoji shows.
-- Polish pass (2026-10-07): every button clicks (Sounds) and squashes when pressed (clicky), deny() shakes a
-- button with the error sound, flash() lights up a card after a purchase, closeButton() is the shared red X,
-- card() the shared shop card, short() writes big numbers as 1.2K / 3.4M.

local MarketplaceService = game:GetService("MarketplaceService")
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
	Coins = { Image = "rbxassetid://98949249976360", Emoji = "💰" },
	Speed = { Image = "rbxassetid://111362551254873", Emoji = "⚡" },
	Strength = { Image = "rbxassetid://128313204943236", Emoji = "💪" },
	Forests = { Image = "rbxassetid://82377814437587", Emoji = "🌳" }, -- the user's "forest-icon" (was 137125846833438)
	Friends = { Image = "rbxassetid://15403044988", Emoji = "👥" }, -- the user's pick: Creator Store decal 15403045010
	Shop = { Image = "rbxassetid://120542083299834", Emoji = "🛒" }, -- the user's "Red Shopping Cart" (was a basket)
	ServerBoost = { Image = "", Emoji = "🚀" },
	Settings = { Image = "rbxassetid://77572487902863", Emoji = "⚙️" }, -- the user's "Settings White" (was 80167634570686)
	Codes = { Image = "", Emoji = "🎟️" },
	Ranger = { Image = "", Emoji = "🤠" },
	Lord = { Image = "", Emoji = "👑" },
	BulkPickup = { Image = "rbxassetid://120369441988104", Emoji = "🌰" }, -- the user's pick
	BulkPlant = { Image = "rbxassetid://140485439494131", Emoji = "🌱" }, -- the user's pick
	PlantingRange = { Image = "rbxassetid://134531632884543", Emoji = "🎯" }, -- the user's pick
	Restock = { Image = "", Emoji = "⏰" },
	Trophy = { Image = "", Emoji = "🏆" },
} :: { [string]: Icon }

local SHADOW_DROP = 0.1 -- how far the shadow sits below the text, as a fraction of the text size (0.14 until 2026-10-07: too thick)
UIStyle.THIN_DROP = 0.07 -- a lighter shadow: the Forest Bar number and the map's signs (the user's request)
local SHADOW_TRANSPARENCY = 0.2
local SCALED_STROKE = 0.1 -- outline of TextScaled labels (StrokeSizingMode ScaledSize)
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
function UIStyle.panel(parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 0.04
	frame.Parent = parent
	UIStyle.glow(frame, UIStyle.PANEL_EDGE, UIStyle.PANEL_MIDDLE)
	UIStyle.corner(frame, 18)
	UIStyle.stroke(frame, 5, UIStyle.BLACK, true)
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
function UIStyle.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
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
local BAND_WIDTH = 0.8 -- of the sign's width, centered (1 was a bit long)
local BAND_HEIGHT = 1.6 -- of the sign's height, centered: room above and below the text (1 was tight)
local BAND_DARKEST = 0.75 -- transparency in the middle (0 = solid black; 0.35, then 0.6, were too dark)
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
		NumberSequenceKeypoint.new(0.25, BAND_DARKEST),
		NumberSequenceKeypoint.new(0.75, BAND_DARKEST),
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
