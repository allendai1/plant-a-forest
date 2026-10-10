--!strict
-- TargetController: the local player's planting target (docs/plans/M4.md). Only you see your own.
-- Every frame: the closest open plot in range (the mouse doesn't choose; the user's call, 2026-10-07),
-- shown with a pulsing outline, a glowing fill over the tile and a bobbing arrow above it that shows
-- through trees (all gold when your next press finishes the tree), and a progress bar under the tree.
-- When you're carrying seeds and nothing is in range, a white, black-outlined arrow beam along the ground (spaced-out
-- chevrons scrolling toward the plot, on the treadmill arrows' beam settings) leads straight from your feet to the nearest
-- open plot (the fence doesn't block anymore), with a marker above it. Since 2026-10-07 (the user's request) that's
-- the plot you last planted into while it's still open, else the open plot closest to it, so you go back to
-- where you were working; before your first plant, the open plot closest to you. And when you're out in the forest
-- with nothing to plant, it leads back to the nearest acorn dispenser (the user got lost going back for acorns).
-- Settings can turn it off
-- (GuideArrow attribute 0), the tutorial's arrow too. Finding that plot searches the whole forest, so it only runs a few
-- times a second.
-- Seed shop (docs/plans/SeedShop.md): while you hold a special seed (SeedBagController), only Common
-- plots count as targets; the outline takes the seed's rarity color and the meter says "Plant Palm", or
-- turns red with the reason when you've already planted your special seeds for this forest.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Targeting = require(Shared.Targeting)
local Trees = require(Shared.Trees)
local ForestController = require(script.Parent.ForestController)
local SeedBagController = require(script.Parent.SeedBagController)
local UIStyle = require(script.Parent.Parent.UIStyle)

