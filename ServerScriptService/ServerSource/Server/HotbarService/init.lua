local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local HotbarService = Knit.CreateService({
    Name = "HotbarService",
    Client = {
        HotbarUpdated = Knit.CreateSignal(), -- fires to caller on successful SetSlot
    },
    _throttle = {}, -- [player]=lastTime
})

-- Components loader (kept light / optional)
local componentsInitializer = require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
local componentsFolder = script:WaitForChild("Components", 5)
HotbarService.Components = {}
if componentsFolder then
    local others = componentsFolder:FindFirstChild("Others")
    if others then
        for _,v in ipairs(others:GetChildren()) do
            HotbarService.Components[v.Name] = require(v)
        end
    end
end
local GetComponent = componentsFolder and require(componentsFolder["Get()"])
local SetComponent = componentsFolder and require(componentsFolder["Set()"])

local ProfileService
local ConfigPack = require(ReplicatedStorage.Configs.ConfigPack)

-- Server helper (optional for other services)
function HotbarService:GetSnapshot(player)
    if GetComponent and GetComponent.GetSnapshot then
        return GetComponent:GetSnapshot(player)
    end
    local _, data = ProfileService:GetProfile(player)
    return { Hotbar = data and data.Hotbar or {} }
end

-- Client-callable: Set a slot (1..MaxSlots) to an id or nil
function HotbarService.Client:SetSlot(player: Player, slotIndex: number, idOrNil: any)
    -- throttle
    local now = os.clock()
    local last = self.Server._throttle[player]
    if last and (now - last) < 0.2 then
        return { ok=false, reason="throttled" }
    end
    self.Server._throttle[player] = now

    -- server-authoritative write
    local result
    if SetComponent and SetComponent.SetSlot then
        result = self.Server.SetComponent:SetSlot(player, slotIndex, idOrNil)
    else
        -- fallback: simple write directly to profile
        local profile, data = ProfileService:GetProfile(player)
        if not data then return { ok=false, reason="no-profile" } end
        local maxSlots = (ConfigPack.Hotbar and ConfigPack.Hotbar.MaxSlots) or 4
        if type(slotIndex) ~= "number" or slotIndex < 1 or slotIndex > maxSlots then
            return { ok=false, reason="bad-slot" }
        end
        data.Hotbar = data.Hotbar or {}
        data.Hotbar[slotIndex] = idOrNil
        ProfileService:ChangeData(player, {"Hotbar", slotIndex}, idOrNil)
        result = { ok=true, snapshot = { Hotbar = data.Hotbar } }
    end

    if result and result.ok then
        self.Server.Client.HotbarUpdated:Fire(player, result.snapshot)
    end
    return result
end

function HotbarService:KnitStart()
    -- cleanup throttles
    Players.PlayerRemoving:Connect(function(p) self._throttle[p] = nil end)
end

function HotbarService:KnitInit()
    ProfileService = Knit.GetService("ProfileService")
    -- bind components
    self.GetComponent = GetComponent
    self.SetComponent = SetComponent
    componentsInitializer(script)
end

return HotbarService
