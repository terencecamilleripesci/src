local Adapter = {}

-- Shallow merge utility
local function merge(into, from)
	for k,v in pairs(from) do
		into[k] = v
	end
	return into
end

function Adapter.ApplyMutator(data, mutator)
	if type(mutator) == "function" then
		local patch = mutator(data) -- mutator may return a table of changes (optional)
		if type(patch) == "table" then
			merge(data, patch)
		end
	end
end

return Adapter
