--!strict
-- Loading: the join loading screen (2026-10-11, the user's ask: players joined into the story intro before the terrain
-- was there). Replaces Roblox's default screen from the first frame, in the map loading screen's look
-- (MapLoadingController: the canyon's picture, hazard bands), with a bar that follows real work:
--   1. the game's instances arriving (game.Loaded),
--   2. the far scenery's meshes and textures downloading (ContentProvider, counted mesh by mesh),
--   3. the terrain streaming in around spawn and around the town across the canyon (the story intro flies there),
--   4. the bridge being built on this device (Workspace.BridgeView).
-- The character is held still meanwhile. When it's done, the LocalPlayer gets the (local) attribute Loaded, which the
-- story intro waits for (TutorialController), and the screen fades. Gives up waiting after GIVE_UP seconds.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local YELLOW = Color3.fromRGB(250, 196, 30)
local DARK = Color3.fromRGB(24, 21, 18)
local STRIPES = "rbxassetid://78813724066207" -- the hazard tape (UIStyle's window rims, MapLoadingController's bands)
local FONT = Enum.Font.GothamBlack
local GIVE_UP = 45 -- seconds: never keep someone out longer than this
local READY_RING = { radius = 260, points = 8, need = 7 } -- like MapLoadingController
local PRELOAD_BATCH = 40

ReplicatedFirst:RemoveDefaultLoadingScreen()

local gui = Instance.new("ScreenGui")
gui.Name = "JoinLoading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 200 -- over the HUD and the map loading screen
local cover = Instance.new("CanvasGroup")
cover.Size = UDim2.fromScale(1, 1)
cover.BackgroundTransparency = 1
cover.Parent = gui
local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = DARK
backdrop.BorderSizePixel = 0
backdrop.Parent = cover
local art = Instance.new("ImageLabel")
art.Size = UDim2.fromScale(1, 1)
art.BackgroundTransparency = 1
art.ScaleType = Enum.ScaleType.Crop
art.ImageTransparency = 1
art.Parent = cover
local shade = Instance.new("Frame")
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.new(0, 0, 0)
shade.BorderSizePixel = 0
shade.Parent = cover
local fade = Instance.new("UIGradient")
fade.Rotation = 90
fade.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.9),
	NumberSequenceKeypoint.new(0.55, 0.7),
	NumberSequenceKeypoint.new(1, 0.1),
})
fade.Parent = shade
for _, top in { true, false } do
	local band = Instance.new("ImageLabel")
	band.Image = STRIPES
	band.ImageColor3 = YELLOW
	band.ScaleType = Enum.ScaleType.Tile
	band.TileSize = UDim2.fromOffset(64, 64)
	band.BackgroundColor3 = Color3.new(0, 0, 0)
	band.BorderSizePixel = 0
	band.AnchorPoint = Vector2.new(0, if top then 0 else 1)
	band.Position = UDim2.fromScale(0, if top then 0 else 1)
	band.Size = UDim2.new(1, 0, 0, 40)
	band.Parent = cover
end

-- The words and the bar, bottom left, scaled with the screen's height (only this box: scaling the whole cover shrank
-- it into a corner).
local words = Instance.new("Frame")
words.AnchorPoint = Vector2.new(0, 1)
words.Position = UDim2.fromScale(0, 1)
words.Size = UDim2.fromOffset(1400, 320)
words.BackgroundTransparency = 1
words.Parent = cover
local scale = Instance.new("UIScale")
scale.Parent = words
local function label(text: string, size: number, color: Color3, position: UDim2): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = FONT
	t.Text = text
	t.TextSize = size
	t.TextColor3 = color
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.AnchorPoint = Vector2.new(0, 1)
	t.Position = position
	t.Size = UDim2.new(1, -112, 0, size)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = math.max(2, size / 12)
	stroke.Parent = t
	t.Parent = words
	return t
end
local function fit()
	local camera = workspace.CurrentCamera
	scale.Scale = if camera then math.clamp(camera.ViewportSize.Y / 1000, 0.5, 1.2) else 1
