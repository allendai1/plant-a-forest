-- build_map.luau: builds the map around the forest in the open place: the lobby around the Ancient Tree
-- (docs/plans/M6b.md) and, since M11, the floating island, waterfalls, floating islands with bridges,
-- clouds, lighting and the plaza decorations (docs/plans/M11.md).
-- Not shipped. Run it in the Edit datamodel through the Studio connection (fetch it from the local
-- server and loadstring it, like tests/TargetingCheck.luau). Save the place afterwards.
--
-- Step 1 (only when ServerStorage holds the Open Cloud imports "Import_<id>"): moves the Blender meshes
-- into ReplicatedStorage.Assets (Assets.Acorn, Assets.Lobby.*, Assets.Map.*, Assets.Animals.*, the tile's
-- pieces, and the Ancient Tree's Glow, GlowGlyphs and Vines pieces) and colors them.
-- Step 2 (every run): rebuilds Workspace.Map.Lobby, dresses the training stations on tier pads,
-- replaces the seed rack with six acorn piles around the roots and moves the spawn. Then the island.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
-- The HUD's look helpers (font, outlined text with a shadow, icons), for the map's signs (GUI pass).
local UIStyle = (require :: any)(game:GetService("StarterPlayer").StarterPlayerScripts.Client.UIStyle)

local Assets = ReplicatedStorage:WaitForChild("Assets")
local map = workspace:WaitForChild("Map")
local log = {}

local GLOW = Color3.fromRGB(90, 255, 220)
local COLORS = {
	Paver = { Color3.fromRGB(214, 198, 170), Enum.Material.Ground }, -- textured since 2026-10-07 (was SmoothPlastic; Slate tried first)
	PaverDark = { Color3.fromRGB(170, 157, 138), Enum.Material.Ground },
	Stone = { Color3.fromRGB(150, 152, 158), Enum.Material.SmoothPlastic },
	Wood = { Color3.fromRGB(122, 82, 50), Enum.Material.SmoothPlastic },
	Lantern = { Color3.fromRGB(255, 200, 100), Enum.Material.Neon },
	Glow = { GLOW, Enum.Material.Neon },
	Flowers = { Color3.fromRGB(240, 140, 190), Enum.Material.SmoothPlastic },
	FlowersB = { Color3.fromRGB(215, 230, 255), Enum.Material.SmoothPlastic },
	Bush = { Color3.fromRGB(64, 140, 56), Enum.Material.SmoothPlastic },
	Crystal = { Color3.fromRGB(89, 217, 255), Enum.Material.Neon },
	CrystalB = { Color3.fromRGB(191, 115, 255), Enum.Material.Neon },
	Nut = { Color3.fromRGB(176, 120, 61), Enum.Material.SmoothPlastic },
	Cap = { Color3.fromRGB(102, 69, 38), Enum.Material.SmoothPlastic },
	Dirt = { Color3.fromRGB(115, 84, 52), Enum.Material.SmoothPlastic },
	Cushion = { Color3.fromRGB(40, 40, 46), Enum.Material.SmoothPlastic },
	Metal = { Color3.fromRGB(165, 170, 176), Enum.Material.Metal },
	Tier = { Color3.fromRGB(205, 205, 210), Enum.Material.SmoothPlastic },
	Vine = { Color3.fromRGB(46, 107, 41), Enum.Material.SmoothPlastic },
	Grass = { Color3.fromRGB(98, 160, 64), Enum.Material.SmoothPlastic },
	Cliff = { Color3.fromRGB(128, 118, 108), Enum.Material.SmoothPlastic },
	Cloud = { Color3.fromRGB(250, 252, 255), Enum.Material.SmoothPlastic },
	Rope = { Color3.fromRGB(199, 168, 115), Enum.Material.SmoothPlastic },
	Water = { Color3.fromRGB(110, 185, 240), Enum.Material.SmoothPlastic },
	Lily = { Color3.fromRGB(92, 172, 72), Enum.Material.SmoothPlastic },
	GiftBox = { Color3.fromRGB(215, 50, 75), Enum.Material.SmoothPlastic },
	Ribbon = { Color3.fromRGB(255, 205, 65), Enum.Material.SmoothPlastic },
	Paper = { Color3.fromRGB(240, 234, 210), Enum.Material.SmoothPlastic },
	MushroomCap = { Color3.fromRGB(215, 45, 40), Enum.Material.SmoothPlastic },
	MushroomStem = { Color3.fromRGB(242, 235, 215), Enum.Material.SmoothPlastic },
	Deer = { Color3.fromRGB(160, 108, 64), Enum.Material.SmoothPlastic },
	Antler = { Color3.fromRGB(230, 218, 185), Enum.Material.SmoothPlastic },
	Fox = { Color3.fromRGB(230, 115, 40), Enum.Material.SmoothPlastic },
	FoxWhite = { Color3.fromRGB(245, 240, 230), Enum.Material.SmoothPlastic },
	Bunny = { Color3.fromRGB(205, 200, 195), Enum.Material.SmoothPlastic },
	Bird = { Color3.fromRGB(77, 115, 190), Enum.Material.SmoothPlastic },
	Beak = { Color3.fromRGB(255, 165, 40), Enum.Material.SmoothPlastic },
	Bark = { Color3.fromRGB(105, 70, 45), Enum.Material.SmoothPlastic },
	Leaves = { Color3.fromRGB(92, 172, 72), Enum.Material.SmoothPlastic },
	Needles = { Color3.fromRGB(42, 122, 72), Enum.Material.SmoothPlastic },
	-- The seed shop's special trees and their seeds (docs/plans/SeedShop.md).
	SakuraBark = { Color3.fromRGB(92, 58, 52), Enum.Material.SmoothPlastic },
	Blossom = { Color3.fromRGB(255, 160, 205), Enum.Material.SmoothPlastic },
	BlossomDeep = { Color3.fromRGB(232, 92, 162), Enum.Material.SmoothPlastic },
	Pollen = { Color3.fromRGB(255, 225, 120), Enum.Material.SmoothPlastic },
	CrystalBark = { Color3.fromRGB(72, 66, 96), Enum.Material.SmoothPlastic },
	CrystalViolet = { Color3.fromRGB(150, 70, 255), Enum.Material.Neon },
	RedwoodBark = { Color3.fromRGB(168, 62, 36), Enum.Material.SmoothPlastic },
	RedwoodNeedles = { Color3.fromRGB(34, 94, 50), Enum.Material.SmoothPlastic },
	RedwoodNeedlesB = { Color3.fromRGB(58, 124, 60), Enum.Material.SmoothPlastic },
	PalmBark = { Color3.fromRGB(196, 160, 110), Enum.Material.SmoothPlastic },
	Fronds = { Color3.fromRGB(60, 150, 55), Enum.Material.SmoothPlastic },
	FrondsB = { Color3.fromRGB(110, 185, 70), Enum.Material.SmoothPlastic },
	Coconut = { Color3.fromRGB(95, 60, 30), Enum.Material.SmoothPlastic },
	CoconutEyes = { Color3.fromRGB(55, 36, 22), Enum.Material.SmoothPlastic },
	BambooStalk = { Color3.fromRGB(150, 190, 70), Enum.Material.SmoothPlastic },
	BambooNode = { Color3.fromRGB(95, 130, 40), Enum.Material.SmoothPlastic },
	BambooLeaves = { Color3.fromRGB(70, 150, 55), Enum.Material.SmoothPlastic },
	-- The Great Smoky Mountains world (autumn, 2026-10-07).
	MapleBark = { Color3.fromRGB(112, 92, 82), Enum.Material.SmoothPlastic },
	MapleOrange = { Color3.fromRGB(242, 128, 40), Enum.Material.SmoothPlastic },
	MapleRed = { Color3.fromRGB(205, 52, 36), Enum.Material.SmoothPlastic },
	MapleGold = { Color3.fromRGB(250, 190, 50), Enum.Material.SmoothPlastic },
	BirchBark = { Color3.fromRGB(236, 232, 222), Enum.Material.SmoothPlastic },
	BirchMark = { Color3.fromRGB(38, 34, 32), Enum.Material.SmoothPlastic },
	BirchGold = { Color3.fromRGB(250, 205, 60), Enum.Material.SmoothPlastic },
	BirchGoldB = { Color3.fromRGB(232, 160, 40), Enum.Material.SmoothPlastic },
	Crate = { Color3.fromRGB(205, 170, 115), Enum.Material.SmoothPlastic },
	-- The ranger station (the upgrade shop since 2026-10-07).
	Logs = { Color3.fromRGB(110, 72, 44), Enum.Material.SmoothPlastic },
	PlankLight = { Color3.fromRGB(168, 122, 78), Enum.Material.SmoothPlastic },
	Roof = { Color3.fromRGB(58, 112, 64), Enum.Material.SmoothPlastic },
	Burlap = { Color3.fromRGB(196, 160, 112), Enum.Material.SmoothPlastic },
	Iron = { Color3.fromRGB(58, 58, 64), Enum.Material.Metal },
	Awning = { Color3.fromRGB(255, 150, 195), Enum.Material.SmoothPlastic },
	AwningStripe = { Color3.fromRGB(255, 248, 235), Enum.Material.SmoothPlastic },
}
-- The special trees' and seeds' pieces, by the whole "Asset_Piece" name without the stage number.
local SPECIAL_LOOK = {
	Sakura_Bark = "SakuraBark",
	Sakura_Blossom = "Blossom",
	Sakura_BlossomDeep = "BlossomDeep",
	Crystal_Bark = "CrystalBark",
	Crystal_Crystal = "Crystal",
	Crystal_CrystalViolet = "CrystalViolet",
	Redwood_Bark = "RedwoodBark",
	Redwood_Needles = "RedwoodNeedles",
	Redwood_NeedlesB = "RedwoodNeedlesB",
	Palm_Bark = "PalmBark",
	Palm_Fronds = "Fronds",
	Palm_FrondsB = "FrondsB",
	Palm_Coconuts = "Coconut",
	SakuraSeed_Pit = "BlossomDeep",
	SakuraSeed_Petals = "Blossom",
	SakuraSeed_Heart = "Pollen",
	CrystalSeed_Gem = "CrystalViolet",
	CrystalSeed_Shards = "Crystal",
	RedwoodSeed_Cone = "RedwoodBark",
	RedwoodSeed_Sprig = "RedwoodNeedlesB",
	PalmSeed_Husk = "Coconut",
	PalmSeed_Eyes = "CoconutEyes",
	PalmSeed_Leaves = "FrondsB",
	Bamboo_Bark = "BambooStalk",
	Bamboo_Nodes = "BambooNode",
	Bamboo_Leaves = "BambooLeaves",
	BambooSeed_Tube = "BambooStalk",
	BambooSeed_Bands = "BambooNode",
	BambooSeed_Leaf = "BambooLeaves",
	Maple_Bark = "MapleBark",
	Maple_Leaves = "MapleOrange",
	Maple_LeavesB = "MapleRed",
	Maple_LeavesC = "MapleGold",
	Birch_Bark = "BirchBark",
	Birch_Marks = "BirchMark",
	Birch_Leaves = "BirchGold",
	Birch_LeavesB = "BirchGoldB",
	SeedStall_Crates = "Crate",
	SeedStall_Awning = "Awning",
	SeedStall_Stripe = "AwningStripe",
	RangerStation_Logs = "Logs",
	RangerStation_Planks = "PlankLight",
	RangerStation_Roof = "Roof",
	RangerStation_Sacks = "Burlap",
	RangerStation_Paper = "Paper",
	RangerStation_Lamp = "Lantern",
	AcornDispenser_Wood = "PlankLight",
	AcornDispenser_Logs = "Logs",
	AcornDispenser_Bands = "Iron",
	AcornDispenser_Basket = "Burlap",
	AcornDispenser_Roof = "Roof",
	AcornDispenser_Lamp = "Lantern",
}
-- Which look each imported piece gets (by the part of its name after the "_").
local PIECE_LOOK = {
	Stone = "Paver",
	StoneDark = "PaverDark",
	Wood = "Wood",
	Glow = "Glow",
	Flowers = "Flowers",
	FlowersB = "FlowersB",
	Bush = "Bush",
	Crystal = "Crystal",
	CrystalB = "CrystalB",
	Nut = "Nut",
	Nuts = "Nut",
	Cap = "Cap",
	Caps = "Cap",
	Mound = "Dirt",
	Frame = "Tier",
	Pad = "Cushion",
	Bar = "Metal",
	Plates = "Tier",
	Belt = "Cushion",
	Metal = "Metal",
	Top = "Grass",
	Walk = "Grass",
	Grass = "Grass",
	Border = "Grass",
	Dirt = "Dirt",
	Rock = "Cliff",
	Rocks = "Stone",
	Below = "Cloud",
	Far = "Cloud",
	Planks = "Wood",
	Posts = "Wood",
	Rope = "Rope",
	Water = "Water",
	Lily = "Lily",
	Box = "GiftBox",
	Ribbon = "Ribbon",
	Paper = "Paper",
	Stem = "MushroomStem",
	Antler = "Antler",
	White = "FoxWhite",
	Beak = "Beak",
	WingL = "Bird",
	WingR = "Bird",
	Bark = "Bark",
	Leaves = "Leaves",
	Needles = "Needles",
}
-- The worlds' own World Trees (2026-10-07): each set's pieces' colors, by model prefix.
local SAKURA_ANCIENT = {
	Bark = { Color3.fromRGB(62, 40, 36), Enum.Material.SmoothPlastic },
	Leaves = { Color3.fromRGB(255, 196, 214), Enum.Material.SmoothPlastic },
	LeavesLight = { Color3.fromRGB(255, 232, 240), Enum.Material.SmoothPlastic },
	LeavesDark = { Color3.fromRGB(238, 92, 92), Enum.Material.SmoothPlastic },
	Glow = { Color3.fromRGB(255, 120, 200), Enum.Material.Neon }, -- the orbs under the crown
}
local MAPLE_ANCIENT = { -- the Great Smoky Mountains' giant maple
	Bark = { Color3.fromRGB(112, 92, 82), Enum.Material.SmoothPlastic },
	Leaves = { Color3.fromRGB(242, 128, 40), Enum.Material.SmoothPlastic },
	LeavesDark = { Color3.fromRGB(205, 52, 36), Enum.Material.SmoothPlastic },
	LeavesLight = { Color3.fromRGB(250, 190, 50), Enum.Material.SmoothPlastic },
	Glow = { Color3.fromRGB(255, 170, 60), Enum.Material.Neon }, -- amber lanterns and root veins
}
local WORLD_TREE_LOOKS = { AncientSakura = SAKURA_ANCIENT, AncientMaple = MAPLE_ANCIENT }
-- Pieces whose look depends on the asset too.
local ASSET_LOOK = {
	Deer_Body = "Deer",
	Fox_Body = "Fox",
	Bunny_Body = "Bunny",
	Bird_Body = "Bird",
}
local MAP_ASSETS = { Island = true, Clouds = true, IsletA = true, IsletB = true, IsletC = true, Bridge = true }
local ANIMALS = { Deer = true, Fox = true, Bunny = true, Bird = true }

local function look(part: BasePart, key: string)
	local entry = COLORS[key]
	part.Color, part.Material = entry[1], entry[2]
end

local TEXTURED = {
	LobbyFence_Wood = Enum.Material.Wood,
	LobbyFence_Stone = Enum.Material.Slate,
	LobbyGarden_Stone = Enum.Material.Slate,
	-- The acorn dispensers, all wood (the user's call, 2026-10-08), the acorns and metal bands included.
	AcornDispenser_Wood = Enum.Material.Wood,
	AcornDispenser_Logs = Enum.Material.Wood,
	AcornDispenser_Bands = Enum.Material.Wood,
	AcornDispenser_Nuts = Enum.Material.Wood,
	AcornDispenser_Caps = Enum.Material.Wood,
	AcornDispenser_Basket = Enum.Material.Wood,
}

local function dress(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local asset, piece = part.Name:match("^(%w+)_(%w+)$")
			local key = PIECE_LOOK[piece or ""]
			local special = asset and SPECIAL_LOOK[(asset:gsub("%d+$", "")) .. "_" .. piece]
			if special then
				key = special
			elseif ASSET_LOOK[part.Name] then
				key = ASSET_LOOK[part.Name]
			elseif
				asset == "LobbyFence" and piece == "Stone"
				or asset == "LobbyGarden" and piece == "Stone"
				or asset == "ShopAltar" and piece == "Stone"
			then
				key = "Stone"
			elseif (asset == "LobbyFence" or asset == "LobbyPath") and piece == "Glow" then
				key = "Lantern"
			end
			if key then
				look(part, key)
			end
			-- Textured pieces (2026-10-08): their meshes have UVs (build_assets.py box_uv), so these tile properly.
			local textured = TEXTURED[part.Name]
			if textured then
				part.Material = textured
			end
			part.Anchored = true
		end
	end
end

-- Step 1: the imported meshes.
for _, import in ServerStorage:GetChildren() do
	if import:IsA("Model") and import.Name:match("^Import_") then
		local root = import:FindFirstChildWhichIsA("Model") or import
		for _, model in root:GetChildren() do
			if not model:IsA("Model") then
				continue
			end
			local ancient = model.Name:match("^Ancient%d$")
			local worldTree = WORLD_TREE_LOOKS[model.Name:match("^(Ancient%a+)%d$") or ""]
			if worldTree then
				-- A world's own World Tree (Kyoto's, the Smoky Mountains'): a whole model set, next to Ancient1-4.
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") then
						local entry = worldTree[part.Name:match("_(%w+)$") or ""]
						if entry then
							part.Color, part.Material = entry[1], entry[2]
						end
						part.Anchored = true
					end
				end
				local existing = Assets.AncientTree:FindFirstChild(model.Name)
				if existing then
					existing:Destroy()
				end
				model.Parent = Assets.AncientTree
				table.insert(log, "world tree " .. model.Name)
			elseif ancient then
				local target = Assets.AncientTree[model.Name] :: Model
				local oldGlow = target:FindFirstChild(model.Name .. "_Glow") :: BasePart?
				local glowColor = if oldGlow then oldGlow.Color else GLOW
				for _, piece in { "Glow", "GlowGlyphs", "Vines" } do
					local part = model:FindFirstChild(model.Name .. "_" .. piece) :: BasePart
					local existing = target:FindFirstChild(part.Name)
					if existing then
						existing:Destroy()
					end
					local rel = model:GetPivot():ToObjectSpace(part.CFrame)
					part.Anchored = true
					if piece == "Vines" then
						look(part, "Vine")
					else
						part.Material, part.Color = Enum.Material.Neon, glowColor
					end
					part.Parent = target
					part.CFrame = target:GetPivot() * rel
				end
				table.insert(log, "updated " .. model.Name)
			elseif model.Name:match("^%a+%d+$") then -- a forest tree stage: Leafy, Pine and the special trees
				-- A forest tree stage (docs/plans/TreeStages.md): into Assets.Trees, replacing the old one.
				dress(model)
				local existing = Assets.Trees:FindFirstChild(model.Name)
				if existing then
					existing:Destroy()
				end
				model.Parent = Assets.Trees
				table.insert(log, "tree " .. model.Name)
			elseif model.Name == "HexTile" then
				-- Replace the tile's pieces in place, keeping the colors of the ones that already existed.
				local target = Assets.Tiles.HexTile :: Model
				for _, part in model:GetChildren() do
					if part:IsA("BasePart") then
						local existing = target:FindFirstChild(part.Name) :: BasePart?
						local rel = model:GetPivot():ToObjectSpace(part.CFrame)
						if existing then
							part.Color, part.Material, part.Transparency =
								existing.Color, existing.Material, existing.Transparency
							existing:Destroy()
						else
							look(part, if part.Name == "HexTile_Flowers" then "Flowers" else "Grass")
						end
						part.Anchored = true
						part.Parent = target
						part.CFrame = target:GetPivot() * rel
					end
				end
				table.insert(log, "updated HexTile")
			else
				dress(model)
				local folderName = if MAP_ASSETS[model.Name] then "Map" elseif ANIMALS[model.Name] then "Animals" else "Lobby"
				local folder = Assets:FindFirstChild(folderName) or Instance.new("Folder")
				folder.Name = folderName
				folder.Parent = Assets
				local parent = if model.Name == "Acorn" then Assets else folder
				if model.Name:match("Seed$") then -- the seed shop's seeds (docs/plans/SeedShop.md)
					parent = Assets:FindFirstChild("Seeds") or Instance.new("Folder")
					parent.Name = "Seeds"
					parent.Parent = Assets
				end
				local existing = parent:FindFirstChild(model.Name)
				if existing then
					existing:Destroy()
				end
				model.Parent = parent
				table.insert(log, "asset " .. model.Name)
			end
		end
		import:Destroy()
	end
end

-- The treadmill belt arrows: copied once from the TreadmillGold model in Workspace (its scrolling arrow
-- Beam and the turn of its attachments) into Assets.Lobby.TreadmillArrows.
local gold = workspace:FindFirstChild("TreadmillGold")
local goldBeam = gold and gold:FindFirstChildWhichIsA("Beam", true)
if goldBeam and goldBeam.Attachment0 and not Assets.Lobby:FindFirstChild("TreadmillArrows") then
	local folder = Instance.new("Folder")
	folder.Name = "TreadmillArrows"
	local beam = goldBeam:Clone()
	beam.Attachment0, beam.Attachment1 = nil, nil
	beam.Parent = folder
	local turn = Instance.new("Attachment")
	turn.Name = "Turn"
	turn.CFrame = goldBeam.Attachment0.CFrame.Rotation
	turn.Parent = folder
	folder.Parent = Assets.Lobby
	table.insert(log, "copied the treadmill arrows from TreadmillGold")
end

-- Step 2: the lobby.
local Lobby = Assets.Lobby
local centerPart = map:FindFirstChild("ForestCenter") :: BasePart
local GROUND = 0.6 -- the plaza and the garden sit on the hub's grass
local C = Vector3.new(centerPart.Position.X, GROUND, centerPart.Position.Z)
local FENCE_R, GATE = 150, 15 / 150
local RACK_R, RACK_ANGLES = 97, { 30, 90, 150, 210, 270, 330 }
local SHOP_ANGLE, SHOP_R, SHOP_RING_AHEAD, SHOP_RING_R = 0, 97, 13, 6.5
local SPAWN_ANGLE, SPAWN_R = 30, 122
-- The pads ring the World Tree inside the root garden since 2026-10-08 (the user's pick: the garden sat empty;
-- the tree is drawn at 60% to make room). They were on the plaza at 120 studs, between the trails.
local PAD_R, PAD_SIZE = 66, 24 -- each tier pad is a circle this wide, around its bench and treadmill
local PLATE_COLOR = Color3.fromRGB(30, 30, 34)
local TREAD_SCALE = 1.5 -- the treadmills are built this much bigger than the Blender model
local BENCH_SCALE = 1.5 -- and the bench presses, so a lying player fits between the uprights
-- The seat (where the server holds a benching player) sits SEAT_ABOVE over the pad, moved SEAT_TOWARD_BAR
-- along the bench so the lying player's chest is under the bar and their head stays on the pad.
local SEAT_ABOVE, SEAT_TOWARD_BAR = 1.325, 0.85
-- Each tier's pad: the angle it sits at, and its colour. Evenly around the tree, 45 degrees apart and offset
-- from the garden's entrances (the trails, every 60 degrees); 1x is nearest the spawn.
local TIERS = {
	{ multiplier = 1, angle = 22.5, color = Color3.fromRGB(205, 205, 210) }, -- gray
	{ multiplier = 2, angle = 67.5, color = Color3.fromRGB(255, 214, 64) }, -- yellow
	{ multiplier = 5, angle = 112.5, color = Color3.fromRGB(64, 214, 255) }, -- cyan
	{ multiplier = 10, angle = 157.5, color = Color3.fromRGB(176, 96, 255) }, -- purple
	{ multiplier = 25, angle = 202.5, color = Color3.fromRGB(255, 140, 40) }, -- orange
	{ multiplier = 50, angle = 247.5, color = Color3.fromRGB(240, 50, 50) }, -- red
	{ multiplier = 75, angle = 292.5, color = Color3.fromRGB(255, 80, 200) }, -- pink
	{ multiplier = 100, angle = 337.5, color = Color3.fromRGB(60, 235, 140) }, -- emerald
}

local function at(angle: number, r: number, y: number?): Vector3
	local a = math.rad(angle)
	return C + Vector3.new(math.cos(a) * r, y or 0, math.sin(a) * r)
end

-- Turns a model so its local -X (the front, and the trail direction, in the Blender assets) points at angle.
local function toward(angle: number): CFrame
	return CFrame.Angles(0, math.pi - math.rad(angle), 0)
end

-- The rack prompt's settings (from the original rack, or a pile built by an earlier run).
local promptTemplate: ProximityPrompt? = nil
for _, rack in CollectionService:GetTagged("SeedRack") do
	local found = rack:FindFirstChildWhichIsA("ProximityPrompt", true)
	if found then
		promptTemplate = found:Clone()
		break
	end
end

local old = map:FindFirstChild("Lobby")
if old then
	old:Destroy()
end
local lobby = Instance.new("Folder")
lobby.Name = "Lobby"
lobby.Parent = map

local function place(template: Model, cf: CFrame, collide: boolean?, parent: Instance?): Model
	local model = template:Clone()
	model:PivotTo(cf)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = collide == true
			part.CanQuery = collide == true
			part.CanTouch = false
		end
	end
	model.Parent = parent or lobby
	return model
end

local function block(name: string, size: Vector3, cf: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Anchored = true
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic -- Plastic shows a stud texture
	part.Parent = parent
	return part
end

-- Grass under the whole hub, its top (GROUND + 0.05) just under the plaza's pavers.
local hub = map:FindFirstChild("HubClearing") :: Part
hub.Size = Vector3.new(0.2, 320, 320) -- stops short of the ring-7 plot centers (168+), so their heights don't change
hub.Position = Vector3.new(C.X, GROUND - 0.05, C.Z)

place(Lobby.LobbyPlaza, CFrame.new(C))
place(Lobby.LobbyGarden, CFrame.new(C))
local fence = place(Lobby.LobbyFence, CFrame.new(C))

-- Lights at the trail openings. The fence doesn't collide anywhere (the user's request, 2026-10-07: it
-- used to have invisible walls), so players walk straight through it.
for k = 0, 5 do
	local t = math.rad(60 * k)
	local a0, a1 = t + GATE, t + math.rad(60) - GATE
	local function point(a: number): Vector3
		return C + Vector3.new(math.cos(a) * FENCE_R, 3, math.sin(a) * FENCE_R)
	end
	for _, a in { a0, a1 } do
		local holder = block("GateLight", Vector3.one, CFrame.new(point(a) + Vector3.new(0, 4.9, 0)), fence)
		holder.Transparency, holder.CanCollide, holder.CanQuery = 1, false, false
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 200, 110), 18, 1.5
		light.Parent = holder
	end
end

-- Stone trails over the walkways. 32 studs wide and above the tiles' raised edges (1.75), so the zig-zag of
-- the walkway's removed hexes is covered and the neighbouring plots' corners tuck under the stones. The
-- stones are solid, so players walk on them instead of sinking into them.
local TILE_TOP = 1.6
for k = 0, 5 do
	local path = place(Lobby.LobbyPath, CFrame.new(C.X, TILE_TOP + 0.05, C.Z) * toward(60 * k))
	local stones = path:FindFirstChild("LobbyPath_Stone") :: BasePart
	stones.CanCollide, stones.CanQuery = true, true
	-- A grout bed under the pavers, above the tiles' raised edges, so those don't show through the joints.
	local bed = block("PathBed", Vector3.new(stones.Size.X, 0.2, stones.Size.Z), stones.CFrame, path)
	bed.CFrame = stones.CFrame - Vector3.new(0, stones.CFrame.Y - (TILE_TOP + 0.15), 0) -- top 1.85: over the 1.75 edges, under every paver top
	bed.Color, bed.Material = Color3.fromRGB(120, 112, 100), Enum.Material.SmoothPlastic
	bed.CanCollide, bed.CanQuery, bed.CanTouch = false, false, false
end
-- Bushes and rocks in the grass between the round fence and the hexagonal first ring of plots.
if Lobby:FindFirstChild("FenceDecor") then
	place(Lobby.FenceDecor, CFrame.new(C.X, 0.4, C.Z))
end

for _, walkway in map.Walkways:GetChildren() do
	if walkway:IsA("BasePart") then
		walkway.Transparency = 1
	end
end

-- The upgrade shop at the end of a trail, facing out, with its ring; stepping into ShopZone opens the shop.
-- Since 2026-10-07 it's a log-cabin ranger station (Lobby.RangerStation) with a shopkeeper behind the counter;
-- the stone altar (Lobby.ShopAltar) is the fallback when the station isn't imported.
local shopCF = CFrame.new(at(SHOP_ANGLE, SHOP_R, 0.3)) * toward(SHOP_ANGLE) -- on top of the pavers, so the ring shows
local station = Lobby:FindFirstChild("RangerStation")
local SOLID = { ShopAltar_Stone = true, RangerStation_Logs = true, RangerStation_Planks = true, RangerStation_Roof = true }
local altar = place(station or Lobby.ShopAltar, shopCF, true)
for _, part in altar:GetChildren() do
	if part:IsA("BasePart") and not SOLID[part.Name] then
		part.CanCollide, part.CanQuery = false, false -- the walls and counter are solid; the ring is walked into
	end
end
-- In the station's frame (Blender +X is the front, which is local -X here): the sign over the counter and
-- the spot behind the counter where the shopkeeper stands.
-- The sign floats centered above the roof (the user's ask, 2026-10-07; it was over the counter under the eaves).
local SIGN_LOCAL, KEEPER_LOCAL = Vector3.new(0.7, 18.5, 0), Vector3.new(-1, 0.6, 0)
do
	local signAnchor = altar:FindFirstChild("ShopAltar_Stone") :: BasePart?
	if station then
		local anchor = block("SignAnchor", Vector3.one, shopCF * CFrame.new(SIGN_LOCAL), altar)
		anchor.Transparency, anchor.CanCollide, anchor.CanQuery = 1, false, false
		signAnchor = anchor
	end
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(220, 44)
	sign.StudsOffsetWorldSpace = if station then Vector3.zero else Vector3.new(0, 8, 0)
	sign.MaxDistance = 120
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(90, 255, 220)
	text.TextStrokeTransparency = 0.3
	text.Text = "UPGRADES"
	text.Parent = sign
	UIStyle.band(sign) -- a dark strip behind the text (2026-10-07)
	sign.Parent = signAnchor
end
-- UPGRADES painted on the plank board over the counter, both sides (the user's ask, 2026-10-08: it was blank).
-- The board is build_assets.py's box at Blender (front + 1.6, 0, 11.2), 0.3 x 8.5 x 2 studs.
local BOARD_LOCAL, BOARD_SIZE = Vector3.new(-6.2, 11.2, 0), Vector3.new(8.5, 2, 0.36)
if station then
	-- Turned so the part's front face looks out the station's front (local -X).
	local board = block("UpgradesBoard", BOARD_SIZE, shopCF * CFrame.new(BOARD_LOCAL) * CFrame.Angles(0, math.rad(90), 0), altar)
	board.Transparency, board.CanCollide, board.CanQuery, board.CanTouch = 1, false, false, false
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = `Upgrades{face.Name}`
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.LightInfluence = 0
		gui.MaxDistance = 150
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 226, 150)
		label.TextStrokeTransparency = 0
		label.Text = "UPGRADES"
		label.Parent = gui
		local padding = Instance.new("UIPadding")
		padding.PaddingTop, padding.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
		padding.PaddingLeft, padding.PaddingRight = UDim.new(0.04, 0), UDim.new(0.04, 0)
		padding.Parent = label
		gui.Parent = board
	end
end
-- The shopkeeper: a plain avatar behind the counter, for the user to dress in Studio. It lives in Workspace.Map
-- (not the rebuilt Lobby folder) and is only made when missing, so reruns keep their edits. Tagged IdleNpc:
-- OutfitService plays an idle animation on it.
if station and not map:FindFirstChild("Shopkeeper") then
	local keeper = game:GetService("Players")
		:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	keeper.Name = "Shopkeeper"
	local humanoid = keeper:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local rootPart = keeper:FindFirstChild("HumanoidRootPart") :: BasePart
	rootPart.Anchored = true
	local spot = (shopCF * CFrame.new(KEEPER_LOCAL)).Position
	local height = keeper:GetExtentsSize().Y / 2
	local out = (shopCF * CFrame.new(-20, 0, 0)).Position
	keeper:PivotTo(CFrame.lookAt(spot + Vector3.new(0, height, 0), Vector3.new(out.X, spot.Y + height, out.Z)))
	keeper.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CollectionService:AddTag(keeper, "IdleNpc")
	keeper.Parent = map
	table.insert(log, "shopkeeper placed")
end
-- Inside the station model (since 2026-10-07), so moving the station in Studio carries its ring's trigger along.
-- With the ranger station, the trigger is its whole glowing ring (RangerStation_Glow, around the station; the user
-- found the old small circle in front didn't match the ring, 2026-10-07). The stone altar keeps the small ring ahead.
local stationGlow = altar:FindFirstChild("RangerStation_Glow") :: BasePart?
if stationGlow then
	CollectionService:AddTag(stationGlow, "GlowRing") -- drawn as a soft spinning ring (GlowRingController)
end
local zone = block(
	"ShopZone",
	if stationGlow
		then Vector3.new(0.4, stationGlow.Size.X, stationGlow.Size.Z)
		else Vector3.new(0.4, SHOP_RING_R * 2, SHOP_RING_R * 2),
	CFrame.new(
		if stationGlow
			then Vector3.new(stationGlow.Position.X, at(SHOP_ANGLE, 0, 0.5).Y, stationGlow.Position.Z)
			else at(SHOP_ANGLE, SHOP_R + SHOP_RING_AHEAD, 0.5)
	) * CFrame.Angles(0, 0, math.rad(90)),
	altar
)
zone.Shape = Enum.PartType.Cylinder
zone.Transparency, zone.CanCollide, zone.CanQuery = 1, false, false
CollectionService:AddTag(zone, "ShopZone")

-- The Park Ranger and Lord of the Forest NPCs, one on either side of the shop ring, facing it, each standing on
-- a round platform like a display stand (rebuilt every run). Like the shopkeeper the NPCs live in Workspace.Map and
-- are only made when missing, so the user can dress them in Studio. Tagged CharacterNpc (OutfitService adds the pass
-- prompt, name label and shop preview) and IdleNpc.
do
	local SKIN = Color3.fromRGB(234, 184, 146)
	local LOOKS = { -- body colors, the ring color (the name label's), and the dynamic head the user picked
		Ranger = {
			shirt = Color3.fromRGB(194, 170, 120),
			pants = Color3.fromRGB(86, 92, 58),
			ring = Color3.fromRGB(240, 210, 140),
			head = 72457329282324, -- Shedletsky's Slightly Annoyed Face
			mood = 14618207727,
		},
		Lord = {
			shirt = Color3.fromRGB(120, 84, 50),
			pants = Color3.fromRGB(62, 46, 36),
			ring = Color3.fromRGB(150, 255, 150),
		},
	}
	-- Placed around the spot in front of the station (the old small shop ring), not the shop trigger, which now
	-- covers the whole station ring.
	local front = at(SHOP_ANGLE, SHOP_R + SHOP_RING_AHEAD, 0.5)
	local NPC_BACK, NPC_SIDE = 1, 13 -- studs from the ring's center toward the shop, and to either side
	local STAND_R, STAND_H = 3.5, 1.2 -- the platform's radius and height
	local out = (front - C) * Vector3.new(1, 0, 1)
	local outward = if out.Magnitude > 0 then out.Unit else Vector3.xAxis
	local side = outward:Cross(Vector3.yAxis)
	local outfits = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Outfits")
	local made = {}
	for _, item in CollectionService:GetTagged("CharacterNpc") do
		made[item:GetAttribute("Outfit")] = true
	end
	for i, pass in GameConfig.HandsPasses do
		local look = LOOKS[pass.Outfit]
		if not look then
			continue
		end
		local ground = front - outward * NPC_BACK + side * (if i == 1 then -NPC_SIDE else NPC_SIDE)
		ground = Vector3.new(ground.X, GROUND, ground.Z)
		local disk = CFrame.new(ground + Vector3.new(0, STAND_H / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local stand = block(`{pass.Outfit}Stand`, Vector3.new(STAND_H, STAND_R * 2, STAND_R * 2), disk, lobby)
		stand.Shape = Enum.PartType.Cylinder
		stand.Material, stand.Color = Enum.Material.Slate, Color3.fromRGB(120, 116, 108)
		local rim = block(
			`{pass.Outfit}StandRim`,
			Vector3.new(0.25, STAND_R * 2 + 0.3, STAND_R * 2 + 0.3),
			disk * CFrame.new(STAND_H / 2 - 0.2, 0, 0),
			lobby
		)
		rim.Shape = Enum.PartType.Cylinder
		rim.Material, rim.Color = Enum.Material.Neon, look.ring
		rim.CanCollide, rim.CanQuery = false, false
		if made[pass.Outfit] then
			continue
		end
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = SKIN
		description.TorsoColor = look.shirt
		description.LeftArmColor, description.RightArmColor = look.shirt, look.shirt
		description.LeftLegColor, description.RightLegColor = look.pants, look.pants
		description.Head = look.head or 0
		description.MoodAnimation = look.mood or 0
		local rig = game:GetService("Players"):CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		rig.Name = pass.Name
		local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		local outfit = outfits and outfits:FindFirstChild(pass.Outfit)
		for _, item in if outfit then outfit:GetChildren() else {} do
			if item:IsA("Accessory") then
				humanoid:AddAccessory(item:Clone())
			elseif item:IsA("Clothing") then
				item:Clone().Parent = rig
			end
		end
		local rootPart = rig:FindFirstChild("HumanoidRootPart") :: BasePart
		rootPart.Anchored = true
		local standTop = ground + Vector3.new(0, STAND_H + humanoid.HipHeight + rootPart.Size.Y / 2, 0)
		rig:PivotTo(CFrame.lookAt(standTop, Vector3.new(front.X, standTop.Y, front.Z)))
		rig.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		rig:SetAttribute("Outfit", pass.Outfit)
		CollectionService:AddTag(rig, "CharacterNpc")
		CollectionService:AddTag(rig, "IdleNpc")
		rig.Parent = map
		table.insert(log, `{pass.Name} NPC placed`)
	end
end

-- Six seed racks around the roots, one per district. Since 2026-10-07 each is an acorn dispenser (a hopper
-- tower with a spiral slide down to a basket, facing out; DispenserController rolls acorns down the slide's
-- Slide markers when you grab); the old acorn pile is the fallback when the dispenser isn't imported.
local oldRack = map:FindFirstChild("SeedRack")
local DISPENSER_SCALE = 1.5 -- 50% bigger than modeled (the user's ask, 2026-10-08)
local dispenser = Lobby:FindFirstChild("AcornDispenser")
for i, angle in RACK_ANGLES do
	local cf = if dispenser
		then CFrame.new(at(angle, RACK_R)) * toward(angle)
		else CFrame.new(at(angle, RACK_R)) * CFrame.Angles(0, math.rad(37 * i), 0)
	local pile = place(dispenser or Lobby.AcornPile, cf, true)
	pile.Name = "SeedRack"
	if dispenser then
		pile:ScaleTo(DISPENSER_SCALE) -- about its pivot, the base's center, so it stays on the ground
	end
	CollectionService:AddTag(pile, "SeedRack")
	local nuts = (pile:FindFirstChild("AcornDispenser_Basket") or pile:FindFirstChild("AcornPile_Nuts")) :: BasePart
	if dispenser then
		for _, part in pile:GetChildren() do
			if part:IsA("BasePart") then
				local marker = part.Name:match("_Slide%d+$") ~= nil
				part.CanCollide = part.Name == "AcornDispenser_Logs" -- the legs and plinth; the slide isn't walked on
				part.CanQuery = part.CanCollide
				part.Transparency = if marker then 1 else part.Transparency
				part.CastShadow = not marker and part.Name ~= "AcornDispenser_Glow" -- the ring on the ground (2026-10-08)
				if part.Name == "AcornDispenser_Glow" then
					CollectionService:AddTag(part, "GlowRing") -- drawn as a soft spinning ring (GlowRingController)
				end
			end
		end
		local lamp = pile:FindFirstChild("AcornDispenser_Lamp")
		if lamp then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 200, 120)
			light.Range = 24
			light.Brightness = 1.5
			light.Parent = lamp
		end
	end
	local prompt = if promptTemplate then promptTemplate:Clone() else Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText = "Pick Up Seeds", "" -- one white line (was "Seeds" over "Pick Up")
	prompt.Style = Enum.ProximityPromptStyle.Custom -- drawn by PromptController (GUI pass)
	prompt.RequiresLineOfSight = false
	-- On a spot in the tower's middle (not the basket on one side), so it works from all around (2026-10-07).
	prompt.MaxActivationDistance = GameConfig.Planting.RackPromptStuds
	local spot = Instance.new("Attachment")
	spot.Name = "PromptSpot"
	spot.WorldPosition = pile:GetPivot().Position + Vector3.new(0, 3, 0)
	spot.Parent = nuts
	prompt.Parent = spot
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 36)
	-- Right above the barrel (the user's ask, 2026-10-08): the label's bottom edge just over the acorns heaped in
	-- it, centered on the tower (the model's pivot; the basket and slide pull the bounding box off-center). The
	-- old pile goes by its bounding box.
	local barrelTop = 0
	for _, name in { "AcornDispenser_Wood", "AcornDispenser_Nuts" } do
		local part = pile:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			barrelTop = math.max(barrelTop, part.Position.Y + part.Size.Y / 2)
		end
	end
	if barrelTop == 0 then
		local boxCF, boxSize = pile:GetBoundingBox()
		barrelTop = boxCF.Position.Y + boxSize.Y / 2
	end
	gui.SizeOffset = Vector2.new(0, 0.5) -- the point is the label's bottom edge, not its middle
	gui.StudsOffsetWorldSpace = Vector3.new(cf.Position.X, barrelTop + 0.5, cf.Position.Z) - nuts.Position
	gui.MaxDistance = 90
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 230, 150)
	text.TextStrokeTransparency = 0.3
	text.Text = "SEEDS"
	text.Parent = gui
	UIStyle.band(gui)
	gui.Parent = nuts
end
if oldRack then
	oldRack:Destroy()
end

-- The spawn, in the district beside the shop, facing the forest.
local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
if spawn then
	local pos = at(SPAWN_ANGLE, SPAWN_R, 0.3)
	spawn.CFrame = CFrame.lookAt(pos, pos + (pos - C) * Vector3.new(1, 0, 1))
	spawn.Transparency, spawn.CanCollide = 1, false
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
end

-- Training: each tier's bench and treadmill side by side on a glowing pad, facing the tree.
local grove = map:FindFirstChild("TrainingGrove") :: Folder
-- Tiers without stations yet get copies of the 25x bench and treadmill (their looks are rebuilt below).
for _, tier in TIERS do
	for _, kind in { "Bench Press", "Treadmill" } do
		if not grove:FindFirstChild(`{kind} {tier.multiplier}x`) then
			local copy = (grove:FindFirstChild(`{kind} 25x`) :: Model):Clone()
			copy.Name = `{kind} {tier.multiplier}x`
			copy:SetAttribute("Multiplier", tier.multiplier)
			for _, part in copy:GetDescendants() do
				if part:GetAttribute("Multiplier") ~= nil then -- the treadmill's Zone carries its own
					part:SetAttribute("Multiplier", tier.multiplier)
				end
			end
			copy.Parent = grove
		end
	end
end
local function emitter(parent: Instance, props: { [string]: any })
	local e = Instance.new("ParticleEmitter")
	-- Mostly their own colour: fully additive particles vanish against the pale pavers.
	e.LightEmission, e.LightInfluence = 0.3, 0
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
end

local function swapVisuals(
	station: Model,
	keep: { [string]: boolean },
	template: Model,
	cf: CFrame,
	tier: any,
	index: number,
	scale: number?
)
	for _, child in station:GetChildren() do
		if child:IsA("BasePart") and not keep[child.Name] then
			child:Destroy()
		end
	end
	local copy = template:Clone()
	copy:PivotTo(cf)
	copy:ScaleTo(scale or 1) -- around the pivot, the model's bottom center
	for _, part in copy:GetChildren() do
		if part:IsA("BasePart") then
			local piece = part.Name:match("_(%w+)$")
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
			if piece == "Frame" then
				part.Color = tier.color
			elseif piece == "Plates" then
				part.Color = PLATE_COLOR -- black plates, like a real bench
			elseif piece == "Glow" then
				part.Material, part.Color = Enum.Material.Neon, tier.color
				part.Transparency = if index == 1 then 1 else 0
			end
			part.Name = if piece == "Bar" then "Bar" else part.Name
			part.Parent = station
		end
	end
	copy:Destroy()
end

local PARTICLES = "rbxasset://textures/particles/"
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 180, 50)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 80)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 255, 120)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(80, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
})

-- A column of light rising straight up from a pad's ring: as wide as the ring, the same width all the way up.
local function pillar(parent: BasePart, height: number, color: ColorSequence)
	local base = Instance.new("Attachment")
	base.Position = Vector3.new(0, 0.1, 0)
	base.Parent = parent
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, height, 0)
	top.Parent = parent
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = base, top
	beam.Width0, beam.Width1 = PAD_SIZE, PAD_SIZE
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Color = color
	beam.Transparency = NumberSequence.new(0.7, 1)
	beam.Parent = parent
end

-- Each tier adds one layer to the effects of the tiers below it (level 0 = 1x, 7 = 100x), so the higher
-- the multiplier, the more impressive the pad. They hang off the pad's ring, whose +Y points up.
local function tierEffects(edge: BasePart, color: Color3, level: number)
	local tint = ColorSequence.new(color)
	local up = Enum.NormalId.Top
	if level >= 1 then -- 2x: a little glitter
		emitter(edge, {
			Color = tint,
			Texture = PARTICLES .. "sparkles_main.dds",
			Rate = 4,
			Lifetime = NumberRange.new(1, 1.6),
			Size = NumberSequence.new(0.6, 0),
			Speed = NumberRange.new(0.5, 1.2),
			EmissionDirection = up,
		})
	end
	if level >= 2 then -- 5x: twinkling stars
		emitter(edge, {
			Color = tint,
			Rate = 6,
			Lifetime = NumberRange.new(1.2, 2),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.5, 1.1),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Speed = NumberRange.new(0.5, 2),
			RotSpeed = NumberRange.new(-90, 90),
			EmissionDirection = up,
		})
	end
	if level >= 3 then -- 10x: motes streaming upward
		emitter(edge, {
			Color = tint,
			Rate = 12,
			Lifetime = NumberRange.new(2, 3),
			Size = NumberSequence.new(0.5, 0),
			Speed = NumberRange.new(3, 5),
			EmissionDirection = up,
		})
	end
	if level >= 4 then -- 25x: embers, and the pad lights up the ground
		emitter(edge, {
			Color = ColorSequence.new(Color3.fromRGB(255, 120, 30), Color3.fromRGB(255, 220, 90)),
			Rate = 20,
			Lifetime = NumberRange.new(1.5, 2.5),
			Size = NumberSequence.new(0.6, 0),
			Speed = NumberRange.new(1, 3),
			Acceleration = Vector3.new(0, 4, 0),
			SpreadAngle = Vector2.new(25, 25),
			EmissionDirection = up,
		})
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = if level >= 6 then 18 else 12
		light.Brightness = if level >= 6 then 1.5 else 1
		light.Parent = edge
	end
	if level >= 5 then -- 50x: flames licking up around the rim, and a column of light (rainbow at 100x)
		emitter(edge, {
			Color = tint,
			Texture = PARTICLES .. "fire_main.dds",
			LightEmission = 1, -- the fire texture is made to glow; Brightness keeps it bright on the pale pavers
			Brightness = 4,
			Shape = Enum.ParticleEmitterShape.Disc,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			Rate = 60,
			Lifetime = NumberRange.new(0.6, 1),
			Size = NumberSequence.new(3, 0),
			Speed = NumberRange.new(5, 8),
			EmissionDirection = up,
		})
		pillar(edge, if level >= 6 then 18 else 12, if level >= 7 then RAINBOW else tint)
	end
	if level >= 6 then -- 75x: a glowing mist hanging over the pad
		emitter(edge, {
			Color = tint,
			Texture = PARTICLES .. "smoke_main.dds",
			LightEmission = 0.5,
			Rate = 5,
			Lifetime = NumberRange.new(2, 3),
			Size = NumberSequence.new(4, 7),
			Transparency = NumberSequence.new(0.8, 1),
			Speed = NumberRange.new(0.5, 1),
			EmissionDirection = up,
		})
	end
	if level >= 7 then -- 100x: rainbow sparks bursting up and raining back down
		emitter(edge, {
			Color = RAINBOW,
			Texture = PARTICLES .. "fire_sparks_main.dds",
			LightEmission = 1,
			Brightness = 5,
			Rate = 70,
			Lifetime = NumberRange.new(1.2, 1.8),
			Size = NumberSequence.new(1.1, 0),
			Speed = NumberRange.new(8, 12),
			SpreadAngle = Vector2.new(30, 30),
			Acceleration = Vector3.new(0, -12, 0),
			EmissionDirection = up,
		})
	end
end

for index, tier in TIERS do
	local m = tier.multiplier
	local pos = at(tier.angle, PAD_R, 0.32)
	local padCF = CFrame.lookAt(pos, Vector3.new(C.X, pos.Y, C.Z)) -- -Z faces the tree
	local pad = Instance.new("Model")
	pad.Name = `TierPad {m}x`
	pad.Parent = lobby
	-- A round floor (a flat cylinder, so its local +X points up) edged with the gift board's ring mesh.
	local floor = block("Floor", Vector3.new(0.1, PAD_SIZE, PAD_SIZE), padCF * CFrame.Angles(0, 0, math.rad(90)), pad)
	floor.Shape = Enum.PartType.Cylinder
	if index == 1 then
		CollectionService:AddTag(floor, "TutorialTraining") -- the tutorial's arrow leads here (M10)
	end
	floor.Color, floor.Transparency, floor.CanCollide, floor.CanQuery = tier.color, 0.6, false, false
	local edge = (Lobby.GiftBoard:FindFirstChild("GiftBoard_Glow") :: BasePart):Clone()
	edge.Name = "Edge"
	edge.Size = Vector3.new(PAD_SIZE, 0.2, PAD_SIZE)
	edge.CFrame = padCF * CFrame.new(0, 0.05, 0)
	edge.Color = tier.color
	edge.Material = if index == 1 then Enum.Material.SmoothPlastic else Enum.Material.Neon
	edge.Anchored, edge.CanCollide, edge.CanQuery, edge.CanTouch = true, false, false, false
	edge.Parent = pad
	tierEffects(edge, tier.color, index - 1)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(230, 56) -- room for "Requirements: 100" and its icon
	gui.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	gui.MaxDistance = 120
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.62)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = tier.color
	title.TextStrokeTransparency = 0.2
	title.Text = `{m}x`
	title.Parent = gui
	-- "Requirements: 25 (tree icon)": the forests needed (a game pass unlocks it too, via the locked popup).
	local needed = GameConfig.forestsForMultiplier(m) or 0
	local line = Instance.new("Frame")
	line.Name = "Requirement"
	line.Position = UDim2.fromScale(0, 0.62)
	line.Size = UDim2.fromScale(1, 0.38)
	line.BackgroundTransparency = 1
	line.Parent = gui
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 3)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = line
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.FredokaOne
	sub.TextSize = 17
	sub.Size = UDim2.fromScale(0, 1)
	sub.AutomaticSize = Enum.AutomaticSize.X
	sub.TextColor3 = Color3.new(1, 1, 1)
	sub.Text = if needed == 0 then "Free" else `Requirements: {needed}`
	sub.Parent = line
	if needed > 0 then
		local icon = Instance.new("ImageLabel")
		icon.LayoutOrder = 2
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromOffset(20, 20)
		icon.Image = UIStyle.Icons.Forests.Image
		icon.Parent = line
	end
	UIStyle.band(gui)
	gui.Parent = edge -- not the floor: its rotation would tip the sign's offset sideways

	local bench = grove:FindFirstChild(`Bench Press {m}x`) :: Model
	local benchCF = padCF * CFrame.new(-5.5, 0.05, 0)
	swapVisuals(bench, { Bench = true, Seat = true }, Lobby.BenchPress, benchCF, tier, index, BENCH_SCALE)
	local benchPrompt = bench:FindFirstChildWhichIsA("ProximityPrompt", true)
	if benchPrompt then
		benchPrompt.ActionText, benchPrompt.ObjectText = "Train", `{m}x Bench Press`
		benchPrompt.Style = Enum.ProximityPromptStyle.Custom -- drawn by PromptController (GUI pass)
	end
	local benchPart = bench:FindFirstChild("Bench") :: BasePart
	benchPart.Size = Vector3.new(2.1, 1.75, 5.2) * BENCH_SCALE
	benchPart.CFrame = benchCF * CFrame.new(0, benchPart.Size.Y / 2, 0)
	benchPart.Transparency = 1
	local seat = bench:FindFirstChild("Seat") :: BasePart
	seat.CFrame = benchPart.CFrame
		* CFrame.new(0, benchPart.Size.Y / 2 + SEAT_ABOVE, -SEAT_TOWARD_BAR) -- the bar is at the bench's -Z end
		* CFrame.Angles(0, math.pi, 0) -- facing away from the bar
	local bar = bench:FindFirstChild("Bar") :: BasePart
	local plates = bench:FindFirstChild("BenchPress_Plates") :: BasePart
	plates.Anchored, plates.Massless = false, true -- welded to the bar, which the bench animation lifts
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = bar, plates
	weld.Parent = plates

	local tread = grove:FindFirstChild(`Treadmill {m}x`) :: Model
	local treadCF = padCF * CFrame.new(5.5, 0.05, 0)
	swapVisuals(tread, { Zone = true }, Lobby.Treadmill, treadCF, tier, index, TREAD_SCALE)
	local zonePart = tread:FindFirstChild("Zone") :: BasePart
	-- TrainingService reads the zone's own Multiplier. Set it every run: the 50x-100x zones once kept the
	-- 25x they were copied from, so a 25x unlock opened them (at 25x pay).
	zonePart:SetAttribute("Multiplier", m)
	zonePart.Size = Vector3.new(4 * TREAD_SCALE, 8, 7.6 * TREAD_SCALE) -- the belt's area, 8 studs tall
	zonePart.CFrame = treadCF * CFrame.new(0, 0.6 * TREAD_SCALE + 4, 0.3 * TREAD_SCALE)
	-- The visible pieces don't collide, so an invisible deck at the belt's top holds the runner up
	-- (swapVisuals removes the old one on a rerun).
	local beltPart = tread:FindFirstChild("Treadmill_Belt") :: BasePart
	local deck = block("Deck", Vector3.new(beltPart.Size.X, 1, beltPart.Size.Z), beltPart.CFrame, tread)
	deck.CFrame = beltPart.CFrame * CFrame.new(0, beltPart.Size.Y / 2 - 0.5, 0) -- top level with the belt
	deck.Transparency, deck.CanQuery = 1, false
	-- Arrows scrolling along the belt toward the back (the runner faces the console at -Z).
	local arrows = Lobby:FindFirstChild("TreadmillArrows")
	local belt = tread:FindFirstChild("Treadmill_Belt") :: BasePart
	if arrows then
		local turn = (arrows:FindFirstChild("Turn") :: Attachment).CFrame
		local back = Instance.new("Attachment")
		back.Name = "ArrowsBack"
		back.CFrame = CFrame.new(0, 0.06, 3.4 * TREAD_SCALE) * turn
		back.Parent = belt
		local front = Instance.new("Attachment")
		front.Name = "ArrowsFront"
		front.CFrame = CFrame.new(0, 0.06, -3.4 * TREAD_SCALE) * turn
		front.Parent = belt
		local beam = (arrows:FindFirstChildOfClass("Beam") :: Beam):Clone()
		beam.Attachment0, beam.Attachment1 = back, front
		beam.Width0, beam.Width1 = 3.2 * TREAD_SCALE, 3.2 * TREAD_SCALE
		beam.TextureLength = 1.6 * TREAD_SCALE -- the same proportions as TreadmillGold's arrows
		beam.Parent = belt
	end
	table.insert(log, `tier {m}x placed`)
