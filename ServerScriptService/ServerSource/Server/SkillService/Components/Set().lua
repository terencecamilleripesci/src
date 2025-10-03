local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

---- Knit Services
local ProfileService
local MasteryService
local HotbarService
local CombatService

---- Others (defer requires)
local Catalog
local Gating
local SkillExp
local BasicCombo

-- runtime cooldowns per player per key
module._cooldowns = {} -- [player] = { [key] = os.clock() when usable again }

local function now()
	return os.clock()
end

local function isAdmin(player)
	local Config = require(ReplicatedStorage.Configs.ConfigPack)
	local wl = (Config.Admin and Config.Admin.Whitelist) or {}
	if RunService:IsStudio() then return true end
	for _, id in ipairs(wl) do
		if id == player.UserId then return true end
	end
	return false
end

local function getSlotKeyForKey(key)
	-- Map keys to mastery slots 1:1 (Z/X/C/F/V)
	if key == "Z" or key == "X" or key == "C" or key == "F" or key == "V" then
		return key
	end
	return nil
end

function module:Cleanup(player: Player)
	self._cooldowns[player] = nil
end

-- Admin persistent grant of Martial Arts set and auto-assign hotbar if any empty
function module:GrantMartial(player: Player, id: string)
	if not isAdmin(player) then
		return { ok=false, reason="not-admin" }
	end
	if type(id) ~= "string" or #id == 0 then
		return { ok=false, reason="bad-id" }
	end
	local profile, data = ProfileService:GetProfile(player)
	if not data then return { ok=false, reason="no-profile" } end

	data.MartialArts = data.MartialArts or {}
	if not data.MartialArts[id] then
		data.MartialArts[id] = true
		ProfileService:ChangeData(player, {"MartialArts", id}, true)
	end

	-- Auto-assign to first empty hotbar slot
	local assigned = false
	for i=1,4 do
		if data.Hotbar[i] == nil then
			data.Hotbar[i] = id
			ProfileService:ChangeData(player, {"Hotbar", i}, id)
			assigned = true
			break
		end
	end

	-- Immediately unlock Z for testing
	local Config = require(ReplicatedStorage.Configs.ConfigPack)
	local threshold = Config.Mastery.Unlocks.Z
	data.Mastery = data.Mastery or {}
	if (data.Mastery.Z or 0) < threshold then
		data.Mastery.Z = threshold
		ProfileService:ChangeData(player, {"Mastery","Z"}, threshold)
	end

	return { ok=true, assigned = assigned }
end

-- LMB basic combo server entry
function module:UseLMB(player: Player)
	if typeof(player) ~= "Instance" then
		return { ok=false, reason="bad-player" }
	end
	local profile, data = ProfileService:GetProfile(player)
	if not data then return { ok=false, reason="no-profile" } end
	-- Basic stamina check using first step cost (will be re-checked at each step)
	local combo = require(script.Parent.Others.BasicCombo)
	local res = combo.OnLMB(player)
	if not (res and res.ok) then return res end
	local step = res.step
	if step.StaminaCost and (data.Stats.Stamina or 0) < step.StaminaCost then
		return { ok=false, reason="no-stamina" }
	end
	-- Spend stamina immediately
	if step.StaminaCost then
		data.Stats.Stamina -= step.StaminaCost
		ProfileService:ChangeData(player, {"Stats","Stamina"}, data.Stats.Stamina)
	end
	-- Tell client to play animation + sfx; client will display instantly
	local service = require(script.Parent.Parent)
	service.Client.LocalAction:Fire(player, { type = "PlayAnimSFX", anim = step.AnimId, sound = step.SoundId })

	-- After windup, resolve a single server-side hit to nearest target in front
	task.delay(step.Windup or 0, function()
		local cfg = require(ReplicatedStorage.Configs.ConfigPack)
		local martial = cfg.MartialArts.KungFu.Basic
		local Hitbox = require(script.Parent.Others.Hitbox)
		local target = Hitbox.FindNearestInFront(player, martial.Range, martial.ConeDeg)
		if target then
			CombatService:ApplyDamage(player, target, { BaseDamage = step.Damage, DamageType = "Physical" })
		end
	end)
	-- Recovery handling/lockout already maintained by BasicCombo
	return { ok=true, step = step }
end

-- Server-authoritative skill usage request
-- RMB parry stance
function module:ParryDown(player: Player)
	local CombatService = Knit.GetService("CombatService")
	CombatService:SetParryActive(player, true)
	-- tell client to loop stance anim/sfx
	local Config = require(ReplicatedStorage.Configs.ConfigPack)
	local parry = Config.MartialArts.KungFu.Parry
	local service = require(script.Parent.Parent)
	service.Client.LocalAction:Fire(player, { type = "ParryLoop", anim = parry.StanceAnimId, sound = parry.StanceSoundId, active = true })
	return { ok = true }
