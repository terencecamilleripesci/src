local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

---- Knit Services
local ProfileService

-- Cooldowns map: stored per player on service.SetComponent
function module:GetCooldowns(player: Player)
	local service = require(script.Parent.Parent)
	if service and service.SetComponent and service.SetComponent._cooldowns then
		return service.SetComponent._cooldowns[player]
	end
	return nil
end

function module.Start() end
function module.Init()
	ProfileService = Knit.GetService("ProfileService")
end

return module
