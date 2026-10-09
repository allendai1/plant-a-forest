--!strict
-- RobuxShopController: the SHOP button's panel (docs/plans/GUI.md; tabs and characters in the polish pass,
-- 2026-10-07). Everything in it costs Robux, on three tabs:
-- - Boosts: "BOOST Server Training!" (2x training for everyone for a while) and the Strength and Speed boost
--   pass ladders.
-- - Characters: the Forest Ranger and the Lord of the Forest (GameConfig.HandsPasses: faster picking up and planting,
--   and the outfit), each a card with a turning 3D preview (Assets.Outfits.<Outfit>Preview, made by
--   OutfitService).
-- - Stations: the training station passes.
-- Roblox's own purchase prompts do the buying; the server grants (ProductService, PassService). A purchase
-- flashes its card with the purchase sound. The NPCs' prompts by the altar (a PassId attribute) also open
-- their pass's purchase prompt from here. The upgrades for coins stay at the altar (ShopController).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(script.Parent.Parent.Sounds)
local UIStyle = require(script.Parent.Parent.UIStyle)

local REFRESH_SECONDS = 0.5
local WIDTH = 680
local TABS = { "Boosts", "Characters", "Stations" }
local PREVIEW_TURN = 0.6 -- radians per second

local RobuxShopController = {}

local localPlayer = Players.LocalPlayer
local gui: ScreenGui? = nil
local refreshers: { () -> () } = {}
local ownsPass: { [number]: boolean } = {} -- station passes, asked from Roblox when the shop opens
local cardOf: { [number]: GuiObject } = {} -- product or pass id -> its card, to flash on purchase
local showTab: (string) -> () = function() end

local function attribute(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function refreshAll()
	for _, refresh in refreshers do
		refresh()
	end
end

local function header(parent: Instance, order: number, text: string)
	local label = UIStyle.text(parent, text, 30, UIStyle.GOLD)
	label.LayoutOrder = order
end

local function buyButton(parent: Instance, colors: { Color3 }): TextButton
	local button = UIStyle.button(parent, "", colors, UDim2.fromOffset(130, 44), 26)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -12, 0.5, 0)
	return button
end

-- A slanted tag on a card's top left corner ("POPULAR", "BEST VALUE").
local function ribbon(card: GuiObject, text: string, colors: { Color3 })
	local tag = UIStyle.button(card, text, colors, UDim2.fromOffset(0, 26), 16)
	tag.Name = "Ribbon"
	tag.AutomaticSize = Enum.AutomaticSize.X
	tag.Active = false
	tag.AutoButtonColor = false
	tag.Position = UDim2.fromOffset(-8, -12)
	tag.Rotation = -6
	tag.ZIndex = 6
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.Parent = tag
end

local function serverBoostCard(list: Instance)
	local boost = GameConfig.ServerBoost
	local forestState = ReplicatedStorage:WaitForChild("ForestState")
	local frame = UIStyle.card(list, 104)
	frame.LayoutOrder = 1
	local shine = frame:FindFirstChildOfClass("UIGradient")
	if shine then -- the cards' center glow, in purple
		shine.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 32, 150)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 95, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 32, 150)),
		})
	end
	ribbon(frame, "POPULAR", UIStyle.Colors.Orange)
	local art = UIStyle.icon(frame, UIStyle.Icons.ServerBoost, 64)
	art.Position = UDim2.fromOffset(14, 20)
	local title = UIStyle.text(frame, "BOOST Server Training!", 32)
	title.Position = UDim2.fromOffset(90, 14)
	local detail = UIStyle.text(frame, "", 19, UIStyle.GREY)
	detail.Position = UDim2.fromOffset(90, 56)
	local pitch = UIStyle.text(frame, "Everyone in the server thanks you!", 16, Color3.fromRGB(220, 210, 255))
	pitch.Position = UDim2.fromOffset(90, 80)
	local buy = buyButton(frame, UIStyle.Colors.Green)
	cardOf[boost.ProductId] = frame
	buy.Activated:Connect(function()
		MarketplaceService:PromptProductPurchase(localPlayer, boost.ProductId)
	end)
	table.insert(refreshers, function()
		local left = attribute(forestState, "ServerBoostEndsAt") - workspace:GetServerTimeNow()
		local minutes = math.round(boost.Seconds / 60)
		detail.Text = if left > 0
			then `{boost.Multiplier}x for everyone: {UIStyle.clock(left)} left, buy to add {minutes} min`
			else `1x → {boost.Multiplier}x training for everyone, {minutes} min`
		buy.Text = UIStyle.priceText(boost.ProductId, Enum.InfoType.Product, refreshAll)
	end)
