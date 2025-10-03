local DamageCalc = {}

-- Compute damage according to config and snapshots
-- atkSnap: { Stats = { Strength=, Mana= }, ... } or nil (environment)
-- defSnap: { Stats = { Defense=, Mana= }, ... }
function DamageCalc.Compute(atkSnap, defSnap, baseDamage, damageType, ConfigPack, opts)
	local cfg = ConfigPack or {}
	local types = cfg.DamageTypes or {}
	local critCfg = cfg.Crit or { DefaultChance = 0.05, DefaultMultiplier = 1.5 }
	local t = types[damageType] or types.Physical

	local canCrit = not (opts and opts.canCrit == false)
	local skipMitigation = (opts and opts.skipMitigation) or false
	local atkStatName = (t and t.StatScale) or "Strength"
	local scaleMult = (t and t.Multiplier) or (cfg.Stats and cfg.Stats.STR_MULTIPLIER) or 0
	local mitStatName = (t and t.MitigationStat) or "Defense"
	local mitMult = (t and t.MitigationMultiplier) or (cfg.Stats and cfg.Stats.DEF_MULTIPLIER) or 0
	local mitCap = (t and t.Cap) or (cfg.Stats and cfg.Stats.DEF_CAP) or 0.75

	local atkStat = 0
	if atkSnap and atkSnap.Stats and atkSnap.Stats[atkStatName] then
		atkStat = tonumber(atkSnap.Stats[atkStatName]) or 0
	end

	local defStat = 0
	if defSnap and defSnap.Stats and defSnap.Stats[mitStatName] then
		defStat = tonumber(defSnap.Stats[mitStatName]) or 0
	end

	-- Strength scaling applied to all damage (per spec)
	local strengthBonus = 0
	if atkSnap and atkSnap.Stats and atkSnap.Stats.Strength then
		local s = tonumber(atkSnap.Stats.Strength) or 0
		local sm = (cfg.Stats and cfg.Stats.STR_MULTIPLIER) or 0
		strengthBonus = baseDamage * s * sm
	end

	local scaled = baseDamage + (baseDamage * atkStat * scaleMult) + strengthBonus

	-- Mitigation via defense-like stat with cap (unless skipped)
	local reduction = 0
	if not skipMitigation then
		reduction = math.clamp(defStat * mitMult, 0, mitCap)
	end
	local afterMit = scaled * (1 - reduction)

	-- Crit roll
	local crit = false
	if canCrit then
		local chance = critCfg.DefaultChance or 0.05
		if math.random() < chance then
			crit = true
			afterMit *= (critCfg.DefaultMultiplier or 1.5)
		end
	end

	return crit, afterMit
end

return DamageCalc
