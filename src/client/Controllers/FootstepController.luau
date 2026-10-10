--!strict
-- FootstepController: no footsteps. The surface-matched steps (grass, stone, wood; polish pass 2026-10-07) were
-- removed on 2026-10-08 at the user's call; all that's left is muting Roblox's own running sound ("Running" in each
-- character's root part, from RbxCharacterSounds) so walking is silent.

local Players = game:GetService("Players")

local FootstepController = {}

local function muteDefault(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
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

local function watch(player: Player)
	player.CharacterAdded:Connect(muteDefault)
	if player.Character then
		task.spawn(muteDefault, player.Character)
	end
end

function FootstepController.start()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return FootstepController
