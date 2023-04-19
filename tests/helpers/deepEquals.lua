local function deepEquals(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end

	for k in pairs(a) do
		local av = a[k]
		local bv = b[k]

		if type(av) == "table" and type(bv) == "table" then
			local result = deepEquals(av, bv)
			if not result then
				return false
			end
		elseif av ~= bv then
			return false
		end
	end

	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end

	return true
end

return deepEquals