end

table.insert(log, "lobby built")

-- The floating island (M11) ------------------------------------------------------------------------
local MapAssets = Assets.Map
local FLOOR_Y = 0.4 -- the forest floor's height (the plots' ground)
local WATERFALL_TEXTURE = "rbxassetid://114706914302517" -- assets/textures/waterfall.png, uploaded with Open Cloud
local BRIDGE_START, BRIDGE_LENGTH = 440, 80 -- the trails end at 440 studs; the bridges are 80 long
local ISLETS = { IsletA = { radius = 34, trees = 4 }, IsletB = { radius = 24, trees = 3 }, IsletC = { radius = 16, trees = 1 } }
local rng = Random.new(11)

local oldIsland = map:FindFirstChild("Island")
if oldIsland then
	oldIsland:Destroy()
end
local islandFolder = Instance.new("Folder")
islandFolder.Name = "Island"
islandFolder.Parent = map

-- The old flat floors go: the island ends at the outer ring and players who walk off fall and respawn.
-- The template's Baseplate goes: the island replaces it (its grid texture showed even when invisible).
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end
local forestFloor = map:FindFirstChild("ForestFloor")
if forestFloor and forestFloor:IsA("BasePart") then
	-- Invisible and walk-through, but ForestService's ground raycasts still find the plots' height on it.
	forestFloor.Transparency, forestFloor.CanCollide, forestFloor.CanQuery = 1, false, true
