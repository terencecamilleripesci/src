local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

---- Knit Services
local ProfileService

---- Others
local Validator

-- Server-authoritative hotbar slot update
function module:SetSlot(player: Player, slotIndex: number, id: string | nil)
	if typeof(player) ~= "Instance" then return { ok=false, reason="bad-player" } end
	if not Validator.ValidateSlot(slotIndex) then return { ok=false, reason="bad-slot" } end
	if not Validator.ValidateId(id) then return { ok=false, reason="bad-id" } end

	local profile, data = ProfileService:GetProfile(player)
	if not data then return { ok=false, reason="no-profile" } end

	-- Write
	data.Hotbar[slotIndex] = id
	-- Notify via ProfileService for client sync
	ProfileService:ChangeData(player, {"Hotbar", slotIndex}, id)

	return { ok = true, snapshot = { Hotbar = data.Hotbar } }
end

function module.Start()
	Validator = require(script.Parent.Others.Validator)
end

function module.Init()
	ProfileService = Knit.GetService("ProfileService")
end

return module
