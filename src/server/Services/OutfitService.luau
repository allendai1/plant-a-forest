--!strict
-- OutfitService: the Park Ranger and Lord of the Forest characters (polish pass, 2026-10-07). Owners of a Hands pass
-- (PassService's HandsSpeed attribute) wear that character's accessories, cloned from
-- ReplicatedStorage.Assets.Outfits.<Outfit> (GameConfig.HandsPasses), on every spawn and as soon as they buy.
-- Only the best owned outfit is worn. The outfit's Shirt and Pants (catalog clothing) replace the player's own.
-- Everything put on is tagged so it can be swapped.
-- An NPC of each character (a model in Workspace.Map, dressed in Studio) stands by the upgrade shop's ring with a
-- prompt that sells its pass, and a copy goes to Assets.Outfits.<Outfit>Preview for the Robux shop's character cards.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local TAG = "Outfit"
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
	if not want then
		return
	end
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

local function onPlayerAdded(player: Player)
	player.CharacterAppearanceLoaded:Connect(function()
		dress(player)
	end)
	player:GetAttributeChangedSignal("HandsSpeed"):Connect(function()
		dress(player)
	end)
	if player.Character then
		dress(player)
	end
end

function OutfitService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

-- A glowing aura on an NPC (2026-10-08, the user's ask, like a sun god's): soft flames licking up off the torso,
-- arms and legs in the pass's Aura color, a few rising sparks, and a light on the ground around it.
local AURA_PARTS =
	{ "UpperTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg" }
local function addAura(rig: Model, color: Color3)
	local light = color:Lerp(Color3.new(1, 1, 1), 0.45)
	for _, name in AURA_PARTS do
		local part = rig:FindFirstChild(name)
		if not (part and part:IsA("BasePart")) then
			continue
		end
		local flames = Instance.new("ParticleEmitter")
		flames.Name = "AuraFlames"
		flames.Texture = "rbxasset://textures/particles/fire_main.dds"
		-- Mostly their own color: fully additive flames wash out to white in daylight.
		flames.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 0.6), 0.3), color)
		flames.LightEmission, flames.LightInfluence = 0.7, 0
		-- From the body's surface outward, so the body doesn't hide them.
		flames.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		flames.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		flames.Brightness = 2
		flames.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0.3) })
		flames.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.6, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		flames.Lifetime = NumberRange.new(0.35, 0.7)
		flames.Speed = NumberRange.new(1.5, 3)
		flames.Acceleration = Vector3.new(0, 5, 0)
		flames.Drag = 2
		flames.Rotation = NumberRange.new(0, 360)
		flames.RotSpeed = NumberRange.new(-90, 90)
		flames.Rate = if name == "UpperTorso" then 45 else 20
		flames.Parent = part
	end
	local torso = rig:FindFirstChild("UpperTorso")
	if torso and torso:IsA("BasePart") then
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "AuraSparks"
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Color = ColorSequence.new(light)
		sparks.LightEmission, sparks.LightInfluence = 1, 0
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		sparks.Lifetime = NumberRange.new(1, 1.6)
		sparks.Speed = NumberRange.new(2, 4)
		sparks.SpreadAngle = Vector2.new(60, 60)
		sparks.Acceleration = Vector3.new(0, 2, 0)
		sparks.Rate = 8
		sparks.Parent = torso
		local glow = Instance.new("PointLight")
		glow.Name = "AuraLight"
		glow.Color = color
		glow.Range = 12
		glow.Brightness = 1.5
		glow.Parent = torso
	end
end

-- The Park Ranger and Lord of the Forest NPCs: models in Workspace.Map tagged CharacterNpc with an Outfit attribute
-- (placed by tools/build_map.luau, dressed by the user in Studio). Each gets a prompt that sells its pass (the
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
		if pass.Aura then
			addAura(rig, pass.Aura) -- after the shop card's copy, which shows the plain outfit
		end
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