end
fit()
local title = label("CROSS THE CANYON!", 96, YELLOW, UDim2.new(0, 56, 1, -150))
local status = label("Loading the game...", 36, Color3.new(1, 1, 1), UDim2.new(0, 56, 1, -104))
-- The bar: a plain yellow rectangle filling left to right across the whole screen, just above the bottom hazard band
-- (2026-10-11, the user's call: full width, no rounded ends). The percentage sits at the end of the status line.
local track = Instance.new("Frame")
track.AnchorPoint = Vector2.new(0, 1)
track.Position = UDim2.new(0, 0, 1, -40)
track.Size = UDim2.new(1, 0, 0, 14)
track.BackgroundColor3 = Color3.new(0, 0, 0)
track.BackgroundTransparency = 0.35
track.BorderSizePixel = 0
track.Parent = cover
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = YELLOW
fill.BorderSizePixel = 0
fill.Parent = track
-- Roblox draws less of the far scenery and terrain at low graphics levels, and a game can't change the player's setting
-- (2026-10-11, the user's note: most of the canyon only showed from level 9). Those who set it low by hand get a tip;
-- on Automatic the level isn't readable, so nothing is said.
local okSetting, quality = pcall(function()
	return UserSettings():GetService("UserGameSettings").SavedQualityLevel
end)
local level = if okSetting and quality ~= Enum.SavedQualitySetting.Automatic then quality.Value else nil
if level and level < 8 then
	label("Tip: turn Graphics Quality up in Roblox's settings to see the whole canyon", 22, YELLOW, UDim2.new(0, 56, 1, -254))
end
gui.Parent = player:WaitForChild("PlayerGui")

-- The bar eases toward the progress it's told; a stage moves it from `from` toward `to` as its own work goes.
local shown = 0
local step = "Loading the game..."
local function progress(value: number, text: string?)
	step = text or step
	value = math.clamp(value, shown, 1)
	shown = value
	TweenService:Create(fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(value, 1) }):Play()
	status.Text = `{step}  {math.floor(value * 100)}%`
end

local started = os.clock()
local function timeLeft(): number
	return math.max(0, GIVE_UP - (os.clock() - started))
end

-- Is there terrain in the column at (x, z)? (MapLoadingController's check.)
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

local function groundAround(center: Vector3): number
	local found = 0
	for i = 1, READY_RING.points do
		local angle = i / READY_RING.points * math.pi * 2
		if hasGround(center.X + math.cos(angle) * READY_RING.radius, center.Z + math.sin(angle) * READY_RING.radius) then
			found += 1
		end
	end
	return found
end

-- 1. The game's instances.
progress(0.02, "Loading the game...")
while not game:IsLoaded() and timeLeft() > 0 do
	progress(shown + (0.2 - shown) * 0.05)
	task.wait(0.1)
end
progress(0.2)

-- The canyon's own picture and name, once the config and the live map are known.
task.spawn(function()
	local shared = ReplicatedStorage:WaitForChild("Shared", 20)
	local config = shared and shared:WaitForChild("GameConfig", 20)
	local map = workspace:WaitForChild("Map", 20)
	if not (config and config:IsA("ModuleScript") and map) then
		return
	end
	local GameConfig = (require :: any)(config)
	local name = map:GetAttribute("CurrentMap")
	local image = GameConfig.LoadingArt[if typeof(name) == "string" then name else "GrandCanyon"]
	if image then
		art.Image = image
		TweenService:Create(art, TweenInfo.new(0.5), { ImageTransparency = 0 }):Play()
	end
	for _, tier in GameConfig.Tiers do
		if tier.Map == name then
			title.Text = string.upper(tier.Name)
			break
		end
	end
end)

-- Hold the character still until the ground is there (only on this device: its physics is ours).
local function root(): BasePart?
	local character = player.Character or player.CharacterAdded:Wait()
	local part = character:WaitForChild("HumanoidRootPart", 10)
	return if part and part:IsA("BasePart") then part else nil
end

-- 2. The far scenery: every mesh and its texture, counted as they arrive.
progress(0.2, "Loading the canyon...")
local map = workspace:WaitForChild("Map", timeLeft())
local far = map and map:WaitForChild("FarCanyon", timeLeft())
if far then
	local parts = {}
	for _, item in far:GetDescendants() do
		if item:IsA("MeshPart") then
			table.insert(parts, item)
		end
	end
	for i = 1, #parts, PRELOAD_BATCH do
		if timeLeft() <= 0 then
			break
		end
		local batch = table.move(parts, i, math.min(i + PRELOAD_BATCH - 1, #parts), 1, {})
		ContentProvider:PreloadAsync(batch)
		progress(0.2 + 0.4 * math.min(i + PRELOAD_BATCH - 1, #parts) / #parts)
	end
end
progress(0.6)

-- 3. The terrain round spawn, and round the town across the canyon (the story intro flies there).
progress(0.6, "Shaping the terrain...")
local body = root()
if body then
	body.Anchored = true
	local here = body.Position
	local forestState = ReplicatedStorage:WaitForChild("ForestState", timeLeft())
	local frame = forestState and forestState:GetAttribute("BridgeFrame")
	local town = if typeof(frame) == "CFrame" then frame:PointToWorldSpace(Vector3.new(0, 0, -3060)) else nil
	pcall(player.RequestStreamAroundAsync, player, here, timeLeft())
	while timeLeft() > 0 do
		local found = groundAround(here)
		progress(0.6 + 0.25 * found / READY_RING.points)
		if found >= READY_RING.need then
			break
		end
		task.wait(0.25)
	end
	if town then
		pcall(player.RequestStreamAroundAsync, player, town, math.min(10, timeLeft()))
	end
end
progress(0.85)

-- 4. The bridge, built on this device by BridgeController.
progress(0.85, "Building the bridge...")
workspace:WaitForChild("BridgeView", timeLeft())
progress(1, "Ready!")
task.wait(0.4)

if body then
	body.Anchored = false
end
player:SetAttribute("Loaded", true)
TweenService:Create(cover, TweenInfo.new(0.6), { GroupTransparency = 1 }):Play()
task.wait(0.6)
gui:Destroy()
