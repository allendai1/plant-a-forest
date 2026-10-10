--!strict
-- TrainingService: benches, treadmills, walk speed and camera settings (docs/plans/M2b.md).
-- Bench: its ProximityPrompt fires on the server; the server checks reach and the unlock, then holds
-- the character on the bench (root anchored) until LeaveBench, death or leaving.
-- Treadmill: standing inside a TreadmillStation zone trains Speed, with nothing to press.
-- Either way, every full RepSeconds on an unlocked station pays RepAmount * the station's multiplier,
-- timed per player from the moment they start. Getting off drops the unfinished rep.
-- The Ancient Spring (M6): during the break after a forest, standing within SpringRadiusStuds of the
-- hub center, on the platform up in the World Tree (SpringHeightStuds; TreeClimbService, 2026-10-09), trains Strength and Speed together, RepAmount * your best unlocked station * the spring multiplier each per rep.
-- GUI pass: every gain is also times the player's boost (PassService.boost) and, while it runs, the
-- server training boost bought in the Robux shop (ForestState ServerBoostEndsAt, ServerBoostBy and
-- ServerBoosts, a purchase count clients watch for the banner).
-- Seed shop: also times the special trees' boosts (ForestService.ownerBoost and serverBoost).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local Remotes = require(Shared.Remotes)
local AwakeningService = require(script.Parent.AwakeningService)
local DataService = require(script.Parent.DataService)
local ForestService = require(script.Parent.ForestService)
local PassService = require(script.Parent.PassService)
local Guard = require(script.Parent.Parent.Guard)
local Analytics = require(script.Parent.Parent.Analytics)

local BENCH_TAG = "BenchStation"
local TREADMILL_TAG = "TreadmillStation"
local LEAVE_OFFSET = CFrame.new(0, 0, -7) -- where a player stands after getting up, in the seat's frame
local SPRING_HEIGHT = 30 -- the spring counts up to this far above its floor (not on the ramp below it)
local SPRING = Instance.new("Folder") -- stands for the Ancient Spring as a player's station

type Session = {
	station: Instance?, -- the bench model or treadmill zone being trained on
	elapsed: number,
	bench: Model?, -- set while benching
	lockedNotified: Instance?, -- the locked treadmill this player was already told about
}

local TrainingService = {}

local sessions: { [Player]: Session } = {}
local boostEndsAt = 0 -- server time the server training boost ends
local boostCount = 0

-- One "BOOST Server Training!" purchase: adds ServerBoost.Seconds for everyone.
function TrainingService.addServerBoost(player: Player?)
	local now = workspace:GetServerTimeNow()
	boostEndsAt = math.max(boostEndsAt, now) + GameConfig.ServerBoost.Seconds
	boostCount += 1
	local forestState = ReplicatedStorage:WaitForChild("ForestState")
	forestState:SetAttribute("ServerBoostBy", if player then player.DisplayName else "Someone")
	forestState:SetAttribute("ServerBoostEndsAt", boostEndsAt)
	forestState:SetAttribute("ServerBoosts", boostCount)
end

local function serverBoost(): number
	return if workspace:GetServerTimeNow() < boostEndsAt then GameConfig.ServerBoost.Multiplier else 1
end

-- A rep's gain of one stat for this player, times their boost pass, the server boost and the special
-- trees' boosts (their own trees and the server-wide ones, docs/plans/SeedShop.md).
local function gain(player: Player, stat: PassService.BoostStat, amount: number)
	local trees = (1 + ForestService.ownerBoost(player)) * ForestService.serverBoost()
	DataService.add(player, stat, amount * PassService.boost(player, stat) * serverBoost() * trees)
	Analytics.onboarding(player, "Trained")
end

local function multiplierOf(station: Instance): number
	local value = station:GetAttribute("Multiplier")
	return if typeof(value) == "number" then value else 1
end

local function isUnlocked(player: Player, multiplier: number): boolean
	local needed = GameConfig.forestsForMultiplier(multiplier)
	local profile = DataService.get(player)
	if needed == nil or profile == nil then
		return false
	end
	return profile.ForestsCompleted >= needed or PassService.owns(player, multiplier)
