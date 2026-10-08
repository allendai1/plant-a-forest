--!strict
-- AwakeningController: the forest complete moment on this client (docs/plans/M6.md).
-- Driven by ForestState.AwakeningEndsAt. When it goes from 0 to a time, the cutscene plays: the camera
-- flies up and around the Ancient Tree as it awakens over the finished forest, with a Skip button.
-- (Movement isn't locked: this place has no PlayerModule to disable, and the camera is scripted anyway.) Then "Forest complete! +500 coins" (from AwakeningReward) and the spring's
-- multiplier show, and the break starts: every tree sways and placeholder animals walk in along the
-- walkways while birds circle above the canopy. When it goes back to 0, the break visuals stop and the
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
local WALKWAY_TOP = 1.2 -- the stone trails' tops above the forest floor (level with the tiles since M6b)
local WALKERS = { "Deer", "Fox", "Bunny", "Deer", "Fox", "Bunny", "Deer", "Fox" }
local WING_ROOT = 0.3 -- the wings flap around a point this far to each side of the body's centre
local GROUND_ANIMALS = 8
local BIRDS = 6

type Walker = { model: Model, from: Vector3, to: Vector3, speed: number, started: number }
type Bird = {
	body: BasePart,
	beak: BasePart,
	left: BasePart,
	right: BasePart,
	relBody: CFrame,
	relBeak: CFrame,
	relLeft: CFrame,
	relRight: CFrame,
	radius: number,
	height: number,
	speed: number,
	phase: number,
}

local AwakeningController = {}

local localPlayer = Players.LocalPlayer
local forestState: Instance
local pendingCoins: number? = nil
local stopCutscene: (() -> ())? = nil
local breakOn = false
local animalFolder: Folder? = nil
local walkers: { Walker } = {}
local birds: { Bird } = {}
local animalConnection: RBXScriptConnection? = nil
local rng = Random.new()

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

-- An animal from Assets.Animals (Blender, facing -Z with its feet at the pivot), with no collisions.
local function animal(name: string, parent: Instance): Model
	local model = (ReplicatedStorage.Assets.Animals:FindFirstChild(name) :: Model):Clone()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		end
	end
	model.Parent = parent
	return model
end

-- A bird: its body and beak move together; each wing flaps around its root beside the body.
local function buildBird(parent: Instance, index: number): Bird
	local model = animal("Bird", parent)
	local pivot = model:GetPivot()
	local parts: { [string]: BasePart } = {}
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			parts[part.Name] = part
		end
	end
	local function rel(name: string): CFrame
		return pivot:ToObjectSpace(parts[name].CFrame)
	end
	return {
		body = parts.Bird_Body,
		beak = parts.Bird_Beak,
		left = parts.Bird_WingL,
		right = parts.Bird_WingR,
		relBeak = rel("Bird_Beak"),
		relLeft = rel("Bird_WingL"),
		relRight = rel("Bird_WingR"),
		relBody = rel("Bird_Body"),
		radius = rng:NextNumber(150, 320),
		height = rng:NextNumber(70, 110),
		speed = rng:NextNumber(0.15, 0.25) * (if index % 2 == 0 then 1 else -1),
		phase = rng:NextNumber(0, 2 * math.pi),
	}
end

local function stepAnimals()
	local now = os.clock()
	local center = centerOf()
	for _, walker in walkers do
		local distance = (walker.to - walker.from).Magnitude
		local t = math.min((now - walker.started) * walker.speed / distance, 1)
		local position = walker.from:Lerp(walker.to, t)
		local bob = if t < 1 then math.abs(math.sin(now * 9)) * 0.25 else 0
		local facing = if t < 1 then walker.to - walker.from else center - position
		local flat = Vector3.new(facing.X, 0, facing.Z)
		walker.model:PivotTo(CFrame.lookAt(position, position + flat) + Vector3.new(0, bob, 0))
	end
	for _, bird in birds do
		local angle = bird.phase + now * bird.speed
		local position = center + Vector3.new(math.cos(angle) * bird.radius, bird.height, math.sin(angle) * bird.radius)
		local ahead = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * math.sign(bird.speed)
		local frame = CFrame.lookAt(position, position + ahead)
		local flap = math.sin(now * 10 + bird.phase) * 0.6
		bird.body.CFrame = frame * bird.relBody
		bird.beak.CFrame = frame * bird.relBeak
		local function flapWing(wing: BasePart, rel: CFrame)
			local side = math.sign(rel.X) -- which side of the body this wing is on
			local root = CFrame.new(side * WING_ROOT, 0, 0)
			wing.CFrame = frame * root * CFrame.Angles(0, 0, side * flap) * root:Inverse() * rel
		end
		flapWing(bird.left, bird.relLeft)
		flapWing(bird.right, bird.relRight)
	end
end

local function startAnimals()
	local folder = Instance.new("Folder")
	folder.Name = "Animals"
	folder.Parent = workspace
	animalFolder = folder
	local center = centerOf()
	local groundY = ForestController.groundY() + WALKWAY_TOP
	local outer = (GameConfig.Grid.HubRings + GameConfig.Grid.ForestRings + 0.5) * GameConfig.Grid.HexSize * math.sqrt(3)
	for i = 1, GROUND_ANIMALS do
		local angle = math.rad(((i - 1) % 6) * 60) -- the six walkways run out from the hub at these angles
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local side = Vector3.new(-direction.Z, 0, direction.X) * rng:NextNumber(-5, 5)
		local base = Vector3.new(center.X, groundY, center.Z) + side
		table.insert(walkers, {
			model = animal(WALKERS[(i - 1) % #WALKERS + 1], folder),
			from = base + direction * (outer + rng:NextNumber(0, 40)),
			to = base + direction * rng:NextNumber(115, 140),
			speed = rng:NextNumber(7, 10),
			started = os.clock() + rng:NextNumber(0, 6),
		})
	end
	for i = 1, BIRDS do
		table.insert(birds, buildBird(folder, i))
	end
	animalConnection = RunService.RenderStepped:Connect(stepAnimals)
end

local function stopAnimals()
	if animalConnection then
		animalConnection:Disconnect()
		animalConnection = nil
	end
	if animalFolder then
		animalFolder:Destroy()
		animalFolder = nil
	end
	table.clear(walkers)
	table.clear(birds)
end

local function startBreak()
	if breakOn then
		return
	end
	breakOn = true
	AncientTreeController.setAwakened(true)
	ForestController.setSway(true)
	startAnimals()
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
				HUD.banner(`The Ancient Spring is {multiplier}x! Stand in the glowing circle.`)
			end
		end)
	else
		HUD.banner(`The Ancient Spring is {multiplier}x! Stand in the glowing circle.`)
	end
end

local function playCutscene()
	local camera = workspace.CurrentCamera
	local center = centerOf()
	local start = camera.CFrame
	local startAngle = math.atan2(start.Position.Z - center.Z, start.Position.X - center.X)
	local seconds = GameConfig.Awakening.CutsceneSeconds
	HUD.setVisible(false)
	Sounds.play("Fanfare")
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
	stopAnimals()
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
