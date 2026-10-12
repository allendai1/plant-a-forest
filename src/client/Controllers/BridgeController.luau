--!strict
-- BridgeController: the client's copy of the bridge (2026-10-10; replaced ForestController's trees and hex tiles).
-- Builds every slot from the GetForest snapshot and applies HexBatch updates (a plot is a slot, seeds are planks; the
-- remote names stayed). A slot shows its planks as they arrive: Grid.PlanksPerSlot planks laid across the bridge, one
-- more for each share of the slot's planks, each dropping in with a puff of sawdust. A finished slot swaps its loose
-- planks for one deck you can walk on (fewer parts: a full bridge has 2,400 slots) and, on the edge columns, a dark steel
-- edge girder with an LED strip, a glass railing and now and then a street lamp. A finished row adds its piece of the
-- structure under the bridge: a concrete deck beam and its stretch of the twin concrete arch ribs (GameConfig.Grid.Arch,
-- after the Hoover Dam Bypass over the Colorado), with slender columns up to the deck: the arch grows out across the
-- canyon as the bridge does. Only the slot you're aiming at is highlighted (TargetController; every open slot had its
-- own pulsing outline until 2026-10-10, the user's call). When a row is finished a golden sweep runs across it with a
-- rising chime, and every 20th row a banner. Answers slot lookups for TargetController.
-- Zion's bridge is a suspension bridge instead (2026-10-11, the user's ask: a different structure per map; SUSPENSION):
-- steel towers on both rims, main cables sagging across that grow out row by row, hangers and a steel box girder.
-- The Verdon Gorge's is cable-stayed, after the Millau Viaduct (STAYED): tall white piers from the gorge's floor, a
-- pylon over each one on both edges and fans of stay cables down to the deck.
-- Conveyor belts (GameConfig.Grid.Belts): the finished rows' decks in two lanes move whoever stands on them, out toward
-- the far rim or back to camp, at one speed set by the built length (at least Belts.MinSpeed); one beam of arrows
-- scrolls down each lane at that speed (updateBeltArrows). Their speeds are recomputed whenever the bridge's end moves. Each client moves its own character, so belts can be client-side.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local BridgeGrid = require(Shared.BridgeGrid)
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)
local Targeting = require(Shared.Targeting)
local Types = require(Shared.Types)
local HUD = require(script.Parent.HUD)
local Sounds = require(script.Parent.Parent.Sounds)

-- Look (visual only, not balance numbers).
-- Each bridge's deck: GameConfig.Decks, by the live map (concrete, steel plates or asphalt since 2026-10-11; wood before).
local function deckLook(): GameConfig.Deck
	local map = workspace:FindFirstChild("Map")
	return GameConfig.deckFor(map and map:GetAttribute("CurrentMap"))
