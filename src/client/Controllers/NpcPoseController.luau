--!strict
-- NpcPoseController: the map NPCs' poses (2026-10-08; was played by OutfitService on the server, which never reached
-- the clients). Every model tagged IdleNpc (the Park Ranger, the shopkeeper) loops its Animation attribute (a pose
-- or emote picked in Studio, for example the Ranger's salute), or else Roblox's idle, on this client.

local CollectionService = game:GetService("CollectionService")

local IDLE_ANIMATION = "rbxassetid://507766388" -- Roblox's default R15 idle

local NpcPoseController = {}

local function pose(model: Instance)
	local humanoid = model:WaitForChild("Humanoid", 10)
	if not (humanoid and humanoid:IsA("Humanoid")) then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local animation = Instance.new("Animation")
	local custom = model:GetAttribute("Animation")
	animation.AnimationId = if typeof(custom) == "string" and custom ~= "" then custom else IDLE_ANIMATION
	local track = animator:LoadAnimation(animation)
	track.Looped = true
	track:Play()
end

function NpcPoseController.start()
	CollectionService:GetInstanceAddedSignal("IdleNpc"):Connect(function(model)
		task.spawn(pose, model) -- also when a streamed-out NPC comes back
	end)
	for _, model in CollectionService:GetTagged("IdleNpc") do
		task.spawn(pose, model)
	end
end

return NpcPoseController
