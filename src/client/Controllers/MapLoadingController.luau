--!strict
-- MapLoadingController: the loading screen while the server swaps the canyon's map (MapService, 2026-10-11): ForestState
-- MapLoading holds the canyon's name while it runs ("" otherwise). A dark screen with black and yellow hazard bands top
-- and bottom and "HEADING TO <canyon>", fading in and out, over everything. Since 2026-10-11 the canyon's own picture
-- fills it (GameConfig.LoadingArt: its finished bridge), darkened toward the middle so the words read.
-- The server's swap ends before this device has the new ground (the terrain streams in afterwards: the first try lifted
-- the screen onto camp floating on a lone column of rock), so the screen stays up, and the character held still, until
-- there is terrain on a ring around the player (READY_RING) or READY_TIMEOUT passes.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local UIStyle = require(script.Parent.Parent.UIStyle)

local STRIPES = "rbxassetid://78813724066207" -- assets/textures/hazard_tape.png, tinted yellow (UIStyle's window rims)
local YELLOW = Color3.fromRGB(250, 196, 30)
local FADE = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local READY_RING = { radius = 260, points = 8, need = 7 } -- columns around the player that must have ground
local READY_TIMEOUT = 20 -- seconds after the swap at most

-- Is there terrain in the column at (x, z) (anything solid from the canyon's floor to above the rims)?
local function hasGround(x: number, z: number): boolean
	local region = Region3.new(Vector3.new(x - 2, -2600, z - 2), Vector3.new(x + 2, 900, z + 2)):ExpandToGrid(4)
	local materials = workspace.Terrain:ReadVoxels(region, 4)
	for _, layer in materials do
		for _, row in layer do
			for _, material in row do
				if material ~= Enum.Material.Air then
					return true
				end
			end
		end
	end
	return false
end

-- Waits until this device has the new terrain around the player (or the timeout), holding the character still.
local function waitForGround()
	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	root.Anchored = true -- only on this device: the character's physics is ours
	local center = root.Position
	pcall(player.RequestStreamAroundAsync, player, center, READY_TIMEOUT)
	local started = os.clock()
	while os.clock() - started < READY_TIMEOUT do
		local found = 0
		for i = 1, READY_RING.points do
			local angle = i / READY_RING.points * math.pi * 2
			if hasGround(center.X + math.cos(angle) * READY_RING.radius, center.Z + math.sin(angle) * READY_RING.radius) then
				found += 1
			end
		end
		if found >= READY_RING.need then
			break
		end
		task.wait(0.25)
	end
	root.Anchored = false
end

local MapLoadingController = {}

local function band(parent: Instance, top: boolean)
	local stripes = Instance.new("ImageLabel")
	stripes.Image = STRIPES
	stripes.ImageColor3 = YELLOW
	stripes.ScaleType = Enum.ScaleType.Tile
	stripes.TileSize = UDim2.fromOffset(64, 64)
	stripes.BackgroundColor3 = Color3.new(0, 0, 0)
	stripes.BorderSizePixel = 0
	stripes.AnchorPoint = Vector2.new(0, if top then 0 else 1)
	stripes.Position = UDim2.fromScale(0, if top then 0 else 1)
	stripes.Size = UDim2.new(1, 0, 0, 40)
	stripes.Parent = parent
end

function MapLoadingController.start()
	local forestState = ReplicatedStorage:WaitForChild("ForestState")
	local gui = Instance.new("ScreenGui")
	gui.Name = "MapLoading"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100 -- over every window and the HUD
	gui.Enabled = false
	local cover = Instance.new("CanvasGroup")
	cover.Size = UDim2.fromScale(1, 1)
	cover.BackgroundColor3 = Color3.fromRGB(24, 21, 18)
	cover.BorderSizePixel = 0
	cover.GroupTransparency = 1
	cover.BackgroundTransparency = 1
	cover.Parent = gui
	-- The dark backdrop as its own frame: the CanvasGroup's own background didn't draw (the game showed through).
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(24, 21, 18)
	backdrop.BackgroundTransparency = 0
	backdrop.BorderSizePixel = 0
	backdrop.Parent = cover
	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.Size = UDim2.fromScale(1, 1)
	art.BackgroundTransparency = 1
	art.ScaleType = Enum.ScaleType.Crop
	art.Parent = cover
	local shade = Instance.new("Frame") -- darker toward the bottom, where the words are
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BorderSizePixel = 0
	shade.Parent = cover
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(0.55, 0.75),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	fade.Parent = shade
	local pictures = {}
	for _, image in GameConfig.LoadingArt do
		table.insert(pictures, image)
	end
	task.spawn(ContentProvider.PreloadAsync, ContentProvider, pictures) -- ready before the first swap
	band(cover, true)
	band(cover, false)
	local words = Instance.new("Frame")
	-- Bottom left, over the lower hazard band (2026-10-11, the user's ask; it was in the middle).
	words.AnchorPoint = Vector2.new(0, 1)
	words.Position = UDim2.new(0, 56, 1, -64)
	words.AutomaticSize = Enum.AutomaticSize.XY
	words.BackgroundTransparency = 1
	words.Parent = cover
	UIStyle.list(words, false, 6)
	UIStyle.autoScale(words)
	local heading = UIStyle.text(words, "HEADING TO", 36, UIStyle.GREY)
	heading.LayoutOrder = 1
	local name = UIStyle.text(words, "", 84, YELLOW)
	name.LayoutOrder = 2
	local place = UIStyle.text(words, "", 34, UIStyle.WHITE) -- the real canyon's location ("Zion National Park, Utah")
	place.LayoutOrder = 3
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local shown = 0
	local function refresh()
		local label = forestState:GetAttribute("MapLoading")
		shown += 1
		local mine = shown
		if typeof(label) == "string" and label ~= "" then
			name.Text = string.upper(label)
			art.Image, place.Text = "", ""
			for _, tier in GameConfig.Tiers do
				if tier.Name == label then
					art.Image = GameConfig.LoadingArt[tier.Map] or ""
					place.Text = tier.Place
				end
			end
			gui.Enabled = true
			TweenService:Create(cover, FADE, { GroupTransparency = 0 }):Play()
		elseif gui.Enabled then
			task.spawn(function()
				waitForGround()
				if shown ~= mine then
					return -- another swap began meanwhile
				end
				TweenService:Create(cover, FADE, { GroupTransparency = 1 }):Play()
				task.delay(FADE.Time, function()
					if shown == mine then
						gui.Enabled = false
					end
				end)
			end)
		end
	end
	forestState:GetAttributeChangedSignal("MapLoading"):Connect(refresh)
	refresh()
end

return MapLoadingController
