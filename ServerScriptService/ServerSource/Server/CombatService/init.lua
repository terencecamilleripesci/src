local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local CombatService = Knit.CreateService({
	Name = "CombatService",
	Client = {},
	_parry = {},
})

local componentsInitializer = require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
local componentsFolder = script:WaitForChild("Components", 5)

CombatService.Components = {}
for _, v in pairs(componentsFolder:WaitForChild("Others", 10):GetChildren()) do
	CombatService.Components[v.Name] = require(v)
end

local self_GetComponent = require(componentsFolder["Get()"])
CombatService.GetComponent = self_GetComponent
CombatService.SetComponent = require(componentsFolder["Set()"])

local ProfileService
local StatsService
local MasteryService
local HotbarService

local ConfigsFolder = ReplicatedStorage:WaitForChild("Configs", 10)
local ConfigPack = ConfigsFolder and require(ConfigsFolder:WaitForChild("ConfigPack", 10))

local ParryDefense

local function N(n, d)
	n = tonumber(n)
	return (n ~= nil) and n or (d or 0)
end

function CombatService:SetParryActive(player: Player, active: boolean)
	if active then
		self._parry[player] = true
	else
		self._parry[player] = nil
	end
	if ParryDefense and ParryDefense.SetParry then
		ParryDefense.SetParry(player, active)
	end
end

function CombatService:IsParrying(player: Player)
	return self._parry[player] == true
end

function CombatService:ApplyDamage(attacker: Player, target: Instance, ctx: table)
	ctx = ctx or {}

	local humanoid: Humanoid? = nil
	if target then
		if target:IsA("Humanoid") then
			humanoid = target
		elseif target:IsA("Model") then
			humanoid = target:FindFirstChildOfClass("Humanoid")
		end
	end
	if not humanoid then
		return { ok = false, reason = "no-humanoid" }
	end

	local base = N(ctx.BaseDamage, 0)
	local dmgType = ctx.DamageType or "Physical"
	local flags = ctx.Flags or {}

	local atkStats = StatsService and attacker and StatsService:GetDerived(attacker) or nil
	if dmgType == "Physical" then
		local mul = (ConfigPack.Stats and N(ConfigPack.Stats.STR_MULTIPLIER, 0)) or 0
		base += (atkStats and N(atkStats.Strength, 0) or 0) * mul
	else
		local mul = (ConfigPack.DamageTypes and ConfigPack.DamageTypes.Magical and N(ConfigPack.DamageTypes.Magical.Multiplier, 0)) or 0
		base += (atkStats and N(atkStats.Mana, 0) or 0) * mul
	end

	local victimPlayer = humanoid.Parent and Players:GetPlayerFromCharacter(humanoid.Parent) or nil
	local vicStats = StatsService and victimPlayer and StatsService:GetDerived(victimPlayer) or nil

	local mitPct = 0
	if dmgType == "Physical" then
		local mul = (ConfigPack.Stats and N(ConfigPack.Stats.DEF_MULTIPLIER, 0)) or 0
		local cap = (ConfigPack.Stats and N(ConfigPack.Stats.DEF_CAP, 0.75)) or 0.75
		mitPct = math.clamp((vicStats and N(vicStats.Defense, 0) or 0) * mul, 0, cap)
	else
		local useRes = (ConfigPack.Stats and ConfigPack.Stats.UseMagicResist) or false
		if useRes then
			local mul = N(ConfigPack.Stats.MAG_DEF_MULTIPLIER, 0)
			local cap = N(ConfigPack.Stats.MagicResistCap, 0.75)
			mitPct = math.clamp((vicStats and N(vicStats.MagicResist, 0) or 0) * mul, 0, cap)
		else
			local mul = N(ConfigPack.Stats.DEF_MULTIPLIER, 0)
			local cap = N(ConfigPack.Stats.DEF_CAP, 0.75)
			mitPct = math.clamp((vicStats and N(vicStats.Defense, 0) or 0) * mul, 0, cap)
		end
	end

	if victimPlayer and self:IsParrying(victimPlayer) then
		mitPct = 1
	end

	local final = math.max(0, math.floor(base * (1 - mitPct)))

	if final > 0 then
		humanoid:TakeDamage(final)
	end

	return { ok = true, damage = final, mitigated = mitPct }
end

function CombatService:KnitInit()
	StatsService   = Knit.GetService("StatsService")
	MasteryService = Knit.GetService("MasteryService")
	HotbarService  = Knit.GetService("HotbarService")
	ProfileService = Knit.GetService("ProfileService")

	componentsInitializer(script)

	local others = componentsFolder:FindFirstChild("Others")
	if others then
		local pd = others:FindFirstChild("ParryDefense")
		if pd then
			ParryDefense = require(pd)
		end
	end
end

function CombatService:KnitStart()
	Players.PlayerRemoving:Connect(function(p)
		self._parry[p] = nil
	end)
end

return CombatService
