--!strict
-- GrandOpeningController: Springtown's grand opening when a bridge is finished (2026-10-10, the user's ask). The town
-- (tools/build_town.luau, Workspace.Map.Springtown) is what the bridge is built to reach; when ForestState
-- AwakeningEndsAt goes from 0 to a time (the bridge complete moment, AwakeningController's cutscene), fireworks go up
-- over the town for SHOW_SECONDS, big enough to see from camp, and the townsfolk cheer, jumping and waving. A player
-- who joins during the break doesn't get the show. All on this client: nothing is sent or saved.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Sounds = require(script.Parent.Parent.Sounds)

local SHOW_SECONDS = 26 -- the cutscene (Awakening.CutsceneSeconds, 8) and then some
local LAUNCH_EVERY = NumberRange.new(0.25, 0.7) -- seconds between rockets
local CLIMB_SECONDS = NumberRange.new(1.1, 1.6)
local BURST_HEIGHT = NumberRange.new(90, 170) -- over the town's ground
local BURST_SPEED = NumberRange.new(90, 130) -- studs per second: bursts about 200 studs across (were 55-85, the user wanted much larger)
local SPARKS = 110
local COLORS = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 196, 70),
	Color3.fromRGB(110, 220, 255),
	Color3.fromRGB(150, 255, 120),
	Color3.fromRGB(230, 120, 255),
	Color3.fromRGB(255, 255, 255),
}
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local BOOM = "rbxassetid://83996729056576" -- "Firework Explosion" (EasyPlay Creations)
local CHEER = "rbxassetid://7755719721" -- "Crowd cheering sound effect" (Aimarekin)
local CHEER_ANIMATION = "rbxassetid://507770677" -- Roblox's R15 cheer
local HOP = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)

local GrandOpeningController = {}

local rng = Random.new()
local running = false

-- The town's middle on the ground (the oasis) and the spots rockets go up from.
local function launchSpots(town: Instance): { Vector3 }
	local spots = {}
	for _, name in { "Inn", "GeneralStore", "WaterTower", "Stable", "Oasis" } do
		local piece = town:FindFirstChild(name)
		if piece and piece:IsA("Model") then
			table.insert(spots, piece:GetPivot().Position)
		end
	end
	return spots
end

-- One firework: a glowing rocket with a trail climbs, then bursts into sparks with a flash and a boom.
local function rocket(from: Vector3, folder: Instance)
	local color = COLORS[rng:NextInteger(1, #COLORS)]
	local top = from + Vector3.new(rng:NextNumber(-25, 25), rng:NextNumber(BURST_HEIGHT.Min, BURST_HEIGHT.Max), rng:NextNumber(-25, 25))
	local shell = Instance.new("Part")
	shell.Name = "Rocket"
	shell.Size = Vector3.one * 2.4
	shell.Shape = Enum.PartType.Ball
	shell.Material = Enum.Material.Neon
	shell.Color = color
	shell.Anchored = true
	shell.CanCollide, shell.CanQuery, shell.CanTouch = false, false, false
	shell.CastShadow = false
	shell.Position = from
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.5, 0), Vector3.new(0, -0.5, 0)
	a0.Parent, a1.Parent = shell, shell
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.5
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 1
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Parent = shell
	shell.Parent = folder
	local climb = rng:NextNumber(CLIMB_SECONDS.Min, CLIMB_SECONDS.Max)
	TweenService:Create(shell, TweenInfo.new(climb, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = top }):Play()
	task.delay(climb, function()
		shell.Transparency = 1
		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = SPARK_TEXTURE
		sparks.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.5))
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 16), NumberSequenceKeypoint.new(1, 4) }) -- was 7 to 1.5
		sparks.Brightness = 4 -- glowing well past the daylight (was 1)
		sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.75, 0), NumberSequenceKeypoint.new(1, 1) })
		sparks.Lifetime = NumberRange.new(1.8, 2.6)
		sparks.Speed = BURST_SPEED
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Drag = 1.6
		sparks.Acceleration = Vector3.new(0, -14, 0)
		sparks.Rate = 0
		sparks.Parent = shell
		sparks:Emit(SPARKS)
		local flash = Instance.new("PointLight")
		flash.Color = color
		flash.Range = 60
		flash.Brightness = 8
		flash.Parent = shell
		TweenService:Create(flash, TweenInfo.new(0.8), { Brightness = 0 }):Play()
		local boom = Instance.new("Sound")
		boom.SoundId = BOOM
		boom.Volume = 0.9
		boom.RollOffMinDistance = 200
		boom.RollOffMaxDistance = 6000
		boom.PlaybackSpeed = rng:NextNumber(0.9, 1.1)
		boom.SoundGroup = Sounds.effects()
		boom.Parent = shell
		boom:Play()
		task.delay(3, function()
			shell:Destroy()
		end)
	end)
end

-- The townsfolk cheer: the cheer animation on a loop and a little hop now and then, until `untilTime`.
local function cheer(town: Instance, untilTime: number)
	local folk = town:FindFirstChild("Townsfolk")
	if not folk then
		return
	end
	for _, npc in folk:GetChildren() do
		local humanoid = npc:FindFirstChildOfClass("Humanoid")
		local root = npc:FindFirstChild("HumanoidRootPart")
		if humanoid and root and root:IsA("BasePart") then
			local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
			animator.Parent = humanoid
			local animation = Instance.new("Animation")
			animation.AnimationId = CHEER_ANIMATION
			local track = animator:LoadAnimation(animation)
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Action
			track:Play()
			task.spawn(function()
				local home = root.CFrame
				while os.clock() < untilTime and root.Parent do
					task.wait(rng:NextNumber(0.8, 2))
					TweenService:Create(root, HOP, { CFrame = home + Vector3.new(0, 2.2, 0) }):Play()
				end
				track:Stop(0.5)
				root.CFrame = home
			end)
		end
	end
	Sounds.playId(CHEER, 0.5) -- heard everywhere: the cutscene's camera is far from the town
end

local function show()
	local map = workspace:FindFirstChild("Map")
	local town = map and map:FindFirstChild("Springtown")
	if running or not town then
		return
	end
	running = true
	local spots = launchSpots(town)
	if #spots == 0 then
		running = false
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "GrandOpening"
	folder.Parent = workspace
	local untilTime = os.clock() + SHOW_SECONDS
	cheer(town, untilTime)
	task.spawn(function()
		while os.clock() < untilTime do
			rocket(spots[rng:NextInteger(1, #spots)] + Vector3.new(0, 10, 0), folder)
			task.wait(rng:NextNumber(LAUNCH_EVERY.Min, LAUNCH_EVERY.Max))
		end
		task.wait(4)
		folder:Destroy()
		running = false
	end)
end

function GrandOpeningController.start()
	local forestState = ReplicatedStorage:WaitForChild("ForestState")
	local function endsAt(): number
		local value = forestState:GetAttribute("AwakeningEndsAt")
		return if typeof(value) == "number" then value else 0
	end
	local last = endsAt() -- joined during a break: no show
	forestState:GetAttributeChangedSignal("AwakeningEndsAt"):Connect(function()
		local now = endsAt()
		if last == 0 and now > 0 then
			show()
		end
		last = now
	end)
end

return GrandOpeningController
