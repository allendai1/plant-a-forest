--!strict
-- GlowRingController: turns the glowing ground rings (Shared/GlowRing builds them into the place, so they're visible
-- and editable in Studio). Each GlowRingFx part's ground texture (Ground.Glow) spins slowly while it's near the
-- camera; the walls' Beams scroll by themselves. A ring with the BreakOnly attribute (the Ancient Spring's) shows only
-- during the break after a forest (ForestState AwakeningEndsAt > 0). One with the Rainbow attribute (the 100x pad's,
-- 2026-10-08) cycles through the rainbow: a rainbow sweeps across its ground glow, and the colors flow around its
-- wall. Visual only.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GlowRing = require(ReplicatedStorage.Shared.GlowRing)
local UIStyle = require(script.Parent.Parent.UIStyle)

local SPIN = 18 -- degrees per second
local NEAR_STUDS = 220 -- rings farther from the camera than this stop spinning
local RAINBOW_SPEED = 0.5 -- turns of the rainbow per second
local WALL_KEYS = 6 -- color keypoints along each quarter of the wall

local GlowRingController = {}

local rings: { [Instance]: ImageLabel } = {}
type Rainbow = { gradient: UIGradient, walls: { Beam } }
local rainbows: { [Instance]: Rainbow } = {}
local breakOn = false

-- Shows or hides a ring's glow and walls.
local function show(fx: Instance, on: boolean)
	for _, item in fx:GetDescendants() do
		-- selene: allow(if_same_then_else) -- separate branches keep each type narrowed for luau-lsp
		if item:IsA("SurfaceGui") then
			item.Enabled = on
		elseif item:IsA("Beam") then
			item.Enabled = on
		end
	end
end

local function add(fx: Instance)
	local image = fx:FindFirstChild("Glow", true)
	if fx:IsA("BasePart") and image and image:IsA("ImageLabel") then
		rings[fx] = image
		if fx:GetAttribute("Rainbow") then
			image.ImageColor3 = Color3.new(1, 1, 1)
			local gradient = image:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
			gradient.Color = UIStyle.rainbowSequence(0)
			gradient.Parent = image
			-- The walls, in order around the ring (Wall1..Wall4, each a quarter).
			local walls: { Beam } = {}
			for i = 1, 4 do
				for _, item in fx:GetChildren() do
					if item:IsA("Beam") and item.Name == `Wall{i}` then
						walls[i] = item
					end
				end
			end
			rainbows[fx] = { gradient = gradient, walls = walls }
		end
		if fx:GetAttribute("BreakOnly") then
			show(fx, breakOn)
		end
	end
end

function GlowRingController.start()
	local forestState = ReplicatedStorage:WaitForChild("ForestState")
	local function onBreak()
		local endsAt = forestState:GetAttribute("AwakeningEndsAt")
		breakOn = typeof(endsAt) == "number" and endsAt > 0
		for fx in rings do
			if fx:GetAttribute("BreakOnly") then
				show(fx, breakOn)
			end
		end
	end
	forestState:GetAttributeChangedSignal("AwakeningEndsAt"):Connect(onBreak)
	onBreak()
	for _, fx in CollectionService:GetTagged(GlowRing.TAG) do
		add(fx)
	end
	CollectionService:GetInstanceAddedSignal(GlowRing.TAG):Connect(add) -- streamed back in, too
	CollectionService:GetInstanceRemovedSignal(GlowRing.TAG):Connect(function(fx)
		rings[fx] = nil
		rainbows[fx] = nil
	end)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		local now = os.clock()
		local angle = now * SPIN % 360
		local turn = now * RAINBOW_SPEED
		for fx, image in rings do
			if ((fx :: BasePart).Position - eye).Magnitude > NEAR_STUDS then
				continue
			end
			image.Rotation = angle
			local rainbow = rainbows[fx]
			if rainbow then
				rainbow.gradient.Color = UIStyle.rainbowSequence(turn)
				for i, wall in rainbow.walls do
					local keys = {}
					for k = 0, WALL_KEYS - 1 do
						local along = k / (WALL_KEYS - 1)
						table.insert(keys, ColorSequenceKeypoint.new(along, UIStyle.rainbowAt((i - 1 + along) / 4 - turn)))
					end
					wall.Color = ColorSequence.new(keys)
				end
			end
		end
	end)
end

return GlowRingController
