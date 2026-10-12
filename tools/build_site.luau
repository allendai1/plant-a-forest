-- build_site.luau: dresses camp as a rectangular bridge construction site (2026-10-10, the user's asks). Not shipped.
-- Run it in the Edit datamodel through the Studio connection (fetch it from the local server and loadstring it, like
-- tests/TargetingCheck.luau), after tools/build_canyon.luau (which lays the camp's walk floor, the same rectangle).
-- Safe to run again: it rebuilds Workspace.Map.Site. Save the place afterwards.
--
-- Camp is a rectangle (BASE) from the canyon's rim east, fenced with orange and white barriers, with a gap for the
-- bridge and an entrance on the east side. In the middle stands the lumber supply: one big plank pile (the only
-- SeedRack), with a forklift and a logging truck beside it. Around it:
-- - the gym on the north side: a walled floor, the tiers in order along both sides, a GYM sign at the back
-- - a yellow tower crane in the northwest corner, its jib reaching out over the canyon (decoration)
-- - a site office and porta-potties, a steel and pipe yard, a cement mixer, a generator, gravel and dirt heaps, tire
--   tracks in from the gate, hazard-striped blocks, floodlights, and a "CANYON BRIDGE CO." banner over the bridge's start
-- - construction vehicles parked outside the fence (Creator Store models, stripped of every script, seat and joint and
--   kept in ServerStorage.SiteAssets; see docs/notes/Grand Canyon game.md for where each came from)
-- Everything else players use stays put (the shop, gift boards, leaderboards, the Spring, the spawn). The Plant Trees!
-- plaza, garden, fence and hub floors go to ServerStorage.PlantTreesMap; the other five plank piles are removed.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- A fresh copy: Studio keeps a required module between tool runs, so a changed GameConfig would otherwise be missed.
local GameConfig = require(ReplicatedStorage.Shared.GameConfig:Clone()) :: any

local map = workspace:WaitForChild("Map")
local lobby = map:WaitForChild("Lobby")
local log = {}

local BASE = { X0 = -179.5, X1 = 172, Z0 = -220, Z1 = 150 } -- camp's rectangle (tools/build_canyon.luau CAMP)
local GROUND_Y = 1.55 -- the walk floor's top
local SLAB_TOP = 1.5 -- the visible gravel ground, just under it (the terrain under camp is lowered to make room)
local OUTSIDE_Y = 0.4 -- the terrain past camp's edge
local RIM_X = -180
local BRIDGE_GAP = 46 -- half-width of the barrier gap at the bridge (the deck is 40)
local GATE_GAP = 22 -- half-width of the east entrance
local PILE = { Layers = 9, Planks = 7, Length = 28, Width = 3.2, Height = 1.4 } -- the lumber supply

local YELLOW = Color3.fromRGB(245, 190, 30)
local ORANGE = Color3.fromRGB(240, 110, 30)
local WHITE = Color3.fromRGB(240, 240, 236)
local STEEL = Color3.fromRGB(120, 126, 134)
local DARK = Color3.fromRGB(46, 46, 50)
local CONCRETE = Color3.fromRGB(176, 172, 164)
local CABIN = Color3.fromRGB(226, 228, 222)
local BLUE = Color3.fromRGB(50, 110, 190)
local RUST = Color3.fromRGB(150, 70, 40)
local WOOD = Color3.fromRGB(176, 124, 74)

-- 1. The Plant Trees! hub goes into storage.
local stash = ServerStorage:FindFirstChild("PlantTreesMap")
if not stash then
	stash = Instance.new("Folder")
	stash.Name = "PlantTreesMap"
	stash.Parent = ServerStorage
end
for _, item in { lobby:FindFirstChild("LobbyGarden"), lobby:FindFirstChild("LobbyFence"), lobby:FindFirstChild("FenceDecor"), lobby:FindFirstChild("LobbyPlaza"), map:FindFirstChild("HubClearing"), map:FindFirstChild("HubEdgeFloor") } do
	if item then
		item.Parent = stash
		table.insert(log, `stored {item.Name}`)
	end
end

-- 2. The site.
local old = map:FindFirstChild("Site")
if old then
	old:Destroy()
end
local site = Instance.new("Folder")
site.Name = "Site"

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.CanTouch = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or site
	return m
end

-- Text on faces of a part.
local function label(target: BasePart, text: string, color: Color3, faces: { Enum.NormalId })
	for _, face in faces do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.PixelsPerStud = 20
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.Parent = target
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = text
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack -- the GUIs' font (UIStyle.FONT; FredokaOne until 2026-10-10)
		t.TextColor3 = color
		t.Parent = gui
	end
end

-- A point on camp's ground at (x, z), facing `toward` (default: camp's middle).
local function spot(x: number, z: number, toward: Vector2?): CFrame
	local t = toward or Vector2.zero
	return CFrame.lookAt(Vector3.new(x, GROUND_Y, z), Vector3.new(t.X, GROUND_Y, t.Y))
end

-- A round bar from a to b.
local function strut(parent: Instance, name: string, a: Vector3, b: Vector3, thick: number, color: Color3)
	return part(parent, name, Vector3.new(thick, thick, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, Enum.Material.Metal, false)
end

-- A lattice: four corner posts with X braces on each side, `height` tall and `width` square, standing at `base`.
local function lattice(parent: Instance, base: CFrame, width: number, height: number, post: number, color: Color3)
	local h = width / 2
	for _, c in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		part(parent, "Post", Vector3.new(post, height, post), base * CFrame.new(c[1] * h, height / 2, c[2] * h), color, Enum.Material.Metal)
	end
	local bays = math.max(1, math.floor(height / width))
	local bay = height / bays
	local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
	for i = 0, bays - 1 do
		for s = 1, 4 do
			local c1, c2 = corners[s], corners[s % 4 + 1]
			strut(parent, "Brace", (base * CFrame.new(c1[1] * h, i * bay, c1[2] * h)).Position, (base * CFrame.new(c2[1] * h, (i + 1) * bay, c2[2] * h)).Position, post * 0.45, color)
			strut(parent, "Brace", (base * CFrame.new(c2[1] * h, i * bay, c2[2] * h)).Position, (base * CFrame.new(c1[1] * h, (i + 1) * bay, c1[2] * h)).Position, post * 0.45, color)
		end
	end
end

-- The road in from the east (tools/canyon_out/road.json, tools/canyon_farfield.py): its middle every 16 studs as
-- { x, z, graded height, far scenery height }.
local roadData = HttpService:JSONDecode(HttpService:GetAsync("http://127.0.0.1:34877/tools/canyon_out/road.json", true))
local roadPoints: { { number } } = roadData.points
local ROAD_COLOR = Color3.fromRGB(138, 112, 86) -- tools/canyon_terrain.luau ROAD_COLOR

-- The road's middle at x: (z, graded height, heading in degrees for a vehicle facing +x along it).
local function roadAt(x: number): (number, number, number)
	for i = 1, #roadPoints - 1 do
		local a, b = roadPoints[i], roadPoints[i + 1]
		if x <= b[1] or i == #roadPoints - 1 then
			local t = math.clamp((x - a[1]) / (b[1] - a[1]), 0, 1)
			local yaw = math.deg(math.atan2(-(b[2] - a[2]), b[1] - a[1]))
			return a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, yaw
		end
	end
	return 0, OUTSIDE_Y, 0
end

-- The terrain's height at (x, z) (for setting things down outside camp).
local function groundAt(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1500, 0), params)
	return if hit then hit.Position.Y else OUTSIDE_Y
end

-- A copy of a stored model (ServerStorage.SiteAssets), turned by `yaw` degrees and set down on the ground at (x, z)
-- (on the terrain when groundY is nil).
local assets = ServerStorage:FindFirstChild("SiteAssets")
local function vehicle(name: string, x: number, z: number, yaw: number, groundY: number?): Model?
	local source = assets and assets:FindFirstChild(name)
	if not source then
		table.insert(log, `missing SiteAssets.{name}`)
		return nil
	end
	local copy = source:Clone()
	local m = if copy:IsA("Model") then copy else Instance.new("Model")
	if not copy:IsA("Model") then
		for _, child in copy:GetChildren() do
			child.Parent = m
		end
		copy:Destroy()
	end
	m.Name = name
	m.Parent = site
	local pivot = m:GetPivot()
	m:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, math.rad(yaw), 0) * pivot.Rotation) -- turned in place
	local box, size = m:GetBoundingBox()
	local y = groundY or groundAt(x, z)
	m:TranslateBy(Vector3.new(x, y + size.Y / 2, z) - box.Position)
	return m
