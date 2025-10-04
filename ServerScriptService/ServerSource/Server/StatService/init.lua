-- ServerScriptService/ServerSource/Server/StatService/init.lua
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

-- Knit
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Service (NOTE: Name MUST be "StatService")
local StatService = Knit.CreateService({
    Name = "StatService",
    Client = {
        StatsChanged = Knit.CreateSignal(), -- (snapshot)
        LevelChanged = Knit.CreateSignal(), -- (level, xp)
    },
    _allocCooldown = {}, -- anti-spam
})

-- ------------- Safe requires / config ----------------
local function safeRequire(mod)
    local ok, res = pcall(require, mod)
    if not ok then
        warn(("[StatService] safeRequire failed for %s: %s"):format(tostring(mod), tostring(res)))
        return nil
    end
    return res
end

local ConfigsFolder = ReplicatedStorage:FindFirstChild("Configs")
local ConfigPack = ConfigsFolder and safeRequire(ConfigsFolder:FindFirstChild("ConfigPack")) or {}

local componentsInitializer = nil
do
    local utilPath = ReplicatedStorage:FindFirstChild("SharedSource")
        and ReplicatedStorage.SharedSource:FindFirstChild("Utilities")
        and ReplicatedStorage.SharedSource.Utilities:FindFirstChild("ScriptsLoader")
    if utilPath then
        componentsInitializer = safeRequire(utilPath:FindFirstChild("ComponentsInitializer"))
    end
end

local componentsFolder = script:FindFirstChild("Components")
local GetComponent = nil
local SetComponent = nil
do
    if componentsFolder then
        local others = componentsFolder:FindFirstChild("Others")
        if others then
            -- optional: preload others; not required
            for _, m in ipairs(others:GetChildren()) do
                safeRequire(m)
            end
        end
        GetComponent = safeRequire(componentsFolder:FindFirstChild("Get()"))
        SetComponent = safeRequire(componentsFolder:FindFirstChild("Set()"))
    end
end

-- Optional calculators
local StatCalculator = nil
local XPLevel        = nil
do
    local others = componentsFolder and componentsFolder:FindFirstChild("Others")
    if others then
        StatCalculator = safeRequire(others:FindFirstChild("StatCalculator"))
        XPLevel        = safeRequire(others:FindFirstChild("XPLevel"))
    end
end

-- ------------- Knit services we depend on ------------
local ProfileService -- set in KnitInit

-- ------------- Small helpers -------------------------
local function clamp(n, lo, hi)
    n = tonumber(n) or 0
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

local function getData(player)
    if not ProfileService then return nil end
    local _, data = ProfileService:GetProfile(player)
    return data
end

local function baseStats()
    local s = (ConfigPack.Stats and ConfigPack.Stats.Base) or {}
    return {
        Health   = tonumber(s.Health)   or 100,
        Mana     = tonumber(s.Mana)     or 50,
        Stamina  = tonumber(s.Stamina)  or 100,
        Strength = tonumber(s.Strength) or 0,
        Defense  = tonumber(s.Defense)  or 0,
    }
end

local function staminaPerPoint()
    return (ConfigPack.Stats and ConfigPack.Stats.PerPoint and tonumber(ConfigPack.Stats.PerPoint.Stamina)) or 0
end

-- ------------- Public read APIs ----------------------
function StatService:GetSnapshot(player)
    if GetComponent and GetComponent.GetSnapshot then
        local ok, snap = pcall(GetComponent.GetSnapshot, GetComponent, player)
        if ok and snap then return snap end
    end

    local data = getData(player) or {}
    local b = baseStats()
    local s = data.Stats or {}
    return {
        Level = data.Level,
        XP    = data.XP,
        Stats = {
            Health   = tonumber(s.Health)   or b.Health,
            Mana     = tonumber(s.Mana)     or b.Mana,
            Stamina  = tonumber(s.Stamina)  or b.Stamina,
            Strength = tonumber(s.Strength) or b.Strength,
            Defense  = tonumber(s.Defense)  or b.Defense,
            StaminaCurrent = tonumber(s.StaminaCurrent) or tonumber(s.Stamina) or b.Stamina,
        }
    }
end

function StatService:GetDerived(player)
    local data = getData(player) or {}
    if StatCalculator and StatCalculator.BuildDerived then
        local ok, derived = pcall(StatCalculator.BuildDerived, data.Stats or {}, ConfigPack)
        if ok and derived then return derived end
    end
    -- fallback: only MaxStamina
    local b = baseStats()
    local points = tonumber(data.Stats and data.Stats.Stamina) or 0
    local maxS = b.Stamina + points * staminaPerPoint()
    return { MaxStamina = maxS }
