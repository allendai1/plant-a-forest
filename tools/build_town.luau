-- build_town.luau: Springtown, the oasis town on the South Rim that the bridge is built to reach (2026-10-10, the user's
-- pick and concept art). Not shipped. Run it in the Edit datamodel through the Studio connection with the repo served on
-- 127.0.0.1:34877 (fetch and loadstring it). Safe to run again: it rebuilds Workspace.Map.Springtown.
--
-- Around the far landing (tools/canyon_heightmap.py LANDING: flat around (-3240, 0), the rim at x -3180; the ground
-- falls away south of about z -80):
-- - a timber archway at the bridge's end with a hanging SPRINGTOWN sign and lanterns
-- - the oasis: a turquoise pool with sandstone rocks and palms, on the Spring itself (the break's training circle,
--   GameConfig.Awakening, radius 43 around (-3240, 0)), with gaps in the rocks to walk in
-- - behind it the inn (two storeys, balcony, smoking chimney), the general store (tall western front, striped awning)
--   and the water tower; a stable with hay to the north; barrels and crates
-- - a fence with lantern posts along the rim, lantern posts round the plaza
-- Kept loaded (Persistent), so it shows from camp and the bridge. Lit windows and lanterns are Neon; a few lanterns
-- carry real lights. Nothing stands on the bridge's line from the rim to the pool.
--
-- Each map has its own town (2026-10-11, the user's ask: "not just Springtown"): set _G.TownPlace = "zion" first, with
-- that map's terrain live in Studio (MapService's paste), to build Springdale into ServerStorage.Maps.Zion.Springtown
-- (the model keeps the name Springtown everywhere: MapService and GrandOpeningController find it by it). Then copy the
-- terrain back into that map's folder, since the pool is carved into it. Zion's landing is smaller (flat over x -3180
-- to -3340, z -100 to 100), so its buildings sit closer in.

local PLACES = {
	grand = {
		name = "SPRINGTOWN",
		inn = { sign = "INN", x = -3280, z = 96 },
		store = { sign = "GENERAL STORE", x = -3335, z = 30 },
		tower = { x = -3300, z = -32 },
		stable = { x = -3232, z = 128 },
		fence = { { 36, 112 }, { -36, -76 } },
		posts = { { -3215, 48 }, { -3215, -46 }, { -3268, 62 }, { -3272, -50 }, { -3300, 12 } },
		folk = { { -3202, 34 }, { -3204, -34 }, { -3209, 40 }, { -3263, 79 }, { -3318, 24 }, { -3224, 112 } },
		tree = "palm",
	},
	-- Springdale, the real town at Zion's gate: a stone-and-timber lodge (Zion Lodge's look) with green roofs, a trading
	-- post, red sandstone and cottonwoods (the trees along the Virgin River) instead of palms.
	zion = {
		into = "Zion",
		name = "SPRINGDALE",
		inn = { sign = "ZION LODGE", x = -3320, z = 0, stone = true },
		store = { sign = "TRADING POST", x = -3270, z = -78 },
		tower = { x = -3305, z = -50 },
		stable = { x = -3250, z = 80 },
		fence = { { 36, 88 }, { -36, -88 } },
		posts = { { -3215, 48 }, { -3215, -46 }, { -3268, 62 }, { -3272, -50 }, { -3290, 30 } },
		folk = { { -3202, 34 }, { -3204, -34 }, { -3209, 40 }, { -3275, 72 }, { -3296, 24 }, { -3226, 70 } },
		tree = "cottonwood",
		roof = Color3.fromRGB(62, 88, 64),
		stone = Color3.fromRGB(170, 90, 66),
		rock = Color3.fromRGB(186, 84, 58),
		water = Color3.fromRGB(72, 190, 168),
	},
	-- Moustiers (2026-10-11, the Verdon Gorge): a Provence village after Moustiers-Sainte-Marie, at the gorge's west end.
	-- Cream plaster walls under terracotta tile roofs with blue shutters, an AUBERGE (inn) and a BOULANGERIE (bakery,
	-- no western false front), a stone bell tower instead of the water tower, cypresses and olives round the Spring
	-- (models from tools/blender/build_verdon_plants.py), white limestone rocks, a lavender field, and Moustiers' golden
	-- star hanging on its chain from the archway (the real one hangs between two cliffs over the village).
	verdon = {
		into = "Verdon",
		name = "MOUSTIERS",
		inn = { sign = "AUBERGE", x = -3290, z = 100 },
		store = { sign = "BOULANGERIE", x = -3340, z = 20, front = false },
		tower = { x = -3300, z = -60, kind = "bell" },
		stable = { x = -3240, z = 140 },
		fence = { { 36, 150 }, { -36, -150 } },
		posts = { { -3215, 48 }, { -3215, -46 }, { -3268, 62 }, { -3272, -50 }, { -3300, 12 } },
		folk = { { -3202, 34 }, { -3204, -34 }, { -3209, 40 }, { -3263, 79 }, { -3318, 44 }, { -3224, 112 } },
		tree = { "Cypress", "Olive" }, -- NatureAssets models, alternating round the Spring
		roof = Color3.fromRGB(184, 92, 60),
		roofMaterial = Enum.Material.ClayRoofTiles,
		walls = { Color3.fromRGB(232, 214, 180), Enum.Material.Plaster },
		trim = Color3.fromRGB(78, 118, 156), -- the shutters and window frames
		awning = { Color3.fromRGB(66, 104, 160), Color3.fromRGB(240, 236, 226) },
		stone = Color3.fromRGB(206, 196, 178),
		rock = Color3.fromRGB(226, 222, 210),
		water = Color3.fromRGB(56, 176, 156),
		star = true,
		lavender = { x0 = -3440, x1 = -3380, z0 = -170, z1 = -40, rowEvery = 8, plantEvery = 4.5 },
	},
}
local PLACE = PLACES[_G.TownPlace or "grand"]
assert(PLACE, `no town {_G.TownPlace}`)

local map = workspace:WaitForChild("Map")
local home = if PLACE.into then game:GetService("ServerStorage").Maps[PLACE.into] else map
local old = home:FindFirstChild("Springtown")
if old then
	old:Destroy()
end
local town = Instance.new("Model")
town.Name = "Springtown"
town.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

