local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local StatsService = Knit.CreateService({
	Name = "StatsService",
	Client = {
		StatsChanged = Knit.CreateSignal(),
		LevelChanged = Knit.CreateSignal(),
	},
	_allocCooldown = {},
})

local componentsInitializer = require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
local componentsFolder = script:WaitForChild("Components", 5)

StatsService.Components = {}
for _, v in pairs(componentsFolder:WaitForChild("Others", 10):GetChildren()) do
	StatsService.Components[v.Name] = require(v)
end

local self_GetComponent = require(componentsFolder["Get()"])
StatsService.GetComponent = self_GetComponent
StatsService.SetComponent = require(componentsFolder["Set()"])

local StatCalculator
local XPLevel
local ProfileService

local ConfigsFolder = ReplicatedStorage:WaitForChild("Configs", 10)
local ConfigPack = ConfigsFolder and require(ConfigsFolder:WaitForChild("ConfigPack", 10))

function StatsService:GetSnapshot(player: Player)
	return self_GetComponent:GetSnapshot(player)
end

function StatsService:GetDerived(player: Player)
	local _, data = ProfileService:GetProfile(player)
	if not data then return nil end
	StatCalculator = StatCalculator or require(componentsFolder.Others.StatCalculator)
	return StatCalculator.BuildDerived(data.Stats or {}, ConfigPack)
end

function StatsService:AddXP(player: Player, amount: number)
	if type(amount) ~= "number" or amount <= 0 then
		return { ok = false, reason = "bad-amount" }
	end

	local _, data = ProfileService:GetProfile(player)
	if not data then
		return { ok = false, reason = "no-profile" }
	end

	data.Level = tonumber(data.Level) or 1
	data.XP    = tonumber(data.XP) or 0

	XPLevel = XPLevel or require(componentsFolder.Others.XPLevel)
	local newLevel, newXP, points = XPLevel.Compute(data.Level, data.XP, amount, ConfigPack)

	if newLevel ~= data.Level then
		ProfileService:ChangeData(player, {"Level"}, newLevel)
		ProfileService:ChangeData(player, {"UnspentPoints"}, (tonumber(data.UnspentPoints) or 0) + (points or 0))
	else
		ProfileService:ChangeData(player, {"XP"}, newXP or data.XP)
	end

	return { ok = true, level = newLevel, xp = newXP, pointsAwarded = points }
end

function StatsService.Client:AllocatePoints(player: Player, statName: string, count: number)
	local now = os.clock()
	local last = self.Server._allocCooldown[player]
	if last and (now - last) < 0.2 then
		return { ok = false, reason = "throttled" }
	end
	self.Server._allocCooldown[player] = now

	local result = self.Server.SetComponent:AllocatePoints(player, statName, count)
	if result and result.ok then
		self.Server.Client.StatsChanged:Fire(player, result.snapshot)
	end
	return result
end

function StatsService:_broadcastLevelChanged(player: Player)
	local _, data = ProfileService:GetProfile(player)
	if not data then return end
	self.Client.LevelChanged:Fire(player, tonumber(data.Level) or 1, tonumber(data.XP) or 0)
end

function StatsService:KnitInit()
	ProfileService = Knit.GetService("ProfileService")
	componentsInitializer(script)
end

function StatsService:KnitStart()
	StatCalculator = require(componentsFolder.Others.StatCalculator)
	XPLevel        = require(componentsFolder.Others.XPLevel)

	ProfileService.UpdateSpecificData:Connect(function(player, path)
		if not player or not path or #path == 0 then return end
		if path[1] == "Level" or path[1] == "XP" then
			self:_broadcastLevelChanged(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._allocCooldown[player] = nil
	end)
end

return StatsService
