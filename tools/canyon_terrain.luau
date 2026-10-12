-- canyon_terrain.luau: writes the canyon's terrain from tools/canyon_out/heightmap.txt (tools/canyon_heightmap.py,
-- 2026-10-10: the real Toroweap stretch of the Grand Canyon, reshaped for the bridge). Not shipped.
-- Run it in the Edit datamodel through the Studio connection with the repo served on 127.0.0.1:34877 (fetch and
-- loadstring it, like tests/TargetingCheck.luau). Each run works for about BUDGET seconds and returns its progress;
-- run it again until it says "done". The first run clears the terrain. Then run tools/build_canyon.luau for the rest
-- of the map, and save the place.
--
-- Every 4-stud column is solid from its surface (the heightmap, bilinear) down to SHELL studs under the lowest of its
-- neighbors, so cliff faces are closed but the inside of the plateaus stays empty (lighter terrain). Rock layers go by
-- height (the Grand Canyon's strata, wobbling a little), flat tops are dusty ground, the gorge floor is sand and the
-- river is water up to the heightmap's river line.
--
-- More maps (2026-10-11): set _G.CanyonPlace = "zion" before the first run to build another place from its own heightmap
-- (tools/canyon_heightmap.py with CANYON_PLACE) with its own rock layers and colors (PLACES below); default "grand".

local HttpService = game:GetService("HttpService")

local RES = 4 -- terrain voxel size
local CHUNK = 16 -- columns per chunk side
local SHELL = 16 -- studs of rock under the lowest neighbor
local BUDGET = 20 -- seconds per run
local FLAT = 0.45 -- slope (rise over run) under which a top is "flat"

-- From the rim down: material, color, thickness in studs (the last one goes all the way down). Sized for the
-- canyon's ~2,000-stud depth (tools/canyon_heightmap.py V_SCALE 2.6).
local PLACES = {
	grand = { -- Toroweap, the Grand Canyon (sized for its ~2,000-stud depth, V_SCALE 2.6)
		url = "http://127.0.0.1:34877/tools/canyon_out/heightmap.txt",
		bands = {
			{ Enum.Material.Limestone, Color3.fromRGB(226, 202, 160), 110 }, -- Kaibab: the pale rim
			{ Enum.Material.Sandstone, Color3.fromRGB(222, 170, 112), 150 }, -- Coconino: the tan cliff
			{ Enum.Material.Mud, Color3.fromRGB(176, 88, 58), 190 }, -- Hermit shale: red slopes
			{ Enum.Material.Pavement, Color3.fromRGB(166, 76, 52), 370 }, -- the Supai group: red ledges (CrackedLava drew black)
			{ Enum.Material.Rock, Color3.fromRGB(170, 112, 82), 350 }, -- Redwall limestone, stained red
			{ Enum.Material.Slate, Color3.fromRGB(110, 98, 84), 330 }, -- Tonto: the greenish-grey platform
			{ Enum.Material.Basalt, Color3.fromRGB(62, 54, 56), math.huge }, -- Vishnu schist: the dark inner gorge
		},
		ground = Color3.fromRGB(198, 166, 120),
		aboveRim = Enum.Material.Mud, -- the red Moenkopi slopes over the rim's limestone (the far side's high ground)
		floor = { Enum.Material.Sand, Color3.fromRGB(212, 176, 128), 12 }, -- near the river: material, color, studs over it
		water = Color3.fromRGB(70, 120, 100),
	},
	-- Zion at Zion Lodge (2026-10-11; ~2,350 studs deep, V_SCALE 3.6): nearly all Navajo sandstone, cream-white at the
	-- top going salmon then deep red lower down, the purple-red Kayenta ledges near the bottom, and a green valley floor
	-- (cottonwoods and meadows) along a jade river.
	zion = {
		url = "http://127.0.0.1:34877/tools/zion_out/heightmap.txt",
		bands = {
			{ Enum.Material.Sandstone, Color3.fromRGB(238, 226, 204), 520 }, -- upper Navajo: cream and white
			{ Enum.Material.Limestone, Color3.fromRGB(232, 168, 126), 620 }, -- middle Navajo: salmon
			{ Enum.Material.Rock, Color3.fromRGB(192, 88, 58), 560 }, -- lower Navajo: deep red, iron-stained
			{ Enum.Material.Mud, Color3.fromRGB(150, 72, 66), 300 }, -- Kayenta: purple-red ledges
			{ Enum.Material.Pavement, Color3.fromRGB(168, 104, 76), math.huge }, -- Moenave: the valley's base
		},
		ground = Color3.fromRGB(214, 194, 160), -- slickrock on the plateaus
		aboveRim = Enum.Material.Sandstone,
		floor = { Enum.Material.Grass, Color3.fromRGB(104, 138, 66), 60 },
		water = Color3.fromRGB(88, 140, 118),
	},
	-- The Verdon Gorge (2026-10-11; ~1,950 studs deep, V_SCALE 4.0): sheer limestone, bright white at the top, then grey
	-- streaked with ochre and orange lower down, olive scrub (garrigue) on the plateaus, wooded hills above the rim, a
	-- green strip of trees along the bottom and the famous jade-green water.
	verdon = {
		url = "http://127.0.0.1:34877/tools/verdon_out/heightmap.txt",
		bands = {
			{ Enum.Material.Limestone, Color3.fromRGB(238, 234, 224), 480 }, -- the white upper cliffs
			{ Enum.Material.Rock, Color3.fromRGB(200, 194, 182), 520 }, -- pale grey
			{ Enum.Material.Sandstone, Color3.fromRGB(214, 176, 132), 260 }, -- ochre-streaked
			{ Enum.Material.Slate, Color3.fromRGB(176, 166, 150), 420 }, -- grey-beige
			{ Enum.Material.Pavement, Color3.fromRGB(150, 140, 126), math.huge }, -- the gorge's foot
		},
		ground = Color3.fromRGB(128, 134, 86), -- olive garrigue on the plateaus
		aboveRim = Enum.Material.Grass, -- the wooded hills behind the far rim
		aboveRimColor = Color3.fromRGB(96, 116, 64),
		floor = { Enum.Material.LeafyGrass, Color3.fromRGB(86, 120, 62), 120 }, -- wooded banks
		water = Color3.fromRGB(56, 170, 150),
	},
}
local PLACE = PLACES[_G.CanyonPlace or "grand"]
assert(PLACE, `no place {_G.CanyonPlace}`)
local URL = PLACE.url
local BANDS = PLACE.bands
local TOP = 0.4
local ROAD_MATERIAL = Enum.Material.Salt -- used only by the road, so it can have its own color
local ROAD_COLOR = Color3.fromRGB(138, 112, 86)
local ABOVE_RIM = 50 -- ground this far above the rim is red slope, not limestone

