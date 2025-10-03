local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local HotbarService = Knit.CreateService({
	Name = "HotbarService",
	Client = {
		HotbarUpdated = Knit.CreateSignal(), -- fires to caller with latest snapshot
	},
})

local ProfileService
local _throttle = {} -- [player] = last os.clock()

local function now() return os.clock() end
local function snapshot(data) return { Hotbar = (data and data.Hotbar) or {} } end

function HotbarService:_setSlot(player: Player, slotIndex: number, idOrNil: string?)
	if type(slotIndex) ~= "number" or slotIndex < 1 or slotIndex > 4 then
		return { ok=false, reason="bad-slot" }
	end
	local _, data = ProfileService:GetProfile(player)
	if not data then return { ok=false, reason="no-profile" } end

	data.Hotbar = data.Hotbar or {}
	data.Hotbar[slotIndex] = idOrNil -- nil = clear
	ProfileService:ChangeData(player, {"Hotbar", slotIndex}, idOrNil)

	return { ok=true, snapshot = snapshot(data) }
end

function HotbarService.Client:SetSlot(player: Player, slotIndex: number, idOrNil: string?)
	local t = now()
	local last = _throttle[player]
	if last and (t - last) < 0.2 then
		return { ok=false, reason="throttled" }
	end
	_throttle[player] = t

	local res = self.Server:_setSlot(player, slotIndex, idOrNil)
	if res and res.ok then
		self.Server.Client.HotbarUpdated:Fire(player, res.snapshot)
	end
	return res
end

function HotbarService:GetSnapshot(player: Player)
	local _, data = ProfileService:GetProfile(player)
	return snapshot(data)
end

function HotbarService:KnitInit()
	ProfileService = Knit.GetService("ProfileService")
end

function HotbarService:KnitStart()
	Players.PlayerRemoving:Connect(function(p) _throttle[p] = nil end)
end

return HotbarService
