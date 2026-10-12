--!strict
-- TargetController: the local player's planting target (docs/plans/M4.md). Only you see your own. Since 2026-10-10
-- the targets are bridge slots (BridgeController): a square outline, and a see-through plank where your next one goes.
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
local BridgeController = require(script.Parent.BridgeController)
local SeedBagController = require(script.Parent.SeedBagController)
local UIStyle = require(script.Parent.Parent.UIStyle)

-- Look of the indicator (visual only).
-- Green like Build the Pyramid's block placement (2026-10-10, the user's pick; was white, and yellow when the press
-- finishes the slot). One color either way now.
local OUTLINE_COLOR = Color3.fromRGB(110, 240, 110)
local FINISH_COLOR = OUTLINE_COLOR
local REFUSED_COLOR = Color3.fromRGB(255, 70, 70)
local OUTLINE_SCALE = 1.04
local OUTLINE_THICK = 0.6 -- the outline box's height, centered on the deck
local FILL_SCALE = 0.97 -- the glowing fill covers this much of the slot
local FILL_TOP = 0.15 -- the fill's top, above the deck
local FILL_TRANSPARENCY = NumberRange.new(0.78, 0.9) -- the fill pulses between these (faint for the green: the edges lead)
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
-- A see-through plank where your next one lands while you carry planks, like Build the Pyramid's block preview (the
-- forest's see-through sapling, 2026-10-09, the user's idea). Black, so it can't pass for a real plank.
local PREVIEW_COLOR = Color3.fromRGB(0, 0, 0)
local PREVIEW_TRANSPARENCY = 0.4

local TargetController = {}

local localPlayer = Players.LocalPlayer
local target: BridgeController.Plot? = nil
local outline: BasePart -- invisible; its SelectionBox (outlineBox) draws the square
local outlineBox: SelectionBox
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
local nearest: BridgeController.Plot? = nil
local guideTarget: Vector3? = nil -- set by the tutorial: lead the arrow here instead
local lastPlanted: BridgeController.Plot? = nil -- where you last planted (CarryController tells us)
local HUB_RADIUS = 160 -- out past this from the hub's center (on the bridge), empty hands get an arrow to a dispenser
local nearestRack: Vector3? = nil
local lastNearest = 0

function TargetController.getTarget(): BridgeController.Plot?
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
local function plantable(plot: BridgeController.Plot): boolean
	return BridgeController.isOpenPlot(plot) and not (SeedBagController.held() and Trees.isSpecial(plot.species))
end

local function plantableAt(q: number, r: number): boolean
	local plot = BridgeController.plotAt(q, r)
	return plot ~= nil and plantable(plot)
end

-- The tutorial (M10) points the guide arrow at a spot on the ground (an acorn pile, the training pad,
-- the shop), or gives it back with nil.
-- CarryController: a plant request went to this plot.
function TargetController.notePlanted(plot: BridgeController.Plot)
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

local function chooseTarget(root: BasePart): BridgeController.Plot?
	local found = Targeting.openNear(root.Position, rangeStuds(), BridgeController.frame(), plantableAt)
	inReach = found
	local first = found[1]
	return if first then BridgeController.plotAt(first.q, first.r) else nil
end

local function nearestOpen(position: Vector3): BridgeController.Plot?
	local best: BridgeController.Plot? = nil
	local bestDistance = math.huge
	for _, plot in BridgeController.allPlots() do
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

	local slot = GameConfig.Grid.SlotStuds
	outline = makePart("Outline", Vector3.new(slot * OUTLINE_SCALE, OUTLINE_THICK, slot * OUTLINE_SCALE), OUTLINE_COLOR, folder)
	outline.Transparency = 1
	outlineBox = Instance.new("SelectionBox")
	outlineBox.Adornee = outline
	outlineBox.LineThickness = 0.25
	outlineBox.SurfaceTransparency = 1
	outlineBox.Color3 = OUTLINE_COLOR
	outlineBox.Visible = false
	outlineBox.Parent = outline
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

	-- The glowing fill laid over the slot.
	fill = makePart("Fill", Vector3.new(slot * FILL_SCALE, 0.2, slot * FILL_SCALE), OUTLINE_COLOR, folder)
	fill.Transparency = 1
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

local preview: BasePart? = nil

-- The plank your next press adds to the slot, see-through, while you carry planks. Nothing on a full slot.
local function showPreview(plot: BridgeController.Plot?)
	local carried = localPlayer:GetAttribute("Carried")
	local show = plot ~= nil and typeof(carried) == "number" and carried > 0 and not SeedBagController.held()
	local nextPlank = if show and plot then BridgeController.nextPlank(plot) else 0
	if nextPlank == 0 or not plot then
		if preview then
			preview.Transparency = 1
		end
		return
	end
	local ghost = preview or makePart("Preview", Vector3.one, PREVIEW_COLOR, fill.Parent :: Instance)
	ghost.Material = Enum.Material.SmoothPlastic
	preview = ghost
	local cframe, size = BridgeController.plankAt(plot, nextPlank)
	ghost.Size = size
	ghost.CFrame = cframe
	ghost.Transparency = PREVIEW_TRANSPARENCY
