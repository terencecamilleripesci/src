local Validator = {}

function Validator.ValidateSlot(slotIndex)
	return type(slotIndex) == "number" and slotIndex >= 1 and slotIndex <= 4
end

function Validator.ValidateId(id)
	if id == nil then return true end
	return type(id) == "string" and #id > 0 and #id <= 64
end

return Validator
