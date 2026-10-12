-- style_treadmills.luau: the gym treadmills' glowing, per-tier look (2026-10-10, the user's reference pictures). Not
-- shipped. Run it in the Edit datamodel through the Studio connection. Safe to run again.
--
-- Every treadmill (the TreadmillStation zones' models, "Treadmill <N>x") gets wide, soft, glowing chevrons on its belt
-- (tools/make_site_textures.py treadmill_chevron) pointing at the console, tinted its tier's color (the frames and pads
-- are already in it). From 2x up the console takes the tier's color too and the treadmill's neon shell glows faintly,
-- more at each tier. Effects build up with the tier (the user's call: sparkles from 5x only), each in the tier's color:
--   1x, 2x  chevrons only
--   5x      + twinkling sparkles
--   10x     + thin light streaks rising
--   25x     + embers floating up
--   50x     + low flames licking along the belt
--   75x     + taller flames
--   100x    + lightning crackling over the belt
-- Particle counts stay small (a few per second each).
-- Every tier also has the user's speed lines (ReplicatedStorage.Assets.SpeedLines2, 2026-10-11: white and black lines
-- and stars; the first pick, SpeedLinesAnime, was swapped for it) flying back along the belt from the console end,
-- always on, the white lines and stars in the tier's color, thicker on faster tiers.

local CollectionService = game:GetService("CollectionService")

