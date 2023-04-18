local MiddlewareArray = {}
MiddlewareArray.__index = MiddlewareArray

function MiddlewareArray.new(...)
	return setmetatable({
		_middlewares = { ... },
	}, MiddlewareArray)
end

function MiddlewareArray:push(middleware)
	table.insert(self._middlewares, middleware)
end

function MiddlewareArray:concat(...: any) end

function MiddlewareArray:prepend(...: any)
	local args = table.pack(...)
	if args.n == 1 and #args[0] ~= 0 then
		return MiddlewareArray.new(table.concat(args[0]))
	end

	return MiddlewareArray.new(table.concat(self))
end

export type MiddlewareArray = typeof(MiddlewareArray.new())

return MiddlewareArray
