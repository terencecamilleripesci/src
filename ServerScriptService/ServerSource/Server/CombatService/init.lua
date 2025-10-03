local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local CombatService = Knit.CreateService({
	Name = "CombatService",
	Client = {
		DamageDealt = Knit.CreateSignal(),
		DamageTaken = Knit.CreateSignal(),
		Died = Knit.CreateSignal(),
		ParryStateChanged = Knit.CreateSignal(),
	},

	_health = {}, -- [player] = current hp (runtime only)
	_dead = {},   -- [player] = true if currently dead/respawning
	_stunUntil = {}, -- [player] = os.clock() when stun ends
})

---- Components
--- component utilities
local componentsInitializer = require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
--- component folders
local componentsFolder = script:WaitForChild("Components", 5)
CombatService.Components = {}
for _, v in pairs(componentsFolder:WaitForChild("Others", 10):GetChildren()) do
	CombatService.Components[v.Name] = require(v)
end
local self_GetComponent = require(componentsFolder["Get()"])
CombatService.GetComponent = self_GetComponent
CombatService.SetComponent = require(componentsFolder["Set()"])

---- Knit Services
local ProfileService
local SaveService
local StatsService
local MasteryService

---- Configs
local ConfigsFolder = ReplicatedStorage:WaitForChild("Configs", 10)
local ConfigPack = ConfigsFolder and require(ConfigsFolder:WaitForChild("ConfigPack", 10))

---- Others (deferred requires)
local DamageCalc
local DOT
local ParryDefense
local Death

-- Internal helpers
local function getMaxHP(player: Player)
	local derived = StatsService:GetDerived(player) or {}
	return derived.MaxHealth or (ConfigPack and ConfigPack.Stats and ConfigPack.Stats.Base.Health) or 100
end

local function now()
	return os.clock()
end

local function ensureHPInitialized(player: Player)
	if not CombatService._health[player] then
		CombatService._health[player] = getMaxHP(player)
	end
end

-- Crowd control helpers
function CombatService:IsStunned(player: Player)
	local t = self._stunUntil[player]
	return t ~= nil and now() < t
end

function CombatService:Stun(player: Player, seconds: number)
	local dur = tonumber(seconds) or 0
	if dur > 0 then
		self._stunUntil[player] = math.max(self._stunUntil[player] or 0, now() + dur)
	end
end

-- Main server-only damage entry
-- ctx = {
--   BaseDamage: number,
--   DamageType: "Physical"|"Magical",
--   CanCrit: boolean? (default true),
--   IgnoreParry: boolean? (default false),
--   Flags: table? (e.g., { IsDOT=true })
-- }
function CombatService:ApplyDamage(attacker: Player?, defender: Player, ctx: table)
	if typeof(defender) ~= "Instance" then return { ok=false, reason="bad-defender" } end
	if not ctx or type(ctx.BaseDamage) ~= "number" or ctx.BaseDamage <= 0 then
		return { ok=false, reason="bad-ctx" }
	end
	if self._dead[defender] then
		return { ok=false, reason="target-dead" }
	end

	ensureHPInitialized(defender)
	local atkSnap = attacker and StatsService:GetSnapshot(attacker) or nil
	local defSnap = StatsService:GetSnapshot(defender)
	if not defSnap then return { ok=false, reason="no-defender-data" } end

	local damageType = ctx.DamageType or "Physical"
	local canCrit = (ctx.CanCrit ~= false)

	-- Parry priority (never stacks with defense)
	local parried, reduction, breakStun, parryHitSfx, parryBreakSfx = false, 0, 0, nil, nil
	if not (ctx.IgnoreParry) then
		local callCtx = table.clone(ctx)
		callCtx.attacker = attacker
		parried, reduction, breakStun, parryHitSfx, parryBreakSfx = ParryDefense.Check(defender, callCtx)
	end

	local crit, amount = false, 0
	if parried then
		if breakStun and breakStun > 0 then
			-- guard broken: ignore parry reduction, apply stun and break stance
			amount = math.max(1, math.floor(ctx.BaseDamage or 0))
			self:Stun(defender, breakStun)
			-- break stance
			self:SetParryActive(defender, false)
		else
			-- apply parry reduction, no defense stacking
			crit, amount = DamageCalc.Compute(atkSnap, defSnap, ctx.BaseDamage, damageType, ConfigPack, { canCrit = false, skipMitigation = true })
			amount = math.floor(amount * (1 - reduction))
			amount = math.max(1, amount)
		end
	else
		crit, amount = DamageCalc.Compute(atkSnap, defSnap, ctx.BaseDamage, damageType, ConfigPack, { canCrit = canCrit })
		amount = math.max(1, math.floor(amount))
	end

	-- Apply to runtime HP and clamp
	local cur = CombatService._health[defender]
	local newHP = math.max(0, cur - amount)
	CombatService._health[defender] = newHP

	-- Fire client signals (to respective players only)
	if attacker then
		self.Client.DamageDealt:Fire(attacker, {
			target = defender,
			amount = amount,
			crit = crit,
			parried = parried,
			isDOT = (ctx.Flags and ctx.Flags.IsDOT) or false,
			remaining = newHP,
			max = getMaxHP(defender),
		})
	end
	self.Client.DamageTaken:Fire(defender, {
		source = attacker,
		amount = amount,
		crit = crit,
		parried = parried,
		isDOT = (ctx.Flags and ctx.Flags.IsDOT) or false,
		remaining = newHP,
		max = getMaxHP(defender),
		parryHitSfx = parryHitSfx,
		parryBreakSfx = parryBreakSfx,
		breakStun = breakStun,
	})

	-- Handle death
	if newHP <= 0 and not self._dead[defender] then
		self._dead[defender] = true
		self.Client.Died:Fire(defender)
		-- Mastery credit for the attacker if a slot key was provided
		if attacker and ctx and ctx.SlotKey then
			pcall(function()
				MasteryService:AddKillCredit(attacker, ctx.SlotKey, "Normal")
			end)
		end
		Death.Handle(defender, ConfigPack, ProfileService)
	end

	return { ok = true, damage = amount, crit = crit, parried = parried, remaining = newHP }
