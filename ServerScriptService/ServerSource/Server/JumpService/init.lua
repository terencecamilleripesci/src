local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit   = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Configs.ConfigPack)

local JumpService = Knit.CreateService({
    Name = "JumpService",
    Client = {
        Jumped = Knit.CreateSignal(),
        Dashed = Knit.CreateSignal(),
    },
})

-- other services (resolved in KnitInit)
local ProfileService
local StatService -- optional

-- per-player runtime state
local State = {} -- [player] = { used = 0, lastDash = 0 }

local function ensureState(plr)
    local s = State[plr]
    if not s then s = { used = 0, lastDash = 0 }; State[plr] = s end
    return s
end

local function getMaxJumps(plr)
    local base  = (Config.Movement.DoubleJump and Config.Movement.DoubleJump.BaseJumps) or 1
    local extra = (Config.Movement.DoubleJump and Config.Movement.DoubleJump.ExtraJump) or 0

    -- (optional) read extra from saved gear if you track it in profile data
    local _, data = ProfileService:GetProfile(plr)
    if data and data.Gear and data.Gear.Modifiers and tonumber(data.Gear.Modifiers.ExtraJump) then
        extra += data.Gear.Modifiers.ExtraJump
    end
    return math.max(1, base + extra)
end

local function hasStamina(plr, cost)
    cost = tonumber(cost) or 0
    if cost <= 0 then return true end

    if StatService and StatService.HasStamina then
        local ok, res = pcall(function() return StatService:HasStamina(plr, cost) end)
        if ok then return res end
    end

    local _, data = ProfileService:GetProfile(plr)
    local cur = (data and data.Stats and tonumber(data.Stats.Stamina)) or 0
    return cur >= cost
end

local function spendStamina(plr, cost)
    cost = tonumber(cost) or 0
    if cost <= 0 then return true end

    if StatService and StatService.SpendStamina then
        local ok, res = pcall(function() return StatService:SpendStamina(plr, cost) end)
        if ok and res then return true end
    end

    local profile, data = ProfileService:GetProfile(plr)
    if not data then return false end
    local cur = (data.Stats and tonumber(data.Stats.Stamina)) or 0
    if cur < cost then return false end
    data.Stats.Stamina = cur - cost
    ProfileService:ChangeData(plr, {"Stats","Stamina"}, data.Stats.Stamina)
    return true
end

-- ===== Client-callable API =====
function JumpService.Client:ResetJumps(plr)
    ensureState(plr).used = 0
    return true
end

function JumpService.Client:JumpRequest(plr)
    local s = ensureState(plr)
    local char = plr.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return { ok=false, reason="no-humanoid" } end

    -- grounded -> reset chain
    if hum.FloorMaterial ~= Enum.Material.Air then s.used = 0 end

    local max = getMaxJumps(plr)
    if s.used >= max then
        return { ok=false, reason="no-jumps" }
    end

    local cost = (Config.Movement.DoubleJump and Config.Movement.DoubleJump.StaminaCost) or 0
    if s.used > 0 and cost > 0 then
        if not hasStamina(plr, cost) then
            return { ok=false, reason="stamina" }
        end
        spendStamina(plr, cost)
    end

    s.used += 1

    -- small server nudge
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        hrp.AssemblyLinearVelocity += Vector3.new(0, 35, 0)
    end

    JumpService.Client.Jumped:Fire(plr)
    return { ok = true }
end

function JumpService.Client:DashRequest(plr)
    local s = ensureState(plr)
    local now = os.clock()
    local cfg = Config.Movement.Dash or {}
    local cd  = tonumber(cfg.Cooldown) or 0

    if cd > 0 and s.lastDash and (now - s.lastDash) < cd then
        return { ok=false, reason="cooldown" }
    end

    local cost = tonumber(cfg.StaminaCost) or 0
    if cost > 0 then
        if not hasStamina(plr, cost) then return { ok=false, reason="stamina" } end
        spendStamina(plr, cost)
    end

    s.lastDash = now

    local char = plr.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hrp and hum then
        local dir = hum.MoveDirection
        if dir.Magnitude < 0.1 and hrp.CFrame then dir = hrp.CFrame.LookVector end
        local strength = tonumber(cfg.Speed) or 50
        hrp.AssemblyLinearVelocity = Vector3.new(dir.X*strength, hrp.AssemblyLinearVelocity.Y, dir.Z*strength)
    end

    JumpService.Client.Dashed:Fire(plr)
    return { ok = true }
end

-- ===== Knit wiring =====
function JumpService:KnitStart()
    Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function(char)
            local hum = char:WaitForChild("Humanoid", 10)
            if hum then
                hum.StateChanged:Connect(function(_, new)
                    if new == Enum.HumanoidStateType.Running
                    or new == Enum.HumanoidStateType.RunningNoPhysics
                    or new == Enum.HumanoidStateType.Landed then
                        ensureState(plr).used = 0
                    end
                end)
            end
        end)
    end)

    Players.PlayerRemoving:Connect(function(plr)
        State[plr] = nil
    end)
end

function JumpService:KnitInit()
    ProfileService = Knit.GetService("ProfileService")
    local ok, svc = pcall(function() return Knit.GetService("StatService") end)
    if ok then StatService = svc end
end

return JumpService
