--!strict
-- AncientTreeController: the world tree in the hub (docs/plans/M5.md).
-- It grows with the Forest Bar (Seeds / Target): each of its 4 models covers a quarter of the bar and
-- scales up smoothly inside it, starting at the size the previous model ended, so a swap is never a
-- jump. AncientBase (rune circle, stones, flowers) never grows. The section complete moment plays shake().
-- Everything is drawn at FINAL_SCALE (2026-10-08): the full-grown tree and its rune circle at 60% of the models,
-- so the garden has room for the training pads around it (roots ~46 studs out, the pads from 54).
-- ForestController calls build() once it knows the ground height (the plots' heights from the server).
-- setAwakened() (M6) is the forest complete look: the glow (rune circle included) brightens and lights
-- up, the canopy blooms, and soft shafts of light with drifting motes pour down from under the
-- canopy. When the forest
-- resets, the tree shrinks back to a sapling over SHRINK_TWEEN instead of the usual quick tween.
-- A "World Tree" name label (2026-10-07) floats just above the tree's top at every size (2026-10-08, the user's
-- ask; it used to stop at 45 studs up), the size of the lobby's other signs; it shows through the canopy.
-- Each world has its own World Tree (GameConfig.Tiers[].WorldTree, the model prefix): Sherwood's Ancient1-4,
-- Kyoto's AncientSakura1-4, a bonsai-like cherry blossom with falling petals and pink sparkles from its crown
-- and a pink glow; the Great Smoky Mountains' AncientMaple1-4, a giant maple dropping orange leaves with an
-- amber glow (VARIANT_LOOK). When the world changes, the swap waits for the tree to shrink to a sapling.
-- Standing in the spring circle (within SpringRadiusStuds of the trunk) fades the tree (not its base) to see-through for you
-- (2026-10-08, the user's ask), so it doesn't fill your screen; it uses LocalTransparencyModifier, so it's only local.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local UIStyle = require(script.Parent.Parent.UIStyle)

-- Look (visual only).
local FINAL_SCALE = 0.6 -- the whole World Tree (and its base) at this size; keep GameConfig SpringRadiusStuds inside it
local SAPLING_SCALE = 0.5 -- Ancient1's size at 0%, before FINAL_SCALE (about 16 studs tall)
local GROW_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SHRINK_TWEEN = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local AWAKE_TWEEN = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local AWAKE_GLOW = Color3.fromRGB(200, 255, 245)
local BLOSSOM = Color3.fromRGB(255, 175, 215)
local BLOSSOM_MIX = 0.35 -- how far the canopy turns toward BLOSSOM
local BLOOM_SCALE = 1.06
local BEAM_COLOR = ColorSequence.new(Color3.fromRGB(255, 240, 190), Color3.fromRGB(190, 255, 240))
local BEAM_FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.55), -- brightest under the canopy
	NumberSequenceKeypoint.new(0.6, 0.75),
	NumberSequenceKeypoint.new(1, 1), -- fading out at the ground
})
local BEAM_COUNT = 10
local BEAM_TOP = 0.57 -- the shafts start at the canopy's underside, this fraction of the tree's height
local BEAM_SPREAD = { 60 * FINAL_SCALE, 115 * FINAL_SCALE } -- distance from the trunk at the top and at the ground
local BEAM_WIDTH = { 16 * FINAL_SCALE, 34 * FINAL_SCALE } -- each shaft's width at the top and at the ground
local MOTE_AREA = 220 * FINAL_SCALE -- motes fall from a square this wide under the canopy
local SHAKE_SECONDS = 0.8
local SHAKE_ANGLE = math.rad(1.5)
local SHAKE_SPEED = 30
local LABEL_TEXT = "World Tree"
local LABEL_COLOR = Color3.fromRGB(120, 255, 220)
local LABEL_ABOVE = 8 -- studs above the tree's top
local LABEL_SIZE = UDim2.fromOffset(220, 44) -- the same as the UPGRADES sign (tools/build_map.luau)
local LABEL_DISTANCE = 500 -- a full-grown tree's top is ~220 studs up

