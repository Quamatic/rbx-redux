local isArray = require(script.Parent.isArray)

local MiddlewareArray = {}
MiddlewareArray.__index = MiddlewareArray

function MiddlewareArray.new(...)
	return setmetatable({ ... }, MiddlewareArray)
end

function MiddlewareArray:concat(...: any) end

function MiddlewareArray:prepend(...: any)
	local args = { ... }

	if #args == 1 and isArray(args[1]) then
		return MiddlewareArray.new(table.concat(args[1]))
	end

	return MiddlewareArray.new(table.concat(self))
end

export type MiddlewareArray = typeof(MiddlewareArray.new())

return MiddlewareArray
