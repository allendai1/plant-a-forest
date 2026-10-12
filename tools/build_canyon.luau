-- build_canyon.luau: turns the Plant Trees! island into the Grand Canyon (2026-10-10, docs/notes/Grand Canyon game.md).
-- Not shipped. Run it in the Edit datamodel through the Studio connection (fetch it from the local server and
-- loadstring it, like tests/TargetingCheck.luau), after tools/build_map.luau if that ever runs again (it rebuilds the
-- island). Safe to run again. The canyon's terrain itself comes from tools/canyon_terrain.luau (the real Grand Canyon,
-- tools/canyon_heightmap.py); run that first. Save the place afterwards.
--
-- 1. Moves the forest-only parts of the map (the floating island, its clouds, waterfalls and islets, the island-shaped
--    walk floor and edge walls, the forest's walkways and trails, the Edit-mode forest preview) into
--    ServerStorage.PlantTreesMap, so they're kept in the place but out of the game.
-- 2. Places the BridgeStart part (where the bridge leaves the rim, BridgeGrid) and a flat invisible walk floor over
--    camp's rectangle at the deck's height (the terrain there is flat at 0.4, just under it).
-- 3. Turns the acorn dispensers into plank piles, and sets a light desert haze.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- A fresh copy: Studio keeps a required module between tool runs, so a changed GameConfig would otherwise be missed.
local GameConfig = require(ReplicatedStorage.Shared.GameConfig:Clone()) :: any

local map = workspace:WaitForChild("Map")
local log = {}

local RIM_X = -180 -- the near rim's edge (the bridge starts here, heading -X)
local DECK_Y = 1.55 -- the walk floor's top (the plaza's walking height) and the bridge deck's
-- Camp's rectangle (tools/build_site.luau BASE): the walk floor covers it, stopping half a stud short of the rim so it
-- never reaches out over the canyon. Past it you walk on the terrain, flat out to about 330 from the middle.
local CAMP = { X0 = -179.5, X1 = 172, Z0 = -220, Z1 = 150 } -- Z0 -150 until the gym (2026-10-10)

local grid = GameConfig.Grid

-- 1. The forest-only map goes into storage.
local stash = ServerStorage:FindFirstChild("PlantTreesMap")
if not stash then
	stash = Instance.new("Folder")
	stash.Name = "PlantTreesMap"
	stash.Parent = ServerStorage
end
local function put(item: Instance?)
	if item then
		item.Parent = stash
		table.insert(log, `stored {item.Name}`)
	end
end
put(workspace:FindFirstChild("ForestPreview"))
for _, name in { "Island", "WalkFloor", "EdgeFloor", "Walkways", "ForestFloor" } do
	put(map:FindFirstChild(name))
end
local lobby = map:FindFirstChild("Lobby")
for _, item in if lobby then lobby:GetChildren() else {} do
	if item.Name == "LobbyPath" then
		put(item)
	end
end
for _, name in { "TrojanHorsePreview", "WorldTreePreview", "VoxelWorldTree" } do
	put(workspace:FindFirstChild(name))
end

