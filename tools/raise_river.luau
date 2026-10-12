-- raise_river.luau: brings the terrain's river up to the heightmap's river line without rebuilding the terrain
-- (2026-10-10, when canyon_heightmap.py RIVER_RISE lifted it 10 studs: stretches of the canyon floor had no water).
-- Not shipped. Run it in the Edit datamodel through the Studio connection with the repo served on 127.0.0.1:34877
-- (fetch and loadstring it); it works for about BUDGET seconds a call, so run it again until it says "done".
--
-- Water goes exactly where tools/canyon_terrain.luau lays it: voxels whose bottom is at or over the column's ground
-- (the heightmap, bilinear at the column's middle) and under the river line. The terrain is a shell (rock only near
-- the surface, empty inside), so water anywhere under the ground is wrong and goes back to empty (the first version of
-- this tool filled the shells' insides). Rock and ground aren't touched. Only the river's band of heights is read, over
-- the gorge.

local HttpService = game:GetService("HttpService")

local RES = 4
local CHUNK = 512 -- studs per chunk side
local BUDGET = 20 -- seconds a call
local X0, X1 = -3200, -160 -- the gorge, rim to rim (the river runs through it everywhere in the terrain's area)
local Z0, Z1 = -2000, 2000
local Y_FLOOR = -2400 -- under the canyon's lowest floor (about -2,348)

local state = _G.RaiseRiver
if not state then
	local text = HttpService:GetAsync("http://127.0.0.1:34877/tools/canyon_out/heightmap.txt", true)
	local newline = string.find(text, "\n", 1, true) :: number
	local header = string.split(string.sub(text, 1, newline - 1), " ")
	local nx, nz = tonumber(header[1]) :: number, tonumber(header[2]) :: number
	local rest = string.sub(text, newline + 1)
	local second = string.find(rest, "\n", 1, true)
	local data = if second then string.sub(rest, 1, second - 1) else rest
	local heights = table.create(nx * nz)
	for i = 1, nx * nz do
		heights[i] = (tonumber(string.sub(data, i * 4 - 3, i * 4), 16) :: number - 32768) / 4
	end
	state = {
		nx = nx,
		nz = nz,
		x0 = tonumber(header[3]) :: number,
		z0 = tonumber(header[4]) :: number,
		step = tonumber(header[5]) :: number,
		riverY = tonumber(header[6]) :: number,
		heights = heights,
		nextX = X0,
		nextZ = Z0,
		water = 0,
		emptied = 0,
		chunks = 0,
	}
	_G.RaiseRiver = state
end

-- The heightmap's height at a world (x, z), bilinear (tools/canyon_terrain.luau heightAt).
local function heightAt(x: number, z: number): number
	local nx, step, heights = state.nx, state.step, state.heights
	local fx = math.clamp((x - state.x0) / step, 0, nx - 1.001)
	local fz = math.clamp((z - state.z0) / step, 0, state.nz - 1.001)
	local i, j = math.floor(fx), math.floor(fz)
	local tx, tz = fx - i, fz - j
	local a, b = heights[j * nx + i + 1], heights[j * nx + i + 2]
	local c, d = heights[(j + 1) * nx + i + 1], heights[(j + 1) * nx + i + 2]
	return (a * (1 - tx) + b * tx) * (1 - tz) + (c * (1 - tx) + d * tx) * tz
end

local terrain = workspace.Terrain
local yTop = math.ceil(state.riverY / RES) * RES
local started = os.clock()
while state.nextX < X1 and os.clock() - started < BUDGET do
	local x, z = state.nextX, state.nextZ
	local region = Region3.new(Vector3.new(x, Y_FLOOR, z), Vector3.new(math.min(x + CHUNK, X1), yTop, math.min(z + CHUNK, Z1))):ExpandToGrid(RES)
	local materials, occupancy = terrain:ReadVoxels(region, RES)
	local size = materials.Size
	local low = region.CFrame.Position - region.Size / 2
	local changed = false
	for i = 1, size.X do
		local cx = low.X + (i - 0.5) * RES
		local mi, oi = materials[i], occupancy[i]
		for k = 1, size.Z do
			local s = heightAt(cx, low.Z + (k - 0.5) * RES)
			for j = 1, size.Y do
				local vy = low.Y + (j - 1) * RES -- the voxel's bottom
				local m = mi[j][k]
				if vy >= s and vy < state.riverY then
					if m == Enum.Material.Air then
						mi[j][k], oi[j][k] = Enum.Material.Water, 1
						state.water += 1
						changed = true
					end
				elseif vy < s and m == Enum.Material.Water then
					mi[j][k], oi[j][k] = Enum.Material.Air, 0
					state.emptied += 1
					changed = true
				end
			end
		end
	end
	if changed then
		terrain:WriteVoxels(region, RES, materials, occupancy)
	end
	state.chunks += 1
	state.nextZ += CHUNK
	if state.nextZ >= Z1 then
		state.nextZ = Z0
		state.nextX += CHUNK
	end
end

local progress = `{state.chunks} chunks, {state.water} voxels of open water added, {state.emptied} under the ground emptied`
if state.nextX >= X1 then
	_G.RaiseRiver = nil
	return `done: {progress}, river line y {state.riverY}`
end
return `working: {progress}; run again`
