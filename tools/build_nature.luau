-- build_nature.luau: desert plants and rocks over the canyon's rims (2026-10-10, the user's ask: "add some nature, like
-- cactuses"). Not shipped. Run it in the Edit datamodel through the Studio connection with the repo served on
-- 127.0.0.1:34877 (fetch and loadstring it), after the terrain (tools/canyon_terrain.luau). Safe to run again: it
-- rebuilds Workspace.Map.Nature, the same every time (seeded).
--
-- Saguaro cacti, prickly pears and boulders, scattered on flat ground on both rims: not in camp, not on the road
-- (tools/canyon_out/road.json), not on the bridge's line or the far landing, not on slopes or the canyon floor. The
-- prickly pears don't collide. (Sage bushes and junipers went on 2026-10-10, the user's call: the tries that grew them
-- now leave the spot empty, so the cacti and boulders stay as thick as before.)
-- The cacti are copies of the user's models (2026-10-10), kept in ServerStorage.NatureAssets: Saguaro (their "Cactus1",
-- one mesh) and PricklyPear (their 350-part "Prickly Pear Cactus" merged into one union, colors kept, so each copy is
-- one part; the originals are in NatureAssets.UserOriginals). The boulders are plain parts.
-- Zion (2026-10-11): set _G.NaturePlace = "zion" first, with Zion's terrain live, to build its plants into
-- ServerStorage.Maps.Zion.Nature: ponderosa and pinyon pines, junipers, sagebrush and red boulders on the rims,
-- cottonwoods and sagebrush on the green canyon floor along the river (2,400 studs down, seen from the bridge).

local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local natureAssets = ServerStorage:WaitForChild("NatureAssets")

local PLACES = {
	grand = {
		road = "http://127.0.0.1:34877/tools/canyon_out/road.json",
		areas = { -- x0, x1, z0, z1, how many tries, what grows
			{ -175, 800, -1900, 1900, 900, "desert" }, -- camp's side: its point and the ledges around it (no terrain past x 800)
			{ -4800, -3200, -1900, 1900, 700, "desert" }, -- the far (south) rim
		},
	},
	zion = {
		into = "Zion",
		road = "http://127.0.0.1:34877/tools/zion_out/road.json",
		areas = {
			{ -175, 800, -1900, 1900, 900, "forest" }, -- camp's (east) rim
			{ -4800, -3200, -1900, 1900, 700, "forest" }, -- the far (west) rim
			{ -2950, -800, -1950, 1950, 1400, "floor" }, -- the canyon floor
		},
	},
	-- The Verdon Gorge (2026-10-11): Aleppo pines, holm oaks, boxwood and lavender on the plateaus; holm oaks and
	-- boxwood clinging to the gorge's ledges (its white walls are dotted with them); green banks along the river.
	-- Its town (Moustiers, with its lavender field) spreads wider than the others: kept clear for 300 studs.
	verdon = {
		into = "Verdon",
		road = "http://127.0.0.1:34877/tools/verdon_out/road.json",
		floorY = -2000, -- its water at -2088
		landingClear = 300,
		areas = {
			{ -175, 800, -1900, 1900, 900, "garrigue" }, -- camp's (east) plateau
			{ -4800, -3200, -1900, 1900, 900, "garrigue" }, -- the far (west) side and its hills
			{ -3150, -200, -1950, 1950, 1600, "ledge" }, -- the gorge's walls
			{ -2300, -1300, -1950, 1950, 500, "banks" }, -- along the river
		},
	},
}
local PLACE = PLACES[_G.NaturePlace or "grand"]
assert(PLACE, `no place {_G.NaturePlace}`)

