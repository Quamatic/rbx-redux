local merge = require(script.Parent.merge)

local MiddlewareArray = require(script.Parent.utils.MiddlewareArray)
type MiddlewareArray = MiddlewareArray.MiddlewareArray

-- Same as Redux importing from 'redux-thunk'
local thunkMiddleware = require(script.Parent.thunk)
local createImmutableStateInvariantMiddleware =
	require(script.Parent.immutableStateInvariantMiddleware).immutableStateInvariantMiddleware

local function isBoolean(x: any)
	return typeof(x) == "boolean"
end

type ThunkOptions<E = any> = {
	extraArgument: E,
}

type GetDefaultMiddlewareOptions = {
	thunk: boolean | ThunkOptions<any>?,
	immutableCheck: boolean,
	serializableCheck: boolean,
}

-- This type is unused because Luau cannot extend nor infer types
type ThunkMiddlewareFor = {}

-- Redux does a Partial cast on this type, but thats not possible with Luau
export type CurriedGetDefaultMiddleware = (options: GetDefaultMiddlewareOptions) -> MiddlewareArray

local defaultMiddlewareOptions: GetDefaultMiddlewareOptions = {
	thunk = true,
	immutableCheck = true,
	serializableCheck = true,
}

local function getDefaultMiddleware(options: GetDefaultMiddlewareOptions?): MiddlewareArray
	options = merge(defaultMiddlewareOptions, options or {})

	local thunk, immutableCheck, serializableCheck = options.thunk, options.immutableCheck, options.serializableCheck
	local middlewareArray = MiddlewareArray.new()

	if thunk then
		if isBoolean(thunk) then
			table.insert(middlewareArray, thunkMiddleware.thunk)
		else
			table.insert(middlewareArray, thunkMiddleware.withExtraArgument(thunk.extraArgument))
		end
	end

	if getfenv().production then
		if immutableCheck then
			local immutableOptions = {}

			if not isBoolean(immutableCheck) then
				immutableOptions = immutableCheck
			end

			table.insert(immutableOptions, 1, createImmutableStateInvariantMiddleware(immutableOptions))
		end

		if serializableCheck then
			-- TODO
			warn("serializableCheck is not currently implemented")
		end
	end

	return middlewareArray :: any
end

local function curryGetDefaultMiddleware<S>(): CurriedGetDefaultMiddleware
	return function(options: GetDefaultMiddlewareOptions)
		return getDefaultMiddleware(options)
	end
end

return {
	getDefaultMiddleware = getDefaultMiddleware,
	curryGetDefaultMiddleware = curryGetDefaultMiddleware,
}
