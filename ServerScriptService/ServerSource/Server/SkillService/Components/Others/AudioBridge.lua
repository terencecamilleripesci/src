local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioBridge = {}

function AudioBridge.PlayPlayerSFX(player: Player, soundId: string)
	local Knit = require(ReplicatedStorage.Packages.Knit)
	local controller = require(ReplicatedStorage.SharedSource.Audio.AudioController)
	-- NOTE: In a Knit service, do not require controllers; instead, we will trigger clients via signals.
	-- This bridge exists only as a placeholder if needed by client controllers. Server should not play sounds.
end

return AudioBridge
