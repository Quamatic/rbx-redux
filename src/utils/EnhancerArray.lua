local isArray = require(script.Parent.isArray)
local concat = require(script.Parent.concat)

local EnhancerArray = {}
EnhancerArray.__index = EnhancerArray

-- Redux directly exists off of the Array class, but we cant do that.
function EnhancerArray.new(...): EnhancerArray
	return setmetatable({ ... }, EnhancerArray)
end

function EnhancerArray:concat(...)
	-- Change: JS has table concatenation with other tables, but Luau does not.
	-- This does the same thing.
	return concat(self, ...)
end

function EnhancerArray:prepend(...)
	local args, length = { ... }, select("#", ...)

	if length == 1 and isArray(args[1]) then
		return EnhancerArray.new(unpack(concat(args[1], self)))
	end

	return EnhancerArray.new(unpack(concat(args, self)))
end

export type EnhancerArray = typeof(EnhancerArray.new())

return EnhancerArray
