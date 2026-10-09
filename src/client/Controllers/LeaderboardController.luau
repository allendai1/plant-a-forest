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
	SeedsPlanted = UIStyle.Icons.BulkPlant, -- the planting icon
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

local VALUE_ROOM = 96 -- pixels kept free for the value at a row's right end (rows are ~330 px wide)
local AVATAR_X = 66 -- the headshot's left edge, after the rank

-- A player name that stops short of the value, cut off with "..." when it's long (UIStyle's outlined text draws a
-- Face and a Shadow copy; each is cut the same way).
local function nameLabel(row: Frame, text: string, left: number, color: Color3?): TextLabel
	local label = UIStyle.text(row, text, 26, color)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.Position = UDim2.fromOffset(left, 13)
	label.Size = UDim2.new(1, -(left + VALUE_ROOM), 0, 26)
	for _, item in { label :: Instance, unpack(label:GetChildren()) } do
		if item:IsA("TextLabel") then
			item.TextXAlignment = Enum.TextXAlignment.Left
			item.TextTruncate = Enum.TextTruncate.AtEnd
		end
	end
	return label
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
		-- Their avatar's headshot right of the rank (2026-10-08, the user's ask); Roblox serves it by user id.
		local face = Instance.new("ImageLabel")
		face.Name = "Avatar"
		face.BackgroundColor3 = Color3.fromRGB(30, 24, 18)
		face.BackgroundTransparency = 0.3
		face.Image = `rbxthumb://type=AvatarHeadShot&id={entry.id}&w=48&h=48`
		face.AnchorPoint = Vector2.new(0, 0.5)
		face.Position = UDim2.new(0, AVATAR_X, 0.5, 0)
		face.Size = UDim2.fromOffset(ROW - 10, ROW - 10)
		face.Parent = row
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = face
		nameLabel(row, entry.name, AVATAR_X + ROW - 2, color)
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
	scroll.Size = UDim2.new(1, -32, 1, -112 - ROW - 8) -- room for your own place at the bottom
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 10
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = surface
	UIStyle.list(scroll, false, 4).VerticalAlignment = Enum.VerticalAlignment.Top
	-- Your own place, always at the bottom (2026-10-08, the user's ask): your rank on this board, or #100+ when
	-- you're not in the top Size, with your avatar, name and current value.
	local mine = Instance.new("Frame")
	mine.Name = "You"
	mine.AnchorPoint = Vector2.new(0, 1)
	mine.Position = UDim2.new(0, 16, 1, -12)
	mine.Size = UDim2.new(1, -42, 0, ROW)
	mine.BackgroundColor3 = MINE
	mine.BackgroundTransparency = 0.1
	mine.Parent = surface
	UIStyle.corner(mine, 8)
	local place = UIStyle.text(mine, "", 32)
	place.Position = UDim2.fromOffset(10, 9)
	local face = Instance.new("ImageLabel")
	face.BackgroundColor3 = Color3.fromRGB(30, 24, 18)
	face.BackgroundTransparency = 0.3
	face.Image = `rbxthumb://type=AvatarHeadShot&id={localPlayer.UserId}&w=48&h=48`
	face.AnchorPoint = Vector2.new(0, 0.5)
	face.Position = UDim2.new(0, AVATAR_X + 22, 0.5, 0) -- room for "#100+"
	face.Size = UDim2.fromOffset(ROW - 10, ROW - 10)
	face.Parent = mine
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = face
	nameLabel(mine, localPlayer.DisplayName, AVATAR_X + 20 + ROW)
	local amount = UIStyle.text(mine, "", 32)
	amount.AnchorPoint = Vector2.new(1, 0)
	amount.Position = UDim2.new(1, -12, 0, 9)
	local function showMine()
		local rank: number? = nil
		for i, entry in entries(stat) do
			if entry.id == localPlayer.UserId then
				rank = i
				break
			end
		end
		place.Text = if rank then `#{rank}` else `#{GameConfig.Leaderboards.Size}+`
		local value = localPlayer:GetAttribute(stat)
		amount.Text = UIStyle.short(if typeof(value) == "number" then value else 0)
	end
	surface.Parent = localPlayer:WaitForChild("PlayerGui")
	drawn[board] = surface
	fill(scroll, stat)
	showMine()
	local folder = ReplicatedStorage:WaitForChild("Leaderboards")
	local value = folder:WaitForChild(stat) :: StringValue
	local connection = value.Changed:Connect(function()
		fill(scroll, stat)
		showMine()
	end)
	local mineConnection = localPlayer:GetAttributeChangedSignal(stat):Connect(showMine)
	board.AncestryChanged:Connect(function()
		if not board:IsDescendantOf(workspace) then
			connection:Disconnect()
			mineConnection:Disconnect()
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