local map = workspace:WaitForChild("Map")
local home = if PLACE.into then ServerStorage.Maps[PLACE.into] else map
local CAMP = { X0 = -179.5, X1 = 172, Z0 = -220, Z1 = 150 } -- tools/build_canyon.luau CAMP
local RIM_X, FAR_X = -180, -3180
local CLEAR = { Camp = 8, Road = 10, Bridge = 70, Landing = 140 } -- Camp: right up to its barriers (tools/build_camp.luau)
local MAX_DROP = 700 -- the rims and the canyon's upper ledges, not its floor
local FLOOR_Y = PLACE.floorY or -2300 -- the floor is under this (Zion's water at -2404, tools/canyon_heightmap.py)
CLEAR.Landing = PLACE.landingClear or CLEAR.Landing
local MIN_UP = 0.88 -- only flat-ish ground (the surface normal's up part)

local road = HttpService:JSONDecode(HttpService:GetAsync(PLACE.road, true))
local roadHalf = road.half :: number

local old = home:FindFirstChild("Nature")
if old then
	old:Destroy()
end
local nature = Instance.new("Folder")
nature.Name = "Nature"

local rng = Random.new(1540) -- Cárdenas, the first European at the canyon: the same desert on every run
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?,
	collide: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Shape = shape or Enum.PartType.Block
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.CanQuery = collide == true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function shade(c: Color3, amount: number): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v * (1 + rng:NextNumber(-amount, amount)), 0, 1))
end

-- A copy of a NatureAssets model, scaled, turned to the ground point's yaw, its bottom `sink` studs into the ground.
local function plant(name: string, at: CFrame, scale: number, sink: number)
	local m = natureAssets[name]:Clone() :: Model
	m:ScaleTo(m:GetScale() * scale)
	local box, size = m:GetBoundingBox()
	local rel = box:ToObjectSpace(m:GetPivot())
	m:PivotTo(at * CFrame.new(0, size.Y / 2 - sink, 0) * rel)
	for _, part in m:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false -- walk through cacti (2026-10-11, the user's call)
		end
	end
	m.Parent = nature
end

local function saguaro(at: CFrame)
	plant("Saguaro", at, rng:NextNumber(0.9, 1.6), 0.6) -- 10 to 19 studs tall
end

local function pricklyPear(at: CFrame)
	plant("PricklyPear", at, rng:NextNumber(0.6, 1.05), 0.3) -- 3 to 6 studs tall
end

local function boulder(at: CFrame, base: Color3?, material: Enum.Material?)
	local m = Instance.new("Model")
	m.Name = "Boulder"
	local color = shade(base or Color3.fromRGB(176, 104, 72), 0.15)
	local stone = material or Enum.Material.Rock
	local size = rng:NextNumber(3, 9)
	part(
		m,
		"Rock",
		Vector3.new(size, size * rng:NextNumber(0.5, 0.8), size * rng:NextNumber(0.7, 1.1)),
		at
			* CFrame.new(0, size * 0.2, 0)
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.3), rng:NextNumber(-0.3, 0.3)),
		color,
		stone,
		Enum.PartType.Block,
		true
	)
	if rng:NextNumber() < 0.6 then
		local s = size * rng:NextNumber(0.35, 0.6)
		part(
			m,
			"Rock",
			Vector3.new(s, s * 0.7, s),
			at
				* CFrame.new(size * 0.55, s * 0.2, size * 0.2)
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.3), 0),
			shade(color, 0.1),
			stone,
			Enum.PartType.Block,
			true
		)
	end
	m.Parent = nature
end

-- Zion's (2026-10-11, models from tools/blender/build_zion_plants.py, "Zion Plants v1" 123184395624993, kept in
-- NatureAssets as Ponderosa1-3, Pinyon1-2, Juniper1-3, Cottonwood1-3 and Sagebrush1-2; the part-built pines, junipers
-- and cottonwoods before them looked ugly, the user's call): one of a species' shapes, scaled a little.
local function zionPlant(species: string, shapes: number, low: number, high: number)
	return function(at: CFrame)
		plant(`{species}{rng:NextInteger(1, shapes)}`, at, rng:NextNumber(low, high), 0.5)
	end
