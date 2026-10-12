-- build_camp.luau: lays camp out as one bridge-building megaproject (2026-10-10, the user's brief "Improve the Grand
-- Canyon Construction Base Camp"; replaces tools/build_busy_site.luau). Not shipped. Run it in the Edit datamodel
-- through the Studio connection with the repo served on 127.0.0.1:34877 (fetch and loadstring it). Safe to run again:
-- it rebuilds Workspace.Map.Site.Camp and touches nothing that the game's code uses.
--
-- Camp reads along one line, east to west: the truck gate, the spawn, the gym's aisle, the plank pile (the user's
-- PlankPiles, the pick-up), a wide paved road, and the bridge's gateway. Around that line:
-- - by the pile: lumber racks, crates and pallets, a lumber yard with log piles, and a cutting shop under a lean-to
-- - safety lines down the gym's aisle
-- - the bridge's gateway: two yellow lattice towers and a girder with GRAND CANYON BRIDGE on it, the bridge's progress
--   board (filled in by SiteAmbienceController), a plank bundle swinging on a cable, scaffolds, floodlight towers
-- - the equipment yard on the back lot: gravel, marked parking bays, the tower crane (turned slowly by
--   SiteAmbienceController), an excavator loading a dump truck, a maintenance corner
-- - the site HQ by the spawn: two stacked cabins, a flagpole, a survey instrument, a plan table, porta-potties
-- - concrete barriers round camp's edge, ground patches (paving, concrete slabs, compacted dirt, gravel, tire tracks)
--
-- Taken out on 2026-10-10 (the user's calls): the lumber depot's shed over the pile and the steel frame over the gym
-- (they blocked the players' view), and every name sign that isn't about the game (CUTTING SHOP, MAINTENANCE, DIESEL,
-- SITE HQ, the company name on the container and the flag). The only words left are GRAND CANYON BRIDGE and the
-- progress board on the gateway.
--
-- Nothing is placed over the bridge (x < -179, |z| < 47 from the deck up) or in the walking line. Decoration parts
-- don't collide unless a player should bump into them. Copies of stored models come from ServerStorage.SiteAssets
-- (scripts, prompts, seats and joints stripped; see docs/notes/Grand Canyon game.md). The toolbox props the user had
-- dropped loose in Workspace are moved to ServerStorage.SiteAssets.UserPlaced (copies of each are in SiteAssets.Kit).

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local map = workspace:WaitForChild("Map")
local site = map:WaitForChild("Site")
local assets = ServerStorage:WaitForChild("SiteAssets")
local kit = assets:WaitForChild("Kit")

-- The camp's images (tools/make_site_textures.py), and the bridge's steel lattice (BridgeController LATTICE).
local HAZARD = "rbxassetid://135458992836001"
local TREAD = "rbxassetid://88988907820262"
local SLAB = "rbxassetid://77545709746012"
local ARROW = "rbxassetid://116307392520955"
local LATTICE = "rbxassetid://92137594628571"

local STEEL = Color3.fromRGB(58, 66, 80) -- the buildings' frames
local YELLOW = Color3.fromRGB(242, 184, 32) -- the cranes and the gateway
local CONCRETE = Color3.fromRGB(196, 192, 184)
local DIRT = Color3.fromRGB(156, 120, 86)
local PLANK = Color3.fromRGB(184, 128, 76)
local NAVY = Color3.fromRGB(24, 52, 100)

-- Old builds of camp's decoration go; the loose toolbox props go to storage.
for _, name in { "Busy", "Camp" } do
	local old = site:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
local retired = assets:FindFirstChild("Retired") or Instance.new("Folder")
retired.Name = "Retired"
retired.Parent = assets
local banner = site:FindFirstChild("BridgeBanner") -- tools/build_site.luau's banner: the gateway takes its place
if banner then
	banner.Parent = retired
end
local userPlaced = assets:FindFirstChild("UserPlaced") or Instance.new("Folder")
userPlaced.Name = "UserPlaced"
userPlaced.Parent = assets
for _, item in workspace:GetChildren() do
	if item:IsA("Model") and kit:FindFirstChild(item.Name) then
		item.Parent = userPlaced
	end
end

local camp = Instance.new("Model")
camp.Name = "Camp"
camp.Parent = site

local rng = Random.new(1929) -- the Navajo Bridge's opening year: the same camp on every run
local log = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain, map:FindFirstChild("RimFloor"), site:FindFirstChild("Ground") }
local function groundAt(x: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
	return if hit then hit.Position.Y else 1.5
end

-------------------------------------------------------------------------------------------------------------------
-- Building blocks.

type PartOptions = { collide: boolean?, transparency: number?, shape: Enum.PartType?, shadow: boolean? }
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, options: PartOptions?): Part
	local o = options or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = o.shape or Enum.PartType.Block
	p.Transparency = o.transparency or 0
	p.Anchored = true
	p.CanCollide = o.collide ~= false
	p.CanQuery = o.collide ~= false
	p.CanTouch = false
	p.CastShadow = o.shadow ~= false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function group(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or camp
	return m
end

local function texture(target: BasePart, image: string, faces: { Enum.NormalId }, tile: number, color: Color3?, transparency: number?)
	for _, face in faces do
		local t = Instance.new("Texture")
		t.Texture = image
		t.Face = face
		t.StudsPerTileU = tile
		t.StudsPerTileV = tile
		t.Color3 = color or Color3.new(1, 1, 1)
		t.Transparency = transparency or 0
		t.Parent = target
	end
end

local SIDES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

-- A see-through steel lattice panel in `cf`'s XY plane, `width` by `height`, one X every `tile` studs.
local function lattice(parent: Instance, name: string, cf: CFrame, width: number, height: number, tile: number, color: Color3, collide: boolean?): Part
	local panel = part(parent, name, Vector3.new(width, height, 0.2), cf, color, Enum.Material.Metal, { transparency = 1, collide = collide == true, shadow = false })
	texture(panel, LATTICE, { Enum.NormalId.Front, Enum.NormalId.Back }, tile, color)
	return panel
end

-- A beam from a to b.
local function beam(parent: Instance, name: string, a: Vector3, b: Vector3, thick: number, color: Color3, collide: boolean?): Part
	return part(parent, name, Vector3.new(thick, thick, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, Enum.Material.Metal, { collide = collide == true })
end

-- A sign board facing along cf's LookVector (and back, when `both`): white letters on `color`, a yellow rim. To face
-- +X turn it by -90 degrees, to face -X by 90, to face +Z by 180.
local function sign(parent: Instance, name: string, cf: CFrame, width: number, height: number, text: string, color: Color3, both: boolean?): Part
	local board = part(parent, name, Vector3.new(width, height, 0.4), cf, color, Enum.Material.SmoothPlastic, { collide = false })
	for _, face in if both then { Enum.NormalId.Front, Enum.NormalId.Back } else { Enum.NormalId.Front } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.LightInfluence = 0.3
		gui.Parent = board
		local rim = Instance.new("UIStroke")
		rim.Color = YELLOW
		rim.Thickness = math.min(width, height) * 1.6
		rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundTransparency = 1
		rim.Parent = frame
		frame.Parent = gui
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.92, 0.8)
		label.Position = UDim2.fromScale(0.04, 0.1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack -- the GUIs' font (UIStyle.FONT; FredokaOne until 2026-10-10)
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = text
		label.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(20, 20, 24)
		stroke.Parent = label
	end
	return board
end

-- A flat patch lying on the ground from (x0, z0) to (x1, z1), its top `lift` over the ground; walked through, never
-- hit by rays.
local function patch(name: string, x0: number, z0: number, x1: number, z1: number, color: Color3, material: Enum.Material, lift: number, parent: Instance?): Part
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local y = groundAt(cx, cz) + lift - 0.1
	local p = part(parent or camp, name, Vector3.new(math.abs(x1 - x0), 0.2, math.abs(z1 - z0)), CFrame.new(cx, y, cz), color, material, { collide = false, shadow = false })
	return p
end

-- A tire track from a to b (two tread lines), on the ground.
local function tracks(a: Vector2, b: Vector2, gauge: number)
	local dir = (b - a).Unit
	local side = Vector2.new(-dir.Y, dir.X) * gauge / 2
	for _, s in { side, -side } do
		local p0, p1 = a + s, b + s
		local mid = (p0 + p1) / 2
		local y = groundAt(mid.X, mid.Y) + 0.07
		local strip = part(camp, "TireTrack", Vector3.new(1.4, 0.1, (p1 - p0).Magnitude), CFrame.lookAt(Vector3.new(mid.X, y, mid.Y), Vector3.new(p1.X, y, p1.Y)), DIRT, Enum.Material.Ground, { collide = false, transparency = 1, shadow = false })
		local t = Instance.new("Texture")
		t.Texture = TREAD
		t.Face = Enum.NormalId.Top
		t.StudsPerTileU = 1.4
		t.StudsPerTileV = 3
		t.Parent = strip
	end
end

-- A painted line on the ground from a to b.
local function paint(a: Vector2, b: Vector2, width: number, color: Color3, lift: number?)
	local mid = (a + b) / 2
	local y = groundAt(mid.X, mid.Y) + (lift or 0.09) - 0.05
	part(camp, "Paint", Vector3.new(width, 0.1, (b - a).Magnitude), CFrame.lookAt(Vector3.new(mid.X, y, mid.Y), Vector3.new(b.X, y, b.Y)), color, Enum.Material.SmoothPlastic, { collide = false, shadow = false })
end

-- The world box around a model's parts (its own bounding box can lie on its side).
local function worldBox(m: Model): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local r = d.CFrame
			local half = Vector3.new(
				math.abs(r.XVector.X) * d.Size.X + math.abs(r.YVector.X) * d.Size.Y + math.abs(r.ZVector.X) * d.Size.Z,
				math.abs(r.XVector.Y) * d.Size.X + math.abs(r.YVector.Y) * d.Size.Y + math.abs(r.ZVector.Y) * d.Size.Z,
				math.abs(r.XVector.Z) * d.Size.X + math.abs(r.YVector.Z) * d.Size.Y + math.abs(r.ZVector.Z) * d.Size.Z
			) / 2
			lo = lo:Min(d.Position - half)
			hi = hi:Max(d.Position + half)
		end
	end
	return lo, hi
end

-- A copy of a stored model standing on the ground at (x, z): its bounding box turned to `yaw` degrees.
local function put(source: Instance, name: string, x: number, z: number, yaw: number, parent: Instance?): Model?
	local template = source:FindFirstChild(name)
	if not template then
		table.insert(log, `missing {name}`)
		return nil
	end
	local m = template:Clone() :: Model
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local box = m:GetBoundingBox()
	local rel = box:ToObjectSpace(m:GetPivot())
	-- Which of the box's axes is up in the template (a drum's box lies on its side), turned to point up.
	local up = box:VectorToObjectSpace(Vector3.yAxis)
	local stand = if math.abs(up.Y) > 0.5
		then (if up.Y > 0 then CFrame.identity else CFrame.Angles(math.pi, 0, 0))
		elseif math.abs(up.X) > 0.5 then CFrame.Angles(0, 0, math.sign(up.X) * math.pi / 2)
		else CFrame.Angles(-math.sign(up.Z) * math.pi / 2, 0, 0)
	m:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0) * stand * rel)
	local lo, hi = worldBox(m)
	m:PivotTo(m:GetPivot() + Vector3.new(x - (lo.X + hi.X) / 2, groundAt(x, z) - lo.Y, z - (lo.Z + hi.Z) / 2))
	m.Parent = parent or camp
	return m