local SPRING = Vector3.new(-3240, 0, 0)
local RIM_X = -3180
local WOOD = Color3.fromRGB(150, 98, 58)
local WOOD_DARK = Color3.fromRGB(96, 62, 40)
local WOOD_LIGHT = Color3.fromRGB(196, 146, 96)
local ROOF = PLACE.roof or Color3.fromRGB(84, 70, 64)
local STONE = PLACE.stone or Color3.fromRGB(150, 132, 118)
local ROCK = PLACE.rock or Color3.fromRGB(210, 150, 104)
local ROOF_MATERIAL = PLACE.roofMaterial or Enum.Material.Wood
local WALL = PLACE.walls and PLACE.walls[1] -- nil: the buildings' own wood
local WALL_MATERIAL = PLACE.walls and PLACE.walls[2]
local TRIM = PLACE.trim or Color3.fromRGB(96, 62, 40)
local GLOW = Color3.fromRGB(255, 196, 110)
local WATER = PLACE.water or Color3.fromRGB(64, 206, 200)
local LEAF = Color3.fromRGB(74, 140, 66)
local FONT = Enum.Font.GothamBlack -- the GUIs' font (UIStyle.FONT)

local rng = Random.new(1869) -- Powell's first run down the Colorado

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }
local function groundAt(x: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1500, 0), params)
	return if hit then hit.Position.Y else 2
end

type Options = { collide: boolean?, shape: Enum.PartType?, transparency: number?, shadow: boolean? }
local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	o: Options?
): Part
	local opts = o or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Wood
	p.Shape = opts.shape or Enum.PartType.Block
	p.Transparency = opts.transparency or 0
	p.Anchored = true
	p.CanCollide = opts.collide ~= false
	p.CanQuery = opts.collide ~= false
	p.CanTouch = false
	p.CastShadow = opts.shadow ~= false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function group(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or town
	return m
end

local function beam(parent: Instance, name: string, a: Vector3, b: Vector3, thick: number, color: Color3, collide: boolean?): Part
	return part(
		parent,
		name,
		Vector3.new(thick, thick, (b - a).Magnitude),
		CFrame.lookAt((a + b) / 2, b),
		color,
		Enum.Material.Wood,
		{ collide = collide == true }
	)
end

-- A sign board facing along cf's LookVector: `text` in the GUIs' font, dark letters on cream, a wood frame.
local function sign(parent: Instance, cf: CFrame, width: number, height: number, text: string)
	part(
		parent,
		"SignFrame",
		Vector3.new(width + 0.8, height + 0.8, 0.4),
		cf * CFrame.new(0, 0, 0.15),
		WOOD_DARK,
		Enum.Material.Wood,
		{ collide = false }
	)
	local board = part(
		parent,
		"Sign",
		Vector3.new(width, height, 0.3),
		cf,
		Color3.fromRGB(238, 222, 186),
		Enum.Material.WoodPlanks,
		{ collide = false }
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0.4
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.92, 0.8)
	label.Position = UDim2.fromScale(0.04, 0.1)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(70, 40, 24)
	label.Text = text
	label.Parent = gui
end

-- A lantern: a dark frame round a glowing box; `light` adds a real warm light (used sparingly).
local function lantern(parent: Instance, at: Vector3, light: boolean?)
	part(
		parent,
		"LanternCap",
		Vector3.new(1.3, 0.3, 1.3),
		CFrame.new(at + Vector3.new(0, 0.95, 0)),
		Color3.fromRGB(40, 36, 34),
		Enum.Material.Metal,
		{ collide = false }
	)
	local glow = part(
		parent,
		"Lantern",
		Vector3.new(1, 1.6, 1),
		CFrame.new(at),
		GLOW,
		Enum.Material.Neon,
		{ collide = false, shadow = false }
	)
	part(
		parent,
		"LanternBase",
		Vector3.new(1.2, 0.25, 1.2),
		CFrame.new(at - Vector3.new(0, 0.9, 0)),
		Color3.fromRGB(40, 36, 34),
		Enum.Material.Metal,
		{ collide = false }
	)
	if light then
		local l = Instance.new("PointLight")
		l.Color = GLOW
		l.Range = 22
		l.Brightness = 1.2
		l.Parent = glow
	end
end

local function lanternPost(parent: Instance, x: number, z: number, light: boolean?)
	local g = groundAt(x, z)
	part(parent, "Post", Vector3.new(0.8, 10, 0.8), CFrame.new(x, g + 5, z), WOOD_DARK)
	part(
		parent,
		"Arm",
		Vector3.new(2.2, 0.4, 0.4),
		CFrame.new(x + 0.9, g + 9.6, z),
		WOOD_DARK,
		Enum.Material.Wood,
		{ collide = false }
	)
	lantern(parent, Vector3.new(x + 1.8, g + 8.2, z), light)
end

-- A building's base: cf on the ground at (x, z) facing `toward`, and a timber foundation filling down to the lowest
-- ground under its footprint (w wide, d deep), its top `lift` over the highest corner.
local function siteAt(parent: Instance, x: number, z: number, toward: Vector3, w: number, d: number, lift: number): CFrame
	local base = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(toward.X, 0, toward.Z))
	local lo, hi = math.huge, -math.huge
	for _, c in { { -w / 2, -d / 2 }, { w / 2, -d / 2 }, { -w / 2, d / 2 }, { w / 2, d / 2 }, { 0, 0 } } do
		local p = base * Vector3.new(c[1], 0, c[2])
		local g = groundAt(p.X, p.Z)
		lo, hi = math.min(lo, g), math.max(hi, g)
	end
	local floor = hi + lift
	local tall = floor - lo + 2
	part(
		parent,
		"Foundation",
		Vector3.new(w + 1, tall, d + 1),
		base * CFrame.new(0, floor - tall / 2, 0) + Vector3.new(0, 0, 0),
		STONE,
		Enum.Material.Cobblestone
	)
	return base + Vector3.new(0, floor, 0)
end

-- Lit windows on a wall: `count` across, at height `y`, on the face at local z = `face` (front is -z).
local function windows(parent: Instance, cf: CFrame, width: number, face: number, y: number, count: number)
	for k = 1, count do
		local x = (k - (count + 1) / 2) * width / count
		part(
			parent,
			"WindowFrame",
			Vector3.new(3.4, 4, 0.3),
			cf * CFrame.new(x, y, face),
			TRIM,
			Enum.Material.Wood,
			{ collide = false }
		)
		part(
			parent,
			"Window",
			Vector3.new(2.6, 3.2, 0.35),
			cf * CFrame.new(x, y, face),
			GLOW,
			Enum.Material.Neon,
			{ collide = false, shadow = false }
		)
	end
end

