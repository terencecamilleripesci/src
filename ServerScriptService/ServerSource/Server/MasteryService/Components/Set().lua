local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

---- Knit Services
local ProfileService

---- Others
local Tracker

---- Config
local ConfigPack = require(ReplicatedStorage.Configs.ConfigPack)

-- Server-authoritative add kill credit
function module:AddKillCredit(player: Player, slotKey: string, kind: string?)
	if typeof(player) ~= "Instance" or type(slotKey) ~= "string" then
		return { ok=false, reason="bad-args" }
	end
	local profile, data = ProfileService:GetProfile(player)
	if not data then return { ok=false, reason="no-profile" } end

	local newValue, unlocked = Tracker.AddKillCredit(data, slotKey, kind, ConfigPack)
	-- Notify specific data change
	ProfileService:ChangeData(player, {"Mastery", slotKey}, newValue)
	if unlocked then
		local master = require(script.Parent.Parent) -- MasteryService module table
		master.Client.SlotUnlocked:Fire(player, slotKey)
	end
	return { ok=true, value=newValue, unlocked=unlocked }
end

function module.Start()
	Tracker = require(script.Parent.Others.Tracker)
end

function module.Init()
	ProfileService = Knit.GetService("ProfileService")
end

return module