end

-- A point on the ground at (x, z), turned `yaw` degrees.
local function at(x: number, z: number, yaw: number?): CFrame
	return CFrame.new(x, groundAt(x, z), z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
end

local function plankColor(): Color3
	local h, s, v = PLANK:ToHSV()
	return Color3.fromHSV(h, s, v * rng:NextNumber(0.84, 1.04))
end

-- A strapped stack of planks on two runners, the planks along the stack's local Z.
local function plankStack(cf: CFrame, across: number, layers: number, parent: Instance?)
	local m = group("PlankStack", parent)
	local width, tall, long = 1.6, 0.7, 14
	local span = across * width
	for _, z in { -long * 0.35, long * 0.35 } do
		part(m, "Runner", Vector3.new(span + 0.6, 0.6, 1), cf * CFrame.new(0, 0.3, z), Color3.fromRGB(110, 80, 52), Enum.Material.Wood)
	end
	for layer = 1, layers do
		for k = 1, across do
			local x = (k - (across + 1) / 2) * width
			part(m, "Plank", Vector3.new(width - 0.08, tall, long + rng:NextNumber(-0.6, 0.6)), cf * CFrame.new(x, 0.6 + (layer - 0.5) * tall, rng:NextNumber(-0.3, 0.3)), plankColor(), Enum.Material.WoodPlanks)
		end
	end
	local top = 0.6 + layers * tall
	for _, z in { -long * 0.25, long * 0.25 } do
		part(m, "Strap", Vector3.new(span + 0.12, top + 0.06, 0.25), cf * CFrame.new(0, top / 2 + 0.03, z), Color3.fromRGB(40, 40, 46), Enum.Material.Fabric, { collide = false })
	end
	return m
end

-- A pyramid of logs along cf's local Z.
local function logPile(cf: CFrame, length: number)
	local m = group("LogPile")
	local r = 1.3
	local bark = Color3.fromRGB(108, 76, 50)
	for row = 0, 2 do
		for k = 0, 3 - row - 1 do
			local x = (k - (3 - row - 1) / 2) * r * 2
			part(m, "Log", Vector3.new(length + rng:NextNumber(-1, 1), r * 2, r * 2), cf * CFrame.new(x, r + row * r * 1.75, 0) * CFrame.Angles(0, math.rad(90), 0), bark, Enum.Material.Wood, { shape = Enum.PartType.Cylinder })
		end
	end
	for _, s in { -1, 1 } do -- stakes holding the pile
		part(m, "Stake", Vector3.new(0.5, 6, 0.5), cf * CFrame.new(s * 4.4, 3, 0), Color3.fromRGB(70, 70, 76), Enum.Material.Metal)
	end
end

-- A cantilever lumber rack along cf's local X, `length` long, plank bundles on four levels.
local function lumberRack(cf: CFrame, length: number, facing: number)
	local m = group("LumberRack")
	for k = 0, 2 do
		local x = (k - 1) * (length / 2 - 1)
		part(m, "Upright", Vector3.new(1, 13, 1), cf * CFrame.new(x, 6.5, 0), STEEL, Enum.Material.Metal)
		part(m, "Foot", Vector3.new(1, 0.8, 7), cf * CFrame.new(x, 0.4, facing * 2.5), STEEL, Enum.Material.Metal)
		for level = 1, 4 do
			part(m, "Arm", Vector3.new(0.6, 0.5, 5.5), cf * CFrame.new(x, level * 3, facing * 2.75), YELLOW, Enum.Material.Metal)
		end
	end
	for level = 1, 4 do
		local bundle = part(m, "Bundle", Vector3.new(length - 1, 1.6, 4.6), cf * CFrame.new(rng:NextNumber(-0.5, 0.5), level * 3 + 1.05, facing * 2.9), plankColor(), Enum.Material.WoodPlanks)
		bundle.CastShadow = level == 1
	end
end

local function crate(cf: CFrame, size: number)
	local m = group("Crate")
	part(m, "Box", Vector3.one * size, cf * CFrame.new(0, size / 2, 0), Color3.fromRGB(176, 132, 82), Enum.Material.WoodPlanks)
	for _, y in { 0.15, size - 0.15 } do
		part(m, "Band", Vector3.new(size + 0.1, 0.3, size + 0.1), cf * CFrame.new(0, y, 0), Color3.fromRGB(120, 86, 52), Enum.Material.Wood, { collide = false })
	end
end

local function pallets(cf: CFrame, count: number)
	local m = group("Pallets")
	for k = 0, count - 1 do
		part(m, "Pallet", Vector3.new(4.4, 0.55, 4.4), cf * CFrame.new(0, 0.3 + k * 0.6, 0) * CFrame.Angles(0, math.rad(rng:NextNumber(-6, 6)), 0), Color3.fromRGB(160, 118, 74), Enum.Material.WoodPlanks)
	end
end

local function drum(cf: CFrame, color: Color3)
	part(camp, "Drum", Vector3.new(3.6, 2.6, 2.6), cf * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Metal, { shape = Enum.PartType.Cylinder })
end

local function heap(cf: CFrame, radius: number, height: number, color: Color3, material: Enum.Material)
	part(camp, "Heap", Vector3.new(radius * 2, height * 2, radius * 2), cf, color, material, { shape = Enum.PartType.Ball })
end

-- Excavated sandstone: a few red blocks tumbled together.
local function rubble(cf: CFrame, size: number)
	local m = group("Rubble")
	for k = 1, 4 do
		local s = size * rng:NextNumber(0.4, 1)
		part(m, "Rock", Vector3.new(s, s * 0.7, s * rng:NextNumber(0.7, 1.2)), cf * CFrame.new(rng:NextNumber(-1, 1) * size * 0.6, s * 0.25, rng:NextNumber(-1, 1) * size * 0.6) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.3), rng:NextNumber(-0.4, 0.4)), Color3.fromRGB(184, 98 + k * 4, 66), Enum.Material.Rock)
	end
