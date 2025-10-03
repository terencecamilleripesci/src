local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

---- Knit Services
local ProfileService

function module:GetSnapshot(player: Player)
	local _, data = ProfileService:GetProfile(player)
	if not data then return nil end
	return {
		Level = data.Level,
		XP = data.XP,
		UnspentPoints = data.UnspentPoints,
		Stats = {
			Health = data.Stats.Health,
			Mana = data.Stats.Mana,
			Stamina = data.Stats.Stamina,
			Strength = data.Stats.Strength,
			Defense = data.Stats.Defense,
		},
	}
end

function module.Start()
	-- nothing for now
end

function module.Init()
	ProfileService = Knit.GetService("ProfileService")
end

return module
