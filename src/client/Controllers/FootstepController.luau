--!strict
-- FootstepController: footsteps that match the ground (polish pass, 2026-10-07), for every character near
-- the camera. A step plays every STRIDE studs walked (more often at speed, but at most MAX_STEPS_PER_SECOND),
-- picked from the surface under the feet: grass, stone (the plaza, trails, altar, treadmill decks) or wood
-- (bridges, the seed stall). Running on a treadmill (the Running attribute) makes no steps (the user's call,
-- 2026-10-08; it used to step in place). Roblox's own running sound is muted. The sounds are 3D, in the character, through the Effects group.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Sounds = require(script.Parent.Parent.Sounds)

local HEAR_STUDS = 90 -- characters farther than this from the camera make no steps
local STRIDE = 5.5 -- studs per step at walking pace
local MAX_STEPS_PER_SECOND = 7
local VOLUME = 0.35
local PLAZA_R = 148 -- the plaza's stones end here (the fence is at 150); beyond it the walk plate is grass
-- Creator Store picks (free), each surface a few variations so steps don't repeat.
local STEPS = {
	Grass = { "129956418693357", "78534941650081", "110522236020035", "135037154891351" }, -- "footstep grass 1-4"
	Stone = { "133325104274958", "93803555891980", "85682518019906", "80346333847986" }, -- "Stone Footstep 1-4 (SFX)"
	Wood = { "92705710431057", "76286399907074" }, -- "footstep wood 3-4"
}

type Walker = { travelled: number, lastStep: number }

local FootstepController = {}

local walkers: { [Model]: Walker } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function hubCenter(): Vector3
	local state = ReplicatedStorage:FindFirstChild("ForestState")
	local center = state and state:GetAttribute("Center")
	return if typeof(center) == "Vector3" then center else Vector3.zero
end

local function surface(root: BasePart, character: Model): string?
	rayParams.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -7, 0), rayParams)
	if not hit then
		return nil -- in the air
	end
	local part = hit.Instance
	local name = part.Name
	if name:find("Bridge") or name:find("SeedStall") or part.Material == Enum.Material.Wood then
		return "Wood"
	elseif name:find("Stone") or name:find("Walkway") or name == "Deck" then
		return "Stone"
	elseif name == "WalkFloor" then
		local offset = root.Position - hubCenter()
		return if Vector2.new(offset.X, offset.Z).Magnitude < PLAZA_R then "Stone" else "Grass"
	end
	return "Grass"
end

local function step(root: BasePart, kind: string)
	local list = STEPS[kind]
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. list[math.random(#list)]
	sound.Volume = VOLUME
	sound.PlaybackSpeed = 0.95 + math.random() * 0.1
	sound.RollOffMaxDistance = HEAR_STUDS
	sound.RollOffMinDistance = 8
	sound.SoundGroup = Sounds.effects()
	sound.Parent = root
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
end

-- Roblox's default footstep loop (RbxCharacterSounds' "Running" in the root part) is muted.
local function muteDefault(root: BasePart)
	local function mute(child: Instance)
		if child:IsA("Sound") and child.Name == "Running" then
			child.Volume = 0
		end
	end
	for _, child in root:GetChildren() do
		mute(child)
	end
	root.ChildAdded:Connect(mute)
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (character and root and root:IsA("BasePart") and humanoid) then
			continue
		end
		local walker = walkers[character]
		if not walker then
			walker = { travelled = 0, lastStep = 0 }
			walkers[character] = walker
			muteDefault(root)
			character.Destroying:Connect(function()
				walkers[character] = nil
			end)
		end
		if (root.Position - camera.CFrame.Position).Magnitude > HEAR_STUDS then
			continue
		end
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector2.new(velocity.X, velocity.Z).Magnitude
		if speed < 2 or humanoid.FloorMaterial == Enum.Material.Air or player:GetAttribute("Running") == true then
			walker.travelled = 0
			continue
		end
		walker.travelled += speed * dt
		local stride = math.max(STRIDE, speed / MAX_STEPS_PER_SECOND)
		if walker.travelled >= stride and now - walker.lastStep > 1 / MAX_STEPS_PER_SECOND then
			walker.travelled = 0
			walker.lastStep = now
			local kind = surface(root, character)
			if kind then
				step(root, kind)
			end
		end
	end
end

function FootstepController.start()
	RunService.Heartbeat:Connect(update)
end

return FootstepController