end

local island = place(MapAssets.Island, CFrame.new(C.X, FLOOR_Y, C.Z), false, islandFolder)
-- The walk plate (rings 7-15, plaza cut out) sits just under the tile tops and bridges every seam.
local walk = island:FindFirstChild("Island_Walk") :: BasePart
local oldWalk = map:FindFirstChild("WalkFloor")
if oldWalk then
	oldWalk:Destroy()
end
walk.Name = "WalkFloor"
walk.CFrame = walk.CFrame + Vector3.new(0, TILE_TOP - 0.05 - FLOOR_Y, 0)
walk.Transparency = 1
walk.CanCollide = true
walk.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
walk.Parent = map
CollectionService:AddTag(walk, "WalkFloor") -- ForestService's ground raycasts skip it
-- The walk plate's plaza cut-out is wider than the hub's grass (radius 160), which left a ring of gaps
-- outside the fence where players fell through. An invisible floor out to 180 fills it; tagged like the
-- walk plate so the ring-7 plot heights stay the same.
local oldEdge = map:FindFirstChild("HubEdgeFloor")
if oldEdge then
	oldEdge:Destroy()
end
local edge = hub:Clone()
edge.Name = "HubEdgeFloor"
edge.Size = Vector3.new(0.2, 360, 360)
edge.Position = hub.Position - Vector3.new(0, 0.01, 0)
edge.Transparency = 1
edge.CanCollide = true
edge.Parent = map
CollectionService:AddTag(edge, "WalkFloor")

