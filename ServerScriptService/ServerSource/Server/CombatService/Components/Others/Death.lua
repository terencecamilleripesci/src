local Death = {}

function Death.Handle(player: Player, ConfigPack, ProfileService)
	local respawn = (ConfigPack and ConfigPack.Death and ConfigPack.Death.RespawnTime) or 5
	local xpLossPct = (ConfigPack and ConfigPack.Death and ConfigPack.Death.ExpLossPct) or 0.05
	-- Apply XP penalty
	local profile, data = ProfileService:GetProfile(player)
	if data then
		local lost = math.floor((data.XP or 0) * xpLossPct)
		ProfileService:ChangeData(player, {"XP"}, math.max(0, (data.XP or 0) - lost))
	end
	-- Respawn timer
	task.delay(respawn, function()
		-- Character will auto-respawn by Roblox; here we can reset runtime states if CombatService exposes setter
		-- Leave state resets to CombatService
	end)
end

return Death
