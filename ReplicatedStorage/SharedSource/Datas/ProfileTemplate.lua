-- Legends Reborn Profile Template (v4.8.1 FINAL)
-- IMPORTANT: Client and server code rely on these tables existing.
-- NEVER remove keys; add new ones safely to avoid nil table access.

local ProfileTemplate = {
	Version = 1,

	Level = 1,
	XP = 0,
	UnspentPoints = 0,

	Stats = {
		Health = 100,
		Mana = 50,
		Stamina = 100,
		Strength = 10,
		Defense = 5,
	},

	-- Skill mastery per slot for Z/X/C/F/V
	Mastery = {
		Z = 0,
		X = 0,
		C = 0,
		F = 0,
		V = 0,
	},

	-- Per-skill EXP/levels, filled as skills are used
	SkillExp = {
		-- [skillId] = { Level = 0, Exp = 0 }
	},

	-- Owned Martial Arts sets (by id)
	MartialArts = {
		-- [id] = true
	},

	-- Inventory and Gear
	Inventory = {
		-- itemId strings
	},
	Gear = {
		Head = nil,
		Chest = nil,
		Boots = nil,
		Accessory = nil,
	},

	-- Hotbar assignments: 1=Martial Arts, 2=Weapons, 3=Internals, 4=Pets
	Hotbar = {
		[1] = nil, -- martial arts set id
		[2] = nil, -- weapon id
		[3] = nil, -- internal ability set id
		[4] = nil, -- pet ability set id (not summons)
	},

	-- Movement unlocks and persistent counts
	Movement = {
		ExtraJump = 1, -- default +1 extra jump
		DashLevel = 1, -- baseline dash level
	},

	-- Quest progress data structure
	Quests = {
		-- [questId] = { State = "active"|"completed", Progress = number }
	},
}

return ProfileTemplate
