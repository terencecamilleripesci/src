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

-- Components bootstrap (unchanged from your structure)
local componentsInitializer = require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
local componentsFolder = script:WaitForChild("Components", 5)
StatsService.Components = {}
for _, v in pairs(componentsFolder:WaitForChild("Others", 10):GetChildren()) do
	StatsService.Components[v.Name] = require(v)
end
local self_GetComponent = require(componentsFolder["Get()"])
StatsService.GetComponent = self_GetComponent
StatsService.SetComponent = require(componentsFolder["Set()"])

-- Knit services / configs / helpers
local ProfileService
local ConfigPack = require(ReplicatedStorage:WaitForChild("Configs", 10):WaitForChild("ConfigPack", 10))
local StatCalculator
local XPLevel

-- ---------- defaults & guards ----------
local function num(v, d) return (type(v) == "number") and v or d end

function StatsService:_ensureDefaults(player)
	local _, data = ProfileService:GetProfile(player)
	if not data then return end

	-- Top-level
	data.Level = num(data.Level, 1)
	data.XP = num(data.XP, 0)
	data.UnspentPoints = num(data.UnspentPoints, 0)

	-- Stats table
	data.Stats = data.Stats or {}
	for k, base in pairs(ConfigPack.Stats.Base or {}) do
		data.Stats[k] = num(data.Stats[k], base)
	end
end

local function safeCompute(level, xp, add, cfg)
	level = num(level, 1)
	xp    = num(xp, 0)
	add   = num(add, 0)

	local req = 0
	if cfg and cfg.XP and typeof(cfg.XP.ExpFormula) == "function" then
		req = num(cfg.XP.ExpFormula(level), 100)
	else
		req = 100
	end

	xp = xp + add
	local pointsAwarded = 0

	-- Level up while you have enough XP (always compare numbers)
	while xp >= req do
		xp -= req
		level += 1
		pointsAwarded += num(cfg.Stats and cfg.Stats.STAT_POINTS_PER_LEVEL, 2)
		req = num(cfg.XP.ExpFormula(level), 100)
	end

	return level, xp, pointsAwarded
end

-- ---------- public helpers ----------
function StatsService:GetSnapshot(player)
	return self_GetComponent:GetSnapshot(player)
end

function StatsService:GetDerived(player)
	self:_ensureDefaults(player)
	local _, data = ProfileService:GetProfile(player)
	if not data then return nil end
	StatCalculator = StatCalculator or require(componentsFolder.Others.StatCalculator)
	return StatCalculator.BuildDerived(data.Stats or {}, ConfigPack)
end

function StatsService:AddXP(player, amount)
	if type(amount) ~= "number" or amount <= 0 then
		return { ok = false, reason = "bad-amount" }
	end
	self:_ensureDefaults(player)
	local _, data = ProfileService:GetProfile(player)
	if not data then return { ok = false, reason = "no-profile" } end

	local newLevel, newXP, points = safeCompute(data.Level, data.XP, amount, ConfigPack)

	if newLevel ~= data.Level then
		ProfileService:ChangeData(player, {"Level"}, newLevel)
		ProfileService:ChangeData(player, {"UnspentPoints"}, num(data.UnspentPoints, 0) + points)
	end
	if newXP ~= data.XP then
		ProfileService:ChangeData(player, {"XP"}, newXP)
	end

	return { ok = true, level = newLevel, xp = newXP, pointsAwarded = points }
end

-- ---------- Knit lifecycle ----------
function StatsService:KnitStart()
	StatCalculator = require(componentsFolder.Others.StatCalculator)
	XPLevel = require(componentsFolder.Others.XPLevel)

	-- If your ProfileService exposes a “profile ready/loaded” event, normalize immediately
	if ProfileService.PlayerProfileLoaded then
		ProfileService.PlayerProfileLoaded:Connect(function(player)
			self:_ensureDefaults(player)
		end)
	end

	-- Defensive re-broadcast whenever Level/XP is changed
	if ProfileService.UpdateSpecificData then
		ProfileService.UpdateSpecificData:Connect(function(player, path, _)
			if not player or not path or #path == 0 then return end
			if path[1] == "Level" or path[1] == "XP" then
				self:_ensureDefaults(player)
				local _, data = ProfileService:GetProfile(player)
				if data then
					self.Client.LevelChanged:Fire(player, num(data.Level,1), num(data.XP,0))
				end
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		self._allocCooldown[player] = nil
	end)
end

function StatsService:KnitInit()
	ProfileService = Knit.GetService("ProfileService")
	componentsInitializer(script)
end

-- ---------- client RPC (unchanged) ----------
function StatsService.Client:AllocatePoints(player, statName, count)
	local now = os.clock()
	local last = self.Server._allocCooldown[player]
	if last and (now - last) < 0.2 then
		return { ok = false, reason = "throttled" }
	end
	self.Server._allocCooldown[player] = now

	self.Server:_ensureDefaults(player)
	local result = self.Server.SetComponent:AllocatePoints(player, statName, count)
	if result and result.ok then
		self.Server.Client.StatsChanged:Fire(player, result.snapshot)
	end
	return result
end

return StatsService