-- A gable roof over a w x d box whose walls end at `top`, the ridge running along local x.
local function gableRoof(parent: Instance, cf: CFrame, w: number, d: number, top: number, rise: number)
	local half = d / 2 + 1.5
	local slope = math.sqrt(half * half + rise * rise)
	local angle = math.atan2(rise, half)
	for _, s in { -1, 1 } do
		part(
			parent,
			"Roof",
			Vector3.new(w + 3, 0.8, slope),
			cf * CFrame.new(0, top + rise / 2, s * half / 2) * CFrame.Angles(s * angle, 0, 0),
			ROOF,
			ROOF_MATERIAL
		)
	end
	-- Gable ends: two wedges filling the triangle under the roof at each end.
	for _, e in { -1, 1 } do
		for _, s in { -1, 1 } do
			local wedge = Instance.new("WedgePart")
			wedge.Name = "Gable"
			wedge.Size = Vector3.new(0.6, rise, d / 2)
			wedge.CFrame = cf
				* CFrame.new(e * (w / 2 - 0.3), top + rise / 2, s * d / 4)
				* CFrame.Angles(0, if s > 0 then math.pi else 0, 0)
			wedge.Color = WALL or WOOD
			wedge.Material = WALL_MATERIAL or Enum.Material.WoodPlanks
			wedge.Anchored = true
			wedge.Parent = parent
		end
	end
end

local function barrel(parent: Instance, cf: CFrame)
	part(
		parent,
		"Barrel",
		Vector3.new(3, 2.4, 2.4),
		cf * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
		WOOD_LIGHT,
		Enum.Material.Wood,
		{ shape = Enum.PartType.Cylinder }
	)
	for _, y in { 0.6, 2.4 } do
		part(
			parent,
			"Hoop",
			Vector3.new(0.2, 2.5, 2.5),
			cf * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(50, 46, 44),
			Enum.Material.Metal,
			{ shape = Enum.PartType.Cylinder, collide = false }
		)
	end
end

local function crate(parent: Instance, cf: CFrame, s: number)
	part(parent, "Crate", Vector3.one * s, cf * CFrame.new(0, s / 2, 0), WOOD_LIGHT, Enum.Material.WoodPlanks)
end

local function palm(parent: Instance, x: number, z: number, height: number)
	local m = group("Palm", parent)
	local g = groundAt(x, z)
	local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit * rng:NextNumber(0.12, 0.25)
	local prev = Vector3.new(x, g - 0.5, z)
	local segments = 6
	for k = 1, segments do
		local t = k / segments
		local nextPoint = Vector3.new(x, g, z) + Vector3.new(0, height * t, 0) + lean * height * t * t
		local seg = part(
			m,
			"Trunk",
			Vector3.new(1.6 - t * 0.5, 1.6 - t * 0.5, (nextPoint - prev).Magnitude + 0.4),
			CFrame.lookAt((prev + nextPoint) / 2, nextPoint),
			Color3.fromRGB(136, 108, 76),
			Enum.Material.Wood,
			{ collide = k <= 2 }
		)
		seg.Shape = Enum.PartType.Block
		prev = nextPoint
	end
	local top = prev
	for k = 1, 8 do
		local yaw = (k / 8) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local frond = CFrame.new(top)
			* CFrame.Angles(0, yaw, 0)
			* CFrame.Angles(math.rad(-25 - rng:NextNumber(0, 15)), 0, 0)
			* CFrame.new(0, 0, -4.2)
		part(m, "Frond", Vector3.new(2.4, 0.25, 9), frond, LEAF, Enum.Material.Grass, { collide = false })
	end
	for k = 1, 3 do
		part(
			m,
			"Coconut",
			Vector3.one * 0.9,
			CFrame.new(top + Vector3.new(math.cos(k * 2.1) * 0.8, -0.6, math.sin(k * 2.1) * 0.8)),
			Color3.fromRGB(110, 78, 46),
			Enum.Material.Wood,
			{ shape = Enum.PartType.Ball, collide = false }
		)
	end
end

-- A cottonwood (Zion's): a short leaning trunk forking into two, under a broad clump of round leafy balls.
local function cottonwood(parent: Instance, x: number, z: number, height: number)
	local m = group("Cottonwood", parent)
	local g = groundAt(x, z)
	local base = Vector3.new(x, g - 0.5, z)
	local fork = base + Vector3.new(rng:NextNumber(-1.5, 1.5), height * 0.45, rng:NextNumber(-1.5, 1.5))
	beam(m, "Trunk", base, fork, 2.2, Color3.fromRGB(112, 96, 82), true)
	local crown = {}
	for k = 1, 2 do
		local a = k * math.pi + rng:NextNumber(-0.5, 0.5)
		local tip = fork + Vector3.new(math.cos(a) * height * 0.22, height * 0.3, math.sin(a) * height * 0.22)
		beam(m, "Branch", fork, tip, 1.3, Color3.fromRGB(112, 96, 82))
		table.insert(crown, tip)
	end
	for k = 1, 7 do
		local at = crown[k % 2 + 1] + Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(-1, 3), rng:NextNumber(-4, 4))
		local s = rng:NextNumber(7, 11)
		local leaf = LEAF:Lerp(Color3.fromRGB(150, 170, 70), rng:NextNumber(0, 0.5))
		part(
			m,
			"Leaves",
			Vector3.one * s,
			CFrame.new(at),
			leaf,
			Enum.Material.Grass,
			{ shape = Enum.PartType.Ball, collide = false }
		)
	end
end