end

-- 2a. The ground: a gravel yard over all of camp, just under the walk floor.
do
	local w, d = BASE.X1 - BASE.X0, BASE.Z1 - BASE.Z0
	part(site, "Ground", Vector3.new(w, 0.5, d), CFrame.new((BASE.X0 + BASE.X1) / 2, SLAB_TOP - 0.25, (BASE.Z0 + BASE.Z1) / 2), Color3.fromRGB(150, 142, 128), Enum.Material.Pebble)
end

-- 2b. The lumber supply: the one plank pile, in the middle of camp. The other piles go. Its pick-up prompt sits in the
-- pile's middle and reaches its whole edge (GameConfig.Planting RackPromptStuds; the server allows that plus RackSlackStuds).
do
	local racks = CollectionService:GetTagged("SeedRack")
	if lobby:FindFirstChild("PlankPiles") then
		racks = {} -- the user built their own pile (Lobby.PlankPiles, 2026-10-10): leave it exactly as it is
		table.insert(log, "lumber supply: kept the user's Lobby.PlankPiles")
	end
	local keep: Model? = nil
	for _, rack in racks do
		if rack:IsA("Model") and not keep then
			keep = rack
		else
			rack:Destroy()
		end
	end
	if keep then
		local rack = keep
		rack:PivotTo(CFrame.new(0, rack:GetPivot().Position.Y, 0))
		local oldPile = rack:FindFirstChild("PlankPile")
		if oldPile then
			oldPile:Destroy()
		end
		local pile = Instance.new("Model")
		pile.Name = "PlankPile"
		local rng = Random.new(7)
		local step = PILE.Length / PILE.Planks
		for layer = 1, PILE.Layers do
			local turn = CFrame.Angles(0, if layer % 2 == 0 then math.pi / 2 else 0, 0)
			for i = 1, PILE.Planks do
				local offset = Vector3.new((i - (PILE.Planks + 1) / 2) * step, (layer - 0.5) * PILE.Height, 0)
				local shade = 1 + rng:NextNumber(-0.12, 0.12)
				part(
					pile,
					"Plank",
					Vector3.new(PILE.Width, PILE.Height, PILE.Length + rng:NextNumber(-1.5, 1.5)),
					CFrame.new(0, SLAB_TOP, 0) * turn * CFrame.new(offset) * CFrame.Angles(0, rng:NextNumber(-0.05, 0.05), 0),
					Color3.fromRGB(WOOD.R * 255 * shade, WOOD.G * 255 * shade, WOOD.B * 255 * shade),
					Enum.Material.WoodPlanks,
					false
				)
			end
		end
		local height = PILE.Layers * PILE.Height
		local block = part(pile, "Collision", Vector3.new(PILE.Length, height, PILE.Length), CFrame.new(0, SLAB_TOP + height / 2, 0), WOOD)
		block.Transparency = 1
		pile.PrimaryPart = block
		pile.Parent = rack
		local basket = rack:FindFirstChild("AcornDispenser_Basket")
		if basket and basket:IsA("BasePart") then
			basket.CFrame = CFrame.new(0, SLAB_TOP + height / 2, 0)
			local sign = basket:FindFirstChildOfClass("BillboardGui")
			if sign then
				sign.StudsOffsetWorldSpace = Vector3.new(0, height / 2 + 6, 0)
			end
			for _, d in basket:GetDescendants() do
				if d:IsA("Attachment") then
					d.WorldPosition = Vector3.new(0, SLAB_TOP + height + 1, 0)
				elseif d:IsA("ProximityPrompt") then
					d.MaxActivationDistance = GameConfig.Planting.RackPromptStuds
					d.RequiresLineOfSight = false
				end
			end
		end
		table.insert(log, `lumber supply in the middle ({#racks - 1} other piles removed)`)
	end
	-- A forklift working by the pile and a logging truck parked beside it.
	vehicle("Forklift", 30, -24, 135, SLAB_TOP)
	vehicle("LogTruck", 0, 44, 0, SLAB_TOP)
