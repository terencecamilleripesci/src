-- #############################################################
-- 📦 Legends Reborn - ConfigPack.lua (v4.8.1 FINAL)
-- #############################################################

local Config = {}

-- =========================
-- ⚔️ STATS
-- =========================
Config.Stats = {
    DEF_MULTIPLIER = 0.001,   -- 0.1% reduction per Defense
    STR_MULTIPLIER = 0.002,   -- 0.2% damage per Strength
    DEF_CAP = 0.75,           -- 75% max reduction
    STAT_POINTS_PER_LEVEL = 2,

    Base = { Health=100, Mana=50, Stamina=100, Strength=0, Defense=0 },

    Caps = { HealthMax=9999, ManaMax=9999, StaminaMax=9999, StrengthMax=2000, DefenseMax=2000 },

    Allocatable = { Health=true, Mana=true, Stamina=true, Strength=true, Defense=true },

    PerPoint = { Health=5, Mana=5, Stamina=5 },

    Regen = {
        Enabled = true,
        InCombat  = { ManaPerSec=0.5, StaminaPerSec=2 },
        OutCombat = { ManaPerSec=2,   StaminaPerSec=8 }
    },

    UseMagicResist = false,
    MAG_DEF_MULTIPLIER = 0.001,
    MagicResistCap = 0.75
}

-- =========================
-- 📊 XP / LEVEL
-- =========================
Config.XP = {
    ExpFormula = function(level) return level * 100 end
}

-- =========================
-- 🥋 MASTERY
-- =========================
Config.Mastery = {
    ExpPerKill = { Normal=15, Strong=25, Boss=150 },
    Unlocks = { Z=25, X=50, C=150, F=250, V=420 }
}

-- =========================
-- 🎯 SKILL EXP
-- =========================
Config.SkillExp = {
    ExpPerUse = 5,
    ExpPerStrongEnemy = 10,
    ExpFormula = function(level) return 50 * level end,
    MaxSkillLevel = 10
}

-- =========================
-- 🔪 WEAPONS
-- =========================
Config.Weapons = {
    IronSword = {
        Name = "Iron Sword",
        BaseDamage = 20,
        ScalesWith = "Strength",
        ScaleMultiplier = Config.Stats.STR_MULTIPLIER,
        BonusStats = { Strength = 5 },
        Rarity = "Common"
    }
}

-- =========================
-- 🗡️ SKILLS (examples)
-- =========================
Config.Skills = {
    KungFu = {
        { Key="Z", Type="Physical", MasteryReq=25,  Name="Palm Strike",  BaseDamage=25, Cost={Stamina=10}, Cooldown=2, Flags={ CanParry=true }, AnimationId="rbxassetid://000010", SoundId="rbxassetid://1234566" },
        { Key="X", Type="Physical", MasteryReq=50,  Name="Flying Kick",  BaseDamage=40, Cost={Stamina=20}, Cooldown=5, Flags={ ParryBreak=true }, AnimationId="rbxassetid://000011", SoundId="rbxassetid://1234567" },
        { Key="C", Type="Buff",     MasteryReq=150, Name="Iron Guard",   Buff={Defense=0.2}, Duration=5, Cooldown=15 },
        { Key="F", Type="Physical", MasteryReq=250, Name="Dragon Combo", BaseDamage=50, Cost={Stamina=40}, Cooldown=15 },
        { Key="V", Type="Physical", MasteryReq=420, Name="Heaven’s Fist",BaseDamage=100,Cost={Stamina=60}, Cooldown=30 }
    },
    FireInternal = {
        { Key="Z", Type="Magical",  MasteryReq=25,  Name="Fire Bolt",    BaseDamage=18, Cost={Mana=15}, Cooldown=3 },
        { Key="C", Type="Debuff",   MasteryReq=150, Name="Burning Aura", Debuff="Burn", Duration=6, Cost={Mana=35}, Cooldown=18 }
    }
}

-- =========================
-- 🎒 HOTBAR
-- =========================
Config.Hotbar = {
    Slots = { [1] = "MartialArts", [2] = "Weapons", [3] = "Internals", [4] = "Pets" },
    MaxSlots = 4
}

-- =========================
-- 👕 GEAR (examples)
-- =========================
Config.Gear = {
    Slots = { "Head", "Chest", "Boots", "Accessory" },
    Items = {
        WindBoots = { Slot = "Boots", Name = "Wind Boots", Modifiers = { MaxStamina = 20, ExtraJump = 1, DashRangePct = 0.10 } },
        IronHelm  = { Slot = "Head",  Name = "Iron Helm",  Modifiers = { Defense = 10, MaxHealth = 25 } }
    }
}