end

-- ------------- Stamina helpers (used by Jump/Dash) ---
function StatService:GetMaxStamina(player)
    local d = self:GetDerived(player)
    return tonumber(d and d.MaxStamina) or 0
end

function StatService:GetCurrentStamina(player)
    local data = getData(player)
    if not data then return 0 end
    local s = data.Stats or {}
    return tonumber(s.StaminaCurrent) or tonumber(s.Stamina) or baseStats().Stamina
end

function StatService:SetCurrentStamina(player, value)
    local data = getData(player)
    if not data then return false end
    local maxS = self:GetMaxStamina(player)
    local v = clamp(value, 0, maxS)
    data.Stats = data.Stats or {}
    data.Stats.StaminaCurrent = v
    ProfileService:ChangeData(player, {"Stats","StaminaCurrent"}, v)
    self.Client.StatsChanged:Fire(player, { Stats = { StaminaCurrent = v, StaminaMax = maxS }})
    return true
end

function StatService:HasStamina(player, cost)
    cost = tonumber(cost) or 0
    if cost <= 0 then return true, self:GetCurrentStamina(player) end
    local cur = self:GetCurrentStamina(player)
    return cur >= cost, cur
end

function StatService:SpendStamina(player, cost)
    cost = tonumber(cost) or 0
    if cost <= 0 then return true end
    local ok, cur = self:HasStamina(player, cost)
    if not ok then return false, cur end
    return self:SetCurrentStamina(player, cur - cost)
end

function StatService:AddStamina(player, amount)
    amount = tonumber(amount) or 0
    if amount == 0 then return self:GetCurrentStamina(player) end
    local cur = self:GetCurrentStamina(player)
    self:SetCurrentStamina(player, cur + amount)
    return self:GetCurrentStamina(player)
end

-- ------------- Points / XP (safe) --------------------
function StatService.Client:AllocatePoints(player, statName, count)
    local now = os.clock()
    local last = self.Server._allocCooldown[player]
    if last and (now - last) < 0.2 then
        return { ok=false, reason="throttled" }
    end
    self.Server._allocCooldown[player] = now

    if SetComponent and SetComponent.AllocatePoints then
        local ok, res = pcall(SetComponent.AllocatePoints, SetComponent, player, statName, count)
        if ok and res and res.ok then
            self.Server.Client.StatsChanged:Fire(player, res.snapshot)
            return res
        elseif ok and res then
            return res
        end
    end

    -- minimal fallback: just ACK (no-op)
    return { ok=false, reason="alloc-not-implemented" }
end

function StatService:AddXP(player, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return { ok=false, reason="bad-amount" } end
    local data = getData(player)
    if not data then return { ok=false, reason="no-profile" } end

    local level, xp, points = data.Level or 1, data.XP or 0, 0
    if XPLevel and XPLevel.Compute then
        local ok, L, X, P = pcall(XPLevel.Compute, level, xp, amount, ConfigPack)
        if ok then level, xp, points = L, X, P or 0 else xp = xp + amount end
    else
        -- simple fallback
        xp = xp + amount
    end

    ProfileService:ChangeData(player, {"Level"}, level)
    ProfileService:ChangeData(player, {"XP"}, xp)
    if points and points > 0 then
        ProfileService:ChangeData(player, {"UnspentPoints"}, (data.UnspentPoints or 0) + points)
    end
    self.Client.LevelChanged:Fire(player, level, xp)
    return { ok=true, level=level, xp=xp, pointsAwarded=points }
end

-- ------------- Knit lifecycle ------------------------
function StatService:KnitStart()
    -- Ensure staminaCurrent is set on join (no nil compares anywhere)
    Players.PlayerAdded:Connect(function(plr)
        task.defer(function()
            local data = getData(plr)
            if not data then return end
            data.Stats = data.Stats or {}
            if data.Stats.StaminaCurrent == nil then
                self:SetCurrentStamina(plr, self:GetMaxStamina(plr))
            end
        end)
    end)

    Players.PlayerRemoving:Connect(function(plr)
        self._allocCooldown[plr] = nil
    end)

    -- Optional rebroadcasts if ProfileService exposes them
    if ProfileService and ProfileService.UpdateSpecificData then
        ProfileService.UpdateSpecificData:Connect(function(player, path)
            if player and path and #path > 0 and (path[1] == "Level" or path[1] == "XP") then
                local d = getData(player)
                if d then self.Client.LevelChanged:Fire(player, d.Level, d.XP) end
            end
        end)
    end
end

function StatService:KnitInit()
    ProfileService = Knit.GetService("ProfileService")
    if componentsInitializer then
        componentsInitializer(script)
    end
end

return StatService
