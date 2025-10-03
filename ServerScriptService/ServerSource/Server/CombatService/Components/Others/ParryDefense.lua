local module = {}

local parry = {} -- [player] = true/false

function module.SetParry(player, active)
	if active then
		parry[player] = true
	else
		parry[player] = nil
	end
end

function module.IsParrying(player)
	return parry[player] == true
end

-- Optional hook if other code expects a Check() signature
-- Return values: isParry, reductionPercent
function module.Check(attacker, defender, ctx)
	return false, 0
end

return module
