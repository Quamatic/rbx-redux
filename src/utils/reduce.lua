type ReduceFn<T, U> = (previousValue: U, currentValue: T, currentIndex: number, array: { T }) -> U

local function reduce<T, U>(array: { T }, callback: ReduceFn<T, U>, initialValue: U?): U
	local length = #array

	local value: T | U
	local initial = 1

	if initialValue ~= nil then
		value = initialValue
	else
		initial = 2
		if length == 0 then
			error("reduce of empty array with no initial value")
		end
		value = array[1]
	end

	for i = initial, length do
		value = callback(value :: U, array[i], i, array)
	end

	return value :: U
end

return reduce