end

-- 2c. The tower crane in the northwest corner: a lattice mast, the cab, the jib reaching out over the canyon (-X) with
-- a plank bundle on the hook, and the counter-jib with its concrete weights.
local CRANE = Vector3.new(-128, GROUND_Y, -108)
do
	local crane = model("TowerCrane")
	local MAST, HEIGHT, JIB, COUNTER = 12, 150, 210, 60
	local base = CFrame.new(CRANE)
	part(crane, "Footing", Vector3.new(24, 3, 24), base * CFrame.new(0, 1.5, 0), CONCRETE, Enum.Material.Concrete)
	lattice(crane, base * CFrame.new(0, 3, 0), MAST, HEIGHT - 3, 1.4, YELLOW)
	local top = base * CFrame.new(0, HEIGHT, 0)
	part(crane, "Slewing", Vector3.new(MAST + 4, 3, MAST + 4), top * CFrame.new(0, 1.5, 0), YELLOW, Enum.Material.Metal)
	local cab = part(crane, "Cab", Vector3.new(8, 8, 8), top * CFrame.new(-MAST / 2 - 2, 7, MAST / 2 - 1), YELLOW, Enum.Material.Metal)
	part(crane, "CabWindow", Vector3.new(0.2, 4.5, 6.5), cab.CFrame * CFrame.new(-4.05, 1, 0), DARK, Enum.Material.Glass)
	local function truss(from: number, to: number, height: number)
		local length = math.abs(to - from)
		local origin = top * CFrame.new((from + to) / 2, 4, 0)
		for _, z in { -3, 3 } do
			part(crane, "Chord", Vector3.new(length, 1.2, 1.2), origin * CFrame.new(0, 0, z), YELLOW, Enum.Material.Metal)
		end
		part(crane, "TopChord", Vector3.new(length, 1.2, 1.2), origin * CFrame.new(0, height, 0), YELLOW, Enum.Material.Metal)
		local panels = math.floor(length / 10)
		for i = 0, panels do
			local x = -length / 2 + i * length / panels
			local apex = (origin * CFrame.new(x, height, 0)).Position
			for _, z in { -3, 3 } do
				strut(crane, "Web", (origin * CFrame.new(x, 0, z)).Position, apex, 0.6, YELLOW)
				if i < panels then
					strut(crane, "Web", (origin * CFrame.new(x, 0, z)).Position, (origin * CFrame.new(x + length / panels, height, 0)).Position, 0.5, YELLOW)
				end
			end
		end
	end
	truss(-JIB, MAST / 2, 6)
	truss(MAST / 2, COUNTER, 6)
	part(crane, "Apex", Vector3.new(2, 26, 2), top * CFrame.new(0, 16, 0), YELLOW, Enum.Material.Metal)
	local apex = (top * CFrame.new(0, 29, 0)).Position
	for _, x in { -JIB * 0.6, COUNTER * 0.9 } do
		strut(crane, "Pendant", apex, (top * CFrame.new(x, 10, 0)).Position, 0.4, DARK)
	end
	for i = 0, 2 do
		part(crane, "Counterweight", Vector3.new(4, 10, 9), top * CFrame.new(COUNTER - 6 - i * 5, 0, 0), CONCRETE, Enum.Material.Concrete)
	end
	-- The trolley out past the rim, its cable, the hook and a bundle of planks hanging over the canyon.
	local trolley = top * CFrame.new(RIM_X - 25 - CRANE.X, 2, 0)
	part(crane, "Trolley", Vector3.new(6, 2, 8), trolley, DARK, Enum.Material.Metal)
	local hook = Vector3.new(trolley.Position.X, GROUND_Y + 60, CRANE.Z)
	strut(crane, "Cable", trolley.Position, hook, 0.3, DARK)
	part(crane, "Hook", Vector3.new(2.5, 3, 2.5), CFrame.new(hook - Vector3.new(0, 1.5, 0)), YELLOW, Enum.Material.Metal, false)
	for i = 0, 3 do
		part(crane, "Load", Vector3.new(16, 1, 2.6), CFrame.new(hook + Vector3.new(0, -5 - (i % 2), -3.9 + i * 2.6)), WOOD, Enum.Material.WoodPlanks, false)
	end
	local beacon = part(crane, "Beacon", Vector3.new(1.5, 1.5, 1.5), CFrame.new(apex + Vector3.new(0, 1, 0)), Color3.fromRGB(255, 60, 40), Enum.Material.Neon, false)
	local light = Instance.new("PointLight")
	light.Color = beacon.Color
	light.Range = 30
	light.Brightness = 2
	light.Parent = beacon
	crane.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- the landmark you see from the bridge
