-- ServerScriptService/ServerSource/Server/StatService/init.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local StatService = Knit.CreateService({
    Name = "StatService", -- << singular, authoritative
    Client = {
        StatsChanged = Knit.CreateSignal(),
        LevelChanged = Knit.CreateSignal(),
    },
    _allocCooldown = {}, -- [player] = lastTime
})

-- Components bootstrap
local componentsInitializer = require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
local componentsFolder = script:WaitForChild("Components", 5)
StatService.Components = {}
for _, v in pairs(componentsFolder:WaitForChild("Others", 10):GetChildren()) do
    StatService.Components[v.Name] = require(v)
end
local self_GetComponent = require(componentsFolder["Get()"])
StatService.GetComponent = self_GetComponent
StatService.SetComponent = require(componentsFolder["Set()"])

-- Knit services we depend on
local ProfileService
local XPLevel
local StatCalculator

-- Small helpers
local function now() return os.clock() end

function StatService:GetSnapshot(player)
    return self_GetComponent:GetSnapshot(player)
end

function StatService:GetDerived(player)
    local _, data = ProfileService:GetProfile(player)
    if not data then return nil end
    if not StatCalculator then
        StatCalculator = require(componentsFolder.Others.StatCalculator)
    end
    local ConfigPack = require(ReplicatedStorage.Configs.ConfigPack)
    return StatCalculator.BuildDerived(data.Stats or {}, ConfigPack)
end

-- Add XP and handle level ups safely
function StatService:AddXP(player: Player, amount: number)
    amount = tonumber(amount) or 0
    if amount <= 0 then
        return { ok = false, reason = "bad-amount" }
    end

    local _, data = ProfileService:GetProfile(player)
    if not data then return { ok=false, reason="no-profile" } end

    local ConfigPack = require(ReplicatedStorage.Configs.ConfigPack)
    if not XPLevel then
        XPLevel = require(componentsFolder.Others.XPLevel)
    end

    local newLevel, newXP, points = XPLevel.Compute(
        tonumber(data.Level) or 1,
        tonumber(data.XP) or 0,
        amount,
        ConfigPack
    )

    points = tonumber(points) or 0

    if newLevel ~= (tonumber(data.Level) or 1) then
        ProfileService:ChangeData(player, {"Level"}, newLevel)
        ProfileService:ChangeData(player, {"UnspentPoints"}, (tonumber(data.UnspentPoints) or 0) + points)
    else
        ProfileService:ChangeData(player, {"XP"}, newXP)
    end

    return { ok = true, level = newLevel, xp = newXP, pointsAwarded = points }
end

-- Client API: allocate stat points with throttling and nil-safe math
function StatService.Client:AllocatePoints(player: Player, statName: string, count: number)
    local srv = self.Server

    local last = srv._allocCooldown[player]
    local t = now()
    if last and (t - last) < 0.2 then
        return { ok=false, reason="throttled" }
    end
    srv._allocCooldown[player] = t

    count = math.floor(tonumber(count) or 0)
    if count == 0 then return { ok=false, reason="zero" } end

    -- Delegate to Set() which does full validation and writes to ProfileService
    local result = srv.SetComponent:AllocatePoints(player, tostring(statName or ""), count)

    if result and result.ok then
        srv.Client.StatsChanged:Fire(player, result.snapshot)
    end
    return result
end

function StatService:_rebroadcastLevelXP(player: Player)
    local _, data = ProfileService:GetProfile(player)
    if not data then return end
    self.Client.LevelChanged:Fire(player, tonumber(data.Level) or 1, tonumber(data.XP) or 0)
end

function StatService:KnitStart()
    -- Late requires
    XPLevel = require(componentsFolder.Others.XPLevel)
    StatCalculator = require(componentsFolder.Others.StatCalculator)

    -- When ProfileService changes Level/XP, rebroadcast to client
    ProfileService.UpdateSpecificData:Connect(function(player, path)
        if not player or not path or #path == 0 then return end
        local root = path[1]
        if root == "Level" or root == "XP" then
            self:_rebroadcastLevelXP(player)
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        self._allocCooldown[player] = nil
    end)
end

function StatService:KnitInit()
    ProfileService = Knit.GetService("ProfileService")
    componentsInitializer(script)
end

return StatService
