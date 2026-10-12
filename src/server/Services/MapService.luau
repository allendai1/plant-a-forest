--!strict
-- MapService: which canyon's map is live (2026-10-11, the user's ask: other places, swapped in a running server).
-- Each map is a folder in ServerStorage.Maps (built in Studio by the tools/canyon_* scripts): a Terrain TerrainRegion
-- (the whole terrain), attributes for every material's color (Color_<Material>) and the water, the paste corner, and
-- the map's own pieces that sit on its ground (MAP_PARTS: far scenery, plants, landmarks...). The live map's pieces are
-- in Workspace.Map; Map.CurrentMap names it (the place is saved with the Grand Canyon live).
-- show() swaps behind a loading screen: ForestState MapLoading (the canyon's name, "" when done) tells clients to
-- cover the screen (MapLoadingController); everyone is held at spawn while the terrain is cleared and pasted, then for
-- SETTLE_SECONDS so their devices have the new ground around them. Measured in Studio: the swap itself about 2.4 s.
-- Its sky too (2026-10-11): a map folder's Lighting folder holds its Sky, Atmosphere and Clouds and, as attributes, its
-- LIGHT_PROPS. The live ones go back into the old map's Lighting folder (made the first time), so a map that was never
-- given its own keeps whatever the place was saved with.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local MapService = {}

-- Pieces of Workspace.Map that belong to one map's ground ("A/B" = B inside A). Each map's folder keeps its own under
-- the same path name; a map without one simply has none.
local MAP_PARTS = { "FarCanyon", "Nature", "Landmarks", "SouthRimLabel", "FarRimFlag", "Springtown", "Site/Road" }
local BRIDGE_SIGNS = { "Name", "NameBack" } -- the camp gateway's boards in Map.Site (tools/build_camp.luau)
local COVER_SECONDS = 0.6 -- the loading screen fades in before the world changes
local SETTLE_SECONDS = 3 -- held at spawn after the swap, while the new terrain reaches every device

local SKY: { [string]: string } = { Sky = "Lighting", Atmosphere = "Lighting", Clouds = "Terrain" } -- class: where it lives when live
local LIGHT_PROPS = { "ClockTime", "Brightness", "OutdoorAmbient", "ExposureCompensation" }

local busy = false

local function current(): string
	local map = workspace:FindFirstChild("Map")
	local name = map and map:GetAttribute("CurrentMap")
	return if typeof(name) == "string" then name else "GrandCanyon"
end

-- The instance at `path` ("A/B") under `root`, and its parent.
local function at(root: Instance, path: string): (Instance?, Instance?)
	local parent: Instance? = root
	local parts = string.split(path, "/")
	for i = 1, #parts - 1 do
		parent = parent and parent:FindFirstChild(parts[i])
	end
	return if parent then parent:FindFirstChild(parts[#parts]) else nil, parent
end

-- Every character held still at spawn (true) or let go (false).
local function hold(on: boolean)
	local pad = workspace:FindFirstChildWhichIsA("SpawnLocation")
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and root and root:IsA("BasePart") then
			if on and pad then
				root.AssemblyLinearVelocity = Vector3.zero
				character:PivotTo(pad.CFrame + Vector3.new(0, pad.Size.Y / 2 + 4, 0))
			end
			root.Anchored = on
		end
	end
end

local function swapTerrain(folder: Instance)
	local terrain = workspace.Terrain
	local region = folder:FindFirstChild("Terrain")
	local corner = folder:GetAttribute("Corner")
	if not (region and region:IsA("TerrainRegion") and typeof(corner) == "Vector3") then
		warn(`[MapService] {folder.Name} has no terrain`)
		return
	end
	terrain:Clear()
	terrain:PasteRegion(region, Vector3int16.new(corner.X, corner.Y, corner.Z), true)
	for key, value in folder:GetAttributes() do
		local material = string.match(key, "^Color_(.+)$")
		if material and typeof(value) == "Color3" then
			pcall(terrain.SetMaterialColor, terrain, (Enum.Material :: any)[material], value)
		end
	end
	for _, property in { "WaterColor", "WaterTransparency", "WaterReflectance" } do
		local value = folder:GetAttribute(property)
		if value ~= nil then
			(terrain :: any)[property] = value
		end
	end
end

-- Puts the old map's sky and light away into its folder and the new map's in.
local function swapSky(old: Instance?, folder: Instance)
	local Lighting = game:GetService("Lighting")
	local homes = { Lighting = Lighting, Terrain = workspace.Terrain } :: { [string]: Instance }
	local keep = old and old:FindFirstChild("Lighting")
	if old and not keep then
		local made = Instance.new("Folder")
		made.Name = "Lighting"
		made.Parent = old
		keep = made
	end
	local incoming = folder:FindFirstChild("Lighting")
	for class, home in SKY do
		local live = homes[home]:FindFirstChildOfClass(class)
		local new = incoming and incoming:FindFirstChildOfClass(class)
		if keep and live then
			live.Parent = keep
		end
		if new then
			new.Parent = homes[home]
		end
	end
	for _, property in LIGHT_PROPS do
		if keep then
			keep:SetAttribute(property, (Lighting :: any)[property])
		end
		local value = incoming and incoming:GetAttribute(property)
		if value ~= nil then
			(Lighting :: any)[property] = value
		end
	end
end

-- The camp's plank pile (Lobby.PlankPiles) in the map's building material (GameConfig.Decks, 2026-10-11): each plank
-- keeps a little brightness of its own, from where it lies.
local function dressPile(map: Instance, name: string)
	local lobby = map:FindFirstChild("Lobby")
	local pile = lobby and lobby:FindFirstChild("PlankPiles")
	if not pile then
		return
	end
	local look = GameConfig.deckFor(name)
	local h, s, v = look.Color:ToHSV()
	for _, plank in pile:GetDescendants() do
		if plank:IsA("BasePart") and plank.Name == "Plank" then
			local p = plank.Position
			local shade = 1 + math.noise(p.X * 0.37, p.Y * 0.71, p.Z * 0.53) * 0.25
			plank.Color = Color3.fromHSV(h, s, math.clamp(v * shade, 0, 1))
			plank.Material = look.Material
		end
	end
end

-- The camp gateway's sign names the canyon being bridged: "<LABEL> BRIDGE".
local function nameBridge(map: Instance, label: string)
	local site = map:FindFirstChild("Site")
	for _, board in BRIDGE_SIGNS do
		local part = site and site:FindFirstChild(board)
		if part then
			for _, d in part:GetDescendants() do
				if d:IsA("TextLabel") then
					d.Text = `{string.upper(label)} BRIDGE`
				end
			end
		end
	end
end

-- Swaps `name` (a ServerStorage.Maps folder) in for the live map right away: its pieces, terrain and sky, and the
-- camp's sign named for `label`. With `saveTerrain` (editing in Studio: tools/plugins/MapSwitcher.lua) the live terrain
-- is first copied back into the old map's folder, so terrain edits are kept. False when it's missing or already live.
function MapService.swap(name: string, label: string, saveTerrain: boolean?): boolean
	local maps = ServerStorage:FindFirstChild("Maps")
	local folder = maps and maps:FindFirstChild(name)
	local map = workspace:FindFirstChild("Map")
	if map then
		nameBridge(map, label)
		dressPile(map, if folder then name else current())
	end
	if name == current() or not (folder and map and maps) then
		return false
	end
	local old = maps:FindFirstChild(current())
	if saveTerrain and old then
		local terrain = workspace.Terrain
		local region = terrain:CopyRegion(terrain.MaxExtents)
		local stale = old:FindFirstChild("Terrain")
		if stale then
			stale:Destroy()
		end
		region.Name = "Terrain"
		region.Parent = old
		old:SetAttribute("Corner", Vector3.new(terrain.MaxExtents.Min.X, terrain.MaxExtents.Min.Y, terrain.MaxExtents.Min.Z))
	end
	for _, path in MAP_PARTS do
		local live = at(map, path)
		if live and old then
			live.Name = path
			live.Parent = old
		end
		local incoming = folder:FindFirstChild(path)
		local _, parent = at(map, path)
		if incoming and parent then
			incoming.Name = string.match(path, "[^/]+$") :: string
			incoming.Parent = parent
		end
	end
	swapTerrain(folder)
	swapSky(old, folder)
	map:SetAttribute("CurrentMap", name)
	print(`[MapService] {name} is live`)
	return true
end

-- Makes `name` the live map behind the loading screen, `label` shown on it and on the camp's sign. Only renames the
-- sign when the map is already live. Yields for the loading screen (a few seconds).
function MapService.show(name: string, label: string)
	if busy or name == current() then
		MapService.swap(name, label) -- just the sign
		return
	end
	busy = true
	local forestState = ReplicatedStorage:WaitForChild("ForestState")
	forestState:SetAttribute("MapLoading", label)
	task.wait(COVER_SECONDS)
	hold(true)
	MapService.swap(name, label)
	task.wait(SETTLE_SECONDS)
	hold(false)
	forestState:SetAttribute("MapLoading", "")
	busy = false
end

-- A server starts on the first canyon: if the place was saved with another map live (left switched in Studio), the
-- first canyon's comes back before anyone joins.
function MapService.init()
	local first = GameConfig.Tiers[1]
	MapService.swap(first.Map, first.Name)
end

function MapService.current(): string
	return current()
end

return MapService
