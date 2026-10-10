--!strict
-- ForestController: the client's copy of the forest (docs/ARCHITECTURE.md section 4, docs/plans/M5.md).
-- Builds a hex tile per plot from the GetForest snapshot (the Blender tile from Assets.Tiles) and
-- applies HexBatch updates. Only one row is open at a time (one section's plots in one ring, from the
-- OpenRow attribute). Each tile shows its state: unplanted (brown; the open row adds a pulsing rim),
-- started (mossy with tufts, rim kept) and finished (mossy, no rim). Each planted plot gets its tree:
-- the Assets.Trees model for its stage, offset, turned and sized from its tree seed so every client
-- sees the same tree. Every update bounces the tree and the finishing seed adds a leaf burst (no
-- sound). A new stage (8 of them, docs/plans/TreeStages.md) pops in from the old model's size with a small
-- leaf puff, and a "bling" when the seeds were your own. When a row is finished a small moment plays, and
-- when a whole section is finished the big
-- one. During the break after a forest, setSway() sways every tree (M6). Answers plot lookups for
-- TargetController.
-- Seed shop (docs/plans/SeedShop.md): a plot whose species changes (a special seed turned it) is rebuilt
-- as the new tree. Cherry Blossoms drop petals, Bamboo leaves and Crystal Trees sparkle from stage PARTICLE_STAGE on (only
-- the shop's, not a world's wild ones), and
-- Epic and Legendary trees show their owner's name.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local HexGrid = require(Shared.HexGrid)
local Remotes = require(Shared.Remotes)
local Targeting = require(Shared.Targeting)
local Trees = require(Shared.Trees)
local Types = require(Shared.Types)
local AncientTreeController = require(script.Parent.AncientTreeController)
local HUD = require(script.Parent.HUD)
local Sounds = require(script.Parent.Parent.Sounds)
local UIStyle = require(script.Parent.Parent.UIStyle)