local clouds = place(MapAssets.Clouds, CFrame.new(C.X, FLOOR_Y, C.Z), false, islandFolder)
for _, part in clouds:GetDescendants() do
	if part:IsA("BasePart") then
		part.CastShadow = false
	end
end

local function holder(name: string, position: Vector3): Part
	local part = block(name, Vector3.one, CFrame.new(position), islandFolder)
	part.Transparency, part.CanCollide, part.CanQuery = 1, false, false
	return part
end

-- A waterfall: a scrolling, camera-facing water beam from top to bottom, with mist where it fades.
local function waterfall(top: Vector3, bottom: Vector3, width: number)
	local part = holder("Waterfall", top)
	local a0 = Instance.new("Attachment")
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Parent = part -- parented first: WorldPosition on an unparented attachment is only a local offset
	a1.WorldPosition = bottom
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Texture = WATERFALL_TEXTURE
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = width * 2
	beam.TextureSpeed = 1.2
	beam.Width0, beam.Width1 = width, width * 1.6
	beam.FaceCamera = true
	beam.Segments = 12
	beam.LightEmission = 0.3
	beam.LightInfluence = 0.6
	beam.Color = ColorSequence.new(Color3.fromRGB(235, 248, 255), Color3.fromRGB(190, 225, 255))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.75, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Parent = part
	local mist = holder("WaterfallMist", bottom + (top - bottom) * 0.2)
	local spray = Instance.new("ParticleEmitter")
	spray.Rate = 5
	spray.Lifetime = NumberRange.new(3, 4)
	spray.Speed = NumberRange.new(2, 4)
	spray.SpreadAngle = Vector2.new(180, 180)
	spray.Size = NumberSequence.new(width * 0.8, width * 2)
	spray.Transparency = NumberSequence.new(0.55, 1)
	spray.Texture = "rbxasset://textures/particles/smoke_main.dds" -- soft puffs, not the default sparkle
	spray.Color = ColorSequence.new(Color3.fromRGB(240, 248, 255))
	spray.Parent = mist
