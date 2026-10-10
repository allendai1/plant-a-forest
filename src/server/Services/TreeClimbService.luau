--!strict
-- TreeClimbService: the climb up the World Tree to the Ancient Spring (2026-10-09, the user's idea, like Build the
-- Pyramid's well inside the finished pyramid). A wooden ramp spirals up around the trunk (Awakening.Climb) to a round
-- platform in the canopy, Awakening.SpringHeightStuds up and SpringRadiusStuds wide, where the Spring trains during
-- the break (TrainingService). Built once around ForestState Center; it's in the world only during the break
-- (ForestState AwakeningEndsAt > 0) and waits in ServerStorage otherwise, so it comes with the full-grown tree and
-- goes when the next forest starts (anyone still on it drops to the hub; Roblox has no fall damage). The Spring's
-- glowing field (the BreakOnly GlowRingFx, tools/build_map.luau) is lifted onto the platform.
-- SpringHeightStuds 0 turns it all off: the Spring is on the ground again.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GlowRing = require(ReplicatedStorage.Shared.GlowRing)

local WOOD = Color3.fromRGB(134, 94, 60)
local DECK = Color3.fromRGB(150, 108, 70)
local THICKNESS = 1.5
local SEGMENT_STUDS = 8 -- each plank of the ramp covers about this much of it
local OVERLAP = 0.6 -- planks run this much longer, so the joints have no gaps
local RAIL_HEIGHT = 2.5 -- the low rail along the ramp's outer edge

local TreeClimbService = {}

local function plank(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanTouch = false
	part.Material = Enum.Material.Wood
	part.Color = color
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Size = size
	part.CFrame = cframe
	part.Parent = parent
	return part
end

-- The ramp from the ground at `ground` height up to `top`, and the platform, around `center`.
local function build(center: Vector3, ground: number, top: number): Folder
	local a = GameConfig.Awakening
	local climb = a.Climb
	local folder = Instance.new("Folder")
	folder.Name = "TreeClimb"
	local horizontal = (top - ground) / climb.Slope
	local turn = horizontal / climb.Radius -- radians the ramp winds around the trunk
	local count = math.ceil(horizontal / SEGMENT_STUDS)
	local function point(i: number): Vector3
		local t = i / count
		local angle = climb.StartAngle + turn * t
		return Vector3.new(
			center.X + climb.Radius * math.cos(angle),
			ground + (top - ground) * t,
			center.Z + climb.Radius * math.sin(angle)
		)
	end
	for i = 1, count do
		local from, to = point(i - 1), point(i)
		-- The plank's top runs along the line; its right side faces the trunk, the rail goes on the left.
		local frame = CFrame.lookAt((from + to) / 2, to) * CFrame.new(0, -THICKNESS / 2, 0)
		local length = (to - from).Magnitude + OVERLAP
		plank(`Ramp{i}`, Vector3.new(climb.Width, THICKNESS, length), frame, WOOD, folder)
		local rail = frame * CFrame.new(-(climb.Width / 2 - 0.5), (THICKNESS + RAIL_HEIGHT) / 2, 0)
		plank(`Rail{i}`, Vector3.new(1, RAIL_HEIGHT, length), rail, DECK, folder)
	end
	-- From the ramp's end straight in onto the platform.
	local finish = point(count)
	local inward = Vector3.new(center.X, finish.Y, center.Z)
	local bridge = climb.Radius + climb.Width / 2 - a.SpringRadiusStuds + 4
	local bridgeFrame = CFrame.lookAt(finish, inward) * CFrame.new(0, -THICKNESS / 2, -bridge / 2 + climb.Width / 2)
	plank("Bridge", Vector3.new(climb.Width, THICKNESS, bridge), bridgeFrame, WOOD, folder)
	-- The platform: a round deck (a cylinder lying on its side, turned upright).
	local across = 2 * a.SpringRadiusStuds
	local deck = CFrame.new(center.X, top - THICKNESS / 2, center.Z) * CFrame.Angles(0, 0, math.rad(90))
	local platform = plank("SpringPlatform", Vector3.new(THICKNESS, across, across), deck, DECK, folder)
	platform.Shape = Enum.PartType.Cylinder
	return folder
end

function TreeClimbService.start()
	local a = GameConfig.Awakening
	if a.SpringHeightStuds <= 0 then
		return
	end
	local forestState = ReplicatedStorage:WaitForChild("ForestState")
	local center = forestState:GetAttribute("Center")
	if typeof(center) ~= "Vector3" then
		return
	end
	-- The ramp starts on the hub's ground (just under the hub center's height).
	local start = GameConfig.climbStart(center)
	local hit = workspace:Raycast(start + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0))
	local ground = if hit then hit.Position.Y else center.Y
	local top = center.Y + a.SpringHeightStuds
	local folder = build(center, ground, top)
	-- The Spring's glowing field moves up onto the platform.
	for _, fx in CollectionService:GetTagged(GlowRing.TAG) do
		if fx:GetAttribute("BreakOnly") and fx:IsA("BasePart") then
			fx.CFrame += Vector3.new(0, top - fx.Position.Y + 0.1, 0)
		end
	end
	local function onBreak()
		local endsAt = forestState:GetAttribute("AwakeningEndsAt")
		folder.Parent = if typeof(endsAt) == "number" and endsAt > 0 then workspace else ServerStorage
	end
	forestState:GetAttributeChangedSignal("AwakeningEndsAt"):Connect(onBreak)
	onBreak()
end

return TreeClimbService