end

-- A pass ladder card: the multiplier the next purchase gives, and a button for it.
-- `ownedAttribute` is the attribute with the player's best multiplier.
local function boostCard(
	list: Instance,
	order: number,
	name: string,
	pitch: string,
	ladder: { GameConfig.BoostPass },
	ownedAttribute: string,
	icon: UIStyle.Icon
)
	local frame = UIStyle.card(list, 96)
	frame.LayoutOrder = order
	local art = UIStyle.icon(frame, icon, 60)
	art.Position = UDim2.fromOffset(14, 18)
	local title = UIStyle.text(frame, name, 28)
	title.Position = UDim2.fromOffset(86, 8)
	local steps = UIStyle.text(frame, "", 22, UIStyle.GREY)
	steps.Position = UDim2.fromOffset(86, 42)
	steps.RichText = true
	local line = UIStyle.text(frame, pitch, 16, UIStyle.GREY)
	line.Position = UDim2.fromOffset(86, 70)
	local buy = buyButton(frame, UIStyle.Colors.Green)
	for _, step in ladder do
		cardOf[step.PassId] = frame
	end
	local nextPass: GameConfig.BoostPass? = nil
	buy.Activated:Connect(function()
		if nextPass then
			MarketplaceService:PromptGamePassPurchase(localPlayer, nextPass.PassId)
		end
	end)
	table.insert(refreshers, function()
		-- Just what the next purchase gives ("2x"), not the whole ladder (the user's call, 2026-10-07).
		local have = math.max(1, attribute(localPlayer, ownedAttribute))
		nextPass = nil
		for _, step in ladder do
			if step.Multiplier > have and not nextPass then
				nextPass = step
			end
		end
		steps.Text = if nextPass
			then `<font color="#ffffff">{nextPass.Multiplier}x</font>`
			else `<font color="#78ff5a">{have}x (max)</font>`
		if nextPass then
			buy.Text = UIStyle.priceText(nextPass.PassId, Enum.InfoType.GamePass, refreshAll)
			UIStyle.recolor(buy, UIStyle.Colors.Green)
		else
			buy.Text = "MAX"
			UIStyle.recolor(buy, UIStyle.Colors.Grey)
		end
	end)
end

-- A slowly turning 3D preview of a character (Assets.Outfits.<Outfit>Preview, made by OutfitService).
local function characterPreview(parent: Instance, outfit: string, size: UDim2): ViewportFrame
	local frame = Instance.new("ViewportFrame")
	frame.Size = size
	frame.BackgroundTransparency = 1
	frame.Ambient = Color3.fromRGB(210, 210, 210)
	frame.LightColor = Color3.fromRGB(255, 250, 240)
	frame.LightDirection = Vector3.new(-1, -1, -1.5)
	frame.Parent = parent
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = frame
	frame.CurrentCamera = camera
	task.spawn(function()
		local outfits = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Outfits")
		local template = outfits:WaitForChild(outfit .. "Preview", 30)
		if not (template and template:IsA("Model")) then
			return
		end
		local world = Instance.new("WorldModel")
		world.Parent = frame
		local model = template:Clone()
		model.Parent = world
		local box, extents = model:GetBoundingBox()
		local distance = extents.Y * 2.1
		local angle = 0
		RunService.RenderStepped:Connect(function(dt: number)
			if not frame.Visible or not (gui and gui.Enabled) then
				return
			end
			angle += dt * PREVIEW_TURN
			local eye = box.Position + Vector3.new(math.sin(angle) * distance, extents.Y * 0.15, -math.cos(angle) * distance)
			camera.CFrame = CFrame.lookAt(eye, box.Position + Vector3.new(0, extents.Y * 0.1, 0))
		end)
	end)
	return frame
end

local function characterCards(list: Instance)
	local pitch = UIStyle.text(list, "Pick up and plant faster, and wear the outfit!", 22, UIStyle.GREY)
	pitch.LayoutOrder = 1
	local row = Instance.new("Frame")
	row.LayoutOrder = 2
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 330)
	row.Parent = list
	local layout = UIStyle.list(row, true, 14, Enum.HorizontalAlignment.Center)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	local passes = GameConfig.availableHandsPasses()
	for i, pass in passes do
		local card = UIStyle.card(row, 330)
		card.Size = UDim2.new(0.5, -7, 0, 330)
		card.LayoutOrder = i
		cardOf[pass.PassId] = card
		if i == #passes and #passes > 1 then
			ribbon(card, "BEST", UIStyle.Colors.Purple)
		end
		local preview = characterPreview(card, pass.Outfit, UDim2.new(1, -20, 0, 190))
		preview.Position = UDim2.fromOffset(10, 6)
		local icon = UIStyle.icon(card, if pass.Outfit == "Lord" then UIStyle.Icons.Lord else UIStyle.Icons.Ranger, 40)
		icon.Position = UDim2.fromOffset(12, 196)
		local name = UIStyle.text(
			card,
			pass.Name,
			if #pass.Name > 14 then 22 else 28,
			if i == 1 then Color3.fromRGB(240, 210, 140) else Color3.fromRGB(150, 255, 150)
		)
		name.Position = UDim2.fromOffset(58, 200)
		local perk = UIStyle.text(card, pass.Pitch, 17, UIStyle.WHITE)
		perk.Position = UDim2.fromOffset(14, 240)
		local buy = UIStyle.button(card, "", UIStyle.Colors.Green, UDim2.new(1, -24, 0, 44), 26)
		buy.AnchorPoint = Vector2.new(0.5, 1)
		buy.Position = UDim2.new(0.5, 0, 1, -10)
		buy.Activated:Connect(function()
			if attribute(localPlayer, "HandsSpeed") < pass.Multiplier then
				MarketplaceService:PromptGamePassPurchase(localPlayer, pass.PassId)
			end
		end)
		table.insert(refreshers, function()
			local speed = attribute(localPlayer, "HandsSpeed")
			if speed == pass.Multiplier then
				buy.Text = "Wearing"
				UIStyle.recolor(buy, UIStyle.Colors.Teal)
			elseif speed > pass.Multiplier then
				buy.Text = "Owned"
				UIStyle.recolor(buy, UIStyle.Colors.Grey)
			else
				buy.Text = UIStyle.priceText(pass.PassId, Enum.InfoType.GamePass, refreshAll)
				UIStyle.recolor(buy, UIStyle.Colors.Green)
			end
		end)
	end
