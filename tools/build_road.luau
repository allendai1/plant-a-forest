-- build_road.luau: another map's road past the terrain's edge (2026-10-11). Not shipped. Run it in the Edit datamodel
-- through the Studio connection with the repo served on 127.0.0.1:34877 (fetch and loadstring it), with
-- _G.RoadPlace = "zion". Builds ServerStorage.Maps.<Map>["Site/Road"] (MapService swaps it with the live Site.Road): a
-- copy of the live road's entrance sign (by the gate, where every map's road starts the same) and flat strips lying on
-- that map's far scenery along its own road (tools/<out>/road.json), like tools/build_site.luau's.

local HttpService = game:GetService("HttpService")

local PLACES = {
	zion = { into = "Zion", road = "http://127.0.0.1:34877/tools/zion_out/road.json" },
	verdon = { into = "Verdon", road = "http://127.0.0.1:34877/tools/verdon_out/road.json" },
}
local PLACE = PLACES[_G.RoadPlace]
assert(PLACE, `no place {_G.RoadPlace}`)

-- The template: the live road, or the Grand Canyon's stored one when another map is live.
local live = workspace.Map.Site:FindFirstChild("Road") or game:GetService("ServerStorage").Maps.GrandCanyon["Site/Road"]
local folder = game:GetService("ServerStorage").Maps[PLACE.into]
local old = folder:FindFirstChild("Site/Road")
if old then
	old:Destroy()
end
local road = live:Clone()
for _, strip in road:GetChildren() do
	if strip.Name == "Strip" then
		strip:Destroy()
	end
end
local template = live:FindFirstChild("Strip") :: BasePart

local data = HttpService:JSONDecode(HttpService:GetAsync(PLACE.road, true))
local points: { { number } } = data.points
local strips = 0
for i = 1, #points - 1 do
	local a, b = points[i], points[i + 1]
	if a[1] >= (data.terrainEndX :: number) - 16 then
		local p0 = Vector3.new(a[1], a[4] + 1.5, a[2])
		local p1 = Vector3.new(b[1], b[4] + 1.5, b[2])
		local strip = template:Clone()
		strip.Size = Vector3.new(data.half * 2, 3, (p1 - p0).Magnitude + 2)
		strip.CFrame = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.new(0, -1.5, 0)
		strip.Parent = road
		strips += 1
	end
end
road.Name = "Site/Road"
road.Parent = folder
return `{PLACE.into} road: {strips} strips past the terrain`
