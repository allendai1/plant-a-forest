-- build_shop.luau: turns the upgrades shop (Lobby.RangerStation, a log cabin) into a construction supply depot
-- (2026-10-10, the user's ask). Not shipped. Run it in the Edit datamodel through the Studio connection (fetch it from
-- the local server and loadstring it). Safe to run again: it rebuilds RangerStation.SupplyDepot.
--
-- What makes the shop work stays exactly where it is: the ShopZone ring players step into, its glow, the floating
-- UPGRADES sign (SignAnchor) and the Shopkeeper. The cabin's meshes go to ServerStorage.PlantTreesMap.RangerStation.
-- The depot is built around the station's own position and facing, wherever it has been moved: an orange shipping
-- container opened at the front, a service counter with the shopkeeper behind it, a hazard-striped awning with the
-- UPGRADES board on it and SUPPLY DEPOT lettering, shelves of hard hats, paint cans and toolboxes, crates and cones.

local ServerStorage = game:GetService("ServerStorage")

local station = workspace.Map.Lobby:FindFirstChild("RangerStation") :: Model
assert(station, "no Lobby.RangerStation")
local zone = station:FindFirstChild("ShopZone") :: BasePart
local keeper = station:FindFirstChild("Shopkeeper") :: Model?
local board = station:FindFirstChild("UpgradesBoard") :: BasePart?
local log = {}

local ORANGE = Color3.fromRGB(226, 112, 36)
local RIB = Color3.fromRGB(196, 92, 28)
local YELLOW = Color3.fromRGB(245, 190, 30)
local DARK = Color3.fromRGB(46, 46, 50)
local STEEL = Color3.fromRGB(120, 126, 134)
local WOOD = Color3.fromRGB(176, 124, 74)
local WHITE = Color3.fromRGB(240, 240, 236)
local GROUND_Y = 1.55

-- The station's frame: at the ring's middle on the ground, facing out the cabin's front (-Z is the front).
local front = if board then board.CFrame.LookVector else Vector3.new(0, 0, -1)
front = Vector3.new(front.X, 0, front.Z).Unit
local origin = Vector3.new(zone.Position.X, GROUND_Y, zone.Position.Z)
local frame = CFrame.lookAt(origin, origin + front)

-- 1. The cabin's meshes go into storage.
local stash = ServerStorage:FindFirstChild("PlantTreesMap")
if stash then
	local keep = stash:FindFirstChild("RangerStation") or Instance.new("Folder")
	keep.Name = "RangerStation"
	keep.Parent = stash
	for _, part in station:GetChildren() do
		if part:IsA("MeshPart") and part.Name:match("^RangerStation_") and part.Name ~= "RangerStation_Glow" then
			part.Parent = keep
			table.insert(log, `stored {part.Name}`)
		end
	end
end

-- 2. The depot.
local old = station:FindFirstChild("SupplyDepot")
if old then
	old:Destroy()
end
local depot = Instance.new("Model")
depot.Name = "SupplyDepot"