-- Look of the indicator (visual only).
local OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)
local FINISH_COLOR = Color3.fromRGB(255, 200, 40)
local REFUSED_COLOR = Color3.fromRGB(255, 70, 70)
local OUTLINE_SCALE = 1.06
local OUTLINE_LIFT = 0.3 -- raised a little above the tile's own rim height so it shows over the slab
local OUTLINE_THICK = 1.6 -- the outline is this much taller than the tile's rim
local FILL_SCALE = 0.97 -- the glowing fill covers this much of the tile
local FILL_TOP = 1.5 -- the fill's top, above the tile's base (the grass border is at 1.35)
local FILL_TRANSPARENCY = NumberRange.new(0.5, 0.75) -- the fill pulses between these
local PULSE_SPEED = 5 -- radians per second
local ARROW_HEIGHT = 13 -- the bobbing arrow floats this far above the tile
local METER_SIZE = Vector2.new(110, 14) -- the progress bar, in pixels
local METER_HEIGHT = 2.5 -- the bar floats this far above the tile's base, under the tree
local METER_COLOR = Color3.fromRGB(120, 220, 90) -- the bar's fill (FINISH_COLOR when your next press finishes it)
local ARROW_BOB = 1.2
local ARROW_COLOR = Color3.fromRGB(255, 255, 255) -- white with a black outline since 2026-10-07 (was blue)
local GUIDE_LIFT = 1.2 -- the guide beam floats this far above the feet and the tile, so tiles don't hide it
local GUIDE_WIDTH = 3.5
-- The guide's chevron (tools/make_particle_textures.py: white, pointing to the image's top, with empty
-- space below it). A beam runs the image's height along its length, top at Attachment0 (the plot), so the
-- chevrons point at the plot; checked on screen 2026-10-07. Repeated every GUIDE_SPACING studs.
-- Since 2026-10-07 the outlined one (make_particle_textures.py guide_arrow_outlined, decal 86385859634767), drawn
-- untinted; the old white-only one tinted blue was 78690048206615.
local GUIDE_TEXTURE = "rbxassetid://119862567044814"
local GUIDE_SPACING = 7
local GUIDE_SPEED = -1 -- texture lengths per second; negative moves toward Attachment0 (the plot)
local NEAREST_SECONDS = 0.25
local REACH_COLOR = Color3.fromRGB(255, 255, 255) -- the plots in planting range (showReach)
local REACH_TRANSPARENCY = 0.82
-- A see-through tree on an empty target while you carry acorns, showing what you'd plant and where, like Build the
-- Pyramid's block preview (2026-10-09, the user's idea): this world's first Common tree at this growth stage.
local PREVIEW_STAGE = 1
-- A black ghost with a black outline, so it can't pass for a real sapling (it did in its first, tree-colored version).
local PREVIEW_COLOR = Color3.fromRGB(0, 0, 0) -- black (was white; the user's call, 2026-10-09)
local PREVIEW_OUTLINE = Color3.fromRGB(0, 0, 0) -- black and fully opaque (was white; the user's call, 2026-10-09)
local PREVIEW_TRANSPARENCY = 0.4 -- 0.6 looked too faint (the user's call, 2026-10-09)
local PREVIEW_LIFT = 1.2 -- the slab's top, where trees stand

local TargetController = {}

local localPlayer = Players.LocalPlayer
local target: ForestController.Plot? = nil
local outline: BasePart
local outlineHeight = 0 -- the rim's center height above the tile's base
local fill: BasePart
local arrowGui: BillboardGui
local arrowText: TextLabel
local meter: TextLabel
local meterFill: Frame
local guideFrom: Attachment
local guideTo: Attachment
local guideBeam: Beam
local guideTurn = CFrame.identity -- how the arrow texture's attachments are turned to lie flat
local marker: BasePart
local nearest: ForestController.Plot? = nil
local guideTarget: Vector3? = nil -- set by the tutorial: lead the arrow here instead
local lastPlanted: ForestController.Plot? = nil -- where you last planted (CarryController tells us)
local HUB_RADIUS = 160 -- out past this from the World Tree (the forest), empty hands get an arrow to a dispenser
local nearestRack: Vector3? = nil
local lastNearest = 0

function TargetController.getTarget(): ForestController.Plot?
	return target
end

local function attribute(name: string): number
	local value = localPlayer:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

-- Can the held special seed go into the target now? (The server checks again.)
function TargetController.canPlantSpecial(): boolean
	return target ~= nil and SeedBagController.held() ~= nil and attribute("SpecialsPlanted") < GameConfig.SeedShop.PerForestLimit
end

-- An open plot you can plant into: with a special seed in hand, only Common ones.
local function plantable(plot: ForestController.Plot): boolean
	return ForestController.isOpenPlot(plot) and not (SeedBagController.held() and Trees.isSpecial(plot.species))
end

local function plantableAt(q: number, r: number): boolean
	local plot = ForestController.plotAt(q, r)
	return plot ~= nil and plantable(plot)
end

-- The tutorial (M10) points the guide arrow at a spot on the ground (an acorn pile, the training pad,
-- the shop), or gives it back with nil.
-- CarryController: a plant request went to this plot.
function TargetController.notePlanted(plot: ForestController.Plot)
	lastPlanted = plot
end

function TargetController.setGuideTarget(position: Vector3?)
	guideTarget = position
end

-- Your value for an upgrade, from your level attribute (the server sets it).
local function upgradeValue(upgradeId: string): number
	local level = localPlayer:GetAttribute(upgradeId .. "Level")
	return GameConfig.upgradeValue(upgradeId, if typeof(level) == "number" then level else 0)
end

local function rangeStuds(): number
	return GameConfig.Planting.BaseRangeStuds + upgradeValue("PlantingRange")
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local inReach: { Targeting.Candidate } = {} -- every open plot in planting range this frame (showReach)

local function chooseTarget(root: BasePart): ForestController.Plot?
	local found = Targeting.openNear(root.Position, rangeStuds(), GameConfig.Grid.HexSize, ForestController.center(), plantableAt)
	inReach = found
	local first = found[1]
	return if first then ForestController.plotAt(first.q, first.r) else nil
end

local function nearestOpen(position: Vector3): ForestController.Plot?
	local best: ForestController.Plot? = nil
	local bestDistance = math.huge
	for _, plot in ForestController.allPlots() do
		if plantable(plot) then
			local distance = flatDistance(position, plot.base)
			if distance < bestDistance then
				best, bestDistance = plot, distance
			end
		end
	end
	return best
end

local function makePart(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function build()
	local folder = Instance.new("Folder")
	folder.Name = "TargetIndicator"
	folder.Parent = workspace

	local rim =
		ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Tiles"):WaitForChild("HexTile"):WaitForChild("HexTile_Rim") :: BasePart
	outline = rim:Clone()
	outline.Name = "Outline"
	local scale = GameConfig.Grid.HexSize / 16 -- the Blender tile was modeled for HexSize 16
	outline.Size = rim.Size * scale * Vector3.new(OUTLINE_SCALE, OUTLINE_THICK, OUTLINE_SCALE)
	outlineHeight = rim.CFrame.Position.Y * scale
	outline.Material = Enum.Material.Neon
	outline.Color = OUTLINE_COLOR
	outline.Anchored = true
	outline.CanCollide = false
	outline.CanQuery = false
	outline.CastShadow = false
	outline.Transparency = 1
	outline.Parent = folder
	-- The tree's progress: a slim bar low on the tile, under the tree (2026-10-09, the user's ask; was a "12 / 40"
	-- label up at 7 studs). The label only shows text while holding a special seed.
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(METER_SIZE.X, METER_SIZE.Y)
	gui.StudsOffsetWorldSpace = Vector3.new(0, METER_HEIGHT, 0)
	gui.AlwaysOnTop = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- the fill draws over the bar's background
	gui.Enabled = false
	gui.Adornee = outline
	gui.Parent = outline
	meter = Instance.new("TextLabel")
	meter.Size = UDim2.fromScale(1, 1)
	meter.BackgroundColor3 = Color3.fromRGB(20, 26, 20)
	meter.BackgroundTransparency = 0.25
	meter.TextColor3 = Color3.new(1, 1, 1)
	meter.Font = UIStyle.FONT
	meter.TextScaled = true
	meter.Parent = gui
	UIStyle.corner(meter, METER_SIZE.Y // 2)
	UIStyle.stroke(meter, 2, UIStyle.BLACK)
	meterFill = Instance.new("Frame")
	meterFill.BorderSizePixel = 0
	meterFill.Size = UDim2.fromScale(0, 1)
	meterFill.Parent = meter
	UIStyle.corner(meterFill, METER_SIZE.Y // 2)

	-- The glowing fill: a thin copy of the tile's slab laid over the tile.
	local slab = (rim.Parent :: Instance):FindFirstChild("HexTile_Slab") :: BasePart
	fill = slab:Clone()
	fill.Name = "Fill"
	fill.Size = Vector3.new(slab.Size.X * scale * FILL_SCALE, 0.2, slab.Size.Z * scale * FILL_SCALE)
	fill.Material = Enum.Material.Neon
	fill.Anchored, fill.CanCollide, fill.CanQuery, fill.CanTouch, fill.CastShadow = true, false, false, false, false
	fill.Transparency = 1
	fill.Parent = folder
	-- The arrow above the target, seen through trees.
	arrowGui = Instance.new("BillboardGui")
	arrowGui.Name = "TargetArrow"
	arrowGui.Size = UDim2.fromOffset(56, 56)
	arrowGui.AlwaysOnTop = true
	arrowGui.Enabled = false
	arrowGui.Adornee = outline
	arrowGui.Parent = outline
	arrowText = Instance.new("TextLabel")
	arrowText.Size = UDim2.fromScale(1, 1)
	arrowText.BackgroundTransparency = 1
	arrowText.Text = "▼"
	arrowText.TextScaled = true
	arrowText.TextColor3 = OUTLINE_COLOR
	arrowText.TextStrokeTransparency = 0.2
	arrowText.Parent = arrowGui

	-- The guide beam runs between two attachments on the terrain (world positions set each frame).
	local terrain = workspace.Terrain
	guideFrom = Instance.new("Attachment")
	guideFrom.Name = "GuideFrom"
	guideFrom.Parent = terrain
	guideTo = Instance.new("Attachment")
	guideTo.Name = "GuideTo"
	guideTo.Parent = terrain
	local arrows = ReplicatedStorage.Assets:FindFirstChild("Lobby")
	arrows = arrows and arrows:FindFirstChild("TreadmillArrows")
	local template = arrows and arrows:FindFirstChildOfClass("Beam")
	local turn = arrows and arrows:FindFirstChild("Turn")
	guideBeam = if template then template:Clone() else Instance.new("Beam")
	if turn and turn:IsA("Attachment") then
		guideTurn = turn.CFrame
	end
	guideBeam.Name = "GuideBeam"
	guideBeam.Color = ColorSequence.new(ARROW_COLOR)
	guideBeam.LightEmission = 0 -- additive light would make the black outline invisible
	guideBeam.LightInfluence = 0 -- full brightness at night too
	guideBeam.Transparency = NumberSequence.new(0)
	guideBeam.Width0, guideBeam.Width1 = GUIDE_WIDTH, GUIDE_WIDTH
	guideBeam.Texture = GUIDE_TEXTURE
	guideBeam.TextureLength = GUIDE_SPACING
	guideBeam.TextureSpeed = GUIDE_SPEED
	guideBeam.Attachment0, guideBeam.Attachment1 = guideTo, guideFrom -- scrolls toward Attachment0: the plot
	guideBeam.Enabled = false
	guideBeam.Parent = terrain

	marker = makePart("Marker", Vector3.new(1, 1, 1), ARROW_COLOR, folder)
	marker.Transparency = 1
	local markerGui = Instance.new("BillboardGui")
	markerGui.Size = UDim2.fromOffset(48, 48)
	markerGui.AlwaysOnTop = true
	markerGui.Enabled = false
	markerGui.Adornee = marker
	markerGui.Parent = marker
	local markerText = Instance.new("TextLabel")
	markerText.Size = UDim2.fromScale(1, 1)
	markerText.BackgroundTransparency = 1
	markerText.Text = "▼"
	markerText.TextScaled = true
	markerText.TextColor3 = ARROW_COLOR
	markerText.TextStrokeTransparency = 0
	markerText.Parent = markerGui
end

local preview: Model? = nil
local previewOf: Model? = nil -- the template it was copied from (a new world or the next stage changes it)

-- Empty tile: a sapling at its center. Started tree (2026-10-09, the user's ask): its next growth stage, where and
-- as big as the real tree will stand, so you see what your acorns grow it into. Full grown: nothing.
local function showPreview(plot: ForestController.Plot?, seedsPerHex: number)
	local carried = localPlayer:GetAttribute("Carried")
	local show = plot ~= nil and typeof(carried) == "number" and carried > 0 and not SeedBagController.held()
	local template: Model? = nil
	if show and plot then
		local stage = GameConfig.growthStage(plot.seeds, seedsPerHex)
		if stage == 0 then
			template = ForestController.previewTemplate(PREVIEW_STAGE, 0)
		elseif stage < #GameConfig.Growth.StageStarts then
			template = ForestController.previewTemplate(stage + 1, plot.species)
		end
	end
	if template ~= previewOf then
		if preview then
			preview:Destroy()
			preview = nil
		end
		previewOf = template
		if template then
			local model = template:Clone()
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
					part.CastShadow = false
					part.Transparency = PREVIEW_TRANSPARENCY
					part.Color = PREVIEW_COLOR
					part.Material = Enum.Material.SmoothPlastic
				end
			end
			local edge = Instance.new("Highlight")
			edge.FillTransparency = 1
			edge.OutlineColor = PREVIEW_OUTLINE
			edge.OutlineTransparency = 0
			edge.DepthMode = Enum.HighlightDepthMode.Occluded
			edge.Parent = model
			model.Parent = fill.Parent
			preview = model
		end
	end
	if preview and plot then
		local size = if plot.seeds == 0 then 1 else plot.treeSize
		if preview:GetScale() ~= size then
			preview:ScaleTo(size)
		end
		preview:PivotTo(if plot.seeds == 0 then CFrame.new(plot.base + Vector3.new(0, PREVIEW_LIFT, 0)) else plot.treePivot)
	end
end

local function showTarget(plot: ForestController.Plot?)
	local gui = meter:FindFirstAncestorOfClass("BillboardGui")
	if not plot then
		showPreview(nil, 0)
		outline.Transparency = 1
		fill.Transparency = 1
		arrowGui.Enabled = false
		if gui then
			gui.Enabled = false
		end
		return
	end
	local perHex = ReplicatedStorage:WaitForChild("ForestState"):GetAttribute("SeedsPerHex")
	local seedsPerHex = if typeof(perHex) == "number" then perHex else GameConfig.Tiers[1].SeedsPerHex
	showPreview(plot, seedsPerHex)
	local carried = localPlayer:GetAttribute("Carried")
	local press = math.min(upgradeValue("BulkPlant"), if typeof(carried) == "number" then carried else 0)
	local finishes = plot.seeds + math.max(press, 1) >= seedsPerHex
	outline.CFrame = CFrame.new(plot.base + Vector3.new(0, outlineHeight + OUTLINE_LIFT, 0))
	outline.Color = if finishes then FINISH_COLOR else OUTLINE_COLOR
	outline.Transparency = 0
	meter.Text = ""
	meterFill.Visible = true
	meterFill.Size = UDim2.fromScale(math.clamp(plot.seeds / seedsPerHex, 0, 1), 1)
	meterFill.BackgroundColor3 = if finishes then FINISH_COLOR else METER_COLOR
	local def = GameConfig.seedDef(SeedBagController.held() or "")
	if def then
		meterFill.Visible = false
		local allowed = TargetController.canPlantSpecial()
		outline.Color = if allowed then Trees.RarityColors[def.Rarity] else REFUSED_COLOR
		meter.Text = if allowed then `Plant {def.DisplayName}` else `{GameConfig.SeedShop.PerForestLimit} per forest`
	end
	if gui then
		gui.Enabled = true
	end
	-- Fill and arrow in the outline's color, pulsing and bobbing so the target reads at a glance.
	local wave = (math.sin(os.clock() * PULSE_SPEED) + 1) / 2
	fill.CFrame = CFrame.new(plot.base + Vector3.new(0, FILL_TOP - fill.Size.Y / 2, 0))
	fill.Color = outline.Color
	fill.Transparency = FILL_TRANSPARENCY.Min + (FILL_TRANSPARENCY.Max - FILL_TRANSPARENCY.Min) * wave
	outline.Transparency = 0.25 * wave
	arrowText.TextColor3 = outline.Color
	arrowGui.StudsOffsetWorldSpace = Vector3.new(0, ARROW_HEIGHT + ARROW_BOB * wave, 0)
	arrowGui.Enabled = true
end

local function showGuide(root: BasePart?, spot: Vector3?)
	local gui = marker:FindFirstChildOfClass("BillboardGui")
	if not root or not spot then
		guideBeam.Enabled = false
		if gui then
			gui.Enabled = false
		end
		return
	end
	local from = Vector3.new(root.Position.X, root.Position.Y - 2.8 + GUIDE_LIFT, root.Position.Z)
	local to = spot + Vector3.new(0, 1.2 + GUIDE_LIFT, 0)
	local flat = Vector3.new(from.X - to.X, 0, from.Z - to.Z)
	if flat.Magnitude < 0.01 then
		return
	end
	-- Both ends look from the plot (Attachment0) toward the player (Attachment1), like the treadmill
	-- arrows look from the back of the belt (Attachment0) toward the console (Attachment1).
	guideTo.WorldCFrame = CFrame.lookAt(to, to + flat) * guideTurn
	guideFrom.WorldCFrame = CFrame.lookAt(from, from + flat) * guideTurn
	guideBeam.Enabled = true
	marker.CFrame = CFrame.new(spot + Vector3.new(0, 10, 0))
	if gui then
		gui.Enabled = true
	end
end

-- Every other open plot you could plant into from where you stand, faintly lit while you carry acorns (2026-10-09):
-- each Planting Range level reaches one more tree, and this shows it. Copies of the target's fill, pooled.
local reachParts: { BasePart } = {}
local function showReach(on: boolean)
	local count = 0
	local list: { Targeting.Candidate } = if on then inReach else {}
	for _, candidate in list do
		local plot = ForestController.plotAt(candidate.q, candidate.r)
		if plot and plot ~= target then
			count += 1
			local part: BasePart = reachParts[count] or fill:Clone()
			if not reachParts[count] then
				part.Name = "Reach"
				part.Color = REACH_COLOR
				part.Parent = fill.Parent
				reachParts[count] = part
			end
			part.Transparency = REACH_TRANSPARENCY
			part.CFrame = CFrame.new(plot.base + Vector3.new(0, FILL_TOP - part.Size.Y / 2, 0))
		end
	end
	for i = count + 1, #reachParts do
		reachParts[i].Transparency = 1
	end
end

local function step()
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not ForestController.ready() or not (root and root:IsA("BasePart")) then
		target = nil
		showReach(false)
		showTarget(nil)
		showGuide(nil, nil)
		return
	end
	target = chooseTarget(root)
	showTarget(target)

	local carried = localPlayer:GetAttribute("Carried")
	local carrying = typeof(carried) == "number" and carried > 0 or SeedBagController.held() ~= nil
	showReach(carrying)
	local arrowOn = localPlayer:GetAttribute("GuideArrow") ~= 0 -- it can be turned off in Settings
	if arrowOn and guideTarget then
		showGuide(root, guideTarget)
	elseif arrowOn and carrying and not target then
		if os.clock() - lastNearest >= NEAREST_SECONDS then
			lastNearest = os.clock()
			-- Back to where you were planting: that plot while it's open, else the open plot nearest to it.
			local last = lastPlanted
			nearest = if last and plantable(last) then last else nearestOpen(if last then last.base else root.Position)
		end
		local plot = nearest
		showGuide(root, if plot then plot.base else nil)
	elseif arrowOn and not carrying and flatDistance(root.Position, ForestController.center()) > HUB_RADIUS then
		-- Out in the forest with empty hands: back to the nearest acorn dispenser.
		if os.clock() - lastNearest >= NEAREST_SECONDS then
			lastNearest = os.clock()
			nearestRack = nil
			local best = math.huge
			for _, rack in CollectionService:GetTagged("SeedRack") do
				local spot = if rack:IsA("Model") then rack:GetPivot().Position else nil
				if spot and flatDistance(root.Position, spot) < best then
					nearestRack, best = spot, flatDistance(root.Position, spot)
				end
			end
		end
		showGuide(root, nearestRack)
	else
		showGuide(nil, nil)
	end
end

function TargetController.start()
	build()
	RunService.RenderStepped:Connect(step)
end

return TargetController
