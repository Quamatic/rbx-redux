-- Polyfill for JS's Array.isArray()
local function isArray(x: any): boolean
	if typeof(x) ~= "table" then
		return false
	end

	if next(x) == nil then
		return false
	end

	local length = #x

	if length == 0 then
		return false
	end

	local count = 0
	local sum = 0

	for key in x do
		if typeof(key) ~= "number" then
			return false
		end

		if key % 1 ~= 0 or key < 1 then
			return false
		end

		count += 1
		sum += key
	end

	return sum == (count * (count + 1) / 2)
end

return isArray
