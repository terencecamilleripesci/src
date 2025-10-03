local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local HotbarService = Knit.CreateService({
	Name = "HotbarService",
	Client = {
		HotbarUpdated = Knit.CreateSignal(),
	},

	-- internal
	_setCooldown = {}, -- [player] = lastTime
})

---- Components
--- component utilities
local componentsInitializer = require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
--- component folders
local componentsFolder = script:WaitForChild("Components", 5)
HotbarService.Components = {}
for _, v in pairs(componentsFolder:WaitForChild("Others", 10):GetChildren()) do
	HotbarService.Components[v.Name] = require(v)
end
local self_GetComponent = require(componentsFolder["Get()"])
HotbarService.GetComponent = self_GetComponent
HotbarService.SetComponent = require(componentsFolder["Set()"])

---- Knit Services
local ProfileService
local SaveService

---- Configs
local ConfigsFolder = ReplicatedStorage:WaitForChild("Configs", 10)
local ConfigPack = ConfigsFolder and require(ConfigsFolder:WaitForChild("ConfigPack", 10))

-- Client API
function HotbarService.Client:SetSlot(player: Player, slotIndex: number, id: string | nil)
	-- Throttle per-player requests
	local now = os.clock()
	local last = self.Server._setCooldown[player]
	if last and (now - last) < 0.2 then
		return { ok = false, reason = "throttled" }
	end
	self.Server._setCooldown[player] = now

	local result = self.Server.SetComponent:SetSlot(player, slotIndex, id)
	if result and result.ok then
		self.Server.Client.HotbarUpdated:Fire(player, result.snapshot)
	end
	return result
end

-- Server helpers
function HotbarService:GetSnapshot(player: Player)
	return self_GetComponent:GetSnapshot(player)
end

function HotbarService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		self._setCooldown[player] = nil
	end)
end

function HotbarService:KnitInit()
	---- Knit Services
	ProfileService = Knit.GetService("ProfileService")
	SaveService = Knit.GetService("SaveService")

	---- Components Initializer
	componentsInitializer(script)
end

return HotbarService