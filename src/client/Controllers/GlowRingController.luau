--!strict
-- GlowRingController: the soft glowing ground rings (2026-10-08, like Build the Pyramid's): every part tagged
-- GlowRing (the shop's and the acorn dispensers' neon ring meshes, tagged by tools/build_map.luau) is hidden on this
-- client and drawn instead as a blurred ring texture lying on the ground in the part's color, turning slowly, a low
-- glowing wall standing on it (four curved Beams whose fading, streaky texture scrolls around the ring). The rising
-- streaks were removed on 2026-10-08 (the user's call: just the swirl). Only rings near the camera spin. Visual only.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "GlowRing"
local TEXTURE = "rbxassetid://139917524501692" -- tools/make_particle_textures.py glow_ring (decal 89571232641592)
local TEXTURE_CENTER = 0.72 -- the band's middle in the texture, as a fraction of its half-width (GLOW_RING_CENTER)
local LIFT = 0.12 -- studs above the ring mesh's middle, so the glow sits on the ground without flickering
local SPIN = 18 -- degrees per second
local BRIGHTNESS = 2.5
local NEAR_STUDS = 220 -- rings farther from the camera than this stop spinning
local WALL_TEXTURE = "rbxassetid://111090819332847" -- glow_wall (decal 103636328548536): opaque foot, clear top
local WALL_HEIGHT = 2.2 -- studs
local WALL_SPEED = 0.35 -- how fast the wall's streaks scroll around the ring (Beam.TextureSpeed)
local WALL_FLIP = true -- the beams' width axis points down, which puts the texture's bright edge at the foot
local CURVE = 0.5523 -- Bezier handle length per radius for a quarter circle

type Ring = { glow: Part, image: ImageLabel }

local GlowRingController = {}

local rings: { [BasePart]: Ring } = {}
local folder: Folder

local function add(source: Instance)
	if not source:IsA("BasePart") or rings[source] or not source:IsDescendantOf(workspace) then
		return
	end
	source.LocalTransparencyModifier = 1 -- the soft ring replaces the hard neon mesh
	local across = source.Size.X -- the mesh's outer diameter; the band's middle is just inside it
	local bandRadius = across / 2 * 0.97
	local glowAcross = 2 * bandRadius / TEXTURE_CENTER

	local glow = Instance.new("Part")
	glow.Name = "GlowRing"
	glow.Anchored, glow.CanCollide, glow.CanQuery, glow.CanTouch, glow.CastShadow = true, false, false, false, false
	glow.Transparency = 1
	glow.Size = Vector3.new(glowAcross, 0.05, glowAcross)
	glow.CFrame = CFrame.new(source.Position + Vector3.new(0, LIFT, 0))
	glow.Parent = folder
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Top
	surface.LightInfluence = 0
	surface.Brightness = BRIGHTNESS
	surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surface.CanvasSize = Vector2.new(512, 512)
	surface.Parent = glow
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = TEXTURE
	image.ImageColor3 = source.Color
	image.Parent = surface

	-- The wall: four quarter-circle Beams around the band, each attachment's X along the ring (the curve's handles)
	-- and Y up (the ribbon's width), so the ribbon stands upright.
	local corners: { Attachment } = {}
	for i = 0, 3 do
		local a = math.rad(90 * i)
		local corner = Instance.new("Attachment")
		corner.CFrame = CFrame.fromMatrix(
			Vector3.new(math.cos(a) * bandRadius, WALL_HEIGHT / 2, math.sin(a) * bandRadius),
			Vector3.new(-math.sin(a), 0, math.cos(a)),
			if WALL_FLIP then -Vector3.yAxis else Vector3.yAxis
		)
		corner.Parent = glow
		corners[i + 1] = corner
	end
	for i = 1, 4 do
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = corners[i], corners[i % 4 + 1]
		beam.CurveSize0, beam.CurveSize1 = CURVE * bandRadius, CURVE * bandRadius
		beam.FaceCamera = false
		beam.Width0, beam.Width1 = WALL_HEIGHT, WALL_HEIGHT
		beam.Segments = 16
		beam.Texture = WALL_TEXTURE
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureLength = 2 * math.pi * bandRadius / 8 -- the texture repeats 8 times around the ring
		beam.TextureSpeed = WALL_SPEED
		beam.Color = ColorSequence.new(source.Color)
		beam.LightEmission, beam.LightInfluence = 1, 0
		beam.Brightness = 2.5
		beam.Parent = glow
	end

	rings[source] = { glow = glow, image = image }
end

local function remove(source: Instance)
	local ring = rings[source :: BasePart]
	if ring then
		ring.glow:Destroy()
		rings[source :: BasePart] = nil
	end
end

function GlowRingController.start()
	folder = Instance.new("Folder")
	folder.Name = "GlowRings"
	folder.Parent = workspace
	for _, source in CollectionService:GetTagged(TAG) do
		add(source)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		local angle = os.clock() * SPIN % 360
		for _, ring in rings do
			if (ring.glow.Position - eye).Magnitude <= NEAR_STUDS then
				ring.image.Rotation = angle
			end
		end
	end)
end

return GlowRingController
