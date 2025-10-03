local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local Allocator = {}

-- Pure allocation calculator; does not mutate data by itself.
-- Returns result table:
-- { ok = boolean, reason? = string, usedPoints = number, newValue = number }
function Allocator.ComputeAllocation(profileData, ConfigPack, statName: string, requestedPoints: number)
	if type(profileData) ~= "table" then
		return { ok = false, reason = "no-profile" }
	end
	local statsCfg = ConfigPack and ConfigPack.Stats
	if not statsCfg then
		return { ok = false, reason = "no-config" }
	end

	local allocatable = statsCfg.Allocatable
	if not (allocatable and allocatable[statName]) then
		return { ok = false, reason = "invalid-stat" }
	end

	local count = tonumber(requestedPoints)
	if not count or count ~= math.floor(count) or count <= 0 then
		return { ok = false, reason = "bad-count" }
	end

	local available = tonumber(profileData.UnspentPoints) or 0
	if available <= 0 then
		return { ok = false, reason = "no-points" }
	end

	-- Clamp by available points
	count = math.min(count, available)

	local stats = profileData.Stats or {}
	local current = tonumber(stats[statName]) or 0

	-- Per-point increments (Health/Mana/Stamina). For Strength/Defense default to +1/point
	local perPoint = statsCfg.PerPoint and statsCfg.PerPoint[statName] or 1

	-- Determine caps mapping names
	local caps = statsCfg.Caps or {}
	local capKey
	if statName == "Health" then capKey = "HealthMax"
	elseif statName == "Mana" then capKey = "ManaMax"
	elseif statName == "Stamina" then capKey = "StaminaMax"
	elseif statName == "Strength" then capKey = "StrengthMax"
	elseif statName == "Defense" then capKey = "DefenseMax"
	else
		capKey = nil
	end
	local cap = capKey and tonumber(caps[capKey]) or nil

	-- Figure max usable points given the cap and perPoint gain
	local maxUsable = count
	if cap then
		local remainingToCap = math.max(0, cap - current)
		if remainingToCap <= 0 then
			return { ok = false, reason = "at-cap" }
		end
		local maxByCap = math.floor(remainingToCap / perPoint)
		if perPoint > 0 and (remainingToCap % perPoint) == 0 then
			-- exact fit allowed (floor already ok)
		end
		maxUsable = math.max(0, math.min(count, maxByCap))
	end

	if maxUsable <= 0 then
		return { ok = false, reason = "cap-block" }
	end

	local increment = maxUsable * perPoint
	local newValue = current + increment
	if cap then
		newValue = math.clamp(newValue, 0, cap)
	end

	return {
		ok = true,
		usedPoints = maxUsable,
		newValue = newValue,
		increment = increment,
	}
end

function Allocator.Start() end
function Allocator.Init() end
return Allocator
