--!strict
-- CollisionService: players walk through each other (2026-10-10). The bridge is the one way to the work and back, and
-- with a full server on it characters pushing each other made a jam (and knocked people off the edge). Every part of
-- every character goes in the "Players" collision group, which doesn't collide with itself.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local GROUP = "Players"

local CollisionService = {}

local function setGroup(part: Instance)
	if part:IsA("BasePart") then
		part.CollisionGroup = GROUP
	end
end

local function onCharacter(character: Model)
	for _, part in character:GetDescendants() do
		setGroup(part)
	end
	character.DescendantAdded:Connect(setGroup) -- accessories and tools added later
end

function CollisionService.init()
	PhysicsService:RegisterCollisionGroup(GROUP)
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
end

function CollisionService.start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			onCharacter(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return CollisionService