-- Look (visual only, not balance numbers). The rim keeps its color from the asset.
local TEMPLATE_HEX_SIZE = 16 -- the Blender tile was modeled for HexSize 16
-- Tiles look like the style reference (M11): brown dirt with a thin grass border, grassy once planted.
-- Every unplanted tile has the open look (the user's call, 2026-10-07: the slate grey for other sections, and the
-- darker brown for rows not open yet, looked ugly). The open row stands out by its pulsing rim, the target
-- highlight and the guide arrow.
-- Smooth, flat colors (Roblox's Ground material with lighter colors was tried on 2026-10-07 and dropped the same day:
-- SLAB_MATERIAL Ground, OPEN_COLOR 205, 150, 98, MOSS_COLOR 140, 215, 95).
-- The wasteland (2026-10-09, the user's pick, colors only for now): an unplanted tile is dry, dusty ground with a dry
-- grass border, and turns green with its first acorn, so planting brings the land back to life. A dusty tan, not the
-- slate grey that looked ugly on 2026-10-07; OPEN_COLOR was the brown dirt before.
local SLAB_MATERIAL = Enum.Material.SmoothPlastic
local OPEN_COLOR = Color3.fromRGB(158, 142, 116) -- dry wasteland (was 150, 103, 64: brown dirt)
local MOSS_COLOR = Color3.fromRGB(104, 168, 68)
local BORDER_COLOR = Color3.fromRGB(98, 160, 64)
local DRY_BORDER_COLOR = Color3.fromRGB(150, 136, 96) -- an unplanted tile's dry grass edge
local LEAF_TINT = 0.08 -- each tree's leaves vary in brightness by up to this much, from its tree seed
local LEAF_HUE = 0.025 -- ... and in hue by up to this much
local GOLD_COLOR = Color3.fromRGB(255, 205, 70)
local PULSE = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local PULSE_TRANSPARENCY = 0.6
local GROW_FROM = 0.8 -- within a stage a tree grows from 80% to 100% of its model, so every seed ends a little bigger
local POP_FROM = 0.5 -- a new stage's model pops in from at least this fraction of its size
local STAGE_LEAVES = 6 -- the leaf puff when a tree reaches a new stage
-- A new stage plays this, the same each time (Creator Store "bling_diamond_pickup_2", 1.51 s; the user's pick).
local STAGE_SOUND_ID = "rbxassetid://4612374393"
local STAGE_NOTE_VOLUME = 0.35
local STAGE_BLING_EVERY = 2 -- only every 2nd stage blings (2, 4, 6: seeds 5, 21, 53 of 100), the user wanted fewer
local OWN_PLANT_SECONDS = 0.6 -- a tree changing this soon after your Carried count dropped ...
local OWN_PLANT_STUDS = 60 -- ... and this close to you counts as your planting (for the note)
local SIZE_JITTER = 0.1 -- trees are 90% to 110% of the model's size
local SQUASH = 0.14 -- squash for one seed; more seeds in one update squash harder, up to SQUASH_MAX
local SQUASH_MAX = 0.3
local SINK = 0.2 -- trees sit this far into the tile so the roots don't float
local BACKDROP_SIZE = { 0.95, 1.3 } -- the old forest's trees: full grown, a little bigger than a new forest's
local BACKDROP_SINK = 0.6 -- they stand on the grass (no tile), a bit deeper
local LEAF_COLORS = ColorSequence.new(Color3.fromRGB(120, 200, 80), Color3.fromRGB(200, 230, 90))
local CHIME_ID = "rbxasset://sounds/electronicpingshort.wav" -- placeholder until there's real audio
local FINISH_LEAVES = 30
local WAVE_SECONDS = 2 -- the ring moment's wave runs all the way around the ring in this long
local WAVE_BOUNCE_SECONDS = 0.6
local WAVE_SWAY = math.rad(8)
local WAVE_LEAVES = 6
local REVEAL_SECONDS = 0.6 -- the next row's rims light up one after another over this long
local CHIME_NOTES = { 1, 1.26, 1.5 }
local CHIME_NOTE_GAP = 0.12
local RETRY_SECONDS = 5
local SWAY_ANGLE = math.rad(3)
local SWAY_SPEED = 1.6 -- radians per second
local SWAY_WAVE = 0.012 -- phase per stud across the map, so the sway rolls through the forest like wind
-- Special trees' particles (the petal and sparkle images from tools/make_particle_textures.py).
local PARTICLE_STAGE = 4
type TreeParticles = { piece: string, texture: string, colors: { Color3 }, glow: boolean }
local TREE_PARTICLES: { [string]: TreeParticles } = {
	Sakura = {
		piece = "_Blossom",
		texture = "rbxassetid://130093552340519",
		colors = { Color3.fromRGB(255, 175, 210), Color3.fromRGB(240, 110, 170) },
		glow = false,
	},
	Bamboo = { -- the shop's Bamboo: falling leaves, so it stands out from the wild bamboo of its world
		piece = "_Leaves",
		texture = "rbxassetid://130093552340519",
		colors = { Color3.fromRGB(150, 220, 90), Color3.fromRGB(80, 170, 60) },
		glow = false,
	},
	Crystal = {
		piece = "_CrystalViolet",
		texture = "rbxassetid://88252539838654",
		colors = { Color3.fromRGB(140, 235, 255), Color3.fromRGB(200, 140, 255) },
		glow = true,
	},
}
local NAME_LABEL_RARITIES = { Epic = true, Legendary = true }
local NAME_LABEL_DISTANCE = 250

type Piece = { part: BasePart, rel: CFrame, size: Vector3 }

export type Plot = {
	index: number,
	q: number,
	r: number,
	ring: number,
	side: number, -- its forest section (1..6), HexGrid.side
	base: Vector3, -- hex center on the ground
	seeds: number,
	species: number,
	mutation: number,
	starterUserId: number,
	treeSeed: number,
	slab: BasePart,
	rim: BasePart?,
	pulse: Tween?,
	tufts: BasePart?,
	flowers: BasePart?,
	border: BasePart,
	tree: Model?,
	treeStage: number,
	treePieces: { Piece },
	treePivot: CFrame, -- where the tree stands, turned by its tree seed
	treeSize: number, -- its size factor from the tree seed
	treeScale: number, -- its current growth scale (GROW_FROM..1 within a stage)
}

type Bounce = { start: number, seconds: number, from: number, to: number, squash: number, sway: number }

local ForestController = {}

local plots: { Plot } = {}
local byKey: { [string]: number } = {}
local center = Vector3.zero
local openRing = 0 -- the open ring (0 when the forest is complete)
local lastRing = 0 -- the round's last ring (ForestState LastRing; 0 = every ring is in this forest)
local seedsPerHex = GameConfig.Tiers[1].SeedsPerHex -- the current world's (ForestState SeedsPerHex; worlds differ)
local snapshotSeq: number? = nil -- nil until the snapshot has been applied
local pending: { Types.HexBatch } = {}
local view: Folder
local slabTemplate: BasePart
local rimTemplate: BasePart
local tuftsTemplate: BasePart
local flowersTemplate: BasePart
local borderTemplate: BasePart
local treeTemplates: Instance
local scale = 1
local tileTop = 0 -- the slab's top above the plot's base
local bounces: { [Plot]: Bounce } = {} -- only the trees bouncing right now
local stageFirst: { [number]: number } = {}
local stageLast: { [number]: number } = {}
local swayConnection: RBXScriptConnection? = nil
local swayParts: { BasePart } = {}
local swayFrames: { CFrame } = {}
local burstPart: Part
local burstEmitter: ParticleEmitter
local chime: Sound
local stageSound: Sound
local templateHeights: { [string]: number } = {}
local lastOwnPlant = -math.huge

function ForestController.ready(): boolean
	return snapshotSeq ~= nil
end

function ForestController.center(): Vector3
	return center
end

-- The forest floor's height (from the server's raycasts in the snapshot).
function ForestController.groundY(): number
	return if plots[1] then plots[1].base.Y else center.Y
end

function ForestController.plotAt(q: number, r: number): Plot?
	local index = byKey[HexGrid.key(q, r)]
	return if index then plots[index] else nil
end

-- This server's ring order (ForestState OutsideIn: the layout A/B test), else GameConfig's.
local function outsideInNow(): boolean
	local value = ReplicatedStorage:WaitForChild("ForestState"):GetAttribute("OutsideIn")
	return if typeof(value) == "boolean" then value else GameConfig.Grid.OutsideIn
end

local function isGrownAt(q: number, r: number): boolean
	local plot = ForestController.plotAt(q, r)
	return plot ~= nil and plot.seeds >= seedsPerHex
end

-- Rounds (GameConfig.Rounds): is `ring` in a forest whose last ring is `last` (ForestState LastRing; 0 = all)?
local function inRoundFor(ring: number, last: number): boolean
	if last == 0 then
		return true
	end
	return if outsideInNow() then ring >= last else ring <= last
end

local function inRound(plot: Plot): boolean
	return inRoundFor(plot.ring, lastRing)
end

-- The open row is a whole ring (since 2026-10-07; was one section's slice of it): OpenRow is (0, ring). Since
-- 2026-10-09 the plots just behind its full-grown trees are open too (Targeting.isOpenPlot, the server's rule).
function ForestController.isOpenPlot(plot: Plot): boolean
	if not inRound(plot) then
		return false
	elseif ReplicatedStorage:WaitForChild("ForestState"):GetAttribute("WholeRound") == true then
		return openRing ~= 0 and plot.seeds < seedsPerHex -- a small round: all of it (the server's rule)
	end
	return Targeting.isOpenPlot(
		plot.q,
		plot.r,
		plot.ring,
		plot.seeds >= seedsPerHex,
		openRing,
		outsideInNow(),
		GameConfig.Grid.AheadRings,
		isGrownAt
	)
end

function ForestController.isOpen(q: number, r: number): boolean
	local plot = ForestController.plotAt(q, r)
	return plot ~= nil and ForestController.isOpenPlot(plot)
end

-- The model of `species` (0 = this world's first Common tree) at `stage`, for the target's preview (TargetController).
function ForestController.previewTemplate(stage: number, species: number): Model?
	if species == 0 then
		local tierId = ReplicatedStorage:WaitForChild("ForestState"):GetAttribute("TierId")
		for _, tier in GameConfig.Tiers do
			if tier.Id == tierId then
				species = Trees.index(tier.Commons[1])
			end
		end
	end
	local modelName = Trees.model(species)
	local template = modelName and treeTemplates:FindFirstChild(`{modelName}{stage}`)
	return if template and template:IsA("Model") then template else nil
end

function ForestController.allPlots(): { Plot }
	return plots
end

-- Copies one piece of the tile asset so its base sits at `base`, scaled to the current HexSize.
local function place(template: BasePart, base: Vector3): BasePart
	local part = template:Clone()
	local rel = template.CFrame -- relative to the asset's pivot (the tile's bottom center, at the origin)
	part.Size = template.Size * scale
	part.CFrame = CFrame.new(base) * (rel.Rotation + rel.Position * scale)
	-- Players walk on Map.WalkFloor (top 1.55, over the whole forest), not on the tiles, so no tile piece
	-- collides: ~2,150 fewer colliding parts per client, and the grass tufts that stick up through the
	-- floor stop being bumps (M12, 2026-10-07).
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.Parent = view
	return part
end

local function refreshPlot(plot: Plot)
	local started = plot.seeds > 0
	local open = ForestController.isOpenPlot(plot)
	if open and not plot.rim then
		plot.rim = place(rimTemplate, plot.base)
	elseif not open and plot.rim then
		if plot.pulse then
			plot.pulse:Cancel()
			plot.pulse = nil
		end
		plot.rim:Destroy()
		plot.rim = nil
	end
	local rim = plot.rim
	if rim and not started and not plot.pulse then
		rim.Transparency = 0
		local pulse = TweenService:Create(rim, PULSE, { Transparency = PULSE_TRANSPARENCY })
		pulse:Play()
		plot.pulse = pulse
	elseif rim and started and plot.pulse then
		plot.pulse:Cancel()
		plot.pulse = nil
		rim.Transparency = 0
	end
	if started and not plot.tufts then
		plot.tufts = place(tuftsTemplate, plot.base)
		plot.flowers = place(flowersTemplate, plot.base)
	elseif not started and plot.tufts then
		plot.tufts:Destroy()
		plot.tufts = nil
		if plot.flowers then
			plot.flowers:Destroy()
			plot.flowers = nil
		end
	end
	plot.border.Color = if started then BORDER_COLOR else DRY_BORDER_COLOR
	plot.slab.Color = if started then MOSS_COLOR else OPEN_COLOR
end

-- The tree's growth scale for its seed count: GROW_FROM at its stage's first seed, 1 at the last.
local function growScale(seeds: number): number
	local stage = GameConfig.growthStage(seeds, seedsPerHex)
	local first, last = stageFirst[stage], stageLast[stage]
	local t = if last > first then (seeds - first) / (last - first) else 1
	return GROW_FROM + (1 - GROW_FROM) * t
end

-- Poses the tree: `squash` > 0 is shorter and wider, < 0 taller and thinner; `tilt` sways it.
local function pose(plot: Plot, growth: number, squash: number, tilt: number)
	plot.treeScale = growth
	local s = growth * plot.treeSize
	local stretch = Vector3.new(s * (1 + squash * 0.5), s * (1 - squash), s * (1 + squash * 0.5))
	local pivot = plot.treePivot * CFrame.Angles(tilt, 0, 0)
	for _, piece in plot.treePieces do
		piece.part.Size = piece.size * stretch
		piece.part.CFrame = pivot * CFrame.new(piece.rel.Position * stretch) * piece.rel.Rotation
	end
end

local function startBounce(plot: Plot, from: number, to: number, squash: number, sway: number, delay: number, seconds: number)
	bounces[plot] = { start = os.clock() + delay, seconds = seconds, from = from, to = to, squash = squash, sway = sway }
end

-- One RenderStepped pass over only the trees that are bouncing (empty most frames).
local function stepBounces()
	local now = os.clock()
	for plot, bounce in bounces do
		local t = (now - bounce.start) / bounce.seconds
		if not plot.tree then
			bounces[plot] = nil
		elseif t >= 1 then
			pose(plot, bounce.to, 0, 0)
			bounces[plot] = nil
		elseif t >= 0 then
			local wave = math.sin(t * 2 * math.pi) * (1 - t) -- squash first, then stretch, settling
			local eased = 1 - (1 - t) ^ 3
			pose(plot, bounce.from + (bounce.to - bounce.from) * eased, bounce.squash * wave, bounce.sway * wave)
		end
	end
end

-- Every tree sways at once, moved with one BulkMoveTo call per frame. The only loop over all trees,
-- and it runs only during the break after a forest.
local function stepSway()
	local t = os.clock()
	table.clear(swayParts)
	table.clear(swayFrames)
	for _, plot in plots do
		if plot.tree and not bounces[plot] then
			local phase = (plot.base.X + plot.base.Z) * SWAY_WAVE
			local tilt = SWAY_ANGLE * math.sin(t * SWAY_SPEED + phase)
			local s = plot.treeScale * plot.treeSize
			local pivot = plot.treePivot * CFrame.Angles(tilt, 0, tilt * 0.5)
			for _, piece in plot.treePieces do
				table.insert(swayParts, piece.part)
				table.insert(swayFrames, pivot * CFrame.new(piece.rel.Position * s) * piece.rel.Rotation)
			end
		end
	end
	workspace:BulkMoveTo(swayParts, swayFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

function ForestController.setSway(on: boolean)
	if on and not swayConnection then
		swayConnection = RunService.RenderStepped:Connect(stepSway)
	elseif not on and swayConnection then
		swayConnection:Disconnect()
		swayConnection = nil
		for _, plot in plots do
			if plot.tree and not bounces[plot] then
				pose(plot, plot.treeScale, 0, 0)
			end
		end
	end
end

local function removeTree(plot: Plot)
	if plot.tree then
		plot.tree:Destroy()
	end
	plot.tree = nil
	plot.treeStage = 0
	plot.treePieces = {}
	bounces[plot] = nil
end

-- Petals or sparkles from a special tree's canopy, more as it grows.
local function addParticles(model: Model, name: string, stage: number)
	local look = TREE_PARTICLES[name]
	if not look then
		return
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and string.find(part.Name, look.piece .. "$") then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = look.texture
			emitter.Color = ColorSequence.new(look.colors[1], look.colors[2])
			emitter.Rate = stage - 2 -- 2 a second at stage 4, 6 full grown
			if look.glow then -- sparkles: twinkle in place and drift up
				emitter.LightEmission, emitter.LightInfluence = 1, 0
				emitter.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.5, 1.4),
					NumberSequenceKeypoint.new(1, 0),
				})
				emitter.Lifetime = NumberRange.new(0.8, 1.4)
				emitter.Speed = NumberRange.new(0.5, 1.5)
				emitter.Acceleration = Vector3.new(0, 1, 0)
			else -- petals: tumble down from the canopy
				emitter.LightInfluence = 1
				emitter.Size = NumberSequence.new(0.7)
				emitter.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.8, 0),
					NumberSequenceKeypoint.new(1, 1),
				})
				emitter.Lifetime = NumberRange.new(4, 6)
				emitter.Speed = NumberRange.new(0.5, 1.5)
				emitter.Acceleration = Vector3.new(0.6, -1.4, 0)
				emitter.Drag = 0.3
				emitter.Rotation = NumberRange.new(0, 360)
				emitter.RotSpeed = NumberRange.new(-90, 90)
				emitter.EmissionDirection = Enum.NormalId.Bottom
			end
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Parent = part
		end
	end
