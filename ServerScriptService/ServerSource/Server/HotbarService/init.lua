local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local HotbarService = Knit.CreateService({
	Name = "HotbarService",
	Client = {
		HotbarUpdated = Knit.CreateSignal(),
	},
	_lastCall = {}, -- throttle
})

local componentsInitializer = require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
local componentsFolder = script:WaitForChild("Components", 5)

HotbarService.Components = {}
for _, v in pairs(componentsFolder:WaitForChild("Others", 10):GetChildren()) do
	HotbarService.Components[v.Name] = require(v)
end

HotbarService.GetComponent = require(componentsFolder["Get()"])
HotbarService.SetComponent = require(componentsFolder["Set()"])

local ProfileService

local function throttle(self, player)
	local now = os.clock()
	local last = self._lastCall[player]
	if last and (now - last) < 0.2 then
		return false
	end
	self._lastCall[player] = now
	return true
end

function HotbarService:GetSnapshot(player)
	return self.GetComponent:GetSnapshot(player)
end

function HotbarService.Client:SetSlot(player: Player, slotIndex: number, idOrNil: string?)
	if not throttle(self.Server, player) then
		return { ok = false, reason = "throttled" }
	end
	local result = self.Server.SetComponent:SetSlot(player, slotIndex, idOrNil)
	if result and result.ok then
		self.Server.Client.HotbarUpdated:Fire(player, result.snapshot)
	end
	return result
end

function HotbarService:KnitInit()
	ProfileService = Knit.GetService("ProfileService")
	componentsInitializer(script)
end

function HotbarService:KnitStart()
	Players.PlayerRemoving:Connect(function(p)
		self._lastCall[p] = nil
	end)
end

return HotbarService