end

-- 2d. Barriers along camp's four sides: a gap for the bridge on the rim side, the entrance on the east side.
do
	local ring = model("Barriers")
	local SEGMENT = 7
	local count, cones = 0, 0
	local function cone(at: Vector3)
		local c = model("Cone", ring)
		part(c, "Base", Vector3.new(2.6, 0.3, 2.6), CFrame.new(at + Vector3.new(0, 0.15, 0)), ORANGE)
		for k, w in { 1.6, 1.25, 0.9, 0.55 } do
			local disc = part(c, "Body", Vector3.new(0.8, w, w), CFrame.new(at + Vector3.new(0, 0.3 + (k - 0.5) * 0.8, 0)) * CFrame.Angles(0, 0, math.pi / 2), if k == 3 then WHITE else ORANGE, Enum.Material.Plastic, k == 1)
			disc.Shape = Enum.PartType.Cylinder
		end
		cones += 1
	end
	-- One side from a to b (inset 2 studs), facing `inward`, leaving out [gapFrom, gapTo] along it.
	local function side(a: Vector3, b: Vector3, inward: Vector3, gapFrom: number?, gapTo: number?)
		local length = (b - a).Magnitude
		local dir = (b - a).Unit
		local pieces = math.floor(length / SEGMENT)
		for i = 0, pieces - 1 do
			local t0, t1 = i * SEGMENT, (i + 1) * SEGMENT
			if gapFrom and gapTo and t1 > gapFrom and t0 < gapTo then
				continue
			end
			local at = a + dir * (t0 + SEGMENT / 2)
			local cf = CFrame.lookAt(at, at + inward)
			local b2 = model("Barrier", ring)
			local color = if i % 2 == 0 then ORANGE else WHITE
			local other = if i % 2 == 0 then WHITE else ORANGE
			part(b2, "Panel", Vector3.new(SEGMENT - 0.4, 2.2, 0.8), cf * CFrame.new(0, 2.8, 0), color, Enum.Material.Plastic)
			part(b2, "Stripe", Vector3.new(SEGMENT - 0.4, 0.6, 0.85), cf * CFrame.new(0, 2.8, 0), other, Enum.Material.Plastic, false)
			for _, x in { -SEGMENT / 2 + 0.8, SEGMENT / 2 - 0.8 } do
				part(b2, "Foot", Vector3.new(0.8, 1.8, 2.8), cf * CFrame.new(x, 0.9, 0), color, Enum.Material.Plastic)
			end
			count += 1
		end
		if gapFrom and gapTo then
			cone(a + dir * (gapFrom - 1.5))
			cone(a + dir * (gapTo + 1.5))
		end
	end
	local x0, x1, z0, z1, y = BASE.X0 + 2, BASE.X1 - 2, BASE.Z0 + 2, BASE.Z1 - 2, GROUND_Y
	side(Vector3.new(x0, y, z0), Vector3.new(x1, y, z0), Vector3.new(0, 0, 1)) -- north
	side(Vector3.new(x0, y, z1), Vector3.new(x1, y, z1), Vector3.new(0, 0, -1)) -- south
	side(Vector3.new(x1, y, z0), Vector3.new(x1, y, z1), Vector3.new(-1, 0, 0), -z0 - GATE_GAP, -z0 + GATE_GAP) -- east, the gate
	side(Vector3.new(x0, y, z0), Vector3.new(x0, y, z1), Vector3.new(1, 0, 0), -z0 - BRIDGE_GAP, -z0 + BRIDGE_GAP) -- the rim
	table.insert(log, `barriers: {count}, cones: {cones}`)
end

-- 2e. The site office in the northeast corner: two portable cabins stacked, stairs, a sign, porta-potties.
do
	local office = model("SiteOffice")
	local at = spot(146, -128, Vector2.new(146, 0)) -- facing south, into camp
	local function cabin(cf: CFrame, sign: string?)
		part(office, "Cabin", Vector3.new(24, 9, 9), cf * CFrame.new(0, 4.5, 0), CABIN)
		part(office, "Roof", Vector3.new(24.6, 0.6, 9.6), cf * CFrame.new(0, 9.3, 0), Color3.fromRGB(150, 150, 150), Enum.Material.Metal)
		for _, x in { -7, 0, 7 } do
			part(office, "Window", Vector3.new(4, 2.6, 0.2), cf * CFrame.new(x, 5.5, -4.55), Color3.fromRGB(110, 150, 180), Enum.Material.Glass, false)
		end
		part(office, "Door", Vector3.new(3, 6.5, 0.2), cf * CFrame.new(-10, 3.3, -4.55), BLUE, Enum.Material.SmoothPlastic, false)
		if sign then
			local board = part(office, "Sign", Vector3.new(14, 2.6, 0.3), cf * CFrame.new(3, 8, -4.7), BLUE, Enum.Material.SmoothPlastic, false)
			label(board, sign, WHITE, { Enum.NormalId.Front })
		end
	end
	cabin(at, "SITE OFFICE")
	cabin(at * CFrame.new(0, 9.6, 0))
	for i = 0, 7 do
		part(office, "Step", Vector3.new(3, 0.5, 2), at * CFrame.new(13.5, 0.6 + i * 1.2, -2 + i * 1.1), STEEL, Enum.Material.DiamondPlate)
	end
	for i = 0, 1 do
		local cf = at * CFrame.new(-20 - i * 5, 0, 1)
		part(office, "Toilet", Vector3.new(4, 7.5, 4), cf * CFrame.new(0, 3.75, 0), BLUE, Enum.Material.Plastic)
		part(office, "ToiletRoof", Vector3.new(4.4, 0.5, 4.4), cf * CFrame.new(0, 7.75, 0), WHITE, Enum.Material.Plastic)
	end
	local gen = at * CFrame.new(-36, 0, 0)
	part(office, "Generator", Vector3.new(9, 5, 5), gen * CFrame.new(0, 2.5, 0), YELLOW, Enum.Material.Metal)
	part(office, "GeneratorTop", Vector3.new(9.4, 0.5, 5.4), gen * CFrame.new(0, 5.25, 0), DARK, Enum.Material.Metal)
	part(office, "Exhaust", Vector3.new(0.8, 2, 0.8), gen * CFrame.new(3, 6.5, 0), DARK, Enum.Material.Metal, false)