local CHEVRON = "rbxassetid://87800705387711" -- treadmill_chevron.png, pointing at the console (125497508852208 pointed away)
local SPARKLE = "rbxassetid://88252539838654" -- sparkle.png
local STREAK = "rbxassetid://116977228380642" -- streak.png
local LIGHTNING = "rbxassetid://79542222053446" -- tools/make_particle_textures.py lightning
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local EFFECTS = { "Sparkles", "Streaks", "Embers", "Flames", "Lightning" }
local LINES_ASSET = "SpeedLines2"
local LINES_SLOW = 0.3 -- of the asset's speeds (8-160 studs/s; the user: slower, twice)
local LINES_SPAN = 0.4 -- they start over this much of the belt from the console end
local LINES_REACH = 1.1 -- and the fastest one fades by this share of the belt: just past its end (the user)
local LINES_LIFE = NumberRange.new(0.3, 0.6) -- seconds (the asset's 0.07-0.25 was gone too soon: the user)
local LINES_RATE = 0.5 -- of the asset's rate, before the tier's share (the user: fewer lines)
local LINES_HEIGHT = 4.5 -- the lines fill this much above the belt
local LINES_AT_1X = 0.25 -- share of the asset's rate on 1x; 100x gets all of it (by the tier's log)
local LINES_SIZE = 0.5 -- of the asset's sizes (made for a 28 x 18 stud box; a belt is 10 x 5)
-- Its "star" sparkles (5 studs at brightness 15 merged into one white flare): small, and slow twinkles that fade
-- (the user): each lives STAR_LIFE seconds, drifting STAR_SPEED studs/s, growing in, shrinking, flaring once more and
-- fading out, turning slowly; fewer of them (STAR_RATE of the asset's) since they live longer.
local STAR_SIZE, STAR_BRIGHTNESS = 0.9, 6
local STAR_LIFE = NumberRange.new(0.7, 1.1)
local STAR_SPEED = NumberRange.new(1.5, 3)
local STAR_RATE = 0.15

-- How much each tier's neon shell glows (1 = not at all), and from which tier each effect starts.
local SHELL_GLOW = { [1] = 1, [2] = 1, [5] = 0.92, [10] = 0.9, [25] = 0.88, [50] = 0.86, [75] = 0.84, [100] = 0.82 }
local FROM = { Sparkles = 5, Streaks = 10, Embers = 25, Flames = 50, TallFlames = 75, Lightning = 100, SpeedLines = 25 }

local function emitter(belt: BasePart, name: string, props: { [string]: any })
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.LightEmission = 1
	e.LightInfluence = 0
	e.EmissionDirection = Enum.NormalId.Top
	e.Shape = Enum.ParticleEmitterShape.Box
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = belt
	return e
end

local styled = {}
for _, zone in CollectionService:GetTagged("TreadmillStation") do
	local treadmill = zone.Parent
	local belt = treadmill and treadmill:FindFirstChild("Treadmill_Belt")
	local beam = belt and belt:FindFirstChildOfClass("Beam")
	local tier = treadmill and tonumber(string.match(treadmill.Name, "(%d+)x"))
	if not (belt and beam and tier) then
		continue
	end
	local frame = treadmill:FindFirstChild("Treadmill_Frame")
	local color = if frame and tier > 1 then frame.Color else Color3.fromRGB(255, 214, 140)
	local light = color:Lerp(Color3.new(1, 1, 1), 0.35)

	-- The chevrons.
	beam.Texture = CHEVRON
	beam.TextureMode = Enum.TextureMode.Wrap -- TextureLength in studs (Static stretched the chevron into a smear)
	beam.TextureLength = 3.2 -- one chevron every 3.2 studs, about as long as it is wide
	local length = (beam.Attachment0.WorldPosition - beam.Attachment1.WorldPosition).Magnitude
	beam.Segments = math.max(1, math.ceil(length / beam.TextureLength)) -- flat pieces bend the texture; one per chevron
	beam.Width0, beam.Width1 = belt.Size.X * 0.95, belt.Size.X * 0.95
	beam.Color = ColorSequence.new(light)
	beam.LightEmission = 0.8
	beam.LightInfluence = 0
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.15),
		NumberSequenceKeypoint.new(0.85, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	}) -- fading in and out at the belt's two ends

	-- The console in the tier's color, the neon shell glowing faintly.
	local metal = treadmill:FindFirstChild("Treadmill_Metal")
	if metal and metal:IsA("BasePart") then
		metal.Color = if tier > 1 then color:Lerp(Color3.new(0.2, 0.2, 0.22), 0.35) else Color3.fromRGB(165, 170, 176)
	end
	local shell = treadmill:FindFirstChild("Treadmill_Glow")
	if shell and shell:IsA("BasePart") then
		shell.Color = color
		shell.Transparency = SHELL_GLOW[tier] or 1
		shell.CanCollide, shell.CanQuery, shell.CanTouch = false, false, false
		shell.CastShadow = false
	end

	-- The speed lines: a copy of the asset over the front of the belt, its +X (the way its emitters shoot) pointing
	-- to the back, so the lines fly back along the belt from the console end.
	for _, name in { "SpeedLines", "SpeedStars" } do
		local old = treadmill:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local asset = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	asset = asset and asset:FindFirstChild(LINES_ASSET)
	if asset and asset:IsA("BasePart") and tier >= FROM.SpeedLines then -- 25x and up only (the user's call)
		local from, to = beam.Attachment0.WorldPosition, beam.Attachment1.WorldPosition
		local back = (from - to).Unit
		local lines = asset:Clone()
		lines.Name = "SpeedLines"
		lines.Anchored = true
		lines.CanCollide, lines.CanQuery, lines.CanTouch = false, false, false
		lines.Size = Vector3.new(length * LINES_SPAN, LINES_HEIGHT, belt.Size.X * 0.9)
		local middle = to + back * (length * LINES_SPAN / 2) + Vector3.new(0, LINES_HEIGHT / 2 + 0.3, 0)
		lines.CFrame = CFrame.fromMatrix(middle, back, Vector3.yAxis)
		local share = LINES_AT_1X + (1 - LINES_AT_1X) * math.clamp(math.log10(tier) / 2, 0, 1)
		for _, emitter in lines:GetDescendants() do
			if emitter:IsA("ParticleEmitter") then
				emitter.Rate *= share
				if emitter.Name ~= "star" then
					-- Longer lived, fewer, and fading out over the second half of their life (the asset's cut off at full).
					emitter.Lifetime = LINES_LIFE
					emitter.Rate *= LINES_RATE
					emitter.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.12, 0),
						NumberSequenceKeypoint.new(0.45, 0),
						NumberSequenceKeypoint.new(1, 1),
					})
				end
				-- Slower, and only just past the belt: the fastest line, starting at the back of the span, fades in time.
				local room = length * (LINES_REACH - LINES_SPAN)
				local slow = math.min(LINES_SLOW, room / (emitter.Speed.Max * emitter.Lifetime.Max))
				emitter.Speed = NumberRange.new(emitter.Speed.Min * slow, emitter.Speed.Max * slow)
				local points = {}
				for _, point in emitter.Size.Keypoints do
					table.insert(points, NumberSequenceKeypoint.new(point.Time, point.Value * LINES_SIZE, point.Envelope * LINES_SIZE))
				end
				emitter.Size = NumberSequence.new(points)
				if emitter.Name == "star" then
					emitter.Size = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(0.25, STAR_SIZE),
						NumberSequenceKeypoint.new(0.5, STAR_SIZE * 0.45),
						NumberSequenceKeypoint.new(0.7, STAR_SIZE * 0.8),
						NumberSequenceKeypoint.new(1, 0),
					})
					emitter.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.3),
						NumberSequenceKeypoint.new(0.25, 0),
						NumberSequenceKeypoint.new(0.7, 0.1),
						NumberSequenceKeypoint.new(1, 1),
					})
					emitter.Brightness = STAR_BRIGHTNESS
					emitter.Lifetime = STAR_LIFE
					emitter.Speed = STAR_SPEED
					emitter.Rate *= STAR_RATE
					emitter.Rotation = NumberRange.new(0, 360)
					emitter.RotSpeed = NumberRange.new(-45, 45)
				end
				-- The white lines and stars take the tier's color; the black lines stay black.
				local first = emitter.Color.Keypoints[1].Value
				if first.R + first.G + first.B > 0.3 then
					emitter.Color = ColorSequence.new(light)
				end
			end
		end
		lines.Parent = treadmill
		-- The stars get their own box over the whole belt, so they twinkle all along it (the user: more evenly spread).
		local star = lines:FindFirstChild("star")
		if star then
			local stars = Instance.new("Part")
			stars.Name = "SpeedStars"
			stars.Transparency = 1
			stars.Anchored = true
			stars.CanCollide, stars.CanQuery, stars.CanTouch = false, false, false
			stars.CastShadow = false
			stars.Size = Vector3.new(length * 0.95, LINES_HEIGHT, belt.Size.X * 0.9)
			stars.CFrame = CFrame.fromMatrix((from + to) / 2 + Vector3.new(0, LINES_HEIGHT / 2 + 0.3, 0), back, Vector3.yAxis)
			star.Parent = stars
			stars.Parent = treadmill
		end
	end

	-- The effects for this tier.
	for _, name in EFFECTS do
		local old = belt:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	if tier >= FROM.Sparkles then
		emitter(belt, "Sparkles", {
			Texture = SPARKLE,
			Color = ColorSequence.new(light),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.3, 0.9),
				NumberSequenceKeypoint.new(0.6, 0.35),
				NumberSequenceKeypoint.new(1, 0),
			}), -- a twinkle: pops up, shrinks, a little flare, gone
			Transparency = NumberSequence.new(0.05),
			Lifetime = NumberRange.new(0.9, 1.5),
			Rate = if tier >= 50 then 8 else 5,
			Speed = NumberRange.new(0.6, 1.6),
			SpreadAngle = Vector2.new(25, 25),
			Rotation = NumberRange.new(0, 45),
		})
	end
	if tier >= FROM.Streaks then
		emitter(belt, "Streaks", {
			Texture = STREAK,
			Color = ColorSequence.new(light),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Size = NumberSequence.new(1.4),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.3), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.7, 1.1),
			Rate = 2,
			Speed = NumberRange.new(2.5, 4),
			SpreadAngle = Vector2.new(6, 6),
		})
	end
	if tier >= FROM.Embers then
		emitter(belt, "Embers", {
			Texture = SPARKLE,
			Color = ColorSequence.new(color, Color3.fromRGB(255, 120, 40)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new(0),
			Lifetime = NumberRange.new(1.4, 2.4),
			Rate = 6,
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(30, 30),
			Acceleration = Vector3.new(0, 1, 0),
			RotSpeed = NumberRange.new(-90, 90),
		})
	end
	if tier >= FROM.Flames then
		local tall = tier >= FROM.TallFlames
		emitter(belt, "Flames", {
			Texture = FIRE,
			Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.15), color),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, if tall then 1.6 else 1.1),
				NumberSequenceKeypoint.new(1, 0.2),
			}),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.5, if tall then 1.1 else 0.8),
			Rate = if tall then 14 else 10,
			Speed = NumberRange.new(if tall then 3.5 else 2, if tall then 5.5 else 3.5),
			SpreadAngle = Vector2.new(10, 10),
			RotSpeed = NumberRange.new(-60, 60),
			Rotation = NumberRange.new(0, 360),
		})
	end
	if tier >= FROM.Lightning then
		emitter(belt, "Lightning", {
			Texture = LIGHTNING,
			Color = ColorSequence.new(light),
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			Size = NumberSequence.new(2.4),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.1), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.12, 0.22), -- a flicker
			Rate = 4,
			Speed = NumberRange.new(0.1, 0.1),
			Rotation = NumberRange.new(0, 360),
			Squash = NumberSequence.new(-0.6),
		})
	end
	table.insert(styled, tier)
end
table.sort(styled)
return `treadmills styled: {table.concat(styled, "x, ")}x`
