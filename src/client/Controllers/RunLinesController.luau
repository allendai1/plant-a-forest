--!strict
-- RunLinesController: speed lines streaming past the God of Hammers suit while its wearer runs (2026-10-11, the user's
-- ask; they replaced a caution-tape trail). tools/import_god_outfit.luau puts a box of the treadmill's speed-line
-- emitters (Assets.SpeedLines2) on the suit, tagged RunLines, emitters off. A particle emitter can't tell running from
-- standing, so each client turns every tagged box's emitters on while its character moves faster than MIN_SPEED.

local CollectionService = game:GetService("CollectionService")

local MIN_SPEED = 6 -- studs a second across the ground
local CHECK_EVERY = 0.1 -- seconds

local RunLinesController = {}

local function setEnabled(box: Instance, on: boolean)
	if box:GetAttribute("Running") == on then
		return
	end
	box:SetAttribute("Running", on) -- only on this client: just remembers what the emitters are set to
	for _, emitter in box:GetChildren() do
		if emitter:IsA("ParticleEmitter") then
			emitter.Enabled = on
		end
	end
end

function RunLinesController.start()
	while true do
		for _, box in CollectionService:GetTagged("RunLines") do
			local character = box:FindFirstAncestorOfClass("Model")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local velocity = root.AssemblyLinearVelocity
				setEnabled(box, Vector3.new(velocity.X, 0, velocity.Z).Magnitude > MIN_SPEED)
			end
		end
		task.wait(CHECK_EVERY)
	end
end

return RunLinesController