end

-- Public helper: apply a configured DOT debuff (e.g., "Burn" or "Bleed")
function CombatService:ApplyDOT(attacker: Player?, defender: Player, debuffId: string)
	if typeof(defender) ~= "Instance" or type(debuffId) ~= "string" then
		return { ok=false, reason="bad-args" }
	end
	local deb = ConfigPack and ConfigPack.Debuffs and ConfigPack.Debuffs[debuffId]
	if not deb then
		return { ok=false, reason="unknown-debuff" }
	end

	-- Provide a callback so DOT manager can tick damage without circular requires
	DOT.Run(attacker, defender, deb, function(src, dst, base, dtype)
		return CombatService:ApplyDamage(src, dst, { BaseDamage = base, DamageType = dtype, CanCrit = false, IgnoreParry = true, Flags = { IsDOT = true } })
	end)
	return { ok = true }
end

-- Expose health snapshot to other systems
function CombatService:GetHealthSnapshot(player: Player)
	ensureHPInitialized(player)
	local max = getMaxHP(player)
	local cur = math.clamp(self._health[player], 0, max)
	return { current = cur, max = max }
end

function CombatService:KnitStart()
	-- Defer requires
	local othersFolder = componentsFolder:WaitForChild("Others", 10)
	DamageCalc = require(othersFolder:WaitForChild("DamageCalc", 10))
	DOT = require(othersFolder:WaitForChild("DOT", 10))
	ParryDefense = require(othersFolder:WaitForChild("ParryDefense", 10))
	Death = require(othersFolder:WaitForChild("Death", 10))

	-- Initialize health on join/character spawn
	local function initPlayer(p: Player)
		ProfileService:WaitUntilProfileLoaded(p)
		CombatService._health[p] = getMaxHP(p)
		-- Reset death state and hp whenever character spawns
		p.CharacterAdded:Connect(function()
			CombatService._dead[p] = nil
			CombatService._health[p] = getMaxHP(p)
		end)
	end

	for _, p in ipairs(Players:GetPlayers()) do
		initPlayer(p)
	end
	Players.PlayerAdded:Connect(initPlayer)
	Players.PlayerRemoving:Connect(function(p)
		CombatService._health[p] = nil
		CombatService._dead[p] = nil
	end)

	-- Clamp health on stat changes
	ProfileService.UpdateSpecificData:Connect(function(player, path, _)
		if not player or not path or #path == 0 then return end
		if path[1] == "Stats" then
			local max = getMaxHP(player)
			ensureHPInitialized(player)
			CombatService._health[player] = math.clamp(CombatService._health[player], 0, max)
		end
	end)
end

-- Allow other services to toggle Parry state
function CombatService:SetParryActive(player: Player, active: boolean)
	local othersFolder = componentsFolder:WaitForChild("Others", 10)
	local ParryState = require(othersFolder:WaitForChild("ParryState", 10))
	ParryState.Set(player, active)
end

function CombatService:KnitInit()
	---- Knit Services
	ProfileService = Knit.GetService("ProfileService")
	SaveService = Knit.GetService("SaveService")
	StatsService = Knit.GetService("StatsService")
	MasteryService = Knit.GetService("MasteryService")

	---- Components Initializer
	componentsInitializer(script)
end

return CombatService