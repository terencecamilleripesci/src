-- StatService (server)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local StatService = Knit.CreateService({
    Name = "StatService", -- <== IMPORTANT: singular, matches Knit.GetService("StatService")
    Client = {
        StatsChanged = Knit.CreateSignal(),
        LevelChanged = Knit.CreateSignal(),
    },
    _allocCooldown = {}, -- [player] = lastTime for throttle
})

-- Components bootstrapping (kept as in your repo)
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
local ProfileService -- resolved in KnitInit()

-- Config
local ConfigsFolder = ReplicatedStorage:WaitForChild("Configs", 10)
local ConfigPack = ConfigsFolder and require(ConfigsFolder:WaitForChild("ConfigPack", 10))

-- ========= Internal helpers =========
local function _getData(player)
    local _, data = ProfileService:GetProfile(player)
    return data
end

local function _ensureStatsTable(player)
    local data = _getData(player)
    if not data then return nil end
    data.Stats = data.Stats or { Health=100, Mana=50, Stamina=100, Strength=0, Defense=0 }
    return data.Stats, data
end

-- ========= Public helpers used by other services =========

function StatService:GetSnapshot(player)
    return self_GetComponent:GetSnapshot(player)
end

function StatService:GetDerived(player)
    local data = _getData(player)
    if not data then return nil end
    local StatCalculator = require(componentsFolder.Others.StatCalculator)
    return StatCalculator.BuildDerived(data.Stats or {}, ConfigPack)
end

-- ---- Resource helpers (NEW) ----
function StatService:GetStat(player, name)
    local stats = _ensureStatsTable(player)
    return stats and stats[name] or nil
end

function StatService:SetStat(player, name, value)
    local stats, data = _ensureStatsTable(player)
    if not stats then return false end
    stats[name] = value
    ProfileService:ChangeData(player, {"Stats", name}, value)
    self.Client.StatsChanged:Fire(player, self_GetComponent:GetSnapshot(player))
    return true
end

function StatService:HasResource(player, name, amount)
    amount = tonumber(amount) or 0
    local v = self:GetStat(player, name)
    return type(v) == "number" and v >= amount
end

function StatService:SpendResource(player, name, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return true, self:GetStat(player, name) end
    local stats = _ensureStatsTable(player)
    if not stats then return false, "no-profile" end
    local cur = tonumber(stats[name]) or 0
    if cur < amount then return false, "insufficient" end
    cur -= amount
    stats[name] = cur
    ProfileService:ChangeData(player, {"Stats", name}, cur)
    self.Client.StatsChanged:Fire(player, self_GetComponent:GetSnapshot(player))
    return true, cur
end

-- Sugar aliases used by JumpService / Dash / Skills
function StatService:HasStamina(player, amount)  return self:HasResource(player, "Stamina", amount) end
function StatService:SpendStamina(player, amount) return self:SpendResource(player, "Stamina", amount) end
function StatService:HasMana(player, amount)     return self:HasResource(player, "Mana", amount) end
function StatService:SpendMana(player, amount)   return self:SpendResource(player, "Mana", amount) end

-- ========= XP / Level API (unchanged logic, kept simple) =========
function StatService:AddXP(player, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return { ok=false, reason="bad-amount" } end

    local data = _getData(player)
    if not data then return { ok=false, reason="no-profile" } end

    -- default values if nil
    data.Level = tonumber(data.Level) or 1
    data.XP    = tonumber(data.XP)    or 0
    local perLevel = ConfigPack and ConfigPack.XP and ConfigPack.XP.ExpFormula or function(l) return l*100 end
    local needed = perLevel(data.Level)

    local newXP = data.XP + amount
    local newLevel = data.Level
    while newXP >= needed do
        newXP -= needed
        newLevel += 1
        needed = perLevel(newLevel)
        data.UnspentPoints = (tonumber(data.UnspentPoints) or 0) + (ConfigPack.Stats and ConfigPack.Stats.STAT_POINTS_PER_LEVEL or 2)
        ProfileService:ChangeData(player, {"UnspentPoints"}, data.UnspentPoints)
    end

    if newLevel ~= data.Level then
        ProfileService:ChangeData(player, {"Level"}, newLevel)
        self.Client.LevelChanged:Fire(player, newLevel, newXP)
    end
    ProfileService:ChangeData(player, {"XP"}, newXP)
    return { ok=true, level=newLevel, xp=newXP }
end

-- ========= Client RPC =========
function StatService.Client:AllocatePoints(player, statName, count)
    local now = os.clock()
    local last = self.Server._allocCooldown[player]
    if last and (now - last) < 0.2 then
        return { ok=false, reason="throttled" }
    end
    self.Server._allocCooldown[player] = now

    local result = self.Server.SetComponent:AllocatePoints(player, statName, count)
    if result and result.ok then
        self.Server.Client.StatsChanged:Fire(player, result.snapshot)
    end
    return result
end

-- ========= Knit lifecycle =========
function StatService:KnitStart()
    -- Re-broadcast level/xp when ProfileService says so
    ProfileService.UpdateSpecificData:Connect(function(player, path, _)
        if not path or #path == 0 then return end
        if path[1] == "Level" or path[1] == "XP" then
            local data = _getData(player)
            if data then
                self.Client.LevelChanged:Fire(player, tonumber(data.Level) or 1, tonumber(data.XP) or 0)
            end
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
