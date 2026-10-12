--!strict
-- BoundaryController: near the edge of the walkable world (GameConfig.Boundary, invisible walls from
-- tools/build_boundary.luau), a banner turns the player back toward camp and the bridge (2026-10-10, the user's call).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local HUD = require(script.Parent.HUD)

local CHECK_SECONDS = 0.5

local BoundaryController = {}

function BoundaryController.start()
	local edge = GameConfig.Boundary
	local lastWarned = -math.huge
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local p = root.Position
				local toEdge = math.min(p.X - edge.X0, edge.X1 - p.X, p.Z - edge.Z0, edge.Z1 - p.Z)
				if toEdge < edge.WarnStuds and os.clock() - lastWarned > edge.WarnSeconds then
					lastWarned = os.clock()
					HUD.banner("The canyon goes on, but the bridge is back this way!")
				end
			end
		end
	end)
end

return BoundaryController
