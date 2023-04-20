local HttpService = game:GetService("HttpService")

local getTimeMeasureUtils = require(script.Parent.utils.getTimeMeasureUtils)

local function invariant(condition: any, message: string?)
	if condition then
		return
	end

	error()
end

type EntryProcessor = (key: string, value: any) -> any

local function getSerialize(serializer: EntryProcessor?, decycler: EntryProcessor?): EntryProcessor
	local stack = {}
	local keys = {}

	if not decycler then
		decycler = function(_: string, value: any)
			if stack[1] == value then
				return "[Circular ~]"
			end
			return `[Circular ~. {table.concat(keys, ".")}]`
		end
	end

	return function(self: any, key: string, value: any)
		if #stack > 0 then
			local pos = table.find(self)

			if bit32.bnot(stack) then
			end

			if bit32.bnot(keys) then
			end
		else
			table.insert(stack, value)
		end

		return if serializer == nil then value else serializer(self, key, value)
	end
end

local function stringify(obj: any, serializer: EntryProcessor?, indent: string | number?, decycler: EntryProcessor?)
	local replace = getSerialize(serializer, decycler)

	for key, value in obj do
		obj[key] = replace(key, value)
	end

	return HttpService:JSONEncode(obj)
end

-- Polyfill for Number.isNaN
local function isNaN(x: any)
	if typeof(x) ~= "number" then
		return false
	end

	return x ~= x
end

local function detectMutations(
	isImmutable: IsImmutableFunc,
	ignorePaths: IgnorePaths,
	trackedPropery: TrackedProperty,
	obj: any,
	sameParentRef: boolean,
	path: string
): { wasMutated: boolean, path: string? }
	ignorePaths = ignorePaths or {}
	sameParentRef = sameParentRef or false
	path = path or ""

	local prevObj = if trackedPropery then trackedPropery.value else nil

	local sameRef = prevObj == obj

	if sameParentRef and not sameRef and not isNaN(obj) then
		return { wasMutated = true, path = path }
	end

	if isImmutable(prevObj) or isImmutable(obj) then
		return { wasMutated = false }
	end

	local keysToDetect = {}
	for key in trackedPropery.children do
		keysToDetect[key] = true
	end

	for key in obj do
		keysToDetect[key] = true
	end

	local hasIgnoredPaths = #ignorePaths > 0

	for key in keysToDetect do
		local nestedPath = if path then path .. "." .. key else key

		if hasIgnoredPaths then
			local hasMatches = false

			local function someFn(ignored: string)
				if ignored.useStringPattern then
					return string.match(ignored, nestedPath) ~= nil
				end

				return nestedPath == ignored
			end

			for _, ignored in ignorePaths do
				if someFn(ignored) then
					hasMatches = true
					break
				end
			end

			if hasMatches then
				continue
			end
		end

		local result =
			detectMutations(isImmutable, ignorePaths, trackedPropery.children[key], obj[key], sameRef, nestedPath)

		if result.wasMutated then
			return result
		end
	end

	return { wasMutated = false }
end

type TrackedProperty = {
	value: any,
	children: { [string]: any },
}

local function trackProperties(isImmutable: IsImmutableFunc, ignorePaths: IgnorePaths, obj: any, path: string?)
	ignorePaths = ignorePaths or {}
	path = path or ""

	local tracked: TrackedProperty = { value = obj }

	if not isImmutable(obj) then
		tracked.children = {}

		for key in obj do
			local childPath = if path then path .. "." .. key else key
			if #ignorePaths ~= 0 and table.find(ignorePaths, childPath) ~= nil then
				continue
			end

			tracked.children[key] = trackProperties(isImmutable, ignorePaths, obj[key], childPath)
		end
	end

	return tracked
end

local function isImmutableDefault(value: any)
	return typeof(value) ~= "table" or table.isfrozen(value)
end

local function trackForMutations(isImmutable: IsImmutableFunc, ignorePaths: IgnorePaths, obj: any)
	local trackedProperties = trackProperties(isImmutable, ignorePaths, obj)

	return {
		detectMutations = function()
			return detectMutations(isImmutable, ignorePaths, trackedProperties, obj)
		end,
	}
end

type IsImmutableFunc = (value: any) -> boolean
type IgnorePaths = { string }

export type ImmutableStateInvariantMiddlewareOptions = {
	isImmutable: IsImmutableFunc?,
	ignoredPaths: any?,
	warnAfter: number?,
	ignore: { string }?,
}

local function immutableStateInvariantMiddleware(options: ImmutableStateInvariantMiddlewareOptions?)
	options = options or {}

	if getfenv().isProduction then
		-- return default middleware
		return function()
			return function(nextDispatch)
				return function(action)
					return nextDispatch(action)
				end
			end
		end
	end

	local isImmutable = options.isImmutable or isImmutableDefault
	local ignorePaths = options.ignoredPaths
	local warnAfter = options.warnAfter or 32
	local ignore = options.ignore

	ignorePaths = ignorePaths or ignore

	local track = function(obj)
		return trackForMutations(isImmutable, ignorePaths, obj)
	end

	return function(store)
		local state = store.getState()
		local tracker = track(state)

		local result
		return function(nextDispatch)
			return function(action)
				local measureUtils = getTimeMeasureUtils(warnAfter, "ImmutableStateInvariantMiddleware")

				measureUtils.measureTime(function()
					state = store.getState()

					result = tracker.detectMutations()
					tracker = track(state)

					invariant(
						not result.wasMutated,
						`A state mutation was detected between dispatches, in the path {result.path or ""}`
							.. "This may cause incorrect behavior. (https://redux.js.org/style-guide/style-guide#do-not-mutate-state)"
					)
				end)

				local dispatchedAction = nextDispatch(action)

				measureUtils.measureTime(function()
					state = store.getState()

					result = tracker.detectMutations()
					tracker = track(state)

					if result.wasMutated then
						invariant(
							not result.wasMutated,
							`A state mutation was detected between dispatches, in the path {result.path or ""}`
								.. ` Take a look at the reducer(s) handling the action {stringify(action)}`
								.. "(https://redux.js.org/style-guide/style-guide#do-not-mutate-state)"
						)
					end
				end)

				measureUtils.warnIfExceeded()

				return dispatchedAction
			end
		end
	end
end

return immutableStateInvariantMiddleware
