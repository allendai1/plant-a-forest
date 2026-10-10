--!strict
-- FallService: nobody dies from falling off the island (2026-10-08, the user's ask). A character that drops below
-- FALL_Y (well under every walkable surface; the plaza and forest are at about 1.5) is put straight back on the
-- spawn, still alive and still carrying its seeds, instead of falling to Roblox's kill height (-500).

local Players = game:GetService("Players")

local FALL_Y = -50
local CHECK_SECONDS = 0.25
local ABOVE_SPAWN = 4 -- studs over the spawn pad

local FallService = {}

local function spawnCFrame(): CFrame?
	local pad = workspace:FindFirstChildWhichIsA("SpawnLocation")
	return if pad then pad.CFrame + Vector3.new(0, pad.Size.Y / 2 + ABOVE_SPAWN, 0) else nil
end

function FallService.start()
	while true do
		task.wait(CHECK_SECONDS)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if character and root and root:IsA("BasePart") and root.Position.Y < FALL_Y then
				local target = spawnCFrame()
				if target then
					root.AssemblyLinearVelocity = Vector3.zero
					character:PivotTo(target)
				end
			end
		end
	end
end

return FallService
