local ReplicatedStorage = game:GetService("ReplicatedStorage")

local XPLevel = {}

-- Compute level ups given current level/xp and an amount to add.
-- Returns newLevel, newXP, pointsGained
function XPLevel.Compute(level: number, xp: number, addAmount: number, ConfigPack)
	local cfg = ConfigPack and ConfigPack.XP
	local statsCfg = ConfigPack and ConfigPack.Stats
	if not cfg or type(cfg.ExpFormula) ~= "function" then
		return level, math.max(0, xp + (addAmount or 0)), 0
	end

	local pointsPerLevel = (statsCfg and statsCfg.STAT_POINTS_PER_LEVEL) or 2
	local curLevel = tonumber(level) or 1
	local curXP = tonumber(xp) or 0
	local add = tonumber(addAmount) or 0
	curXP = math.max(0, curXP + add)

	local gainedPoints = 0
	local safety = 0
	while safety < 1000 do
		safety += 1
		local needed = cfg.ExpFormula(curLevel)
		if not needed or needed <= 0 then break end
		if curXP >= needed then
			curXP -= needed
			curLevel += 1
			gainedPoints += pointsPerLevel
		else
			break
		end
	end
	return curLevel, curXP, gainedPoints
end

return XPLevel
