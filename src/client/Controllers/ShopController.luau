--!strict
-- ShopController: the upgrade shop at the altar in front of the Ancient Tree (docs/plans/M6b.md, M7.md).
-- Stepping into the glowing ring in front of the altar (the part tagged ShopZone) opens the panel;
-- stepping out closes it. Each upgrade shows its level, what the next level does and a Buy button with
-- the price (dimmed when you can't afford it, MAX at the top). Buying asks the server (BuyUpgrade),
-- which checks everything; the panel follows your Coins and level attributes.
-- GUI pass: restyled (UIStyle), and each row also sells its next level for Robux
-- (GameConfig.UpgradeProducts, granted by ProductService).
-- Seed shop (docs/plans/SeedShop.md): the seed stall's ring (SeedShopZone) opens the Seeds page instead. It shows this restock's stock (the
-- same seedStock() the server uses), what you have left to buy, a countdown to the next restock, and per
-- seed a coin Buy button (BuySeed) and a Robux one. A banner (and a chime) tells everyone when an Epic or
-- Legendary seed comes into stock.
-- Polish pass (2026-10-07): an icon and level pips per upgrade; a level bought flashes its row with the level
-- up sound, a seed bought flashes its card; a button you can't use shakes with the error sound and the line
-- at the bottom says why ("You need 120 more coins"). The X closes the panel until you step out of the ring.

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)
local Trees = require(Shared.Trees)
local HUD = require(script.Parent.HUD)
local SeedBagController = require(script.Parent.SeedBagController)
local Sounds = require(script.Parent.Parent.Sounds)
local UIStyle = require(script.Parent.Parent.UIStyle)

local CHECK_SECONDS = 0.2
local RING_HEIGHT = 8 -- the ring counts up to this far above it
local WIDTH = 640
local HINT_SECONDS = 2.5
local PIP = 13 -- level pip size
local PIP_ON = Color3.fromRGB(255, 205, 80)
local PIP_OFF = Color3.fromRGB(40, 32, 26)
local GROW = 1.4 -- the upgrade shop opens this much bigger than the HUD scale (1.25 until the user asked for bigger)
local SEEDS_HEIGHT = 568 -- the seed page: the restock line and five 96-pixel cards, no scrolling
local SEEDS_HEIGHT_TOUCH = 300 -- phones: about three cards, the rest scroll

type Row = { id: string, frame: Frame, detail: TextLabel, pips: { Frame }, button: TextButton, robux: TextButton }
type SeedRow = { def: GameConfig.SeedDef, frame: Frame, stock: TextLabel, button: TextButton, robux: TextButton }

local ShopController = {}

local localPlayer = Players.LocalPlayer
local rows: { Row } = {}
local seedRows: { SeedRow } = {}
local restockLabel: TextLabel? = nil
local hintLabel: TextLabel? = nil
local hintShown = 0
local dismissed = false -- closed with the X; stays closed until you step out of the ring
local pages: { [string]: GuiObject } = {}
local page = "Upgrades"
local titleLabel: TextLabel? = nil
-- Which page each ring opens.
local RINGS: { [string]: string } = { ShopZone = "Upgrades", SeedShopZone = "Seeds" }
local TITLES: { [string]: string } = { Upgrades = "Upgrades", Seeds = "Seed Shop" }

-- The page of the shop ring the character stands in, if any. Looked up every check: with StreamingEnabled
-- the zone part can unload and come back as a new part.
local function ringPage(root: BasePart): string?
	for tag, name in RINGS do
		for _, zone in CollectionService:GetTagged(tag) do
			if zone:IsA("BasePart") then
				local offset = root.Position - zone.Position
				local radius = math.max(zone.Size.Y, zone.Size.Z) / 2
				if Vector2.new(offset.X, offset.Z).Magnitude <= radius and math.abs(offset.Y) <= RING_HEIGHT then
					return name
				end
			end
		end
	end
	return nil
end

local function attribute(name: string): number
	local value = localPlayer:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

-- The bottom line says why a button didn't work, in red, for a moment.
local function tell(text: string)
	local label = hintLabel
	if not label then
		return
	end
	hintShown += 1
	local shown = hintShown
	label.Text = text
	label.Visible = true
	task.delay(HINT_SECONDS, function()
		if hintShown == shown then
			label.Visible = false
		end
	end)
end

local function needCoins(button: GuiObject, price: number)
	UIStyle.deny(button)
	tell(`You need {UIStyle.commas(price - attribute("Coins"))} more coins`)
end

-- What an upgrade does at a level, e.g. "4 per press" or "38 studs".
local function effect(id: string, level: number): string
	local value = GameConfig.upgradeValue(id, level)
	if id == "PlantingRange" then
		return `{GameConfig.Planting.BaseRangeStuds + value} studs`
	end
	return `{value} per press`