end

function module:ParryUp(player: Player)
	local CombatService = Knit.GetService("CombatService")
	CombatService:SetParryActive(player, false)
	local service = require(script.Parent.Parent)
	service.Client.LocalAction:Fire(player, { type = "ParryLoop", active = false })
	return { ok = true }
end

function module:UseSkill(player: Player, key: string)
	if typeof(player) ~= "Instance" or type(key) ~= "string" then
		return { ok=false, reason="bad-args" }
	end
	local profile, data = ProfileService:GetProfile(player)
	if not data then return { ok=false, reason="no-profile" } end

	local slotKey = getSlotKeyForKey(key)
	if not slotKey then return { ok=false, reason="bad-key" } end

	-- Find a skill definition for this key from config via catalog
	local skillDef, category = Catalog.GetSkillByKey(data, key)
	if not skillDef then
		return { ok=false, reason="no-skill" }
	end

	-- Gating: mastery threshold
	local ok, why = Gating.Check(data, MasteryService, slotKey, skillDef)
	if not ok then
		return { ok=false, reason=why }
	end

	-- Cooldown check
	local cdMap = self._cooldowns[player]
	if not cdMap then cdMap = {}; self._cooldowns[player] = cdMap end
	local readyAt = cdMap[key]
	if readyAt and now() < readyAt then
		return { ok=false, reason="cooldown" }
	end

	-- Resource costs (basic checks):
	local cost = skillDef.Cost or {}
	if cost.Mana then
		if (data.Stats.Mana or 0) < cost.Mana then
			return { ok=false, reason="no-mana" }
		end
		data.Stats.Mana -= cost.Mana
		ProfileService:ChangeData(player, {"Stats","Mana"}, data.Stats.Mana)
	end
	if cost.Stamina then
		if (data.Stats.Stamina or 0) < cost.Stamina then
			return { ok=false, reason="no-stamina" }
		end
		data.Stats.Stamina -= cost.Stamina
		ProfileService:ChangeData(player, {"Stats","Stamina"}, data.Stats.Stamina)
	end

	-- Execute effect: immediate server side damage application to the nearest target in front if configured
	local context = {
		skillId = skillDef.Name,
		category = category,
		key = key,
		damageType = skillDef.Type or "Physical",
		baseDamage = skillDef.BaseDamage or 0,
		flags = skillDef.Flags,
	}

	-- Fire client to play anim + sfx immediately
	local service = require(script.Parent.Parent)
	service.Client.LocalAction:Fire(player, { type = "PlayAnimSFX", anim = skillDef.AnimationId, sound = skillDef.SoundId })

	-- After windup, resolve a server-side hit to nearest valid target
	task.delay((skillDef.Windup or 0), function()
		local Hitbox = require(script.Parent.Others.Hitbox)
		local cfg = require(ReplicatedStorage.Configs.ConfigPack)
		local martial = cfg.MartialArts and cfg.MartialArts.KungFu and cfg.MartialArts.KungFu.Basic
		local range = (martial and martial.Range) or 8
		local cone = (martial and martial.ConeDeg) or 60
		local target = Hitbox.FindNearestInFront(player, range, cone)
		if target then
			CombatService:ApplyDamage(player, target, { BaseDamage = context.baseDamage or context.BaseDamage or 0, DamageType = context.damageType, Flags = skillDef.Flags, SlotKey = key })
		end
	end)

	-- Award Skill EXP per-use
	local level, xp, leveled = SkillExp.AddUse(data, context.skillId)
	ProfileService:ChangeData(player, {"SkillExp", context.skillId}, { Level = level, Exp = xp })

	-- Set cooldown
	local cd = tonumber(skillDef.Cooldown) or 1
	cdMap[key] = now() + cd

	return { ok=true, context=context, leveled=leveled, skillId=context.skillId, level=level }
end

function module.Start()
	Catalog = require(script.Parent.Others.Catalog)
	Gating = require(script.Parent.Others.Gating)
	SkillExp = require(script.Parent.Others.SkillExp)
	BasicCombo = require(script.Parent.Others.BasicCombo)
	-- CombatService optional usage later when we do server target validation
end

function module.Init()
	ProfileService = Knit.GetService("ProfileService")
	MasteryService = Knit.GetService("MasteryService")
	HotbarService = Knit.GetService("HotbarService")
	CombatService = Knit.GetService("CombatService")
end

return module
