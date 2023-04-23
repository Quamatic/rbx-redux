local isArray = require(script.Parent.isArray)
local concat = require(script.Parent.concat)

local MiddlewareArray = {}
MiddlewareArray.__index = MiddlewareArray

function MiddlewareArray.new(...)
	return setmetatable({ ... }, MiddlewareArray)
end

function MiddlewareArray:concat(...: any)
	return MiddlewareArray.new(unpack(concat(self, ...)))
end

function MiddlewareArray:prepend(...: any)
	local args, length = { ... }, select("#", ...)

	if length == 1 and isArray(args[1]) then
		return MiddlewareArray.new(unpack(concat(args[1], self)))
	end

	return MiddlewareArray.new(unpack(concat(args, self)))
end

export type MiddlewareArray = typeof(MiddlewareArray.new())

return MiddlewareArray