-- Each World Tree's look: its glow (also the rune circle under it), the awakened glow, the label color, and
-- whether petals and sparkles fall from its crown.
-- petalColors / sparkleColors: the falling petals' (or leaves') and sparkles' colors, from-to.
type VariantLook = {
	glow: Color3?,
	awake: Color3,
	blossom: Color3,
	label: Color3,
	petals: boolean,
	petalColors: { Color3 }?,
	sparkleColors: { Color3 }?,
}
local VARIANT_LOOK: { [string]: VariantLook } = {
	Ancient = { glow = nil, awake = AWAKE_GLOW, blossom = BLOSSOM, label = LABEL_COLOR, petals = false },
	AncientSakura = {
		glow = Color3.fromRGB(255, 120, 200),
		awake = Color3.fromRGB(255, 200, 235),
		blossom = Color3.fromRGB(255, 245, 250),
		label = Color3.fromRGB(255, 160, 210),
		petals = true,
		petalColors = { Color3.fromRGB(255, 200, 225), Color3.fromRGB(245, 120, 165) },
		sparkleColors = { Color3.fromRGB(255, 190, 230), Color3.fromRGB(255, 120, 200) },
	},
	AncientMaple = { -- the Great Smoky Mountains: falling orange and red leaves, amber sparkles
		glow = Color3.fromRGB(255, 170, 60),
		awake = Color3.fromRGB(255, 215, 140),
		blossom = Color3.fromRGB(255, 200, 90),
		label = Color3.fromRGB(255, 175, 80),
		petals = true,
		petalColors = { Color3.fromRGB(245, 140, 40), Color3.fromRGB(205, 52, 36) },
		sparkleColors = { Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 160, 50) },
	},
}
local PETAL_TEXTURE = "rbxassetid://130093552340519" -- the shop Cherry Blossom's petals
local SPARKLE_TEXTURE = "rbxassetid://88252539838654"
local PETAL_RATE = { 3, 40 } -- per second, from the sapling to full grown
local SWAP_WAIT_SECONDS = 4 -- a world change waits this long at most for the tree to shrink first
local INSIDE_FADE = 0.75 -- how see-through the tree gets while you stand in the spring circle (1 = invisible)
local INSIDE_HEIGHT = 30 -- the circle counts up to this far above the Spring's floor (TrainingService SPRING_HEIGHT)
local FADE_RATE = 6 -- how fast the fade follows you in and out (higher is quicker)

local AncientTreeController = {}

type Variant = { models: { Model }, heights: { number } }
local variants: { [string]: Variant } = {}
local variantName = "Ancient"
local models: { Model } = {}
local heights: { number } = {}
local blossomPart: Part? = nil -- the petals and sparkles fall from this, over the crown
local labelText: TextLabel? = nil
local baseGlows: { BasePart } = {} -- the rune circle's glow parts (recolored per world)
local shown: Model? = nil
local folder: Folder
local root = CFrame.identity
local tilt = 0
local progress: NumberValue? = nil
local bloom: NumberValue
local originals: { [BasePart]: Color3 } = {} -- glow and leaf colors from the assets
local beam: Part? = nil -- holds the light shafts' attachments and the falling motes
local labelAnchor: Part? = nil -- the World Tree label hangs on this

