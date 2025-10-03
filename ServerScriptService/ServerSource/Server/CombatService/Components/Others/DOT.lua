local DOT = {}

-- deb = { DOT=10, Duration=6, Type="Magical"|"Physical", Tick=1 }
function DOT.Run(attacker, defender, deb, applyFn)
	local tickTime = deb.Tick or 1
	local remaining = deb.Duration or 0
	while remaining > 0 do
		remaining -= tickTime
		local base = deb.DOT or 0
		local dtype = deb.Type or "Physical"
		local result = applyFn(attacker, defender, base, dtype)
		if not (result and result.ok) then
			break
		end
		task.wait(tickTime)
	end
end

return DOT