end

local function refreshAll()
	for _, row in rows do
		local level = attribute(row.id .. "Level")
		local cost = GameConfig.upgradeCost(row.id, level + 1)
		local productId = GameConfig.UpgradeProducts[row.id][level + 1]
		row.robux.Visible = cost ~= nil and productId ~= nil
		for i, pip in row.pips do
			pip.BackgroundColor3 = if i <= level then PIP_ON else PIP_OFF
		end
		if cost then
			row.detail.Text = `{effect(row.id, level)}  →  <font color="#78ff5a">{effect(row.id, level + 1)}</font>`
			row.button.Text = `{UIStyle.commas(cost)} coins`
			local affordable = attribute("Coins") >= cost
			UIStyle.recolor(row.button, if affordable then UIStyle.Colors.Gold else UIStyle.Colors.Grey)
			if productId then
				row.robux.Text = UIStyle.priceText(productId, Enum.InfoType.Product, refreshAll)
			end
		else
			row.detail.Text = `{effect(row.id, level)}  (max level)`
			row.button.Text = "MAX"
			UIStyle.recolor(row.button, UIStyle.Colors.Grey)
		end
	end
end

local function restockNow(): number
	return GameConfig.restockIndex(workspace:GetServerTimeNow())
end

-- How many of a seed you can still buy this restock.
local function seedsLeft(def: GameConfig.SeedDef, restock: number, stock: { [string]: number }): number
	local bought = if attribute("ShopRestock") == restock then attribute(`Bought_{def.Id}`) else 0
	return math.max(0, stock[def.Id] - bought)
end

local function refreshSeeds()
	local restock = restockNow()
	local stock = GameConfig.seedStock(restock)
	local secondsLeft = (restock + 1) * GameConfig.SeedShop.RestockSeconds - workspace:GetServerTimeNow()
	if restockLabel then
		restockLabel.Text = `New seeds in {UIStyle.clock(secondsLeft)}`
	end
	for _, row in seedRows do
		local left = seedsLeft(row.def, restock, stock)
		if stock[row.def.Id] == 0 then
			row.stock.Text, row.stock.TextColor3 = "Not in stock", UIStyle.GREY
		elseif left == 0 then
			row.stock.Text, row.stock.TextColor3 = "Sold out", Color3.fromRGB(255, 110, 110)
		else
			row.stock.Text, row.stock.TextColor3 = `x{left} in stock`, UIStyle.PRICE
		end
		local can = left > 0 and attribute("Coins") >= row.def.Price
		UIStyle.recolor(row.button, if can then UIStyle.Colors.Gold else UIStyle.Colors.Grey)
		row.robux.Text = UIStyle.priceText(row.def.ProductId, Enum.InfoType.Product)
	end
end

local function showPage(name: string)
	page = name
	for key, frame in pages do
		frame.Visible = key == name
	end
	if titleLabel then
		titleLabel.Text = TITLES[name]
	end
	if name == "Seeds" then
		refreshSeeds()
	end
end

