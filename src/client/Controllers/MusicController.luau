--!strict
-- MusicController: quiet background music (polish pass, 2026-10-07). Plays PLAYLIST in order and loops it,
-- through the Music SoundGroup (Settings: Music on/off). Fades down during the forest complete cutscene so
-- its fanfare stands out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Sounds = require(script.Parent.Parent.Sounds)

local VOLUME = 0.25
-- Free Creator Store music (DistrokidOfficial), checked to load in Studio.
local PLAYLIST = {
	"rbxassetid://98002463968288", -- "Forest Calm Ambient", 3:23
	"rbxassetid://125021936389109", -- "Flowery Gardens", 3:19
}
local FADE = TweenInfo.new(1.5)
local DUCKED = 0.06 -- the volume while the cutscene plays

local MusicController = {}

function MusicController.start()
	local sound = Instance.new("Sound")
	sound.Name = "Music"
	sound.Volume = VOLUME
	sound.SoundGroup = Sounds.music()
	sound.Parent = SoundService
	-- Duck under the forest complete fanfare: AwakeningEndsAt is set when the cutscene starts.
	local forestState = ReplicatedStorage:WaitForChild("ForestState")
	local running = false
	forestState:GetAttributeChangedSignal("AwakeningEndsAt"):Connect(function()
		local endsAt = forestState:GetAttribute("AwakeningEndsAt")
		local wasRunning = running
		running = typeof(endsAt) == "number" and endsAt > 0
		if running and not wasRunning then -- the start, not an extension
			TweenService:Create(sound, FADE, { Volume = DUCKED }):Play()
			task.delay(GameConfig.Awakening.CutsceneSeconds, function()
				TweenService:Create(sound, FADE, { Volume = VOLUME }):Play()
			end)
		end
	end)
	local index = 1
	while true do
		sound.SoundId = PLAYLIST[index]
		sound:Play()
		sound.Ended:Wait()
		index = index % #PLAYLIST + 1
	end
end

return MusicController