end

local function stationCards(list: Instance)
	local pitch = UIStyle.text(list, "Unlock a training tier now, without waiting for forests.", 20, UIStyle.GREY)
	pitch.LayoutOrder = 1
	local grid = Instance.new("Frame")
	grid.LayoutOrder = 2
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromScale(1, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.Parent = list
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.25, -9, 0, 118)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	for _, step in GameConfig.Stats.GymMultipliers do
		local passId = GameConfig.StationPasses[step.Multiplier]
		if passId then
			local frame = UIStyle.card(grid, 118)
			frame.LayoutOrder = step.Multiplier
			cardOf[passId] = frame
			local title = UIStyle.text(frame, `{step.Multiplier}x`, 36)
			title.AnchorPoint = Vector2.new(0.5, 0)
			title.Position = UDim2.new(0.5, 0, 0, 4)
			local free =
				UIStyle.text(frame, `or {step.ForestsDone} forest{if step.ForestsDone == 1 then "" else "s"}`, 15, UIStyle.GREY)
			free.AnchorPoint = Vector2.new(0.5, 0)
			free.Position = UDim2.new(0.5, 0, 0, 42)
			local buy = UIStyle.button(frame, "", UIStyle.Colors.Green, UDim2.new(1, -20, 0, 40), 24)
			buy.AnchorPoint = Vector2.new(0.5, 1)
			buy.Position = UDim2.new(0.5, 0, 1, -10)
			buy.Activated:Connect(function()
				if not ownsPass[passId] then
					MarketplaceService:PromptGamePassPurchase(localPlayer, passId)
				end
			end)
			table.insert(refreshers, function()
				if ownsPass[passId] or attribute(localPlayer, "ForestsCompleted") >= step.ForestsDone then
					buy.Text = if ownsPass[passId] then "Owned" else "Unlocked"
					UIStyle.recolor(buy, UIStyle.Colors.Grey)
				else
					buy.Text = UIStyle.priceText(passId, Enum.InfoType.GamePass, refreshAll)
					UIStyle.recolor(buy, UIStyle.Colors.Green)
				end
			end)
		end
	end
end

-- One tab's page: a scrolling list.
local function page(panel: Instance, name: string): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = name
	scroll.Position = UDim2.fromOffset(18, 126)
	scroll.Size = UDim2.new(1, -36, 1, -142)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Visible = false
	scroll.Parent = panel
	local list = UIStyle.list(scroll, false, 14)
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 14), UDim.new(0, 6)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 14)
	pad.Parent = scroll
	return scroll
end

