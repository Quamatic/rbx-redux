local types = require(script.Parent.types.reducers)
local actions = require(script.Parent.types.actions)

local ActionTypes = require(script.Parent.utils.actionTypes)

type ReducerMap = {
	[string]: types.Reducer<any, any, any>,
}

local function keys<T>(object: { [string]: T })
	local keys_ = {}

	for key in object do
		table.insert(keys_, key)
	end

	return keys_
end

local function getUnexpectedStateShapeWarningMessage(
	inputState: table,
	reducers: ReducerMap,
	action: actions.Action<any>,
	unexpectedKeyCache: { [string]: true }
)
	local reducerKeys = keys(reducers)
	local argumentName = if action and action.type == ActionTypes.INIT
		then "preloadedState argument passed to createStore"
		else "previous state received by the reducer"

	if #reducerKeys == 0 then
		return "Store does not have a valid reducer. Make sure the argument passed "
			.. "to combineReducers is an object whose values are reducers."
	end

	local inputStateKeys = keys(inputState)
	local unexpectedKeys = {}

	for _, key in inputStateKeys do
		if reducers[key] == nil and unexpectedKeyCache[key] == nil then
			table.insert(unexpectedKeys, key)
		end
	end

	for _, key in unexpectedKeys do
		unexpectedKeyCache[key] = true
	end

	if action and action.type == ActionTypes.REPLACE then
		return
	end

	if #unexpectedKeys > 0 then
		return `Unexpected {if #unexpectedKeys > 1 then "keys" else "key"} `
			.. `"{table.concat(unexpectedKeys, '", "')}" found in {argumentName}. `
			.. `Expected to find one of the known reducer keys instead: `
			.. `"{table.concat(reducerKeys, '", "')}". Unexpected keys will be ignored.`
	end
end

local function assertReducerShape(reducers: ReducerMap)
	for key, reducer in reducers do
		local initialState = reducer(nil, { type = ActionTypes.INIT })

		if initialState == nil then
			error(
				`The slice reducer for key "{key}" returned nil during initialization.`
					.. `If the state passed to the reducer is undefined, you must `
					.. `explicitly return the initial state. The initial state may `
					.. `not be undefined. If you don't want to set a value for this reducer,`
					.. `you can use null instead of undefined.`
			)
		end

		if reducer(nil, {
			type = ActionTypes.PROBE_UNKNOWN_ACTION(),
		}) == nil then
			error(
				`The slice reducer for key ${key}" returned undefined when probed with a random type. `
					.. `Don't try to handle '{ActionTypes.INIT}' or other actions in "redux/*" `
					.. `namespace. They are considered private. Instead, you must return the `
					.. `current state for any unknown actions, unless it is undefined, `
					.. `in which case you must return the initial state, regardless of the `
					.. `action type. The initial state may not be undefined, but can be null.`
			)
		end
	end
end

local function combineReducers(reducers: ReducerMap)
	local finalReducers: ReducerMap = {}

	for key, value in reducers do
		if typeof(value) == "function" then
			finalReducers[key] = value
		end
	end

	local numFinalReducers = #keys(finalReducers)
	local unexpectedKeyCache: { [string]: true } = {}

	if _G.__DEV__ then
		unexpectedKeyCache = {}
	end

	local _, shapeAssertionError = pcall(assertReducerShape, finalReducers)

	return function(state, action)
		state = state or {}

		if shapeAssertionError then
			error(shapeAssertionError)
		end

		if _G.__DEV__ then
			local warningMessage =
				getUnexpectedStateShapeWarningMessage(state, finalReducers, action, unexpectedKeyCache)

			if warningMessage then
				warn(warningMessage)
			end
		end

		local hasChanged = false
		local nextState = {}

		for key, reducer in finalReducers do
			local previousStateForKey = state[key]
			local nextStateForKey = reducer(previousStateForKey, action)

			if typeof(nextStateForKey) == "nil" then
				local actionType = action and action.type
				error(
					`When called with an action of type {if actionType then tostring(actionType) else "(unknown type),"}, the slice reducer for key "{key}" returned undefined.`
						.. "To ignore an action, you must explicitly return the previous state."
						.. "If you want this reducer to hold no value, you can return null instead of undefined."
				)
			end

			nextState[key] = nextStateForKey
			hasChanged = hasChanged or nextStateForKey ~= previousStateForKey
		end

		hasChanged = hasChanged or numFinalReducers ~= #keys(state)
		return if hasChanged then nextState else state
	end
end

return combineReducers
