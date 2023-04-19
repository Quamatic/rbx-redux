-- Polyfill
local function reduce<T>(
	arr: { T },
	callbackFn: (accumulator: T, currentValue: T, currentIndex: number, array: { T }) -> any,
	initialValue
)
	local result = initialValue or arr[1]

	for i = 2, #arr do
		result = callbackFn(result, arr[i], i - 1, arr)
	end

	return result
end

type Function<T..., R...> = (T...) -> R...
type ComposeFn<Funcs...> = (Funcs...) -> Function

-- Equivalent to Redux's `compose` function.
local function compose(...: Function): ComposeFn
	local funcs = { ... } :: { Function } & { n: number }
	local len = #funcs

	if len == 0 then
		return function<T>(arg: T)
			return arg
		end
	end

	if len == 1 then
		return funcs[1]
	end

	print(funcs)

	return reduce(funcs, function(a, b)
		return function(...)
			return a(b(...))
		end
	end)
end

return compose
