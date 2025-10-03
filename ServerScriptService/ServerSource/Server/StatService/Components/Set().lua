local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

---- Knit Services (resolved during .Init())
local ProfileService

---- Datas / Config
local ConfigsFolder = ReplicatedStorage:WaitForChild("Configs", 10)
local ConfigPack = ConfigsFolder and require(ConfigsFolder:WaitForChild("ConfigPack", 10))

---- Others
local Allocator -- defer require to .Start()

-- Server-authoritative allocation
-- Returns table: { ok:boolean, reason?:string, snapshot?:table }
function module:AllocatePoints(player: Player, statName: string, count: number)
	if typeof(player) ~= "Instance" then
		return { ok = false, reason = "bad-player" }
	end
	if type(statName) ~= "string" then
		return { ok = false, reason = "bad-stat" }
	end
	if type(count) ~= "number" then
		return { ok = false, reason = "bad-count" }
	end

	-- Pull profile
	local profile, data = ProfileService:GetProfile(player)
	if not data then
		return { ok = false, reason = "no-profile" }
	end

	-- Compute allocation using pure helper
	local result = Allocator.ComputeAllocation(data, ConfigPack, statName, count)
	if not result.ok then
		return result
	end

	-- Apply mutation: spend points and set stat
	local used = result.usedPoints or 0
	local newValue = result.newValue
	local stats = data.Stats
	local unspent = tonumber(data.UnspentPoints) or 0
	if used <= 0 or used > unspent then
		return { ok = false, reason = "insufficient" }
	end

	-- Update underlying profile data
	stats[statName] = newValue
	data.UnspentPoints = unspent - used

	-- Fire profile update signals via ProfileService.ChangeData for both fields
	ProfileService:ChangeData(player, {"Stats", statName}, newValue)
	ProfileService:ChangeData(player, {"UnspentPoints"}, data.UnspentPoints)

	-- Minimal snapshot to return to caller
	local snapshot = {
		UnspentPoints = data.UnspentPoints,
		Stats = {
			Health = stats.Health,
			Mana = stats.Mana,
			Stamina = stats.Stamina,
			Strength = stats.Strength,
			Defense = stats.Defense,
		},
	}
	return { ok = true, snapshot = snapshot }
end

function module.Start()
	Allocator = require(script.Parent.Others.Allocator)
end

function module.Init()
	-- Resolve Knit services only here
	ProfileService = Knit.GetService("ProfileService")
end

return module
