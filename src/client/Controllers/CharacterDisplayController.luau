--!strict
-- CharacterDisplayController: the shop-display look of the Park Ranger and Lord of the Forest NPCs (2026-10-07,
-- after Build the Pyramid's Pharaoh stand). Over each NPC (tagged CharacterNpc, with an Outfit attribute): the
-- pass's Robux price, its name in big colored letters and its boosts, plus sparkles rising around the NPC in
-- the same color. The prompt that sells the pass is OutfitService's.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local UIStyle = require(script.Parent.Parent.UIStyle)

local SPARKLE_TEXTURE = "rbxassetid://88252539838654" -- tools/make_particle_textures.py sparkle
local PRICE_COLOR = Color3.fromRGB(110, 255, 110)
local COLORS: { [string]: Color3 } = { -- the stands' rim colors
	Ranger = Color3.fromRGB(240, 210, 140),
	Lord = Color3.fromRGB(150, 255, 150),
}
local ABOVE_HEAD = 2 -- studs over the NPC's head to the bottom of the sign
local SIGN_STUDS = 7 -- the sign's width in the world
local DESIGN = Vector2.new(460, 150) -- the layout's size in pixels before it's scaled to the sign
local MAX_DISTANCE = 80

local CharacterDisplayController = {}

local function passFor(outfit: unknown): GameConfig.HandsPass?
	for _, pass in GameConfig.availableHandsPasses() do
		if pass.Outfit == outfit then
			return pass
		end
	end
	return nil
end

local function decorate(model: Instance)
	local pass = passFor(model:GetAttribute("Outfit"))
	local head = model:WaitForChild("Head", 10)
	local root = model:WaitForChild("HumanoidRootPart", 10)
	if not (pass and head and head:IsA("BasePart") and root and root:IsA("BasePart")) then
		return
	end
	if head:FindFirstChild("CharacterSign") then
		return
	end
	local color = COLORS[pass.Outfit] or UIStyle.WHITE

	local sign = Instance.new("BillboardGui")
	sign.Name = "CharacterSign"
	sign.Adornee = head
	-- Sized in studs, so it shrinks as you zoom out like a real sign (the user's ask, 2026-10-07). The layout
	-- inside is drawn at DESIGN pixels and scaled to whatever size the sign has on screen.
	sign.Size = UDim2.fromScale(SIGN_STUDS, SIGN_STUDS * DESIGN.Y / DESIGN.X)
	sign.SizeOffset = Vector2.new(0, 0.5) -- its bottom edge sits at the offset point
	sign.StudsOffsetWorldSpace = Vector3.new(0, ABOVE_HEAD, 0)
	sign.MaxDistance = MAX_DISTANCE
	sign.LightInfluence = 0
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y)
	content.Parent = sign
	local fit = Instance.new("UIScale")
	fit.Parent = content
	sign:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fit.Scale = sign.AbsoluteSize.X / DESIGN.X
	end)
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = content
	local price = UIStyle.text(content, "", 34, PRICE_COLOR)
	price.LayoutOrder = 1
	local function showPrice()
		price.Text = UIStyle.priceText(pass.PassId, Enum.InfoType.GamePass, showPrice)
	end
	showPrice()
	UIStyle.text(content, pass.Name, 56, color).LayoutOrder = 2
	local boosts = UIStyle.text(content, `{pass.Multiplier}x Quick Pickup · {pass.Multiplier}x Quick Plant`, 28, color)
	boosts.LayoutOrder = 3
	sign.Parent = head

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "DisplaySparkles"
	sparkles.Texture = SPARKLE_TEXTURE
	sparkles.Color = ColorSequence.new(color, UIStyle.WHITE)
	sparkles.LightEmission = 0.8
	sparkles.LightInfluence = 0
	sparkles.Rate = 6
	sparkles.Lifetime = NumberRange.new(1.2, 2)
	sparkles.Speed = NumberRange.new(1.5, 3)
	sparkles.SpreadAngle = Vector2.new(25, 25)
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Shape = Enum.ParticleEmitterShape.Cylinder
	sparkles.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	sparkles.Parent = root
end

function CharacterDisplayController.start()
	CollectionService:GetInstanceAddedSignal("CharacterNpc"):Connect(function(model)
		task.spawn(decorate, model)
	end)
	for _, model in CollectionService:GetTagged("CharacterNpc") do
		task.spawn(decorate, model)
	end
end

return CharacterDisplayController