end

-- 2f. The steel and pipe yard in the southwest corner, a cement mixer, heaps of gravel and dirt.
do
	local yard = model("MaterialYard")
	local function beams(cf: CFrame)
		for layer = 0, 2 do
			for i = 0, 3 - layer do
				local beam = cf * CFrame.new((i - (3 - layer) / 2) * 3.2, 1.2 + layer * 2.4, 0)
				part(yard, "Flange", Vector3.new(2.6, 0.4, 26), beam * CFrame.new(0, 1, 0), RUST, Enum.Material.Metal)
				part(yard, "Flange", Vector3.new(2.6, 0.4, 26), beam * CFrame.new(0, -1, 0), RUST, Enum.Material.Metal)
				part(yard, "Web", Vector3.new(0.4, 1.8, 26), beam, RUST, Enum.Material.Metal)
			end
		end
		for _, z in { -10, 10 } do
			part(yard, "Dunnage", Vector3.new(14, 0.8, 1.6), cf * CFrame.new(0, 0.4, z), Color3.fromRGB(120, 86, 56), Enum.Material.Wood)
		end
	end
	local function pipes(cf: CFrame)
		for layer = 0, 2 do
			for i = 0, 3 - layer do
				local p = part(yard, "Pipe", Vector3.new(24, 3.2, 3.2), cf * CFrame.new((i - (3 - layer) / 2) * 3.4, 1.7 + layer * 2.9, 0) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(90, 96, 104), Enum.Material.Metal)
				p.Shape = Enum.PartType.Cylinder
			end
		end
	end
	beams(CFrame.new(-150, GROUND_Y, 112))
	beams(CFrame.new(-128, GROUND_Y, 112))
	pipes(CFrame.new(-102, GROUND_Y, 120) * CFrame.Angles(0, math.pi / 2, 0))
	-- A cement mixer.
	local mixerAt = spot(-60, 128, Vector2.new(0, 128))
	part(yard, "Chassis", Vector3.new(6, 2, 10), mixerAt * CFrame.new(0, 2.5, 0), STEEL, Enum.Material.Metal)
	for _, z in { -3.5, 3.5 } do
		for _, x in { -3.4, 3.4 } do
			local w = part(yard, "Wheel", Vector3.new(1.2, 3, 3), mixerAt * CFrame.new(x, 1.5, z), DARK, Enum.Material.Rubber)
			w.Shape = Enum.PartType.Cylinder
		end
	end
	local drum = part(yard, "Drum", Vector3.new(8, 6, 6), mixerAt * CFrame.new(0, 6.5, 0.5) * CFrame.Angles(math.rad(-20), math.pi / 2, 0), ORANGE, Enum.Material.Metal)
	drum.Shape = Enum.PartType.Cylinder
	-- Heaps.
	local function heap(x: number, z: number, radius: number, height: number, color: Color3, material: Enum.Material)
		local h = part(yard, "Heap", Vector3.new(radius * 2, height * 2, radius * 2), CFrame.new(x, GROUND_Y - height * 0.15, z), color, material)
		h.Shape = Enum.PartType.Ball
		local second = part(yard, "Heap", Vector3.new(radius * 1.3, height * 1.5, radius * 1.3), CFrame.new(x + radius * 0.5, GROUND_Y - height * 0.2, z - radius * 0.3), color, material)
		second.Shape = Enum.PartType.Ball
	end
	heap(-150, 70, 9, 4, Color3.fromRGB(150, 146, 140), Enum.Material.Pebble)
	heap(-20, 132, 8, 4.5, Color3.fromRGB(140, 104, 72), Enum.Material.Ground)
	heap(40, 130, 7, 3.5, Color3.fromRGB(150, 146, 140), Enum.Material.Pebble)
end