end

local function sawhorse(cf: CFrame)
	local m = group("Sawhorse")
	local wood = Color3.fromRGB(150, 108, 66)
	part(m, "Beam", Vector3.new(0.6, 0.5, 6), cf * CFrame.new(0, 3, 0), wood, Enum.Material.Wood)
	for _, z in { -2.5, 2.5 } do
		for _, s in { -1, 1 } do
			part(m, "Leg", Vector3.new(0.35, 3.2, 0.35), cf * CFrame.new(s * 0.6, 1.45, z) * CFrame.Angles(0, 0, math.rad(s * -12)), wood, Enum.Material.Wood)
		end
	end
end

local function spool(cf: CFrame)
	local m = group("CableSpool")
	local r = 2.6
	for _, x in { -1.4, 1.4 } do
		part(m, "Flange", Vector3.new(0.4, r * 2, r * 2), cf * CFrame.new(x, r, 0), Color3.fromRGB(160, 116, 70), Enum.Material.Wood, { shape = Enum.PartType.Cylinder })
	end
	part(m, "Cable", Vector3.new(2.4, r * 1.5, r * 1.5), cf * CFrame.new(0, r, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Rubber, { shape = Enum.PartType.Cylinder })
end

local function generator(cf: CFrame)
	local m = group("Generator")
	part(m, "Body", Vector3.new(4, 3.4, 7), cf * CFrame.new(0, 2.1, 0), YELLOW)
	part(m, "Skid", Vector3.new(4.4, 0.4, 7.6), cf * CFrame.new(0, 0.2, 0), STEEL, Enum.Material.Metal)
	part(m, "Vent", Vector3.new(4.05, 1.4, 2), cf * CFrame.new(0, 2.4, 2), Color3.fromRGB(60, 60, 64), Enum.Material.DiamondPlate)
end

-- A concrete barrier along cf's local Z with a hazard band, 12 studs long.
local function barrier(cf: CFrame)
	local m = group("Barrier")
	part(m, "Base", Vector3.new(2.4, 1.4, 12), cf * CFrame.new(0, 0.7, 0), CONCRETE, Enum.Material.Concrete)
	local top = part(m, "Top", Vector3.new(1.3, 1.8, 12), cf * CFrame.new(0, 2.3, 0), CONCRETE, Enum.Material.Concrete)
	texture(top, HAZARD, { Enum.NormalId.Left, Enum.NormalId.Right }, 3)
end
local function barrierRow(fromX: number, fromZ: number, toX: number, toZ: number)
	local length = Vector2.new(toX - fromX, toZ - fromZ).Magnitude
	local count = math.max(1, math.floor(length / 12.4 + 0.5))
	for k = 0, count - 1 do
		local t = (k + 0.5) / count
		local x, z = fromX + (toX - fromX) * t, fromZ + (toZ - fromZ) * t
		barrier(CFrame.lookAt(Vector3.new(x, groundAt(x, z), z), Vector3.new(toX, groundAt(x, z), toZ)))
	end
end

-- A blinking amber beacon (SiteAmbienceController).
local function beacon(parent: Instance, position: Vector3)
	local light = part(parent, "Beacon", Vector3.new(1.2, 1.2, 1.2), CFrame.new(position), Color3.fromRGB(255, 150, 20), Enum.Material.Neon, { collide = false, shadow = false })
	CollectionService:AddTag(light, "SiteBeacon")
end

-- A square lattice tower `width` wide and `height` tall standing at `base`, corner posts and lattice sides.
local function tower(parent: Instance, base: CFrame, width: number, height: number, color: Color3, tile: number)
	local h = width / 2
	for _, side in { 0, 90, 180, 270 } do
		lattice(parent, "Side", base * CFrame.Angles(0, math.rad(side), 0) * CFrame.new(0, height / 2, h), width, height, tile, color)
	end
	for _, c in { { -h, -h }, { -h, h }, { h, -h }, { h, h } } do
		part(parent, "Post", Vector3.new(0.7, height, 0.7), base * CFrame.new(c[1], height / 2, c[2]), color, Enum.Material.Metal)
	end
end

-- A concrete footing `size` square, hazard stripes round its sides.
local function footing(parent: Instance, cf: CFrame, size: number, tall: number)
	local f = part(parent, "Footing", Vector3.new(size, tall, size), cf * CFrame.new(0, tall / 2, 0), CONCRETE, Enum.Material.Concrete)
	texture(f, HAZARD, SIDES, 3)
	return f
end

-- A portable cabin with its long front facing cf's +Z.
local function cabin(parent: Instance, cf: CFrame, trim: Color3)
	local m = group("Cabin", parent)
	local size = Vector3.new(26, 9, 10)
	part(m, "Body", size, cf * CFrame.new(0, size.Y / 2 + 0.6, 0), Color3.fromRGB(236, 236, 228), Enum.Material.Metal)
	part(m, "Base", Vector3.new(size.X + 0.4, 0.6, size.Z + 0.4), cf * CFrame.new(0, 0.3, 0), STEEL, Enum.Material.Metal)
	part(m, "Roof", Vector3.new(size.X + 0.6, 0.4, size.Z + 0.6), cf * CFrame.new(0, size.Y + 0.8, 0), trim, Enum.Material.Metal)
	part(m, "Stripe", Vector3.new(size.X + 0.05, 0.8, size.Z + 0.05), cf * CFrame.new(0, 2, 0), trim, Enum.Material.Metal, { collide = false })
	for _, x in { -8, 0, 8 } do
		part(m, "Window", Vector3.new(4, 2.6, 0.2), cf * CFrame.new(x, 6, size.Z / 2 + 0.05), Color3.fromRGB(120, 170, 200), Enum.Material.Glass, { collide = false })
	end
	part(m, "Door", Vector3.new(3, 6.4, 0.2), cf * CFrame.new(11, 3.8, size.Z / 2 + 0.05), trim, Enum.Material.Metal, { collide = false })
end

-------------------------------------------------------------------------------------------------------------------
-- 1. The ground: the route's paving, slabs under the buildings, compacted dirt roads, gravel in the yards.

local ground = group("Ground")
local road = patch("MainRoad", -180, -42, -128, 42, Color3.fromRGB(84, 82, 80), Enum.Material.Asphalt, 0.06, ground)
patch("DepotLink", -128, -14, -45, 30, Color3.fromRGB(84, 82, 80), Enum.Material.Asphalt, 0.06, ground)
for _, z in { -41, 41 } do
	paint(Vector2.new(-179, z), Vector2.new(-128, z), 0.9, YELLOW) -- the road's edges, run on to the bridge's
end
for _, x in { -142, -166 } do -- chevrons pointing at the bridge, in both lanes
	for _, z in { -20, 20 } do
		local mark = part(ground, "Arrow", Vector3.new(14, 0.1, 14), CFrame.new(x, road.Position.Y + 0.08, z) * CFrame.Angles(0, math.rad(-90), 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { collide = false, transparency = 1, shadow = false })
		local decal = Instance.new("Decal")
		decal.Texture = ARROW
		decal.Face = Enum.NormalId.Top
		decal.Transparency = 0.15
		decal.Parent = mark
	end
end
local depotSlab = patch("DepotSlab", -130, -32, -76, 30, CONCRETE, Enum.Material.Concrete, 0.08, ground)
texture(depotSlab, SLAB, { Enum.NormalId.Top }, 10)
local plaza = patch("SpawnPlaza", 72, -22, 100, 18, CONCRETE, Enum.Material.Concrete, 0.08, ground)
texture(plaza, SLAB, { Enum.NormalId.Top }, 10)
local hqPad = patch("HQPad", 136, 18, 166, 82, CONCRETE, Enum.Material.Concrete, 0.08, ground)
texture(hqPad, SLAB, { Enum.NormalId.Top }, 10)
patch("GateRoad", 100, -12, 172, 8, DIRT, Enum.Material.Ground, 0.06, ground)
patch("ServiceRoadEast", 94, -107, 116, -12, DIRT, Enum.Material.Ground, 0.05, ground)
patch("ServiceRoadNorth", -100, -102, 116, -78, DIRT, Enum.Material.Ground, 0.06, ground)
patch("YardEntry", 94, -125, 116, -107, DIRT, Enum.Material.Ground, 0.06, ground)
patch("YardGravel", -170, -215, 166, -110, Color3.fromRGB(150, 138, 124), Enum.Material.Pebble, 0.04, ground)
patch("LumberYardGravel", -168, 50, -94, 96, Color3.fromRGB(160, 146, 128), Enum.Material.Pebble, 0.04, ground)
patch("CuttingShopFloor", -168, -100, -102, -50, Color3.fromRGB(208, 180, 140), Enum.Material.Sand, 0.05, ground)
tracks(Vector2.new(172, -2), Vector2.new(100, -2), 7)
tracks(Vector2.new(105, -10), Vector2.new(105, -125), 7)
tracks(Vector2.new(110, -90), Vector2.new(-100, -90), 7)
tracks(Vector2.new(100, -140), Vector2.new(-40, -150), 7)
tracks(Vector2.new(20, -125), Vector2.new(30, -200), 7)

-------------------------------------------------------------------------------------------------------------------
-- 2. Around the plank pile: lumber racks either side, crates and pallets at the corners (no shed over it since
-- 2026-10-10: it blocked the view).

do
	-- Racks of plank bundles either side of the pile, crates and pallets at the corners.
	lumberRack(at(-114, 36), 20, 1)
	lumberRack(at(-90, 36), 20, 1)
	lumberRack(at(-114, -38), 20, -1)
	lumberRack(at(-90, -38), 20, -1)
	crate(at(-73, 34, 10), 3.2)
	crate(at(-70, 37, 30), 2.6)
	crate(at(-72.5, 34, 5) * CFrame.new(0, 3.2, 0), 2.6)
	pallets(at(-71, -36, 0), 6)
	pallets(at(-76, -36, 12), 4)
end

-- The lumber yard south of the road: stacks, log piles, a forklift bringing a load toward the bridge.
for _, spot in { { -158, 62 }, { -140, 62 }, { -158, 74 }, { -140, 74 }, { -158, 86 }, { -140, 86 } } do
	plankStack(at(spot[1], spot[2], 90 + rng:NextNumber(-2, 2)), 4, rng:NextInteger(3, 7))
end
logPile(at(-118, 64, 90), 18)
logPile(at(-118, 80, 90), 18)
put(assets, "BigForklift", -150, 51, 0)
plankStack(at(-160, 51, 90), 3, 2)

-- The cutting shop north of the pile, under a lean-to roof: saw tables, a table saw, sawhorses, offcuts.
local shop = group("CuttingShop")
do
	local g = groundAt(-135, -75)
	for _, x in { -162, -135, -108 } do
		for _, z in { -58, -92 } do
			part(shop, "Post", Vector3.new(1, if z == -58 then 13 else 11, 1), CFrame.new(x, g + (if z == -58 then 6.5 else 5.5), z), STEEL, Enum.Material.Metal)
		end
		beam(shop, "Rafter", Vector3.new(x, g + 13, -58), Vector3.new(x, g + 11, -92), 0.8, STEEL)
	end
	local roofLow, roofHigh = Vector3.new(-135, g + 11.5, -94), Vector3.new(-135, g + 13.5, -56)
	part(shop, "Roof", Vector3.new(58, 0.4, (roofHigh - roofLow).Magnitude), CFrame.lookAt((roofLow + roofHigh) / 2, roofHigh), Color3.fromRGB(150, 160, 170), Enum.Material.Metal, { collide = false })
	put(assets, "SawTable", -150, -66, 0, shop)
	put(assets, "SawTable", -128, -66, 0, shop)
	put(assets, "TableSaw", -114, -70, 90, shop)
	local horses = at(-150, -84, 90)
	sawhorse(horses * CFrame.new(0, 0, -3.5))
	sawhorse(horses * CFrame.new(0, 0, 3.5))
	part(shop, "Plank", Vector3.new(1.6, 0.7, 14), horses * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, math.rad(90), 0), plankColor(), Enum.Material.WoodPlanks)
	for k = 1, 6 do
		part(shop, "Offcut", Vector3.new(1.6, 0.7, rng:NextNumber(1.5, 4)), at(-132 + rng:NextNumber(-3, 3), -84 + rng:NextNumber(-3, 3), rng:NextNumber(0, 180)) * CFrame.new(0, 0.35 + (k % 2) * 0.7, 0), plankColor(), Enum.Material.WoodPlanks, { collide = false })
	end
	plankStack(at(-120, -86, 90), 4, 4, shop)
end

-------------------------------------------------------------------------------------------------------------------
-- 3. The bridge's gateway: the tallest thing in camp short of the crane, on the rim either side of the bridge.

local gate = group("BridgeGateway")
gate.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- seen from far out on the bridge
do
	local X = -173 -- the towers' middle, on the rim
	local Z = 52
	local HEIGHT, GIRDER = 64, 8
	local g = groundAt(X, 0)
	for _, s in { -1, 1 } do
		local base = CFrame.new(X, g, s * Z)
		footing(gate, base, 11, 2)
		tower(gate, base * CFrame.new(0, 2, 0), 8, HEIGHT - 2, YELLOW, 4)
		beacon(gate, Vector3.new(X, g + HEIGHT + 0.8, s * Z))
	end
	-- The girder across the top: lattice faces front and back, four chords.
	local top = g + HEIGHT - GIRDER / 2
	for _, x in { X - 2.2, X + 2.2 } do
		lattice(gate, "Girder", CFrame.new(x, top, 0) * CFrame.Angles(0, math.rad(90), 0), Z * 2 + 8, GIRDER, 4, YELLOW)
		for _, y in { top - GIRDER / 2, top + GIRDER / 2 } do
			part(gate, "Chord", Vector3.new(0.9, 0.9, Z * 2 + 8), CFrame.new(x, y, 0), YELLOW, Enum.Material.Metal, { collide = false })
		end
	end
	sign(gate, "Name", CFrame.new(X + 2.8, top, 0) * CFrame.Angles(0, math.rad(-90), 0), 76, GIRDER - 1.2, "GRAND CANYON BRIDGE", NAVY)
	sign(gate, "NameBack", CFrame.new(X - 2.8, top, 0) * CFrame.Angles(0, math.rad(90), 0), 60, GIRDER - 1.2, "GRAND CANYON BRIDGE", NAVY)
	-- The progress board hangs under the girder's middle (SiteAmbienceController fills it in).
	local boardY = top - GIRDER / 2 - 6
	for _, z in { -12, 12 } do
		part(gate, "Hanger", Vector3.new(0.3, 2, 0.3), CFrame.new(X + 2.2, boardY + 5, z), STEEL, Enum.Material.Metal, { collide = false })
	end
	local board = part(gate, "ProgressBoard", Vector3.new(0.6, 8, 30), CFrame.new(X + 2.2, boardY, 0), NAVY, Enum.Material.SmoothPlastic, { collide = false })
	CollectionService:AddTag(board, "BridgeProgressBoard")
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Progress"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.LightInfluence = 0.3
		gui.Parent = board
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(0.94, 0.3)
		title.Position = UDim2.fromScale(0.03, 0.06)
		title.Font = Enum.Font.GothamBlack -- the GUIs' font (UIStyle.FONT; FredokaOne until 2026-10-10)
		title.TextScaled = true
		title.TextColor3 = YELLOW
		title.Text = "BRIDGE PROGRESS"
		title.Parent = gui
		local percent = Instance.new("TextLabel")
		percent.Name = "Percent"
		percent.BackgroundTransparency = 1
		percent.Size = UDim2.fromScale(0.94, 0.32)
		percent.Position = UDim2.fromScale(0.03, 0.36)
		percent.Font = Enum.Font.GothamBlack -- the GUIs' font (UIStyle.FONT; FredokaOne until 2026-10-10)
		percent.TextScaled = true
		percent.TextColor3 = Color3.new(1, 1, 1)
		percent.Text = "0% BUILT"
		percent.Parent = gui
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.BackgroundColor3 = Color3.fromRGB(14, 28, 56)
		bar.BorderSizePixel = 0
		bar.Size = UDim2.fromScale(0.9, 0.16)
		bar.Position = UDim2.fromScale(0.05, 0.75)
		bar.Parent = gui
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BackgroundColor3 = YELLOW
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(0, 1)
		fill.Parent = bar
	end
	-- A plank bundle on a cable from the girder, swinging a little (SiteAmbienceController).
	local load = group("SwingingLoad", gate)
	local hang = Vector3.new(X, top - GIRDER / 2, -30)
	part(load, "Cable", Vector3.new(0.2, 14, 0.2), CFrame.new(hang - Vector3.new(0, 7, 0)), Color3.fromRGB(30, 30, 34), Enum.Material.Metal, { collide = false })
	part(load, "Hook", Vector3.new(1, 1.2, 1), CFrame.new(hang - Vector3.new(0, 14.4, 0)), YELLOW, Enum.Material.Metal, { collide = false })
	for _, z in { -4, 4 } do
		beam(load, "Sling", hang - Vector3.new(0, 15, 0), hang + Vector3.new(0, -19, z), 0.15, Color3.fromRGB(240, 120, 30))
	end
	for k = 0, 2 do
		part(load, "Bundle", Vector3.new(4.8, 0.7, 14), CFrame.new(hang + Vector3.new(0, -19.4 - k * 0.72, 0)), plankColor(), Enum.Material.WoodPlanks, { collide = false })
	end
	load.WorldPivot = CFrame.new(hang)
	CollectionService:AddTag(load, "SiteSway")
	-- Scaffolds against the rim beside each tower, three lifts high.
	for _, s in { -1, 1 } do
		local base = CFrame.new(-174, g, s * 65)
		local sc = group("Scaffold", gate)
		for _, c in { { -4, -5 }, { -4, 5 }, { 4, -5 }, { 4, 5 } } do
			part(sc, "Pole", Vector3.new(0.5, 25, 0.5), base * CFrame.new(c[1], 12.5, c[2]), Color3.fromRGB(170, 176, 184), Enum.Material.Metal)
		end
		for level = 1, 3 do
			part(sc, "Deck", Vector3.new(8.6, 0.4, 10.6), base * CFrame.new(0, level * 8, 0), Color3.fromRGB(160, 116, 70), Enum.Material.WoodPlanks)
			part(sc, "Toe", Vector3.new(8.6, 1, 0.2), base * CFrame.new(0, level * 8 + 0.7, s * 5.2), YELLOW, Enum.Material.SmoothPlastic, { collide = false })
		end
		lattice(sc, "Brace", base * CFrame.new(0, 12.5, -s * 5), 8, 25, 8, Color3.fromRGB(170, 176, 184))
		lattice(sc, "Brace", base * CFrame.new(4, 12.5, 0) * CFrame.Angles(0, math.rad(90), 0), 10, 25, 10, Color3.fromRGB(170, 176, 184))
	end
	-- Floodlight towers farther along the rim, lamps turned to the bridge.
	for _, s in { -1, 1 } do
		local base = CFrame.new(-171, groundAt(-171, s * 104), s * 104)
		footing(gate, base, 6, 1.5)
		tower(gate, base * CFrame.new(0, 1.5, 0), 3, 44, Color3.fromRGB(170, 176, 184), 3)
		part(gate, "LampBar", Vector3.new(1, 1, 12), base * CFrame.new(-1, 46, 0), STEEL, Enum.Material.Metal, { collide = false })
		for k = -1, 1 do
			part(gate, "Lamp", Vector3.new(1.4, 2.4, 3), base * CFrame.new(-2, 47.5, k * 4) * CFrame.Angles(0, 0, math.rad(-20)), Color3.fromRGB(255, 244, 210), Enum.Material.Neon, { collide = false, shadow = false })
		end
	end
	-- Lit barricades and drums beside the way onto the bridge.
	put(kit, "RoadBarricadeWithLights", -160, 45, 0, gate)
	put(kit, "RoadBarricadeWithLights", -160, -45, 0, gate)
	put(kit, "DrumBarrelConeWithLight", -150, 46, 0, gate)
	put(kit, "DrumBarrelConeWithLight", -150, -46, 0, gate)
end

-------------------------------------------------------------------------------------------------------------------
-- 4. Safety lines down both edges of the gym's aisle (its steel frame came out on 2026-10-10: it blocked the view).

for _, z in { -12.5, 26.5 } do
	paint(Vector2.new(-54, z), Vector2.new(82, z), 0.7, YELLOW, 0.2)
end

-------------------------------------------------------------------------------------------------------------------
-- 5. The equipment yard on the back lot: the tower crane, an excavator loading a dump truck, marked bays, a
-- maintenance corner, steel and a container waiting.

local yard = group("EquipmentYard")
do
	-- The tower crane: a lattice mast on a footing; its top (cab, jib, counter-jib, the load) turns slowly.
	local crane = group("TowerCrane", yard)
	crane.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local CX, CZ = -138, -158
	local g = groundAt(CX, CZ)
	local MAST, W = 80, 6
	footing(crane, CFrame.new(CX, g, CZ), 14, 3)
	tower(crane, CFrame.new(CX, g + 3, CZ), W, MAST, YELLOW, 6)
	local base = g + 3 + MAST
	local top = group("Slewing", crane)
	part(top, "Turntable", Vector3.new(1.5, 8, 8), CFrame.new(CX, base + 0.75, CZ) * CFrame.Angles(0, 0, math.rad(90)), STEEL, Enum.Material.Metal, { shape = Enum.PartType.Cylinder, collide = false })
	part(top, "Cab", Vector3.new(4.5, 4.2, 4.5), CFrame.new(CX + 2, base + 3.6, CZ + 5), YELLOW, Enum.Material.Metal, { collide = false })
	part(top, "CabGlass", Vector3.new(4.6, 2, 3.4), CFrame.new(CX + 2.1, base + 4.4, CZ + 5), Color3.fromRGB(120, 170, 200), Enum.Material.Glass, { collide = false })
	local apex = Vector3.new(CX, base + 18, CZ)
	for _, c in { { -2.5, -2.5 }, { -2.5, 2.5 }, { 2.5, -2.5 }, { 2.5, 2.5 } } do
		beam(top, "Apex", Vector3.new(CX + c[1], base + 1.5, CZ + c[2]), apex, 0.7, YELLOW)
	end
	local JIB, COUNTER = 92, 30
	for _, z in { -1.6, 1.6 } do -- the jib out along +X, the counter-jib along -X
		lattice(top, "Jib", CFrame.new(CX + 3 + JIB / 2, base + 3.5, CZ + z), JIB, 4, 4, YELLOW)
		part(top, "JibChord", Vector3.new(JIB, 0.6, 0.6), CFrame.new(CX + 3 + JIB / 2, base + 1.5, CZ + z), YELLOW, Enum.Material.Metal, { collide = false })
		lattice(top, "CounterJib", CFrame.new(CX - 3 - COUNTER / 2, base + 3, CZ + z), COUNTER, 3, 3, YELLOW)
	end
	part(top, "JibTop", Vector3.new(JIB, 0.6, 0.6), CFrame.new(CX + 3 + JIB / 2, base + 5.5, CZ), YELLOW, Enum.Material.Metal, { collide = false })
	part(top, "Walkway", Vector3.new(COUNTER, 0.4, 3.6), CFrame.new(CX - 3 - COUNTER / 2, base + 1.4, CZ), STEEL, Enum.Material.DiamondPlate, { collide = false })
	for k = 0, 1 do
		part(top, "Counterweight", Vector3.new(3, 6, 5), CFrame.new(CX - COUNTER + 1 + k * 3.2, base - 1, CZ), CONCRETE, Enum.Material.Concrete, { collide = false })
	end
	beam(top, "Tie", apex, Vector3.new(CX + 3 + JIB * 0.7, base + 5.5, CZ), 0.25, STEEL)
	beam(top, "Tie", apex, Vector3.new(CX - COUNTER, base + 4, CZ), 0.25, STEEL)
	beacon(top, apex + Vector3.new(0, 1, 0))
	beacon(top, Vector3.new(CX + 3 + JIB, base + 6.4, CZ))
	-- The trolley 60 out, a steel girder hanging on slings far below.
	local trolley = Vector3.new(CX + 62, base + 0.8, CZ)
	part(top, "Trolley", Vector3.new(4, 1.4, 4), CFrame.new(trolley), STEEL, Enum.Material.Metal, { collide = false })
	local hookY = base - 40
	part(top, "HookCable", Vector3.new(0.25, trolley.Y - hookY, 0.25), CFrame.new(CX + 62, (trolley.Y + hookY) / 2, CZ), Color3.fromRGB(30, 30, 34), Enum.Material.Metal, { collide = false })
	part(top, "Hook", Vector3.new(1.4, 2, 1.4), CFrame.new(CX + 62, hookY - 1, CZ), YELLOW, Enum.Material.Metal, { collide = false })
	local loadY = hookY - 9
	for _, x in { -6, 6 } do
		beam(top, "Sling", Vector3.new(CX + 62, hookY - 2, CZ), Vector3.new(CX + 62 + x, loadY + 1.2, CZ), 0.15, Color3.fromRGB(240, 120, 30))
	end
	local RED = Color3.fromRGB(196, 72, 44) -- primer red steel, like the bridge's girders before paint
	part(top, "GirderTop", Vector3.new(20, 0.5, 2.4), CFrame.new(CX + 62, loadY + 1, CZ), RED, Enum.Material.Metal, { collide = false })
	part(top, "GirderWeb", Vector3.new(20, 2, 0.4), CFrame.new(CX + 62, loadY - 0.25, CZ), RED, Enum.Material.Metal, { collide = false })
	part(top, "GirderBottom", Vector3.new(20, 0.5, 2.4), CFrame.new(CX + 62, loadY - 1.5, CZ), RED, Enum.Material.Metal, { collide = false })
	top.WorldPivot = CFrame.new(CX, base, CZ)
	top:SetAttribute("SlewSeconds", 260)
	CollectionService:AddTag(top, "SiteSlew")

	-- Steel girders and a container waiting by the crane.
	for k = 0, 2 do
		for j = -1, 1 do
			local cf = at(-140, -128, 90) * CFrame.new(j * 3, 0.6 + k * 2.6, 0)
			part(yard, "Girder", Vector3.new(2.4, 2.4, 22), cf * CFrame.new(0, 1.2, 0), RED, Enum.Material.Metal)
		end
	end
	for _, z in { -6, 6 } do
		part(yard, "Dunnage", Vector3.new(10, 0.6, 1), at(-140, -128 + z, 0) * CFrame.new(0, 0.3, 0), Color3.fromRGB(110, 80, 52), Enum.Material.Wood)
	end
	part(yard, "Container", Vector3.new(20, 8.5, 8), at(-150, -196) * CFrame.new(0, 4.25, 0), Color3.fromRGB(40, 110, 170), Enum.Material.CorrodedMetal)

	-- The excavator loading a dump truck from a heap of dug sandstone; dust drifts off the heap.
	put(assets, "Excavator", -70, -150, 200, yard)
	heap(at(-100, -142), 11, 5, Color3.fromRGB(170, 96, 64), Enum.Material.Ground)
	rubble(at(-108, -152), 3)
	rubble(at(-92, -128), 2.4)
	put(assets, "DumpTruck", -36, -142, 90, yard)
	local dust = part(yard, "Dust", Vector3.new(14, 1, 14), at(-100, -142) * CFrame.new(0, 4, 0), DIRT, Enum.Material.SmoothPlastic, { collide = false, transparency = 1, shadow = false })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(214, 176, 132))
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.7), NumberSequenceKeypoint.new(1, 1) })
	emitter.Size = NumberSequence.new(4, 9)
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Rate = 2
	emitter.Speed = NumberRange.new(1, 2.5)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Acceleration = Vector3.new(1.5, 0.4, 0)
	emitter.LightEmission = 0
	emitter.Parent = dust

	-- Parking bays along the back, white lines, a vehicle nosed into most of them.
	local BAYS = { -- x from, x to, what's parked (nil: empty), its yaw
		{ -112, -26, "LogTruck", 0 },
		{ -20, 4, "DumpTruck", 90 },
		{ 6, 24, "BigForklift", 90 },
		{ 26, 44, nil, 0 },
		{ 46, 64, nil, 0 },
	}
	local Z0, Z1 = -208, -178
	for _, bay in BAYS do
		paint(Vector2.new(bay[1], Z1), Vector2.new(bay[1], Z0), 0.7, Color3.new(1, 1, 1))
		paint(Vector2.new(bay[2], Z1), Vector2.new(bay[2], Z0), 0.7, Color3.new(1, 1, 1))
		paint(Vector2.new(bay[1], Z0), Vector2.new(bay[2], Z0), 0.7, Color3.new(1, 1, 1))
		if bay[3] then
			put(assets, bay[3], (bay[1] + bay[2]) / 2, if bay[3] == "LogTruck" then -196 else -192, bay[4], yard)
		end
	end
	-- The crane-and-digger set on its own pad by the east fence.
	local pad = patch("HeavyPad", 88, -212, 152, -118, Color3.fromRGB(176, 170, 160), Enum.Material.Concrete, 0.08, yard)
	texture(pad, SLAB, { Enum.NormalId.Top }, 12)
	put(assets, "ConstructionSet", 120, -164, 0, yard)

	-- The maintenance corner: an open shed, tool chests, drums, tires, a fuel tank, a generator.
	local mx, mz = 52, -150
	local mg = groundAt(mx, mz)
	for _, x in { mx - 12, mx + 12 } do
		for _, z in { mz - 6, mz + 6 } do
			part(yard, "Post", Vector3.new(0.8, 11, 0.8), CFrame.new(x, mg + 5.5, z), STEEL, Enum.Material.Metal)
		end
	end
	part(yard, "ShedRoof", Vector3.new(28, 0.4, 15), CFrame.new(mx, mg + 11.2, mz) * CFrame.Angles(math.rad(-4), 0, 0), Color3.fromRGB(150, 160, 170), Enum.Material.Metal, { collide = false })
	for k, x in { mx - 8, mx - 4.5 } do
		part(yard, "ToolChest", Vector3.new(3, 3.6 + k * 0.4, 2), CFrame.new(x, mg + 1.8 + k * 0.2, mz - 4.4), Color3.fromRGB(196, 40, 36), Enum.Material.Metal)
	end
	part(yard, "Workbench", Vector3.new(8, 3, 3), CFrame.new(mx + 4, mg + 1.5, mz - 4.2), Color3.fromRGB(120, 90, 60), Enum.Material.Wood)
	for k = 0, 3 do
		drum(at(mx + 14 + (k % 2) * 3, mz + 9 + math.floor(k / 2) * 3), if k == 2 then Color3.fromRGB(40, 90, 170) else Color3.fromRGB(196, 60, 40))
	end
	for k = 0, 4 do -- a stack of tires
		part(yard, "Tire", Vector3.new(1.4, 5, 5), at(mx - 16, mz + 9) * CFrame.new(0, 0.7 + k * 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(28, 28, 30), Enum.Material.Rubber, { shape = Enum.PartType.Cylinder })
	end
	local tank = at(mx + 4, mz + 16)
	for _, x in { -5, 5 } do
		part(yard, "Saddle", Vector3.new(1, 2.4, 5), tank * CFrame.new(x, 1.2, 0), STEEL, Enum.Material.Metal)
	end
	part(yard, "FuelTank", Vector3.new(16, 6, 6), tank * CFrame.new(0, 5, 0), Color3.fromRGB(236, 236, 228), Enum.Material.Metal, { shape = Enum.PartType.Cylinder })
	generator(at(mx - 20, mz - 2, 90))
	spool(at(mx - 26, mz + 12, 30))
	for k = 0, 3 do
		put(kit, "DrumBarrelCone", 92 + k * 6, -112, 0, yard)
	end
end

-------------------------------------------------------------------------------------------------------------------
-- 6. The site HQ by the spawn: two stacked cabins facing camp, a flagpole, a survey instrument and a plan table.

local hq = group("SiteHQ")
do
	local cf = at(158, 46, -90)
	cabin(hq, cf, NAVY)
	cabin(hq, cf * CFrame.new(0, 10.4, 0), NAVY)
	for k = 0, 9 do
		part(hq, "Step", Vector3.new(3, 0.5, 1.2), cf * CFrame.new(-15, 0.6 + k * 1.05, 4.4 - k * 1.05), STEEL, Enum.Material.DiamondPlate)
	end
	part(hq, "Landing", Vector3.new(4, 0.5, 10), cf * CFrame.new(-15.5, 10.6, -0.5), STEEL, Enum.Material.DiamondPlate)
	local g = groundAt(142, 70)
	part(hq, "Flagpole", Vector3.new(0.5, 34, 0.5), CFrame.new(142, g + 17, 70), Color3.fromRGB(220, 220, 226), Enum.Material.Metal)
	part(hq, "Flag", Vector3.new(0.2, 5, 8.6), CFrame.new(142, g + 31, 74.6), Color3.fromRGB(196, 60, 40), Enum.Material.Fabric, { collide = false })
	-- A theodolite on its tripod, looking out at the canyon.
	local tg = groundAt(141, 26)
	for k = 0, 2 do
		local a = math.rad(k * 120)
		beam(hq, "Leg", Vector3.new(141 + math.cos(a) * 1.6, tg, 26 + math.sin(a) * 1.6), Vector3.new(141, tg + 4.6, 26), 0.25, YELLOW)
	end
	part(hq, "Instrument", Vector3.new(1.2, 1.4, 0.9), CFrame.new(141, tg + 5.3, 26), YELLOW, Enum.Material.SmoothPlastic, { collide = false })
	-- The plan table, a blueprint on it.
	local pt = at(146, 36, 0)
	part(hq, "Table", Vector3.new(7, 0.4, 4), pt * CFrame.new(0, 3.4, 0), Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
	for _, c in { { -3.2, -1.7 }, { -3.2, 1.7 }, { 3.2, -1.7 }, { 3.2, 1.7 } } do
		part(hq, "Leg", Vector3.new(0.3, 3.2, 0.3), pt * CFrame.new(c[1], 1.6, c[2]), STEEL, Enum.Material.Metal)
	end
	part(hq, "Plan", Vector3.new(6, 0.05, 3.4), pt * CFrame.new(0, 3.63, 0), Color3.fromRGB(40, 90, 170), Enum.Material.SmoothPlastic, { collide = false })
	crate(at(150, 22, 15), 3)
	crate(at(154, 23, -10), 2.4)
	for k, z in { 66, 71, 76 } do
		put(kit, "PortaPotty", 162, z, 90 + (k - 2) * 3, hq)
	end
	beacon(hq, cf.Position + Vector3.new(0, 21.4, 0))
end

-- The truck gate: flagged signs either side of the road, lit drums along its edges.
put(kit, "TemporarySignWithFlags", 165, 12, 90)
put(kit, "TemporarySignWithFlags", 165, -16, 90)
for x = 128, 160, 16 do
	put(kit, "DrumBarrelConeWithLight", x, 11, 0)
	put(kit, "DrumBarrelConeWithLight", x, -15, 0)
end

-------------------------------------------------------------------------------------------------------------------
-- 7. Concrete barriers round camp's edge: gaps for the bridge (and its gateway and scaffolds), the gate and the yard.

barrierRow(-176, 76, -176, 147) -- the rim, south of the bridge
barrierRow(-176, -76, -176, -214) -- the rim, north of the bridge
barrierRow(-170, 149, 166, 149) -- the south side
barrierRow(-170, -218, 166, -218) -- the back of the yard
barrierRow(169, 147, 169, 16) -- the east side, south of the gate
barrierRow(169, -20, 169, -216) -- the east side, north of the gate

-- Excavated sandstone left at camp's corners, a few dry bushes.
for _, spot in { { -165, 140, 3 }, { 155, 140, 2.6 }, { -165, -112, 2.4 }, { 75, 140, 2 }, { 160, -110, 2.4 } } do
	rubble(at(spot[1], spot[2]), spot[3])
end

-------------------------------------------------------------------------------------------------------------------

local parts = 0
for _, d in camp:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
return `camp: {parts} parts` .. (if #log > 0 then "; " .. table.concat(log, ", ") else "")
