local isArray = require(script.Parent.isArray)

local EnhancerArray = {}
EnhancerArray.__index = EnhancerArray

local function jsConcat(t: table, ...)
	return { unpack(t), ... }
end

-- Redux directly exists off of the Array class, but we cant do that.
function EnhancerArray.new(...): EnhancerArray
	return setmetatable({
		_enhancers = { ... },
	}, EnhancerArray)
end

function EnhancerArray:concat(...)
	-- Change: JS has table concatenation with other tables, but Luau does not.
	-- This does the same thing.
	return jsConcat(self._enhancers, ...)
end

function EnhancerArray:prepend(...)
	local args = table.pack(...)

	if args.n == 1 and isArray(args[0]) then
		return EnhancerArray.new(jsConcat(args[0], self._enhancers))
	end

	return EnhancerArray.new(jsConcat(args, self._enhancers))
end

export type EnhancerArray = typeof(EnhancerArray.new())

return EnhancerArray