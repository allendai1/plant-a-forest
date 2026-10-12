-- build_landmarks.luau: a floating label on a real Grand Canyon landmark near Toroweap (2026-10-10, the user's ask).
-- Not shipped. Run it in the Edit datamodel through the Studio connection with the repo served on 127.0.0.1:34877
-- (fetch and loadstring it). Safe to run again: it rebuilds Workspace.Map.Landmarks.
--
-- The position comes from the real coordinates through the map's own transform (tools/canyon_heightmap.py Canyon: the
-- same turn, scale and squeeze as the terrain and far scenery), so the label stands over the real place: Vulcan's
-- Throne, 36.2189 N 113.0774 W (Wikipedia), the cinder cone 1.7 km west of the overlook, 1,555 m: in the far scenery
-- about 4,300 studs from camp, its top about 380 studs over the rim.
-- Lava Falls and Mount Trumbull had labels too, taken out the same day (the user's call: they implied players could go
-- there); their positions are in docs/notes/Visitable landmarks.md for when they can.
-- In the SOUTH RIM label's style (tools/build_canyon.luau), sized in studs so it shrinks with distance, and kept loaded
-- (a Persistent model). Not AlwaysOnTop: those didn't draw at all (checked on screen).

-- Zion (2026-10-11): set _G.LandmarkPlace = "zion" first to build its labels into ServerStorage.Maps.Zion.Landmarks.
-- Real coordinates through Zion's transform (CANYON_PLACE=zion): Angels Landing 37.2694 N 112.9476 W, the fin 1.7 km
-- up the canyon from the lodge, and the Great White Throne 37.2553 N 112.9419 W, the monolith behind camp. Their tops
-- are the far scenery's tile tops there.
local PLACES = {
	grand = { { "VULCAN'S THRONE", "volcano · 1,555 m", Vector3.new(3279, 380 + 220, -2695) } },
	zion = {
		into = "Zion",
		{ "ANGELS LANDING", "rock fin · 1,765 m", Vector3.new(-701, -734 + 200, 4524) },
		{ "GREAT WHITE THRONE", "monolith · 2,056 m", Vector3.new(854, 59 + 220, 1464) },
	},
	-- The Verdon Gorge (2026-10-11, CANYON_PLACE=verdon): La Mescla 43.738 N 6.365 E, where the Artuby meets the
	-- Verdon; the Pont de l'Artuby 43.7314 N 6.3784 E, the arch bridge over the Artuby's gorge; Point Sublime
	-- 43.7926 N 6.3976 E, the lookout at the gorge's upper end. Down in the gorge they'd hide behind its walls, so the
	-- labels float at rim height over them.
	verdon = {
		into = "Verdon",
		{ "LA MESCLA", "where two rivers meet", Vector3.new(-3660, 220, -7454) },
		{ "PONT DE L'ARTUBY", "arch bridge over the Artuby", Vector3.new(344, 220, -9227) },
		{ "POINT SUBLIME", "the gorge's great lookout", Vector3.new(785, 260, 15560) },
	},
}
local PLACE = PLACES[_G.LandmarkPlace or "grand"]
assert(PLACE, `no place {_G.LandmarkPlace}`)

local map = workspace:WaitForChild("Map")
local home = if PLACE.into then game:GetService("ServerStorage").Maps[PLACE.into] else map
local old = home:FindFirstChild("Landmarks")
if old then
	old:Destroy()
end
local landmarks = Instance.new("Model")
landmarks.Name = "Landmarks"
landmarks.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

local CAMP = Vector3.new(0, 0, 0)
local COLOR = Color3.fromRGB(255, 196, 92) -- warm, to tell them from the blue SOUTH RIM label
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)

-- A label over `at`: the name and a smaller line under it, sized for its distance from camp (200 studs wide per 3,000
-- away, a little smaller on screen than the SOUTH RIM label).
local function label(name: string, note: string, at: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = name
	anchor.Size = Vector3.one
	anchor.Position = at
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
	anchor.Transparency = 1
	anchor.Parent = landmarks
	local width = 200 * (at - CAMP).Magnitude / 3000
	local board = Instance.new("BillboardGui")
	board.Name = "Label"
	board.Size = UDim2.new(width, 150, width * 0.36, 54)
	board.LightInfluence = 0
	board.MaxDistance = 60000
	board.Parent = anchor
	local function line(text: string, y: number, height: number, color: Color3)
		for _, layer in { { "Shadow", Color3.new(0, 0, 0), 0.04, 1 }, { "Face", color, 0, 2 } } do
			local t = Instance.new("TextLabel")
			t.Name = layer[1] :: string
			t.Size = UDim2.fromScale(1, height)
			t.Position = UDim2.fromScale(0, y + (layer[3] :: number))
			t.BackgroundTransparency = 1
			t.Text = text
			t.TextScaled = true
			t.FontFace = FONT
			t.TextColor3 = layer[2] :: Color3
			t.ZIndex = layer[4] :: number
			t.Parent = board
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 2.5
			stroke.Parent = t
		end
	end
	line(name, 0, 0.5, COLOR)
	line(note, 0.5, 0.28, Color3.new(1, 1, 1))
	line("▼", 0.8, 0.2, COLOR)
end

-- Positions (studs) from tools/canyon_heightmap.py's transform; heights are the ground there.
for _, mark in ipairs(PLACE) do
	label(mark[1], mark[2], mark[3])
end

landmarks.Parent = home
return `landmarks: {#landmarks:GetChildren()} parts`
