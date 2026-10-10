--!strict
-- Sounds: the game's one-shot sound effects and the two volume groups (polish pass, 2026-10-07).
-- play(name) plays one of IDS at full volume (not in a part). Everything goes through the Effects or Music
-- SoundGroup, so the Settings toggles can mute a whole group. All picks are free Creator Store audio,
-- checked to load in Studio; swap an id here to change a sound everywhere.

local SoundService = game:GetService("SoundService")

local Sounds = {}

-- name = { id, volume, pitch? } (pitch: playback speed, 1 = as recorded; lower is deeper)
Sounds.IDS = {
	Click = { "rbxassetid://15675059323", 0.5 }, -- "Roblox_UI_Bright_Click" (Roblox)
	Hover = { "rbxassetid://119354387183704", 0.25 }, -- the user's pick 2026-10-08 (was 139800881181209, "ui-simple-button-hover")
	Purchase = { "rbxassetid://10066947742", 0.6 }, -- "RBLX UI Purchase (SFX)" (Roblox)
	Error = { "rbxassetid://87519554692663", 0.5 }, -- "ui-simple-negative-error" (AmbientSorcery)
	LevelUp = { "rbxassetid://112485797063762", 0.5 }, -- "UI - Level Up" (SodaBreadle)
	Notify = { "rbxassetid://104000340117740", 0.5 }, -- "Notification Chime" (Flare Studio)
	Fanfare = { "rbxassetid://136993031050456", 0.5 }, -- "SuccessSfx" (proxyprevails, 1.1 s): the tutorial is complete; the user's pick 2026-10-08 (was 9047103106)
	-- The forest is complete: "Where Dreams Come True (B)" (APM Music), 12.4 s; the user's pick 2026-10-08 (was Fanfare).
	ForestComplete = { "rbxassetid://1840544226", 0.35 }, -- 0.35 (was 0.5; 30% down, the user 2026-10-08)
	StatUp = { "rbxassetid://112485797063762", 0.5 }, -- capacity or walk speed leveled up (HUD); the user's pick 2026-10-08 (was 76834925120308)
	Plant = { "rbxassetid://110522236020035", 0.5 }, -- "footstep grass 3" (Robloxmastermanyay): your own seed going into the ground (CarryController); the user's pick 2026-10-08
	Gain = { "rbxassetid://121434237134952", 0.28, 1 }, -- volume 0.28 (was 0.35; 20% down, the user 2026-10-08); pitch 1 measured to match the clip (average 727 vs 722 Hz, ~40 ms long); -- "bubble-pop-06" (artem1323323): the training pop, with each "+N" popup (HUD). Picked 2026-10-07 to match Build the Pyramid's (a ~40 ms pop sliding up from ~530 to ~1,060 Hz; this one slides 600 -> 900). Was 10066931761. Close alternatives: 109359226723492, 86707910685850.
} :: { [string]: { any } }

local function group(name: string, volume: number): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local made = Instance.new("SoundGroup")
	made.Name = name
	made.Volume = volume
	made.Parent = SoundService
	return made
end

-- The volume groups: Effects for every sound effect, Music for the background music.
function Sounds.effects(): SoundGroup
	return group("Effects", 1)
end

function Sounds.music(): SoundGroup
	return group("Music", 1)
end

local last: { [string]: number } = {}
local MIN_GAP = 0.05 -- the same sound twice within this is played once

-- Plays a sound from IDS. pitch: playback speed (1 = as recorded).
function Sounds.play(name: string, pitch: number?)
	local entry = Sounds.IDS[name]
	if not entry then
		return
	end
	local now = os.clock()
	if now - (last[name] or -1) < MIN_GAP then
		return
	end
	last[name] = now
	local sound = Instance.new("Sound")
	sound.SoundId = entry[1]
	sound.Volume = entry[2]
	sound.PlaybackSpeed = pitch or entry[3] or 1
	sound.SoundGroup = Sounds.effects()
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
end

-- Plays any sound id once through the Effects group (for sounds that live in their own controller).
function Sounds.playId(id: string, volume: number, pitch: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch or 1
	sound.SoundGroup = Sounds.effects()
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
end

return Sounds