end
local ponderosa = zionPlant("Ponderosa", 3, 0.85, 1.15)
local pinyon = zionPlant("Pinyon", 2, 0.8, 1.2)
local juniper = zionPlant("Juniper", 3, 0.8, 1.3)
local cottonwood = zionPlant("Cottonwood", 3, 0.85, 1.2)
local sagebrush = zionPlant("Sagebrush", 2, 0.8, 1.4)
-- The Verdon's (tools/blender/build_verdon_plants.py, "Verdon Plants v1" 132132670899289).
local aleppo = zionPlant("Aleppo", 3, 0.85, 1.2)
local holmOak = zionPlant("HolmOak", 2, 0.8, 1.25)
local boxwood = zionPlant("Boxwood", 2, 0.8, 1.5)
local lavender = zionPlant("Lavender", 2, 0.9, 1.3)

local function redBoulder(at: CFrame)
	boulder(at, Color3.fromRGB(184, 86, 60), Enum.Material.Sandstone)
end

local function whiteBoulder(at: CFrame)
	boulder(at, Color3.fromRGB(222, 218, 206), Enum.Material.Limestone)
end

-- Is (x, z) somewhere a plant may go? Not in or by camp, the road, the bridge's line or the far landing.
local function clear(x: number, z: number): boolean
	if x > CAMP.X0 - CLEAR.Camp and x < CAMP.X1 + CLEAR.Camp and z > CAMP.Z0 - CLEAR.Camp and z < CAMP.Z1 + CLEAR.Camp then
		return false
	end
	if math.abs(z) < CLEAR.Bridge and (x < RIM_X + 40 and x > FAR_X - 40) then
		return false
	end
	if Vector2.new(x - (FAR_X - 60), z).Magnitude < CLEAR.Landing then
		return false
	end
	for _, p in road.points do
		if
			math.abs(p[1] - x) < roadHalf + CLEAR.Road + 10
			and Vector2.new(p[1] - x, p[2] - z).Magnitude < roadHalf + CLEAR.Road
		then
			return false
		end
	end
	return true
end

-- What grows where, by weight.
local function nothing(_at: CFrame) end -- where the bushes (34) and junipers (12) grew
local KINDS = {
	desert = { { saguaro, 18 }, { pricklyPear, 22 }, { nothing, 46 }, { boulder, 14 } },
	forest = { { ponderosa, 14 }, { pinyon, 14 }, { juniper, 22 }, { sagebrush, 26 }, { redBoulder, 10 }, { nothing, 24 } },
	floor = { { cottonwood, 55 }, { sagebrush, 25 }, { nothing, 20 } },
	garrigue = { { aleppo, 16 }, { holmOak, 16 }, { boxwood, 24 }, { lavender, 14 }, { whiteBoulder, 10 }, { nothing, 20 } },
	ledge = { { holmOak, 45 }, { boxwood, 45 }, { nothing, 10 } },
	banks = { { holmOak, 45 }, { boxwood, 30 }, { nothing, 25 } },
}
local function pick(kinds: { { any } })
	local total = 0
	for _, kind in kinds do
		total += kind[2]
	end
	local roll = rng:NextNumber() * total
	for _, kind in kinds do
		roll -= kind[2]
		if roll <= 0 then
			return kind[1]
		end
	end
	return nothing
end

local placed = 0
for _, area in PLACE.areas do
	local onFloor = area[6] == "floor" or area[6] == "banks"
	local onLedge = area[6] == "ledge" -- anywhere on the walls between the rim and the floor
	for _ = 1, area[5] do
		local x, z = rng:NextNumber(area[1], area[2]), rng:NextNumber(area[3], area[4])
		local make = pick(KINDS[area[6]])
		if clear(x, z) then
			local hit = workspace:Raycast(Vector3.new(x, 1500, z), Vector3.new(0, -5000, 0), params)
			local y = hit and hit.Position.Y
			local depthOk = if not y
				then false
				elseif onFloor then y < FLOOR_Y
				elseif onLedge then y < -40 and y > FLOOR_Y
				else y > -MAX_DROP
			if hit and depthOk and hit.Normal.Y >= MIN_UP and hit.Material ~= Enum.Material.Water then
				make(CFrame.new(hit.Position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
				placed += if make == nothing then 0 else 1
			end
		end
	end
end

nature.Parent = home
local parts = 0
for _, d in nature:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
return `nature: {placed} plants and rocks, {parts} parts`
