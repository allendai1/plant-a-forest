--!strict
-- NameplateController: the rank over every player's head (2026-10-07). Each character gets a nameplate: their
-- forest count inside the forest icon on top (like Build the Pyramid's pyramid badge, 2026-10-07), their rank
-- (GameConfig.Ranks by their ForestsCompleted attribute, in the rank's color) and their name underneath, in the
-- HUD's outlined text. It replaces Roblox's own name tag (hidden on this client). Everyone, yourself
-- included, sees everyone's. Reaching a new rank yourself plays a "Rank up!" banner and the level-up sound.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local HUD = require(script.Parent.HUD)
local Sounds = require(script.Parent.Parent.Sounds)
local UIStyle = require(script.Parent.Parent.UIStyle)

local ABOVE_HEAD = 2.4 -- studs above the head's center to the plate's bottom edge (clears the outfits' hats)
local ICON = 46 -- the forest badge, in pixels (of the DESIGN layout)
local PLATE_STUDS = 7.5 -- the plate's width in the world: about its old size at the default zoom
local DESIGN = Vector2.new(320, 120) -- the layout's size in pixels before it's scaled to the plate
local MAX_DISTANCE = 200 -- nameplates farther away than this aren't drawn (past the 150-stud max zoom, so yours stays)
local RAINBOW_SPEED = 0.25 -- turns per second of the top rank's rainbow

local NameplateController = {}

local localPlayer = Players.LocalPlayer
local plates: { [Player]: BillboardGui } = {}
local rainbows: { UIGradient } = {}

local function forestsOf(player: Player): number
	local value = player:GetAttribute("ForestsCompleted")
	return if typeof(value) == "number" then value else 0
end

local function build(player: Player, head: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = `Nameplate_{player.Name}`
	gui.Adornee = head
	-- Sized in studs, so it shrinks as you zoom out (the user's ask, 2026-10-08; it was a fixed 320 x 120 pixels).
	-- The layout inside is drawn at DESIGN pixels and scaled to the plate's size on screen.
	gui.Size = UDim2.fromScale(PLATE_STUDS, PLATE_STUDS * DESIGN.Y / DESIGN.X)
	gui.SizeOffset = Vector2.new(0, 0.5) -- grows up from the offset point, so a bigger plate never covers the head
	gui.StudsOffsetWorldSpace = Vector3.new(0, ABOVE_HEAD, 0)
	gui.MaxDistance = MAX_DISTANCE
	gui.ResetOnSpawn = false
	gui.LightInfluence = 0
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y)
	content.Parent = gui
	local fit = Instance.new("UIScale")
	fit.Parent = content
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fit.Scale = gui.AbsoluteSize.X / DESIGN.X
	end)
	-- The forest badge: the forest icon with the forest count on it.
	local badge = UIStyle.icon(content, UIStyle.Icons.Forests, ICON)
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.fromScale(0.5, 0)
	local count = UIStyle.text(badge, "", 20, UIStyle.WHITE)
	count.Name = "Count"
	count.AutomaticSize = Enum.AutomaticSize.None
	count.Size = UDim2.fromScale(1, 0.5)
	count.Position = UDim2.fromScale(0, 0.42)
	local rank = UIStyle.text(content, "", 32)
	rank.Name = "Rank"
	rank.AutomaticSize = Enum.AutomaticSize.None
	rank.Size = UDim2.new(1, 0, 0, 34)
	rank.Position = UDim2.fromOffset(0, ICON + 2)
	local name = UIStyle.text(content, player.DisplayName, 30, UIStyle.WHITE)
	name.Name = "PlayerName"
	name.AutomaticSize = Enum.AutomaticSize.None
	name.Size = UDim2.new(1, 0, 0, 32)
	name.Position = UDim2.fromOffset(0, ICON + 38)
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	return gui
end

local function refresh(player: Player)
	local gui = plates[player]
	if not gui then
		return
	end
	gui.Enabled = player:GetAttribute("NameplateHidden") ~= true -- TrainingController hides a benching player's double
	local forests = forestsOf(player)
	local rank = GameConfig.rankFor(forests)
	local count = gui:FindFirstChild("Count", true) :: TextLabel
	count.Text = UIStyle.short(forests)
	local label = gui:FindFirstChild("Rank", true) :: TextLabel
	label.Text = rank.Name
	label.TextColor3 = rank.Color
	-- The top rank's rainbow: a gradient on the label's colored face.
	local face = label:FindFirstChild("Face")
	local gradient = face and face:FindFirstChildOfClass("UIGradient")
	if rank.Rainbow and face and not gradient then
		local rainbow = Instance.new("UIGradient")
		rainbow.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 90)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 255, 140)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(110, 170, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 120, 255)),
		})
		rainbow.Parent = face
		table.insert(rainbows, rainbow)
		label.TextColor3 = UIStyle.WHITE -- the gradient tints white
	elseif not rank.Rainbow and gradient then
		gradient:Destroy()
	end
end

local function attach(player: Player, character: Model)
	local old = plates[player]
	if old then
		old:Destroy()
		plates[player] = nil
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	local head = character:WaitForChild("Head", 10)
	if not (humanoid and humanoid:IsA("Humanoid") and head and head:IsA("BasePart")) then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- our nameplate replaces it
	plates[player] = build(player, head)
	refresh(player)
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		attach(player, character)
	end)
	if player.Character then
		task.spawn(attach, player, player.Character)
	end
	-- The rank follows the forest count; your own rank-up gets a banner.
	local lastRank = GameConfig.rankFor(forestsOf(player)).Name
	local loaded = player:GetAttribute("ForestsCompleted") ~= nil
	player:GetAttributeChangedSignal("NameplateHidden"):Connect(function()
		refresh(player)
	end)
	player:GetAttributeChangedSignal("ForestsCompleted"):Connect(function()
		refresh(player)
		local rank = GameConfig.rankFor(forestsOf(player))
		if player == localPlayer and loaded and rank.Name ~= lastRank then
			HUD.banner(`Rank up! You're now a {rank.Name}!`, rank.Color)
			Sounds.play("LevelUp")
		end
		lastRank = rank.Name
		loaded = true -- the first value is the save loading, not a rank-up
	end)
end

function NameplateController.start()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local gui = plates[player]
		if gui then
			gui:Destroy()
		end
		plates[player] = nil
	end)
	RunService.Heartbeat:Connect(function()
		local turn = (os.clock() * RAINBOW_SPEED % 1) * 2 - 1
		for i = #rainbows, 1, -1 do
			local gradient = rainbows[i]
			if gradient.Parent then
				gradient.Offset = Vector2.new(turn, 0)
			else
				table.remove(rainbows, i)
			end
		end
	end)
end

return NameplateController
