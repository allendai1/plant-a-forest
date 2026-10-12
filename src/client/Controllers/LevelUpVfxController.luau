--!strict
-- LevelUpVfxController: the user's level-up effect (ReplicatedStorage.Assets.LevelUpVFX, 2026-10-11) on a player's
-- character whenever their capacity or walk speed goes up by at least 1, the same rule as the HUD's level-up sound.
-- Every player's, so others see you level up too. At most once per LEVEL_UP_GAP per player, so fast training doesn't
-- stack it; only for characters near the camera.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local LEVEL_UP_GAP = 0.9 -- seconds, like the HUD's sound
local SHOW_STUDS = 250 -- characters farther than this from the camera don't get it
-- The effect's size: this many times the asset's (5 studs, about the body; the user found it too contained, 2026-10-11).
local SIZE_SCALE = 2
local COLOR = Color3.fromRGB(255, 214, 60) -- yellow (2026-10-11, the user; the asset's is white)

local LevelUpVfxController = {}

local template: Attachment? = nil

local function level(stat: string, value: number): number
	return if stat == "Strength" then GameConfig.capacity(value) else math.round(GameConfig.walkSpeed(value))
end

local function play(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not (template and root and root:IsA("BasePart") and camera) then
		return
	end
	if (root.Position - camera.CFrame.Position).Magnitude > SHOW_STUDS then
		return
	end
	local effect = template:Clone()
	local longest = 0
	for _, emitter in effect:GetDescendants() do
		if emitter:IsA("ParticleEmitter") then
			emitter.Enabled = false -- one burst, not its steady rate
			longest = math.max(longest, emitter.Lifetime.Max)
			local points = {}
			for _, point in emitter.Size.Keypoints do
				table.insert(points, NumberSequenceKeypoint.new(point.Time, point.Value * SIZE_SCALE, point.Envelope * SIZE_SCALE))
			end
			emitter.Size = NumberSequence.new(points)
			emitter.Color = ColorSequence.new(COLOR)
		end
	end
	effect.Parent = root
	for _, emitter in effect:GetDescendants() do
		if emitter:IsA("ParticleEmitter") then
			emitter:Emit(1)
		end
	end
	Debris:AddItem(effect, longest + 0.5)
end

local function watch(player: Player)
	local last = 0
	for _, stat in { "Strength", "Speed" } do
		local before = player:GetAttribute(stat)
		player:GetAttributeChangedSignal(stat):Connect(function()
			local now = player:GetAttribute(stat)
			-- Not for the save loading (from nil), only for real gains.
			if typeof(now) == "number" and typeof(before) == "number" and level(stat, now) > level(stat, before) then
				local clock = os.clock()
				if clock - last >= LEVEL_UP_GAP then
					last = clock
					play(player)
				end
			end
			before = now
		end)
	end
end

function LevelUpVfxController.start()
	local asset = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("LevelUpVFX", 10)
	local attachment = asset and asset:FindFirstChildWhichIsA("Attachment")
	if not attachment then
		warn("[LevelUpVfxController] ReplicatedStorage.Assets.LevelUpVFX has no Attachment")
		return
	end
	template = attachment
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return LevelUpVfxController
