--!strict
-- SiteAmbienceController: the construction camp's small motions (2026-10-10, the user's camp brief). All of it is
-- decoration built by tools/build_camp.luau and found by tag, moved only on this client:
-- - SiteSlew: the tower crane's top turns once every SlewSeconds (its attribute) round its pivot
-- - SiteSway: a hanging load swings a little round its pivot (the cable's top)
-- - SiteBeacon: an amber light blinks
-- - BridgeProgressBoard: the gateway's board shows how much of the bridge is built (ForestState Seeds / Target)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SWAY = Vector2.new(0.035, 0.05) -- the load's swing, radians, round X and Z
local SWAY_SPEED = Vector2.new(0.9, 0.7) -- radians per second
local BLINK_SECONDS = 0.6
local BEACON_OFF = 0.8 -- an unlit beacon's transparency

local SiteAmbienceController = {}

-- Every model with `tag`, and the pivot it had when it reached this client.
local function track(tag: string): { [Model]: CFrame }
	local set: { [Model]: CFrame } = {}
	local function add(item: Instance)
		if item:IsA("Model") then
			set[item] = item:GetPivot()
		end
	end
	for _, item in CollectionService:GetTagged(tag) do
		add(item)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(item)
		set[item :: Model] = nil
	end)
	return set
end

local function progressBoards(forestState: Instance)
	local function refresh()
		local seeds = forestState:GetAttribute("Seeds")
		local target = forestState:GetAttribute("Target")
		local share = if typeof(seeds) == "number" and typeof(target) == "number" and target > 0
			then math.clamp(seeds / target, 0, 1)
			else 0
		for _, board in CollectionService:GetTagged("BridgeProgressBoard") do
			for _, gui in board:GetChildren() do
				local percent = gui:FindFirstChild("Percent")
				local fill = gui:FindFirstChild("Bar") and (gui :: any).Bar:FindFirstChild("Fill")
				if percent and percent:IsA("TextLabel") then
					percent.Text = `{math.floor(share * 100)}% BUILT`
				end
				if fill and fill:IsA("Frame") then
					fill.Size = UDim2.fromScale(share, 1)
				end
			end
		end
	end
	forestState:GetAttributeChangedSignal("Seeds"):Connect(refresh)
	forestState:GetAttributeChangedSignal("Target"):Connect(refresh)
	CollectionService:GetInstanceAddedSignal("BridgeProgressBoard"):Connect(refresh)
	refresh()
end

function SiteAmbienceController.start()
	progressBoards(ReplicatedStorage:WaitForChild("ForestState"))
	local slewing = track("SiteSlew")
	local swaying = track("SiteSway")
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for model, base in slewing do
			local seconds = model:GetAttribute("SlewSeconds")
			local turn = now / (if typeof(seconds) == "number" and seconds > 0 then seconds else 240)
			model:PivotTo(base * CFrame.Angles(0, turn * 2 * math.pi, 0))
		end
		for model, base in swaying do
			model:PivotTo(base * CFrame.Angles(math.sin(now * SWAY_SPEED.X) * SWAY.X, 0, math.sin(now * SWAY_SPEED.Y + 1) * SWAY.Y))
		end
	end)
	task.spawn(function()
		local lit = false
		while true do
			task.wait(BLINK_SECONDS)
			lit = not lit
			for _, light in CollectionService:GetTagged("SiteBeacon") do
				if light:IsA("BasePart") then
					light.Transparency = if lit then 0 else BEACON_OFF
				end
			end
		end
	end)
end

return SiteAmbienceController
