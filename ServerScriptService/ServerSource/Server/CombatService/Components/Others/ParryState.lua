local ParryState = {}

local STATE = {}

function ParryState.Set(player: Player, active: boolean)
	STATE[player] = active and true or nil
end

function ParryState.IsActive(player: Player)
	return STATE[player] and true or false
end

function ParryState.Clear(player: Player)
	STATE[player] = nil
end

return ParryState
