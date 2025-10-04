local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local JumpService = Knit.CreateService({
    Name = "JumpService",
    Client = {
        Jumped = Knit.CreateSignal(), -- optional hint to client FX
        Dashed = Knit.CreateSignal(),
    },
})

-- deps (resolved in KnitInit)
local StatService

-- runtime state
local _cooldowns = {}  -- [player] = { dash = t }
local _jumpState = {}  -- [player] = { max = n, left = n }
local _config     -- cached ConfigPack.Movement

local function safeRequire(mod)
    local ok, res = pcall(require, mod)
    if ok then return res end
    warn("[JumpService] require failed:", mod, res)
    return nil
end

local function getMovementCfg()
    if _config then return _config end
    local cfgFolder = ReplicatedStorage:FindFirstChild("Configs")
    local pack = cfgFolder and safeRequire(cfgFolder:FindFirstChild("ConfigPack")) or {}
    local mv = pack.Movement or {}

    mv.DoubleJump = mv.DoubleJump or { BaseJumps = 1, ExtraJump = 1, StaminaCost = 25 }
    mv.Dash       = mv.Dash       or { Speed = 50, StaminaCost = 20, Cooldown = 0.25 }

    _config = mv
    return _config
end

function JumpService:_ensureCooldown(p)
    _cooldowns[p] = _cooldowns[p] or { dash = 0 }
    return _cooldowns[p]
end

function JumpService:_recalcJumps(p)
    local mv = getMovementCfg()
    local base  = tonumber(mv.DoubleJump.BaseJumps) or 1
    local extra = tonumber(mv.DoubleJump.ExtraJump) or 0

    -- if StatService ever exposes ExtraJump, add it:
    local derived = StatService and StatService:GetDerived(p)
    if derived and tonumber(derived.ExtraJump) then
        extra = extra + tonumber(derived.ExtraJump)
    end

    local max = math.max(1, base + extra)
    _jumpState[p] = { max = max, left = max }
end

function JumpService:ResetJumps(p)
    if not _jumpState[p] then self:_recalcJumps(p) end
    _jumpState[p].left = _jumpState[p].max
end

-- ---------- server handlers ----------
function JumpService:_handleJump(p)
    if not _jumpState[p] then self:_recalcJumps(p) end
    local st = _jumpState[p]
    if st.left <= 0 then
        return { ok = false, reason = "no-jumps" }
    end

    local cost = tonumber(getMovementCfg().DoubleJump.StaminaCost) or 0
    if cost > 0 then
        local ok = StatService and StatService:SpendStamina(p, cost)
        if not ok then
            return { ok = false, reason = "not-enough-stamina" }
        end
    end

    st.left -= 1
    self.Client.Jumped:Fire(p)
    return { ok = true, jumpsLeft = st.left }
end

function JumpService:_handleDash(p)
    local cd = self:_ensureCooldown(p)
    local now = os.clock()

    local mv = getMovementCfg().Dash
    local dashCD   = tonumber(mv.Cooldown) or 0.25
    local dashCost = tonumber(mv.StaminaCost) or 0

    if cd.dash > now then
        return { ok = false, reason = "cooldown", readyIn = cd.dash - now }
    end

    if dashCost > 0 then
        local ok = StatService and StatService:SpendStamina(p, dashCost)
        if not ok then
            return { ok = false, reason = "not-enough-stamina" }
        end
    end

    cd.dash = now + dashCD
    self.Client.Dashed:Fire(p)
    return { ok = true, cooldown = dashCD }
end

-- ---------- client-callable methods ----------
function JumpService.Client:JumpRequest(player)
    return self.Server:_handleJump(player)
end

function JumpService.Client:DashRequest(player)
    return self.Server:_handleDash(player)
end

function JumpService.Client:ResetJumps(player)
    self.Server:ResetJumps(player)
    return true
end

-- ---------- knit lifecycle ----------
function JumpService:KnitInit()
    StatService = Knit.GetService("StatService") -- name MUST match your service folder
end

function JumpService:KnitStart()
    Players.PlayerAdded:Connect(function(p)
        task.defer(function() self:_recalcJumps(p) end)
    end)
    Players.PlayerRemoving:Connect(function(p)
        _cooldowns[p] = nil
        _jumpState[p] = nil
    end)
end

return JumpService
