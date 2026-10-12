-- build_builderman_stage.luau: a showcase stage for the Builderman pass's NPC (2026-10-11, the user's ask, after Build the
-- Pyramid's character stands: a raised stage, a gate with the name hanging from it, a glowing ring). Not shipped. Run it
-- in the Edit datamodel through the Studio connection. Safe to run again: it rebuilds Map.Model.BuildermanStage and
-- puts Builderman and his ring on top (it remembers where they stood on the ground in the stage's StandAt attribute).
--
-- Construction-themed: a round two-tier stage (steel base, concrete top, a glowing yellow trim) with a step at the
-- front, and behind him an archway of yellow I-beams with hazard stripes, a crossbeam with a hanging BUILDERMAN board
-- and two work lights aimed at him.

local model = workspace.Map.Model
local npc = model:FindFirstChild("Builderman") :: Model
local ring = model:FindFirstChild("RangerRing") :: Model?
assert(npc, "no Map.Model.Builderman")
local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart

local FLOOR = 1.55 -- the camp's floor (RimFloor's top)
local RADIUS = 7.5 -- the stage's top
local HEIGHT = 1.2 -- how far he goes up
local ARCH_WIDTH = 15 -- between the columns' centers
local ARCH_HEIGHT = 15
local ARCH_BACK = 3 -- the arch stands this far behind him
local SCALE = 0.8 -- the whole stage, built at the sizes above, is scaled by this round his feet (the user: a bit smaller, 2026-10-11)
local YELLOW = Color3.fromRGB(245, 190, 30)
local STEEL = Color3.fromRGB(70, 74, 82)
local CONCRETE = Color3.fromRGB(190, 186, 178)
local HAZARD = "rbxassetid://135458992836001" -- tools/make_site_textures.py hazard stripes

-- Where he stood on the ground, and his root's height above it, from before the first run (kept on the stage).
local old = model:FindFirstChild("BuildermanStage")
local standAt = Vector3.new(root.Position.X, FLOOR, root.Position.Z)
local rootOffset = root.Position.Y - FLOOR
if old then
	standAt = old:GetAttribute("StandAt") :: Vector3
	rootOffset = old:GetAttribute("RootOffset") :: number
	old:Destroy()
end
local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
local frame = CFrame.lookAt(standAt, standAt + look) -- -Z: the way he faces; the arch stands behind him, at +Z

local stage = Instance.new("Model")
stage.Name = "BuildermanStage"
stage:SetAttribute("StandAt", standAt)
stage:SetAttribute("RootOffset", rootOffset)

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = stage
	return p
end

