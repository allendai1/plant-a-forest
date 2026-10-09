--!strict
-- CarryService: the seeds each player is carrying (docs/ARCHITECTURE.md section 3, docs/plans/M3.md).
-- Counts live here on the server (session only) and are mirrored to the `Carried` attribute.
-- The seed rack is a ProximityPrompt. Triggered (fired on the server) grabs once and starts a
-- server-side repeat every HoldRepeatSeconds; TriggerEnded (the player let go of E) stops it.
-- Every grab re-checks reach and capacity, and grabs are never closer together than the player's pace
-- (HoldRepeatSeconds, faster with a Hands pass), so tapping fast is no quicker than holding.
-- DropSeeds (Q) empties your hands, anywhere (lobby only until 2026-10-08).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Parent.Guard)
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.Parent.Analytics)
local EconomyService = require(script.Parent.EconomyService)
local PassService = require(script.Parent.PassService)

local RACK_TAG = "SeedRack"
local TIMING_SLACK = 0.01 -- task.wait wakes a hair early or late; don't drop a grab over that

type Holder = { holding: boolean, lastGrab: number }

local CarryService = {}

local carried: { [Player]: number } = {}
local holders: { [Player]: Holder } = {}

local function set(player: Player, count: number)
	carried[player] = count
	player:SetAttribute("Carried", count)
end

function CarryService.get(player: Player): number
	return carried[player] or 0
end

-- Removes up to `count` seeds and returns how many were actually taken.
function CarryService.take(player: Player, count: number): number
	local have = CarryService.get(player)
	local taken = math.clamp(math.floor(count), 0, have)
	set(player, have - taken)
	return taken
end

-- Studio-only testing (DevService): set the carried count directly.
function CarryService.devSet(player: Player, count: number)
	set(player, math.max(0, math.floor(count)))
end

local function capacityOf(player: Player): number
	local profile = DataService.get(player)
	return GameConfig.capacity(if profile then profile.Strength else 0)
end

local function inReach(player: Player, rack: Instance): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")) then
		return false
	end
	-- Measured from the rack's middle (the dispenser tower), the same spot its prompt is measured from.
	local center = if rack:IsA("Model") then rack:GetPivot().Position elseif rack:IsA("BasePart") then rack.Position else nil
	return center ~= nil and (root.Position - center).Magnitude <= GameConfig.Planting.RackRangeStuds
end

-- One grab. Returns whether holding should keep repeating.
local function grab(player: Player, rack: Instance): boolean
	local holder = holders[player]
	if not holder then
		return false
	end
	local now = os.clock()
	if now - holder.lastGrab < GameConfig.pressSeconds(PassService.handsSpeed(player)) - TIMING_SLACK then
		return true -- too soon after the last grab; try again on the next repeat
	end
	if not inReach(player, rack) then
		return false
	end
	local have, capacity = CarryService.get(player), capacityOf(player)
	if have >= capacity then
		return false
	end
	local perPress = EconomyService.upgradeValue(player, "BulkPickup")
	local after = have + math.min(perPress, capacity - have)
	set(player, after)
	holder.lastGrab = now
	Analytics.onboarding(player, "PickedUpSeeds")
	return after < capacity
end

local function onTriggered(player: Player, rack: Instance)
	local holder = holders[player]
	if not holder or holder.holding then
		return
	end
	holder.holding = true
	task.spawn(function()
		local first = true
		while holder.holding and holders[player] == holder do
			if not grab(player, rack) then
				break
			end
			local pace = GameConfig.pressSeconds(PassService.handsSpeed(player))
			-- A pause before the repeat starts, so a tap is one grab (Planting.HoldDelaySeconds).
			task.wait(if first then math.max(pace, GameConfig.Planting.HoldDelaySeconds) else pace)
			first = false
		end
		holder.holding = false
	end)
end

local function onTriggerEnded(player: Player)
	local holder = holders[player]
	if holder then
		holder.holding = false
	end
end

local function hookRack(rack: Instance)
	local prompt = rack:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function(player)
			onTriggered(player, rack)
		end)
		prompt.TriggerEnded:Connect(onTriggerEnded)
	end
end

local function onDrop(player: Player)
	local rate = GameConfig.Drop.Rate
	if not Guard.allow(player, "DropSeeds", rate.PerSecond, rate.Burst) then
		return
	end
	if CarryService.get(player) > 0 then
		local holder = holders[player]
		if holder then
			holder.holding = false -- a held grab at the dispenser stops too
		end
		set(player, 0)
	end
end

local function onPlayerAdded(player: Player)
	holders[player] = { holding = false, lastGrab = 0 }
	set(player, 0)
end

function CarryService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		holders[player] = nil
		carried[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	for _, rack in CollectionService:GetTagged(RACK_TAG) do
		hookRack(rack)
	end
	CollectionService:GetInstanceAddedSignal(RACK_TAG):Connect(hookRack)
	Remotes.event("DropSeeds").OnServerEvent:Connect(onDrop)
end

return CarryService
