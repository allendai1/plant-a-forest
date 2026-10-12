-- build_boundary.luau: the edge of the walkable world (2026-10-10, the user's call). Not shipped. Run it in the Edit
-- datamodel through the Studio connection with the repo served on 127.0.0.1:34877 (fetch and loadstring it), after
-- syncing GameConfig. Safe to run again: it rebuilds Workspace.Map.Boundary.
--
-- The terrain stops a little past GameConfig.Boundary's rectangle; beyond it the canyon is look-only scenery
-- (Workspace.Map.FarCanyon, no collision) and players fell through it. Invisible walls stand on the rectangle's four
-- sides, from deep in the canyon to well over the highest ground. They're Persistent so a player's device always has
-- the ones near them (the character's physics runs on the device), and the camera ignores them. Where the road leaves
-- the map, barricades close it. BoundaryController shows a banner near the walls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- A fresh copy: Studio keeps a required module between tool runs, so a changed GameConfig would otherwise be missed.
local GameConfig = require(ReplicatedStorage.Shared.GameConfig:Clone()) :: any
local edge = GameConfig.Boundary

local MAX = 2000 -- a part can be at most 2,048 studs on any side
local BOTTOM, TOP = -2500, 1500 -- under the river (about -2,330) to over the highest ground (about 1,060)
local THICK = 4

local map = workspace:WaitForChild("Map")
local old = map:FindFirstChild("Boundary")
if old then
	old:Destroy()
end
local boundary = Instance.new("Model")
boundary.Name = "Boundary"
boundary.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

local walls = 0
local function wall(a: Vector2, b: Vector2)
	local length = (b - a).Magnitude
	local pieces = math.ceil(length / MAX)
	local layers = math.ceil((TOP - BOTTOM) / MAX)
	local tall = (TOP - BOTTOM) / layers
	for i = 0, pieces - 1 do
		local p0 = a + (b - a) * (i / pieces)
		local p1 = a + (b - a) * ((i + 1) / pieces)
		local mid = (p0 + p1) / 2
		for k = 0, layers - 1 do
			local y = BOTTOM + tall * (k + 0.5)
			local part = Instance.new("Part")
			part.Name = "Wall"
			part.Size = Vector3.new(THICK, tall, (p1 - p0).Magnitude)
			part.CFrame = CFrame.lookAt(Vector3.new(mid.X, y, mid.Y), Vector3.new(p1.X, y, p1.Y))
			part.Anchored = true
			part.CanCollide = true
			part.CanQuery = false -- the camera and every raycast pass through
			part.CanTouch = false
			part.Transparency = 1
			part.CastShadow = false
			part.Parent = boundary
			walls += 1
		end
	end
end
local c00, c10 = Vector2.new(edge.X0, edge.Z0), Vector2.new(edge.X1, edge.Z0)
local c11, c01 = Vector2.new(edge.X1, edge.Z1), Vector2.new(edge.X0, edge.Z1)
wall(c00, c10)
wall(c10, c11)
wall(c11, c01)
wall(c01, c00)

-- Barricades across the road where it reaches the east wall (the road is 28 studs wide there, at z about 0).
local kit = ServerStorage:FindFirstChild("SiteAssets") and ServerStorage.SiteAssets:FindFirstChild("Kit")
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }
local barricades = 0
if kit then
	-- Lit barricades without sign boards: the kit's boards show blank grey from camp's side (checked on screen), and
	-- the banner says why the road stops.
	for _, spot in { { "RoadBarricadeWithLights", -12 }, { "RoadBarricadeWithLights", 0 }, { "RoadBarricadeWithLights", 12 } } do
		local template = kit:FindFirstChild(spot[1])
		local x, z = edge.X1 - 12, spot[2] :: number
		local hit = workspace:Raycast(Vector3.new(x, 500, z), Vector3.new(0, -1000, 0), params)
		if template and hit then
			local m = template:Clone() :: Model
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			-- Stand it on the road, its long side across the road (along Z), as the kit has it.
			local box, size = m:GetBoundingBox()
			local rel = box:ToObjectSpace(m:GetPivot())
			m:PivotTo(CFrame.new(x, hit.Position.Y + size.Y / 2, z) * rel)
			m.Parent = boundary
			barricades += 1
		end
	end
end

boundary.Parent = map
return `boundary: {walls} wall pieces, {barricades} road barricades`
