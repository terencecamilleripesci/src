local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = {}

-- Build a skill index by key (Z/X/C/F/V) using player's current Hotbar assignment.
-- Returns skill definition from ConfigPack.Skills[category][i] for matching key
function Catalog.GetSkillByKey(playerData, key)
	local cfg = require(ReplicatedStorage.Configs.ConfigPack)
	local hotbar = playerData.Hotbar or {}

	local slotKeyMap = { Z = 1, X = 1, C = 1, F = 1, V = 1 } -- category resolved below
	-- Determine category by hotbar slot mapping
	-- We use category sets per slot: 1=MartialArts, 2=Weapons, 3=Internals, 4=Pets
	local categoryBySlot = cfg and cfg.Hotbar and cfg.Hotbar.Slots or { [1]="MartialArts", [2]="Weapons", [3]="Internals", [4]="Pets" }

	-- For now, assume key maps to 'category selection' for slot 1 (MartialArts) and 3 (Internals) examples in config
	-- We'll search all categories for an entry matching the key
	for category, list in pairs(cfg.Skills or {}) do
		for _, def in ipairs(list) do
			if def.Key == key then
				return def, category
			end
		end
	end
	return nil
end

return Catalog