end

-- The best station this player can train on (by forests or a station pass); the Spring multiplies it.
local function bestUnlocked(player: Player): number
	local best = 1
	for _, step in GameConfig.Stats.GymMultipliers do
		if step.Multiplier > best and isUnlocked(player, step.Multiplier) then
			best = step.Multiplier
		end
	end
	return best
end

local function notifyLocked(player: Player, multiplier: number)
	Analytics.stationLocked(player, multiplier)
	Remotes.event("StationLocked"):FireClient(player, multiplier, GameConfig.forestsForMultiplier(multiplier))
end

local function liveCharacter(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

local function seatOf(bench: Model): BasePart?
	local seat = bench:FindFirstChild("Seat")
	return if seat and seat:IsA("BasePart") then seat else nil
end

local function inside(zone: BasePart, point: Vector3): boolean
	local p = zone.CFrame:PointToObjectSpace(point)
	local half = zone.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

local function treadmillAt(point: Vector3, zones: { Instance }): BasePart?
	for _, zone in zones do
		if zone:IsA("BasePart") and inside(zone, point) then
			return zone
		end
	end
	return nil
end

local function releaseBench(player: Player)
	local session = sessions[player]
	local bench = session and session.bench
	if not session or not bench then
		return
	end
	session.bench = nil
	player:SetAttribute("Benching", "")
	local seat = seatOf(bench)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = false
		if seat then
			root.CFrame = seat.CFrame * LEAVE_OFFSET
		end
	end
	if humanoid then
		humanoid.Sit = false
	end
end

local function startBench(player: Player, bench: Model)
	local session = sessions[player]
	local seat = seatOf(bench)
	local humanoid, root = liveCharacter(player)
	if not session or session.bench or not seat or not humanoid or not root then
		return
	end
	-- The prompt has its own range, but the server re-checks it with its own copy of the position.
	if (root.Position - seat.Position).Magnitude > GameConfig.Stations.BenchReachStuds then
		return
	end
	local multiplier = multiplierOf(bench)
	if not isUnlocked(player, multiplier) then
		notifyLocked(player, multiplier)
		return
	end
	session.bench = bench
	root.Anchored = true
	root.CFrame = seat.CFrame
	humanoid.Sit = true
	player:SetAttribute("BenchedAt", workspace:GetServerTimeNow())
	player:SetAttribute("Benching", bench.Name)
end

local function hookBench(bench: Instance)
	if not bench:IsA("Model") then
		return
	end
	local prompt = bench:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.MaxActivationDistance = GameConfig.Stations.PromptStuds
		prompt.Triggered:Connect(function(player)
			startBench(player, bench)
		end)
	end
end

local function applyWalkSpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local profile = DataService.get(player)
	if humanoid and profile then
		local earned = GameConfig.walkSpeed(profile.Speed)
		humanoid.WalkSpeed = if profile.WalkCap > 0 then math.min(earned, profile.WalkCap) else earned
	end
end

local function onPlayerAdded(player: Player)
	player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
	player.CameraMaxZoomDistance = GameConfig.Camera.MaxZoomStuds
	player:SetAttribute("Benching", "")
	player:SetAttribute("Running", false)
	player:SetAttribute("InSpring", false)
	sessions[player] = { station = nil, elapsed = 0, bench = nil, lockedNotified = nil }
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				releaseBench(player)
			end)
			applyWalkSpeed(player)
		end
	end)
	player.CharacterRemoving:Connect(function()
		releaseBench(player)
	end)
	-- Only server-side writes fire this on the server, so a client editing its own attribute changes nothing.
	player:GetAttributeChangedSignal("Speed"):Connect(function()
		applyWalkSpeed(player)
	end)
	player:GetAttributeChangedSignal("WalkCap"):Connect(function()
		applyWalkSpeed(player)
	end)
	applyWalkSpeed(player)
