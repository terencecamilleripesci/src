local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local MasteryService = Knit.CreateService({
	Name = "MasteryService",
	Client = {
		-- Fired to a single player when a slot becomes newly unlocked (crosses its threshold)
		SlotUnlocked = Knit.CreateSignal(),
	},
})

---- Components
--- component utilities
local componentsInitializer = require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
--- component folders
local componentsFolder = script:WaitForChild("Components", 5)
MasteryService.Components = {}
for _, v in pairs(componentsFolder:WaitForChild("Others", 10):GetChildren()) do
	MasteryService.Components[v.Name] = require(v)
end
local self_GetComponent = require(componentsFolder["Get()"])
MasteryService.GetComponent = self_GetComponent
MasteryService.SetComponent = require(componentsFolder["Set()"])

---- Knit Services
local ProfileService

---- Configs
local ConfigsFolder = ReplicatedStorage:WaitForChild("Configs", 10)
local ConfigPack = ConfigsFolder and require(ConfigsFolder:WaitForChild("ConfigPack", 10))

-- Public server API
function MasteryService:GetSnapshot(player: Player)
	return self_GetComponent:GetSnapshot(player)
end

-- Add kill credit to a mastery slot (Z/X/C/F/V). If 'kind' omitted, defaults to 'Normal'.
-- Returns { ok, newValue, unlocked:boolean }
function MasteryService:AddKillCredit(player: Player, slotKey: string, kind: string?)
	return self.SetComponent:AddKillCredit(player, slotKey, kind)
end

-- Convenience: check if slot is unlocked for player
function MasteryService:IsUnlocked(player: Player, slotKey: string)
	return self_GetComponent:IsUnlocked(player, slotKey)
end

function MasteryService:KnitStart()
	-- No-op for now; wiring to CombatService will happen in that service or SkillService once slot context is known
end

function MasteryService:KnitInit()
	---- Knit Services
	ProfileService = Knit.GetService("ProfileService")

	---- Components Initializer
	componentsInitializer(script)
end

-- Admin API to max a mastery slot and fire unlock
function MasteryService:MaxMastery(player: Player, slotKey: string)
	-- Admin-only guard
	local Config = require(ReplicatedStorage.Configs.ConfigPack)
	local wl = (Config.Admin and Config.Admin.Whitelist) or {}
	local isStudio = game:GetService("RunService"):IsStudio()
	local allowed = isStudio
	for _, id in ipairs(wl) do
		if id == player.UserId then allowed = true break end
	end
	if not allowed then
		return { ok=false, reason="not-admin" }
	end

	local profile, data = ProfileService:GetProfile(player)
	if not data then return { ok=false, reason="no-profile" } end

	local need = Config.Mastery.Unlocks[slotKey]
	if not need then return { ok=false, reason="bad-slot" } end

	data.Mastery = data.Mastery or {}
	data.Mastery[slotKey] = need
	ProfileService:ChangeData(player, {"Mastery", slotKey}, need)
	MasteryService.Client.SlotUnlocked:Fire(player, slotKey)
	return { ok=true, mastery = need }
end

return MasteryService