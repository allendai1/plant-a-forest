--!strict
-- ForestService: the hex grid and all plot state (docs/ARCHITECTURE.md section 3).
-- Builds the plots around the ForestCenter part, answers GetForest with the snapshot, handles
-- PlantSeeds (validation, overflow, first-seed setup), opens the forest one row at a time, and sends changed
-- plots to every client in one HexBatch every Forest.BatchSeconds. Each seed pays the planter coins (M5).
-- When the last row fills it calls the onComplete callback (AwakeningService, M6); reset() empties it.
-- GUI pass: addSeeds() puts bought seeds (the Robux buttons under the Forest Bar) into the open rows;
-- what doesn't fit waits for the next forest. ForestState BarBoostBy / BarBoostSeeds / BarBoosts (a count)
-- tell clients to show the banner. Planting coins are times the planter's Friend Boost.
-- Seed shop (docs/plans/SeedShop.md): free acorns start Common trees only. PlantSpecial puts a special seed
-- from the player's bag into an open Common plot, which becomes that tree with the player as its owner
-- (starterUserId). When a special tree is full grown its boosts start: the owner's training (TreeBoost
-- attribute) and, for the rarest, everyone's (ForestState ServerTreeBoost, with TreeBoostBy /
-- TreeBoostSeed / TreeBoosts for the banner). TrainingService reads them through ownerBoost() and
-- serverBoost(); reset() ends them with the forest.
-- Rounds (GameConfig.Rounds, 2026-10-09): a server's first forests open only the inner 2, 4, then 6 rings; plots
-- outside the round have row 0 and never open. ForestState Round / RingCount / LastRing tell clients.
-- Worlds: setTier() picks which tier the next forest is (AwakeningService's roulette). The tier sets what the
-- free acorns grow (Tiers[].Commons) and multiplies planting coins (CoinMultiplier); ForestState TierId.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.GameConfig)
local HexGrid = require(Shared.HexGrid)
local Remotes = require(Shared.Remotes)
local Targeting = require(Shared.Targeting)
local Trees = require(Shared.Trees)
local Types = require(Shared.Types)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local FriendService = require(script.Parent.FriendService)
local PassService = require(script.Parent.PassService)
local BadgeAwardService = require(script.Parent.BadgeAwardService)
local TreeCounterService = require(script.Parent.TreeCounterService)
local Guard = require(script.Parent.Parent.Guard)
local Analytics = require(script.Parent.Parent.Analytics)

type Plot = {
	index: number,
	q: number,
	r: number,
	ring: number,
	position: Vector3, -- hex center on the ground
	seeds: number,
	species: number, -- 0 = none, else an index into Trees.Species
	mutation: number, -- 0 = none
	starterUserId: number, -- 0 = none
	treeSeed: number, -- 0 = none
	side: number, -- the forest section (1..6, between two walkway spokes): HexGrid.side
	row: number, -- index into rows
}

-- A row is one whole ring (since 2026-10-07, the user's call: was one section's slice of a ring, the sections in
-- turn). Only one row is open at a time, from the outer ring in to the hub, so everyone can work the part of the
-- ring nearest their dispenser.
type Row = { ring: number, plantable: number, finished: number }

local CENTER_TAG = "ForestCenter"
local WALK_FLOOR_TAG = "WalkFloor"
local RAY_START_HEIGHT = 500 -- ground raycasts start this far above the ForestCenter
local RAY_LENGTH = 1000
local MAX_TREE_SEED = 2 ^ 31 - 1

local ForestService = {}

