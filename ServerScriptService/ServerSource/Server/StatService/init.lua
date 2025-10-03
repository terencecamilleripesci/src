-- ServerScriptService/ServerSource/Server/StatsService/init.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local StatsService = Knit.CreateService({
	Name = "StatsService",
	Client = {
		StatsChanged = Knit.CreateSignal(), -- snapshot to that player
		LevelChanged = Knit.CreateSignal(), -- level/xp to that player
	},
	_allocCooldown = {}, -- [player] = lastTime
})

-- ──────────────────────────────────────────────────────────────────────────────
-- Components / Config
local componentsInitializer = require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
local componentsFolder = script:WaitForChild("Components", 5)

StatsService.Components = {}
for _,v in ipairs(componentsFolder:WaitForChild("Others", 10):GetChildren()) do
	StatsService.Components[v.Name] = require(v)
end

local GetComponent = require(componentsFolder["Get()"])
StatsService.GetComponent = GetComponent
StatsService.SetComponent = require(componentsFolder["Set()"])

local ConfigsFolder = ReplicatedStorage:WaitForChild("Configs", 10)
local ConfigPack = require(ConfigsFolder:WaitForChild("ConfigPack", 10))

-- Deferred requires (loaded in KnitStart)
local StatCalculator
local XPLevel

-- Knit services
local ProfileService -- set in KnitInit()

-- ──────────────────────────────────────────────────────────────────────────────
-- Utilities

local function num(v, default)
	return (type(v) == "number") and v or default
end

local function sanitizeProfile(player)
	-- Ensure the profile has safe numbers so we never compare number < nil
	local _, data = ProfileService:GetProfile(player)
	if not data then return false end

	local changed = false

	-- Level / XP defaults
	if type(data.Level) ~= "number" then data.Level = 1; ProfileService:ChangeData(player, {"Level"}, 1); changed = true end
	if type(data.XP)    ~= "number" then data.XP    = 0; ProfileService:ChangeData(player, {"XP"},    0); changed = true end
	if type(data.UnspentPoints) ~= "number" then
		data.UnspentPoints = 0; ProfileService:ChangeData(player, {"UnspentPoints"}, 0); changed = true
	end

	-- Stats table + base keys
	data.Stats = data.Stats or {}
	for k,base in pairs(ConfigPack.Stats.Base) do
		if type(data.Stats[k]) ~= "number" then
			data.Stats[k] = base
			ProfileService:ChangeData(player, {"Stats", k}, base)
			changed = true
		end
	end

	return changed
end

local function safeLevelXP(player)
	local _, data = ProfileService:GetProfile(player)
	if not data then return 1, 0 end
	return num(data.Level, 1), num(data.XP, 0)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Public helpers

function StatsService:GetSnapshot(player)
	return GetComponent:GetSnapshot(player)
end

function StatsService:GetDerived(player)
	local _, data = ProfileService:GetProfile(player)
	if not data then return nil end
	StatCalculator = StatCalculator or require(componentsFolder.Others.StatCalculator)
	return StatCalculator.BuildDerived(data.Stats or {}, ConfigPack)
end

function StatsService:AddXP(player: Player, amount: number)
	if type(amount) ~= "number" or amount <= 0 then
		return { ok=false, reason="bad-amount" }
	end

	-- ALWAYS sanitize before math
	sanitizeProfile(player)

	local level, xp = safeLevelXP(player)

	XPLevel = XPLevel or require(componentsFolder.Others.XPLevel)
	local newLevel, newXP, points = XPLevel.Compute(level, xp, amount, ConfigPack)

	if newLevel ~= level then
		ProfileService:ChangeData(player, {"Level"}, newLevel)
		ProfileService:ChangeData(player, {"UnspentPoints"}, (ProfileService:GetProfile(player)).Data.UnspentPoints + (points or 0))
	else
		ProfileService:ChangeData(player, {"XP"}, newXP)
	end

	self.Client.LevelChanged:Fire(player, newLevel, newXP)
	return { ok=true, level=newLevel, xp=newXP, pointsAwarded=points or 0 }
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Client API

function StatsService.Client:AllocatePoints(player: Player, statName: string, count: number)
	local now = os.clock()
	local last = self.Server._allocCooldown[player]
	if last and (now - last) < 0.2 then
		return { ok=false, reason="throttled" }
	end
	self.Server._allocCooldown[player] = now

	-- sanitize before doing any math
	sanitizeProfile(player)

	local result = self.Server.SetComponent:AllocatePoints(player, statName, count)
	if result and result.ok then
		self.Server.Client.StatsChanged:Fire(player, result.snapshot)
	end
	return result
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Knit lifecycle

function StatsService:KnitStart()
	-- Lazy requires
	StatCalculator = require(componentsFolder.Others.StatCalculator)
	XPLevel = require(componentsFolder.Others.XPLevel)

	-- Make sure every current player is sanitized (Studio re-run safety)
	for _,p in ipairs(Players:GetPlayers()) do
		task.defer(function()
			-- try a few times until profile exists
			for _=1,50 do
				if sanitizeProfile(p) ~= nil then break end
				task.wait(0.1)
			end
			local L, X = safeLevelXP(p)
			self.Client.LevelChanged:Fire(p, L, X)
		end)
	end

	-- New players
	Players.PlayerAdded:Connect(function(p)
		task.defer(function()
			for _=1,50 do
				if sanitizeProfile(p) ~= nil then break end
				task.wait(0.1)
			end
			local L, X = safeLevelXP(p)
			self.Client.LevelChanged:Fire(p, L, X)
		end)
	end)

	-- Clean cooldowns
	Players.PlayerRemoving:Connect(function(p)
		self._allocCooldown[p] = nil
	end)

	-- If your ProfileService broadcasts changes, mirror level/xp to client
	if ProfileService and ProfileService.UpdateSpecificData then
		ProfileService.UpdateSpecificData:Connect(function(player, path, _)
			if not player or not path or #path == 0 then return end
			if path[1] == "Level" or path[1] == "XP" then
				local L, X = safeLevelXP(player)
				self.Client.LevelChanged:Fire(player, L, X)
			end
		end)
	end

	componentsInitializer(script) -- keep your component system warm
end

function StatsService:KnitInit()
	ProfileService = Knit.GetService("ProfileService")
end

return StatsService