-- 2g. The gym (2026-10-10, the user's ask, from a picture of another game's gym): a walled concrete floor north of the
-- lumber pile, its entrance facing the pile, an open aisle up the middle and a floating GYM label over it all.
-- The tiers run in order up the left side from the entrance (1x free, 2x, 5x, 10x) and back down the right (100x at the
-- back, 75x, 50x, 25x by the entrance), each on a square pad in its color with a bright border, its bench and treadmill
-- facing the aisle. Each tier moves as a unit; the training code finds stations by tag and the tutorial finds pads by
-- name, so moving them changes nothing else. Re-running is safe: a moved pad remembers which way it faces (YardFacing).
local GYM = {
	X0 = -58, X1 = 58, Z0 = -214, Z1 = -40, -- the floor (Z1 is the entrance side)
	Top = 1.52, -- the floor's top (just over the gravel)
	Pad = 30, -- a tier pad's square
	ColumnX = 36, -- the two columns of pads, either side of the aisle
	RowZ = { -62, -96, -130, -164 }, -- from the entrance to the back
	Door = 17, -- half the entrance's width
	Curb = Vector2.new(1.6, 2.4), -- the low wall around the floor: thickness, height
}
do
	local gym = model("Gym")
	local grove = map:FindFirstChild("TrainingGrove")
	local moved = 0
	for i, step in GameConfig.Stats.GymMultipliers do
		local m = step.Multiplier
		local pad = lobby:FindFirstChild(`TierPad {m}x`)
		local floor = pad and pad:FindFirstChild("Floor")
		if not (pad and floor and floor:IsA("BasePart") and grove) then
			continue
		end
		local left = i <= 4
		local row = if left then i else i - 4 -- the right column: 25x by the entrance, 100x at the back
		local at = floor.Position
		local facing = pad:GetAttribute("YardFacing")
		local forward = if typeof(facing) == "Vector3" then facing else Vector3.new(-at.X, 0, -at.Z).Unit
		local from = CFrame.lookAt(at, at + forward)
		local lift = if typeof(facing) == "Vector3" then 0 else GYM.Top - 0.85
		local target = Vector3.new(if left then -GYM.ColumnX else GYM.ColumnX, at.Y + lift, GYM.RowZ[row])
		local toward = Vector3.new(if left then 1 else -1, 0, 0) -- facing the aisle
		local to = CFrame.lookAt(target, target + toward)
		for _, item in { pad, grove:FindFirstChild(`Bench Press {m}x`), grove:FindFirstChild(`Treadmill {m}x`) } do
			if item and item:IsA("Model") then
				item:PivotTo(to * from:ToObjectSpace(item:GetPivot()))
			end
		end
		pad:SetAttribute("YardFacing", toward)
		moved += 1
		-- The square pad in the tier's color (the round floor it came with is hidden, but kept: the tutorial finds it).
		local color = floor.Color
		floor.Transparency = 1
		local ring = pad:FindFirstChild("GlowRingFx") -- the round glowing wall: the square border replaces it
		if ring then
			ring:Destroy()
		end
		local center = Vector3.new(target.X, GROUND_Y + 0.04, target.Z) -- on the floor players walk on
		local plate = part(gym, "PadPlate", Vector3.new(GYM.Pad, 0.08, GYM.Pad), CFrame.new(center), color, Enum.Material.Neon, false)
		plate.Transparency = 0.82 -- a light tint, so the bright border reads
		plate.CastShadow = false
		local half = GYM.Pad / 2
		for _, e in { { 0, -half, GYM.Pad + 1, 1 }, { 0, half, GYM.Pad + 1, 1 }, { -half, 0, 1, GYM.Pad + 1 }, { half, 0, 1, GYM.Pad + 1 } } do
			local border = part(gym, "PadBorder", Vector3.new(e[3], 0.25, e[4]), CFrame.new(center + Vector3.new(e[1], 0.12, e[2])), color, Enum.Material.Neon, false)
			border.CastShadow = false
		end
	end
	-- The floor, and the curb around it with the entrance on the pile's side.
	local x0, x1, z0, z1 = GYM.X0, GYM.X1, GYM.Z0, GYM.Z1
	part(gym, "Floor", Vector3.new(x1 - x0, 0.5, z1 - z0), CFrame.new((x0 + x1) / 2, GYM.Top - 0.25, (z0 + z1) / 2), CONCRETE, Enum.Material.Concrete)
	local t, h = GYM.Curb.X, GYM.Curb.Y
	local curbColor = Color3.fromRGB(150, 146, 140)
	local function curb(cx: number, cz: number, sx: number, sz: number)
		part(gym, "Curb", Vector3.new(sx, h, sz), CFrame.new(cx, GYM.Top + h / 2, cz), curbColor, Enum.Material.Concrete)
	end
	curb((x0 + x1) / 2, z0 + t / 2, x1 - x0, t) -- the back
	curb(x0 + t / 2, (z0 + z1) / 2, t, z1 - z0) -- the sides
	curb(x1 - t / 2, (z0 + z1) / 2, t, z1 - z0)
	local sideLength = (x1 - x0) / 2 - GYM.Door
	curb(x0 + sideLength / 2, z1 - t / 2, sideLength, t) -- the front, either side of the entrance
	curb(x1 - sideLength / 2, z1 - t / 2, sideLength, t)
	-- Entrance pillars with a yellow beam across.
	for _, x in { -GYM.Door - 1, GYM.Door + 1 } do
		part(gym, "Pillar", Vector3.new(2.6, 14, 2.6), CFrame.new(x, GYM.Top + 7, z1 - t / 2), YELLOW, Enum.Material.Metal)
	end
	part(gym, "Lintel", Vector3.new(GYM.Door * 2 + 5, 2, 2), CFrame.new(0, GYM.Top + 14, z1 - t / 2), YELLOW, Enum.Material.Metal)
	-- The floating GYM label over the middle of the training area, in the tiers' label style (their BillboardGui: the
	-- text with a drop shadow and a black outline over a black band that fades out at both ends), sized in studs. (The stage and giant barbell at the back were taken out, the user's call.)
	local anchor = part(gym, "LabelAnchor", Vector3.new(1, 1, 1), CFrame.new(0, GYM.Top + 66, (z0 + z1) / 2), WHITE -- the user raised it to 66 over the floor, Enum.Material.SmoothPlastic, false)
	anchor.Transparency = 1
	anchor.CanQuery = false
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GymLabel"
	billboard.Size = UDim2.fromScale(26, 7.5) -- studs, so it shrinks with distance (pixels stayed huge zoomed out)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 700
	billboard.Parent = anchor
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Position = UDim2.fromScale(0.5, 0.5)
	band.Size = UDim2.fromScale(0.8, 1.15)
	band.BackgroundColor3 = Color3.new(0, 0, 0)
	band.BorderSizePixel = 0
	band.ZIndex = 0
	band.Parent = billboard
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.75),
		NumberSequenceKeypoint.new(0.75, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = band
	local function layer(name: string, color: Color3, offset: number, z: number)
		local text = Instance.new("TextLabel")
		text.Name = name
		text.Size = UDim2.fromScale(1, 1)
		text.Position = UDim2.fromScale(0, offset)
		text.BackgroundTransparency = 1
		text.Text = "GYM"
		text.TextScaled = true
		text.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
		text.TextColor3 = color
		text.ZIndex = z
		text.Parent = billboard
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Parent = text
	end
	layer("Shadow", Color3.new(0, 0, 0), 0.06, 1)
	layer("Face", Color3.fromRGB(40, 120, 255), 0, 2)
	-- Lighter at the top, deeper at the bottom (2026-10-11, the user; UIStyle.textGradient's colors for this blue).
	local face = billboard:FindFirstChild("Face") :: TextLabel
	face:SetAttribute("GradientBase", face.TextColor3)
	face.TextColor3 = Color3.new(1, 1, 1)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "TextGradient"
	gradient.Color = ColorSequence.new(Color3.fromRGB(137, 181, 255), Color3.fromRGB(30, 90, 191))
	gradient.Rotation = 90
	gradient.Parent = face
	gym.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- the sign is seen from the pile
	table.insert(log, `gym: {moved} tiers`)
end

-- 2h. Tire tracks in from the east gate to the lumber pile, and hazard-striped blocks around the crane's footing.
do
	local ground = model("Groundwork")
	local track = Color3.fromRGB(104, 94, 82)
	local points = { Vector2.new(BASE.X1, 0), Vector2.new(130, 2), Vector2.new(90, -6), Vector2.new(55, -4), Vector2.new(24, 0) }
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dir = (b - a).Unit
		local sideways = Vector2.new(-dir.Y, dir.X) * 3.2
		for _, sign in { -1, 1 } do
			local p0, p1 = a + sideways * sign, b + sideways * sign
			local y = if math.max(p0.X, p1.X) > BASE.X1 then OUTSIDE_Y + 0.02 else GROUND_Y + 0.02
			local from3, to3 = Vector3.new(p0.X, y, p0.Y), Vector3.new(p1.X, y, p1.Y)
			local band = part(ground, "Track", Vector3.new(1.6, 0.04, (to3 - from3).Magnitude + 1.5), CFrame.lookAt((from3 + to3) / 2, to3), track, Enum.Material.Ground, false)
			band.Transparency = 0.25
			band.CanQuery = false
		end
	end
	local function block(cf: CFrame)
		local b = model("HazardBlock", ground)
		part(b, "Block", Vector3.new(6, 2.6, 2.2), cf * CFrame.new(0, 1.3, 0), CONCRETE, Enum.Material.Concrete)
		for k = 0, 5 do
			part(b, "Stripe", Vector3.new(0.9, 0.9, 2.3), cf * CFrame.new(-2.5 + k, 1.7, 0) * CFrame.Angles(0, 0, math.rad(35)), if k % 2 == 0 then YELLOW else DARK, Enum.Material.SmoothPlastic, false)
		end
	end
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local at = CRANE + Vector3.new(math.cos(a) * 17, 0, math.sin(a) * 17)
		block(CFrame.lookAt(at, CRANE))
	end
end

-- 2i. Floodlight towers.
do
	local lights = model("Floodlights")
	for _, xz in { { BASE.X0 + 12, BASE.Z1 - 12 }, { BASE.X1 - 12, BASE.Z1 - 12 }, { BASE.X1 - 12, BASE.Z0 + 30 }, { -75, BASE.Z0 + 10 } } do
		local cf = spot(xz[1], xz[2])
		part(lights, "Mast", Vector3.new(1, 30, 1), cf * CFrame.new(0, 15, 0), STEEL, Enum.Material.Metal)
		part(lights, "Base", Vector3.new(5, 1.5, 5), cf * CFrame.new(0, 0.75, 0), YELLOW, Enum.Material.Metal)
		local bar = part(lights, "Bar", Vector3.new(7, 0.6, 0.6), cf * CFrame.new(0, 30, 0), STEEL, Enum.Material.Metal, false)
		for _, x in { -2.5, 0, 2.5 } do
			local lamp = part(lights, "Lamp", Vector3.new(2, 1.6, 0.8), bar.CFrame * CFrame.new(x, 1, -0.5) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(255, 244, 210), Enum.Material.Neon, false)
			local spotLight = Instance.new("SpotLight")
			spotLight.Face = Enum.NormalId.Front
			spotLight.Angle = 70
			spotLight.Range = 60
			spotLight.Brightness = 1.2
			spotLight.Color = Color3.fromRGB(255, 240, 210)
			spotLight.Parent = lamp
		end
	end
end

-- 2j. The road in from the east and the trucks on it. The road itself is carved and painted in the terrain (tools/
-- canyon_heightmap.py ROAD, tools/canyon_terrain.luau); past the terrain's edge it goes on as flat strips lying on the
-- far scenery, out to the horizon. A dump truck is coming in, another is parked on the shoulder, the excavator and a
-- crane-and-digger set work beside the road, and a sign by the gate says where you are.
do
	local road = model("Road")
	local half = roadData.half :: number
	local strips = 0
	for i = 1, #roadPoints - 1 do
		local a, b = roadPoints[i], roadPoints[i + 1]
		if a[1] >= (roadData.terrainEndX :: number) - 16 then
			local p0 = Vector3.new(a[1], a[4] + 1.5, a[2])
			local p1 = Vector3.new(b[1], b[4] + 1.5, b[2])
			local strip = part(road, "Strip", Vector3.new(half * 2, 3, (p1 - p0).Magnitude + 2), CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.new(0, -1.5, 0), ROAD_COLOR, Enum.Material.Salt, false) -- the terrain road's material
			strip.CanQuery = false
			strip.CastShadow = false
			strips += 1
		end
	end
	road.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- seen far down the road
	table.insert(log, `road: {strips} strips past the terrain`)

	local function onRoad(name: string, x: number, side: number, turn: number)
		local z, h, yaw = roadAt(x)
		vehicle(name, x, z + side, yaw + turn, h)
	end
	onRoad("DumpTruck", 330, -7, 180) -- coming in toward camp, in its lane
	onRoad("DumpTruck", 560, 24, 0) -- parked on the shoulder
	local zSet = roadAt(300)
	vehicle("ConstructionSet", 300, zSet + 85, 90)
	vehicle("Excavator", BASE.X1 + 50, -95, 200)

	-- The entrance sign beside the road, just outside the gate.
	local zSign = roadAt(BASE.X1 + 18)
	local signAt = CFrame.lookAt(Vector3.new(BASE.X1 + 18, OUTSIDE_Y, zSign - 26), Vector3.new(BASE.X1 + 60, OUTSIDE_Y, zSign - 26))
	for _, x in { -9, 9 } do
		part(road, "SignPost", Vector3.new(0.8, 14, 0.8), signAt * CFrame.new(x, 7, 0), Color3.fromRGB(120, 86, 56), Enum.Material.Wood)
	end
	local board = part(road, "Sign", Vector3.new(21, 7, 0.4), signAt * CFrame.new(0, 11, 0), Color3.fromRGB(245, 190, 30), Enum.Material.SmoothPlastic, false)
	label(board, "CANYON BRIDGE PROJECT · TRUCK ENTRANCE", DARK, { Enum.NormalId.Front, Enum.NormalId.Back })
	-- Cones along the road's edges at the gate.
	for k = 0, 3 do
		for _, side in { -1, 1 } do
			local x = BASE.X1 + 6 + k * 14
			local z = roadAt(x)
			local at = Vector3.new(x, groundAt(x, z + side * (half + 2)), z + side * (half + 2))
			part(road, "Cone", Vector3.new(1.4, 2.6, 1.4), CFrame.new(at + Vector3.new(0, 1.3, 0)), ORANGE, Enum.Material.Plastic, false)
		end
	end
end

-- 2k. A banner over the bridge's start, between the bridgehead posts (tools/build_canyon.luau).
do
	local head = model("BridgeBanner")
	local grid = GameConfig.Grid
	local half = grid.Columns * grid.SlotStuds / 2 + 1.6
	for _, z in { -half, half } do
		part(head, "Upright", Vector3.new(2.4, 22, 2.4), CFrame.new(RIM_X + 2, GROUND_Y + 11, z), YELLOW, Enum.Material.Metal)
	end
	part(head, "Beam", Vector3.new(2, 2, half * 2 + 2.4), CFrame.new(RIM_X + 2, GROUND_Y + 22, 0), YELLOW, Enum.Material.Metal, false)
	local board = part(head, "Board", Vector3.new(0.5, 5, half * 1.4), CFrame.new(RIM_X + 2, GROUND_Y + 18.5, 0), BLUE, Enum.Material.SmoothPlastic, false)
	label(board, "CANYON BRIDGE CO.", WHITE, { Enum.NormalId.Right, Enum.NormalId.Left })
	head.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
end

-- 2l. The Spring's glowing rings (the break-time training circle, Lobby.SpringRing and its BreakOnly GlowRingFx) move
-- out to the far rim's landing, where the Spring is now (GameConfig.Awakening.SpringBeyondStuds; the user's ask).
do
	local grid = GameConfig.Grid
	local beyond = grid.Rows * grid.SlotStuds + GameConfig.Awakening.SpringBeyondStuds
	local spot = Vector3.new(RIM_X - beyond, 0, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(spot + Vector3.new(0, 300, 0), Vector3.new(0, -600, 0), params)
	local groundY = if hit then hit.Position.Y else GROUND_Y
	for _, item in lobby:GetChildren() do
		if item:IsA("BasePart") and (item.Name == "SpringRing" or (item.Name == "GlowRingFx" and item:GetAttribute("BreakOnly"))) then
			local lift = if item.Name == "SpringRing" then 0.15 else 0.25
			item.CFrame = item.CFrame.Rotation + Vector3.new(spot.X, groundY + lift, spot.Z)
			table.insert(log, `moved {item.Name} to the far rim`)
		end
	end
end

-- 3. The spawn faces the lumber pile and the bridge beyond it.
local spawnPad = workspace:FindFirstChildWhichIsA("SpawnLocation")
if spawnPad then
	local at = spawnPad.Position
	spawnPad.CFrame = CFrame.lookAt(at, Vector3.new(0, at.Y, 0))
end

site.Parent = map
local parts = 0
for _, d in site:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
table.insert(log, `site: {parts} parts`)
return table.concat(log, "\n")
