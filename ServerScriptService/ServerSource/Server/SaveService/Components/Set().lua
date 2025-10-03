local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

---- Knit Services
local ProfileService

---- Others (defer require in Start)
local Adapter

-- Update the player's data via mutator function (server-only)
function module:Update(player: Player, mutator: (any) -> ())
	local profile, data = ProfileService:GetProfile(player)
	if not data then return false end
	Adapter.ApplyMutator(data, mutator)
	return true
end

-- Change a specific nested path and notify clients via ProfileService.ChangeData
function module:Change(player: Player, path: {any}, newValue: any)
	if type(path) ~= "table" or #path == 0 then return false end
	ProfileService:ChangeData(player, path, newValue)
	return true
end

function module.Start()
	Adapter = require(script.Parent.Others.Adapter)
end

function module.Init()
	ProfileService = Knit.GetService("ProfileService")
end

return module