end

-- "Allen's Crystal Tree" over Epic and Legendary trees, in the rarity color.
local function addNameLabel(model: Model, plot: Plot, name: string)
	local def = GameConfig.seedDef(name)
	if not (def and NAME_LABEL_RARITIES[def.Rarity]) then
		return
	end
	local top: BasePart? = nil
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and (not top or part.Position.Y + part.Size.Y / 2 > top.Position.Y + top.Size.Y / 2) then
			top = part
		end
	end
	if not top then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "OwnerLabel"
	gui.Size = UDim2.fromOffset(320, 44)
	gui.ExtentsOffsetWorldSpace = Vector3.new(0, 1, 0)
	gui.MaxDistance = NAME_LABEL_DISTANCE
	gui.Adornee = top
	gui.Parent = top
	local owner = Players:GetPlayerByUserId(plot.starterUserId)
	local label = UIStyle.text(
		gui,
		`{if owner then owner.DisplayName else "Someone"}'s {def.DisplayName}`,
		30,
		Trees.RarityColors[def.Rarity]
	)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
end

local function buildTree(plot: Plot, stage: number)
	removeTree(plot)
	local name = Trees.Species[plot.species] -- the species: particles and the name label go by it
	local modelName = Trees.model(plot.species) -- the models (a world's wild Sakura uses Sakura's)
	local template = modelName and treeTemplates:FindFirstChild(`{modelName}{stage}`)
	if not (template and template:IsA("Model")) then
		return
	end
	-- The same tree seed gives every client the same offset, turn and size.
	local rng = Random.new(plot.treeSeed)
	local angle = rng:NextNumber() * 2 * math.pi
	local distance = rng:NextNumber() * GameConfig.Grid.TreeJitterFraction * GameConfig.Grid.HexSize
	local yaw = rng:NextNumber() * 2 * math.pi
	plot.treeSize = 1 + (rng:NextNumber() * 2 - 1) * SIZE_JITTER
	local offset = Vector3.new(math.cos(angle) * distance, tileTop - SINK, math.sin(angle) * distance)
	plot.treePivot = CFrame.new(plot.base + offset) * CFrame.Angles(0, yaw, 0)

	-- Leaf and bark shades vary a little per tree (drawn after the placement, so trees don't move).
	local hueShift = (rng:NextNumber() * 2 - 1) * LEAF_HUE
	local leafShade = 1 + (rng:NextNumber() * 2 - 1) * LEAF_TINT
	local barkShade = 1 + (rng:NextNumber() * 2 - 1) * LEAF_TINT

	local model = template:Clone()
	local pivot = model:GetPivot()
	local pieces: { Piece } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local bark = string.find(part.Name, "_Bark") ~= nil
			local h, sat, v = part.Color:ToHSV()
			part.Color = if bark
				then Color3.fromHSV(h, sat, math.clamp(v * barkShade, 0, 1))
				else Color3.fromHSV((h + hueShift) % 1, sat, math.clamp(v * leafShade, 0, 1))
			part.Anchored = true
			part.CanTouch = false
			part.CanCollide = false -- players run straight through trees
			part.CanQuery = bark -- the camera still sees trunks (they fade when in the way); it ignores canopies
			table.insert(pieces, { part = part, rel = pivot:ToObjectSpace(part.CFrame), size = part.Size })
		end
	end
	if stage >= PARTICLE_STAGE then
		addParticles(model, name, stage)
	end
	addNameLabel(model, plot, name)
	model.Parent = view
	plot.tree = model
	plot.treeStage = stage
	plot.treePieces = pieces
end

local function canopy(plot: Plot): Vector3
	local tree = plot.tree
	return if tree then tree:GetBoundingBox().Position else plot.base
end

local function leafBurst(position: Vector3, count: number)
	burstPart.Position = position
	burstEmitter:Emit(count) -- particles stay in the world, so the part can move on to the next burst
end

local function chimeNote(speed: number, volume: number?)
	local note = chime:Clone()
	note.PlaybackSpeed = speed
	note.Volume = volume or chime.Volume
	note.Parent = SoundService -- not in a part, so it plays at full volume wherever you are
	note:Play()
	Debris:AddItem(note, 2)
end

-- A tree model's height as modeled, for popping a new stage in from the old one's size.
local function templateHeight(name: string, stage: number): number
	local key = `{name}{stage}`
	local height = templateHeights[key]
	if not height then
		local template = treeTemplates:FindFirstChild(key)
		height = if template and template:IsA("Model") then template:GetExtentsSize().Y else 1
		templateHeights[key] = height
	end
	return height :: number
end

-- Did the local player just plant near this plot? (Batches don't say who planted.)
local function plantedByMe(plot: Plot): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return os.clock() - lastOwnPlant <= OWN_PLANT_SECONDS
		and root ~= nil
		and root:IsA("BasePart")
		and (root.Position - plot.base).Magnitude <= OWN_PLANT_STUDS
end

-- Shows the plot's tree for its seed count. `added` seeds just arrived (0 when loading or resetting).
local function updateTree(plot: Plot, added: number)
	if plot.seeds <= 0 or plot.species == 0 then
		removeTree(plot)
		return
	end
	local stage = GameConfig.growthStage(plot.seeds, seedsPerHex)
	local growth = growScale(plot.seeds)
	local squash = math.min(SQUASH + SQUASH * 0.25 * (added - 1), SQUASH_MAX)
	local seconds = GameConfig.Growth.BounceSeconds
	if stage ~= plot.treeStage or not plot.tree then
		local name = Trees.model(plot.species)
		local oldHeight = if plot.tree
				and plot.treeStage > 0
				and name
			then plot.treeScale * templateHeight(name, plot.treeStage)
			else 0
		buildTree(plot, stage)
		if not plot.tree then
			return
		end
		if added > 0 then
			-- From the old model's height, so the tree never shrinks for a moment.
			local from = growth * POP_FROM
			if oldHeight > 0 and name then
				from = math.clamp(oldHeight / templateHeight(name, stage), from, growth)
			end
			pose(plot, from, 0, 0)
			startBounce(plot, from, growth, squash, 0, 0, seconds * 1.5)
			if plot.seeds < seedsPerHex then -- full grown has its own burst and chime below
				leafBurst(canopy(plot), STAGE_LEAVES)
				if stage % STAGE_BLING_EVERY == 0 and plantedByMe(plot) then
					local bling = stageSound:Clone()
					bling.Parent = SoundService -- not in a part, so it plays at full volume
					bling:Play()
					Debris:AddItem(bling, 2)
				end
			end
		else
			pose(plot, growth, 0, 0)
		end
	elseif added > 0 then
		startBounce(plot, plot.treeScale, growth, squash, 0, 0, seconds)
	else
		pose(plot, growth, 0, 0)
	end
	if added > 0 and plot.seeds >= seedsPerHex and plot.seeds - added < seedsPerHex then
		leafBurst(canopy(plot), FINISH_LEAVES) -- no sound (its placeholder ping was removed, the user's call 2026-10-08)
	end
end

local function applyEntries(entries: { number })
	for i = 1, #entries, 6 do
		local plot = plots[entries[i]]
		if plot then
			local before = plot.seeds
			local beforeSpecies = plot.species
			plot.seeds = entries[i + 1]
			plot.species = entries[i + 2]
			plot.mutation = entries[i + 3]
			plot.starterUserId = entries[i + 4]
			plot.treeSeed = entries[i + 5]
			refreshPlot(plot)
			if (before >= seedsPerHex) ~= (plot.seeds >= seedsPerHex) then
				-- Finished (or emptied by a new forest): the plots behind it may open or close (two rings).
				for _, n in HexGrid.neighbors(plot.q, plot.r) do
					local neighbor = ForestController.plotAt(n.q, n.r)
					if neighbor then
						refreshPlot(neighbor)
					end
				end
			end
			if plot.species ~= beforeSpecies and plot.tree then
				plot.treeStage = 0 -- a special seed turned it: rebuild it as the new tree
			end
			if plot.seeds ~= before or plot.species ~= beforeSpecies then
				updateTree(plot, math.max(0, plot.seeds - before))
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

local function angleOf(plot: Plot): number
	return math.atan2(plot.base.Z - center.Z, plot.base.X - center.X)
end

-- One ring's plots, in order around the hub.
local function ringPlots(ring: number): { Plot }
	local list: { Plot } = {}
	for _, plot in plots do
		if plot.ring == ring then
			table.insert(list, plot)
		end
	end
	table.sort(list, function(a, b)
		return angleOf(a) < angleOf(b)
	end)
	return list
end

-- A wave of sways and bounces with a golden sweep and a few leaves, along `list` in `seconds`.
local function wave(list: { Plot }, seconds: number)
	for i, plot in list do
		local delay = (i - 1) / #list * seconds
		if plot.tree then
			local growth = growScale(plot.seeds)
			startBounce(plot, growth, growth, SQUASH, WAVE_SWAY, delay, WAVE_BOUNCE_SECONDS)
			task.delay(delay, function()
				leafBurst(canopy(plot), WAVE_LEAVES)
			end)
		end
		local sweep = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, delay)
		TweenService:Create(plot.slab, sweep, { Color = GOLD_COLOR }):Play()
	end
end

-- The next row's rims light up one after another, starting `after` seconds from now.
local function reveal(list: { Plot }, after: number)
	for i, plot in list do
		task.delay(after + (i - 1) / #list * REVEAL_SECONDS, refreshPlot, plot)
	end
end

-- Ring finished (since 2026-10-07; rows used to be sections' slices): the wave runs all the way around it, then a
-- rising chime, the next ring lights up, the Ancient Tree shakes, the Forest Bar pulses and a "Ring 3 of 9
-- complete!" banner shows. When it was the last ring, only the wave plays: the forest complete cutscene
-- (AwakeningController) is the moment.
local function ringComplete(ring: number, opening: { Plot })
	wave(ringPlots(ring), WAVE_SECONDS)
	reveal(opening, WAVE_SECONDS)
	if openRing == 0 then
		return
	end
	task.delay(WAVE_SECONDS, function()
		for i, speed in CHIME_NOTES do
			task.delay((i - 1) * CHIME_NOTE_GAP, chimeNote, speed)
		end
		AncientTreeController.shake()
		HUD.pulseBar()
		local grid = GameConfig.Grid
		local outer = grid.HubRings + grid.ForestRings
		local number = if outsideInNow() then outer - ring + 1 else ring - grid.HubRings
		HUD.banner(`Ring {number} complete!`) -- just that (the user's call, 2026-10-08)
		HUD.confetti()
	end)
end

local function onOpenRow(value: Vector2)
	local beforeRing = openRing
	openRing = value.Y
	if not ForestController.ready() then
		return -- the snapshot build refreshes every plot
	end
	local grid = GameConfig.Grid
	local firstRing = if outsideInNow() then grid.HubRings + grid.ForestRings else grid.HubRings + 1
	local moment = beforeRing ~= 0 and openRing ~= firstRing -- not when a new forest starts back at the first ring
	local opening: { Plot } = if moment then ringPlots(openRing) else {}
	local delayed: { [Plot]: boolean } = {}
	for _, plot in opening do
		delayed[plot] = true -- the opening ring lights up during the moment
	end
	for _, plot in plots do
		if not delayed[plot] then
			refreshPlot(plot)
		end
	end
	if moment then
		ringComplete(beforeRing, opening)
	end
end

-- A round grew (ForestState LastRing, GameConfig.Rounds): the open rims follow, and a banner says how many rings this
-- forest has. Tiles outside the round stay as wasteland, like every unplanted tile.
local function onLastRing(value: number)
	local before = lastRing
	lastRing = value
	if not ForestController.ready() then
		return -- the snapshot build refreshes every plot
	end
	for _, plot in plots do
		refreshPlot(plot)
	end
	if before ~= 0 and value ~= before then -- rounds only grow
		local rings = ReplicatedStorage:WaitForChild("ForestState"):GetAttribute("RingCount")
		HUD.banner(`The forest grows! {rings} rings to plant`)
	end
end

-- The old forest on the town's side (2026-10-09, the user's ask: the grass behind the town looked empty): a
-- full-grown tree of this world's Common trees on every spot the server sent (Snapshot.backdrop), turned, offset,
-- sized and shaded from the spot itself, so every client sees the same forest. Nothing to touch or plant; built
-- again when the world changes.
local backdropSpots: { number } = {}
local backdropFolder: Folder? = nil

local function buildBackdrop()
	if backdropFolder then
		backdropFolder:Destroy()
		backdropFolder = nil
	end
	if #backdropSpots == 0 then
		return
	end
	local tierId = ReplicatedStorage:WaitForChild("ForestState"):GetAttribute("TierId")
	local commons = GameConfig.Tiers[1].Commons
	for _, tier in GameConfig.Tiers do
		if tier.Id == tierId then
			commons = tier.Commons
		end
	end
	local stage = #GameConfig.Growth.StageStarts
	local hexSize = GameConfig.Grid.HexSize
	local folder = Instance.new("Folder")
	folder.Name = "OldForest"
	for i = 1, #backdropSpots // 3 do
		local q, r, y = backdropSpots[i * 3 - 2], backdropSpots[i * 3 - 1], backdropSpots[i * 3]
		local rng = Random.new(q * 7919 + r * 104729)
		local modelName = Trees.model(Trees.index(commons[rng:NextInteger(1, #commons)]))
		local template = modelName and treeTemplates:FindFirstChild(`{modelName}{stage}`)
		if template and template:IsA("Model") then
			local model = template:Clone()
			local leafShade = 1 + (rng:NextNumber() * 2 - 1) * LEAF_TINT
			local hueShift = (rng:NextNumber() * 2 - 1) * LEAF_HUE
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					if not string.find(part.Name, "_Bark") then
						local h, sat, v = part.Color:ToHSV()
						part.Color = Color3.fromHSV((h + hueShift) % 1, sat, math.clamp(v * leafShade, 0, 1))
					end
					part.Anchored, part.CanTouch, part.CanCollide, part.CanQuery = true, false, false, false
				end
			end
			model:ScaleTo(BACKDROP_SIZE[1] + rng:NextNumber() * (BACKDROP_SIZE[2] - BACKDROP_SIZE[1]))
			local flat = HexGrid.toWorld(q, r, hexSize, center)
			local angle = rng:NextNumber() * 2 * math.pi
			local distance = rng:NextNumber() * GameConfig.Grid.TreeJitterFraction * hexSize
			local at = Vector3.new(flat.X + math.cos(angle) * distance, y - BACKDROP_SINK, flat.Z + math.sin(angle) * distance)
			model:PivotTo(CFrame.new(at) * CFrame.Angles(0, rng:NextNumber() * 2 * math.pi, 0))
			model.Parent = folder
		end
	end
	folder.Parent = view
	backdropFolder = folder
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
	local hexSize = GameConfig.Grid.HexSize
	for i = 1, #layout / 3 do
		local q, r, y = layout[i * 3 - 2], layout[i * 3 - 1], layout[i * 3]
		local flat = HexGrid.toWorld(q, r, hexSize, center)
		local base = Vector3.new(flat.X, y, flat.Z)
		local slab = place(slabTemplate, base)
		local s = (i - 1) * 5
		local plot: Plot = {
			index = i,
			q = q,
			r = r,
			ring = HexGrid.distance(q, r, 0, 0),
			side = HexGrid.side(q, r),
			base = base,
			seeds = state[s + 1],
			species = state[s + 2],
			mutation = state[s + 3],
			starterUserId = state[s + 4],
			treeSeed = state[s + 5],
			slab = slab,
			rim = nil,
			pulse = nil,
			tufts = nil,
			flowers = nil,
			border = place(borderTemplate, base),
			tree = nil,
			treeStage = 0,
			treePieces = {},
			treePivot = CFrame.new(base),
			treeSize = 1,
			treeScale = 1,
		}
		plots[i] = plot
		byKey[HexGrid.key(q, r)] = i
	end
	for _, plot in plots do
		refreshPlot(plot)
		updateTree(plot, 0)
	end
end

local function makeEffects()
	burstPart = Instance.new("Part")
	burstPart.Name = "LeafBurst"
	burstPart.Size = Vector3.one
	burstPart.Transparency = 1
	burstPart.Anchored = true
	burstPart.CanCollide = false
	burstPart.CanQuery = false
	burstPart.CanTouch = false
	burstPart.Parent = view
	burstEmitter = Instance.new("ParticleEmitter")
	burstEmitter.Rate = 0
	burstEmitter.Color = LEAF_COLORS
	burstEmitter.Size = NumberSequence.new(1.4, 0.5)
	burstEmitter.Lifetime = NumberRange.new(1, 1.6)
	burstEmitter.Speed = NumberRange.new(12, 22)
	burstEmitter.SpreadAngle = Vector2.new(180, 180)
	burstEmitter.Acceleration = Vector3.new(0, -25, 0)
	burstEmitter.Drag = 2
	burstEmitter.Rotation = NumberRange.new(0, 360)
	burstEmitter.RotSpeed = NumberRange.new(-180, 180)
	burstEmitter.Parent = burstPart
	chime = Instance.new("Sound")
	chime.SoundId = CHIME_ID
	chime.Volume = 0.6
	chime.SoundGroup = Sounds.effects()
	stageSound = Instance.new("Sound")
	stageSound.SoundId = STAGE_SOUND_ID
	stageSound.Volume = STAGE_NOTE_VOLUME
	stageSound.SoundGroup = Sounds.effects()
end

function ForestController.start()
	local forestState = ReplicatedStorage:WaitForChild("ForestState")
	-- Your carried seeds dropping means you just planted (for the stage note).
	local player = Players.LocalPlayer
	local carried = player:GetAttribute("Carried")
	player:GetAttributeChangedSignal("Carried"):Connect(function()
		local now = player:GetAttribute("Carried")
		if typeof(now) == "number" and typeof(carried) == "number" and now < carried then
			lastOwnPlant = os.clock()
		end
		carried = now
	end)
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local tile = assets:WaitForChild("Tiles"):WaitForChild("HexTile")
	slabTemplate = tile:WaitForChild("HexTile_Slab") :: BasePart
	slabTemplate.Material = SLAB_MATERIAL -- this client's copy of the template, before any tile is placed
	rimTemplate = tile:WaitForChild("HexTile_Rim") :: BasePart
	tuftsTemplate = tile:WaitForChild("HexTile_Tufts") :: BasePart
	flowersTemplate = tile:WaitForChild("HexTile_Flowers") :: BasePart
	borderTemplate = tile:WaitForChild("HexTile_Border") :: BasePart
	treeTemplates = assets:WaitForChild("Trees")
	center = forestState:GetAttribute("Center") :: Vector3
	scale = GameConfig.Grid.HexSize / TEMPLATE_HEX_SIZE
	tileTop = (slabTemplate.CFrame.Position.Y + slabTemplate.Size.Y / 2) * scale
	-- The first and last seed of each growth stage, for the current world's seeds per tree.
	local function useSeedsPerHex()
		local value = forestState:GetAttribute("SeedsPerHex")
		seedsPerHex = if typeof(value) == "number" and value > 0 then value else GameConfig.Tiers[1].SeedsPerHex
		table.clear(stageFirst)
		table.clear(stageLast)
		for seeds = 1, seedsPerHex do
			local stage = GameConfig.growthStage(seeds, seedsPerHex)
			stageFirst[stage] = stageFirst[stage] or seeds
			stageLast[stage] = seeds
		end
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
	view.Name = "ForestView"
	makeEffects()
	local row = forestState:GetAttribute("OpenRow") :: Vector2
	openRing = row.Y
	build(snapshot)
	backdropSpots = snapshot.backdrop or {}
	buildBackdrop()
	forestState:GetAttributeChangedSignal("TierId"):Connect(buildBackdrop) -- the old forest takes the new world's trees
	view.Parent = workspace
	snapshotSeq = snapshot.seq
	for _, batch in pending do
		applyBatch(batch)
	end
	table.clear(pending)
	RunService.RenderStepped:Connect(stepBounces)
	AncientTreeController.build(Vector3.new(center.X, ForestController.groundY(), center.Z))
	local open = 0
	for _, plot in plots do
		if plot.rim then
			open += 1
		end
	end
	print(`[ForestController] {#plots} tiles ({open} open) built in {math.round((os.clock() - started) * 1000)} ms`)
end

return ForestController