-- =========================
-- 🏃 MOVEMENT
-- =========================
Config.Movement = {
    DoubleJump = { BaseJumps = 1, ExtraJump = 1, StaminaCost = 25, Unlockable = true },
    Dash       = { Speed = 50, StaminaCost = 20, Unlockable = true, Cooldown = nil }
}

-- =========================
-- 🎲 CRIT
-- =========================
Config.Crit = {
    DefaultChance = 0.05,
    DefaultMultiplier = 1.5
}

-- =========================
-- 🧪 DAMAGE TYPES
-- =========================
Config.DamageTypes = {
    Physical = { StatScale = "Strength", Multiplier = Config.Stats.STR_MULTIPLIER, MitigationStat = "Defense", MitigationMultiplier = Config.Stats.DEF_MULTIPLIER, Cap = Config.Stats.DEF_CAP },
    Magical  = { StatScale = "Mana",     Multiplier = 0.0025, MitigationStat = (Config.Stats.UseMagicResist and "MagicResist" or "Defense"), MitigationMultiplier = (Config.Stats.UseMagicResist and Config.Stats.MAG_DEF_MULTIPLIER or Config.Stats.DEF_MULTIPLIER), Cap = (Config.Stats.UseMagicResist and Config.Stats.MagicResistCap or Config.Stats.DEF_CAP) }
}

-- =========================
-- 🛡️ BUFFS & ☠️ DEBUFFS
-- =========================
Config.Buffs = {
    IronGuard = { DefenseBoost = 0.2, Duration = 5 }
}

Config.Debuffs = {
    Burn  = { DOT = 10, Duration = 6,  Type = "Magical",  Tick = 1 },
    Bleed = { DOT = 5,  Duration = 10, Type = "Physical", Tick = 1 },
    Stun  = { DisableInput = true, Duration = 2 },
    Slow  = { SpeedMult = 0.5, Duration = 4 }
}

-- =========================
-- 🔒 COMBAT LOCK-ON
-- =========================
Config.CombatMode = {
    LockOnKey    = Enum.KeyCode.Tab,
    MaxLockRange = 50,
    OutlineColor = Color3.fromRGB(128,128,128),
    ShowHPBar    = true
}

-- =========================
-- 💀 DEATH HANDLING
-- =========================
Config.Death = {
    RespawnTime = 5,
    ExpLossPct  = 0.05,
    DropItems   = false
}

-- =========================
-- 📜 QUESTS
-- =========================
Config.Quests = {
    Example = { Type = "Kill", Target = "Bandit", Amount = 10, Reward = { XP = 100, Gold = 50, Item = "WindBoots" } }
}

-- =========================
-- 🥋 MARTIAL ARTS
-- =========================
Config.MartialArts = {
    KungFu = {
        Basic = {
            Combo = {
                { AnimId = "rbxassetid://000001", SoundId = "rbxassetid://1234561", Damage = 10, StaminaCost = 5,  Windup = 0.15, Recovery = 0.2 },
                { AnimId = "rbxassetid://000002", SoundId = "rbxassetid://1234561", Damage = 12, StaminaCost = 5,  Windup = 0.15, Recovery = 0.25 },
                { AnimId = "rbxassetid://000003", SoundId = "rbxassetid://1234562", Damage = 18, StaminaCost = 8,  Windup = 0.2,  Recovery = 0.35, Finisher = true }
            },
            CooldownBetweenChains = 0.8,
            MaxChainWindow = 0.55,
            Hitbox = "NearestInFrontCone",
            Range = 8,
            ConeDeg = 60
        },
        Parry = {
            StanceAnimId = "rbxassetid://KungFu_ParryStance",
            StanceSoundId = "rbxassetid://1234563",
            PvPReduction = 0.8,
            PvEReduction = 0.9,
            BreakStunSeconds = 1.0,
            ParryHitSoundId = "rbxassetid://1234564",
            ParryBreakSoundId = "rbxassetid://1234565"
        }
    }
}

-- =========================
-- 🔊 AUDIO
-- =========================
Config.Audio = {
    DefaultSFXVolume = 0.7,
    UseSoundGroups = true
}

Config.Sounds = {
    ComboLight = "rbxassetid://1234561",
    ComboHeavy = "rbxassetid://1234562",
    ParryStanceLoop = "rbxassetid://1234563",
    ParryHit = "rbxassetid://1234564",
    ParryBreak = "rbxassetid://1234565",
    PalmStrike = "rbxassetid://1234566",
    FlyingKick = "rbxassetid://1234567",
    Dash = "rbxassetid://1234568",
    Jump = "rbxassetid://1234569",
    HitImpact = "rbxassetid://1234570"
}

-- =========================
-- 👑 ADMIN
-- =========================
Config.Admin = { Whitelist = { } }

return Config
