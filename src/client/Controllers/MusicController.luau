--!strict
-- MusicController: quiet background music (polish pass, 2026-10-07), through the Music SoundGroup (Settings: Music
-- on/off). While a forest grows it plays PLAYLIST in order from a random track and loops it. When the forest is
-- complete (ForestState AwakeningEndsAt goes above 0) the playlist pauses and BREAK_TRACK loops until the break ends,
-- then the playlist resumes where it was (2026-10-08, the user's call). The break music starts quiet under the
-- forest complete clip, then comes up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Sounds = require(script.Parent.Parent.Sounds)

-- Every track plays equally quietly: volume = LEVEL / its loudness (the average PlaybackLoudness measured in a
-- playtest at volume 0.1 over five spots in the song). The user's picks (2026-10-08), free Creator Store music.
-- 30% of the first level (29.6, an average track at volume 0.2) since 2026-10-08, the user's call: now an average track
-- (loudness 148) plays at volume 0.06. Raise or lower to change them all.
local LEVEL = 8.9
type Track = { id: string, loudness: number }
local PLAYLIST: { Track } = {
	{ id = "rbxassetid://138788292783547", loudness = 153.6 }, -- "Ethereal Forest, Pt. 3" (DistrokidOfficial), 6:56
	{ id = "rbxassetid://135055193420375", loudness = 178.9 }, -- "Morning Forest Birds" (DistrokidOfficial), 3:42
	{ id = "rbxassetid://103529274376153", loudness = 184.0 }, -- "Forest Explorer's Journey" (DistrokidOfficial), 2:41
	{ id = "rbxassetid://139140953638078", loudness = 76.4 }, -- "River Forest Flute" (DistrokidOfficial), 3:32
	{ id = "rbxassetid://90928113744956", loudness = 198.5 }, -- "Bright Forest" (DistrokidOfficial), 4:20
}
local BREAK_TRACK: Track = { id = "rbxassetid://9047876673", loudness = 213.9 } -- "Happy Adventure" (APM), 1:11, looped
local FADE = TweenInfo.new(1.5)
local DUCKED = 0.02 -- the break music's volume under the forest complete clip (Sounds ForestComplete)
local CLIP_SECONDS = 12.4 -- that clip's length: the break music comes up once it (and the cutscene) are over

local MusicController = {}

local function newSound(name: string): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundGroup = Sounds.music()
	sound.Parent = SoundService
	return sound
end

local function volumeOf(track: Track): number
	return LEVEL / track.loudness
end

function MusicController.start()
	local music = newSound("ForestMusic")
	local breakMusic = newSound("BreakMusic")
	breakMusic.SoundId = BREAK_TRACK.id
	breakMusic.Looped = true
	local inBreak = false
	local trackVolume = 0 -- the playing playlist track's

	-- The break: the playlist fades out and pauses; the break music loops (quiet at first if the cutscene plays).
	local forestState = ReplicatedStorage:WaitForChild("ForestState")
	local function onBreak(withCutscene: boolean)
		local endsAt = forestState:GetAttribute("AwakeningEndsAt")
		local now = typeof(endsAt) == "number" and endsAt > 0
		if now == inBreak then
			return -- an extension, not a start or end
		end
		inBreak = now
		if now then
			local fadeOut = TweenService:Create(music, FADE, { Volume = 0 })
			fadeOut.Completed:Connect(function()
				if inBreak then
					music:Pause()
				end
			end)
			fadeOut:Play()
			breakMusic.TimePosition = 0
			breakMusic.Volume = if withCutscene then DUCKED else volumeOf(BREAK_TRACK)
			breakMusic:Play()
			if withCutscene then
				task.delay(math.max(GameConfig.Awakening.CutsceneSeconds, CLIP_SECONDS), function()
					if inBreak then
						TweenService:Create(breakMusic, FADE, { Volume = volumeOf(BREAK_TRACK) }):Play()
					end
				end)
			end
		else
			local fadeOut = TweenService:Create(breakMusic, FADE, { Volume = 0 })
			fadeOut.Completed:Connect(function()
				if not inBreak then
					breakMusic:Stop()
				end
			end)
			fadeOut:Play()
			music:Resume()
			TweenService:Create(music, FADE, { Volume = trackVolume }):Play()
		end
	end
	forestState:GetAttributeChangedSignal("AwakeningEndsAt"):Connect(function()
		onBreak(true)
	end)
	onBreak(false) -- joined during a break: straight to the break music

	local index = math.random(#PLAYLIST)
	while true do
		local track = PLAYLIST[index]
		trackVolume = volumeOf(track)
		music.SoundId = track.id
		music.Volume = if inBreak then 0 else trackVolume
		music:Play()
		if inBreak then
			music:Pause() -- resumed when the break ends
		end
		music.Ended:Wait()
		index = index % #PLAYLIST + 1
	end
end

return MusicController