local plots: { Plot } = {}
local plotByKey: { [string]: number } = {}
-- The old forest outside the field (GameConfig.Field, 2026-10-09): q, r and ground height of every spot on the town's
-- side that would be a plot, sent with the snapshot; clients stand full-grown trees there (ForestController).
local backdrop: { number } = {}
local rows: { Row } = {}
local dirty: { [number]: boolean } = {}
local dirtyCount = 0
local seq = 0
local totalSeeds = 0
local openRow = 1 -- index into rows; #rows + 1 once the forest is complete
local seedsPerHex = 0
local center: BasePart
local forestState: Folder
local rng = Random.new()
local onComplete: (() -> ())? = nil
local completePending = false -- the forest just filled; onComplete runs after the next flush
local coinCarry: { [Player]: number } = {} -- fractions of a coin from the Friend Boost, paid when whole
local leftover: { { player: Player, seeds: number } } = {} -- bought seeds waiting for the next forest
local barBoosts = 0
-- Seed shop, by UserId so a player who rejoins this server gets theirs back; all end with the forest.
local ownerBoostSums: { [number]: number } = {} -- the owner boosts of each player's full-grown special trees
-- Acorns each player (by UserId) put into this forest, by hand or with bar boosts. Forest credit (+1 forest and
-- the reward, AwakeningService) needs Stats.ForestCreditSeeds; the ForestPlanted attribute shows the count.
local forestPlanted: { [number]: number } = {}
local serverBoostSum = 0
local treeBoosts = 0 -- server-wide boosts started this server (the banner's counter)
local specialsPlanted: { [number]: number } = {} -- special seeds each player planted this forest
local tierIndex = 1 -- index into GameConfig.Tiers: the world this forest is in
local ringPlanters: { [number]: { [number]: boolean } } = {} -- row -> UserIds who planted in it (RingsHelped)

local function findCenter(): BasePart
	local tagged = CollectionService:GetTagged(CENTER_TAG)
	assert(#tagged == 1, `ForestService: expected exactly one part tagged "{CENTER_TAG}", found {#tagged}`)
	local part = tagged[1]
	assert(part:IsA("BasePart"), `ForestService: the "{CENTER_TAG}" instance must be a BasePart`)
	return part
end

-- Center-only no-plant check: is the point inside the part's top-down footprint?
local function insideFootprint(part: BasePart, point: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	return math.abs(p.X) <= part.Size.X / 2 and math.abs(p.Z) <= part.Size.Z / 2
end

local function buildPlots()
	local grid = GameConfig.Grid

	local noPlant: { BasePart } = {}
	for _, inst in CollectionService:GetTagged(grid.NoPlantTag) do
		if inst:IsA("BasePart") then
			table.insert(noPlant, inst)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { center }
	for _, part in noPlant do
		table.insert(exclude, part)
	end
	-- The invisible floor that bridges the seams between tiles (M6b) sits at tile height; skip it.
	for _, floor in CollectionService:GetTagged(WALK_FLOOR_TAG) do
		table.insert(exclude, floor)
	end
	params.FilterDescendantsInstances = exclude

	for i, ring in HexGrid.rings(grid.HubRings + grid.ForestRings) do
		local radius = i - 1
		if radius > grid.HubRings then
			for j, hex in ring do
				local flat = HexGrid.toWorld(hex.q, hex.r, grid.HexSize, center.Position)
				local offset = flat - center.Position
				-- Outside the field (GameConfig.Field): no plot, a tree of the old forest instead.
				local outside = not GameConfig.inField(math.deg(math.atan2(offset.Z, offset.X)))
				local blocked = false
				for _, part in noPlant do
					if insideFootprint(part, flat) then
						blocked = true
						break
					end
				end
				local hit = if blocked
					then nil
					else workspace:Raycast(
						flat + Vector3.new(0, RAY_START_HEIGHT, 0),
						Vector3.new(0, -RAY_LENGTH, 0),
						params
					)
				-- No ground under the hex, or terrain water: not plantable.
				if hit and hit.Material ~= Enum.Material.Water and outside then
					table.insert(backdrop, hex.q)
					table.insert(backdrop, hex.r)
					table.insert(backdrop, hit.Position.Y)
				elseif hit and hit.Material ~= Enum.Material.Water then
					local index = #plots + 1
					plots[index] = {
						index = index,
						q = hex.q,
						r = hex.r,
						ring = radius,
						position = Vector3.new(flat.X, hit.Position.Y, flat.Z),
						seeds = 0,
						species = 0,
						mutation = 0,
						starterUserId = 0,
						treeSeed = 0,
						side = (j - 1) // radius + 1, -- the same as HexGrid.side(hex.q, hex.r)
						row = 0,
					}
					plotByKey[HexGrid.key(hex.q, hex.r)] = index
				end
			end
		end
	end
end

-- This server's ring order: from the outer ring in (true) or from the hub out (false). GameConfig.Grid.OutsideIn,
-- or a weighted pick per server while the layout A/B test runs (GameConfig.Experiments.LayoutTest).
local outsideIn = GameConfig.Grid.OutsideIn
local round = 1 -- this server's forest number (GameConfig.Rounds)
local wholeRound = false -- every ring of this small round is open at once (Rounds.OpenWholeRound)

-- Orders the rows: one per ring, outside-in (outsideIn) or inside-out, only the round's rings (GameConfig.Rounds).
-- Plots outside the round get row 0 and never open.
local function buildRows()
	table.clear(rows)
	local grid = GameConfig.Grid
	local inner, outer = grid.HubRings + 1, grid.HubRings + grid.ForestRings
	local limit = if GameConfig.Rounds.Enabled then GameConfig.Rounds.Rings[round] or math.huge else math.huge
	local plantable: { [number]: number } = {}
	for _, plot in plots do
		plantable[plot.ring] = (plantable[plot.ring] or 0) + 1
	end
	local index: { [number]: number } = {}
	for i = 0, outer - inner do
		local ring = if outsideIn then outer - i else inner + i
		local count = plantable[ring]
		if count and #rows < limit then -- a ring with nothing to plant is skipped
			table.insert(rows, { ring = ring, plantable = count, finished = 0 })
			index[ring] = #rows
		end
	end
	for _, plot in plots do
		plot.row = index[plot.ring] or 0
	end
end

-- The trees in this forest (the round's rings).
local function plantablePlots(): number
	local count = 0
	for _, row in rows do
		count += row.plantable
	end
	return count
end

-- The round, for clients and analytics: Round, RingCount ("Ring 3 of 9"), LastRing (the round's last ring, 0 when
-- every ring is in) and Layout (the analytics' variant: "Round 2" while rounds are on).
local function publishRound()
	forestState:SetAttribute("Round", round)
	forestState:SetAttribute("RingCount", #rows)
	local rounds = GameConfig.Rounds
	local small = rounds.Enabled and rounds.Rings[round] ~= nil
	wholeRound = small and rounds.OpenWholeRound
	forestState:SetAttribute("WholeRound", wholeRound)
	forestState:SetAttribute("LastRing", if small and #rows > 0 then rows[#rows].ring else 0)
	-- Few values for the analytics fields: every full-size round is "Round 4+".
	local layout = if outsideIn then "OuterFirst" else "InnerFirst"
	if rounds.Enabled then
		layout = if small then `Round {round}` else `Round {#rounds.Rings + 1}+`
	end
	forestState:SetAttribute("Layout", layout)
end

local function plotAt(q: number, r: number): Plot?
	local index = plotByKey[HexGrid.key(q, r)]
	return if index then plots[index] else nil
end

local function isGrownAt(q: number, r: number): boolean
	local plot = plotAt(q, r)
	return plot ~= nil and plot.seeds >= seedsPerHex
end

-- The open ring, and since 2026-10-09 the plots just behind its full-grown trees (Grid.AheadRings).
local function isOpen(plot: Plot): boolean
	local row = rows[openRow]
	if plot.row == 0 then
		return false -- outside this round
	elseif wholeRound then
		return row ~= nil and plot.seeds < seedsPerHex -- a small round: all of it, until the forest is complete
	end
	return Targeting.isOpenPlot(
		plot.q,
		plot.r,
		plot.ring,
		plot.seeds >= seedsPerHex,
		if row then row.ring else 0,
		outsideIn,
		GameConfig.Grid.AheadRings,
		isGrownAt
	)
end

local function isOpenAt(q: number, r: number): boolean
	local plot = plotAt(q, r)
	return plot ~= nil and isOpen(plot)
end

local function markDirty(plot: Plot)
	if not dirty[plot.index] then
		dirty[plot.index] = true
		dirtyCount += 1
	end
end

-- The open row as the OpenRow attribute: (0, ring), the 0 meaning the whole ring; (0, 0) once the forest is
-- complete. (X was the section while rows were sections.) RingCount is how many rings there are.
local function openRowValue(): Vector2
	local row = rows[openRow]
	return if row then Vector2.new(0, row.ring) else Vector2.zero
end

-- Moves past every row whose trees are all (RingUnlockFill) full grown.
local function advanceRows()
	local before = openRow
	while rows[openRow] do
		local row = rows[openRow]
		if row.finished < math.ceil(row.plantable * GameConfig.Grid.RingUnlockFill) then
			break
		end
		openRow += 1
	end
	for i = before, openRow - 1 do
		Analytics.ringCompleted(i, rows[i].plantable)
		local planters = ringPlanters[i]
		if planters then
			for userId in planters do
				local planter = Players:GetPlayerByUserId(userId)
				if planter then
					DataService.add(planter, "RingsHelped", 1) -- the "Help finish a ring" quest
				end
			end
		end
	end
	if openRow ~= before then
		-- The OpenRow attribute is set in flush(), after the batch with the finishing seeds.
		local row = rows[openRow]
		if row then
			print(`[ForestService] ring {before} done, ring {openRow} of {#rows} is open (ring {row.ring})`)
		else
			print("[ForestService] every row is full: the forest is complete")
			completePending = true
		end
	end
end

function ForestService.ownerBoost(player: Player): number
	return math.min(ownerBoostSums[player.UserId] or 0, GameConfig.SeedShop.OwnerBoostCap)
end

function ForestService.serverBoost(): number
	return 1 + math.min(serverBoostSum, GameConfig.SeedShop.ServerBoostCap)
end

-- A special tree just became full grown: its boosts start.
local function startTreeBoost(plot: Plot)
	local def = GameConfig.seedDef(Trees.Species[plot.species] or "")
	if not def then
		return
	end
	local owner = Players:GetPlayerByUserId(plot.starterUserId)
	ownerBoostSums[plot.starterUserId] = (ownerBoostSums[plot.starterUserId] or 0) + def.OwnerBoost
	if owner then
		owner:SetAttribute("TreeBoost", ForestService.ownerBoost(owner))
	end
	if def.ServerBoost > 0 then
		serverBoostSum += def.ServerBoost
		treeBoosts += 1
		forestState:SetAttribute("ServerTreeBoost", ForestService.serverBoost())
		forestState:SetAttribute("TreeBoostBy", if owner then owner.DisplayName else "Someone")
		forestState:SetAttribute("TreeBoostSeed", def.Id)
		forestState:SetAttribute("TreeBoosts", treeBoosts)
	end
end

local function finish(plot: Plot, player: Player?)
	if player then
		Analytics.treeFinished(player) -- they planted its last seed
		DataService.add(player, "TreesFinished", 1) -- the "Grow 3 trees" quest
		local profile = DataService.get(player)
		if profile and profile.FirstTreeDone == 0 then
			-- Their first tree ever: the client celebrates when FirstTreeDone turns 1 (TutorialController).
			local coins = GameConfig.Economy.FirstTreeCoins
			DataService.add(player, "Coins", coins)
			DataService.set(player, "FirstTreeDone", 1)
			Analytics.earned(player, coins, "FirstTree", Enum.AnalyticsEconomyTransactionType.Onboarding)
		end
	end
	rows[plot.row].finished += 1
	TreeCounterService.add(1) -- the hub's counter of every tree grown
	startTreeBoost(plot)
	advanceRows()
end

-- A new tree's look, picked by the server on its first seed: free acorns grow this world's Common trees.
local function startTree(plot: Plot)
	local commons = GameConfig.Tiers[tierIndex].Commons
	plot.species = Trees.index(commons[rng:NextInteger(1, #commons)])
	plot.treeSeed = rng:NextInteger(1, MAX_TREE_SEED)
end

-- Pays CoinsPerSeed per seed times the world's CoinMultiplier and (1 + Friend Boost), carrying fractions of
-- a coin to the next seed.
local function payCoins(player: Player, seeds: number)
	if not DataService.get(player) then
		return -- left the game (their bought seeds can still land in the next forest)
	end
	local perSeed = GameConfig.Economy.CoinsPerSeed * GameConfig.Tiers[tierIndex].CoinMultiplier
	local total = seeds * perSeed * (1 + FriendService.boost(player)) + (coinCarry[player] or 0)
	local whole = math.floor(total + 1e-9) -- 150 * 1.2 is 179.99999... in floating point
	coinCarry[player] = total - whole
	if whole > 0 then
		DataService.add(player, "Coins", whole)
		Analytics.plantingCoins(player, whole)
	end
end

-- Plants up to `count` seeds into one plot and returns how many went in.
-- Each seed pays the planter CoinsPerSeed (times the mutation multiplier from M9 and the boost from M6).
-- `special` (a species index) turns the plot into that special tree, owned by the player.
local function plantInto(plot: Plot, player: Player, count: number, special: number?): number
	local added = math.min(count, seedsPerHex - plot.seeds)
	if added <= 0 then
		return 0
	end
	if plot.seeds == 0 then
		plot.starterUserId = player.UserId
		startTree(plot)
	end
	if special then
		plot.species = special
		plot.starterUserId = player.UserId
	end
	plot.seeds += added
	totalSeeds += added
	payCoins(player, added)
	DataService.add(player, "SeedsPlanted", added)
	local mine = (forestPlanted[player.UserId] or 0) + added
	forestPlanted[player.UserId] = mine
	local planters = ringPlanters[plot.row] or {}
	ringPlanters[plot.row] = planters
	planters[player.UserId] = true
	player:SetAttribute("ForestPlanted", mine)
	Analytics.onboarding(player, "PlantedSeed")
	markDirty(plot)
	if plot.seeds >= seedsPerHex then
		finish(plot, player)
	end
	return added
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- The open plot at (q, r) if the player may plant into it now (alive, within range), and their root part.
local function plantTarget(player: Player, q: unknown, r: unknown): (Plot?, BasePart?)
	if typeof(q) ~= "number" or typeof(r) ~= "number" then
		return nil, nil
	end
	-- Whole numbers inside the grid; this also rejects NaN (NaN ~= NaN) and infinities.
	local outer = GameConfig.Grid.HubRings + GameConfig.Grid.ForestRings
	if q ~= q or r ~= r or math.abs(q) > outer or math.abs(r) > outer or q % 1 ~= 0 or r % 1 ~= 0 then
		return nil, nil
	end
	local target = plotAt(q, r)
	if not target or not isOpen(target) then
		return nil, nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")) then
		return nil, nil
	end
	-- The server's own copy of the player's position, with a little slack for lag.
	local range = EconomyService.plantRange(player) + GameConfig.Planting.RangeToleranceStuds
	if flatDistance(root.Position, target.position) > range then
		return nil, nil
	end
	return target, root
end

-- A special seed from the bag into an open Common plot (docs/plans/SeedShop.md).
local function onPlantSpecial(player: Player, seedId: unknown, q: unknown, r: unknown)
	local rate = GameConfig.SeedShop.PlantRate
	if not Guard.allow(player, "PlantSpecial", rate.PerSecond, rate.Burst) then
		return
	end
	if not GameConfig.Features.SeedShop then
		return
	end
	local def = if typeof(seedId) == "string" then GameConfig.seedDef(seedId) else nil
	local species = if def then Trees.index(def.Id) else 0
	if not def or not Trees.isSpecial(species) then
		return
	end
	local target = plantTarget(player, q, r)
	if not target or Trees.isSpecial(target.species) then
		return -- already a special tree
	end
	local planted = specialsPlanted[player.UserId] or 0
	if planted >= GameConfig.SeedShop.PerForestLimit or DataService.bagCount(player, def.Id) < 1 then
		return
	end
	DataService.addToBag(player, def.Id, -1)
	specialsPlanted[player.UserId] = planted + 1
	player:SetAttribute("SpecialsPlanted", planted + 1)
	plantInto(target, player, 1, species)
	Analytics.custom(player, "SpecialSeedPlanted", def.Id)
	BadgeAwardService.award(player, "SpecialTree")
	Analytics.forestPlanted(player, 1)
end

local function onPlantSeeds(player: Player, q: unknown, r: unknown)
	local planting = GameConfig.Planting
	local perSecond = planting.PlantRateSlack / GameConfig.pressSeconds(PassService.handsSpeed(player))
	if not Guard.allow(player, "PlantSeeds", perSecond, planting.PlantBurst) then
		return
	end
	local target, root = plantTarget(player, q, r)
	if not (target and root) then
		return
	end
	local range = EconomyService.plantRange(player)
	local carried = CarryService.get(player)
	if carried < 1 then
		return
	end

	local remaining = math.min(EconomyService.upgradeValue(player, "BulkPlant"), carried) -- Bulk Plant
	local planted = plantInto(target, player, remaining)
	remaining -= planted
	if remaining > 0 then
		-- Overflow: the next-closest open plots to the player, within range.
		local grid = GameConfig.Grid
		for _, candidate in Targeting.openNear(root.Position, range, grid.HexSize, center.Position, isOpenAt) do
			local plot = plotAt(candidate.q, candidate.r)
			if plot then
				local added = plantInto(plot, player, remaining)
				planted += added
				remaining -= added
			end
			if remaining <= 0 then
				break
			end
		end
	end
	CarryService.take(player, planted)
	if planted > 0 then
		Analytics.forestPlanted(player, planted)
	end
end

local function stateOf(plot: Plot, into: { number })
	table.insert(into, plot.seeds)
	table.insert(into, plot.species)
	table.insert(into, plot.mutation)
	table.insert(into, plot.starterUserId)
	table.insert(into, plot.treeSeed)
end

local function snapshot(): Types.Snapshot
	local layout = table.create(#plots * 3)
	local state = table.create(#plots * 5)
	for _, plot in plots do
		table.insert(layout, plot.q)
		table.insert(layout, plot.r)
		table.insert(layout, plot.position.Y)
		stateOf(plot, state)
	end
	return { seq = seq, layout = layout, state = state, backdrop = backdrop }
end

local function flush()
	if dirtyCount == 0 then
		return
	end
	local entries = table.create(dirtyCount * 6)
	for index in dirty do
		table.insert(entries, index)
		stateOf(plots[index], entries)
	end
	table.clear(dirty)
	dirtyCount = 0
	seq += 1
	forestState:SetAttribute("Seeds", totalSeeds)
	local batch: Types.HexBatch = { seq = seq, entries = entries }
	Remotes.event("HexBatch"):FireAllClients(batch)
	-- After the batch, so clients have the finishing seeds before the row or section moment starts.
	local value = openRowValue()
	if forestState:GetAttribute("OpenRow") ~= value then
		forestState:SetAttribute("OpenRow", value)
	end
	-- The open ring's progress, for the HUD's ring trunk (its full-grown trees of the ring's total; 2026-10-08).
	local ring = rows[openRow]
	forestState:SetAttribute("RingDone", if ring then ring.finished else 0)
	forestState:SetAttribute("RingTrees", if ring then ring.plantable else 0)
	-- The next ring's early progress (two rings, 2026-10-09): the trunk fills its band too.
	local nextRing = if ring and GameConfig.Grid.AheadRings > 0 then rows[openRow + 1] else nil
	forestState:SetAttribute("NextRingDone", if nextRing then nextRing.finished else 0)
	forestState:SetAttribute("NextRingTrees", if nextRing then nextRing.plantable else 0)
	-- Also after the batch, so clients have the last tree before the forest complete moment starts.
	if completePending then
		completePending = false
		if onComplete then
			task.spawn(onComplete)
		end
	end
end

-- Bought seeds: fills the open rows in order as if the buyer planted them (coins included). Seeds that
-- don't fit (the forest is complete, or the break is on) wait for the next forest.
local function fillOpenRows(player: Player, seeds: number): number
	local left = seeds
	while left > 0 and rows[openRow] do
		local before = totalSeeds
		for _, plot in plots do
			if left <= 0 then
				break
			end
			if isOpen(plot) then
				left -= plantInto(plot, player, left)
			end
		end
		if totalSeeds == before then
			break -- nothing went in (can't happen while a row is open, but never loop forever)
		end
	end
	return left
end

-- Did this player put enough acorns into the current forest to get credit for it?
function ForestService.hasForestCredit(player: Player): boolean
	return (forestPlanted[player.UserId] or 0) >= GameConfig.Stats.ForestCreditSeeds
end

-- Studio-only testing (DevService): set how many acorns the player has put into this forest.
function ForestService.devSetPlanted(player: Player, seeds: number)
	forestPlanted[player.UserId] = seeds
	player:SetAttribute("ForestPlanted", seeds)
end

function ForestService.addSeeds(player: Player, seeds: number)
	Analytics.forestBought(seeds)
	local left = fillOpenRows(player, seeds)
	if left > 0 then
		table.insert(leftover, { player = player, seeds = left })
	end
	barBoosts += 1
	forestState:SetAttribute("BarBoostBy", player.DisplayName)
	forestState:SetAttribute("BarBoostSeeds", seeds)
	forestState:SetAttribute("BarBoosts", barBoosts)
end

-- The world the next forest is in (call before reset()).
-- Sizes the next forest for this world and the players in the server now (GameConfig.seedsPerHexFor): seeds per
-- tree and the bar's target. Only between forests: a growing forest keeps its size.
local function sizeForest()
	local tier = GameConfig.Tiers[tierIndex]
	seedsPerHex = GameConfig.seedsPerHexFor(tier, #Players:GetPlayers(), #plots)
	forestState:SetAttribute("SeedsPerHex", seedsPerHex) -- worlds and server sizes differ
	forestState:SetAttribute("Target", GameConfig.forestTarget(plantablePlots(), seedsPerHex)) -- the round's trees
end

function ForestService.setTier(index: number)
	local tier = GameConfig.Tiers[index]
	if not tier then
		return
	end
	tierIndex = index
	forestState:SetAttribute("TierId", tier.Id)
	sizeForest()
	print(`[ForestService] the next forest is {tier.Name}`)
end

function ForestService.setOnComplete(callback: () -> ())
	onComplete = callback
end

-- Empties every plot and opens the first row again (MVP: tier 1 again). Clients get it as one HexBatch.
function ForestService.reset()
	for _, plot in plots do
		plot.seeds = 0
		plot.species = 0
		plot.mutation = 0
		plot.starterUserId = 0
		plot.treeSeed = 0
		markDirty(plot)
	end
	round += 1
	buildRows() -- the next round's rings (GameConfig.Rounds), all unfinished
	publishRound()
	totalSeeds = 0
	openRow = 1
	completePending = false
	-- The special trees are gone, and their boosts with them; everyone can plant 3 again.
	table.clear(ownerBoostSums)
	table.clear(specialsPlanted)
	table.clear(forestPlanted) -- forest credit starts again
	table.clear(ringPlanters)
	serverBoostSum = 0
	forestState:SetAttribute("ServerTreeBoost", 1)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("TreeBoost", 0)
		player:SetAttribute("SpecialsPlanted", 0)
		player:SetAttribute("ForestPlanted", 0)
	end
	sizeForest() -- for the players here now (before the waiting seeds below go in)
	print(`[ForestService] the forest was reset: {seedsPerHex} seeds per tree for {#Players:GetPlayers()} players`)
	Analytics.forestStarted()
	-- Seeds bought while the last forest was full go into this one (a buyer who left gets no coins).
	local waiting = leftover
	leftover = {}
	for _, entry in waiting do
		local left = fillOpenRows(entry.player, entry.seeds)
		if left > 0 then
			table.insert(leftover, { player = entry.player, seeds = left })
		end
	end
end

-- Studio-only test helpers (called by DevService).
function ForestService.devFillOpenRow(leaveEmpty: number)
	local open: { Plot } = {}
	for _, plot in plots do
		if plot.row == openRow and isOpen(plot) then -- the open ring only, not the plots opened ahead of it
			table.insert(open, plot)
		end
	end
	for i = 1, #open - math.max(0, math.floor(leaveEmpty)) do
		local plot = open[i]
		if plot.seeds == 0 then
			startTree(plot)
		end
		totalSeeds += seedsPerHex - plot.seeds
		plot.seeds = seedsPerHex
		markDirty(plot)
		rows[plot.row].finished += 1
		startTreeBoost(plot)
	end
	advanceRows()
end

-- Fills plots row by row, in opening order, until the bar reaches `fraction` of the target.
function ForestService.devFillForest(fraction: number)
	local goal = math.floor(math.clamp(fraction, 0, 1) * plantablePlots() * seedsPerHex)
	while totalSeeds < goal do
		local plot: Plot? = nil
		for _, candidate in plots do
			if isOpen(candidate) then
				plot = candidate
				break
			end
		end
		if not plot then
			break
		end
		if plot.seeds == 0 then
			startTree(plot)
		end
		local added = math.min(seedsPerHex - plot.seeds, goal - totalSeeds)
		plot.seeds += added
		totalSeeds += added
		markDirty(plot)
		if plot.seeds >= seedsPerHex then
			finish(plot)
		end
	end
end

-- Fills every ring in opening order; the last one keeps `leaveEmpty` plots empty.
function ForestService.devFillAll(leaveEmpty: number)
	while rows[openRow] do
		local before = openRow
		ForestService.devFillOpenRow(if rows[openRow + 1] then 0 else leaveEmpty)
		if openRow == before then
			break -- the ring kept empty plots, so it stays open
		end
	end
end

function ForestService.init()
	local started = os.clock()
	-- The Edit-mode tile preview (tools/forest_preview.luau) goes before anyone joins: clients build the real tiles.
	local preview = workspace:FindFirstChild("ForestPreview")
	if preview then
		preview:Destroy()
	end
	center = findCenter()
	-- The town's side (GameConfig.Field): its trails lead nowhere now (2026-10-09, the user's ask), so they go for this
	-- server: the visible trail, its no-planting strip and the bridge at its end (the floating islet stays). Before
	-- the plots, so the old forest fills their spots too.
	local function outsideField(at: Vector3): boolean
		local offset = at - center.Position
		return not GameConfig.inField(math.deg(math.atan2(offset.Z, offset.X)))
	end
	if GameConfig.Field.Enabled then
		local map = workspace:FindFirstChild("Map")
		local lobby = map and map:FindFirstChild("Lobby")
		local island = map and map:FindFirstChild("Island")
		local walkways = map and map:FindFirstChild("Walkways")
		for _, list in { lobby and lobby:GetChildren(), island and island:GetChildren(), walkways and walkways:GetChildren() } do
			for _, item in list or {} do
				local trail = item.Name == "LobbyPath" or item.Name == "Bridge" or item.Parent == walkways
				local at = if item:IsA("Model")
					then item:GetBoundingBox().Position
					elseif item:IsA("BasePart") then item.Position
					else nil
				if trail and at and outsideField(at) then
					item:Destroy()
				end
			end
		end
	end
	buildPlots()
	-- The field's side of the hub (GameConfig.Field): the dispensers facing away from it go for this server, and
	-- the spawn turns to face the World Tree, so a new player looks across the hub at the forest.
	if GameConfig.Field.Enabled then
		for _, rack in CollectionService:GetTagged("SeedRack") do
			local at = if rack:IsA("Model") then rack:GetPivot().Position elseif rack:IsA("BasePart") then rack.Position else nil
			if at and outsideField(at) then
				rack:Destroy()
			end
		end
		for _, spawn in workspace:GetDescendants() do
			if spawn:IsA("SpawnLocation") then
				local at = spawn.Position
				spawn.CFrame = CFrame.lookAt(at, Vector3.new(center.Position.X, at.Y, center.Position.Z))
			end
		end
	end
	if GameConfig.Rounds.Enabled then
		outsideIn = false -- rounds grow from the hub out
	elseif GameConfig.Experiments.LayoutTest then
		outsideIn = rng:NextNumber() < GameConfig.Experiments.OuterFirstShare
	end
	buildRows()

	local tier = GameConfig.Tiers[1]
	-- Sized for the players here at start (usually none yet: a server's first forest is a small one).
	seedsPerHex = GameConfig.seedsPerHexFor(tier, #Players:GetPlayers(), #plots)
	local target = GameConfig.forestTarget(plantablePlots(), seedsPerHex)

	forestState = Instance.new("Folder")
	forestState.Name = "ForestState"
	forestState:SetAttribute("TierId", tier.Id)
	forestState:SetAttribute("Seeds", 0)
	forestState:SetAttribute("Target", target)
	forestState:SetAttribute("SeedsPerHex", seedsPerHex)
	-- The ring order, for the clients' ring numbers; the round and its rings (and Layout, for every analytics event).
	forestState:SetAttribute("OutsideIn", outsideIn)
	publishRound()
	forestState:SetAttribute("OpenRow", openRowValue())
	forestState:SetAttribute("RingDone", 0)
	forestState:SetAttribute("RingTrees", if rows[openRow] then rows[openRow].plantable else 0)
	forestState:SetAttribute("NextRingDone", 0)
	forestState:SetAttribute("NextRingTrees", 0)
	-- Clients place tiles from this, so they don't depend on the ForestCenter part streaming in.
	forestState:SetAttribute("Center", center.Position)
	forestState:SetAttribute("ServerTreeBoost", 1)
	forestState.Parent = ReplicatedStorage

	Remotes.func("GetForest").OnServerInvoke = function(player: Player): Types.Snapshot?
		local rate = GameConfig.Forest.SnapshotRate
		if not Guard.allow(player, "GetForest", rate.PerSecond, rate.Burst) then
			return nil
		end
		return snapshot()
	end
	Remotes.event("PlantSeeds").OnServerEvent:Connect(onPlantSeeds)
	Remotes.event("PlantSpecial").OnServerEvent:Connect(onPlantSpecial)
	Players.PlayerRemoving:Connect(function(player)
		coinCarry[player] = nil
	end)
	-- Back in this server during the same forest: their trees' boost and planting count come back.
	local function onJoin(player: Player)
		player:SetAttribute("TreeBoost", ForestService.ownerBoost(player))
		player:SetAttribute("SpecialsPlanted", specialsPlanted[player.UserId] or 0)
		player:SetAttribute("ForestPlanted", forestPlanted[player.UserId] or 0) -- kept if they rejoin
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end

	local perRing = {}
	for _, row in rows do
		table.insert(perRing, `{row.ring}:{row.plantable}`)
	end
	print(
		`[ForestService] {#plots} plantable plots, target {target} ({seedsPerHex} seeds per hex), `
			.. `{#rows} rings, built in {math.round((os.clock() - started) * 1000)} ms. `
			.. `Plots per ring: {table.concat(perRing, " ")}`
	)
end

function ForestService.start()
	while true do
		task.wait(GameConfig.Forest.BatchSeconds)
		flush()
	end
end

return ForestService
