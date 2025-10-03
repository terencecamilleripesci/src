local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tracker = {}

-- Adds mastery exp on kill based on kind (Normal/Strong/Boss). Returns new value and whether it crossed unlock
function Tracker.AddKillCredit(data, slotKey: string, kind: string?, ConfigPack)
	local expMap = (ConfigPack and ConfigPack.Mastery and ConfigPack.Mastery.ExpPerKill) or { Normal = 15, Strong = 25, Boss = 150 }
	local add = expMap[(kind or "Normal")] or expMap.Normal

	data.Mastery = data.Mastery or {}
	local before = tonumber(data.Mastery[slotKey]) or 0
	local after = before + add
	data.Mastery[slotKey] = after

	local thresholds = (ConfigPack and ConfigPack.Mastery and ConfigPack.Mastery.Unlocks) or {}
	local need = thresholds[slotKey]
	local unlocked = (need and before < need and after >= need) or false
	return after, unlocked
end

return Tracker