local state = _G.CanyonTerrain
if not state then
	local text = HttpService:GetAsync(URL, true)
	local newline = string.find(text, "\n", 1, true) :: number
	local header = string.split(string.sub(text, 1, newline - 1), " ")
	local nx, nz = tonumber(header[1]) :: number, tonumber(header[2]) :: number
	local x0, z0, step = tonumber(header[3]) :: number, tonumber(header[4]) :: number, tonumber(header[5]) :: number
	local riverY = tonumber(header[6]) :: number
	local rest = string.sub(text, newline + 1)
	local second = string.find(rest, string.char(10), 1, true) -- the line break before the road line
	local data = if second then string.sub(rest, 1, second - 1) else rest
	local roadText = if second then string.sub(rest, second + 1) else ""
	assert(#data == nx * nz * 4, `heightmap: {#data} hex digits, expected {nx * nz * 4}`)
	-- Line 3: the road (one digit per sample, 0 off it .. 9 on it; tools/canyon_heightmap.py ROAD).
	local road = table.create(nx * nz, 0)
	if #roadText == nx * nz then
		for i = 1, nx * nz do
			road[i] = (string.byte(roadText, i) - 48) / 9
		end
	end
	local heights = table.create(nx * nz)
	for i = 1, nx * nz do
		heights[i] = (tonumber(string.sub(data, i * 4 - 3, i * 4), 16) :: number - 32768) / 4
	end
	local cols = math.floor((nx - 1) * step / RES)
	local rows = math.floor((nz - 1) * step / RES)
	state = {
		nx = nx,
		nz = nz,
		x0 = x0,
		z0 = z0,
		step = step,
		riverY = riverY,
		road = road,
		heights = heights,
		cols = cols,
		rows = rows,
		chunksX = math.ceil(cols / CHUNK),
		chunksZ = math.ceil(rows / CHUNK),
		next = 1,
		voxels = 0,
	}
	_G.CanyonTerrain = state
	workspace.Terrain:Clear()
	for _, band in BANDS do
		workspace.Terrain:SetMaterialColor(band[1], band[2])
	end
	workspace.Terrain:SetMaterialColor(Enum.Material.Ground, PLACE.ground)
	workspace.Terrain:SetMaterialColor(PLACE.floor[1], PLACE.floor[2])
	if PLACE.aboveRimColor then
		workspace.Terrain:SetMaterialColor(PLACE.aboveRim, PLACE.aboveRimColor)
	end
	workspace.Terrain:SetMaterialColor(ROAD_MATERIAL, ROAD_COLOR)
	workspace.Terrain.WaterColor = PLACE.water
end

local heights, nx, nz, step = state.heights, state.nx, state.nz, state.step

-- The heightmap's height at a world (x, z), bilinear.
-- How much the road covers (x, z), 0..1, bilinear like the heights.
local function roadAt(x: number, z: number): number
	local road = state.road
	local fx = math.clamp((x - state.x0) / step, 0, nx - 1.001)
	local fz = math.clamp((z - state.z0) / step, 0, nz - 1.001)
	local i, j = math.floor(fx), math.floor(fz)
	local tx, tz = fx - i, fz - j
	local a, b = road[j * nx + i + 1], road[j * nx + i + 2]
	local c, d = road[(j + 1) * nx + i + 1], road[(j + 1) * nx + i + 2]
	return (a * (1 - tx) + b * tx) * (1 - tz) + (c * (1 - tx) + d * tx) * tz
end

local function heightAt(x: number, z: number): number
	local fx = math.clamp((x - state.x0) / step, 0, nx - 1.001)
	local fz = math.clamp((z - state.z0) / step, 0, nz - 1.001)
	local i, j = math.floor(fx), math.floor(fz)
	local tx, tz = fx - i, fz - j
	local a = heights[j * nx + i + 1]
	local b = heights[j * nx + i + 2]
	local c = heights[(j + 1) * nx + i + 1]
	local d = heights[(j + 1) * nx + i + 2]
	return (a * (1 - tx) + b * tx) * (1 - tz) + (c * (1 - tx) + d * tx) * tz
end

-- The rock layer at height y, its boundaries wobbling a little across the map.
local function bandAt(y: number, x: number, z: number): Enum.Material
	local depth = TOP - y + 5 * math.sin(x * 0.011 + z * 0.003) + 3 * math.sin(z * 0.017)
	if depth < -ABOVE_RIM then
		return PLACE.aboveRim
	end
	for _, band in BANDS do
		if depth < band[3] then
			return band[1]
		end
		depth -= band[3]
	end
	return BANDS[#BANDS][1]
end

local function writeChunk(ci: number, cj: number)
	local colX0 = (ci - 1) * CHUNK
	local colZ0 = (cj - 1) * CHUNK
	local w = math.min(CHUNK, state.cols - colX0)
	local d = math.min(CHUNK, state.rows - colZ0)
	if w <= 0 or d <= 0 then
		return
	end
	local baseX = state.x0 + colX0 * RES
	local baseZ = state.z0 + colZ0 * RES
	-- Surfaces of the chunk's columns plus a ring of neighbors (for the bottoms and the slopes).
	local surf = {}
	for i = 0, w + 1 do
		surf[i] = {}
		for k = 0, d + 1 do
			surf[i][k] = heightAt(baseX + (i - 0.5) * RES, baseZ + (k - 0.5) * RES)
		end
	end
	local lowY, highY = math.huge, -math.huge
	local bottoms, slopes = {}, {}
	for i = 1, w do
		bottoms[i], slopes[i] = {}, {}
		for k = 1, d do
			local s = surf[i][k]
			local low = math.min(s, surf[i - 1][k], surf[i + 1][k], surf[i][k - 1], surf[i][k + 1])
			local bottom = low - SHELL
			bottoms[i][k] = bottom
			slopes[i][k] = math.max(math.abs(surf[i + 1][k] - surf[i - 1][k]), math.abs(surf[i][k + 1] - surf[i][k - 1]))
				/ (2 * RES)
			lowY = math.min(lowY, bottom)
			highY = math.max(highY, s, if s < state.riverY then state.riverY else s)
		end
	end
	local y0 = math.floor(lowY / RES) * RES
	local y1 = math.ceil((highY + RES) / RES) * RES
	local ny = (y1 - y0) / RES
	local materials, occupancy = table.create(w), table.create(w)
	for i = 1, w do
		local mi, oi = table.create(ny), table.create(ny)
		materials[i], occupancy[i] = mi, oi
		local x = baseX + (i - 0.5) * RES
		for j = 1, ny do
			mi[j], oi[j] = table.create(d, Enum.Material.Air), table.create(d, 0)
		end
		for k = 1, d do
			local z = baseZ + (k - 0.5) * RES
			local s, bottom, slope = surf[i][k], bottoms[i][k], slopes[i][k]
			local flat = slope < FLAT
			for j = 1, ny do
				local vy = y0 + (j - 1) * RES -- the voxel's bottom
				if vy + RES <= bottom then
					continue
				elseif vy < s then
					local occ = math.clamp((s - vy) / RES, 0, 1)
					local material
					if s - vy < RES * 1.5 and roadAt(x, z) >= 0.5 then
						material = ROAD_MATERIAL -- the dirt road in (packed dirt, its own color)
					elseif flat and s - vy < RES * 1.5 then
						material = if s > -80
							then Enum.Material.Ground
							elseif s < state.riverY + PLACE.floor[3] then PLACE.floor[1]
							else bandAt(vy, x, z)
					else
						material = bandAt(vy, x, z)
					end
					mi[j][k], oi[j][k] = material, math.max(occ, 0.05)
					state.voxels += 1
				elseif vy < state.riverY then
					mi[j][k], oi[j][k] = Enum.Material.Water, 1
				end
			end
		end
	end
	local region = Region3.new(Vector3.new(baseX, y0, baseZ), Vector3.new(baseX + w * RES, y1, baseZ + d * RES))
	workspace.Terrain:WriteVoxels(region, RES, materials, occupancy)
end

local started = os.clock()
local total = state.chunksX * state.chunksZ
while state.next <= total and os.clock() - started < BUDGET do
	local index = state.next - 1
	writeChunk(index % state.chunksX + 1, index // state.chunksX + 1)
	state.next += 1
end
if state.next > total then
	_G.CanyonTerrain = nil
	return `done: {total} chunks, {state.voxels} solid voxels`
end
return `{state.next - 1} / {total} chunks ({math.round((state.next - 1) / total * 100)}%), run again`
