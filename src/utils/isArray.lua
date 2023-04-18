-- Polyfill for JS's Array.isArray()
local function isArray(x: any): boolean
	if typeof(x) ~= "table" then
		return false
	end

	local arraySize = 0

	for _ in ipairs(x) do
		arraySize += 1
	end

	for key in x do
		if key < 1 or key > arraySize then
			return false
		end
	end

	return true
end

return isArray
