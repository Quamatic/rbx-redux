local createAction = require(script.Parent.createAction).createAction
local createReducer = require(script.Parent.createReducer)
local merge = require(script.Parent.merge)

export type SliceParameters<T> = {
	name: string,
	initialState: T,
	reducers: { [string]: ReducerFunction<T> },
	extraReducers: { [string]: ReducerFunction<T> }?,
}

export type ActionLike = { type: string, [string]: any }
export type ReducerFunction<S> = ((state: S, action: ActionLike) -> S?) | {
	reducer: (state: S, action: ActionLike) -> S,
	prepare: <T>(payload: T) -> { payload: S },
}

export type ActionCreator = {}

export type SliceObject<S> = {
	name: string,
	reducer: ReducerFunction<S>,
	actions: { [string]: ActionCreator },
	getInitialState: () -> S,
}

local function getType(slice: string, actionKey: string)
	return `{slice}/{actionKey}`
end

--[[
    Creates a new `Redux` slice.

    A slice A function that accepts an initial state, an object of reducer functions, and a "slice name",
    and automatically generates action creators and action types that correspond to the reducers and state.
]]
--
local function createSlice<S>(options: SliceParameters<S>): SliceObject<S>
	local name = options.name
	if name == nil then
		error("`name` is a required option for createSlice")
	end

	local initialState = if typeof(options.initialState) == "table"
		then table.freeze(options.initialState)
		else options.initialState

	local reducers = options.reducers or {}

	local sliceCaseReducersByName = {}
	local sliceCaseReducersByType = {}
	local actionCreators = {}

	for reducerName, maybeReducerWithPrepare in reducers do
		local type = getType(options.name, reducerName)

		local caseReducer
		local prepareCallback

		if typeof(maybeReducerWithPrepare) == "table" and maybeReducerWithPrepare.reducer ~= nil then
			caseReducer = maybeReducerWithPrepare.reducer
			prepareCallback = maybeReducerWithPrepare.prepare
		else
			caseReducer = maybeReducerWithPrepare
		end

		sliceCaseReducersByName[reducerName] = caseReducer
		sliceCaseReducersByType[type] = caseReducer
		actionCreators[reducerName] = if prepareCallback
			then createAction(type, prepareCallback)
			else createAction(type)
	end

	local function buildReducer()
		local extraReducers = { options.extraReducers }
		local actionMatchers = {}
		local defaultCaseReducer = nil
		local finalCaseReducers = merge(sliceCaseReducersByType, extraReducers)

		return createReducer(initialState, function(builder)
			for key in finalCaseReducers do
				builder.addCase(key, finalCaseReducers[key])
			end

			for m in actionMatchers do
				builder.addMatcher(m.matcher, m.reducer)
			end

			if defaultCaseReducer then
				builder.addDefaultCase(defaultCaseReducer)
			end
		end)
	end

	local reducer

	return {
		name = options.name,
		actions = actionCreators,
		caseReducers = sliceCaseReducersByName,

		reducer = function(state, action)
			if not reducer then
				reducer = buildReducer()
			end

			return reducer(state, action)
		end,

		getInitialState = function()
			if not reducer then
				reducer = buildReducer()
			end

			return reducer.getInitialState()
		end,
	} :: SliceObject<S>
end

return createSlice
