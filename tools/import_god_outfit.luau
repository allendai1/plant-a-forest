-- import_god_outfit.luau: turns the God of Hammers armor import (ServerStorage.GodImport, the FBX from
-- tools/blender/build_god_of_hammers.py; the God of Construction's before 2026-10-11), inserted with the Studio connection's insert_asset) into the wearable outfit
-- ReplicatedStorage.Assets.Outfits.God, and re-dresses the NPC (Map.Model.BuilderBot, the God of Hammers until 2026-10-11). Not shipped. Run in
-- the Edit datamodel; safe to run again.
--
-- Each piece <BodyPart>__<Color>__<n> gets BodyPart and Offset attributes (its CFrame from that body part at rest, read
-- against the import's REF_<BodyPart> box in the character's frame: front = toward the visor) and its color/material.
-- OutfitService welds the pieces on at those offsets.

local import = game.ServerStorage:FindFirstChild("GodImport")
assert(import, "no ServerStorage.GodImport")

-- The God of Hammers' colors (2026-10-11: the yellow construction robot from the user's reference;
-- tools/blender/build_god_of_hammers.py; a Thor-style armor's before): bright construction yellow plates on a dark
-- frame, yellow hands, a grey hammer, silver bolts, a bronze chest frame, orange pouches, a black face screen with glowing
-- cyan eyes, warm glowing lamps and a red light.
local LOOK = {
	Yellow = { Color3.fromRGB(250, 196, 30), Enum.Material.SmoothPlastic, 0.05 },
	Dark = { Color3.fromRGB(52, 50, 48), Enum.Material.SmoothPlastic, 0.05 },
	Steel = { Color3.fromRGB(118, 118, 122), Enum.Material.SmoothPlastic, 0.1 },
	Trim = { Color3.fromRGB(205, 208, 214), Enum.Material.SmoothPlastic, 0.25 },
	Bronze = { Color3.fromRGB(105, 78, 52), Enum.Material.SmoothPlastic, 0.1 },
	Orange = { Color3.fromRGB(232, 110, 30), Enum.Material.SmoothPlastic, 0 },
	Hazard = { Color3.fromRGB(24, 24, 26), Enum.Material.SmoothPlastic, 0 }, -- hazard-stripe black (mech v2)
	Red = { Color3.fromRGB(255, 70, 50), Enum.Material.Neon, 0 },
	Screen = { Color3.fromRGB(14, 15, 18), Enum.Material.Glass, 0.2 },
	Eye = { Color3.fromRGB(80, 235, 255), Enum.Material.Neon, 0 },
	Glow = { Color3.fromRGB(255, 225, 150), Enum.Material.Neon, 0 },
}

local parts: { [string]: BasePart } = {}
for _, d in import:GetDescendants() do
	if d:IsA("BasePart") then
		-- Without Blender's ".001" ending (it adds one when an older armor's objects in the same file have the name).
		parts[(string.gsub(d.Name, "%.%d+$", ""))] = d
	end
end
local head = parts.REF_Head
local visor: BasePart? = nil
for name, p in parts do
	-- The face's front piece: the robot's face screen (a visor on the armors before).
	if string.find(name, "^Head__Screen") or string.find(name, "^Head__Visor") then
		visor = p
	end
end
assert(head and visor, "no REF_Head or face screen in the import")
local up = head.CFrame.UpVector
local front = visor.Position - head.Position
front = (front - up * front:Dot(up)).Unit
local right = front:Cross(up)

local outfits = game.ReplicatedStorage.Assets.Outfits
local old = outfits:FindFirstChild("God")
if old then
	old:Destroy()
end
local outfit = Instance.new("Folder")
outfit.Name = "God"
local count = 0
for name, p in parts do
	local body, color = string.match(name, "^(%w+)__(%w+)__%d+$")
	local ref = body and parts["REF_" .. body]
	if body and color and ref then
		local frame = CFrame.fromMatrix(ref.Position, right, up, -front)
		local piece = p:Clone()
		piece.Name = `{body}_{color}_{count + 1}`
		piece:SetAttribute("BodyPart", body)
		piece:SetAttribute("Offset", frame:ToObjectSpace(p.CFrame))
		local look = LOOK[color]
		piece.Color, piece.Material, piece.Reflectance = look[1], look[2], look[3]
		piece.Anchored, piece.CanCollide, piece.CanQuery, piece.CanTouch, piece.Massless = false, false, false, false, true
		piece.CastShadow = look[2] ~= Enum.Material.Neon
		piece.Parent = outfit
		count += 1
	end