end

-- Six waterfalls off the middle of the island's six cliff faces (between the trails).
for k = 0, 5 do
	local angle = 30 + 60 * k
	waterfall(at(angle, 376, FLOOR_Y - C.Y + 0.2), at(angle, 392, -150), 16)
end

-- A floating island with trees from the forest's own tree models.
local function islet(variant: string, center: Vector3, yaw: number, avoidAngle: number?): Model
	local info = ISLETS[variant]
	local model = place(MapAssets[variant], CFrame.new(center) * CFrame.Angles(0, yaw, 0), false, islandFolder)
	local top = model:FindFirstChild(variant .. "_Top") :: BasePart
	top.CanCollide, top.CanQuery = true, true -- walkable
	for i = 1, info.trees do
		local a = rng:NextNumber(0, 2 * math.pi)
		if avoidAngle and math.abs((a - avoidAngle + math.pi) % (2 * math.pi) - math.pi) < math.rad(35) then
			a += math.pi -- keep the bridge's landing clear
		end
		local d = if info.trees == 1 then 0 else rng:NextNumber(0.25, 0.6) * info.radius
		local full = #GameConfig.Growth.StageStarts -- the full-grown stage
		local tree = (Assets.Trees:FindFirstChild(if i % 2 == 0 then `Pine{full}` else `Leafy{full}`) :: Model):Clone()
		tree:ScaleTo(rng:NextNumber(0.8, 1.1))
		tree:PivotTo(
			CFrame.new(center + Vector3.new(math.cos(a) * d, -0.2, math.sin(a) * d))
				* CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		)
		for _, part in tree:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored, part.CanCollide, part.CanTouch = true, false, false
				part.CanQuery = false
			end
		end
		tree.Parent = model
	end
	return model
