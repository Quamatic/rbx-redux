local HttpService = game:GetService("HttpService")

local getTimeMeasureUtils = require(script.Parent.utils.getTimeMeasureUtils)
local splice = require(script.Parent.utils.splice)

type EntryProcessor = (key: string, value: any) -> any
local prefix: string = "Invariant failed"

local function invariant(condition: any, message: string?)
	if condition then
		return
	end

	if not _G.__DEV__ then
		error(prefix)
	end

	error(`{prefix}: {message or ""}`)
end

-- This isn't really used anywhere else throughout the project, might as well stick it here...
-- Credit to corepackages/collections/array
local function slice<T>(t: { T }, start_idx: number?, end_idx: number?): { T }
	if typeof(t) ~= "table" then
		error(string.format("Array.slice called on %s", typeof(t)))
	end
	local length = #t

	local start_idx_ = start_idx or 1
	local end_idx_
	if end_idx == nil or end_idx > length + 1 then
		end_idx_ = length + 1
	else
		end_idx_ = end_idx
	end

	if start_idx_ > length + 1 then
		return {}
	end

	local slice = {}

	if start_idx_ < 1 then
		start_idx_ = math.max(length - math.abs(start_idx_), 1)
	end
	if end_idx_ < 1 then
		end_idx_ = math.max(length - math.abs(end_idx_), 1)
	end

	local idx = start_idx_
	local i = 1
	while idx < end_idx_ do
		slice[i] = t[idx]
		idx = idx + 1
		i = i + 1
	end

	return slice
end

local function getSerialize(serializer: EntryProcessor?, decycler: EntryProcessor?): EntryProcessor
	local stack = {}
	local keys = {}

	if not decycler then
		decycler = function(_: string, value: any)
			if stack[1] == value then
				return "[Circular ~]"
			end
			return `[Circular ~. {table.concat(slice(keys, 1, table.find(stack, value) or -1), ".")}]`
		end
	end

	return function(this: any, key: string, value: any)
		if #stack > 0 then
			local thisPos = table.find(stack, this) or -1

			if bit32.bnot(thisPos) ~= 0 then
				splice(stack, thisPos + 1)
				splice(keys, thisPos, math.huge, key)
			else
				table.insert(stack, this)
				table.insert(keys, key)
			end

			if bit32.bnot(table.find(stack, value) or -1) ~= 0 then
				value = decycler(key, value)
			end
		else
			table.insert(stack, value)
		end

		return if serializer == nil then value else serializer(this, key, value)
	end
end

local function stringify(obj: any, serializer: EntryProcessor?, indent: string | number?, decycler: EntryProcessor?)
	local replace = getSerialize(serializer, decycler)

	for key, value in obj do
		obj[key] = replace(obj, key, value)
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
				if typeof(ignored) == "table" and ignored.useStringPattern then
					return string.match(ignored.path, nestedPath) ~= nil
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

	if not _G.__DEV__ then
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

return {
	trackForMutations = trackForMutations,
	isImmutableDefault = isImmutableDefault,
	immutableStateInvariantMiddleware = immutableStateInvariantMiddleware,
}
