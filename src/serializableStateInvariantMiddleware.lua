local getTimeMeasureUtils = require(script.Parent.utils.getTimeMeasureUtils)

local function isPlain(val: any)
	local type = typeof(val)
	return type == "nil" or type == "string" or type == "number" or type == "boolean" or type == "table"
end

type NonSerializableValue = {
	keyPath: string,
	value: any,
}

type IgnorePaths = { string }

local function isNestedFrozen(value: table)
	if not table.isfrozen(value) then
		return false
	end

	for _, nestedValue in value do
		if typeof(nestedValue) ~= "table" then
			continue
		end

		if not isNestedFrozen(nestedValue) then
			return false
		end
	end

	return true
end

local function findNonSerializableValue(
	value: any,
	path: string?,
	isSerializable: (value: any) -> boolean?,
	getEntries: (value: any) -> { string | any }?,
	ignoredPaths: IgnorePaths?,
	cache: WeakSet<table>
): NonSerializableValue | false
	local foundNestedSerializable: NonSerializableValue | false

	if not isSerializable(value) then
		return {
			keyPath = path or "<root>",
			value = value,
		}
	end

	if typeof(value) ~= "table" or value == nil then
		return false
	end

	if cache and cache:has(value) then
		return false
	end

	local entries = if getEntries ~= nil then getEntries(value) else value
	local hasIgnoredPaths = #ignoredPaths > 0

	for key, nestedValue in entries do
		-- Normally path is set to '' by default, which is falsey in JS. But we don't set the path to that because of it.
		local nestedPath = if path then path .. "." .. key else key

		if hasIgnoredPaths then
		end

		if not isSerializable(nestedValue) then
			return {
				keyPath = nestedPath,
				value = nestedValue,
			}
		end

		if typeof(nestedValue) == "table" then
			foundNestedSerializable =
				findNonSerializableValue(nestedValue, nestedPath, isSerializable, getEntries, ignoredPaths, cache)

			if foundNestedSerializable then
				return foundNestedSerializable
			end
		end
	end

	if cache and isNestedFrozen(value) then
		cache:add(value)
	end

	return false
end

-- BEGIN WEAK SET

local WeakSet = {}
WeakSet.__index = WeakSet

function WeakSet.new()
	local weakSet = setmetatable({}, { __mode = "k" })
	return setmetatable({ _weakSet = weakSet }, WeakSet)
end

function WeakSet:has(key)
	return self._weakSet[key] ~= nil
end

function WeakSet:add(key)
	return self._weakSet[key]
end

type WeakSet<T> = typeof(WeakSet.new())

-- END WEAK SET

type SerializableStateInvariantMiddlewareOptions = {
	isSerializable: (value: any) -> boolean?,
	getEntries: (value: any) -> { string | any }?,
	ignoredActions: { string }?,
	ignoredActionPaths: { string }?,
	warnAfter: number?,
	ignoreState: boolean?,
	ignoreActions: boolean?,
	disableCache: boolean?,
}

local function createSerializableStateInvariantMiddleware(options: SerializableStateInvariantMiddlewareOptions)
	options = options or {}

	if options.isProduction then
		return function()
			return function(nextDispatch)
				return function(action)
					return nextDispatch(action)
				end
			end
		end
	end

	local isSerializable = options.isSerializable
	local getEntries = options.getEntries
	local ignoredActions = options.ignoredActions or {}
	local ignoredActionPaths = options.ignoredActionPaths or { "meta.arg", "meta.baseQueryMeta" }
	local warnAfter = options.warnAfter or 32
	local ignoreState = not not options.ignoreState
	local ignoreActions = not not options.ignoreActions
	local disableCache = not not options.disableCache

	local cache: WeakSet<table>? = if not disableCache then WeakSet.new() else nil

	return function(storeAPI)
		return function(nextDispatch)
			return function(action)
				local result = nextDispatch(action)
				local measureUtils = getTimeMeasureUtils(warnAfter, "SerializableStateInvariantMiddleware")

				if not ignoreActions and (#ignoredActions > 0 and table.find(ignoredActions, action.type) ~= nil) then
					measureUtils.measureTime(function()
						local foundActionNonSerializableValue =
							findNonSerializableValue(action, "", isSerializable, getEntries, ignoredActionPaths, cache)

						if foundActionNonSerializableValue then
							warn(
								`A non-serializable value was detected in an action, in the path: \'{foundActionNonSerializableValue.keyPath}\'. Value:`,
								foundActionNonSerializableValue.value,
								"\n Take a look at the logic that dispatched this action: ",
								action,
								"\n(See https://redux.js.org/faq/actions#why-should-type-be-a-string-or-at-least-serializable-why-should-my-action-types-be-constants)",
								"\n(To allow non-serializable values see: https://redux-toolkit.js.org/usage/usage-guide#working-with-non-serializable-data)"
							)
						end
					end)
				end

				if not ignoreState then
					measureUtils.measureTime(function()
						local state = storeAPI.getState()

						local foundActionNonSerializableValue =
							findNonSerializableValue(state, "", isSerializable, getEntries, ignoredActionPaths, cache)

						if foundActionNonSerializableValue then
							warn(
								`A non-serializable value was detected in the state, in the path: \'{foundActionNonSerializableValue.keyPath}\'. Value:`,
								foundActionNonSerializableValue.value,
								`\n Take a look at the reducer(s) handling this action type: {action.type}`,
								"\n(See https://redux.js.org/faq/organizing-state#can-i-put-functions-promises-or-other-non-serializable-items-in-my-store-state)"
							)
						end
					end)

					measureUtils.warnIfExceeded()
				end

				return result
			end
		end
	end
end

return {
	isPlain = isPlain,
	findNonSerializableValue = findNonSerializableValue,
	createSerializableStateInvariantMiddleware = createSerializableStateInvariantMiddleware,
}
