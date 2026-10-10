--!strict
-- OutfitService: the Forest Ranger and Lord of the Forest characters (polish pass, 2026-10-07). Owners of a Hands pass
-- (PassService's HandsSpeed attribute) wear that character's accessories, cloned from
-- ReplicatedStorage.Assets.Outfits.<Outfit> (GameConfig.HandsPasses), on every spawn and as soon as they buy.
-- Only the best owned outfit is worn. The outfit's Shirt and Pants (catalog clothing) replace the player's own.
-- Everything put on is tagged so it can be swapped.
-- The character's aura too (2026-10-08): every ParticleEmitter named Aura... (Aura, AuraOutline) on its NPC (the green water aura on the
-- Forest Ranger, set up and edited in Studio) is copied onto the same body part of the owner's character.
-- An NPC of each character (a model in Workspace.Map, dressed in Studio) stands by the upgrade shop's ring with a
-- prompt that sells its pass, and a copy goes to Assets.Outfits.<Outfit>Preview for the Robux shop's character cards.
-- The gnome (2026-10-09, GameConfig.Gnome): everyone's avatar is replaced by the forest gnome (the player's own avatar
-- isn't loaded at all: StarterPlayer.LoadCharacterAppearance off) on every spawn, before the character outfit goes on
-- top. Owning a character outfit leaves the gnome's cap off for that character's own hat.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local TAG = "Outfit"
local AURA_TAG = "OutfitAura"
local STASH = "OwnClothes"

local OutfitService = {}

local function outfitFor(player: Player): string?
	local speed = player:GetAttribute("HandsSpeed")
	local best: string? = nil
	for _, pass in GameConfig.HandsPasses do
		if typeof(speed) == "number" and speed >= pass.Multiplier then
			best = pass.Outfit
		end
	end
	return best
end

-- Copies the aura emitters (named Aura..., like Aura and its dark AuraOutline) from the character's NPC onto the same
-- body parts of `character`.
local function wearAura(character: Model, outfit: string)
	for _, npc in CollectionService:GetTagged("CharacterNpc") do
		if npc:GetAttribute("Outfit") ~= outfit then
			continue
		end
		for _, emitter in npc:GetDescendants() do
			local part = emitter.Parent
			local target = part and character:FindFirstChild(part.Name)
			if emitter:IsA("ParticleEmitter") and emitter.Name:match("^Aura") and target and target:IsA("BasePart") then
				local copy = emitter:Clone()
				copy:SetAttribute("Outfit", outfit)
				CollectionService:AddTag(copy, AURA_TAG)
				copy.Parent = target
			end
		end
	end
end

local function dress(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and humanoid) then
		return
	end
	local want = outfitFor(player)
	-- The player's own shirt and pants wait in this folder (not worn) while an outfit's clothing replaces them.
	local stash: Instance = character:FindFirstChild(STASH) or Instance.new("Folder")
	stash.Name = STASH
	stash.Parent = character
	for _, item in character:GetChildren() do
		if CollectionService:HasTag(item, TAG) and item:GetAttribute("Outfit") ~= want then
			item:Destroy()
			local own = if item:IsA("Clothing") then stash:FindFirstChildOfClass(item.ClassName) else nil
			if own then
				own.Parent = character
			end
		end
	end
	for _, emitter in CollectionService:GetTagged(AURA_TAG) do
		if emitter:IsDescendantOf(character) then
			emitter:Destroy() -- put back fresh below, so it always matches the NPC's
		end
	end
	if not want then
		return
	end
	wearAura(character, want)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local outfits = assets and assets:FindFirstChild("Outfits")
	local outfit = outfits and outfits:FindFirstChild(want)
	if not outfit then
		return
	end
	for _, item in outfit:GetChildren() do
		if item:IsA("Accessory") and not character:FindFirstChild(item.Name) then
			local copy = item:Clone()
			copy:SetAttribute("Outfit", want)
			CollectionService:AddTag(copy, TAG)
			humanoid:AddAccessory(copy)
		elseif item:IsA("Clothing") then
			local own = character:FindFirstChildOfClass(item.ClassName)
			if own and CollectionService:HasTag(own, TAG) then
				continue
			elseif own then
				own.Parent = stash
			end
			local copy = item:Clone()
			copy:SetAttribute("Outfit", want)
			CollectionService:AddTag(copy, TAG)
			copy.Parent = character
		end
	end
