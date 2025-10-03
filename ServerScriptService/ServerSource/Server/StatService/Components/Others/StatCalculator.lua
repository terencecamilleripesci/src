local StatCalculator = {}

-- Recompute derived stats (e.g., max hp/mana/stamina).
-- IMPORTANT: Profile.Stats values are treated as actual stat values (already include base + allocations).
-- So derived maxima are just those values capped and later modified by gear/buffs (not applied here).
function StatCalculator.BuildDerived(stats, ConfigPack)
	local cfg = ConfigPack and ConfigPack.Stats
	if not cfg then return {} end
	local caps = cfg.Caps or {}

	local s = stats or {}
	local derived = {
		MaxHealth = math.min(s.Health or 0, caps.HealthMax or math.huge),
		MaxMana = math.min(s.Mana or 0, caps.ManaMax or math.huge),
		MaxStamina = math.min(s.Stamina or 0, caps.StaminaMax or math.huge),
	}
	return derived
end

return StatCalculator