end

local function inSpring(root: BasePart?): boolean
	local center = ReplicatedStorage:FindFirstChild("ForestState")
	local origin = center and center:GetAttribute("Center")
	if not root or typeof(origin) ~= "Vector3" then
		return false
	end
	local offset = root.Position - origin
	local above = offset.Y - GameConfig.Awakening.SpringHeightStuds -- over the Spring's floor
	return Vector2.new(offset.X, offset.Z).Magnitude <= GameConfig.Awakening.SpringRadiusStuds
		and above >= -1
		and above <= SPRING_HEIGHT
end

local function step(dt: number)
	local stats = GameConfig.Stats
	local treadmills = CollectionService:GetTagged(TREADMILL_TAG)
	local spring = AwakeningService.springMultiplier()
	for player, session in sessions do
		local station: Instance? = session.bench
		local stat: PassService.BoostStat = "Strength"
		if not station then
			local _, root = liveCharacter(player)
			if spring > 0 and inSpring(root) then
				station = SPRING
			end
			local zone = if root then treadmillAt(root.Position, treadmills) else nil
			if station then
				session.lockedNotified = nil
			elseif zone and isUnlocked(player, multiplierOf(zone)) then
				station, stat = zone, "Speed"
			elseif zone and session.lockedNotified ~= zone then
				session.lockedNotified = zone -- tell them once per visit, not every check
				notifyLocked(player, multiplierOf(zone))
			end
			if not zone then
				session.lockedNotified = nil
			end
		end
		if station ~= session.station then
			-- Started, stopped or switched: a fresh rep. The player arrived at some point during the
			-- last check interval, so that interval counts toward the first rep.
			session.station = station
			session.elapsed = if station then dt else 0
			player:SetAttribute("Running", station ~= nil and station ~= SPRING and stat == "Speed")
			player:SetAttribute("InSpring", station == SPRING)
			if station == SPRING then
				DataService.set(player, "SpringGuideSeen", 1) -- the first-break guide is done (TutorialController)
			end
		elseif station then
			session.elapsed += dt
			local reps = math.floor(session.elapsed / stats.RepSeconds)
			if reps > 0 then
				session.elapsed -= reps * stats.RepSeconds
				if station == SPRING then
					local amount = reps * stats.RepAmount * bestUnlocked(player) * spring
					gain(player, "Strength", amount)
					gain(player, "Speed", amount)
				else
					gain(player, stat, reps * stats.RepAmount * multiplierOf(station))
				end
			end
		end
	end
end

function TrainingService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	for _, bench in CollectionService:GetTagged(BENCH_TAG) do
		hookBench(bench)
	end
	CollectionService:GetInstanceAddedSignal(BENCH_TAG):Connect(hookBench)
	-- The player's own walk speed limit: 0 (none) or a whole number from WalkSpeed.Base up.
	Remotes.event("SetWalkCap").OnServerEvent:Connect(function(player: Player, cap: unknown)
		local rate = GameConfig.WalkCap.Rate
		if not Guard.allow(player, "SetWalkCap", rate.PerSecond, rate.Burst) then
			return
		end
		-- cap ~= cap rejects NaN; the range check rejects infinities.
		if typeof(cap) ~= "number" or cap ~= cap or cap < 0 or cap > GameConfig.WalkCap.Max then
			return
		end
		local value = if cap == 0 then 0 else math.max(math.round(cap), GameConfig.Stats.WalkSpeed.Base)
		DataService.set(player, "WalkCap", value)
	end)
	Remotes.event("LeaveBench").OnServerEvent:Connect(function(player: Player)
		local rate = GameConfig.Stations.LeaveRate
		if Guard.allow(player, "LeaveBench", rate.PerSecond, rate.Burst) then
			releaseBench(player)
		end
	end)
end

function TrainingService.start()
	local last = os.clock()
	while true do
		task.wait(GameConfig.Stats.TrainingCheckSeconds)
		local now = os.clock()
		step(now - last)
		last = now
	end
end

return TrainingService