end

-- The forest gnome's whole look (GameConfig.Gnome), without the cap when a character outfit brings its own hat.
local function gnome(withCap: boolean): HumanoidDescription
	local g = GameConfig.Gnome
	local look = Instance.new("HumanoidDescription")
	look.Head = g.Head
	look.MoodAnimation = g.Mood
	for _, part in { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" } do
		(look :: any)[part] = g.Skin
	end
	local accessories = {
		{ AccessoryType = Enum.AccessoryType.Face, AssetId = g.Beard, IsLayered = false },
		{ AccessoryType = Enum.AccessoryType.Eyebrow, AssetId = g.Brows, IsLayered = false },
	}
	if withCap then
		table.insert(accessories, { AccessoryType = Enum.AccessoryType.Hat, AssetId = g.Hat, IsLayered = false })
	end
	look:SetAccessories(accessories, true)
	return look
end

-- The gnome first (it replaces everything worn), then the character outfit on top.
local function dressAll(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if GameConfig.Gnome.Enabled and humanoid then
		local ok, err = pcall(humanoid.ApplyDescriptionAsync, humanoid, gnome(outfitFor(player) == nil))
		if not ok then
			warn(`[OutfitService] gnome look for {player.Name}: {err}`)
		end
	end
	if player.Character == character then -- not respawned while the look loaded
		dress(player)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		if not character.Parent then
			character.AncestryChanged:Wait() -- ApplyDescription needs the character in the world
		end
		dressAll(player)
	end)
	player:GetAttributeChangedSignal("HandsSpeed"):Connect(function()
		dressAll(player)
	end)
	if player.Character then
		task.spawn(dressAll, player)
	end
end

function OutfitService.init()
	if GameConfig.Gnome.Enabled then
		StarterPlayer.LoadCharacterAppearance = false -- the gnome replaces the avatar; don't load it first
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

-- The Forest Ranger and Lord of the Forest NPCs: models in Workspace.Map tagged CharacterNpc with an Outfit attribute
-- (placed by tools/build_map.luau, dressed by the user in Studio; the Ranger's green aura is particle emitters and a
-- light in the model itself, made 2026-10-08, so it can be edited in Studio). Each gets a prompt that sells its pass (the
-- client's RobuxShopController answers prompts with a PassId attribute; CharacterDisplayController draws the price,
-- name and boosts sign over it), and a copy goes to
-- Assets.Outfits.<Outfit>Preview for the shop's character cards. Their pose (an idle, or the Animation attribute) is played by each client (NpcPoseController).
local function setUpNpcs()
	for _, rig in CollectionService:GetTagged("CharacterNpc") do
		local outfit = rig:GetAttribute("Outfit")
		local root = rig:FindFirstChild("HumanoidRootPart")
		local pass: GameConfig.HandsPass? = nil
		for _, candidate in GameConfig.availableHandsPasses() do
			if candidate.Outfit == outfit then
				pass = candidate
			end
		end
		if not pass then
			-- A character switched off by its feature flag: its NPC and display stand leave the map for this server.
			local lobby = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Lobby")
			for _, item in
				{ rig, lobby and lobby:FindFirstChild(`{outfit}Stand`), lobby and lobby:FindFirstChild(`{outfit}StandRim`) }
			do
				if item then
					item.Parent = ServerStorage
				end
			end
			continue
		end
		if not (rig:IsA("Model") and root and root:IsA("BasePart")) then
			continue
		end
		for _, part in rig:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
		local preview = rig:Clone()
		preview.Name = `{pass.Outfit}Preview`
		preview:PivotTo(CFrame.new())
		CollectionService:RemoveTag(preview, "CharacterNpc")
		CollectionService:RemoveTag(preview, "IdleNpc")
		preview.Parent = ReplicatedStorage.Assets.Outfits
		local prompt = Instance.new("ProximityPrompt")
		-- Just "E  Buy": the sign above the NPC already shows the name, price and boosts (the user's call, 2026-10-07).
		prompt.ObjectText = ""
		prompt.ActionText = "Buy"
		prompt.Style = Enum.ProximityPromptStyle.Custom -- drawn by PromptController
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("PassId", pass.PassId)
		prompt.Parent = root
	end
end

function OutfitService.start()
	setUpNpcs()
end

return OutfitService
