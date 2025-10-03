local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Thresholds = {}

function Thresholds.Get(slotKey: string)
	local cfg = require(ReplicatedStorage.Configs.ConfigPack)
	local t = cfg and cfg.Mastery and cfg.Mastery.Unlocks or {}
	return t[slotKey]
end

return Thresholds
