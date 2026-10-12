-- build_farfield.luau: puts the canyon's far scenery in the map (tools/canyon_farfield.py, 2026-10-10). Not shipped.
-- Run it in the Edit datamodel through the Studio connection with the repo served on 127.0.0.1:34877 (fetch and
-- loadstring it). Loads the uploaded tiles (MODEL_ID, from tools/blender/build_farfield.py's FBX) and the color strip
-- (COLORS_IMAGE), places every tile from tools/canyon_out/farfield.json and keeps them in Workspace.Map.FarCanyon,
-- a Persistent model so every player always has the whole canyon (the terrain only loads near them). Safe to run again.
-- Save the place afterwards.
-- More maps (2026-10-11): set _G.FarPlace = "zion" first to build another map's far scenery (PLACES below) into its
-- stored map, ServerStorage.Maps.<Map>.FarCanyon, instead of the live one; the map swap moves it into Workspace.Map.

local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")

local PLACES = {
	grand = {
		model = 70525554318258, -- "Canyon Far Scenery v3" (2026-10-10): the river 10 studs higher (v2 97523121286902, v1 99072621223554)
		-- The color strip (tools/canyon_out/farfield_colors.png), one color per height, uploaded as an image for v3 (it was
		-- decal 96902156250519, read through InsertService; the first strip, 76092613884949, streaked).
		colors = "rbxassetid://77249289416370",
		json = "http://127.0.0.1:34877/tools/canyon_out/farfield.json",
		imports = { "FarCanyonImport" },
	},
	-- Zion (2026-10-11): two uploads, since one upload of all its tiles lost 292 of 1,212 (tools/blender/build_farfield.py):
	-- "Zion Far Scenery v3 part 1" 135668393616019 and "... part 2" 140154140504079 (606 tiles each, 2026-10-11: the
	-- flat far_floor shelves removed; v2 was 99060060541322 / 83067237414490), inserted with the Studio connection as
	-- ServerStorage.ZionFarImport and ZionFarImport2. Colors v2 (cream, salmon domes, pine forest above the rim): decal
	-- 89728495075067 (v1, all cream above the rim: 101813156188802 / 86605431075496).
	zion = {
		model = 135668393616019,
		colors = "rbxassetid://112267528967326",
		json = "http://127.0.0.1:34877/tools/zion_out/farfield.json",
		imports = { "ZionFarImport", "ZionFarImport2" },
		into = "Zion", -- ServerStorage.Maps.Zion
	},
	-- The Verdon Gorge (2026-10-11): 363 tiles in one upload, "Verdon Far Scenery v3", fitted to its walls (v2
	-- 115848049530345 sat up to 50 studs inside them; v1 71262516326488 had the narrow landing); colors "Verdon Far
	-- Colors v1", decal 92774166239830.
	verdon = {
		model = 136496843730667,
		colors = "rbxassetid://103014512805002",
		json = "http://127.0.0.1:34877/tools/verdon_out/farfield.json",
		imports = { "VerdonFarImport" },
		into = "Verdon",
	},
}
local PLACE = PLACES[_G.FarPlace or "grand"]
assert(PLACE, `no place {_G.FarPlace}`)
local MODEL_ID = PLACE.model
local COLORS_IMAGE = PLACE.colors
local JSON_URL = PLACE.json

local map = if PLACE.into then game:GetService("ServerStorage").Maps[PLACE.into] else workspace:WaitForChild("Map")

local texture = COLORS_IMAGE

local tiles: { [string]: MeshPart } = {}
-- InsertService:LoadAsset refuses freshly uploaded models ("not authorized"), so insert the model with the Studio
-- connection's insert tool first, as ServerStorage.FarCanyonImport; LoadAsset is the fallback.
local imports = {}
for _, name in PLACE.imports do
	local import = game:GetService("ServerStorage"):FindFirstChild(name)
	if import then
		table.insert(imports, import)
	end
end
if #imports == 0 then
	table.insert(imports, InsertService:LoadAsset(MODEL_ID))
end
for _, import in imports do
	for _, part in import:GetDescendants() do
		if part:IsA("MeshPart") then
			-- Without Blender's ".001" ending (it adds one when a tile of that name already exists in the file).
			tiles[(string.gsub(part.Name, "%.%d+$", ""))] = part
		end
	end
end

local old = map:FindFirstChild("FarCanyon")
if old then
	old:Destroy()
end
local far = Instance.new("Model")
far.Name = "FarCanyon"
far.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- always loaded: it's the canyon past the terrain

local placed, missing = 0, {}
for _, tile in HttpService:JSONDecode(HttpService:GetAsync(JSON_URL, true)) do
	local part = tiles[tile.name]
	if not part then
		table.insert(missing, tile.name)
		continue
	end
	local c = tile.center
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.CastShadow = false
	part.Material = Enum.Material.Sandstone -- matte like the terrain (SmoothPlastic caught shiny glints on the facets)
	part.Color = Color3.new(1, 1, 1)
	part.TextureID = texture
	part.RenderFidelity = Enum.RenderFidelity.Automatic -- lower detail with distance
	part.CollisionFidelity = Enum.CollisionFidelity.Box -- nothing touches or rays it: no detailed collision to keep
	part.CFrame = CFrame.new(c[1], c[2], c[3])
	part.Parent = far
	placed += 1
	if placed % 100 == 0 then
		task.wait() -- let Studio breathe (placing Zion's 933 tiles in one go timed the connection out)
	end
end
for _, import in imports do
	import:Destroy()
end
far.Parent = map

local result = `far scenery: {placed} tiles placed, texture {texture}`
if #missing > 0 then
	result ..= `, missing {#missing}: {table.concat(missing, ", ", 1, math.min(#missing, 5))}`
end
return result