end

-- A bridge from the end of each trail to a floating island, level with the trails.
local variants = { "IsletA", "IsletB", "IsletC" }
for k = 0, 5 do
	local angle = 60 * k
	local bridge =
		place(MapAssets.Bridge, CFrame.new(at(angle, BRIDGE_START, TILE_TOP - C.Y)) * toward(angle), false, islandFolder)
	local planks = bridge:FindFirstChild("Bridge_Planks") :: BasePart
	planks.CanCollide, planks.CanQuery = true, true
	local variant = variants[k % 3 + 1]
	local radius = ISLETS[variant].radius
	local center = at(angle, BRIDGE_START + BRIDGE_LENGTH + radius * 0.75, TILE_TOP - C.Y)
	islet(variant, center, rng:NextNumber(0, 6.28), math.rad(angle) + math.pi)
end
-- Two more floating islands out of reach, each with a little waterfall.
for _, spec in { { 150, 560, 34, "IsletC" }, { 270, 590, -22, "IsletB" } } do
	local center = at(spec[1], spec[2], spec[3])
	islet(spec[4], center, rng:NextNumber(0, 6.28), nil)
	local edge = center + ((center - C) * Vector3.new(1, 0, 1)).Unit * (ISLETS[spec[4]].radius * 0.9)
	waterfall(edge + Vector3.new(0, -1, 0), edge + Vector3.new(0, -70, 0), 6)
