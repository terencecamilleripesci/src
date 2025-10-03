local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LMBApi = {}

local Config = require(ReplicatedStorage.Configs.ConfigPack)

-- Entry for LMB press from client input controller (server-authoritative)
function LMBApi.Process(player: Player)
	local combo = require(script.Parent.BasicCombo)
	local stepResult = combo.OnLMB(player)
	if not (stepResult and stepResult.ok) then return stepResult end
	local step = stepResult.step
	-- Return instruction for client: play step.AnimId + step.SoundId, then server will resolve hit after Windup
	return { ok = true, step = step }
end

return LMBApi
