--!strict
-- LeaderboardController: draws the global leaderboards on the lobby boards (polish pass, 2026-10-07). Each
-- part tagged LeaderboardBoard (tools/build_map.luau) gets a SurfaceGui on its front face, in PlayerGui so it
-- can scroll, showing the top players of its Stat from ReplicatedStorage.Leaderboards.<Stat> (JSON from
-- LeaderboardService). The top three are gold, silver and bronze, and your own row is highlighted. Boards
-- that stream out and back in are drawn again.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local UIStyle = require(script.Parent.Parent.UIStyle)

local PIXELS_PER_STUD = 30 -- the 18 x 20 stud board is 540 x 600 pixels: about 9 rows show, the rest scroll
local ROW = 52
local PLACE_COLORS = { Color3.fromRGB(255, 215, 80), Color3.fromRGB(215, 220, 230), Color3.fromRGB(225, 150, 90) }
local MINE = Color3.fromRGB(90, 160, 80)
local ICONS: { [string]: UIStyle.Icon } = {
	Strength = UIStyle.Icons.Strength,
	Speed = UIStyle.Icons.Speed,
	ForestsCompleted = UIStyle.Icons.Forests,
}

type Entry = { id: number, name: string, value: number }

local LeaderboardController = {}

local localPlayer = Players.LocalPlayer
local drawn: { [BasePart]: SurfaceGui } = {}

local function entries(stat: string): { Entry }
	local folder = ReplicatedStorage:FindFirstChild("Leaderboards")
	local value = folder and folder:FindFirstChild(stat)
	if not (value and value:IsA("StringValue")) then
		return {}
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, value.Value)
	return if ok and typeof(list) == "table" then list else {}
end

local function fill(scroll: ScrollingFrame, stat: string)
	for _, child in scroll:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local list = entries(stat)
	if #list == 0 then
		local empty = Instance.new("Frame")
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.new(1, 0, 0, ROW)
		empty.Parent = scroll
		UIStyle.text(empty, "No one yet. Be the first!", 26, UIStyle.GREY).Position = UDim2.fromOffset(16, 8)
		return
	end
	for rank, entry in list do
		local row = Instance.new("Frame")
		row.LayoutOrder = rank
		row.Size = UDim2.new(1, 0, 0, ROW)
		row.BackgroundColor3 = if entry.id == localPlayer.UserId then MINE else Color3.fromRGB(58, 46, 36)
		row.BackgroundTransparency = if entry.id == localPlayer.UserId then 0.1 else (if rank % 2 == 0 then 0.6 else 0.3)
		row.Parent = scroll
		UIStyle.corner(row, 8)
		local color = PLACE_COLORS[rank] or UIStyle.WHITE
		local place = UIStyle.text(row, `#{rank}`, 32, color)
		place.Position = UDim2.fromOffset(10, 9)
		local name = UIStyle.text(row, entry.name, 30, color)
		name.Position = UDim2.fromOffset(84, 11)
		local value = UIStyle.text(row, UIStyle.short(entry.value), 32, color)
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.new(1, -12, 0, 9)
	end
end

local function draw(board: BasePart)
	local stat = board:GetAttribute("Stat")
	if typeof(stat) ~= "string" or drawn[board] then
		return
	end
	local surface = Instance.new("SurfaceGui")
	surface.Name = `Leaderboard_{stat}`
	surface.Adornee = board
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = PIXELS_PER_STUD
	surface.LightInfluence = 0
	surface.MaxDistance = 160
	surface.ResetOnSpawn = false
	local title = Instance.new("Frame")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 90)
	title.Parent = surface
	local layout = UIStyle.list(title, true, 12, Enum.HorizontalAlignment.Center)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	UIStyle.icon(title, ICONS[stat] or UIStyle.Icons.Trophy, 64)
	UIStyle.text(title, GameConfig.Leaderboards.Titles[stat] or stat, 58, UIStyle.GOLD).LayoutOrder = 2
	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.fromOffset(16, 96)
	scroll.Size = UDim2.new(1, -32, 1, -112)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 10
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = surface
	UIStyle.list(scroll, false, 4).VerticalAlignment = Enum.VerticalAlignment.Top
	surface.Parent = localPlayer:WaitForChild("PlayerGui")
	drawn[board] = surface
	fill(scroll, stat)
	local folder = ReplicatedStorage:WaitForChild("Leaderboards")
	local value = folder:WaitForChild(stat) :: StringValue
	local connection = value.Changed:Connect(function()
		fill(scroll, stat)
	end)
	board.AncestryChanged:Connect(function()
		if not board:IsDescendantOf(workspace) then
			connection:Disconnect()
			surface:Destroy()
			drawn[board] = nil
		end
	end)
end

function LeaderboardController.start()
	CollectionService:GetInstanceAddedSignal("LeaderboardBoard"):Connect(function(board)
		if board:IsA("BasePart") then
			draw(board)
		end
	end)
	for _, board in CollectionService:GetTagged("LeaderboardBoard") do
		if board:IsA("BasePart") then
			draw(board)
		end
	end
end

return LeaderboardController