end

-- Lighting: a sunny afternoon with a light haze, a little warmer and more colourful, toned down so the
-- pale plaza and the neon don't glare.
do
	local Lighting = game:GetService("Lighting")
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2
	Lighting.ExposureCompensation = -0.25
	Lighting.Ambient = Color3.fromRGB(105, 105, 115)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 155, 170)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density, atmosphere.Offset = 0.1, 0.05
	atmosphere.Color, atmosphere.Decay = Color3.fromRGB(200, 225, 255), Color3.fromRGB(120, 160, 215)
	atmosphere.Glare, atmosphere.Haze = 0.1, 0.3
	atmosphere.Parent = Lighting
	local grade = Lighting:FindFirstChild("PTFGrade") or Instance.new("ColorCorrectionEffect")
	grade.Name = "PTFGrade"
	grade.Saturation, grade.Contrast, grade.Brightness = 0.18, 0.06, 0
	grade.TintColor = Color3.fromRGB(255, 249, 240)
	grade.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Intensity, bloom.Size, bloom.Threshold = 0.2, 18, 1.4 -- a soft glow around the neon only
	end
end

-- The plaza's empty districts: the gift board (its ring opens the free gift) and a fountain.
-- They sit between a rack (30 + 60k degrees) and a trail (60k), so nothing hides behind a rack.
local GIFT_ANGLE, SEED_STALL_ANGLE = 225, 285
local DECOR_SCALE = 1.6 -- the Blender pieces read too small on the wide plaza
local function decor(template: Model, angle: number, r: number, faceTree: boolean, collide: boolean): Model
	local model = place(template, CFrame.new(at(angle, r, 0.3)) * toward(if faceTree then angle + 180 else angle), collide)
	model:ScaleTo(DECOR_SCALE)
	return model
