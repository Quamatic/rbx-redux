local isArray = require(script.Parent.isArray)

local MiddlewareArray = {}
MiddlewareArray.__index = MiddlewareArray

-- TODO: Move this to util, and change the way it works... super inefficient right now
local function jsConcat(t: table, ...)
	return { unpack(t), ... }
end

function MiddlewareArray.new(...)
	return setmetatable({ ... }, MiddlewareArray)
end

function MiddlewareArray:concat(...: any)
	return jsConcat(self, ...)
end

function MiddlewareArray:prepend(...: any)
	local args = { ... }

	if #args == 1 and isArray(args[1]) then
		return MiddlewareArray.new(jsConcat(args[1]))
	end

	return MiddlewareArray.new(jsConcat(args, self))
end

export type MiddlewareArray = typeof(MiddlewareArray.new())

return MiddlewareArray