local function buildSeedsPage(panel: Frame)
	-- Scrolls on phones, where the five seeds are taller than the screen (polish pass mobile check).
	local seeds = Instance.new("ScrollingFrame")
	seeds.Name = "Seeds"
	seeds.BackgroundTransparency = 1
	seeds.BorderSizePixel = 0
	seeds.Size = UDim2.new(1, 0, 0, if UIStyle.isTouch() then SEEDS_HEIGHT_TOUCH else SEEDS_HEIGHT)
	seeds.CanvasSize = UDim2.new()
	seeds.AutomaticCanvasSize = Enum.AutomaticSize.Y
	seeds.ScrollBarThickness = if UIStyle.isTouch() then 8 else 0
	seeds.ScrollingDirection = Enum.ScrollingDirection.Y
	seeds.LayoutOrder = 2
	seeds.Parent = panel
	UIStyle.list(seeds, false, 10).VerticalAlignment = Enum.VerticalAlignment.Top
	if UIStyle.isTouch() then
		local pad = Instance.new("UIPadding")
		pad.PaddingRight = UDim.new(0, 12) -- room for the scroll bar
		pad.Parent = seeds
	end
	pages.Seeds = seeds
	local top = Instance.new("Frame")
	top.BackgroundTransparency = 1
	top.AutomaticSize = Enum.AutomaticSize.XY
	top.Parent = seeds
	UIStyle.list(top, true, 8)
	UIStyle.icon(top, UIStyle.Icons.Restock, 30)
	restockLabel = UIStyle.text(top, "", 24, UIStyle.GOLD);
	(restockLabel :: TextLabel).LayoutOrder = 2
	for i, def in GameConfig.SeedShop.Seeds do
		local frame = UIStyle.card(seeds, 96, Trees.RarityColors[def.Rarity])
		frame.LayoutOrder = i
		local picture = SeedBagController.preview(frame, def.Id, 84)
		picture.Position = UDim2.fromOffset(6, 6)
		local name = UIStyle.text(frame, `{def.DisplayName}`, 26, Trees.RarityColors[def.Rarity])
		name.Position = UDim2.fromOffset(94, 6)
		local rarity = UIStyle.text(frame, def.Rarity, 16, Trees.RarityColors[def.Rarity])
		rarity.Position = UDim2.fromOffset(94, 34)
		-- The boosts, one per line so they stay clear of the buttons.
		local own = UIStyle.text(frame, `+{math.round(def.OwnerBoost * 100)}% training for you`, 16, UIStyle.GREY)
		own.Position = UDim2.fromOffset(94, 54)
		if def.ServerBoost > 0 then
			local everyone = UIStyle.text(frame, `+{def.ServerBoost}x for everyone`, 16, UIStyle.GREY)
			everyone.Position = UDim2.fromOffset(94, 74)
		end
		local stock = UIStyle.text(frame, "", 18)
		stock.AnchorPoint = Vector2.new(1, 0)
		stock.Position = UDim2.new(1, -12, 0, 6)
		local robux = UIStyle.button(frame, "", UIStyle.Colors.Green, UDim2.fromOffset(84, 40), 22)
		robux.AnchorPoint = Vector2.new(1, 1)
		robux.Position = UDim2.new(1, -10, 1, -8)
		local button =
			UIStyle.button(frame, `{UIStyle.commas(def.Price)} coins`, UIStyle.Colors.Gold, UDim2.fromOffset(130, 40), 20)
		button.AnchorPoint = Vector2.new(1, 1)
		button.Position = UDim2.new(1, -104, 1, -8)
		table.insert(seedRows, { def = def, frame = frame, stock = stock, button = button, robux = robux })
		button.Activated:Connect(function()
			local restock = restockNow()
			local stockNow = GameConfig.seedStock(restock)
			if stockNow[def.Id] == 0 then
				UIStyle.deny(button)
				tell(`{def.DisplayName} isn't in stock right now`)
			elseif seedsLeft(def, restock, stockNow) == 0 then
				UIStyle.deny(button)
				tell("Sold out! Come back after the restock")
			elseif attribute("Coins") < def.Price then
				needCoins(button, def.Price)
			else
				Remotes.event("BuySeed"):FireServer(def.Id)
			end
		end)
		robux.Activated:Connect(function()
			MarketplaceService:PromptProductPurchase(localPlayer, def.ProductId)
		end)
		-- A seed arrived in the bag (bought here, for Robux or from a code): flash its card.
		local last = localPlayer:GetAttribute(`Bag_{def.Id}`)
		localPlayer:GetAttributeChangedSignal(`Bag_{def.Id}`):Connect(function()
			local now = localPlayer:GetAttribute(`Bag_{def.Id}`)
			if typeof(now) == "number" and typeof(last) == "number" and now > last then
				Sounds.play("Purchase")
				UIStyle.flash(frame)
			end
			last = now
		end)
	end
end

