local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gating = {}

function Gating.Check(playerData, masteryService, slotKey: string, skillDef)
	-- Check mastery unlock
	local cfg = require(ReplicatedStorage.Configs.ConfigPack)
	local need = cfg and cfg.Mastery and cfg.Mastery.Unlocks and cfg.Mastery.Unlocks[slotKey]
	local have = playerData.Mastery and playerData.Mastery[slotKey] or 0
	if need and have < need then
		return false, "locked"
	end
	-- TODO: cooldowns, resource costs validated by caller
	return true
end

return Gating
