local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

---- Knit Services
local ProfileService

function module:Get(player: Player)
	local _, data = ProfileService:GetProfile(player)
	return data -- may be nil until profile loads
end

function module.Start()
	-- nothing
end

function module.Init()
	ProfileService = Knit.GetService("ProfileService")
end

return module