-- A copy of a NatureAssets model (tools/blender/build_*_plants.py) on the ground at (x, z), about `height` tall.
local natureAssets = game:GetService("ServerStorage"):FindFirstChild("NatureAssets")
local function modelTree(species: string): (Instance, number, number, number) -> ()
	return function(parent: Instance, x: number, z: number, height: number)
		local shapes = {}
		for _, m in natureAssets:GetChildren() do
			if m:GetAttribute("Species") == species then
				table.insert(shapes, m)
			end
		end
		local m = shapes[rng:NextInteger(1, #shapes)]:Clone() :: Model
		local _, size = m:GetBoundingBox()
		m:ScaleTo(m:GetScale() * height / size.Y)
		m:PivotTo(CFrame.new(x, groundAt(x, z) - 0.4, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		m.Parent = parent
	end
end

local trees: { (Instance, number, number, number) -> () } = {}
if typeof(PLACE.tree) == "table" then
	for _, species in PLACE.tree do
		table.insert(trees, modelTree(species))
	end
else
	trees = { if PLACE.tree == "cottonwood" then cottonwood else palm }
end
local treeCount = 0
local function tree(parent: Instance, x: number, z: number, height: number)
	treeCount += 1
	trees[(treeCount - 1) % #trees + 1](parent, x, z, height)
end

-------------------------------------------------------------------------------------------------------------------
-- The archway at the bridge's end.

do
	local arch = group("Archway")
	local x = RIM_X - 12
	local g = groundAt(x, 0)
	local H, W = 24, 56
	for _, s in { -1, 1 } do
		part(arch, "Post", Vector3.new(3, H, 3), CFrame.new(x, g + H / 2, s * W / 2), WOOD_DARK)
		part(arch, "PostBase", Vector3.new(4.4, 2, 4.4), CFrame.new(x, g + 1, s * W / 2), STONE, Enum.Material.Cobblestone)
		beam(
			arch,
			"Brace",
			Vector3.new(x, H + g - 7, s * (W / 2 - 1)),
			Vector3.new(x, H + g - 1.5, s * (W / 2 - 7)),
			1.2,
			WOOD_DARK
		)
	end
	part(arch, "Beam", Vector3.new(3, 2.6, W + 8), CFrame.new(x, g + H - 1, 0), WOOD_DARK)
	part(arch, "Cap", Vector3.new(3.6, 0.8, W + 9), CFrame.new(x, g + H + 0.7, 0), WOOD, Enum.Material.Wood, { collide = false })
	-- SPRINGTOWN on both faces, hanging under the beam on chains.
	for _, face in { 1, -1 } do
		local cf = CFrame.lookAt(Vector3.new(x + face * 0.6, g + H - 6, 0), Vector3.new(x + face * 10, g + H - 6, 0))
		sign(arch, cf, 26, 5, PLACE.name)
	end
	for _, z in { -10, 10 } do
		part(
			arch,
			"Chain",
			Vector3.new(0.2, 2.6, 0.2),
			CFrame.new(x, g + H - 3.1, z),
			Color3.fromRGB(50, 46, 44),
			Enum.Material.Metal,
			{ collide = false }
		)
	end
	for _, z in { -20, 20 } do
		part(
			arch,
			"Hook",
			Vector3.new(0.2, 2.2, 0.2),
			CFrame.new(x, g + H - 3.3, z),
			Color3.fromRGB(50, 46, 44),
			Enum.Material.Metal,
			{ collide = false }
		)
		lantern(arch, Vector3.new(x, g + H - 5.3, z), true)
	end
	if PLACE.star then
		-- Moustiers' star: a gold five-pointed star high over the archway, hung on a chain from a tall pole each side.
		local top = g + H + 34
		for _, s in { -1, 1 } do
			part(arch, "StarPole", Vector3.new(1.4, top - g, 1.4), CFrame.new(x, g + (top - g) / 2, s * (W / 2 + 4)), WOOD_DARK)
			beam(
				arch,
				"StarChain",
				Vector3.new(x, top, s * (W / 2 + 4)),
				Vector3.new(x, top - 12, 0),
				0.35,
				Color3.fromRGB(60, 56, 52)
			)
		end
		local gold = Color3.fromRGB(240, 196, 70)
		for k = 0, 4 do -- five points round a middle
			local a = k * math.pi * 2 / 5
			local point = CFrame.new(x, top - 16, 0) * CFrame.Angles(a, 0, 0) * CFrame.new(0, 2.6, 0)
			local wedge = Instance.new("WedgePart")
			wedge.Name = "StarPoint"
			wedge.Size = Vector3.new(0.6, 4.2, 1.7)
			wedge.CFrame = point
			wedge.Color, wedge.Material = gold, Enum.Material.Metal
			wedge.Anchored, wedge.CanCollide, wedge.CanQuery = true, false, false
			wedge.Parent = arch
			local mirror = wedge:Clone()
			mirror.CFrame = point * CFrame.Angles(0, math.pi, 0)
			mirror.Parent = arch
		end
		part(
			arch,
			"StarMiddle",
			Vector3.new(0.8, 2.6, 2.6),
			CFrame.new(x, top - 16, 0),
			gold,
			Enum.Material.Metal,
			{ collide = false }
		)
	end
end

-------------------------------------------------------------------------------------------------------------------
-- The oasis: the Spring is a real pool (2026-10-10, the user's note: players stood on top of it instead of soaking). A
-- basin is carved into the terrain, POOL_DEPTH deep in the middle and sloping up over its last few studs, sand on its
-- floor and round it, and the water's surface (a see-through part, not terrain water: that would make players swim)
-- sits at chest height, so players wade in and stand in it. Steam drifts off it. The rocks ring it with four ways in.
-- Training counts there (TrainingService inSpring allows 6 studs under the Spring's height).

do
	local oasis = group("Oasis")
	local R = 34
	local POOL_DEPTH = 4.8
	local WATER_UP = 4.2 -- the surface over the floor: chest height on a character (the user's call; waist, 3, before)
	-- The rim's height, from outside the basin (so a rerun after carving reads the same).
	local g = groundAt(SPRING.X + R + 14, SPRING.Z)
	local terrain = workspace.Terrain
	-- Shape the basin voxel by voxel: each 4-stud column inside R + 1 gets a floor POOL_DEPTH under the rim in the
	-- middle, rising smoothly to the rim over the last SLOPE studs, sand from 8 studs under it up to the floor (the top
	-- voxel partly filled, so the floor sits exactly there; FillCylinder only cuts in whole 4-stud steps) and air
	-- above it. Columns outside the basin aren't touched. Then the ground round it turns to sand.
	local SLOPE = 7
	local region = Region3.new(
		Vector3.new(SPRING.X - R - 4, g - 16, SPRING.Z - R - 4),
		Vector3.new(SPRING.X + R + 4, g + 8, SPRING.Z + R + 4)
	):ExpandToGrid(4)
	local materials, occupancy = terrain:ReadVoxels(region, 4)
	local low = region.CFrame.Position - region.Size / 2
	local size = materials.Size
	for i = 1, size.X do
		for k = 1, size.Z do
			local x, z = low.X + (i - 0.5) * 4, low.Z + (k - 0.5) * 4
			local r = Vector2.new(x - SPRING.X, z - SPRING.Z).Magnitude
			if r <= R + 1 then
				local t = math.clamp((R + 1 - r) / SLOPE, 0, 1)
				-- Smooth terrain draws the surface about 2 studs over the filled height (measured), so fill 2 lower.
				local floorY = g - POOL_DEPTH * t * t * (3 - 2 * t) - 2
				for j = 1, size.Y do
					local vy = low.Y + (j - 1) * 4
					if vy + 4 <= floorY then
						if vy + 4 > floorY - 8 then
							materials[i][j][k], occupancy[i][j][k] = Enum.Material.Sand, 1
						end
					elseif vy < floorY then
						materials[i][j][k], occupancy[i][j][k] = Enum.Material.Sand, (floorY - vy) / 4
					else
						materials[i][j][k], occupancy[i][j][k] = Enum.Material.Air, 0
					end
				end
			end
		end
	end
	terrain:WriteVoxels(region, 4, materials, occupancy)
	local around = Region3.new(
		Vector3.new(SPRING.X - R - 10, g - 16, SPRING.Z - R - 10),
		Vector3.new(SPRING.X + R + 10, g + 4, SPRING.Z + R + 10)
	):ExpandToGrid(4)
	for _, material in { Enum.Material.Ground, Enum.Material.Limestone, Enum.Material.Sandstone, Enum.Material.Mud } do
		terrain:ReplaceMaterial(around, 4, material, Enum.Material.Sand)
	end
	local floor = groundAt(SPRING.X, SPRING.Z)
	local surface = math.min(floor + WATER_UP, g - 0.6) -- never over the rim
	local pool = part(
		oasis,
		"Pool",
		Vector3.new(0.4, R * 2 + 2, R * 2 + 2),
		CFrame.new(SPRING.X, surface - 0.2, SPRING.Z) * CFrame.Angles(0, 0, math.pi / 2),
		WATER,
		Enum.Material.Glass,
		{ shape = Enum.PartType.Cylinder, collide = false, shadow = false }
	)
	pool.Transparency = 0.3
	-- Steam off the warm water.
	local steam = Instance.new("ParticleEmitter")
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	steam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	steam.Size = NumberSequence.new(5, 14)
	steam.Lifetime = NumberRange.new(4, 6)
	steam.Rate = 6
	steam.Speed = NumberRange.new(1.5, 3)
	steam.SpreadAngle = Vector2.new(15, 15)
	steam.Shape = Enum.ParticleEmitterShape.Disc
	steam.EmissionDirection = Enum.NormalId.Right -- the cylinder lies on its side: its Right face is up
	steam.LightInfluence = 0.6
	steam.Parent = pool
	-- Sandstone rocks round the rim, leaving four ways in (toward the bridge, the town and both sides).
	for k = 0, 35 do
		local a = k / 36 * math.pi * 2
		local nearGap = math.abs(((a + math.pi / 4) % (math.pi / 2)) - math.pi / 4) < 0.22
		if not nearGap then
			local s = rng:NextNumber(2.4, 4.2)
			local r = R + rng:NextNumber(1.5, 3.5)
			local x, z = SPRING.X + math.cos(a) * r, SPRING.Z + math.sin(a) * r
			part(
				oasis,
				"Rock",
				Vector3.new(s * 1.3, s * 0.8, s),
				CFrame.new(x, groundAt(x, z) + s * 0.25, z)
					* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.3), rng:NextNumber(-0.3, 0.3)),
				ROCK,
				Enum.Material.Sandstone
			)
		end
	end
	for k, a in { 0.5, 1.2, 2.0, 2.7, 3.6, 4.3, 5.2, 5.85 } do
		local r = R + 6 + (k % 2) * 3
		tree(oasis, SPRING.X + math.cos(a) * r, SPRING.Z + math.sin(a) * r, rng:NextNumber(16, 24))
	end
	-- Desert grass tufts round the sand.
	for k = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = R + rng:NextNumber(3, 9)
		local x, z = SPRING.X + math.cos(a) * r, SPRING.Z + math.sin(a) * r
		part(
			oasis,
			"Tuft",
			Vector3.new(2, 1.2, 2),
			CFrame.new(x, groundAt(x, z) + 0.4, z) * CFrame.Angles(0, rng:NextNumber(0, 6.3), 0),
			Color3.fromRGB(120, 150, 80),
			Enum.Material.Grass,
			{ shape = Enum.PartType.Ball, collide = false }
		)
	end
end

-------------------------------------------------------------------------------------------------------------------
-- The inn: two storeys, a porch with a balcony over it, lit windows, a stone chimney with smoke.

do
	local inn = group("Inn")
	local W, D, H = 34, 22, 22
	local cf = siteAt(inn, PLACE.inn.x, PLACE.inn.z, SPRING, W, D, 1)
	part(
		inn,
		"Walls",
		Vector3.new(W, H, D),
		cf * CFrame.new(0, H / 2, 0),
		WALL or WOOD,
		WALL_MATERIAL or Enum.Material.WoodPlanks
	)
	if PLACE.inn.stone then -- a stone ground storey, timber above (a lodge)
		part(inn, "StoneStorey", Vector3.new(W + 0.2, H / 2, D + 0.2), cf * CFrame.new(0, H / 4, 0), STONE, Enum.Material.Slate)
	end
	part(
		inn,
		"Trim",
		Vector3.new(W + 0.4, 0.8, D + 0.4),
		cf * CFrame.new(0, H / 2, 0),
		if WALL then STONE else WOOD_DARK,
		if WALL then Enum.Material.Cobblestone else Enum.Material.Wood
	)
	gableRoof(inn, cf, W, D, H, 8)
	windows(inn, cf, W, -D / 2 - 0.1, 5.5, 4)
	windows(inn, cf, W, -D / 2 - 0.1, 16, 4)
	part(
		inn,
		"Door",
		Vector3.new(5, 8, 0.4),
		cf * CFrame.new(0, 4, -D / 2 - 0.15),
		WOOD_DARK,
		Enum.Material.Wood,
		{ collide = false }
	)
	-- Porch and balcony.
	local P = 8
	part(inn, "Porch", Vector3.new(W, 0.8, P), cf * CFrame.new(0, 0.4, -D / 2 - P / 2), WOOD_LIGHT, Enum.Material.WoodPlanks)
	part(
		inn,
		"Balcony",
		Vector3.new(W, 0.8, P),
		cf * CFrame.new(0, H / 2 + 0.4, -D / 2 - P / 2),
		WOOD_LIGHT,
		Enum.Material.WoodPlanks
	)
	for k = 0, 4 do
		local x = -W / 2 + 0.6 + k * (W - 1.2) / 4
		part(inn, "PorchPost", Vector3.new(0.8, H / 2, 0.8), cf * CFrame.new(x, H / 4, -D / 2 - P + 0.5), WOOD_DARK)
		part(inn, "RailPost", Vector3.new(0.5, 3.4, 0.5), cf * CFrame.new(x, H / 2 + 2.5, -D / 2 - P + 0.5), WOOD_DARK)
	end
	part(
		inn,
		"Rail",
		Vector3.new(W, 0.4, 0.4),
		cf * CFrame.new(0, H / 2 + 4, -D / 2 - P + 0.5),
		WOOD_DARK,
		Enum.Material.Wood,
		{ collide = false }
	)
	part(
		inn,
		"BalconyRoof",
		Vector3.new(W + 1, 0.6, P + 1),
		cf * CFrame.new(0, H - 1, -D / 2 - P / 2) * CFrame.Angles(math.rad(-8), 0, 0),
		ROOF,
		ROOF_MATERIAL
	)
	sign(inn, cf * CFrame.new(0, H / 2 + 7.5, -D / 2 - P + 0.1), #PLACE.inn.sign * 1.6 + 8, 3, PLACE.inn.sign)
	lantern(inn, (cf * CFrame.new(-5, 7, -D / 2 - P + 1)).Position, true)
	lantern(inn, (cf * CFrame.new(5, 7, -D / 2 - P + 1)).Position)
	-- Chimney with smoke.
	local chimney =
		part(inn, "Chimney", Vector3.new(3.6, 14, 3.6), cf * CFrame.new(W / 2 - 4, H + 5, 3), STONE, Enum.Material.Cobblestone)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(230, 226, 220))
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	smoke.Size = NumberSequence.new(2.5, 9)
	smoke.Lifetime = NumberRange.new(4, 6)
	smoke.Rate = 4
	smoke.Speed = NumberRange.new(3, 5)
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.Acceleration = Vector3.new(1.2, 0.6, 0)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Parent = chimney
	for k = 0, 2 do
		barrel(inn, cf * CFrame.new(W / 2 + 3, 0, -D / 2 + 3 + k * 3.2))
	end
end

-------------------------------------------------------------------------------------------------------------------
-- The general store: a tall western false front with its sign, a striped awning over the porch, goods outside.

do
	local store = group("GeneralStore")
	local W, D, H = 30, 20, 14
	local cf = siteAt(store, PLACE.store.x, PLACE.store.z, SPRING, W, D, 1)
	part(
		store,
		"Walls",
		Vector3.new(W, H, D),
		cf * CFrame.new(0, H / 2, 0),
		WALL or Color3.fromRGB(170, 118, 72),
		WALL_MATERIAL or Enum.Material.WoodPlanks
	)
	gableRoof(store, cf, W, D, H, 5)
	local front = -D / 2 - 1 -- the false front's face; the wall's own without one
	if PLACE.store.front ~= false then
		part(
			store,
			"FalseFront",
			Vector3.new(W + 2, H + 8, 1),
			cf * CFrame.new(0, (H + 8) / 2, -D / 2 - 0.5),
			Color3.fromRGB(182, 128, 80),
			Enum.Material.WoodPlanks
		)
		part(store, "FrontCap", Vector3.new(W + 3, 0.8, 1.6), cf * CFrame.new(0, H + 8.2, -D / 2 - 0.5), WOOD_DARK)
		sign(store, cf * CFrame.new(0, H + 3.6, front - 0.15), 22, 4, PLACE.store.sign)
	else
		front = -D / 2
		sign(store, cf * CFrame.new(0, H - 2.6, front - 0.3), 22, 3.4, PLACE.store.sign)
	end
	windows(store, cf, W - 10, front - 0.1, 5.2, 2)
	part(
		store,
		"Door",
		Vector3.new(5, 8, 0.4),
		cf * CFrame.new(0, 4, front - 0.15),
		TRIM,
		Enum.Material.Wood,
		{ collide = false }
	)
	local P = 8
	part(
		store,
		"Porch",
		Vector3.new(W, 0.8, P),
		cf * CFrame.new(0, 0.4, -D / 2 - 1 - P / 2),
		WOOD_LIGHT,
		Enum.Material.WoodPlanks
	)
	-- The striped awning: red and cream strips sloping down from the front.
	local strips = 10
	for k = 0, strips - 1 do
		local x = -W / 2 + (k + 0.5) * W / strips
		local stripes = PLACE.awning or { Color3.fromRGB(196, 58, 50), Color3.fromRGB(240, 226, 200) }
		part(
			store,
			"Awning",
			Vector3.new(W / strips, 0.4, P + 1),
			cf * CFrame.new(x, 10, -D / 2 - 1 - P / 2) * CFrame.Angles(math.rad(-16), 0, 0),
			stripes[k % 2 + 1],
			Enum.Material.Fabric,
			{ collide = false }
		)
	end
	for _, x in { -W / 2 + 0.6, W / 2 - 0.6 } do
		part(store, "PorchPost", Vector3.new(0.7, 9, 0.7), cf * CFrame.new(x, 4.5, -D / 2 - 1 - P + 0.5), WOOD_DARK)
	end
	for k = 0, 2 do
		barrel(store, cf * CFrame.new(-W / 2 + 2 + k * 3.2, 0.8, -D / 2 - 3))
	end
	crate(store, cf * CFrame.new(W / 2 - 3, 0.8, -D / 2 - 3), 3)
	crate(store, cf * CFrame.new(W / 2 - 3, 3.8, -D / 2 - 3) * CFrame.Angles(0, 0.4, 0), 2.4)
	crate(store, cf * CFrame.new(W / 2 - 6.4, 0.8, -D / 2 - 3.4) * CFrame.Angles(0, 0.2, 0), 2.6)
	lantern(store, (cf * CFrame.new(-6, 7.5, -D / 2 - P)).Position, true)
end

-------------------------------------------------------------------------------------------------------------------
-- The water tower: the town's tall landmark, seen from camp across the canyon.

if PLACE.tower.kind == "bell" then
	-- The bell tower (Provence): a square stone tower, an open belfry with arches on each side and the bell inside,
	-- under a low tiled pyramid roof with an iron cross-piece.
	local tower = group("BellTower")
	local x, z = PLACE.tower.x, PLACE.tower.z
	local cf = siteAt(tower, x, z, SPRING, 12, 12, 0.5)
	local H = 36
	part(tower, "Shaft", Vector3.new(12, H, 12), cf * CFrame.new(0, H / 2, 0), STONE, Enum.Material.Limestone)
	part(
		tower,
		"Ledge",
		Vector3.new(13.4, 1, 13.4),
		cf * CFrame.new(0, H, 0),
		Color3.fromRGB(230, 222, 204),
		Enum.Material.Limestone
	)
	-- The belfry: four corner piers with arched gaps between them (each arch a beam over the gap).
	local B = 10
	for _, c in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		part(
			tower,
			"Pier",
			Vector3.new(2.6, B, 2.6),
			cf * CFrame.new(c[1] * 5.2, H + B / 2, c[2] * 5.2),
			STONE,
			Enum.Material.Limestone
		)
	end
	for _, side in { 0, 1, 2, 3 } do
		part(
			tower,
			"Arch",
			Vector3.new(12, 2, 1.2),
			cf * CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.new(0, H + B - 1, 5.6),
			STONE,
			Enum.Material.Limestone
		)
	end
	part(tower, "BelfryFloor", Vector3.new(12, 0.6, 12), cf * CFrame.new(0, H + 0.3, 0), STONE, Enum.Material.Limestone)
	local bell = part(
		tower,
		"Bell",
		Vector3.new(3.6, 4, 3.6),
		cf * CFrame.new(0, H + B - 4.4, 0),
		Color3.fromRGB(178, 136, 64),
		Enum.Material.Metal,
		{ collide = false }
	)
	bell.Shape = Enum.PartType.Cylinder
	bell.Size = Vector3.new(4, 3.6, 3.6)
	bell.CFrame = cf * CFrame.new(0, H + B - 4.4, 0) * CFrame.Angles(0, 0, math.pi / 2)
	part(
		tower,
		"Cap",
		Vector3.new(13.4, 1, 13.4),
		cf * CFrame.new(0, H + B + 0.5, 0),
		Color3.fromRGB(230, 222, 204),
		Enum.Material.Limestone
	)
	-- A low pyramid roof from stacked, shrinking tiled slabs, and the iron cross-piece on top.
	for k = 0, 3 do
		local s = 13 - k * 3.2
		part(tower, "Roof", Vector3.new(s, 1.4, s), cf * CFrame.new(0, H + B + 1.6 + k * 1.3, 0), ROOF, ROOF_MATERIAL)
	end
	part(
		tower,
		"Spire",
		Vector3.new(0.5, 6, 0.5),
		cf * CFrame.new(0, H + B + 9, 0),
		Color3.fromRGB(50, 46, 44),
		Enum.Material.Metal
	)
	part(
		tower,
		"CrossBar",
		Vector3.new(2.6, 0.4, 0.4),
		cf * CFrame.new(0, H + B + 10.5, 0),
		Color3.fromRGB(50, 46, 44),
		Enum.Material.Metal
	)
	-- A clock face on the tower's front.
	part(
		tower,
		"Clock",
		Vector3.new(0.4, 5, 5),
		cf * CFrame.new(0, H - 6, -6.1) * CFrame.Angles(0, math.pi / 2, 0),
		Color3.fromRGB(244, 240, 228),
		Enum.Material.SmoothPlastic,
		{ shape = Enum.PartType.Cylinder, collide = false }
	)
	part(tower, "Door", Vector3.new(4, 7, 0.4), cf * CFrame.new(0, 3.5, -6.15), TRIM, Enum.Material.Wood, { collide = false })
else
	local tower = group("WaterTower")
	local x, z = PLACE.tower.x, PLACE.tower.z
	local g = groundAt(x, z)
	local LEGS, SPREAD = 30, 7
	for _, c in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		local foot = Vector3.new(
			x + c[1] * SPREAD * 1.3,
			groundAt(x + c[1] * SPREAD * 1.3, z + c[2] * SPREAD * 1.3) - 1,
			z + c[2] * SPREAD * 1.3
		)
		local top = Vector3.new(x + c[1] * SPREAD, g + LEGS, z + c[2] * SPREAD)
		beam(tower, "Leg", foot, top, 1.4, WOOD_DARK, true)
	end
	for _, y in { 10, 20 } do
		local s = SPREAD * (1.3 - 0.3 * y / LEGS)
		for _, e in { { -1, -1, 1, -1 }, { 1, -1, 1, 1 }, { 1, 1, -1, 1 }, { -1, 1, -1, -1 } } do
			beam(
				tower,
				"Brace",
				Vector3.new(x + e[1] * s, g + y, z + e[2] * s),
				Vector3.new(x + e[3] * s, g + y, z + e[4] * s),
				0.6,
				WOOD_DARK
			)
		end
	end
	part(
		tower,
		"Deck",
		Vector3.new(SPREAD * 2 + 5, 0.8, SPREAD * 2 + 5),
		CFrame.new(x, g + LEGS, z),
		WOOD_LIGHT,
		Enum.Material.WoodPlanks
	)
	local tank = part(
		tower,
		"Tank",
		Vector3.new(14, 16, 16),
		CFrame.new(x, g + LEGS + 7.4, z) * CFrame.Angles(0, 0, math.pi / 2),
		WOOD,
		Enum.Material.WoodPlanks,
		{ shape = Enum.PartType.Cylinder }
	)
	tank.Size = Vector3.new(14, 16, 16)
	for _, y in { 2, 7.4, 12.8 } do
		part(
			tower,
			"Hoop",
			Vector3.new(0.4, 16.3, 16.3),
			CFrame.new(x, g + LEGS + y, z) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(56, 52, 50),
			Enum.Material.Metal,
			{ shape = Enum.PartType.Cylinder, collide = false }
		)
	end
	-- A stepped cone roof.
	for k = 0, 3 do
		local r = 17.5 - k * 4
		part(
			tower,
			"Roof",
			Vector3.new(1.6, r, r),
			CFrame.new(x, g + LEGS + 14.8 + k * 1.5, z) * CFrame.Angles(0, 0, math.pi / 2),
			ROOF,
			Enum.Material.Wood,
			{ shape = Enum.PartType.Cylinder }
		)
	end
	part(tower, "Finial", Vector3.new(0.6, 3, 0.6), CFrame.new(x, g + LEGS + 21.5, z), WOOD_DARK)
	-- A ladder up one leg.
	for k = 0, 12 do
		part(
			tower,
			"Rung",
			Vector3.new(2.4, 0.3, 0.3),
			CFrame.new(x + SPREAD + 2.4, g + 2 + k * 2.2, z),
			WOOD_DARK,
			Enum.Material.Wood,
			{ collide = false }
		)
	end
	for _, dz in { -1.2, 1.2 } do
		part(
			tower,
			"Rail",
			Vector3.new(0.3, LEGS, 0.3),
			CFrame.new(x + SPREAD + 2.4, g + LEGS / 2, z + dz),
			WOOD_DARK,
			Enum.Material.Wood,
			{ collide = false }
		)
	end
end

-------------------------------------------------------------------------------------------------------------------
-- The stable to the north: an open shed with hay bales, barrels, a trough.

do
	local stable = group("Stable")
	local W, D, H = 24, 14, 11
	local cf = siteAt(stable, PLACE.stable.x, PLACE.stable.z, SPRING, W, D, 0.5)
	part(stable, "Back", Vector3.new(W, H, 1), cf * CFrame.new(0, H / 2, D / 2 - 0.5), WOOD, Enum.Material.WoodPlanks)
	for _, s in { -1, 1 } do
		part(stable, "Side", Vector3.new(1, H, D), cf * CFrame.new(s * (W / 2 - 0.5), H / 2, 0), WOOD, Enum.Material.WoodPlanks)
		part(stable, "FrontPost", Vector3.new(0.9, H, 0.9), cf * CFrame.new(s * (W / 2 - 0.5), H / 2, -D / 2 + 0.5), WOOD_DARK)
	end
	part(
		stable,
		"Roof",
		Vector3.new(W + 2, 0.7, D + 3),
		cf * CFrame.new(0, H + 0.8, -0.5) * CFrame.Angles(math.rad(10), 0, 0),
		ROOF
	)
	for k = 0, 3 do
		part(
			stable,
			"Hay",
			Vector3.new(4, 2.4, 3),
			cf * CFrame.new(-W / 2 + 3.5 + (k % 2) * 4.2, 1.2 + math.floor(k / 2) * 2.4, D / 2 - 3),
			Color3.fromRGB(226, 196, 104),
			Enum.Material.Grass
		)
	end
	part(stable, "Trough", Vector3.new(7, 1.6, 2.4), cf * CFrame.new(5, 0.8, -D / 2 - 2), WOOD_LIGHT, Enum.Material.WoodPlanks)
	part(
		stable,
		"TroughWater",
		Vector3.new(6.4, 0.2, 1.8),
		cf * CFrame.new(5, 1.55, -D / 2 - 2),
		WATER,
		Enum.Material.Glass,
		{ collide = false }
	)
	barrel(stable, cf * CFrame.new(W / 2 + 3, 0, -2))
	barrel(stable, cf * CFrame.new(W / 2 + 3, 0, 1.4))
end

-------------------------------------------------------------------------------------------------------------------
-- A lavender field (Provence): rows of Lavender models on the ground, a little jittered.

if PLACE.lavender then
	local field = group("LavenderField")
	local L = PLACE.lavender
	local make = modelTree("Lavender")
	for x = L.x0, L.x1, L.rowEvery do
		for z = L.z0, L.z1, L.plantEvery do
			make(field, x + rng:NextNumber(-0.6, 0.6), z + rng:NextNumber(-0.6, 0.6), rng:NextNumber(2.2, 3))
		end
	end
end

-------------------------------------------------------------------------------------------------------------------
-- The rim fence with lanterns, either side of the bridge's end, and lantern posts round the plaza.

do
	local fence = group("Fence")
	local x = RIM_X - 5
	local function run(z0: number, z1: number)
		local count = math.floor(math.abs(z1 - z0) / 8)
		local step = (z1 - z0) / count
		for k = 0, count do
			local z = z0 + k * step
			local g = groundAt(x, z)
			part(fence, "Post", Vector3.new(0.8, 4.4, 0.8), CFrame.new(x, g + 2.2, z), WOOD_DARK)
			if k < count then
				local z2 = z + step
				local g2 = groundAt(x, z2)
				for _, h in { 1.5, 3.4 } do
					beam(fence, "Rail", Vector3.new(x, g + h, z), Vector3.new(x, g2 + h, z2), 0.5, WOOD, true)
				end
			end
			if k % 3 == 0 then
				lantern(fence, Vector3.new(x, g + 5.6, z))
			end
		end
	end
	for _, span in PLACE.fence do
		run(span[1], span[2])
	end
	for k, spot in PLACE.posts do
		lanternPost(fence, spot[1], spot[2], k % 2 == 1)
	end
end

-------------------------------------------------------------------------------------------------------------------
-- Townsfolk: copies of the Builderman NPC (Map.Model.Builderman, an R15 rig) with his pass, outfit and hard hat taken
-- off, dressed by body colors (shirt, pants) and the user's cowboy hat, idling (the IdleNpc tag: NpcPoseController).

local FOLK = { -- shirt, pants (where: PLACE.folk)
	{ Color3.fromRGB(176, 52, 44), Color3.fromRGB(70, 84, 120) },
	{ Color3.fromRGB(236, 230, 214), Color3.fromRGB(96, 70, 50) },
	{ Color3.fromRGB(64, 104, 150), Color3.fromRGB(84, 64, 48) },
	{ Color3.fromRGB(120, 140, 80), Color3.fromRGB(60, 60, 66) },
	{ Color3.fromRGB(196, 140, 60), Color3.fromRGB(70, 84, 120) },
	{ Color3.fromRGB(150, 70, 110), Color3.fromRGB(96, 70, 50) },
}
local template = map:FindFirstChild("Model") and map.Model:FindFirstChild("Builderman")
local townAssets = game:GetService("ServerStorage"):FindFirstChild("TownAssets")
local hatTemplate = townAssets and townAssets:FindFirstChild("CowboyHat")
if template then
	local folk = group("Townsfolk")
	for i, f in FOLK do
		local npc = template:Clone() :: Model
		npc.Name = `Townsperson{i}`
		for _, name in { "TBCHardHat", "Shirt", "Pants", "Animate", "AnimSaves" } do
			local item = npc:FindFirstChild(name)
			if item then
				item:Destroy()
			end
		end
		for _, d in npc:GetDescendants() do
			if d:IsA("BillboardGui") or d:IsA("ProximityPrompt") or d:IsA("Accessory") then
				d:Destroy()
			end
		end
		npc:SetAttribute("Outfit", nil) -- the pass's outfit (Roblox's own RBX_ attributes can't be changed from here)
		npc:RemoveTag("CharacterNpc") -- not a pass seller; IdleNpc stays, so it idles
		local colors = npc:FindFirstChildOfClass("BodyColors")
		if colors then
			colors.TorsoColor3 = f[1]
			colors.LeftLegColor3, colors.RightLegColor3 = f[2], f[2]
		end
		local humanoid = npc:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		-- Stand it on the ground at (x, z), facing the bridge's end.
		local x, z = PLACE.folk[i][1], PLACE.folk[i][2]
		local g = groundAt(x, z)
		local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart
		local lowest = math.huge
		for _, d in npc:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = d == root -- only the root, like the Builderman: anchored limbs can't animate
				lowest = math.min(lowest, d.Position.Y - d.Size.Y / 2)
			end
		end
		local rootAbove = root.Position.Y - lowest
		npc:PivotTo(
			CFrame.lookAt(Vector3.new(x, g + rootAbove, z), Vector3.new(RIM_X, g + rootAbove, z * 0.3))
				* root.CFrame:ToObjectSpace(npc:GetPivot())
		)
		-- The cowboy hat (the user's pick, catalog 17075928250, kept in ServerStorage.TownAssets.CowboyHat), on the head's
		-- hat attachment, welded to the head.
		local head = npc:FindFirstChild("Head") :: BasePart
		local hat = hatTemplate and hatTemplate:Clone()
		local handle = hat and hat:FindFirstChild("Handle") :: BasePart?
		local onHat = hat and handle and handle:FindFirstChild("HatAttachment") :: Attachment?
		local onHead = head:FindFirstChild("HatAttachment") :: Attachment?
		if hat and handle and onHat and onHead then
			handle.CFrame = onHead.WorldCFrame * onHat.CFrame:Inverse()
			handle.CanCollide, handle.CanTouch, handle.CanQuery, handle.Massless = false, false, false, true
			local weld = Instance.new("WeldConstraint") -- rides on the head as it animates
			weld.Part0, weld.Part1 = head, handle
			weld.Parent = handle
			hat.Parent = npc
		end
		npc.Parent = folk
	end
end

town.Parent = home
local parts = 0
for _, d in town:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
return `{PLACE.name}: {parts} parts`
