local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParryDefense = {}

local Config = require(ReplicatedStorage.Configs.ConfigPack)

local function isPvP(attacker, defender)
	return attacker and defender and attacker.UserId ~= 0 and defender.UserId ~= 0
end

-- Returns: parried:boolean, reduction:number, breakStun:number, hitSoundId:string?, breakSoundId:string?
function ParryDefense.Check(defender: Player, ctx)
	local others = script.Parent
	local ParryState = require(others.ParryState)
	if not ParryState.IsActive(defender) then
		return false, 0, 0
	end
	if ctx and ctx.Flags and ctx.Flags.ParryBreak then
		local stun = (Config.MartialArts and Config.MartialArts.KungFu and Config.MartialArts.KungFu.Parry and Config.MartialArts.KungFu.Parry.BreakStunSeconds) or 1
		local breakSfx = Config.Sounds and Config.Sounds.ParryBreak
		return true, 0, stun, nil, breakSfx
	end
	local pCfg = Config.MartialArts and Config.MartialArts.KungFu and Config.MartialArts.KungFu.Parry or {}
	local reduction = isPvP(ctx and ctx.attacker, defender) and (pCfg.PvPReduction or 0.8) or (pCfg.PvEReduction or 0.9)
	local hitSfx = Config.Sounds and Config.Sounds.ParryHit
	return true, reduction, 0, hitSfx, nil
end

return ParryDefense
