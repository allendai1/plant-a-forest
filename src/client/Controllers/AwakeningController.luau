--!strict
-- AwakeningController: the forest complete moment on this client (docs/plans/M6.md).
-- Driven by ForestState.AwakeningEndsAt. When it goes from 0 to a time, the cutscene plays: the camera
-- flies up and around the Ancient Tree as it awakens over the finished forest, with a Skip button.
-- (Movement isn't locked: this place has no PlayerModule to disable, and the camera is scripted anyway.) Then "Forest complete! +500 coins" (from AwakeningReward) and the spring's
-- multiplier show, and the break starts: every tree sways (the animals walking in and the birds were removed on
-- 2026-10-08, the user's call). When it goes back to 0, the break visuals stop and the
-- forest resets in place (the trees go, the Ancient Tree shrinks back).
-- A player who joins during the break skips the cutscene.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)
local AncientTreeController = require(script.Parent.AncientTreeController)
local ForestController = require(script.Parent.ForestController)
local HUD = require(script.Parent.HUD)
local Sounds = require(script.Parent.Parent.Sounds)
local UIStyle = require(script.Parent.Parent.UIStyle)

-- Look (visual only).
local ORBIT_DEGREES = 120
local ORBIT_RADIUS = { 280, 470 } -- from, to (studs from the hub center)
local ORBIT_HEIGHT = { 90, 320 }
local LOOK_HEIGHT = 100 -- the camera looks at this height on the trunk (was 170 before the tree was drawn at 60%)
local AWAKEN_AT = 1.5 -- seconds into the cutscene when the Ancient Tree awakens
local SPRING_BANNER_DELAY = 3.3 -- after the reward message
local pendingNeeded: number? = nil -- no forest credit: the acorns that would have earned it

local AwakeningController = {}

local localPlayer = Players.LocalPlayer
local forestState: Instance
local pendingCoins: number? = nil
local stopCutscene: (() -> ())? = nil
local breakOn = false

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

local function lerp(range: { number }, t: number): number
	return range[1] + (range[2] - range[1]) * t
end

local function centerOf(): Vector3
	local value = forestState:GetAttribute("Center")
	return if typeof(value) == "Vector3" then value else Vector3.zero
end

local function startBreak()
	if breakOn then
		return
	end
	breakOn = true
	AncientTreeController.setAwakened(true)
	ForestController.setSway(true)
end

-- The user's wording (2026-10-08), with "Climb" once the Spring is up in the tree (2026-10-09).
local function springText(multiplier: unknown): string
	local verb = if GameConfig.Awakening.SpringHeightStuds > 0 then "Climb" else "Stand by"
	return `{verb} the World Tree for a {multiplier}x boost!`
end

local function announce()
	local multiplier = forestState:GetAttribute("SpringMultiplier")
	if pendingCoins then
		HUD.banner(
			if pendingCoins > 0
				then `Forest complete! +{pendingCoins} coins`
				else `Forest complete! Plant {pendingNeeded or 50} acorns next time to earn it`
		)
		pendingCoins = nil
		task.delay(SPRING_BANNER_DELAY, function()
			if breakOn then
				HUD.banner(springText(multiplier))
			end
		end)
	else
		HUD.banner(springText(multiplier))
	end
end

local function playCutscene()
	local camera = workspace.CurrentCamera
	local center = centerOf()
	local start = camera.CFrame
	local startAngle = math.atan2(start.Position.Z - center.Z, start.Position.X - center.X)
	local seconds = GameConfig.Awakening.CutsceneSeconds
	HUD.setVisible(false)
	Sounds.play("ForestComplete")
	camera.CameraType = Enum.CameraType.Scriptable

	local gui = Instance.new("ScreenGui")
	gui.Name = "Cutscene"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	local skip = UIStyle.button(gui, "Skip ▶", UIStyle.Colors.Grey, UDim2.fromOffset(130, 50), 28)
	skip.AnchorPoint = Vector2.new(1, 1)
	skip.Position = UDim2.new(1, -24, 1, -24)
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local started = os.clock()
	local connection: RBXScriptConnection
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		stopCutscene = nil
		connection:Disconnect()
		gui:Destroy()
		camera.CameraType = Enum.CameraType.Custom
		HUD.setVisible(true)
		if (forestState:GetAttribute("AwakeningEndsAt") or 0) :: number > 0 then
			startBreak()
			announce()
		end
	end
	stopCutscene = finish
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - started) / seconds
		if t >= 1 then
			finish()
			return
		end
		local e = smooth(t)
		local angle = startAngle + math.rad(ORBIT_DEGREES) * e
		local radius = lerp(ORBIT_RADIUS, e)
		local position = center + Vector3.new(math.cos(angle) * radius, lerp(ORBIT_HEIGHT, e), math.sin(angle) * radius)
		local frame = CFrame.lookAt(position, center + Vector3.new(0, LOOK_HEIGHT, 0))
		camera.CFrame = frame -- a straight cut from the player's view
	end)
	skip.Activated:Connect(finish)
	task.delay(AWAKEN_AT, AncientTreeController.setAwakened, true)
end

local function endBreak()
	if stopCutscene then
		stopCutscene()
	end
	breakOn = false
	ForestController.setSway(false)
	AncientTreeController.setAwakened(false)
end

function AwakeningController.start()
	forestState = ReplicatedStorage:WaitForChild("ForestState")
	Remotes.event("AwakeningReward").OnClientEvent:Connect(function(reward: { coins: number, needed: number? })
		if typeof(reward) == "table" and typeof(reward.coins) == "number" then
			pendingCoins = reward.coins
			pendingNeeded = reward.needed
		end
	end)
	while not ForestController.ready() do
		task.wait(0.2) -- the trees and the Ancient Tree are built with the snapshot
	end
	local function endsAt(): number
		local value = forestState:GetAttribute("AwakeningEndsAt")
		return if typeof(value) == "number" then value else 0
	end
	local last = endsAt()
	if last > 0 then
		startBreak() -- joined during the break: no cutscene
	end
	forestState:GetAttributeChangedSignal("AwakeningEndsAt"):Connect(function()
		local now = endsAt()
		if last == 0 and now > 0 then
			playCutscene()
		elseif last > 0 and now == 0 then
			endBreak()
		end
		last = now
	end)
end

return AwakeningController
