local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local okCfg, Config = pcall(function()
	return require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ConfigPack"))
end)
if not okCfg then
	warn("[ParryDefense] ConfigPack require failed: ", Config)
	Config = {}
end

local ParryCfg = (Config.MartialArts and Config.MartialArts.KungFu and Config.MartialArts.KungFu.Parry) or {}

local M = {}

-- Resolve parry effect. Returns: finalDamage:number, info:table
-- ctx = { Damage:number, DamageType:string, Flags:table? }
function M.Resolve(attacker, defender, ctx)
	ctx = ctx or {}
	local dmg   = tonumber(ctx.Damage) or 0
	local flags = ctx.Flags or {}

	-- ParryBreak skills ignore parry reduction
	if flags.ParryBreak then
		return dmg, { brokeParry = true }
	end

	-- Ask CombatService if defender is actively parrying
	local CS = Knit.GetService("CombatService")
	local isParrying = false
	if CS and CS.IsParrying then
		local ok, res = pcall(function() return CS:IsParrying(defender) end)
		isParrying = ok and res or false
	end
	if not isParrying then
		return dmg -- no parry active
	end

	-- Parry reduction (does NOT stack with Defense; this replaces it)
	local pvpMult = tonumber(ParryCfg.PvPReduction) or 0.8
	local pveMult = tonumber(ParryCfg.PvEReduction) or 0.9

	local isAttackerPlayer = false
	if typeof(attacker) == "Instance" then
		if attacker:IsA("Player") then
			isAttackerPlayer = true
		elseif attacker:IsA("Model") then
			isAttackerPlayer = Players:GetPlayerFromCharacter(attacker) ~= nil
		end
	end

	local mult = isAttackerPlayer and pvpMult or pveMult
	local reduced = math.max(0, dmg * (1 - mult))
	return reduced, { parried = true, parryMult = mult }
end

-- Compatibility for code that expects Check(): returns isParried:boolean, finalDamage:number, info:table
function M.Check(attacker, defender, ctx)
	local final, info = M.Resolve(attacker, defender, ctx)
	local parried = info and (info.parried or info.brokeParry) or false
	return parried, final, info
end

return M