-- 2. Where the bridge starts, and the floor you walk on over camp (the island's WalkFloor was the old one).
for _, old in CollectionService:GetTagged("BridgeStart") do
	old:Destroy()
end
local start = Instance.new("Part")
start.Name = "BridgeStart"
start.Size = Vector3.new(grid.Columns * grid.SlotStuds, 0.2, 1)
start.CFrame = CFrame.lookAt(Vector3.new(RIM_X, DECK_Y, 0), Vector3.new(RIM_X - 1, DECK_Y, 0))
start.Anchored = true
start.CanCollide, start.CanQuery, start.CanTouch = false, false, false
start.Transparency = 1
start.Parent = map
CollectionService:AddTag(start, "BridgeStart")

local old = map:FindFirstChild("RimFloor")
if old then
	old:Destroy()
end
local floorPart = Instance.new("Part")
floorPart.Name = "RimFloor"
floorPart.Size = Vector3.new(CAMP.X1 - CAMP.X0, 1, CAMP.Z1 - CAMP.Z0)
floorPart.CFrame = CFrame.new((CAMP.X0 + CAMP.X1) / 2, DECK_Y - 0.5, (CAMP.Z0 + CAMP.Z1) / 2)
floorPart.Anchored = true
floorPart.CanCollide = true
floorPart.Transparency = 1
floorPart.Parent = map
CollectionService:AddTag(floorPart, "WalkFloor")

-- The bridgehead: two tall posts either side of the first row, so you can see where to build from the hub.
local head = map:FindFirstChild("Bridgehead")
if head then
	head:Destroy()
end
local model = Instance.new("Model")
model.Name = "Bridgehead"
for _, side in { -1, 1 } do
	local post = Instance.new("Part")
	post.Name = "Post"
	post.Size = Vector3.new(2.4, 14, 2.4)
	post.CFrame = CFrame.new(RIM_X + 2, DECK_Y + 7, side * (grid.Columns * grid.SlotStuds / 2 + 1.6))
	post.Color = Color3.fromRGB(110, 74, 44)
	post.Material = Enum.Material.Wood
	post.Anchored = true
	post.Parent = model
end
model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
model.Parent = map

-- The finish: a tall flag on the far rim's landing, beside where a full bridge ends (tools/canyon_heightmap.py LANDING).
local farX = RIM_X - grid.Rows * grid.SlotStuds
local oldFlag = map:FindFirstChild("FarRimFlag")
if oldFlag then
	oldFlag:Destroy()
end
local flag = Instance.new("Model")
flag.Name = "FarRimFlag"
local base = Vector3.new(farX - 30, DECK_Y, grid.Columns * grid.SlotStuds / 2 + 14)
local pole = Instance.new("Part")
pole.Name = "Pole"
pole.Shape = Enum.PartType.Cylinder
pole.Size = Vector3.new(46, 1.4, 1.4)
pole.CFrame = CFrame.new(base + Vector3.new(0, 23, 0)) * CFrame.Angles(0, 0, math.rad(90))
pole.Color = Color3.fromRGB(90, 62, 40)
pole.Material = Enum.Material.Wood
pole.Anchored = true
pole.Parent = flag
local cloth = Instance.new("Part")
cloth.Name = "Cloth"
cloth.Size = Vector3.new(0.3, 9, 15)
cloth.CFrame = CFrame.new(base + Vector3.new(0, 40.5, 7.5))
cloth.Color = Color3.fromRGB(232, 96, 46)
cloth.Material = Enum.Material.Fabric
cloth.Anchored = true
cloth.CanCollide = false
cloth.Parent = flag
for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(300, 180)
	gui.Parent = cloth
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "SOUTH RIM"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack -- the GUIs' font (UIStyle.FONT; FredokaOne until 2026-10-10)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = gui
end
flag.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- seen from across the canyon
flag.Parent = map

-- The SOUTH RIM label floating over the far landing (2026-10-10, the user's ask), in the GYM label's style: white text (blue until the user's
-- call the same day) with a black outline and drop shadow over a black band fading out at both ends. Sized in studs, big enough to read
-- from camp across the canyon (about 3,000 studs), so it shrinks with distance like a real sign.
-- SOUTH RIM since 2026-10-10 (was NORTH RIM): the map is Toroweap Overlook, on the canyon's north side, so camp is on
-- the north rim and the bridge crosses to the south one (the user's call).
for _, name in { "NorthRimLabel", "SouthRimLabel" } do
	local oldLabel = map:FindFirstChild(name)
	if oldLabel then
		oldLabel:Destroy()
	end
end
-- In its own Persistent model (2026-10-11: as a loose part it streamed out, so camp couldn't see it across the canyon).
local labelModel = Instance.new("Model")
labelModel.Name = "SouthRimLabel"
labelModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
local labelAnchor = Instance.new("Part")
labelAnchor.Name = "Anchor"
labelAnchor.Size = Vector3.one
labelAnchor.Position = Vector3.new(farX - 60, DECK_Y + 310, 0) -- 310 over the deck since Springtown (2026-10-10; was 230)
labelAnchor.Anchored = true
labelAnchor.CanCollide, labelAnchor.CanQuery, labelAnchor.CanTouch = false, false, false
labelAnchor.Transparency = 1
local board = Instance.new("BillboardGui")
board.Name = "Label"
board.Size = UDim2.new(187, 153, 53, 42) -- studs plus pixels: about 150 px wide from camp (3,000 studs away), growing as you come closer (15% smaller since 2026-10-10)
board.LightInfluence = 0
board.MaxDistance = 8000
board.Parent = labelAnchor
local band = Instance.new("Frame")
band.Name = "Band"
band.AnchorPoint = Vector2.new(0.5, 0.5)
band.Position = UDim2.fromScale(0.5, 0.5)
band.Size = UDim2.fromScale(0.9, 1.15)
band.BackgroundColor3 = Color3.new(0, 0, 0)
band.BorderSizePixel = 0
band.ZIndex = 0
band.Parent = board
local fade = Instance.new("UIGradient")
fade.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.2, 0.75),
	NumberSequenceKeypoint.new(0.8, 0.75),
	NumberSequenceKeypoint.new(1, 1),
})
fade.Parent = band
for _, layer in { { "Shadow", Color3.new(0, 0, 0), 0.06, 1 }, { "Face", Color3.new(1, 1, 1), 0, 2 } } do
	local text = Instance.new("TextLabel")
	text.Name = layer[1]
	text.Size = UDim2.fromScale(1, 1)
	text.Position = UDim2.fromScale(0, layer[3])
	text.BackgroundTransparency = 1
	text.Text = "SOUTH RIM"
	text.TextScaled = true
	text.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	text.TextColor3 = layer[2]
	text.ZIndex = layer[4]
	text.Parent = board
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = text
end
labelAnchor.Parent = labelModel
labelModel.Parent = map

-- 3. The acorn dispensers become plank piles: the tower, its acorns and its slide markers go (no slide markers means
-- DispenserController rolls nothing), the basket turns invisible but keeps the pick-up prompt and the sign, and a
-- criss-cross stack of planks stands where the tower was.
local PILE_LAYERS = 6
local PILE_PLANKS = 5 -- per layer
local PILE_LENGTH = 15
local PILE_PLANK = Vector3.new(2.4, 1.3) -- width, height
local piles = 0
for _, rack in CollectionService:GetTagged("SeedRack") do
	-- The user's own pile (Lobby.PlankPiles, 2026-10-10) is left exactly as it is.
	if not rack:IsA("Model") or rack.Name == "PlankPiles" then
		continue
	end
	local logs = rack:FindFirstChild("AcornDispenser_Logs")
	local at = if logs and logs:IsA("BasePart") then logs.Position else rack:GetPivot().Position
	local old = rack:FindFirstChild("PlankPile")
	if old then
		at = (old :: Model):GetPivot().Position
		old:Destroy()
	end
	for _, part in rack:GetChildren() do
		local piece = part.Name:match("^AcornDispenser_(%a+)")
		if piece and piece ~= "Basket" and piece ~= "Glow" then
			part:Destroy()
		end
	end
	local basket = rack:FindFirstChild("AcornDispenser_Basket")
	if basket and basket:IsA("BasePart") then
		basket.Transparency = 1
		local sign = basket:FindFirstChildOfClass("BillboardGui")
		if sign then
			sign.StudsOffsetWorldSpace = Vector3.new(0, PILE_LAYERS * PILE_PLANK.Y + 6, 0)
			for _, label in sign:GetDescendants() do
				if label:IsA("TextLabel") then
					label.Text = "PLANKS"
				end
			end
		end
		for _, prompt in basket:GetDescendants() do
			if prompt:IsA("ProximityPrompt") then
				prompt.ActionText = "Pick Up Planks"
			end
		end
	end
	local pile = Instance.new("Model")
	pile.Name = "PlankPile"
	local ground = Vector3.new(at.X, DECK_Y - 1, at.Z)
	local pileRng = Random.new(math.floor(at.X * 31 + at.Z))
	local step = PILE_LENGTH / PILE_PLANKS
	for layer = 1, PILE_LAYERS do
		local turn = CFrame.Angles(0, if layer % 2 == 0 then math.pi / 2 else 0, 0)
		for i = 1, PILE_PLANKS do
			local plank = Instance.new("Part")
			plank.Name = "Plank"
			plank.Size = Vector3.new(PILE_PLANK.X, PILE_PLANK.Y, PILE_LENGTH + pileRng:NextNumber(-1, 1))
			local offset = Vector3.new((i - (PILE_PLANKS + 1) / 2) * step, (layer - 0.5) * PILE_PLANK.Y, 0)
			plank.CFrame = CFrame.new(ground) * turn * CFrame.new(offset) * CFrame.Angles(0, pileRng:NextNumber(-0.06, 0.06), 0)
			local shade = 1 + pileRng:NextNumber(-0.12, 0.12)
			plank.Color = Color3.fromRGB(176 * shade, 124 * shade, 74 * shade)
			plank.Material = Enum.Material.WoodPlanks
			plank.Anchored = true
			plank.CanCollide, plank.CanQuery, plank.CanTouch = false, false, false
			plank.Parent = pile
		end
	end
	local block = Instance.new("Part")
	block.Name = "Collision"
	block.Size = Vector3.new(PILE_LENGTH, PILE_LAYERS * PILE_PLANK.Y, PILE_LENGTH)
	block.CFrame = CFrame.new(ground + Vector3.new(0, block.Size.Y / 2, 0))
	block.Transparency = 1
	block.Anchored = true
	block.Parent = pile
	pile.PrimaryPart = block
	pile.Parent = rack
	piles += 1
end
table.insert(log, `plank piles: {piles}`)

-- A light desert haze so the far rim fades into the distance.
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmosphere.Density = 0.1 -- 0.15 until 2026-10-10: the far scenery now reaches the horizon, so less haze lets the canyon run on for miles
atmosphere.Offset = 0.6 -- the haze builds with distance: close walls stay crisp, the far canyon fades into the horizon
atmosphere.Color = Color3.fromRGB(232, 206, 176)
atmosphere.Decay = Color3.fromRGB(206, 150, 112)
atmosphere.Glare = 0.25
atmosphere.Haze = 0.8
atmosphere.Parent = Lighting

return table.concat(log, "\n")
