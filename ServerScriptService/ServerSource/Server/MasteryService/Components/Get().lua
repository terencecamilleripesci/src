local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

---- Knit Services
local ProfileService

function module:GetSnapshot(player: Player)
	local _, data = ProfileService:GetProfile(player)
	if not data then return nil end
	return { Mastery = data.Mastery }
end

-- Check unlock status by comparing mastery value vs thresholds in config
function module:IsUnlocked(player: Player, slotKey: string)
	local _, data = ProfileService:GetProfile(player)
	if not data then return false end
	local cfg = require(ReplicatedStorage.Configs.ConfigPack)
	local thresholds = cfg and cfg.Mastery and cfg.Mastery.Unlocks or {}
	local need = thresholds[slotKey]
	if not need then return false end
	return (data.Mastery and (data.Mastery[slotKey] or 0) >= need) or false
end

function module.Start() end
function module.Init()
	ProfileService = Knit.GetService("ProfileService")
end

return module