local function part(name: string, size: Vector3, at: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = frame * at
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.CanTouch = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = depot
	return p
end

local function text(target: BasePart, words: string, color: Color3, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.PixelsPerStud = 25
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = words
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	label.TextColor3 = color
	label.Parent = gui
end

-- Where the shopkeeper stands, in the frame (the counter goes in front of them).
local keeperAt = if keeper then frame:PointToObjectSpace(keeper:GetPivot().Position) else Vector3.new(0, 0, 0)
local FLOOR = 3.0 - GROUND_Y -- the depot's floor top, where the shopkeeper's feet are
local L, D, H = 22, 11, 9.5 -- the container: length across, depth, height inside
local back = keeperAt.Z + 4 -- the back wall, just behind the shopkeeper
local mid = back - D / 2
local openZ = back - D -- the open front

-- Floor slab and the container: back wall, sides, roof and a lintel over the open front, with corrugation ribs.
part("Floor", Vector3.new(L + 2, FLOOR, D + 1), CFrame.new(0, FLOOR / 2, mid), Color3.fromRGB(150, 146, 140), Enum.Material.Concrete)
part("Back", Vector3.new(L, H, 0.6), CFrame.new(0, FLOOR + H / 2, back), ORANGE, Enum.Material.Metal)
for _, side in { -1, 1 } do
	part("Side", Vector3.new(0.6, H, D), CFrame.new(side * L / 2, FLOOR + H / 2, mid), ORANGE, Enum.Material.Metal)
	for k = 0, 8 do
		local z = back - 0.8 - k * (D - 1.6) / 8
		part("Rib", Vector3.new(0.3, H - 0.4, 0.35), CFrame.new(side * (L / 2 + 0.4), FLOOR + H / 2, z), RIB, Enum.Material.Metal, false)
	end
end
for k = 0, 14 do
	part("Rib", Vector3.new(0.35, H - 0.4, 0.3), CFrame.new(-L / 2 + 1 + k * (L - 2) / 14, FLOOR + H / 2, back + 0.4), RIB, Enum.Material.Metal, false)
end
part("Roof", Vector3.new(L + 0.6, 0.6, D + 0.6), CFrame.new(0, FLOOR + H + 0.3, mid), RIB, Enum.Material.Metal)
local lintel = part("Lintel", Vector3.new(L, 2.2, 0.6), CFrame.new(0, FLOOR + H - 1.1, openZ), ORANGE, Enum.Material.Metal)
text(lintel, "SUPPLY DEPOT", WHITE, Enum.NormalId.Front)
-- The doors swung open against the sides.
for _, side in { -1, 1 } do
	part("Door", Vector3.new(0.4, H - 0.4, L / 4), CFrame.new(side * (L / 2 + L / 8), FLOOR + H / 2, openZ - 0.3) * CFrame.Angles(0, math.rad(90), 0), ORANGE, Enum.Material.Metal)
end

-- The counter in front of the shopkeeper, with a till and a stack of planks.
local counterZ = keeperAt.Z - 3
part("Counter", Vector3.new(14, 3.8, 2.2), CFrame.new(0, FLOOR + 1.9, counterZ), WOOD, Enum.Material.WoodPlanks)
part("CounterTop", Vector3.new(14.6, 0.4, 2.8), CFrame.new(0, FLOOR + 4, counterZ), STEEL, Enum.Material.DiamondPlate)
part("Till", Vector3.new(1.6, 1.2, 1.2), CFrame.new(-4.5, FLOOR + 4.8, counterZ), DARK, Enum.Material.Metal, false)
for k = 0, 2 do
	part("Plank", Vector3.new(4.5, 0.4, 0.9), CFrame.new(4, FLOOR + 4.4 + k * 0.42, counterZ - 0.4 + (k % 2) * 0.6), WOOD, Enum.Material.WoodPlanks, false)
end

-- Shelves on the back wall: hard hats, paint cans, toolboxes.
for row, y in { FLOOR + 3.2, FLOOR + 6.2 } do
	part("Shelf", Vector3.new(L - 3, 0.3, 1.8), CFrame.new(0, y, back - 1.1), STEEL, Enum.Material.Metal, false)
	for k = 0, 6 do
		local x = -L / 2 + 3 + k * (L - 6) / 6
		local kind = (k + row) % 3
		if kind == 0 then -- a hard hat
			local hat = part("HardHat", Vector3.new(1.4, 0.9, 1.6), CFrame.new(x, y + 0.6, back - 1.1), YELLOW, Enum.Material.Plastic, false)
			hat.Shape = Enum.PartType.Ball
		elseif kind == 1 then -- a paint can
			local can = part("PaintCan", Vector3.new(1.1, 1, 1), CFrame.new(x, y + 0.7, back - 1.1) * CFrame.Angles(0, 0, math.rad(90)), if k % 2 == 0 then WHITE else Color3.fromRGB(60, 110, 200), Enum.Material.Metal, false)
			can.Shape = Enum.PartType.Cylinder
		else -- a toolbox
			part("Toolbox", Vector3.new(1.8, 0.9, 0.9), CFrame.new(x, y + 0.6, back - 1.1), Color3.fromRGB(200, 40, 40), Enum.Material.Metal, false)
		end
	end
end
local lamp = part("Lamp", Vector3.new(4, 0.3, 0.6), CFrame.new(0, FLOOR + H - 0.4, mid), Color3.fromRGB(255, 244, 210), Enum.Material.Neon, false)
local light = Instance.new("PointLight")
light.Range = 18
light.Brightness = 1.4
light.Parent = lamp

-- The awning over the front with a hazard-striped edge.
local awningZ = openZ - 3
part("Awning", Vector3.new(L + 2, 0.4, 6.4), CFrame.new(0, FLOOR + H + 0.2, awningZ + 0.2) * CFrame.Angles(math.rad(-10), 0, 0), YELLOW, Enum.Material.Metal, false)
-- A flat fascia along the awning's front edge, striped yellow and black.
local stripes = 12
for k = 0, stripes - 1 do
	local width = (L + 2) / stripes
	part("Stripe", Vector3.new(width, 0.9, 0.25), CFrame.new(-(L + 2) / 2 + (k + 0.5) * width, FLOOR + H - 0.35, awningZ - 3.15), if k % 2 == 0 then YELLOW else DARK, Enum.Material.SmoothPlastic, false)
end
for _, side in { -1, 1 } do
	part("AwningPost", Vector3.new(0.5, H - 0.6, 0.5), CFrame.new(side * (L / 2 + 0.6), FLOOR + (H - 0.6) / 2, awningZ - 2.8), STEEL, Enum.Material.Metal)
end
-- The UPGRADES board goes up on the awning's front edge.
if board then
	board.CFrame = frame * CFrame.new(0, FLOOR + H + 2.6, awningZ - 3.2)
end

-- Crates, a pallet of plank bundles and cones beside the depot (outside the ring's middle).
for k, at in { Vector3.new(-L / 2 - 3.5, 0, openZ + 2), Vector3.new(-L / 2 - 3.5, 0, openZ + 5.5), Vector3.new(-L / 2 - 3.2, 3, openZ + 3.7) } do
	part("Crate", Vector3.new(3.2, 3, 3.2), CFrame.new(at.X, at.Y + 1.5, at.Z) * CFrame.Angles(0, math.rad(k * 9), 0), Color3.fromRGB(150, 104, 62), Enum.Material.WoodPlanks)
end
part("Pallet", Vector3.new(4.5, 0.6, 4.5), CFrame.new(L / 2 + 3.5, 0.3, openZ + 3), Color3.fromRGB(120, 86, 56), Enum.Material.Wood)
for layer = 0, 2 do
	part("Bundle", Vector3.new(4.2, 1, 4.2), CFrame.new(L / 2 + 3.5, 1.1 + layer, openZ + 3) * CFrame.Angles(0, math.rad(layer * 90), 0), WOOD, Enum.Material.WoodPlanks)
end
for _, x in { -L / 2 + 1, L / 2 - 1 } do -- traffic cones: a base and a tapering stack of discs with a white band
	part("ConeBase", Vector3.new(2.2, 0.25, 2.2), CFrame.new(x, 0.12, awningZ - 4.5), Color3.fromRGB(240, 110, 30), Enum.Material.Plastic, false)
	for k, w in { 1.4, 1.1, 0.8, 0.5 } do
		local disc = part("Cone", Vector3.new(0.7, w, w), CFrame.new(x, 0.25 + (k - 0.5) * 0.7, awningZ - 4.5) * CFrame.Angles(0, 0, math.pi / 2), if k == 3 then WHITE else Color3.fromRGB(240, 110, 30), Enum.Material.Plastic, false)
		disc.Shape = Enum.PartType.Cylinder
	end
end

depot.Parent = station
local count = 0
for _, d in depot:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
table.insert(log, `supply depot: {count} parts, facing {front}`)
return table.concat(log, "\n")