end

local function showTarget(plot: BridgeController.Plot?)
	local gui = meter:FindFirstAncestorOfClass("BillboardGui")
	if not plot then
		showPreview(nil)
		outlineBox.Visible = false
		fill.Transparency = 1
		arrowGui.Enabled = false
		if gui then
			gui.Enabled = false
		end
		return
	end
	local perHex = ReplicatedStorage:WaitForChild("ForestState"):GetAttribute("SeedsPerHex")
	local seedsPerHex = if typeof(perHex) == "number" then perHex else GameConfig.Tiers[1].SeedsPerHex
	showPreview(plot)
	local carried = localPlayer:GetAttribute("Carried")
	local press = math.min(upgradeValue("BulkPlant"), if typeof(carried) == "number" then carried else 0)
	local finishes = plot.seeds + math.max(press, 1) >= seedsPerHex
	outline.CFrame = plot.frame
	outline.Color = if finishes then FINISH_COLOR else OUTLINE_COLOR
	outlineBox.Visible = true
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
		-- No bar when one plank fills a section (a solo server; the user's call, 2026-10-10): it'd only ever be empty.
		gui.Enabled = seedsPerHex > 1 or def ~= nil
	end
	-- Fill and arrow in the outline's color, pulsing and bobbing so the target reads at a glance.
	local wave = (math.sin(os.clock() * PULSE_SPEED) + 1) / 2
	fill.CFrame = plot.frame * CFrame.new(0, FILL_TOP - fill.Size.Y / 2, 0)
	fill.Color = outline.Color
	fill.Transparency = FILL_TRANSPARENCY.Min + (FILL_TRANSPARENCY.Max - FILL_TRANSPARENCY.Min) * wave
	outlineBox.Color3 = outline.Color
	outlineBox.Transparency = 0.25 * wave
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

-- The other slots your next press fills, lit like the target (2026-10-10, the user's call; every open slot in planting
-- range was faintly lit until then): Bulk Plant's planks past the target overflow into the next-closest open slots,
-- in the server's order (ForestService onPlantSeeds). Copies of the target's fill and outline, pooled.
local reachParts: { BasePart } = {}
local reachOutlines: { SelectionBox } = {}
local function showReach(on: boolean)
	local count = 0
	local perHex = ReplicatedStorage:WaitForChild("ForestState"):GetAttribute("SeedsPerHex")
	local seedsPerHex = if typeof(perHex) == "number" then perHex else GameConfig.Tiers[1].SeedsPerHex
	local remaining = if on and target and not SeedBagController.held()
		then math.min(upgradeValue("BulkPlant"), attribute("Carried")) - math.max(seedsPerHex - target.seeds, 0)
		else 0
	for _, candidate in inReach do
		if remaining <= 0 then
			break
		end
		local plot = BridgeController.plotAt(candidate.q, candidate.r)
		if plot and plot ~= target and plot.seeds < seedsPerHex then
			remaining -= seedsPerHex - plot.seeds
			count += 1
			local part: BasePart = reachParts[count] or fill:Clone()
			if not reachParts[count] then
				part.Name = "Reach"
				part.Parent = fill.Parent
				reachParts[count] = part
			end
			part.Color, part.Transparency = fill.Color, fill.Transparency -- pulsing with the target
			part.CFrame = plot.frame * CFrame.new(0, FILL_TOP - part.Size.Y / 2, 0)
			local box = reachOutlines[count]
			if not box then
				local holder = outline:Clone()
				holder.Name = "ReachOutline"
				for _, child in holder:GetChildren() do
					if not child:IsA("SelectionBox") then
						child:Destroy() -- the target's own arrow and bar ride on its outline part
					end
				end
				holder.Parent = outline.Parent
				box = holder:FindFirstChildOfClass("SelectionBox") :: SelectionBox
				box.Adornee = holder
				reachOutlines[count] = box
			end
			(box.Adornee :: BasePart).CFrame = plot.frame
			box.Color3, box.Transparency, box.Visible = outlineBox.Color3, outlineBox.Transparency, true
		end
	end
	for i = count + 1, #reachParts do
		reachParts[i].Transparency = 1
		reachOutlines[i].Visible = false
	end
end

local function step()
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not BridgeController.ready() or not (root and root:IsA("BasePart")) then
		target = nil
		showReach(false)
		showTarget(nil)
		showGuide(nil, nil)
		return
	end
	target = chooseTarget(root)
	local carried = localPlayer:GetAttribute("Carried")
	local carrying = typeof(carried) == "number" and carried > 0 or SeedBagController.held() ~= nil
	-- The target's outline, glow and arrow only while you have planks to place (2026-10-10, the user's call: they showed
	-- with empty hands too).
	showTarget(if carrying then target else nil)
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
	elseif arrowOn and not carrying and flatDistance(root.Position, BridgeController.center()) > HUB_RADIUS then
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
