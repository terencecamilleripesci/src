local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

---- Knit Services
local ProfileService

function module:GetSnapshot(player: Player)
	local _, data = ProfileService:GetProfile(player)
	if not data then return nil end
	return { Hotbar = data.Hotbar }
end

function module.Start()
end

function module.Init()
	ProfileService = Knit.GetService("ProfileService")
end

return module
