-- ServerScriptService/ServerSource/Server/StatService/init.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local StatService = Knit.CreateService({
	Name = "StatService",
	Client = {
		-- to the owner only
		StatsChanged = Knit.CreateSignal(),
		LevelChanged = Knit.CreateSignal(),
	},
	_allocCooldown = {}, -- [player] = last call time
})

-- ========= Components =========
local componentsInitializer = require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
local componentsFolder = script:WaitForChild("Components", 5)
StatService.Components = {}
for _, v in pairs(componentsFolder:WaitForChild("Others", 10):GetChildren()) do
	StatService.Components[v.Name] = require(v)
end
local self_GetComponent = require(componentsFolder["Get()"])
StatService.GetComponent = self_GetComponent
StatService.SetComponent = require(componentsFolder["Set()"])

-- ========= Knit Services / Configs =========
local ProfileService -- resolved in KnitInit
local ConfigPack = require(ReplicatedStorage:WaitForChild("Configs", 10):WaitForChild("ConfigPack", 10))

-- deferred requires
local StatCalculator
local XPLevel

-- ========= Small helpers =========
local function clampToStatCaps(statName, value)
	value = tonumber(value) or 0
	if statName == "Stamina" then
		local cap = (ConfigPack.Stats.Caps and ConfigPack.Stats.Caps.StaminaMax) or 9999
		return math.clamp(value, 0, cap)
	elseif statName == "Mana" then
		local cap = (ConfigPack.Stats.Caps and ConfigPack.Stats.Caps.ManaMax) or 9999
		return math.clamp(value, 0, cap)
	elseif statName == "Health" then
		local cap = (ConfigPack.Stats.Caps and ConfigPack.Stats.Caps.HealthMax) or 9999
		return math.clamp(value, 0, cap)
	end
	return value
end

local function ensureStatsTable(data)
	data.Stats = data.Stats or {}
	local base = ConfigPack.Stats.Base
	-- only fill missing, never overwrite
	if data.Stats.Health   == nil then data.Stats.Health   = base.Health   end
	if data.Stats.Mana     == nil then data.Stats.Mana     = base.Mana     end
	if data.Stats.Stamina  == nil then data.Stats.Stamina  = base.Stamina  end
	if data.Stats.Strength == nil then data.Stats.Strength = base.Strength end
	if data.Stats.Defense  == nil then data.Stats.Defense  = base.Defense  end
end

-- ========= Public helpers other services use (Jump/Dash etc.) =========

function StatService:GetStamina(player)
	local _, data = ProfileService:GetProfile(player)
	if not data then return 0 end
	ensureStatsTable(data)
	return tonumber(data.Stats.Stamina) or 0
end

function StatService:SetStamina(player, value)
	local _, data = ProfileService:GetProfile(player)
	if not data then return { ok=false, reason="no-profile" } end
	ensureStatsTable(data)
	local v = clampToStatCaps("Stamina", value)
	data.Stats.Stamina = v
	ProfileService:ChangeData(player, {"Stats","Stamina"}, v)
	self.Client.StatsChanged:Fire(player, self_GetComponent:GetSnapshot(player))
	return { ok=true, value=v }
end

function StatService:AddStamina(player, delta)
	delta = tonumber(delta) or 0
	local cur = self:GetStamina(player)
	return self:SetStamina(player, cur + delta)
end

function StatService:GetMana(player)
	local _, data = ProfileService:GetProfile(player)
	if not data then return 0 end
	ensureStatsTable(data)
	return tonumber(data.Stats.Mana) or 0
end

function StatService:SetMana(player, value)
	local _, data = ProfileService:GetProfile(player)
	if not data then return { ok=false, reason="no-profile" } end
	ensureStatsTable(data)
	local v = clampToStatCaps("Mana", value)
	data.Stats.Mana = v
	ProfileService:ChangeData(player, {"Stats","Mana"}, v)
	self.Client.StatsChanged:Fire(player, self_GetComponent:GetSnapshot(player))
	return { ok=true, value=v }
end

function StatService:AddMana(player, delta)
	delta = tonumber(delta) or 0
	local cur = self:GetMana(player)
	return self:SetMana(player, cur + delta)
end

-- ========= Derivations / XP =========

function StatService:GetSnapshot(player)
	return self_GetComponent:GetSnapshot(player)
end

function StatService:GetDerived(player)
	local _, data = ProfileService:GetProfile(player)
	if not data then return nil end
	if not StatCalculator then
		StatCalculator = require(componentsFolder.Others:WaitForChild("StatCalculator"))
	end
	return StatCalculator.BuildDerived(data.Stats or {}, ConfigPack)
end

function StatService:AddXP(player, amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then return { ok=false, reason="bad-amount" } end

	local _, data = ProfileService:GetProfile(player)
	if not data then return { ok=false, reason="no-profile" } end

	-- ensure sane defaults so we never compare against nil
	data.Level = tonumber(data.Level) or 1
	data.XP    = tonumber(data.XP)    or 0

	local levelBefore = data.Level
	if not XPLevel then
		XPLevel = require(componentsFolder.Others:WaitForChild("XPLevel"))
	end

	local newLevel, newXP, points = XPLevel.Compute(data.Level, data.XP, amount, ConfigPack)
	if newLevel ~= levelBefore then
		ProfileService:ChangeData(player, {"Level"}, newLevel)
		ProfileService:ChangeData(player, {"UnspentPoints"}, (data.UnspentPoints or 0) + (points or 0))
	else
		ProfileService:ChangeData(player, {"XP"}, newXP)
	end

	self.Client.LevelChanged:Fire(player, newLevel, newXP)
	return { ok = true, level = newLevel, xp = newXP, pointsAwarded = points or 0 }
end

-- ========= Knit lifecycle =========

function StatService:KnitStart()
	StatCalculator = require(componentsFolder.Others.StatCalculator)
	XPLevel        = require(componentsFolder.Others.XPLevel)

	ProfileService.UpdateSpecificData:Connect(function(player, path)
		if not player or not path or #path == 0 then return end
		if path[1] == "Level" or path[1] == "XP" then
			local _, data = ProfileService:GetProfile(player)
			if data then
				self.Client.LevelChanged:Fire(player, tonumber(data.Level) or 1, tonumber(data.XP) or 0)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		self._allocCooldown[p] = nil
	end)
end

function StatService:KnitInit()
	ProfileService = Knit.GetService("ProfileService")
	componentsInitializer(script)
end

-- ========= Client RPC =========

function StatService.Client:AllocatePoints(player: Player, statName: string, count: number)
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

return StatService
