-- ParryDefense.lua
-- Parry overrides Defense (never stack). Returns final damage and parry info.

local ParryDefense = {}

-- ctx = { BaseDamage, DamageType="Physical"/"Magical", Flags? }
-- parryCfg = Config.MartialArts.KungFu.Parry (or equivalent)
-- isPvP = boolean
function ParryDefense.Resolve(baseDamage, parryActive, parryCfg, isPvP)
    if not parryActive or not parryCfg then
        return baseDamage, false, 0
    end

    local reduce = isPvP and (parryCfg.PvPReduction or 0.8) or (parryCfg.PvEReduction or 0.9)
    local dmg = math.max(0, math.floor(baseDamage * (1 - reduce)))

    -- we don't decide break here (that depends on the attacker flag ParryBreak)
    return dmg, true, 0
end

-- Compatibility helper (optional) — returns { damage, parried, stunSeconds }
function ParryDefense.Check(baseDamage, isParrying, isPvP, cfg)
    local dmg, parried, stun = ParryDefense.Resolve(baseDamage, isParrying, cfg, isPvP)
    return { damage = dmg, parried = parried, stunSeconds = stun }
end

return ParryDefense
