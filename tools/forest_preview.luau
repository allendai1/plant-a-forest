--!strict
-- forest_preview.luau: lays the forest's hex tiles into Workspace.ForestPreview so they can be seen in Studio's Edit
-- mode (2026-10-08, the user's ask; the real tiles are built by each client's ForestController at runtime). Run it in
-- the Edit datamodel. It finds the plots the way ForestService does (every hex in the forest rings that isn't under a
-- NoPlant volume and has ground under it, at that ground's height) and places each one's slab and border at the
-- current HexSize, as a fresh forest (all empty). Rerun after map or grid changes. ForestService deletes the folder
-- when a server starts, so players never load it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig:Clone()) -- Edit caches require; read the current file
local HexGrid = require(ReplicatedStorage.Shared.HexGrid:Clone())

local TEMPLATE_HEX_SIZE = 16 -- the Blender tile was modeled for HexSize 16 (ForestController)
local EMPTY_COLOR = Color3.fromRGB(150, 103, 64) -- an empty plot's slab (ForestController OPEN_COLOR)

local grid = GameConfig.Grid
local center = CollectionService:GetTagged("ForestCenter")[1] :: BasePart
local tile = ReplicatedStorage.Assets.Tiles.HexTile
local scale = grid.HexSize / TEMPLATE_HEX_SIZE

local noPlant: { BasePart } = {}
for _, inst in CollectionService:GetTagged(grid.NoPlantTag) do
	if inst:IsA("BasePart") then
		table.insert(noPlant, inst)
	end
end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local exclude: { Instance } = { center }
for _, part in noPlant do
	table.insert(exclude, part)
end
for _, floor in CollectionService:GetTagged("WalkFloor") do
	table.insert(exclude, floor)
end
local old = workspace:FindFirstChild("ForestPreview")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "ForestPreview"
table.insert(exclude, folder)
params.FilterDescendantsInstances = exclude

local function place(template: BasePart, base: Vector3)
	local part = template:Clone()
	local rel = template.CFrame -- relative to the tile's pivot (its bottom center, at the origin)
	part.Size = template.Size * scale
	part.CFrame = CFrame.new(base) * (rel.Rotation + rel.Position * scale)
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Parent = folder
	return part
end

local count = 0
for i, ring in HexGrid.rings(grid.HubRings + grid.ForestRings) do
	if i - 1 <= grid.HubRings then
		continue
	end
	for _, hex in ring do
		local flat = HexGrid.toWorld(hex.q, hex.r, grid.HexSize, center.Position)
		local blocked = false
		for _, part in noPlant do
			local p = part.CFrame:PointToObjectSpace(flat)
			if math.abs(p.X) <= part.Size.X / 2 and math.abs(p.Z) <= part.Size.Z / 2 then
				blocked = true
				break
			end
		end
		local hit = if blocked then nil else workspace:Raycast(flat + Vector3.new(0, 500, 0), Vector3.new(0, -1000, 0), params)
		if hit and hit.Material ~= Enum.Material.Water then
			local base = Vector3.new(flat.X, hit.Position.Y, flat.Z)
			place(tile.HexTile_Slab :: BasePart, base).Color = EMPTY_COLOR
			place(tile.HexTile_Border :: BasePart, base)
			count += 1
		end
	end
end
folder.Parent = workspace
return `{count} tiles in Workspace.ForestPreview`
