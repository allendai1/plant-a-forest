--!strict
-- GlowRing: the soft glowing ground rings at the upgrade shop and the acorn dispensers (2026-10-08, like Build the
-- Pyramid's). build() turns a ring mesh into the effect, as real instances in the place so they show (and can be
-- edited) in Studio's Edit mode: the neon mesh goes invisible and a GlowRingFx part beside it carries a blurred ring
-- texture lying on the ground in the mesh's color and a low glowing wall standing on it (four curved Beams whose
-- fading, streaky texture scrolls around the ring by itself). tools/build_map.luau calls it; the only runtime part
-- is GlowRingController turning the ground texture. Visual only.

local CollectionService = game:GetService("CollectionService")

local GlowRing = {}

GlowRing.TAG = "GlowRing" -- on each GlowRingFx part (GlowRingController spins its ground texture)

local TEXTURE = "rbxassetid://139917524501692" -- tools/make_particle_textures.py glow_ring (decal 89571232641592)
local TEXTURE_CENTER = 0.72 -- the band's middle in the texture, as a fraction of its half-width (GLOW_RING_CENTER)
local LIFT = 0.12 -- studs above the ring mesh's middle, so the glow sits on the ground without flickering
local BRIGHTNESS = 2.5
local WALL_TEXTURE = "rbxassetid://111090819332847" -- glow_wall (decal 103636328548536): opaque foot, clear top
local WALL_HEIGHT = 1.5 -- studs, at most (was 2.2; a little shorter, the user asked 2026-10-08)
local WALL_PER_STUD = 0.08 -- small rings get a lower wall: this much height per stud across (the Ranger's 9-stud ring)
local WALL_SPEED = 0.35 -- how fast the wall's streaks scroll around the ring (Beam.TextureSpeed)
local WALL_FLIP = true -- the beams' width axis points down, which puts the texture's bright edge at the foot
local CURVE = 0.5523 -- Bezier handle length per radius for a quarter circle

-- Builds (or rebuilds) the effect for one ring mesh; returns its GlowRingFx part, a sibling of the mesh.
function GlowRing.build(source: BasePart): Part
	local old = source.Parent and source.Parent:FindFirstChild("GlowRingFx")
	if old then
		old:Destroy()
	end
	source.Transparency = 1 -- the soft ring replaces the hard neon mesh (it still sizes the shop's trigger)
	local across = source.Size.X -- the mesh's outer diameter; the band's middle is just inside it
	local bandRadius = across / 2 * 0.97
	local glowAcross = 2 * bandRadius / TEXTURE_CENTER
	local wallHeight = math.min(WALL_HEIGHT, across * WALL_PER_STUD)

	local glow = Instance.new("Part")
	glow.Name = "GlowRingFx"
	glow.Anchored, glow.CanCollide, glow.CanQuery, glow.CanTouch, glow.CastShadow = true, false, false, false, false
	glow.Transparency = 1
	glow.Size = Vector3.new(glowAcross, 0.05, glowAcross)
	glow.CFrame = CFrame.new(source.Position + Vector3.new(0, LIFT, 0))
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Ground"
	surface.Face = Enum.NormalId.Top
	surface.LightInfluence = 0
	surface.Brightness = BRIGHTNESS
	surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surface.CanvasSize = Vector2.new(512, 512)
	surface.Parent = glow
	local image = Instance.new("ImageLabel")
	image.Name = "Glow"
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = TEXTURE
	image.ImageColor3 = source.Color
	image.Parent = surface

	-- The wall: four quarter-circle Beams around the band, each attachment's X along the ring (the curve's handles)
	-- and Y the ribbon's width, so the ribbon stands upright.
	local corners: { Attachment } = {}
	for i = 0, 3 do
		local a = math.rad(90 * i)
		local corner = Instance.new("Attachment")
		corner.Name = `Wall{i + 1}`
		corner.CFrame = CFrame.fromMatrix(
			Vector3.new(math.cos(a) * bandRadius, wallHeight / 2, math.sin(a) * bandRadius),
			Vector3.new(-math.sin(a), 0, math.cos(a)),
			if WALL_FLIP then -Vector3.yAxis else Vector3.yAxis
		)
		corner.Parent = glow
		corners[i + 1] = corner
	end
	for i = 1, 4 do
		local beam = Instance.new("Beam")
		beam.Name = `Wall{i}`
		beam.Attachment0, beam.Attachment1 = corners[i], corners[i % 4 + 1]
		beam.CurveSize0, beam.CurveSize1 = CURVE * bandRadius, CURVE * bandRadius
		beam.FaceCamera = false
		beam.Width0, beam.Width1 = wallHeight, wallHeight
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
	CollectionService:AddTag(glow, GlowRing.TAG)
	glow.Parent = source.Parent
	return glow
end

return GlowRing
