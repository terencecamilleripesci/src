local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local StatsService = Knit.CreateService({
	Name = "StatsService",
	Client = {
		StatsChanged = Knit.CreateSignal(),
		LevelChanged = Knit.CreateSignal(),
	},
	_allocCooldown = {}, -- [player] = os.clock()
})

-- Deferred refs
local ProfileService
local componentsFolder
local componentsInitializer
local GetComp
local SetComp
local StatCalculator
local XPLevel
local ConfigPack

-- Helpers
local function num(v, fallback) fallback = fallback or 0; return (type(v)=="number") and v or fallback end
local function clamp(v, min, max) return math.clamp(num(v), min, max) end
local function clampStat(v, maxA, maxB, hardDefault) return clamp(v, 0, num(maxA or maxB or hardDefault or 9999)) end

local _sanitizing = setmetatable({}, {__mode="k"})
function StatsService:_ensureStatRanges(player, data)
	if not data or _sanitizing[player] then return end
	local caps = (ConfigPack and ConfigPack.Stats and ConfigPack.Stats.Caps) or {}
	local base = (ConfigPack and ConfigPack.Stats and ConfigPack.Stats.Base) or {Health=100,Mana=50,Stamina=100}

	data.Stats = data.Stats or {}
	data.Stats.Health   = num(data.Stats.Health,   base.Health)
	data.Stats.Mana     = num(data.Stats.Mana,     base.Mana)
	data.Stats.Stamina  = num(data.Stats.Stamina,  base.Stamina)
	data.Stats.Strength = num(data.Stats.Strength, 0)
	data.Stats.Defense  = num(data.Stats.Defense,  0)

	data.Stats.Health   = clampStat(data.Stats.Health,   caps.MaxHealth,   caps.HealthMax,   9999)
	data.Stats.Mana     = clampStat(data.Stats.Mana,     caps.MaxMana,     caps.ManaMax,     9999)
	data.Stats.Stamina  = clampStat(data.Stats.Stamina,  caps.MaxStamina,  caps.StaminaMax,  9999)
	data.Stats.Strength = clampStat(data.Stats.Strength, caps.MaxStrength, caps.StrengthMax, 2000)
	data.Stats.Defense  = clampStat(data.Stats.Defense,  caps.MaxDefense,  caps.DefenseMax,  2000)

	_sanitizing[player] = true
	ProfileService:ChangeData(player, {"Stats"}, data.Stats)
	_sanitizing[player] = nil
end

-- Public helpers
function StatsService:GetSnapshot(player)
	return GetComp and GetComp:GetSnapshot(player)
end
function StatsService:GetDerived(player)
	if not (ProfileService and StatCalculator and ConfigPack) then return nil end
	local _, data = ProfileService:GetProfile(player)
	if not data then return nil end
	return StatCalculator.BuildDerived(data.Stats or {}, ConfigPack)
end

-- Server API
function StatsService:AddXP(player: Player, amount: number)
	if type(amount) ~= "number" or amount <= 0 then return {ok=false, reason="bad-amount"} end
	local _, data = ProfileService:GetProfile(player)
	if not data then return {ok=false, reason="no-profile"} end
	local newLevel, newXP, points = XPLevel.Compute(data.Level, data.XP, amount, ConfigPack)
	if newLevel ~= data.Level then
		ProfileService:ChangeData(player, {"Level"}, newLevel)
		ProfileService:ChangeData(player, {"UnspentPoints"}, num(data.UnspentPoints) + num(points))
	else
		ProfileService:ChangeData(player, {"XP"}, newXP)
	end
	return {ok=true, level=newLevel, xp=newXP, pointsAwarded=points}
end

function StatsService.Client:AllocatePoints(player: Player, statName: string, count: number)
	local now = os.clock()
	local last = self.Server._allocCooldown[player]
	if last and (now - last) < 0.2 then
		return { ok=false, reason="throttled" }
	end
	self.Server._allocCooldown[player] = now

	if not SetComp then return { ok=false, reason="not-ready" } end
	local result = self.Server.SetComponent:AllocatePoints(player, statName, count)
	if result and result.ok then
		self.Server.Client.StatsChanged:Fire(player, result.snapshot)
	end
	return result
end

function StatsService:_broadcastLevelChanged(player: Player)
	local _, data = ProfileService:GetProfile(player)
	if not data then return end
	self.Client.LevelChanged:Fire(player, data.Level, data.XP)
end

function StatsService:KnitInit()
	ProfileService = Knit.GetService("ProfileService")

	-- Config
	do
		local cfgFolder = ReplicatedStorage:FindFirstChild("Configs")
		if cfgFolder then
			local ok, cfg = pcall(require, cfgFolder:WaitForChild("ConfigPack", 10))
			if ok then ConfigPack = cfg else warn("[StatsService] ConfigPack require failed:", cfg) end
		else
			warn("[StatsService] Missing ReplicatedStorage.Configs")
		end
	end

	-- Components
	componentsFolder = script:WaitForChild("Components", 10)
	local others = componentsFolder:WaitForChild("Others", 10)

	local okCI; okCI, componentsInitializer = pcall(function()
		return require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
	end)
	if okCI and componentsInitializer then
		componentsInitializer(script)
	end

	local okG; okG, GetComp = pcall(function() return require(componentsFolder["Get()"]) end)
	if not okG then warn("[StatsService] Get() require failed:", GetComp) GetComp = nil end

	local okS; okS, SetComp = pcall(function() return require(componentsFolder["Set()"]) end)
	if not okS then warn("[StatsService] Set() require failed:", SetComp) SetComp = nil end

	local okSC; okSC, StatCalculator = pcall(function() return require(others:WaitForChild("StatCalculator", 10)) end)
	if not okSC then warn("[StatsService] StatCalculator require failed:", StatCalculator) StatCalculator = nil end

	local okXL; okXL, XPLevel = pcall(function() return require(others:WaitForChild("XPLevel", 10)) end)
	if not okXL then warn("[StatsService] XPLevel require failed:", XPLevel) XPLevel = nil end
end

function StatsService:KnitStart()
	if ProfileService and ProfileService.UpdateSpecificData then
		ProfileService.UpdateSpecificData:Connect(function(player, path)
			if not player or not path or #path == 0 then return end
			if path[1] == "Level" or path[1] == "XP" then
				self:_broadcastLevelChanged(player)
			elseif path[1] == "Stats" then
				local _, data = ProfileService:GetProfile(player)
				if data then self:_ensureStatRanges(player, data) end
			end
		end)
	end

	Players.PlayerAdded:Connect(function(p)
		task.defer(function()
			for _ = 1, 100 do
				local _, data = ProfileService:GetProfile(p)
				if data then
					self:_ensureStatRanges(p, data)
					self:_broadcastLevelChanged(p)
					break
				end
				task.wait(0.1)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(p)
		self._allocCooldown[p] = nil
	end)
end

return StatsService
