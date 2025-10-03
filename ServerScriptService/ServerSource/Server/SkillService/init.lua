local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))

local SkillService = Knit.CreateService({
	Name = "SkillService",
	Client = {
		-- Fires when a specific skill levels (to the owning player)
		SkillLeveled = Knit.CreateSignal(),
		-- One-shot payloads for client VFX/SFX or stance loops
		LocalAction  = Knit.CreateSignal(),

		-- Client RPCs (server authoritative)
		UseSkill = function(self, player: Player, key: string)
			local set = self.Server.SetComponent
			if set and set.UseSkill then
				local result = set:UseSkill(player, key)
				if result and result.ok and result.leveled and result.skillId and result.level then
					self.Server.Client.SkillLeveled:Fire(player, result.skillId, result.level)
				end
				return result
			end
			return { ok = false, reason = "UseSkill not implemented" }
		end,

		LMB = function(self, player: Player)
			local set = self.Server.SetComponent
			if set and set.UseLMB then
				return set:UseLMB(player)
			end
			return { ok = false, reason = "LMB not implemented" }
		end,

		ParryDown = function(self, player: Player)
			local set = self.Server.SetComponent
			if set and set.ParryDown then
				return set:ParryDown(player)
			end
			return { ok = false, reason = "ParryDown not implemented" }
		end,

		ParryUp = function(self, player: Player)
			local set = self.Server.SetComponent
			if set and set.ParryUp then
				return set:ParryUp(player)
			end
			return { ok = false, reason = "ParryUp not implemented" }
		end,
	},
})

-- ===== Helpers =====
local function safeRequire(mod: Instance?)
	if not (mod and mod:IsA("ModuleScript")) then return nil end
	local ok, res = pcall(require, mod)
	if not ok then
		warn(("[SkillService] require failed for %s\n%s"):format(mod:GetFullName(), tostring(res)))
		return nil
	end
	return res
end

local function tryGetService(name: string)
	local ok, svc = pcall(function() return Knit.GetService(name) end)
	return ok and svc or nil
end
-- ====================

-- Exposed component refs
SkillService.Components = {}
SkillService.GetComponent = nil
SkillService.SetComponent = nil

-- Optional configs (not required at load)
local ConfigPack do
	local cfgFolder = ReplicatedStorage:FindFirstChild("Configs")
	if cfgFolder then
		ConfigPack = safeRequire(cfgFolder:FindFirstChild("ConfigPack"))
	end
end

-- Knit service deps (optional)
local SaveService -- preferred
local ProfileService -- fallback/info only
local MasteryService
local HotbarService
local CombatService
local StatsService

-- Admin helper (stays as you had it)
function SkillService:GrantMartial(player: Player, id: string)
	local set = self.SetComponent
	if set and set.GrantMartial then
		return set:GrantMartial(player, id)
	end
	return { ok = false, reason = "GrantMartial not implemented" }
end

-- Small helper passthrough
function SkillService:GetCooldowns(player: Player)
	local get = self.GetComponent
	if get and get.GetCooldowns then
		return get:GetCooldowns(player)
	end
	return {}
end

function SkillService:KnitInit()
	-- Resolve other services safely (no hard crash if missing)
	SaveService     = tryGetService("SaveService") or nil
	ProfileService  = tryGetService("ProfileService") or nil -- only if you actually have one
	MasteryService  = tryGetService("MasteryService") or nil
	HotbarService   = tryGetService("HotbarService") or nil
	CombatService   = tryGetService("CombatService") or nil
	StatsService    = tryGetService("StatsService") or nil

	-- Load components (no infinite wait; warn if absent)
	local componentsFolder = script:FindFirstChild("Components")
	if not componentsFolder then
		warn("[SkillService] Components folder missing (ok on first boot).")
	else
		-- Others/*
		local others = componentsFolder:FindFirstChild("Others")
		if others then
			for _, m in ipairs(others:GetChildren()) do
				if m:IsA("ModuleScript") then
					local mod = safeRequire(m)
					if mod then
						SkillService.Components[m.Name] = mod
					end
				end
			end
		end

		-- Get()/Set()
		local getMod = componentsFolder:FindFirstChild("Get()")
		local setMod = componentsFolder:FindFirstChild("Set()")
		SkillService.GetComponent = safeRequire(getMod)
		SkillService.SetComponent = safeRequire(setMod)
	end

	-- Optional: component lifecycle initializer if your project uses it
	local initPath = ReplicatedStorage:FindFirstChild("SharedSource")
	if initPath then
		local utils = initPath:FindFirstChild("Utilities")
		if utils then
			local loader = utils:FindFirstChild("ScriptsLoader")
			if loader then
				local initMod = loader:FindFirstChild("ComponentsInitializer")
				local ComponentsInitializer = safeRequire(initMod)
				if ComponentsInitializer then
					pcall(function() ComponentsInitializer(script) end)
				end
			end
		end
	end
end

function SkillService:KnitStart()
	-- No tight loops here; just cleanup hooks
	Players.PlayerRemoving:Connect(function(player)
		local set = self.SetComponent
		if set and set.Cleanup then
			pcall(function() set:Cleanup(player) end)
		end
	end)

	-- If Set component wants to bind remotes, let it
	local set = self.SetComponent
	if set and set.BindRemotes then
		pcall(function() set:BindRemotes(self) end)
	end
end

return SkillService
