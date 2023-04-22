local reduce = require(script.Parent.utils.reduce)

type Function<T..., R...> = (T...) -> R...
type ComposeFn<Funcs...> = (Funcs...) -> Function

-- Equivalent to Redux's `compose` function.
local function compose(...: Function): ComposeFn
	local funcs = { ... } :: { Function }
	local len = select("#", ...)

	if len == 0 then
		return function<T>(arg: T)
			return arg
		end
	end

	if len == 1 then
		return funcs[1]
	end

	return reduce(funcs, function(a, b)
		return function(...)
			return a(b(...))
		end
	end)
end

return compose