-- A cylinder lying flat (Roblox cylinders run along X).
local function disc(name: string, radius: number, thickness: number, y: number, color: Color3, material: Enum.Material): Part
	return part(name, Vector3.new(thickness, radius * 2, radius * 2), frame * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
end

-- The stage: steel base, glowing trim, concrete top; a step in front.
disc("Base", RADIUS + 0.8, HEIGHT * 0.5, HEIGHT * 0.25, STEEL, Enum.Material.DiamondPlate)
local trim = disc("Trim", RADIUS + 0.25, 0.18, HEIGHT * 0.5 + 0.09, YELLOW, Enum.Material.Neon)
trim.CanCollide = false
disc("Top", RADIUS, HEIGHT * 0.5, HEIGHT * 0.75, CONCRETE, Enum.Material.Concrete)
part("Step", Vector3.new(6, HEIGHT * 0.5, 2.4), frame * CFrame.new(0, HEIGHT * 0.25, -(RADIUS + 1.6)), STEEL, Enum.Material.DiamondPlate)

-- The arch: two I-beam columns (a web and two flanges) and a crossbeam, yellow with hazard-striped feet.
local function ibeam(name: string, length: number, cf: CFrame)
	-- cf: the beam's middle; its length runs along cf's Y.
	part(name .. "Web", Vector3.new(0.35, length, 1.3), cf, YELLOW, Enum.Material.Metal)
	part(name .. "FlangeA", Vector3.new(1.3, length, 0.25), cf * CFrame.new(0, 0, 0.6), YELLOW, Enum.Material.Metal)
	part(name .. "FlangeB", Vector3.new(1.3, length, 0.25), cf * CFrame.new(0, 0, -0.6), YELLOW, Enum.Material.Metal)
end
for _, side in { -1, 1 } do
	local x = side * ARCH_WIDTH / 2
	local cf = frame * CFrame.new(x, HEIGHT + ARCH_HEIGHT / 2, ARCH_BACK)
	ibeam(if side < 0 then "ColumnL" else "ColumnR", ARCH_HEIGHT, cf)
	local foot = part(if side < 0 then "FootL" else "FootR", Vector3.new(1.6, 2.4, 1.6), frame * CFrame.new(x, HEIGHT + 1.2, ARCH_BACK), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	for _, face in Enum.NormalId:GetEnumItems() do
		if face ~= Enum.NormalId.Top and face ~= Enum.NormalId.Bottom then
			local tex = Instance.new("Texture")
			tex.Texture = HAZARD
			tex.Face = face
			tex.StudsPerTileU, tex.StudsPerTileV = 2.4, 2.4
			tex.Parent = foot
		end
	end
end
ibeam("Cross", ARCH_WIDTH + 1.3, frame * CFrame.new(0, HEIGHT + ARCH_HEIGHT + 0.65, ARCH_BACK) * CFrame.Angles(0, 0, math.rad(90)))

-- The hanging board: two chains (thin dark bars) and a dark plank board with BUILDERMAN on its front.
local boardY = HEIGHT + ARCH_HEIGHT - 2.6
for _, side in { -1, 1 } do
	local chain = part("Chain", Vector3.new(0.15, 2.2, 0.15), frame * CFrame.new(side * 3.6, boardY + 2.0, ARCH_BACK), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
	chain.CanCollide = false
end
local board = part("Board", Vector3.new(9.5, 2.4, 0.3), frame * CFrame.new(0, boardY, ARCH_BACK), Color3.fromRGB(45, 32, 22), Enum.Material.Wood)
board.CanCollide = false
part("BoardFrameTop", Vector3.new(9.9, 0.25, 0.4), frame * CFrame.new(0, boardY + 1.3, ARCH_BACK), YELLOW, Enum.Material.Metal).CanCollide = false
part("BoardFrameBottom", Vector3.new(9.9, 0.25, 0.4), frame * CFrame.new(0, boardY - 1.3, ARCH_BACK), YELLOW, Enum.Material.Metal).CanCollide = false
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Front -- the board's -Z: the way he faces, toward the road
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 60
gui.LightInfluence = 0
gui.Parent = board
local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(0.96, 0.9)
label.Position = UDim2.fromScale(0.02, 0.05)
label.Font = Enum.Font.GothamBlack
label.TextScaled = true
label.Text = "BUILDERMAN"
label.TextColor3 = Color3.new(1, 1, 1)
label.Parent = gui
local stroke = Instance.new("UIStroke")
stroke.Thickness = 5
stroke.Color = Color3.new(0, 0, 0)
stroke.Parent = label
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(Color3.fromRGB(255, 228, 120), Color3.fromRGB(235, 140, 20))
gradient.Rotation = 90
gradient.Parent = label

-- Two work lights on the crossbeam, aimed down at him.
for _, side in { -1, 1 } do
	local at = frame * CFrame.new(side * 4.5, HEIGHT + ARCH_HEIGHT - 0.3, ARCH_BACK - 1)
	local target = frame * Vector3.new(0, HEIGHT + 3, 0)
	local lampCF = CFrame.lookAt(at.Position, target)
	local lamp = part("Lamp", Vector3.new(1.1, 0.8, 0.9), lampCF, Color3.fromRGB(35, 35, 38), Enum.Material.Metal)
	lamp.CanCollide = false
	local lens = part("Lens", Vector3.new(0.9, 0.6, 0.1), lampCF * CFrame.new(0, 0, -0.5), Color3.fromRGB(255, 244, 210), Enum.Material.Neon)
	lens.CanCollide = false
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = 50
	light.Range = 22
	light.Brightness = 2.5
	light.Color = Color3.fromRGB(255, 236, 190)
	light.Parent = lens
end

for _, p in stage:GetDescendants() do
	if p:IsA("BasePart") then
		p.CastShadow = p.Name ~= "Trim" and p.Name ~= "Lens"
	end
end
stage.WorldPivot = CFrame.new(standAt)
stage:ScaleTo(SCALE)
stage.Parent = model

-- Builderman and his ring up onto the stage.
npc:PivotTo(npc:GetPivot() + Vector3.new(0, FLOOR + HEIGHT * SCALE + rootOffset - root.Position.Y, 0))
if ring then
	ring:ScaleTo(SCALE)
	local ringCF, ringSize = ring:GetBoundingBox()
	ring:PivotTo(ring:GetPivot() + Vector3.new(0, FLOOR + HEIGHT * SCALE + ringSize.Y / 2 + 0.02 - ringCF.Position.Y, 0))
end
return `Builderman stage built at {standAt}; his root at y {root.Position.Y}`
