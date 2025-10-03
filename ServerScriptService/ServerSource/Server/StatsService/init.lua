-- ServerScriptService/ServerSource/Server/StatService/Components/Set().lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Knit services (resolved lazily)
local ProfileService

-- Config
local ConfigPack = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ConfigPack"))

local module = {}

-- helpers
local function num(v, fallback) fallback = fallback or 0; return (type(v) == "number") and v or fallback end

local function clampStat(v, maxA, maxB, hardDefault)
	-- accept either legacy keys (MaxHealth) or new keys (HealthMax)
	local max = num(maxA or maxB or hardDefault or 9999)
	return math.clamp(num(v, 0), 0, max)
end

local function ensureStats(data)
	data.Stats = data.Stats or {}
	local caps = (ConfigPack.Stats and ConfigPack.Stats.Caps) or {}

	data.Stats.Health   = clampStat(data.Stats.Health,   caps.MaxHealth,   caps.HealthMax,   9999)
	data.Stats.Mana     = clampStat(data.Stats.Mana,     caps.MaxMana,     caps.ManaMax,     9999)
	data.Stats.Stamina  = clampStat(data.Stats.Stamina,  caps.MaxStamina,  caps.StaminaMax,  9999)
	data.Stats.Strength = clampStat(data.Stats.Strength, caps.MaxStrength, caps.StrengthMax, 2000)
	data.Stats.Defense  = clampStat(data.Stats.Defense,  caps.MaxDefense,  caps.DefenseMax,  2000)
end

-- Server-authoritative stat allocation
function module:AllocatePoints(player: Player, statName: string, count: number)
	ProfileService = ProfileService or Knit.GetService("ProfileService")

	-- validate args
	statName = tostring(statName or "")
	count = tonumber(count) or 0
	if count <= 0 then
		return { ok = false, reason = "bad-count" }
	end

	local _, data = ProfileService:GetProfile(player)
	if not data then
		return { ok = false, reason = "no-profile" }
	end

	-- normalize numbers to avoid nil math
	data.UnspentPoints = num(data.UnspentPoints)
	ensureStats(data)

	if data.UnspentPoints < count then
		return { ok = false, reason = "no-points" }
	end

	local per  = (ConfigPack.Stats and ConfigPack.Stats.PerPoint) or {}
	local caps = (ConfigPack.Stats and ConfigPack.Stats.Caps) or {}

	if statName == "Health" then
		data.Stats.Health = clampStat(data.Stats.Health + count * num(per.Health, 0), caps.MaxHealth,  caps.HealthMax,  9999)
	elseif statName == "Mana" then
		data.Stats.Mana = clampStat(data.Stats.Mana + count * num(per.Mana, 0),   caps.MaxMana,    caps.ManaMax,    9999)
	elseif statName == "Stamina" then
		data.Stats.Stamina = clampStat(data.Stats.Stamina + count * num(per.Stamina, 0), caps.MaxStamina, caps.StaminaMax, 9999)
	elseif statName == "Strength" then
		data.Stats.Strength = clampStat(data.Stats.Strength + count, caps.MaxStrength, caps.StrengthMax, 2000)
	elseif statName == "Defense" then
		data.Stats.Defense = clampStat(data.Stats.Defense + count,  caps.MaxDefense,  caps.DefenseMax,  2000)
	else
		return { ok = false, reason = "bad-stat" }
	end

	-- consume points + persist
	data.UnspentPoints -= count
	ProfileService:ChangeData(player, {"UnspentPoints"}, data.UnspentPoints)
	ProfileService:ChangeData(player, {"Stats"}, data.Stats)

	return {
		ok = true,
		snapshot = {
			UnspentPoints = data.UnspentPoints,
			Stats = data.Stats,
		}
	}
end

return module
