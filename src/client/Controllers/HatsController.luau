--!strict
-- HatsController: the HARD HATS window (2026-10-11, the user's ask), opened by the Hats button in the top bar (HUD).
-- Every rank's hard hat (GameConfig.Ranks[].Hat) as a card: the ones whose rank you've reached can be equipped, the
-- rest show the bridges they need. Equipping sends EquipHat (OutfitService paints the hat on your character and saves
-- the pick as EquippedHat); picking your newest one saves 0, so the newest follows you up the ranks. Each card shows
-- the helmet itself (Assets.RankHat, the Builders Club Hard Hat's handle) in a viewport, painted like the real one.
-- A character pass outfit (Builderman) brings its own hat, so the window says so while you own one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIStyle = require(script.Parent.Parent.UIStyle)

local COLUMNS = 4
local CARD = Vector2.new(150, 170)
local GAP = 12
-- Room round the cards inside the scrolling list, so their outlines aren't clipped at its edges, and the scrollbar's
-- own strip (the user, 2026-10-11: borders were cut off).
local EDGE = 6
local SCROLLBAR = 8
local PICKED = Color3.fromRGB(255, 205, 80) -- the equipped card's outline
local LOCKED_SHADE = 0.45 -- a locked card's dark cover

local HatsController = {}

local localPlayer = Players.LocalPlayer
local gui: ScreenGui? = nil

function HatsController.toggle()
	if gui then
		gui.Enabled = not gui.Enabled
	end
end

local function number(name: string): number
	local value = localPlayer:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

-- The rank whose hat you have on (your pick if you've reached it, else your newest).
local function wornIndex(): number
	local reached = GameConfig.rankIndexFor(number("ForestsCompleted"))
	local picked = number("EquippedHat")
	return if picked >= 1 and picked <= reached then picked else reached
end

-- The helmet in a card, painted like OutfitService paints the real one.
local function preview(parent: GuiObject, rank: GameConfig.Rank)
	local view = Instance.new("ViewportFrame")
	view.BackgroundTransparency = 1
	view.Size = UDim2.new(1, 0, 0, 100)
	view.Position = UDim2.fromOffset(0, 8)
	view.LightDirection = Vector3.new(-1, -2, -1)
	view.Ambient = Color3.fromRGB(170, 170, 170)
	view.Parent = parent
	local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("RankHat") :: MeshPart
	local hat = template:Clone()
	local look = rank.Hat
	hat.TextureID = look.Texture
	hat.Color = Color3.new(1, 1, 1)
	hat.Material = look.Material or Enum.Material.Plastic
	if look.Rainbow then
		CollectionService:AddTag(hat, "RainbowHat") -- RainbowTextController cycles it
	end
	hat.CFrame = CFrame.Angles(math.rad(-12), math.rad(200), 0)
	hat.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 24
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 1, 3.6), Vector3.new(0, 0.05, 0))
	camera.Parent = view
	view.CurrentCamera = camera
end

type Card = { index: number, frame: Frame, button: TextButton, shade: Frame, ring: UIStroke }

function HatsController.start()
	local screen = Instance.new("ScreenGui")
	screen.Name = "Hats"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	screen.DisplayOrder = 2
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	UIStyle.blurBehind(screen)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(COLUMNS * CARD.X + (COLUMNS - 1) * GAP + 2 * EDGE + SCROLLBAR + 36, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.Parent = screen
	UIStyle.windowScale(holder)
	local panel = UIStyle.panel(holder)
	panel.Size = UDim2.fromScale(1, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	UIStyle.padding(panel, 18)
	UIStyle.list(panel, false, 10, Enum.HorizontalAlignment.Center)
	UIStyle.closeButton(holder, HatsController.toggle)
	UIStyle.text(panel, "HARD HATS", 44, UIStyle.GOLD).LayoutOrder = 1
	local hint = UIStyle.text(panel, "Rank up by building bridges to unlock more!", 20, UIStyle.GREY)
	hint.LayoutOrder = 2
	local outfitNote = UIStyle.text(panel, "Your Builderman outfit wears its own hard hat.", 20, Color3.fromRGB(255, 170, 90))
	outfitNote.LayoutOrder = 3

	-- The cards scroll: four across, so 13 make four rows.
	local scroller = Instance.new("ScrollingFrame")
	scroller.LayoutOrder = 4
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = UDim2.new(1, 0, 0, 2 * CARD.Y + GAP + 30 + 2 * EDGE)
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.CanvasSize = UDim2.new()
	scroller.ScrollBarThickness = SCROLLBAR
	scroller.VerticalScrollBarInset = Enum.ScrollBarInset.Always -- the cards never sit under the scrollbar
	local edge = Instance.new("UIPadding")
	edge.PaddingTop, edge.PaddingBottom = UDim.new(0, EDGE), UDim.new(0, EDGE)
	edge.PaddingLeft, edge.PaddingRight = UDim.new(0, EDGE), UDim.new(0, EDGE)
	edge.Parent = scroller
	scroller.ScrollingDirection = Enum.ScrollingDirection.Y
	scroller.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(CARD.X, CARD.Y)
	grid.CellPadding = UDim2.fromOffset(GAP, GAP)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroller

	local cards: { Card } = {}
	for i, rank in GameConfig.Ranks do
		local frame = UIStyle.card(scroller, CARD.Y)
		frame.LayoutOrder = i
		preview(frame, rank)
		local name = UIStyle.text(frame, rank.Name, 18, rank.Color)
		name.AutomaticSize = Enum.AutomaticSize.None
		name.Size = UDim2.new(1, -10, 0, 20)
		name.Position = UDim2.new(0, 5, 0, 104)
		name.TextScaled = true
		local button = UIStyle.button(frame, "", UIStyle.Colors.Green, UDim2.new(1, -20, 0, 34), 18)
		button.AnchorPoint = Vector2.new(0.5, 1)
		button.Position = UDim2.new(0.5, 0, 1, -8)
		local shade = Instance.new("Frame")
		shade.Size = UDim2.fromScale(1, 1)
		shade.BackgroundColor3 = Color3.new(0, 0, 0)
		shade.BackgroundTransparency = LOCKED_SHADE
		shade.ZIndex = 5
		shade.Parent = frame
		UIStyle.corner(shade, 12)
		local need = UIStyle.text(shade, `🔒 {UIStyle.commas(rank.Forests)} bridges`, 20)
		need.AnchorPoint = Vector2.new(0.5, 0.5)
		need.Position = UDim2.fromScale(0.5, 0.82)
		-- The equipped card's gold outline, on its own frame (the card has its own stroke).
		local outline = Instance.new("Frame")
		outline.BackgroundTransparency = 1
		outline.Size = UDim2.fromScale(1, 1)
		outline.ZIndex = 6
		outline.Parent = frame
		UIStyle.corner(outline, 12)
		local ring = UIStyle.stroke(outline, 4, PICKED, true)
		local card: Card = { index = i, frame = frame, button = button, shade = shade, ring = ring }
		button.Activated:Connect(function()
			local reached = GameConfig.rankIndexFor(number("ForestsCompleted"))
			if i > reached or i == wornIndex() then
				UIStyle.deny(button)
				return
			end
			-- Your newest hat: 0, so it keeps following you as you rank up.
			Remotes.event("EquipHat"):FireServer(if i == reached then 0 else i)
		end)
		table.insert(cards, card)
	end

	local function refresh()
		local reached = GameConfig.rankIndexFor(number("ForestsCompleted"))
		local worn = wornIndex()
		for _, card in cards do
			local owned = card.index <= reached
			card.shade.Visible = not owned
			card.button.Visible = owned
			card.ring.Enabled = owned and card.index == worn
			card.button.Text = if card.index == worn then "Equipped" else "Equip"
			UIStyle.recolor(card.button, if card.index == worn then UIStyle.Colors.Grey else UIStyle.Colors.Green)
		end
		outfitNote.Visible = number("HandsSpeed") > 1
	end
	for _, name in { "ForestsCompleted", "EquippedHat", "HandsSpeed" } do
		localPlayer:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
	screen.Parent = localPlayer:WaitForChild("PlayerGui")
	gui = screen
end

return HatsController