local function build(): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "RobuxShop"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	UIStyle.blurBehind(screen) -- the game blurs behind the window, like the upgrade shop
	screen.DisplayOrder = 2
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(WIDTH, if UIStyle.isTouch() then 580 else 640) -- phones are short; pages scroll
	holder.BackgroundTransparency = 1
	holder.Parent = screen
	UIStyle.autoScale(holder)
	local panel = UIStyle.panel(holder)
	panel.Size = UDim2.fromScale(1, 1)
	local title = UIStyle.text(panel, "SHOP", 48, UIStyle.GOLD)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 8)
	UIStyle.closeButton(holder, function()
		screen.Enabled = false
	end)

	local tabRow = Instance.new("Frame")
	tabRow.BackgroundTransparency = 1
	tabRow.Position = UDim2.fromOffset(18, 70)
	tabRow.Size = UDim2.new(1, -36, 0, 46)
	tabRow.Parent = panel
	UIStyle.list(tabRow, true, 10, Enum.HorizontalAlignment.Center)
	local pages: { [string]: ScrollingFrame } = {}
	local tabButtons: { [string]: TextButton } = {}
	for i, name in TABS do
		local tab = UIStyle.button(tabRow, name, UIStyle.Colors.Grey, UDim2.new(1 / #TABS, -7, 1, 0), 26)
		tab.LayoutOrder = i
		tabButtons[name] = tab
		tab.Activated:Connect(function()
			showTab(name)
		end)
		pages[name] = page(panel, name)
	end
	showTab = function(name: string)
		for key, scroll in pages do
			scroll.Visible = key == name
			UIStyle.recolor(tabButtons[key], if key == name then UIStyle.Colors.Gold else UIStyle.Colors.Grey)
		end
	end

	serverBoostCard(pages.Boosts)
	header(pages.Boosts, 2, "Training Boosts")
	boostCard(
		pages.Boosts,
		3,
		"Strength Boost",
		"Every rep gives more Strength, forever",
		GameConfig.BoostPasses.Strength,
		"StrengthBoost",
		UIStyle.Icons.Strength
	)
	boostCard(
		pages.Boosts,
		4,
		"Speed Boost",
		"Every run gives more Speed, forever",
		GameConfig.BoostPasses.Speed,
		"SpeedBoost",
		UIStyle.Icons.Speed
	)
	characterCards(pages.Characters)
	stationCards(pages.Stations)
	showTab("Boosts")

	screen.Parent = localPlayer:WaitForChild("PlayerGui")
	return screen
end

-- Asks Roblox which station passes the player owns (no attribute carries them).
local function checkPasses()
	for _, passId in GameConfig.StationPasses do
		if not ownsPass[passId] then
			task.spawn(function()
				local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, localPlayer.UserId, passId)
				if ok and has then
					ownsPass[passId] = true
					refreshAll()
				end
			end)
		end
	end
end

local function open(tab: string?)
	local screen = gui or build()
	gui = screen
	screen.Enabled = true
	if tab then
		showTab(tab)
	end
	Remotes.event("RobuxShopOpened"):FireServer() -- analytics: the RobuxShop funnel
	checkPasses()
	refreshAll()
end

function RobuxShopController.toggle()
	if gui and gui.Enabled then
		gui.Enabled = false
	else
		open(nil)
	end
end

-- Opens the shop on a tab ("Boosts", "Characters", "Stations").
function RobuxShopController.open(tab: string)
	open(tab)
end

-- A finished purchase: the purchase sound, and its card flashes if the shop shows it.
local function purchased(id: number)
	Sounds.play("Purchase")
	local card = cardOf[id]
	if card and gui and gui.Enabled then
		UIStyle.flash(card)
	end
end

function RobuxShopController.start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if player == localPlayer and wasPurchased then
			ownsPass[passId] = true
			purchased(passId)
			refreshAll()
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, wasPurchased)
		if userId == localPlayer.UserId and wasPurchased then
			purchased(productId)
		end
	end)
	-- The Forest Ranger and Lord of the Forest NPCs by the altar sell their pass.
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local passId = prompt:GetAttribute("PassId")
		if player == localPlayer and typeof(passId) == "number" then
			MarketplaceService:PromptGamePassPurchase(localPlayer, passId)
		end
	end)
	for _, name in { "StrengthBoost", "SpeedBoost", "HandsSpeed", "ForestsCompleted" } do
		localPlayer:GetAttributeChangedSignal(name):Connect(refreshAll)
	end
	while true do
		task.wait(REFRESH_SECONDS)
		if gui and gui.Enabled then
			refreshAll()
		end
	end
end

return RobuxShopController
