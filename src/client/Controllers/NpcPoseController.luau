--!strict
-- NpcPoseController: the map NPCs' animations (2026-10-08; was played by OutfitService on the server, which never
-- reached the clients). Every model tagged IdleNpc (the Forest Ranger, the shopkeeper) loops Roblox's idle on this
-- client. One with an Animation attribute (a greeting picked in Studio, like the Ranger's salute) plays it once when
-- you walk up to it, then goes back to the idle; walk away and come back for another (the user's call, 2026-10-08).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local IDLE_ANIMATION = "rbxassetid://507766388" -- Roblox's default R15 idle
local GREET_STUDS = 14 -- walking this close greets you
local LEAVE_STUDS = 22 -- and you have to go this far before the next greeting
local CHECK_SECONDS = 0.2

local NpcPoseController = {}

type Npc = { root: BasePart, greet: AnimationTrack, near: boolean }

local npcs: { [Instance]: Npc } = {}
local localPlayer = Players.LocalPlayer

local function track(animator: Animator, id: string, looped: boolean, priority: Enum.AnimationPriority): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local loaded = animator:LoadAnimation(animation)
	loaded.Looped = looped
	loaded.Priority = priority
	return loaded
end

local function setUp(model: Instance)
	local humanoid = model:WaitForChild("Humanoid", 10)
	local root = model:WaitForChild("HumanoidRootPart", 10)
	if not (humanoid and humanoid:IsA("Humanoid") and root and root:IsA("BasePart")) then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	track(animator, IDLE_ANIMATION, true, Enum.AnimationPriority.Idle):Play()
	local greeting = model:GetAttribute("Animation")
	if typeof(greeting) == "string" and greeting ~= "" then
		npcs[model] = { root = root, greet = track(animator, greeting, false, Enum.AnimationPriority.Action), near = false }
	end
end

function NpcPoseController.start()
	CollectionService:GetInstanceAddedSignal("IdleNpc"):Connect(function(model)
		task.spawn(setUp, model) -- also when a streamed-out NPC comes back
	end)
	CollectionService:GetInstanceRemovedSignal("IdleNpc"):Connect(function(model)
		npcs[model] = nil
	end)
	for _, model in CollectionService:GetTagged("IdleNpc") do
		task.spawn(setUp, model)
	end
	task.spawn(function()
		while true do
			local character = localPlayer.Character
			local me = character and character:FindFirstChild("HumanoidRootPart")
			for _, npc in npcs do
				if me and me:IsA("BasePart") and npc.root.Parent then
					local distance = (me.Position - npc.root.Position).Magnitude
					if not npc.near and distance <= GREET_STUDS then
						npc.near = true
						npc.greet:Play()
					elseif npc.near and distance > LEAVE_STUDS then
						npc.near = false
					end
				end
			end
			task.wait(CHECK_SECONDS)
		end
	end)
end

return NpcPoseController
