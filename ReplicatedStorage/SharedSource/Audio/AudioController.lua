local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Audio = {}

local Config = require(ReplicatedStorage.Configs.ConfigPack)
local DEFAULT_VOL = (Config.Audio and Config.Audio.DefaultSFXVolume) or 0.7

local function setProps(sound)
	sound.Volume = DEFAULT_VOL
	if Config.Audio and Config.Audio.UseSoundGroups then
		local group = SoundService:FindFirstChild("SFX")
		if not group then
			group = Instance.new("SoundGroup")
			group.Name = "SFX"
			group.Parent = SoundService
		end
		sound.SoundGroup = group
	end
end

function Audio.SetVolume(v)
	DEFAULT_VOL = math.clamp(tonumber(v) or DEFAULT_VOL, 0, 1)
end

function Audio.PlayAtCharacter(player: Player, soundId: string)
	if not player or type(soundId) ~= "string" then return end
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local s = Instance.new("Sound")
	s.Name = "OneShot"
	s.SoundId = soundId
	setProps(s)
	s.Parent = hrp
	s:Play()
	game:GetService("Debris"):AddItem(s, 5)
end

function Audio.PlayAtWorld(position: Vector3, soundId: string)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.CFrame = CFrame.new(position)
	part.Parent = workspace
	local s = Instance.new("Sound")
	s.Name = "OneShot"
	s.SoundId = soundId
	setProps(s)
	s.Parent = part
	s:Play()
	game:GetService("Debris"):AddItem(part, 5)
end

function Audio.PlayUI(soundId: string)
	local s = Instance.new("Sound")
	s.Name = "UI"
	s.SoundId = soundId
	setProps(s)
	s.Parent = SoundService
	s:Play()
	game:GetService("Debris"):AddItem(s, 5)
end

return Audio
