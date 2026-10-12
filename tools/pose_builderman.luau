-- pose_builderman.luau: Builderman's static pose (2026-10-11): copied from the user's posed rig,
-- ServerStorage.BuildermanAssets.PoseRig (an R15 rig the user posed in Studio as Workspace.CustomRig; earlier the same day
-- a double-biceps flex, a hammer over the shoulder and a tool-equipped stance were tried; before that he looped Roblox's
-- idle and saluted when you walked up). Not shipped. Run it in the Edit datamodel through the Studio connection. Safe to
-- run again (each part is placed from the pose rig, not from where it is).
--
-- His rig's parts are all anchored (an Avatar Previewer rig: AnimationConstraints, not Motor6Ds), so the pose is set
-- straight on the parts, joint by joint out from his root: each part takes the pose rig's part's turn (relative to its
-- root) and sits where its joint attachment meets its parent's, so his own body sizes are kept. In his raised hand:
-- a copy of the user's hammer (ServerStorage.BuildermanAssets.Hammer, a MeshPart with its handle along Y) as Hammer
-- (anchored, no collisions), held at the hand's grip attachment like a Roblox tool. He loses the IdleNpc tag and the Animation
-- attribute, so NpcPoseController leaves him alone (no idle, no greeting).

local CollectionService = game:GetService("CollectionService")

local npc = workspace.Map.Model:FindFirstChild("Builderman") :: Model
assert(npc, "no Map.Model.Builderman")
local assets = game:GetService("ServerStorage"):WaitForChild("BuildermanAssets")
local poseRig = assets:FindFirstChild("PoseRig") :: Model
assert(poseRig, "no ServerStorage.BuildermanAssets.PoseRig")

local HAMMER_SCALE = 2 -- of the user's mesh (1.3 studs long)
local HAMMER_GRIP = -0.3 -- where the fist holds it, along the handle from the middle (as a share of its length)
local HAMMER_TURN = 0 -- degrees around the handle (which way the head faces)

-- R15, out from the root: each part, the part it hangs from, and the joint's attachment (named the same in both).
local CHAIN = {
	{ "LowerTorso", "HumanoidRootPart", "RootRigAttachment" },
	{ "UpperTorso", "LowerTorso", "WaistRigAttachment" },
	{ "Head", "UpperTorso", "NeckRigAttachment" },
	{ "RightUpperArm", "UpperTorso", "RightShoulderRigAttachment" },
	{ "RightLowerArm", "RightUpperArm", "RightElbowRigAttachment" },
	{ "RightHand", "RightLowerArm", "RightWristRigAttachment" },
	{ "LeftUpperArm", "UpperTorso", "LeftShoulderRigAttachment" },
	{ "LeftLowerArm", "LeftUpperArm", "LeftElbowRigAttachment" },
	{ "LeftHand", "LeftLowerArm", "LeftWristRigAttachment" },
	{ "RightUpperLeg", "LowerTorso", "RightHipRigAttachment" },
	{ "RightLowerLeg", "RightUpperLeg", "RightKneeRigAttachment" },
	{ "RightFoot", "RightLowerLeg", "RightAnkleRigAttachment" },
	{ "LeftUpperLeg", "LowerTorso", "LeftHipRigAttachment" },
	{ "LeftLowerLeg", "LeftUpperLeg", "LeftKneeRigAttachment" },
	{ "LeftFoot", "LeftLowerLeg", "LeftAnkleRigAttachment" },
}

local poseRoot = poseRig:FindFirstChild("HumanoidRootPart") :: BasePart
local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart
for _, link in CHAIN do
	local part = npc:FindFirstChild(link[1]) :: BasePart
	local parent = npc:FindFirstChild(link[2]) :: BasePart
	local posed = poseRig:FindFirstChild(link[1]) :: BasePart
	local turn = root.CFrame.Rotation * poseRoot.CFrame.Rotation:ToObjectSpace(posed.CFrame.Rotation)
	local joint = (parent:FindFirstChild(link[3]) :: Attachment).WorldPosition
	local own = (part:FindFirstChild(link[3]) :: Attachment).Position
	part.CFrame = CFrame.new(joint - turn:VectorToWorldSpace(own)) * turn
end

-- The hammer.
local old = npc:FindFirstChild("Hammer")
if old then
	old:Destroy()
end
-- In the higher hand, held the way Roblox holds a tool: out of the fist at the hand's grip attachment, the handle along
-- the attachment's up (across the fist, square to the forearm; along the forearm it looked like part of his arm), the
-- head in the plane of the swing (the attachment's look, back along the forearm).
local sideName = if npc.RightHand.Position.Y >= npc.LeftHand.Position.Y then "Right" else "Left"
local hand = npc:FindFirstChild(sideName .. "Hand") :: BasePart
local grip = (hand:FindFirstChild(sideName .. "GripAttachment") :: Attachment).WorldCFrame
local handle = (assets:WaitForChild("Hammer") :: BasePart):Clone()
handle.Size *= HAMMER_SCALE
local along = CFrame.fromMatrix(Vector3.zero, grip.LookVector, grip.UpVector) * CFrame.Angles(0, math.rad(HAMMER_TURN), 0)
handle.Name = "Hammer"
handle.CFrame = CFrame.new(grip.Position) * along * CFrame.new(0, -HAMMER_GRIP * handle.Size.Y, 0)
handle.Anchored = true
handle.CanCollide, handle.CanQuery, handle.CanTouch = false, false, false
handle.Massless = true
handle.Parent = npc

-- A happy face (the user's ask): the classic Roblox smile from the reference picture. His dynamic head's frown is painted
-- into its SurfaceAppearance (its FaceControls bend the mesh but can't change the paint, and aren't saved anyway), so
-- that goes to ServerStorage.BuildermanAssets.OriginalFace, the head takes his skin color, and the classic smile decal
-- goes on its front.
local head = npc:FindFirstChild("Head") :: BasePart
local painted = head:FindFirstChildOfClass("SurfaceAppearance")
if painted then
	local kept = assets:FindFirstChild("OriginalFace")
	if kept then
		kept:Destroy()
	end
	painted.Name = "OriginalFace"
	painted.Parent = assets
end
head.Color = (npc:FindFirstChild("LeftHand") :: BasePart).Color
local smile = head:FindFirstChild("face") or Instance.new("Decal")
smile.Name = "face"
smile.Texture = "rbxasset://textures/face.png" -- Roblox's classic smile
smile.Face = Enum.NormalId.Front
smile.Parent = head

CollectionService:RemoveTag(npc, "IdleNpc")
npc:SetAttribute("Animation", nil)
return `Builderman posed from PoseRig (hammer in his {sideName} hand, smiling)`
