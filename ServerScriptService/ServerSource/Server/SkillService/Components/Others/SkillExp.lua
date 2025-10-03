local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillExp = {}

-- Increment per-use EXP and level if needed
-- data.SkillExp[skillId] = { Level, Exp }
function SkillExp.AddUse(data, skillId: string)
	local cfg = require(ReplicatedStorage.Configs.ConfigPack)
	local skCfg = cfg and cfg.SkillExp or {}
	local expGain = skCfg.ExpPerUse or 5
	local maxLevel = skCfg.MaxSkillLevel or 10
	local formula = skCfg.ExpFormula or function(lvl) return 50 * lvl end

	data.SkillExp = data.SkillExp or {}
	local rec = data.SkillExp[skillId] or { Level = 0, Exp = 0 }
	rec.Exp = (rec.Exp or 0) + expGain
	local needed = formula(rec.Level or 0)
	local leveled = false
	while rec.Level < maxLevel and rec.Exp >= needed do
		rec.Exp -= needed
		rec.Level += 1
		leveled = true
		needed = formula(rec.Level)
	end
	data.SkillExp[skillId] = rec
	return rec.Level, rec.Exp, leveled
end

return SkillExp
