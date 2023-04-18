-- Polyfill
local function reduce<T>(
	arr: { T },
	callbackFn: (accumulator: T, currentValue: T, currentIndex: number, array: { T }) -> any,
	initialValue
)
	local result = initialValue

	for index, value in arr do
		result = callbackFn(result, value, index, arr)
	end

	return result
end

type Function<T..., R...> = (T...) -> R...
type ComposeFn<Funcs...> = (Funcs...) -> Function

-- Equivalent to Redux's `compose` function.
local function compose(...: Function): ComposeFn
	local funcs = table.pack(...) :: { Function } & { n: number }

	if funcs.n == 0 then
		return function<T>(arg: T)
			return arg
		end
	elseif funcs.n == 1 then
		return funcs[0]
	end

	return reduce(funcs, function(a, b)
		return function(...)
			return a(b(...))
		end
	end)
end

return compose
