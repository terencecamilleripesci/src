local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local StatsService = Knit.CreateService({
    Name = "StatsService",
    Client = {
        StatsChanged = Knit.CreateSignal(), -- payload: snapshot
        LevelChanged = Knit.CreateSignal(), -- payload: (level, xp)
    },
    _allocCooldown = {}, -- [player]=lastTime
})

local componentsInitializer = require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
local componentsFolder = script:WaitForChild("Components", 5)
StatsService.Components = {}
if componentsFolder then
    local others = componentsFolder:FindFirstChild("Others")
    if others then
        for _,v in ipairs(others:GetChildren()) do
            StatsService.Components[v.Name] = require(v)
        end
    end
end
local GetComponent = componentsFolder and require(componentsFolder["Get()"])
local SetComponent = componentsFolder and require(componentsFolder["Set()"])

local ProfileService
local ConfigPack = require(ReplicatedStorage.Configs.ConfigPack)

local StatCalculator -- deferred require
local XPLevel        -- deferred require

function StatsService:GetSnapshot(player)
    if GetComponent and GetComponent.GetSnapshot then
        return GetComponent:GetSnapshot(player)
    end
    local _, data = ProfileService:GetProfile(player)
    return data and data.Stats or {}
end

function StatsService:GetDerived(player)
    local _, data = ProfileService:GetProfile(player)
    if not data then return nil end
    if not StatCalculator then
        local othersFolder = componentsFolder and componentsFolder:FindFirstChild("Others")
        if othersFolder then
            StatCalculator = require(othersFolder:WaitForChild("StatCalculator", 10))
        end
    end
    if StatCalculator then
        return StatCalculator.BuildDerived(data.Stats or {}, ConfigPack)
    end
    return nil
end

function StatsService.Client:AllocatePoints(player: Player, statName: string, count: number)
    local now = os.clock()
    local last = self.Server._allocCooldown[player]
    if last and (now - last) < 0.2 then
        return { ok=false, reason="throttled" }
    end
    self.Server._allocCooldown[player] = now

    if not SetComponent or not SetComponent.AllocatePoints then
        return { ok=false, reason="not-implemented" }
    end

    local result = self.Server.SetComponent:AllocatePoints(player, statName, count)
    if result and result.ok then
        self.Server.Client.StatsChanged:Fire(player, result.snapshot)
    end
    return result
end

function StatsService:_rebroadcastLevel(player)
    local _, data = ProfileService:GetProfile(player)
    if not data then return end
    self.Client.LevelChanged:Fire(player, data.Level, data.XP)
end

function StatsService:KnitStart()
    -- deferred requires
    local othersFolder = componentsFolder and componentsFolder:FindChild("Others") or componentsFolder and componentsFolder:FindFirstChild("Others")
    othersFolder = othersFolder or (componentsFolder and componentsFolder:FindFirstChild("Others"))
    if componentsFolder then
        local ok1, mod1 = pcall(function() return require(componentsFolder.Others.StatCalculator) end)
        if ok1 then StatCalculator = mod1 end
        local ok2, mod2 = pcall(function() return require(componentsFolder.Others.XPLevel) end)
        if ok2 then XPLevel = mod2 end
    end

    if ProfileService and ProfileService.UpdateSpecificData then
        ProfileService.UpdateSpecificData:Connect(function(player, path)
            if player and path and #path > 0 then
                if path[1] == "Level" or path[1] == "XP" then
                    self:_rebroadcastLevel(player)
                end
            end
        end)
    end

    Players.PlayerRemoving:Connect(function(p) self._allocCooldown[p] = nil end)
end

function StatsService:KnitInit()
    ProfileService = Knit.GetService("ProfileService")
    self.GetComponent = GetComponent
    self.SetComponent = SetComponent
    componentsInitializer(script)
end

return StatsService