local function setup(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanTouch = false
			-- Nothing is solid, the trunk and roots included: players walk right into the tree (2026-10-08, the
			-- user's call; the trunk used to collide). The camera ignores it too.
			part.CanCollide = false
			part.CanQuery = false
		end
	end
end

local function apply()
	if not progress then
		return
	end
	local count = #models
	local p = math.clamp(progress.Value, 0, 1)
	local k = math.min(math.floor(p * count) + 1, count)
	local within = p * count - (k - 1)
	local from = if k == 1 then SAPLING_SCALE else heights[k - 1] / heights[k]
	local model = models[k]
	if shown ~= model then
		if shown then
			shown.Parent = nil
		end
		model.Parent = folder
		shown = model
	end
	model:ScaleTo((from + (1 - from) * within) * bloom.Value * FINAL_SCALE)
	model:PivotTo(root * CFrame.Angles(tilt, 0, tilt * 0.6))
	if labelAnchor then
		local height = model:GetExtentsSize().Y
		labelAnchor.CFrame = root + Vector3.new(0, height + LABEL_ABOVE, 0)
	end
	local petals = blossomPart
	if petals then
		-- Over the crown: the top part of the tree's box, as wide as most of the crown.
		local box, size = model:GetBoundingBox()
		petals.CFrame = CFrame.new(box.Position + Vector3.new(0, size.Y * 0.2, 0))
		petals.Size = Vector3.new(size.X * 0.7, 1, size.Z * 0.7)
		local grown = math.clamp(size.Y / (heights[#heights] * FINAL_SCALE), 0, 1)
		for _, emitter in petals:GetChildren() do
			if emitter:IsA("ParticleEmitter") then
				local full = if emitter.Name == "Petals" then PETAL_RATE[2] else PETAL_RATE[2] / 4
				emitter.Rate = PETAL_RATE[1] + (full - PETAL_RATE[1]) * grown
			end
		end
	end
end

-- Falling petals and drifting sparkles over a World Tree's crown (VARIANT_LOOK.petals).
local function buildBlossomPart(look: VariantLook): Part
	local part = Instance.new("Part")
	part.Name = "WorldTreePetals"
	part.Transparency = 1
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.CastShadow = false
	local petals = Instance.new("ParticleEmitter")
	petals.Name = "Petals"
	petals.Texture = PETAL_TEXTURE
	local petalColors = look.petalColors or { Color3.fromRGB(255, 200, 225), Color3.fromRGB(245, 120, 165) }
	petals.Color = ColorSequence.new(petalColors[1], petalColors[2])
	petals.LightInfluence = 1
	petals.Size = NumberSequence.new(2.2)
	petals.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.85, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	petals.Lifetime = NumberRange.new(10, 14)
	petals.Speed = NumberRange.new(1, 3)
	petals.Acceleration = Vector3.new(1.2, -3, 0.4)
	petals.Drag = 0.25
	petals.Rotation = NumberRange.new(0, 360)
	petals.RotSpeed = NumberRange.new(-90, 90)
	petals.EmissionDirection = Enum.NormalId.Bottom
	petals.SpreadAngle = Vector2.new(180, 180)
	petals.Parent = part
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Texture = SPARKLE_TEXTURE
	local sparkleColors = look.sparkleColors or { Color3.fromRGB(255, 190, 230), Color3.fromRGB(255, 120, 200) }
	sparkles.Color = ColorSequence.new(sparkleColors[1], sparkleColors[2])
	sparkles.LightEmission, sparkles.LightInfluence = 1, 0
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 3),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Lifetime = NumberRange.new(2, 3.5)
	sparkles.Speed = NumberRange.new(0.5, 2)
	sparkles.Acceleration = Vector3.new(0, -1, 0)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = part
	return part
end

-- The model set of a World Tree (<name>1-4 in Assets.AncientTree), loaded the first time it's needed.
local function variantOf(name: string): Variant?
	local existing = variants[name]
	if existing then
		return existing
	end
	local assets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("AncientTree")
	local set: Variant = { models = {}, heights = {} }
	for i = 1, 4 do
		local template = assets:FindFirstChild(`{name}{i}`)
		if not (template and template:IsA("Model")) then
			return nil
		end
		local model = template:Clone()
		setup(model)
		set.models[i] = model
		set.heights[i] = model:GetExtentsSize().Y
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and (string.find(part.Name, "_Glow") or string.find(part.Name, "_Leaves")) then
				originals[part] = part.Color
			end
		end
	end
	variants[name] = set
	return set
end

-- Shows this world's World Tree (and its look) from now on.
local function setVariant(name: string)
	local set = variantOf(name) or variantOf("Ancient")
	if not set then
		return
	end
	variantName = if variants[name] then name else "Ancient"
	local look = VARIANT_LOOK[variantName] or VARIANT_LOOK.Ancient
	if shown then
		shown.Parent = nil
		shown = nil
	end
	models, heights = set.models, set.heights
	for _, part in baseGlows do
		part.Color = look.glow or originals[part] or part.Color
	end
	if labelText then
		labelText.TextColor3 = look.label
	end
	if blossomPart then -- rebuilt per world: each has its own petal colors
		blossomPart:Destroy()
		blossomPart = nil
	end
	if look.petals then
		local part = buildBlossomPart(look)
		part.Parent = folder
		blossomPart = part
	end
	apply()
end

-- The World Tree prefix of the world the forest is in now.
local function currentVariant(): string
	local tier = GameConfig.Tiers[ReplicatedStorage:WaitForChild("ForestState"):GetAttribute("TierId") :: number? or 1]
	return if tier then tier.WorldTree else "Ancient"
end

local function buildLabel()
	local anchor = Instance.new("Part")
	anchor.Name = "LabelAnchor"
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.CFrame = root
	anchor.Parent = folder
	local gui = Instance.new("BillboardGui")
	gui.Name = "WorldTreeLabel"
	gui.Size = LABEL_SIZE
	gui.AlwaysOnTop = true -- seen through the canopy from below
	gui.MaxDistance = LABEL_DISTANCE
	gui.Adornee = anchor
	gui.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = UIStyle.FONT
	text.TextScaled = true
	text.TextColor3 = LABEL_COLOR
	text.Text = LABEL_TEXT
	text.Parent = gui
	labelText = text
	UIStyle.dropShadow(text, nil, false, UIStyle.THIN_DROP)
	UIStyle.band(gui) -- the dark strip behind the text, like the lobby's other signs (2026-10-08)
	labelAnchor = anchor
end

function AncientTreeController.shake()
	if not shown then
		return
	end
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - started
		tilt = if t >= SHAKE_SECONDS then 0 else SHAKE_ANGLE * math.sin(t * SHAKE_SPEED) * (1 - t / SHAKE_SECONDS)
		apply()
		if t >= SHAKE_SECONDS then
			connection:Disconnect()
		end
	end)
end

local function isGlow(part: BasePart): boolean
	return string.find(part.Name, "_Glow") ~= nil
end

local function isLeaves(part: BasePart): boolean
	return string.find(part.Name, "_Leaves") ~= nil
end

function AncientTreeController.setAwakened(on: boolean)
	if not folder then
		return
	end
	local look = VARIANT_LOOK[variantName] or VARIANT_LOOK.Ancient
	for part, original in originals do
		local color = if table.find(baseGlows, part) and look.glow then look.glow else original
		local goal = color
		if on and isGlow(part) then
			goal = look.awake
		elseif on then
			goal = color:Lerp(look.blossom, BLOSSOM_MIX)
		end
		TweenService:Create(part, AWAKE_TWEEN, { Color = goal }):Play()
		local light = part:FindFirstChild("AwakeLight")
		if on and isGlow(part) and not light then
			local newLight = Instance.new("PointLight")
			newLight.Name = "AwakeLight"
			newLight.Color = look.awake
			newLight.Range = 60
			newLight.Brightness = 3
			newLight.Parent = part
		elseif not on and light then
			light:Destroy()
		end
	end
	TweenService:Create(bloom, AWAKE_TWEEN, { Value = if on then BLOOM_SCALE else 1 }):Play()

	if on and not beam then
		local top = (if shown then shown:GetExtentsSize().Y else heights[#heights] * FINAL_SCALE) * BEAM_TOP
		local part = Instance.new("Part")
		part.Name = "LightBeam"
		part.Size = Vector3.new(MOTE_AREA, 1, MOTE_AREA)
		part.CFrame = root * CFrame.new(0, top, 0)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		-- Shafts of light angled down and outward from under the canopy, all around the trunk.
		for i = 1, BEAM_COUNT do
			local angle = (i - 1) / BEAM_COUNT * 2 * math.pi
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local a0 = Instance.new("Attachment")
			a0.Position = out * BEAM_SPREAD[1]
			a0.Parent = part
			local a1 = Instance.new("Attachment")
			a1.Position = out * BEAM_SPREAD[2] - Vector3.new(0, top, 0)
			a1.Parent = part
			local shaft = Instance.new("Beam")
			shaft.Attachment0 = a0
			shaft.Attachment1 = a1
			shaft.Width0 = BEAM_WIDTH[1]
			shaft.Width1 = BEAM_WIDTH[2]
			shaft.FaceCamera = true
			shaft.LightEmission = 1
			shaft.LightInfluence = 0
			shaft.Color = BEAM_COLOR
			shaft.Transparency = BEAM_FADE
			shaft.Parent = part
		end
		local motes = Instance.new("ParticleEmitter")
		motes.EmissionDirection = Enum.NormalId.Bottom
		motes.Rate = 60
		motes.Lifetime = NumberRange.new(8, 12)
		motes.Speed = NumberRange.new(6, 12)
		motes.SpreadAngle = Vector2.new(15, 15)
		motes.Size = NumberSequence.new(0.9, 0.2)
		motes.LightEmission = 1
		motes.Color = ColorSequence.new(look.awake)
		motes.Parent = part
		part.Parent = folder
		beam = part
	elseif not on and beam then
		beam:Destroy()
		beam = nil
	end
end

-- Places the tree at `base` (the hub center on the ground) and starts following the bar.
function AncientTreeController.build(base: Vector3)
	local forestState = ReplicatedStorage:WaitForChild("ForestState")
	local assets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("AncientTree")
	folder = Instance.new("Folder")
	folder.Name = "AncientTree"
	root = CFrame.new(base)

	bloom = Instance.new("NumberValue")
	bloom.Value = 1
	bloom.Changed:Connect(apply)
	local decoration = assets:WaitForChild("AncientBase"):Clone() :: Model
	setup(decoration)
	decoration:ScaleTo(FINAL_SCALE)
	decoration:PivotTo(root)
	decoration.Parent = folder
	for _, part in decoration:GetDescendants() do
		if part:IsA("BasePart") and (isGlow(part) or isLeaves(part)) then
			originals[part] = part.Color
			if isGlow(part) then
				table.insert(baseGlows, part)
			end
		end
	end
	assets:WaitForChild("Ancient4")

	local function fraction(): number
		local seeds = forestState:GetAttribute("Seeds")
		local target = forestState:GetAttribute("Target")
		if typeof(seeds) ~= "number" or typeof(target) ~= "number" or target <= 0 then
			return 0
		end
		return seeds / target
	end
	local value = Instance.new("NumberValue")
	value.Value = fraction()
	value.Changed:Connect(apply)
	progress = value
	local function grow()
		local goal = fraction()
		local tween = if goal < value.Value - 0.01 then SHRINK_TWEEN else GROW_TWEEN -- the reset shrinks slowly
		TweenService:Create(value, tween, { Value = goal }):Play()
	end
	forestState:GetAttributeChangedSignal("Seeds"):Connect(grow)
	forestState:GetAttributeChangedSignal("Target"):Connect(grow)
	buildLabel()
	setVariant(currentVariant())
	-- A new world: swap the tree once it has shrunk back to a sapling (the forest reset shrinks it).
	forestState:GetAttributeChangedSignal("TierId"):Connect(function()
		local wanted = currentVariant()
		if wanted == variantName then
			return
		end
		task.spawn(function()
			local deadline = os.clock() + SWAP_WAIT_SECONDS
			while value.Value > 0.05 and os.clock() < deadline do
				task.wait(0.1)
			end
			setVariant(currentVariant())
		end)
	end)
	folder.Parent = workspace

	-- See-through while you're in the spring circle (the tree only; its base and rune circle on the ground stay).
	local fade = 0
	local faded: { [Model]: number } = {}
	RunService.Heartbeat:Connect(function(dt: number)
		local character = Players.LocalPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local inside = false
		if rootPart and rootPart:IsA("BasePart") then
			-- On the climb too (2026-10-09): anywhere within the ramp's outer edge, up to the Spring's platform.
			local a = GameConfig.Awakening
			local reach = math.max(a.SpringRadiusStuds, a.Climb.Radius + a.Climb.Width / 2)
			local offset = rootPart.Position - root.Position
			inside = Vector2.new(offset.X, offset.Z).Magnitude <= reach and offset.Y <= a.SpringHeightStuds + INSIDE_HEIGHT
		end
		local goal = if inside then INSIDE_FADE else 0
		fade += (goal - fade) * math.min(1, dt * FADE_RATE)
		if math.abs(goal - fade) < 0.005 then
			fade = goal
		end
		local model = shown
		if model and faded[model] ~= fade then
			faded[model] = fade
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = fade
				end
			end
		end
	end)
end

return AncientTreeController
