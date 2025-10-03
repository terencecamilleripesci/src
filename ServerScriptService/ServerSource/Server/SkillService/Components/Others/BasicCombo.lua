local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Combo = {}

local Config = require(ReplicatedStorage.Configs.ConfigPack)

local comboState = {} -- [player] = { index=number, lastTime=number, lockUntil=number }

local function now()
	return os.clock()
end

function Combo.Reset(player)
	comboState[player] = { index = 1, lastTime = 0, lockUntil = 0 }
end

local function ensure(player)
	if not comboState[player] then Combo.Reset(player) end
	return comboState[player]
end

function Combo.OnLMB(player: Player)
	local martial = Config.MartialArts and Config.MartialArts.KungFu
	if not martial then return { ok=false, reason="no-config" } end
	local basic = martial.Basic or {}
	local steps = basic.Combo or {}
	local maxWindow = basic.MaxChainWindow or 0.5
	local chainCD = basic.CooldownBetweenChains or 1

	local st = ensure(player)
	if now() < (st.lockUntil or 0) then
		return { ok=false, reason="locked" }
	end

	local t = now()
	if t - (st.lastTime or 0) > maxWindow then
		st.index = 1
	end

	local step = steps[st.index]
	if not step then
		st.index = 1
		step = steps[st.index]
		if not step then return { ok=false, reason="no-steps" } end
	end

	-- Enforce per-step recovery (can't trigger next step until after recovery)
	local rec = step.Recovery or 0
	if t < (st.lastTime or 0) + rec then
		return { ok=false, reason="recovering" }
	end

	-- Advance index for next time
	st.lastTime = t
	-- Lockout during recovery period
	st.lockUntil = math.max(st.lockUntil or 0, t + rec)
	if step.Finisher then
		st.lockUntil = math.max(st.lockUntil, t + chainCD)
		st.index = 1
	else
		st.index = st.index + 1
	end

	return {
		ok = true,
		step = step,
	}
end

return Combo