local function buildPanel(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ScreenInsets = Enum.ScreenInsets.None -- centered on the whole screen, not the area under the top bar
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5) -- the screen's middle (was a little low; the Forest Bar is up in the top bar now)
	holder.Size = UDim2.fromOffset(WIDTH, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	UIStyle.autoScale(holder, if UIStyle.isTouch() then 1 else GROW) -- bigger on desktop, like Build the Pyramid's upgrades
	UIStyle.blurBehind(gui)
	local panel = UIStyle.panel(holder)
	panel.Size = UDim2.fromScale(1, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	UIStyle.padding(panel, 18)
	UIStyle.list(panel, false, 12)
	UIStyle.closeButton(holder, function()
		dismissed = true
		gui.Enabled = false
	end)

	local title = UIStyle.text(panel, "", 44, UIStyle.GOLD)
	title.Name = "Title"
	title.LayoutOrder = 0
	titleLabel = title
	local upgrades = Instance.new("Frame")
	upgrades.Name = "Upgrades"
	upgrades.BackgroundTransparency = 1
	upgrades.Size = UDim2.fromScale(1, 0)
	upgrades.AutomaticSize = Enum.AutomaticSize.Y
	upgrades.LayoutOrder = 1
	upgrades.Parent = panel
	UIStyle.list(upgrades, false, 12)
	pages.Upgrades = upgrades
	buildSeedsPage(panel)
	for i, id in GameConfig.ShopUpgrades do
		local def = GameConfig.Upgrades[id]
		local frame = UIStyle.card(upgrades, 84)
		frame.LayoutOrder = i
		local icon = UIStyle.icon(frame, UIStyle.Icons[id] or UIStyle.Icons.Shop, 60)
		icon.Position = UDim2.fromOffset(10, 12)
		local name = UIStyle.text(frame, def.DisplayName, 28)
		name.Position = UDim2.fromOffset(80, 6)
		local pipRow = Instance.new("Frame")
		pipRow.BackgroundTransparency = 1
		pipRow.Position = UDim2.fromOffset(82, 62)
		pipRow.AutomaticSize = Enum.AutomaticSize.XY
		pipRow.Parent = frame
		UIStyle.list(pipRow, true, 4)
		local pips = {}
		for level = 1, def.MaxLevel do
			local pip = Instance.new("Frame")
			pip.Size = UDim2.fromOffset(PIP, PIP)
			pip.LayoutOrder = level
			pip.BackgroundColor3 = PIP_OFF
			pip.Parent = pipRow
			UIStyle.corner(pip, 5)
			UIStyle.stroke(pip, 2, nil, true)
			table.insert(pips, pip)
		end
		local detail = UIStyle.text(frame, "", 18, UIStyle.GREY)
		detail.RichText = true
		detail.Position = UDim2.fromOffset(80, 36)
		local robux = UIStyle.button(frame, "", UIStyle.Colors.Green, UDim2.fromOffset(84, 44), 24)
		robux.AnchorPoint = Vector2.new(1, 0.5)
		robux.Position = UDim2.new(1, -10, 0.5, 0)
		local button = UIStyle.button(frame, "", UIStyle.Colors.Gold, UDim2.fromOffset(130, 44), 22)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -104, 0.5, 0)
		table.insert(rows, { id = id, frame = frame, detail = detail, pips = pips, button = button, robux = robux })
		button.Activated:Connect(function()
			local cost = GameConfig.upgradeCost(id, attribute(id .. "Level") + 1)
			if not cost then
				UIStyle.deny(button)
				tell(`{def.DisplayName} is at its max level`)
			elseif attribute("Coins") < cost then
				needCoins(button, cost)
			else
				Remotes.event("BuyUpgrade"):FireServer(id)
			end
		end)
		robux.Activated:Connect(function()
			local productId = GameConfig.UpgradeProducts[id][attribute(id .. "Level") + 1]
			if productId then
				MarketplaceService:PromptProductPurchase(localPlayer, productId)
			end
		end)
	end
	-- A short message line (not enough coins and so on); hidden otherwise. It used to say "Step out of the ring
	-- to close." (removed 2026-10-07, the user's call).
	local hint = UIStyle.text(panel, "", 20, Color3.fromRGB(255, 120, 110))
	hint.LayoutOrder = 10
	hint.Visible = false
	hintLabel = hint
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	return gui
end

function ShopController.start()
	local gui = buildPanel()
	localPlayer:GetAttributeChangedSignal("Coins"):Connect(refreshAll)
	for _, row in rows do
		-- nil until the save loads: the first value is the save, not a purchase, so no banner for it.
		local last = localPlayer:GetAttribute(row.id .. "Level")
		localPlayer:GetAttributeChangedSignal(row.id .. "Level"):Connect(function()
			local level = attribute(row.id .. "Level")
			if typeof(last) == "number" and level > last then
				HUD.banner(`{GameConfig.Upgrades[row.id].DisplayName} level {level}!`)
				Sounds.play("LevelUp")
				UIStyle.flash(row.frame)
			end
			last = level
			refreshAll()
		end)
	end
	refreshAll()
	showPage(page)
	for _, def in GameConfig.SeedShop.Seeds do
		localPlayer:GetAttributeChangedSignal(`Bought_{def.Id}`):Connect(refreshSeeds)
	end
	localPlayer:GetAttributeChangedSignal("Coins"):Connect(refreshSeeds)
	local lastRestock = restockNow()
	while true do
		task.wait(CHECK_SECONDS)
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local ring = if root and root:IsA("BasePart") then ringPage(root) else nil
		if not ring then
			dismissed = false -- stepping out resets the X
		end
		gui.Enabled = ring ~= nil and not dismissed
		if ring and ring ~= page then
			showPage(ring)
		end
		if gui.Enabled and page == "Seeds" then
			refreshSeeds() -- the countdown
		end
		local restock = restockNow()
		if restock ~= lastRestock and GameConfig.Features.SeedShop then
			lastRestock = restock
			-- Everyone hears about the rarest seeds coming into stock.
			local stock = GameConfig.seedStock(restock)
			for i = #GameConfig.SeedShop.Seeds, 1, -1 do
				local def = GameConfig.SeedShop.Seeds[i]
				if stock[def.Id] > 0 and def.ServerBoost > 0 then
					HUD.banner(`{def.DisplayName} seeds are in the shop!`, Trees.RarityColors[def.Rarity])
					Sounds.play("Notify")
					break
				end
			end
		end
	end
end

return ShopController
