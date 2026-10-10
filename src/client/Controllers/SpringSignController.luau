--!strict
-- SpringSignController: the "2X TRAINING / INSIDE" sign over the Ancient Spring during the break after a forest (2026-10-08,
-- the user's ask, like Build the Pyramid's "10X TRAINING INSIDE"). A rainbow sweeps through the letters and soft sun
-- rays turn behind them, breathing in size and brightness. (The text itself doesn't pulse: Roblox draws text at whole
-- font sizes, so a small size pulse stepped instead of moving smoothly.) It floats over the World Tree (seen through the trunk), sized in
-- studs so it shrinks with distance, and shows only while the break runs and the spring has a multiplier.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local UIStyle = require(script.Parent.Parent.UIStyle)

local HEIGHT = 30 -- studs over the Spring's floor (up in the World Tree since 2026-10-09: Awakening.SpringHeightStuds)
local SIGN_STUDS = 40 -- the sign's width in the world
local DESIGN = Vector2.new(640, 200) -- the layout's size in pixels before it's scaled to the sign
local MAX_DISTANCE = 450
local RAYS = "rbxassetid://83538665602246" -- tools/make_particle_textures.py sun_rays (decal 98479872249909)
local RAYS_COLOR = Color3.fromRGB(255, 225, 130)
local RAYS_SPIN = 20 -- degrees per second
local RAINBOW_SPEED = 0.7 -- turns of the rainbow per second
local RAYS_PULSE = 0.12 -- the rays grow and shrink by this fraction
local RAYS_FADE = { 0.05, 0.4 } -- their transparency at the biggest and smallest
local PULSE_SPEED = 2.5 -- radians per second
local INSIDE_SIZE = 60 -- "INSIDE" under "2X TRAINING" (96)

local SpringSignController = {}

function SpringSignController.start()
	local forestState = ReplicatedStorage:WaitForChild("ForestState")
	local center = forestState:GetAttribute("Center")
	local anchor = Instance.new("Part")
	anchor.Name = "SpringSignAnchor"
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Position = (if typeof(center) == "Vector3" then center else Vector3.zero)
		+ Vector3.new(0, GameConfig.Awakening.SpringHeightStuds + HEIGHT, 0)
	anchor.Parent = workspace

	local sign = Instance.new("BillboardGui")
	sign.Name = "SpringSign"
	sign.Adornee = anchor
	sign.Size = UDim2.fromScale(SIGN_STUDS, SIGN_STUDS * DESIGN.Y / DESIGN.X)
	sign.AlwaysOnTop = true -- seen through the World Tree's trunk and canopy
	sign.LightInfluence = 0
	sign.MaxDistance = MAX_DISTANCE
	sign.Enabled = false
	sign.Parent = anchor
	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y)
	content.Parent = sign
	local fit = Instance.new("UIScale")
	fit.Parent = content
	sign:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fit.Scale = sign.AbsoluteSize.X / DESIGN.X
	end)

	local rays = Instance.new("ImageLabel")
	rays.Name = "Rays"
	rays.BackgroundTransparency = 1
	rays.Image = RAYS
	rays.ImageColor3 = RAYS_COLOR
	rays.ImageTransparency = 0.15
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromOffset(DESIGN.X * 0.9, DESIGN.X * 0.9)
	rays.Parent = content

	local text = UIStyle.text(content, "", 96)
	text.Name = "Training"
	text.AutomaticSize = Enum.AutomaticSize.None
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.4)
	text.Size = UDim2.fromScale(1, 0.6)
	text.ZIndex = 2
	-- "INSIDE" under it (2026-10-09, the user's ask, like Build the Pyramid's "10X TRAINING INSIDE"): the boost is
	-- for standing inside the World Tree, and players didn't know to walk in.
	local up = GameConfig.Awakening.SpringHeightStuds > 0 -- "UP TOP" once the Spring is up in the tree (2026-10-09)
	local inside = UIStyle.text(content, if up then "UP TOP" else "INSIDE", INSIDE_SIZE)
	inside.Name = "Inside"
	inside.AutomaticSize = Enum.AutomaticSize.None
	inside.AnchorPoint = Vector2.new(0.5, 0.5)
	inside.Position = UDim2.fromScale(0.5, 0.84)
	inside.Size = UDim2.fromScale(1, 0.32)
	inside.ZIndex = 2
	-- The rainbow tints the letters' colored face (UIStyle.text draws Face over a Shadow); the face is white.
	local face = text:FindFirstChild("Face")
	local rainbow = Instance.new("UIGradient")
	rainbow.Color = UIStyle.rainbowSequence(0)
	rainbow.Parent = if face then face else text
	if face and face:IsA("TextLabel") then
		face.TextColor3 = UIStyle.WHITE
	end

	local function refresh()
		local endsAt = forestState:GetAttribute("AwakeningEndsAt")
		local multiplier = forestState:GetAttribute("SpringMultiplier")
		local on = typeof(endsAt) == "number" and endsAt > 0 and typeof(multiplier) == "number" and multiplier > 0
		sign.Enabled = on
		if on then
			text.Text = `{multiplier}X TRAINING`
		end
	end
	forestState:GetAttributeChangedSignal("AwakeningEndsAt"):Connect(refresh)
	forestState:GetAttributeChangedSignal("SpringMultiplier"):Connect(refresh)
	refresh()

	RunService.RenderStepped:Connect(function()
		if not sign.Enabled then
			return
		end
		local now = os.clock()
		rays.Rotation = now * RAYS_SPIN % 360
		rainbow.Color = UIStyle.rainbowSequence(now * RAINBOW_SPEED)
		local wave = math.sin(now * PULSE_SPEED) -- -1..1, eased by the sine itself
		local size = DESIGN.X * 0.9 * (1 + wave * RAYS_PULSE)
		rays.Size = UDim2.fromOffset(size, size)
		rays.ImageTransparency = RAYS_FADE[2] + (RAYS_FADE[1] - RAYS_FADE[2]) * (wave + 1) / 2
	end)
end

return SpringSignController