end
local PLANK_SHADE = 0.12 -- each plank's brightness varies by up to this much
local PLANK_THICK = 0.8
local PLANK_GAP = 0.18 -- between neighboring planks along the bridge
local PLANK_TRIM = 0.3 -- planks stop this short of the slot's sides, so slots read as slots
local PLANK_DROP = 3 -- a new plank drops in from this high
local PLANK_DROP_SECONDS = 0.18
-- The structure (2026-10-10, the user's ask for a modern bridge; it was the Navajo Bridge's steel lattice until then):
-- after the Hoover Dam Bypass over the Colorado (the Mike O'Callaghan-Pat Tillman Memorial Bridge), twin concrete arch
-- ribs with slender concrete columns up to a solid deck beam, a dark steel box girder along each edge with an LED strip,
-- glass railings under a steel handrail, and street lamps. The deck stays the planks the players build.
local CONCRETE_COLOR = Color3.fromRGB(212, 208, 200)
local FASCIA_COLOR = Color3.fromRGB(56, 60, 68) -- the edge girders and lamp poles
local LED_COLOR = Color3.fromRGB(190, 236, 255)
local LAMP_COLOR = Color3.fromRGB(255, 246, 226)
local GLASS_COLOR = Color3.fromRGB(176, 220, 236)
local GLASS_TRANSPARENCY = 0.55
local STEEL_COLOR = Color3.fromRGB(196, 200, 204) -- handrails and posts
local RIB_WIDTH = 10 -- each arch rib's width (its depth is GameConfig.Grid.Arch RibEnd at the rims, RibCrown mid-span)
local COLUMN_THICK = 6
local COLUMN_EVERY = 4 -- rows between the columns from the ribs up to the deck (and the struts between the ribs)
local DECK_BEAM = 4 -- the concrete deck beam's depth under a finished row's planks
local FASCIA = Vector2.new(1.6, 4.4) -- the edge girder: width, height; its top is a curb CURB over the deck
local CURB = 0.3
local RAIL_HEIGHT = 3.6
local HANDRAIL = 0.35
local LAMP_EVERY = 4 -- rows between street lamps (on both edges)
local LAMP_HEIGHT = 12
local GOLD_COLOR = Color3.fromRGB(255, 205, 70)
-- Zion's suspension bridge (after the Royal Gorge Bridge, over a canyon as deep): dark green steel towers on the rims,
-- the main cables hung between their tops, dipping to Sag over the deck mid-span, backstays down to anchor blocks
-- Backstay studs behind each tower (camp's close in, clear of the gym), a hanger down to the deck edge every HangerEvery rows, and a steel box girder
-- under the deck instead of the arch. Which map gets it: Workspace.Map CurrentMap (MapService).
-- The Verdon Gorge's cable-stayed bridge, after France's Millau Viaduct: four white concrete piers rising from the
-- gorge's floor (two segments: a Part can be at most 2,048 long), each splitting into two legs under the deck, a white
-- pylon over each pier on both edges of the deck, and from each pylon a fan of FAN stays every STEP studs each way down to
-- the deck's edge. A pier and its pylons go up with the row they stand in; a stay when both its row and its pylon are.
local STAYED = {
	Map = "Verdon",
	Concrete = Color3.fromRGB(236, 234, 228),
	Stay = Color3.fromRGB(244, 244, 240),
	Girder = 6,
	Piers = { 375, 1125, 1875, 2625 }, -- studs from the near rim
	PierDown = 2150, -- down past the gorge's floor
	PierSize = Vector2.new(30, 50), -- along the bridge, across it (massive, like Millau's; the base wider still)
	LegsFrom = 140, -- under the deck, where a pier splits into its two legs
	Pylon = 150, -- the pylons' tops over the deck
	PylonSize = Vector2.new(9, 6),
	Fan = 8,
	Step = 40,
	StayLow = 70, -- the nearest stay leaves its pylon this high; the furthest at the top
	StayThick = 1.2,
}
local SUSPENSION = {
	Map = "Zion",
	Steel = Color3.fromRGB(44, 88, 80),
	Footing = Color3.fromRGB(196, 186, 170),
	TowerHeight = 260, -- the towers' tops over the deck
	TowerLeg = 9,
	TowerDown = 90, -- the legs go this far under the deck (into the rim)
	Beams = { 40, 130, 210 }, -- cross beams between each tower's legs, over the deck (the top has one too)
	Sag = 12, -- the cables' lowest point over the deck, mid-span
	Cable = 3,
	Hanger = 0.7,
	HangerEvery = 2,
	Girder = 7, -- the box girder's depth under the deck
	Backstay = { 24, 90 }, -- near (camp: clear of the gym) and far
}
-- The belt lanes are moving walkways: dark rubber with yellow safety stripes down both sides (tools/make_site_textures.py
-- belt_edges, image 80968322934467).
local BELT_COLOR = Color3.fromRGB(52, 54, 60)
local BELT_EDGES = "rbxassetid://80968322934467"
-- The belts' arrows: one beam down each lane scrolling at the belt's speed (updateBeltArrows), one bold chevron every
-- BELT_ARROW_SPACING studs (tools/make_site_textures.py belt_arrow, drawn 7:5 like BELT_ARROW_WIDTH by
-- BELT_ARROW_SPACING so it isn't stretched). The guide arrow's tall chevron
-- strip before 2026-10-10 looked squished and small (the user's note).
local BELT_ARROWS = "rbxassetid://113161677219145"
local BELT_ARROW_SPACING = 5
local BELT_ARROW_WIDTH = 7
local BELT_ARROW_MIN = 1 -- belts slower than this (studs/s) show no arrows
local BELT_ARROW_LIFT = 0.08 -- the arrows' height over the deck
local DUST_COLORS = ColorSequence.new(Color3.fromRGB(214, 180, 130), Color3.fromRGB(160, 118, 76))
local DUST_PUFF = 8
local FINISH_DUST = 24
local CHIME_ID = "rbxasset://sounds/electronicpingshort.wav" -- placeholder until there's real audio
local CHIME_NOTES = { 1, 1.26, 1.5 }
local CHIME_NOTE_GAP = 0.12
local SWEEP_SECONDS = 0.5 -- the row moment's golden sweep runs across the row in this long
local BANNER_EVERY = 20 -- rows between "N studs across!" banners
local RETRY_SECONDS = 5

export type Plot = {
	index: number,
	q: number,
	r: number,
	ring: number,
	base: Vector3, -- slot center at deck height
	frame: CFrame, -- the slot's center, turned like the bridge (LookVector across the canyon)
	seeds: number,
	species: number,
	mutation: number,
	starterUserId: number,
	treeSeed: number,
	planks: { BasePart }, -- the loose planks shown while unfinished, rim side first
	finished: Instance?, -- the deck, beams and rails, once finished
	deck: BasePart?, -- the finished deck (in `finished`)
}

local BridgeController = {}

local plots: { Plot } = {}
local byKey: { [string]: number } = {}
local center = Vector3.zero -- the hub's center (ForestState Center)
local bridgeFrame = CFrame.identity
local openRing = 0 -- the open row (0 when the bridge is done)
local lastRing = 0 -- the round's last row (ForestState LastRing; 0 = every row is in this bridge)
local seedsPerHex = GameConfig.Tiers[1].SeedsPerHex -- planks per slot (ForestState SeedsPerHex)
local snapshotSeq: number? = nil -- nil until the snapshot has been applied
local pending: { Types.HexBatch } = {}
local view: Folder
local dustPart: Part
local dustEmitter: ParticleEmitter
local chime: Sound
local beltTurn = CFrame.identity -- turns the arrow attachments so the beam lies flat (TargetController's guideTurn)
local rowSteel: { [number]: Folder } = {} -- the deck beam, arch ribs, columns and struts of each finished row

function BridgeController.ready(): boolean
	return snapshotSeq ~= nil
end

-- The hub's center (the tutorial and the guide arrow measure from it).
function BridgeController.center(): Vector3
	return center
end

-- The BridgeStart frame (BridgeGrid).
function BridgeController.frame(): CFrame
	return bridgeFrame
end

function BridgeController.groundY(): number
	return bridgeFrame.Position.Y
end

function BridgeController.plotAt(q: number, r: number): Plot?
	local index = byKey[BridgeGrid.key(q, r)]
	return if index then plots[index] else nil
end

function BridgeController.allPlots(): { Plot }
	return plots
end

local function isGrownAt(q: number, r: number): boolean
	local plot = BridgeController.plotAt(q, r)
	return plot ~= nil and plot.seeds >= seedsPerHex
end

local function inRound(plot: Plot): boolean
	return lastRing == 0 or plot.ring <= lastRing
end

-- The open row, and the slots just past its finished ones (Targeting.isOpenPlot, the server's rule).
function BridgeController.isOpenPlot(plot: Plot): boolean
	if not inRound(plot) then
		return false
	end
	return Targeting.isOpenPlot(
		plot.q,
		plot.r,
		plot.ring,
		plot.seeds >= seedsPerHex,
		openRing,
		GameConfig.Grid.AheadRings,
		isGrownAt
	)
end

function BridgeController.isOpen(q: number, r: number): boolean
	local plot = BridgeController.plotAt(q, r)
	return plot ~= nil and BridgeController.isOpenPlot(plot)
end

-- Planks drawn for `seeds` of the slot's planks: at least one once started, all of them only when finished.
local function planksFor(seeds: number): number
	local total = GameConfig.Grid.PlanksPerSlot
	if seeds <= 0 then
		return 0
	elseif seeds >= seedsPerHex then
		return total
	end
	return math.clamp(math.floor(seeds / seedsPerHex * total), 1, total - 1)
end

-- Where plank `i` (1 = the rim side) of a slot lies, and its size.
function BridgeController.plankAt(plot: Plot, i: number): (CFrame, Vector3)
	local grid = GameConfig.Grid
	local pitch = grid.SlotStuds / grid.PlanksPerSlot
	local along = grid.SlotStuds / 2 - (i - 0.5) * pitch
	local cframe = plot.frame * CFrame.new(0, -PLANK_THICK / 2, -along)
	return cframe, Vector3.new(grid.SlotStuds - PLANK_TRIM, PLANK_THICK, pitch - PLANK_GAP)
end

-- The planks the next press would add to the slot (for TargetController's ghost), or 0 when it's full.
function BridgeController.nextPlank(plot: Plot): number
	local shown = planksFor(plot.seeds)
	return if shown >= GameConfig.Grid.PlanksPerSlot then 0 else shown + 1
end

local function makePart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function puff(position: Vector3, count: number)
	dustPart.Position = position
	dustEmitter:Emit(count) -- particles stay in the world, so the part can move on to the next puff
end

local function chimeNote(speed: number, volume: number?)
	local note = chime:Clone()
	note.PlaybackSpeed = speed
	note.Volume = volume or chime.Volume
	note.Parent = SoundService -- not in a part, so it plays at full volume wherever you are
	note:Play()
	Debris:AddItem(note, 2)
end

-- The arch at distance `s` along the bridge from the near rim: the top of its ribs (studs below the deck, negative) and
-- how deep the ribs are there.
local function archAt(s: number): (number, number)
	local grid = GameConfig.Grid
	local arch = grid.Arch
	local t = math.clamp(s / (grid.Rows * grid.SlotStuds), 0, 1)
	local bow = 4 * t * (1 - t) -- 0 at the rims, 1 in the middle
	return -arch.Depth + (arch.Depth - arch.Crown) * bow, arch.RibCrown + (arch.RibEnd - arch.RibCrown) * (1 - bow)
end

-- A concrete box from a to b (bridge-local points), `width` wide and `tall` tall, in the world.
local function concrete(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, tall: number, color: Color3?): Part
	local wa, wb = bridgeFrame:PointToWorldSpace(a), bridgeFrame:PointToWorldSpace(b)
	local steel = color ~= nil
	return makePart(
		name,
		Vector3.new(width, tall, (wb - wa).Magnitude),
		CFrame.lookAt((wa + wb) / 2, wb),
		color or CONCRETE_COLOR,
		if steel then Enum.Material.Metal else Enum.Material.Concrete,
		parent
	)
end

-- The live map's bridge: "Suspension", "Stayed" or "Arch".
local function structure(): string
	local map = workspace:FindFirstChild("Map")
	local name = map and map:GetAttribute("CurrentMap")
	return if name == SUSPENSION.Map then "Suspension" elseif name == STAYED.Map then "Stayed" else "Arch"
end

local function suspended(): boolean
	return structure() == "Suspension"
end

-- The main cables' height over the deck at distance `s` from the near rim (a parabola between the towers' tops).
local function cableAt(s: number): number
	local grid = GameConfig.Grid
	local t = math.clamp(s / (grid.Rows * grid.SlotStuds), 0, 1)
	return SUSPENSION.Sag + (SUSPENSION.TowerHeight - SUSPENSION.Sag) * (1 - 4 * t * (1 - t))
end

-- Row `r`'s piece of the suspension bridge: the box girder under its deck, both main cables' stretch over it and every
-- HangerEvery rows a hanger from each cable down to the deck's edge.
local function buildRowSuspension(r: number, folder: Folder)
	local grid = GameConfig.Grid
	local S = grid.SlotStuds
	local s0, s1 = (r - 1) * S, r * S
	local half = grid.Columns * S / 2
	local girderY = -PLANK_THICK - SUSPENSION.Girder / 2
	concrete(
		folder,
		"Girder",
		Vector3.new(0, girderY, -s0),
		Vector3.new(0, girderY, -s1),
		half * 2 - FASCIA.X * 2,
		SUSPENSION.Girder,
		SUSPENSION.Steel
	)
	for _, side in { -1, 1 } do
		local x = side * (half + SUSPENSION.Cable / 2 + 0.5)
		concrete(
			folder,
			"Cable",
			Vector3.new(x, cableAt(s0), -s0),
			Vector3.new(x, cableAt(s1), -s1),
			SUSPENSION.Cable,
			SUSPENSION.Cable,
			SUSPENSION.Steel
		)
		if r % SUSPENSION.HangerEvery == 0 and cableAt(s1) - CURB > 2 then
			concrete(
				folder,
				"Hanger",
				Vector3.new(x, cableAt(s1), -s1),
				Vector3.new(x, CURB, -s1),
				SUSPENSION.Hanger,
				SUSPENSION.Hanger,
				SUSPENSION.Steel
			)
		end
	end
end

-- The suspension bridge's towers on both rims (with their backstays and anchor blocks), there from the start; none on
-- the arch bridge's maps.
local towers: Folder? = nil
local function updateTowers()
	if towers then
		towers:Destroy()
		towers = nil
	end
	if not suspended() then
		return
	end
	local grid = GameConfig.Grid
	local half = grid.Columns * grid.SlotStuds / 2
	local span = grid.Rows * grid.SlotStuds
	local T = SUSPENSION
	local folder = Instance.new("Folder")
	folder.Name = "Towers"
	for i, at in { { -6, 1 }, { span + 6, -1 } } do -- s, and which way is back onto land (-s is out over the canyon)
		local s, back = at[1], at[2]
		local legX = half + T.TowerLeg / 2 + 3
		for _, side in { -1, 1 } do
			local x = side * legX
			concrete(
				folder,
				"Leg",
				Vector3.new(x, -T.TowerDown, -s),
				Vector3.new(x, T.TowerHeight + 6, -s),
				T.TowerLeg,
				T.TowerLeg,
				T.Steel
			)
			concrete(folder, "Footing", Vector3.new(x, -4, -s - 7), Vector3.new(x, -4, -s + 7), T.TowerLeg + 6, 10)
			-- The backstay: the cable goes on over the tower's top and down to its anchor block on the land behind.
			local cableX = side * (half + T.Cable / 2 + 0.5)
			local anchor = Vector3.new(side * (half + 14), 2, -(s - back * T.Backstay[i]))
			concrete(folder, "Backstay", Vector3.new(cableX, T.TowerHeight, -s), anchor, T.Cable, T.Cable, T.Steel)
			concrete(folder, "Anchor", anchor - Vector3.new(0, 3, back * 6), anchor - Vector3.new(0, 3, -back * 6), 12, 10)
		end
		for _, y in { T.Beams[1], T.Beams[2], T.Beams[3], T.TowerHeight + 3 } do
			concrete(
				folder,
				"Beam",
				Vector3.new(-legX, y, -s),
				Vector3.new(legX, y, -s),
				T.TowerLeg * 0.8,
				T.TowerLeg * 0.8,
				T.Steel
			)
		end
	end
	folder.Parent = view
	towers = folder
end

-- The row at distance `s` from the near rim.
local function rowAt(s: number): number
	return math.max(1, math.ceil(s / GameConfig.Grid.SlotStuds))
end

-- A stay from pier `p`'s pylons (both edges) down to the deck at distance `a` along the bridge.
local function buildStay(p: number, a: number, folder: Instance)
	local grid = GameConfig.Grid
	local half = grid.Columns * grid.SlotStuds / 2
	local ps = STAYED.Piers[p]
	local reach = math.abs(a - ps) / (STAYED.Fan * STAYED.Step) -- 0 near the pylon, 1 at the fan's end
	local y = STAYED.StayLow + (STAYED.Pylon - 4 - STAYED.StayLow) * reach
	for _, side in { -1, 1 } do
		local x = side * (half + STAYED.PylonSize.Y / 2 + 1)
		concrete(
			folder,
			"Stay",
			Vector3.new(x, y, -ps),
			Vector3.new(side * (half + 0.3), CURB, -a),
			STAYED.StayThick,
			STAYED.StayThick,
			STAYED.Stay
		)
	end
end

-- Pier `p` (into `folder`): its two-part shaft from the gorge's floor, its two legs up under the deck, a cross beam
-- there, and its pylon on each edge of the deck.
local function buildPier(p: number, folder: Instance)
	local grid = GameConfig.Grid
	local half = grid.Columns * grid.SlotStuds / 2
	local T = STAYED
	local ps = T.Piers[p]
	local under = -PLANK_THICK - T.Girder
	local mid = (-T.PierDown - T.LegsFrom) / 2
	concrete(
		folder,
		"Pier",
		Vector3.new(0, -T.PierDown, -ps),
		Vector3.new(0, mid, -ps),
		T.PierSize.Y * 1.3,
		T.PierSize.X * 1.3,
		T.Concrete
	)
	concrete(folder, "Pier", Vector3.new(0, mid, -ps), Vector3.new(0, -T.LegsFrom, -ps), T.PierSize.Y, T.PierSize.X, T.Concrete)
	for _, side in { -1, 1 } do
		concrete(
			folder,
			"PierLeg",
			Vector3.new(0, -T.LegsFrom, -ps),
			Vector3.new(side * half * 0.7, under, -ps),
			T.PierSize.Y * 0.4,
			T.PierSize.X * 0.7,
			T.Concrete
		)
		local x = side * (half + T.PylonSize.Y / 2 + 1)
		concrete(
			folder,
			"Pylon",
			Vector3.new(x, under, -ps),
			Vector3.new(x, T.Pylon, -ps),
			T.PylonSize.Y,
			T.PylonSize.X,
			T.Concrete
		)
	end
	concrete(
		folder,
		"PierBeam",
		Vector3.new(-half * 0.7, under - 3, -ps),
		Vector3.new(half * 0.7, under - 3, -ps),
		6,
		6,
		T.Concrete
	)
end

-- Row `r`'s piece of the cable-stayed bridge: its steel girder; the pier (and pylons) standing in it; the stays anchored
-- on it whose pylon is up; and, with a new pier, the stays to the rows behind it already finished.
local function buildRowStayed(r: number, folder: Folder)
	local grid = GameConfig.Grid
	local S = grid.SlotStuds
	local s0, s1 = (r - 1) * S, r * S
	local half = grid.Columns * S / 2
	local girderY = -PLANK_THICK - STAYED.Girder / 2
	concrete(
		folder,
		"Girder",
		Vector3.new(0, girderY, -s0),
		Vector3.new(0, girderY, -s1),
		half * 2 - FASCIA.X * 2,
		STAYED.Girder,
		STAYED.Concrete
	)
	local function done(row: number): boolean
		return row == r or (rowSteel[row] :: Folder?) ~= nil
	end
	for p, ps in STAYED.Piers do
		local pierRow = rowAt(ps)
		for k = 1, STAYED.Fan do
			for _, dir in { -1, 1 } do
				local a = ps + dir * k * STAYED.Step
				local anchorRow = rowAt(a)
				if anchorRow == r and done(pierRow) then
					buildStay(p, a, folder)
				elseif pierRow == r and anchorRow ~= r and rowSteel[anchorRow] then
					buildStay(p, a, rowSteel[anchorRow] :: Folder) -- kept with its anchor's row
				end
			end
		end
		if pierRow == r then
			buildPier(p, folder)
		end
	end
end

-- Row `r`'s structure under its deck: the concrete deck beam across the row, its stretch of both arch ribs (tilted with
-- the arch, deeper toward the rims), and every COLUMN_EVERY rows a column from each rib up to the deck beam and a strut
-- across between the ribs. In bridge-local space: X across, Y up, -Z out across the canyon.
local function buildRowSteel(r: number)
	local grid = GameConfig.Grid
	local arch = grid.Arch
	local S = grid.SlotStuds
	local s0, s1 = (r - 1) * S, r * S
	local top0, depth0 = archAt(s0)
	local top1, depth1 = archAt(s1)
	local ribX = grid.Columns * S / 2 - arch.RibInset
	local folder = Instance.new("Folder")
	folder.Name = `Steel{r}`
	local kind = structure()
	if kind ~= "Arch" then
		if kind == "Suspension" then
			buildRowSuspension(r, folder)
		else
			buildRowStayed(r, folder)
		end
		folder.Parent = view
		rowSteel[r] = folder
		return
	end
	local beamBottom = -PLANK_THICK - DECK_BEAM
	local beamY = beamBottom + DECK_BEAM / 2
	concrete(
		folder,
		"DeckBeam",
		Vector3.new(0, beamY, -s0),
		Vector3.new(0, beamY, -s1),
		grid.Columns * S - FASCIA.X * 2,
		DECK_BEAM
	)
	local column = r % COLUMN_EVERY == 0 and beamBottom - top1 > 1
	for _, side in { -1, 1 } do
		local x = side * ribX
		concrete(
			folder,
			"Rib",
			Vector3.new(x, top0 - depth0 / 2, -s0),
			Vector3.new(x, top1 - depth1 / 2, -s1),
			RIB_WIDTH,
			(depth0 + depth1) / 2
		)
		if column then
			concrete(folder, "Column", Vector3.new(x, top1, -s1), Vector3.new(x, beamBottom, -s1), COLUMN_THICK, COLUMN_THICK)
		end
	end
	if r % COLUMN_EVERY == 0 then
		concrete(folder, "Strut", Vector3.new(-ribX, top1 - 1.5, -s1), Vector3.new(ribX, top1 - 1.5, -s1), 2.4, 2.4)
	end
	folder.Parent = view
	rowSteel[r] = folder
end

-- A row's steel goes up once every slot in it is finished, and comes down when a new bridge empties it.
local function refreshRowSteel(r: number)
	local complete = true
	for q = 1, GameConfig.Grid.Columns do
		local plot = BridgeController.plotAt(q, r)
		if not plot or plot.seeds < seedsPerHex then
			complete = false
			break
		end
	end
	if complete and not rowSteel[r] then
		buildRowSteel(r)
	elseif not complete and rowSteel[r] then
		rowSteel[r]:Destroy()
		rowSteel[r] = nil
	end
end

-- The deck you walk on and, on the bridge's outer sides, the edge girder, its LED strip, the glass railing and a lamp.
local function buildFinished(plot: Plot)
	local grid = GameConfig.Grid
	local folder = Instance.new("Folder")
	folder.Name = "Done"
	local s = grid.SlotStuds
	local edge = if plot.q == 1 then -1 elseif plot.q == grid.Columns then 1 else 0
	local shade = 1 + (Random.new(plot.treeSeed + plot.index):NextNumber() * 2 - 1) * PLANK_SHADE * 0.5
	local belts = grid.Belts
	local isBelt = plot.q == belts.Out or plot.q == belts.Back
	local look = deckLook()
	local h, sat, v = (if isBelt then BELT_COLOR else look.Color):ToHSV()
	-- On an edge slot the deck stops at the edge girder's inner face: running the slot's full width put its outer side in
	-- the girder's outer face's plane, and the two flickered (2026-10-11, the user's report).
	local inset = if edge ~= 0 then FASCIA.X else 0
	-- A belt is Belts.Width slots wide (2026-10-11, the user's ask: 50% wider), over the edges of the decks beside it and
	-- a hair higher, so whoever stands on its overhang rides it too.
	local wide = if isBelt then s * (belts.Width - 1) else 0
	local deck = makePart(
		"Deck",
		Vector3.new(s - inset + wide, PLANK_THICK, s),
		plot.frame * CFrame.new(-edge * inset / 2, -PLANK_THICK / 2 + (if isBelt then 0.04 else 0), 0),
		Color3.fromHSV(h, sat, math.clamp(v * shade, 0, 1)),
		if isBelt then Enum.Material.Rubber else look.Material,
		folder
	)
	if isBelt then
		local stripes = Instance.new("Texture")
		stripes.Texture = BELT_EDGES
		stripes.Face = Enum.NormalId.Top
		stripes.StudsPerTileU, stripes.StudsPerTileV = s + wide, s
		stripes.Parent = deck
	end
	deck.CanCollide = true
	deck.CanQuery = true -- the camera and raycasts see the deck
	plot.deck = deck
	if edge ~= 0 then
		-- The edge girder (its top a curb over the deck), an LED strip along its outer face, the glass railing on it under a
		-- steel handrail, a post at the slot's end, and every LAMP_EVERY rows a street lamp leaning over the deck.
		local x = edge * (s / 2 - FASCIA.X / 2)
		local trim = if suspended() then SUSPENSION.Steel else FASCIA_COLOR
		makePart(
			"Fascia",
			Vector3.new(FASCIA.X, FASCIA.Y, s),
			plot.frame * CFrame.new(x, CURB - FASCIA.Y / 2, 0),
			trim,
			Enum.Material.Metal,
			folder
		)
		local led = makePart(
			"Led",
			Vector3.new(0.2, 0.3, s),
			plot.frame * CFrame.new(edge * (s / 2 + 0.1), CURB - FASCIA.Y + 0.7, 0),
			LED_COLOR,
			Enum.Material.Neon,
			folder
		)
		led.CastShadow = false
		local glass = makePart(
			"Glass",
			Vector3.new(0.25, RAIL_HEIGHT - 0.3, s - 0.3),
			plot.frame * CFrame.new(x, CURB + (RAIL_HEIGHT - 0.3) / 2, 0),
			GLASS_COLOR,
			Enum.Material.Glass,
			folder
		)
		glass.Transparency = GLASS_TRANSPARENCY
		glass.CastShadow = false
		local handrail = makePart(
			"Handrail",
			Vector3.new(s, HANDRAIL, HANDRAIL),
			plot.frame * CFrame.new(x, CURB + RAIL_HEIGHT, 0) * CFrame.Angles(0, math.pi / 2, 0),
			STEEL_COLOR,
			Enum.Material.Metal,
			folder
		)
		handrail.Shape = Enum.PartType.Cylinder
		makePart(
			"Post",
			Vector3.new(0.3, RAIL_HEIGHT, 0.3),
			plot.frame * CFrame.new(x, CURB + RAIL_HEIGHT / 2, -s / 2),
			STEEL_COLOR,
			Enum.Material.Metal,
			folder
		)
		if plot.r % LAMP_EVERY == 0 then
			makePart(
				"LampPole",
				Vector3.new(0.5, LAMP_HEIGHT, 0.5),
				plot.frame * CFrame.new(x, CURB + LAMP_HEIGHT / 2, 0),
				trim,
				Enum.Material.Metal,
				folder
			)
			makePart(
				"LampArm",
				Vector3.new(3.4, 0.35, 0.35),
				plot.frame * CFrame.new(x - edge * 1.6, CURB + LAMP_HEIGHT - 0.2, 0),
				trim,
				Enum.Material.Metal,
				folder
			)
			local head = makePart(
				"LampHead",
				Vector3.new(1.8, 0.3, 0.9),
				plot.frame * CFrame.new(x - edge * 3, CURB + LAMP_HEIGHT - 0.5, 0),
				LAMP_COLOR,
				Enum.Material.Neon,
				folder
			)
			head.CastShadow = false
		end
		-- An invisible wall along the railing, so nobody walks off the side of a finished slot by accident.
		local wall = makePart(
			"Guard",
			Vector3.new(0.5, RAIL_HEIGHT + 4, s),
			plot.frame * CFrame.new(x, (RAIL_HEIGHT + 4) / 2, 0),
			STEEL_COLOR,
			Enum.Material.SmoothPlastic,
			folder
		)
		wall.Transparency = 1
		wall.CanCollide = true
	end
	folder.Parent = view
	plot.finished = folder
end

local function removeFinished(plot: Plot)
	if plot.finished then
		plot.finished:Destroy()
	end
	plot.finished, plot.deck = nil, nil
end

-- The first row not finished yet (one past the round's last row once the bridge is done): belts slow down before it.
local function frontRow(): number
	if openRing ~= 0 then
		return openRing
	end
	return (if lastRing > 0 then lastRing else GameConfig.Grid.Rows) + 1
end

-- The invisible edge at the unfinished end (GameConfig.Grid EdgeAheadRows, EdgeWallStuds): a floor from the first
-- unfinished row to EdgeAheadRows past the furthest finished slot, a wall across its far end and one along each side.
-- Rebuilt whenever a slot finishes or the open row moves (the new parts replace the old in the same frame, so nobody
-- standing on it drops); none once the bridge is done. Client-side like the deck: a character's physics runs on its
-- own player's device. The camera and raycasts ignore it.
local edgeModel: Model? = nil
local function updateEdge()
	if edgeModel then
		edgeModel:Destroy()
		edgeModel = nil
	end
	local grid = GameConfig.Grid
	local last = if lastRing > 0 then lastRing else grid.Rows
	local front = frontRow()
	if openRing == 0 or front > last then
		return
	end
	local reach = front - 1
	for _, plot in plots do
		if plot.r > reach and plot.seeds >= seedsPerHex then
			reach = plot.r
		end
	end
	local to = math.min(reach + grid.EdgeAheadRows, last)
	local s = grid.SlotStuds
	local width = grid.Columns * s
	local length = (to - front + 1) * s
	local middle = -((front - 1) * s + length / 2) -- along the bridge (BridgeGrid: rows run along the frame's -Z)
	local tall = grid.EdgeWallStuds
	local model = Instance.new("Model")
	model.Name = "Edge"
	local function wall(name: string, size: Vector3, offset: CFrame)
		local part = makePart(name, size, bridgeFrame * offset, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, model)
		part.Transparency = 1
		part.CastShadow = false
		part.CanCollide = true -- makePart leaves CanQuery off: the camera and rays pass through
	end
	wall("Floor", Vector3.new(width, 0.5, length), CFrame.new(0, -0.25, middle))
	wall("End", Vector3.new(width + 1, tall, 0.5), CFrame.new(0, tall / 2, -(to * s + 0.25)))
	for _, side in { -1, 1 } do
		wall("Side", Vector3.new(0.5, tall, length), CFrame.new(side * (width / 2 + 0.25), tall / 2, middle))
	end
	model.Parent = view
	edgeModel = model
end

-- A belt slot's speed in studs per second (0 for other lanes and unfinished rows): the same along the whole belt, from
-- the built length (GameConfig.Grid.Belts TripSeconds); the outward belt slows down just before the unfinished end.
-- The belt lane (Belts.Out or Belts.Back) under a position, over its whole Belts.Width, or nil.
function BridgeController.laneAt(position: Vector3): number?
	local grid = GameConfig.Grid
	local belts = grid.Belts
	local across = bridgeFrame:PointToObjectSpace(position).X
	for _, q in { belts.Out, belts.Back } do
		if math.abs(across - (q - (grid.Columns + 1) / 2) * grid.SlotStuds) <= grid.SlotStuds * belts.Width / 2 then
			return q
		end
	end
	return nil
end

-- The first row not finished yet (one past the last row once the bridge is done).
function BridgeController.frontRow(): number
	return frontRow()
end

function BridgeController.beltSpeed(plot: Plot): number
	local grid = GameConfig.Grid
	local belts = grid.Belts
	local front = frontRow()
	if (plot.q ~= belts.Out and plot.q ~= belts.Back) or plot.ring >= front then
		return 0
	end
	-- One speed for the whole belt, from the built length: a BaseWalk walker crosses it in about TripSeconds.
	local length = (front - 1) * grid.SlotStuds
	local speed = math.clamp(length / belts.TripSeconds - belts.BaseWalk, belts.MinSpeed, belts.Max)
	if plot.q == belts.Out then
		local toEnd = (front - plot.ring - 0.5) * grid.SlotStuds
		speed *= math.clamp(toEnd / belts.RampStuds, 0, 1) -- slowing to a stop before the unfinished end
	end
	return speed
end

-- Sets a finished belt slot moving (its deck's velocity carries whoever stands on it).
local function updateBelt(plot: Plot)
	local deck = plot.deck
	if not deck then
		return
	end
	local speed = BridgeController.beltSpeed(plot)
	local outward = plot.q == GameConfig.Grid.Belts.Out
	deck.AssemblyLinearVelocity = plot.frame.LookVector * (if outward then speed else -speed)
end

-- The belts' arrows: one beam down each belt lane, from the rim to the end of the finished rows (the whole belt, the
-- outward lane's slowing stretch included: the user's call, 2026-10-10), so all of a lane's chevrons scroll in step at
-- its one speed. Until 2026-10-10 each slot had its own beam: they started scrolling at different moments and the
-- slowing slots ran at their own speeds, so neighbors drifted out of step and overlapped at the seams (the user's note).
-- Updated whenever the open row moves; the lengths stay whole multiples of BELT_ARROW_SPACING, so nothing jumps.
local laneArrows: { [number]: Beam } = {}
local function updateBeltArrows()
	local grid = GameConfig.Grid
	local belts = grid.Belts
	local length = (frontRow() - 1) * grid.SlotStuds
	local speed = math.clamp(length / belts.TripSeconds - belts.BaseWalk, belts.MinSpeed, belts.Max)
	for _, q in { belts.Out, belts.Back } do
		local beam = laneArrows[q]
		if not beam then
			local holder =
				makePart("BeltArrows", Vector3.one, bridgeFrame, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, view)
			holder.Transparency = 1
			local made = Instance.new("Beam")
			made.Attachment0, made.Attachment1 = Instance.new("Attachment"), Instance.new("Attachment")
			made.Attachment0.Parent, made.Attachment1.Parent = holder, holder
			made.Texture = BELT_ARROWS
			made.TextureMode = Enum.TextureMode.Wrap -- TextureLength in studs (the default, Stretch, makes it a repeat count)
			made.TextureLength = BELT_ARROW_SPACING
			made.Width0, made.Width1 = BELT_ARROW_WIDTH, BELT_ARROW_WIDTH
			made.LightEmission, made.LightInfluence = 0, 0
			made.Transparency = NumberSequence.new(0.15)
			made.Parent = holder
			laneArrows[q] = made
			beam = made
		end
		local stop = length
		beam.Enabled = stop >= BELT_ARROW_SPACING and speed >= BELT_ARROW_MIN
		if beam.Enabled then
			-- Attachment0 is the end the arrows point at (the beam scrolls toward it): the far end on the outward lane.
			local x = (q - (grid.Columns + 1) / 2) * grid.SlotStuds
			local near = bridgeFrame:PointToWorldSpace(Vector3.new(x, BELT_ARROW_LIFT, 0))
			local far = bridgeFrame:PointToWorldSpace(Vector3.new(x, BELT_ARROW_LIFT, -stop))
			local tip, tail = near, far
			if q == belts.Out then
				tip, tail = far, near
			end
			local back = (tail - tip).Unit
			beam.Attachment0.WorldCFrame = CFrame.lookAt(tip, tip + back) * beltTurn
			beam.Attachment1.WorldCFrame = CFrame.lookAt(tail, tail + back) * beltTurn
			beam.TextureSpeed = -speed / BELT_ARROW_SPACING -- negative scrolls toward Attachment0, the way it runs
			-- One segment per chevron: a beam's texture is laid flat across each segment, so the default 10 over a
			-- 300-stud lane warped and slid the arrows as the camera moved (checked on screen, 2026-10-10).
			beam.Segments = math.clamp(math.ceil(stop / BELT_ARROW_SPACING), 1, 1000)
		end
	end
end

-- A slot's state changed or the bridge's end moved: its belt speed follows.
local function refreshPlot(plot: Plot)
	updateBelt(plot)
end

-- Shows the slot's planks for its count. `added` planks just arrived (0 when loading or resetting).
local function updatePlanks(plot: Plot, added: number)
	local done = plot.seeds >= seedsPerHex
	local want = if done then 0 else planksFor(plot.seeds)
	while #plot.planks > want do
		local plank = table.remove(plot.planks) :: BasePart
		plank:Destroy()
	end
	local rng = Random.new(plot.treeSeed + plot.index)
	while #plot.planks < want do
		local i = #plot.planks + 1
		local cframe, size = BridgeController.plankAt(plot, i)
		local shade = 1 + (rng:NextNumber() * 2 - 1) * PLANK_SHADE
		local look = deckLook()
		local h, sat, v = look.Color:ToHSV()
		local plank = makePart("Plank", size, cframe, Color3.fromHSV(h, sat, math.clamp(v * shade, 0, 1)), look.Material, view)
		if added > 0 then
			plank.CFrame = cframe + Vector3.new(0, PLANK_DROP, 0)
			TweenService
				:Create(
					plank,
					TweenInfo.new(PLANK_DROP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ CFrame = cframe }
				)
				:Play()
			task.delay(PLANK_DROP_SECONDS, puff, cframe.Position, DUST_PUFF)
		end
		table.insert(plot.planks, plank)
	end
	if done and not plot.finished then
		buildFinished(plot)
		if added > 0 and plot.deck then
			local deck = plot.deck
			local at = deck.CFrame
			deck.CFrame = at + Vector3.new(0, PLANK_DROP, 0)
			TweenService
				:Create(deck, TweenInfo.new(PLANK_DROP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = at })
				:Play()
			puff(plot.base, FINISH_DUST) -- silent: the "bling" for your own finished slot was removed (the user, 2026-10-10)
		end
	elseif not done and plot.finished then
		removeFinished(plot)
	end
	updateBelt(plot)
	refreshRowSteel(plot.r)
end

local function applyEntries(entries: { number })
	for i = 1, #entries, 6 do
		local plot = plots[entries[i]]
		if plot then
			local before = plot.seeds
			plot.seeds = entries[i + 1]
			plot.species = entries[i + 2]
			plot.mutation = entries[i + 3]
			plot.starterUserId = entries[i + 4]
			plot.treeSeed = entries[i + 5]
			refreshPlot(plot)
			if (before >= seedsPerHex) ~= (plot.seeds >= seedsPerHex) then
				-- Finished (or emptied by a new bridge): the slot ahead of it may open or close, the edge may move.
				local ahead = BridgeController.plotAt(plot.q, plot.r + 1)
				if ahead then
					refreshPlot(ahead)
				end
				updateEdge()
			end
			if plot.seeds ~= before then
				updatePlanks(plot, math.max(0, plot.seeds - before))
			end
		end
	end
end

local function applyBatch(batch: Types.HexBatch)
	local appliedSeq = snapshotSeq
	if appliedSeq == nil then
		table.insert(pending, batch) -- arrived before the snapshot; applied right after it
	elseif batch.seq > appliedSeq then
		applyEntries(batch.entries)
	end
end

local function rowPlots(ring: number): { Plot }
	local list: { Plot } = {}
	for q = 1, GameConfig.Grid.Columns do
		local plot = BridgeController.plotAt(q, ring)
		if plot then
			table.insert(list, plot)
		end
	end
	return list
end

-- Row finished: a golden sweep across its planks and a rising chime; every BANNER_EVERY rows a banner. When it was
-- the last row only the sweep plays: the bridge complete cutscene (AwakeningController) is the moment.
local function rowComplete(ring: number)
	local list = rowPlots(ring)
	for i, plot in list do
		local delay = (i - 1) / #list * SWEEP_SECONDS
		local sweep = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, delay)
		if plot.deck then
			TweenService:Create(plot.deck, sweep, { Color = GOLD_COLOR }):Play()
		end
	end
	if openRing == 0 then
		return
	end
	for i, speed in CHIME_NOTES do
		task.delay(SWEEP_SECONDS + (i - 1) * CHIME_NOTE_GAP, chimeNote, speed)
	end
	HUD.pulseBar()
	if ring % BANNER_EVERY == 0 then
		HUD.banner(`{ring * GameConfig.Grid.SlotStuds} studs across!`)
		HUD.confetti()
	end
end

local function onOpenRow(value: Vector2)
	local beforeRing = openRing
	openRing = value.Y
	if not BridgeController.ready() then
		return -- the snapshot build refreshes every slot
	end
	for _, plot in plots do
		refreshPlot(plot)
	end
	updateEdge()
	updateBeltArrows()
	if beforeRing ~= 0 then -- not when a new bridge starts back at the rim
		local last = if lastRing > 0 then lastRing else GameConfig.Grid.Rows
		for ring = beforeRing, (if openRing == 0 then last else openRing - 1) do
			rowComplete(ring)
		end
	end
end

-- A round grew (ForestState LastRing, GameConfig.Rounds): a banner says how far this bridge goes.
local function onLastRing(value: number)
	local before = lastRing
	lastRing = value
	if not BridgeController.ready() then
		return
	end
	for _, plot in plots do
		refreshPlot(plot)
	end
	updateEdge()
	updateBeltArrows()
	if before ~= 0 and value ~= before then -- rounds only grow
		local rows = ReplicatedStorage:WaitForChild("ForestState"):GetAttribute("RingCount")
		local studs = if typeof(rows) == "number" then rows * GameConfig.Grid.SlotStuds else 0
		HUD.banner(`The canyon gets wider! Build {studs} studs across`)
	end
end

local function fetchSnapshot(): Types.Snapshot
	local getForest = Remotes.func("GetForest")
	while true do
		local ok, result = pcall(getForest.InvokeServer, getForest)
		if ok and result then
			return result
		end
		task.wait(RETRY_SECONDS)
	end
end

local function build(snapshot: Types.Snapshot)
	local layout, state = snapshot.layout, snapshot.state
	for i = 1, #layout / 3 do
		local q, r = layout[i * 3 - 2], layout[i * 3 - 1]
		local base = BridgeGrid.toWorld(q, r, bridgeFrame)
		local s = (i - 1) * 5
		local plot: Plot = {
			index = i,
			q = q,
			r = r,
			ring = r,
			base = base,
			frame = bridgeFrame.Rotation + base,
			seeds = state[s + 1],
			species = state[s + 2],
			mutation = state[s + 3],
			starterUserId = state[s + 4],
			treeSeed = state[s + 5],
			planks = {},
			finished = nil,
			deck = nil,
		}
		plots[i] = plot
		byKey[BridgeGrid.key(q, r)] = i
	end
	for _, plot in plots do
		refreshPlot(plot)
		updatePlanks(plot, 0)
	end
	updateEdge()
	updateBeltArrows()
end

local function makeEffects()
	dustPart = Instance.new("Part")
	dustPart.Name = "Dust"
	dustPart.Size = Vector3.one
	dustPart.Transparency = 1
	dustPart.Anchored = true
	dustPart.CanCollide, dustPart.CanQuery, dustPart.CanTouch = false, false, false
	dustPart.Parent = view
	dustEmitter = Instance.new("ParticleEmitter")
	dustEmitter.Rate = 0
	dustEmitter.Color = DUST_COLORS
	dustEmitter.Size = NumberSequence.new(1.2, 0.3)
	dustEmitter.Transparency = NumberSequence.new(0.2, 1)
	dustEmitter.Lifetime = NumberRange.new(0.6, 1.1)
	dustEmitter.Speed = NumberRange.new(6, 14)
	dustEmitter.SpreadAngle = Vector2.new(180, 40)
	dustEmitter.Acceleration = Vector3.new(0, -18, 0)
	dustEmitter.Drag = 3
	dustEmitter.Rotation = NumberRange.new(0, 360)
	dustEmitter.Parent = dustPart
	chime = Instance.new("Sound")
	chime.SoundId = CHIME_ID
	chime.Volume = 0.6
	chime.SoundGroup = Sounds.effects()
end

function BridgeController.start()
	local forestState = ReplicatedStorage:WaitForChild("ForestState")
	center = forestState:GetAttribute("Center") :: Vector3
	local arrowAssets = ReplicatedStorage:WaitForChild("Assets"):FindFirstChild("Lobby")
	local turn = arrowAssets and arrowAssets:FindFirstChild("TreadmillArrows")
	turn = turn and turn:FindFirstChild("Turn")
	if turn and turn:IsA("Attachment") then
		beltTurn = turn.CFrame
	end
	bridgeFrame = forestState:GetAttribute("BridgeFrame") :: CFrame
	local function useSeedsPerHex()
		local value = forestState:GetAttribute("SeedsPerHex")
		seedsPerHex = if typeof(value) == "number" and value > 0 then value else GameConfig.Tiers[1].SeedsPerHex
	end
	useSeedsPerHex()
	forestState:GetAttributeChangedSignal("SeedsPerHex"):Connect(useSeedsPerHex)

	-- Listen first, so batches sent while the snapshot is on its way are kept.
	Remotes.event("HexBatch").OnClientEvent:Connect(applyBatch)
	forestState:GetAttributeChangedSignal("OpenRow"):Connect(function()
		onOpenRow(forestState:GetAttribute("OpenRow") :: Vector2)
	end)
	local function lastRingNow(): number
		local value = forestState:GetAttribute("LastRing")
		return if typeof(value) == "number" then value else 0
	end
	forestState:GetAttributeChangedSignal("LastRing"):Connect(function()
		onLastRing(lastRingNow())
	end)
	lastRing = lastRingNow()

	local snapshot = fetchSnapshot()
	local started = os.clock()
	view = Instance.new("Folder")
	view.Name = "BridgeView"
	makeEffects()
	local row = forestState:GetAttribute("OpenRow") :: Vector2
	openRing = row.Y
	build(snapshot)
	updateTowers()
	view.Parent = workspace
	-- A map swap (MapService) changes the structure: towers, every finished row's steel and the decks' trim.
	local map = workspace:WaitForChild("Map")
	map:GetAttributeChangedSignal("CurrentMap"):Connect(function()
		updateTowers()
		for r, folder in rowSteel do
			folder:Destroy()
			rowSteel[r] = nil
		end
		local look = deckLook()
		for _, plot in plots do
			if plot.finished then
				removeFinished(plot)
				buildFinished(plot)
				refreshPlot(plot)
			end
			for _, plank in plot.planks do
				plank.Color, plank.Material = look.Color, look.Material
			end
			refreshRowSteel(plot.r)
		end
	end)
	snapshotSeq = snapshot.seq
	for _, batch in pending do
		applyBatch(batch)
	end
	table.clear(pending)
	print(`[BridgeController] {#plots} bridge slots built in {math.round((os.clock() - started) * 1000)} ms`)
end

return BridgeController