end
-- Lightning bolts flickering over the whole body (2026-10-11, the user's ask): the bolt emitters of the Creator Store
-- aura "POF:RE AURA: Cloak of Lightning" (its spheres of lightning and light left out), copied to
-- ServerStorage.LightningBoltTemplate. Each R15 part gets an invisible box a bit bigger than the body part, welded like
-- any armor piece (Offset = none: it sits on the part), with the three emitters spraying bolts through its volume.
local BOLT_BOX = 1.2 -- the box's size, times the body part's (the armor stands out past the body)
-- Slower than the aura's own (0.1 s, speed 0.5, 10 a second), so the bolts flow over the body (the user's ask); the
-- rate halved so the longer-lived bolts don't crowd it.
local BOLT_LIFETIME = 0.4 -- seconds
local BOLT_SPEED = 1.2 -- studs a second, along the bolt
local BOLT_RATE = 5 -- per emitter, a second
local boltTemplate = game.ServerStorage:FindFirstChild("LightningBoltTemplate")
assert(boltTemplate, "no ServerStorage.LightningBoltTemplate (the aura's bolt emitters)")
for name, ref in parts do
	local body = string.match(name, "^REF_(%w+)$")
	if body then
		local box = Instance.new("Part")
		box.Name = `{body}_Bolts`
		box.Size = ref.Size * BOLT_BOX
		box.Transparency = 1
		box.Anchored, box.CanCollide, box.CanQuery, box.CanTouch, box.Massless = false, false, false, false, true
		box.CastShadow = false
		box:SetAttribute("BodyPart", body)
		box:SetAttribute("Offset", CFrame.new())
		for _, emitter in boltTemplate:GetChildren() do
			local bolt = emitter:Clone() :: ParticleEmitter
			bolt.Lifetime = NumberRange.new(BOLT_LIFETIME)
			bolt.Speed = NumberRange.new(BOLT_SPEED)
			bolt.Rate = BOLT_RATE
			bolt.Parent = box
		end
		box.Parent = outfit
	end
end
-- Speed lines while running (2026-10-11, the user's ask; they replaced a black and yellow caution-tape trail): the
-- treadmill's white and black line emitters (Assets.SpeedLines2, without its stars) in an invisible box round the body,
-- on the HumanoidRootPart so the box doesn't sway with the walk. The emitters shoot along the box's +X, turned to the
-- character's back, and leave their lines in the world, so the faster the wearer runs the longer they stream behind.
-- They start off; RunLinesController (client) turns the RunLines-tagged box on while its character moves.
local LINES_BOX = Vector3.new(2.5, 6, 5) -- studs: along the back, height, across
local LINES_RATE = 25 -- per emitter, a second (the asset's 100 is for a 28 x 18 stud box)
local LINES_LIFE = NumberRange.new(0.15, 0.35) -- seconds
local LINES_SPEED = NumberRange.new(10, 30) -- studs a second backward, on top of the running speed
local LINES_SIZE = 0.5 -- of the asset's sizes, like the treadmills
local linesAsset = game.ReplicatedStorage.Assets:FindFirstChild("SpeedLines2")
assert(linesAsset, "no ReplicatedStorage.Assets.SpeedLines2 (the treadmill speed lines)")
local linesBox = Instance.new("Part")
linesBox.Name = "SpeedLines"
linesBox.Size = LINES_BOX
linesBox.Transparency = 1
linesBox.Anchored, linesBox.CanCollide, linesBox.CanQuery, linesBox.CanTouch, linesBox.Massless = false, false, false, false, true
linesBox.CastShadow = false
linesBox:SetAttribute("BodyPart", "HumanoidRootPart")
-- +X (where the emitters shoot) along the root's +Z, its back; centred on the body (feet -3, helmet top +2.7).
linesBox:SetAttribute("Offset", CFrame.fromMatrix(Vector3.new(0, -0.15, 0), Vector3.zAxis, Vector3.yAxis))
for _, source in linesAsset:GetChildren() do
	if source:IsA("ParticleEmitter") and source.Name ~= "star" then
		local line = source:Clone()
		line.Enabled = false
		line.Rate = LINES_RATE
		line.Lifetime = LINES_LIFE
		line.Speed = LINES_SPEED
		local points = {}
		for _, point in line.Size.Keypoints do
			table.insert(points, NumberSequenceKeypoint.new(point.Time, point.Value * LINES_SIZE, point.Envelope * LINES_SIZE))
		end
		line.Size = NumberSequence.new(points)
		line.Transparency = NumberSequence.new({ -- fading in and out (the asset's cut off at full)
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.12, 0),
			NumberSequenceKeypoint.new(0.45, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		line.Parent = linesBox
	end
end
linesBox:AddTag("RunLines")
linesBox.Parent = outfit

outfit.Parent = outfits

-- The NPC: its old armor off, the new on.
local npc = nil
for _, d in workspace.Map:GetDescendants() do
	if d:IsA("Model") and d.Name == "BuilderBot" then -- "God of Hammers" until the rename, 2026-10-11
		npc = d
	end
end
if npc then
	for _, d in npc:GetChildren() do
		if d:IsA("BasePart") and d:GetAttribute("BodyPart") then
			d:Destroy()
		end
	end
	for _, piece in outfit:GetChildren() do
		local part = npc:FindFirstChild(piece:GetAttribute("BodyPart")) :: BasePart?
		if part then
			local copy = piece:Clone()
			copy.CFrame = part.CFrame * piece:GetAttribute("Offset")
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = part, copy
			weld.Parent = copy
			copy.Parent = npc
		end
	end
end
return `{count} pieces into Assets.Outfits.God; NPC re-dressed: {npc ~= nil}`
