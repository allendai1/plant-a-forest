--!strict
-- TreeCounterController: the hub's counter of every tree grown in every server (2026-10-09). Each part tagged
-- TreeCounterBoard gets a SurfaceGui on its front face: "TREES GROWN", the total (ReplicatedStorage attribute
-- TreesGrown, from TreeCounterService) counting up smoothly to each new value, and your own trees (the
-- TreesFinished attribute: trees you planted the last acorn of).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIStyle = require(script.Parent.Parent.UIStyle)

local PIXELS_PER_STUD = 30
local COUNT_UP = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local TreeCounterController = {}

local localPlayer = Players.LocalPlayer
local drawn: { [BasePart]: SurfaceGui } = {}

local function number(instance: Instance, attribute: string): number
	local value = instance:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 0
end

local function draw(board: BasePart)
	if drawn[board] then
		return
	end
	local surface = Instance.new("SurfaceGui")
	surface.Name = "TreeCounter"
	surface.Adornee = board
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = PIXELS_PER_STUD
	surface.LightInfluence = 0
	surface.MaxDistance = 250
	surface.ResetOnSpawn = false
	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.Size = UDim2.fromScale(1, 1)
	column.Parent = surface
	local layout = UIStyle.list(column, false, 8, Enum.HorizontalAlignment.Center)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	local title = Instance.new("Frame")
	title.BackgroundTransparency = 1
	title.AutomaticSize = Enum.AutomaticSize.XY
	title.LayoutOrder = 1
	title.Parent = column
	UIStyle.list(title, true, 12, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Center
	UIStyle.icon(title, UIStyle.Icons.Forests, 64)
	UIStyle.text(title, "TREES GROWN", 58, UIStyle.GOLD).LayoutOrder = 2
	local total = UIStyle.text(column, "0", 110)
	total.LayoutOrder = 2
	local by = UIStyle.text(column, "by everyone playing Plant Trees!", 28, UIStyle.GREY)
	by.LayoutOrder = 3
	local mine = UIStyle.text(column, "", 34, UIStyle.GOLD)
	mine.LayoutOrder = 4

	-- The total counts up to each new value instead of jumping.
	local shown = Instance.new("NumberValue")
	shown.Value = number(ReplicatedStorage, "TreesGrown")
	local function showTotal()
		total.Text = UIStyle.commas(shown.Value)
	end
	local function showMine()
		mine.Text = `You: {UIStyle.commas(number(localPlayer, "TreesFinished"))}`
	end
	shown.Changed:Connect(showTotal)
	local grown = ReplicatedStorage:GetAttributeChangedSignal("TreesGrown"):Connect(function()
		TweenService:Create(shown, COUNT_UP, { Value = number(ReplicatedStorage, "TreesGrown") }):Play()
	end)
	local own = localPlayer:GetAttributeChangedSignal("TreesFinished"):Connect(showMine)
	showTotal()
	showMine()
	surface.Parent = localPlayer:WaitForChild("PlayerGui")
	drawn[board] = surface
	board.AncestryChanged:Connect(function()
		if not board:IsDescendantOf(workspace) then
			grown:Disconnect()
			own:Disconnect()
			shown:Destroy()
			surface:Destroy()
			drawn[board] = nil
		end
	end)
end

function TreeCounterController.start()
	CollectionService:GetInstanceAddedSignal("TreeCounterBoard"):Connect(function(board)
		if board:IsA("BasePart") then
			draw(board)
		end
	end)
	for _, board in CollectionService:GetTagged("TreeCounterBoard") do
		if board:IsA("BasePart") then
			draw(board)
		end
	end
end

return TreeCounterController