end
local gift = decor(Lobby.GiftBoard, GIFT_ANGLE, 118, true, false)
-- No ring: walk up and press E (2026-10-07, the user's call; was a pink ring you stepped into). The prompt is
-- tagged GiftPrompt; TutorialController answers it with Roblox's Favorite prompt and hides it once claimed.
local giftGlow = gift:FindFirstChild("GiftBoard_Glow")
if giftGlow then
	giftGlow:Destroy()
end
local giftPrompt = Instance.new("ProximityPrompt")
giftPrompt.ActionText, giftPrompt.ObjectText = "Claim Free Gift", ""
giftPrompt.Style = Enum.ProximityPromptStyle.Custom -- drawn by PromptController
giftPrompt.MaxActivationDistance = 12
giftPrompt.RequiresLineOfSight = false
giftPrompt.Parent = gift:FindFirstChild("GiftBoard_Box")
CollectionService:AddTag(giftPrompt, "GiftPrompt")
local sign = Instance.new("BillboardGui")
sign.Size = UDim2.fromOffset(200, 40)
sign.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
sign.MaxDistance = 120
local signText = Instance.new("TextLabel")
signText.Size = UDim2.fromScale(1, 1)
signText.BackgroundTransparency = 1
signText.Font = Enum.Font.FredokaOne
signText.TextScaled = true
signText.TextColor3 = Color3.fromRGB(255, 140, 190)
signText.TextStrokeTransparency = 0.3
signText.Text = "FREE GIFT"
signText.Parent = sign
UIStyle.band(sign)
sign.Parent = gift:FindFirstChild("GiftBoard_Box")

-- The seed shop (docs/plans/SeedShop.md): a market stall where the fountain was (removed at the user's
-- request, 2026-10-07), facing the tree, with a seed of each kind in its crates. Stepping into its ring
-- (SeedShopZone) opens the seed shop; the altar's ring opens the upgrades.
local STALL_SCALE, STALL_R = 1.4, 120
local STALL_RING_R = 5 -- as modeled (SEED_STALL_RING_R in build_assets.py)
local STALL_CRATES = { -4.2, -2.1, 0, 2.1, 4.2 } -- crate centers along the counter, as modeled
local STALL_SEEDS = { "PalmSeed", "SakuraSeed", "BambooSeed", "RedwoodSeed", "CrystalSeed" }
local STALL_GLOW = Color3.fromRGB(255, 140, 200)
if Lobby:FindFirstChild("SeedStall") then
	local stallCF = CFrame.new(at(SEED_STALL_ANGLE, STALL_R, 0.3)) * toward(SEED_STALL_ANGLE + 180)
	local stall = place(Lobby.SeedStall, stallCF, true)
	stall:ScaleTo(STALL_SCALE)
	for _, part in stall:GetChildren() do
		if part:IsA("BasePart") and part.Name == "SeedStall_Glow" then
			part.CanCollide, part.CanQuery = false, false -- the ring is walked into
			part.Material, part.Color = Enum.Material.Neon, STALL_GLOW
		end
	end
	for i, name in STALL_SEEDS do
		local template = Assets:FindFirstChild("Seeds") and Assets.Seeds:FindFirstChild(name)
		if template then
			local seed = template:Clone()
			seed:ScaleTo(0.22 * STALL_SCALE)
			-- Blender +X is Roblox -X in the imports, so the counter's crates sit at -X.
			seed:PivotTo(stallCF * CFrame.new(-0.6 * STALL_SCALE, 3.4 * STALL_SCALE, STALL_CRATES[i] * STALL_SCALE))
			for _, part in seed:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
				end
			end
			seed.Parent = stall
		end
	end
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(200, 44)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	sign.MaxDistance = 120
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = STALL_GLOW
	text.TextStrokeTransparency = 0.3
	text.Text = "SEEDS"
	text.Parent = sign
	UIStyle.band(sign)
	sign.Parent = stall:FindFirstChild("SeedStall_Wood")
	local glow = stall:FindFirstChild("SeedStall_Glow") :: BasePart
	local ring = block(
		"SeedShopZone",
		Vector3.new(0.4, STALL_RING_R * STALL_SCALE * 2, STALL_RING_R * STALL_SCALE * 2),
		CFrame.new(glow.Position) * CFrame.Angles(0, 0, math.rad(90)), -- centered on the glowing ring
		lobby
	)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency, ring.CanCollide, ring.CanQuery = 1, false, false
	CollectionService:AddTag(ring, "SeedShopZone")
end

-- Leaderboards (polish pass, 2026-10-07): three boards behind the 330 degree acorn pile, inside the fence and
-- facing the tree. Each Board part is tagged LeaderboardBoard with its Stat; LeaderboardController draws the
-- top players on its front face (LeaderboardService publishes them).
local BOARD_R = 135
local BOARDS = { { stat = "Strength", angle = 315 }, { stat = "ForestsCompleted", angle = 330 }, { stat = "Speed", angle = 345 } }
local BOARD_WOOD = Color3.fromRGB(110, 74, 46)
local boards = Instance.new("Model")
boards.Name = "Leaderboards"
boards.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
for _, def in BOARDS do
	local base = at(def.angle, BOARD_R, 0.3)
	local face = CFrame.lookAt(base, Vector3.new(C.X, base.Y, C.Z)) -- -Z (the Front face) toward the tree
	local board = block("Board", Vector3.new(18, 20, 0.8), face * CFrame.new(0, 15, 0), boards) -- raised over the acorn pile
	board.Color = Color3.fromRGB(38, 30, 24)
	board:SetAttribute("Stat", def.stat)
	CollectionService:AddTag(board, "LeaderboardBoard")
	for _, x in { -9.6, 9.6 } do
		local post = block("Post", Vector3.new(1.2, 27.5, 1.2), face * CFrame.new(x, 13.75, 0.2), boards)
		post.Material, post.Color = Enum.Material.Wood, BOARD_WOOD
	end
	local cap = block("Cap", Vector3.new(21.5, 1.2, 2.2), face * CFrame.new(0, 27.5, 0.2), boards)
	cap.Material, cap.Color = Enum.Material.Wood, BOARD_WOOD
end
boards.Parent = lobby

table.insert(log, "island, waterfalls, floating islands, lighting and decorations built")

-- Neon glows at full colour, which glares; every neon part is darkened once. The colour it was dimmed
-- to is remembered, so a rerun skips parts that are already dim but catches any that were recoloured.
local NEON_DIM = 0.65
local dimmed = 0
for _, root in { map, Assets } do
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") and part.Material == Enum.Material.Neon and part:GetAttribute("NeonDimmed") ~= part.Color then
			local h, sat, v = part.Color:ToHSV()
			part.Color = Color3.fromHSV(h, sat, v * NEON_DIM)
			part:SetAttribute("NeonDimmed", part.Color)
			dimmed += 1
		end
	end
end
table.insert(log, `{dimmed} neon parts dimmed`)

-- Every sign in the pyramid's text look (docs/plans/GUI.md): Gotham Black, outlined, with a drop shadow.
-- Same helper as the HUD's; the signs never change, so the copies it makes are saved with the map.
local signs = 0
for _, label in map:GetDescendants() do
	if label:IsA("TextLabel") and label.Name ~= "Face" and label.Name ~= "Shadow" then
		label.Font = UIStyle.FONT
		UIStyle.dropShadow(label, if label.TextScaled then nil else label.TextSize / 12, false, UIStyle.THIN_DROP)
		signs += 1
	end
end
table.insert(log, `{signs} signs styled`)
return table.concat(log, "\n")
