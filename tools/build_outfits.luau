--!nocheck
-- build_outfits: turns the imported outfit meshes (tools/blender/build_assets.py outfits(), uploaded as one
-- FBX) into Accessories in ReplicatedStorage.Assets.Outfits.<Ranger|Lord> (polish pass, 2026-10-07), plus the
-- catalog items in CATALOG.
-- Run in Edit with the meshes in ServerStorage.OutfitMeshes (the import of asset 138623917027942, renamed so
-- build_map's Import_ pickup leaves it alone); re-runnable. Each asset's biggest piece becomes the
-- Handle, the rest are welded to it, and the Handle gets the attachment named in ACCESSORIES at the asset's
-- _Origin marker (modeled at the avatar attachment point). OutfitService puts them on pass owners.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local IMPORT = "OutfitMeshes"

local ACCESSORIES = {
	{ outfit = "Ranger", asset = "RangerBadge", attachment = "BodyFrontAttachment" },
	{ outfit = "Ranger", asset = "RangerPack", attachment = "BodyBackAttachment" },
}
-- Piece name suffix -> color (the Blender PALETTE) and material.
local LOOK = {
	Band = { Color3.new(0.30, 0.19, 0.11) },
	Star = { Color3.new(1.0, 0.78, 0.25), Enum.Material.Metal },
	Bag = { Color3.new(0.50, 0.33, 0.18) }, -- leather, so it stands out from the ranger's olive trousers
	Roll = { Color3.new(0.62, 0.22, 0.15) },
}
-- Catalog items added to an outfit (chosen by the user, 2026-10-07): the Park Ranger shirt and pants, and the
-- Park Ranger Hat in place of the modeled RangerHat; the Lord of the Forest is all catalog (Druidic Helmet,
-- Royal Knight Cape Forest Guardian, Green Anime Cloak, a layered jacket). The modeled hat and Lord pieces are
-- still in OutfitMeshes, no longer used.
local CATALOG = {
	Ranger = { 6360872845, 6360874352, 12309127610 },
	Lord = { 112264404673495, 78153442307246, 14458613654 },
}

local import = ServerStorage:FindFirstChild(IMPORT)
assert(import, "import the outfits FBX first: " .. IMPORT)
local source = import:FindFirstChildWhichIsA("Model")
local assets = ReplicatedStorage:WaitForChild("Assets")
local outfits = assets:FindFirstChild("Outfits")
if outfits then
	outfits:Destroy()
end
outfits = Instance.new("Folder")
outfits.Name = "Outfits"

local log = {}
for _, def in ACCESSORIES do
	local model = source:FindFirstChild(def.asset)
	assert(model, def.asset)
	local origin = model:FindFirstChild(def.asset .. "_Origin")
	local pieces = {}
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= origin then
			table.insert(pieces, part:Clone())
		end
	end
	table.sort(pieces, function(a, b)
		return a.Size.Magnitude > b.Size.Magnitude
	end)
	local accessory = Instance.new("Accessory")
	accessory.Name = def.asset
	accessory.AccessoryType = Enum.AccessoryType.Unknown
	local handle = pieces[1]
	for i, part in pieces do
		local suffix = part.Name:match("_(%w+)$")
		local look = LOOK[suffix]
		if look then
			part.Color = look[1]
			part.Material = look[2] or Enum.Material.SmoothPlastic
		end
		part.Anchored = false
		part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
		part.Massless = true
		part.CastShadow = true
		if i == 1 then
			part.Name = "Handle"
			part.Parent = accessory
		else
			part.Parent = handle
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = handle, part
			weld.Parent = part
		end
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = def.attachment
	attachment.CFrame = handle.CFrame:Inverse() * CFrame.new(origin.Position)
	attachment.Parent = handle
	local folder = outfits:FindFirstChild(def.outfit)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = def.outfit
		folder.Parent = outfits
	end
	accessory.Parent = folder
	table.insert(log, `{def.outfit}.{def.asset}: {#pieces} pieces, {def.attachment}`)
end
for outfit, ids in CATALOG do
	local folder = outfits:FindFirstChild(outfit) or Instance.new("Folder")
	folder.Name = outfit
	folder.Parent = outfits
	for _, id in ids do
		local model = game:GetService("InsertService"):LoadAsset(id)
		for _, item in model:GetChildren() do
			item.Parent = folder
			table.insert(log, `{outfit}.{item.Name}: catalog {id}`)
		end
		model:Destroy()
	end
end
outfits.Parent = assets
return table.concat(log, "\n")
