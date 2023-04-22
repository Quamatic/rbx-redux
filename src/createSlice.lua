local createAction = require(script.Parent.createAction).createAction
local createReducer = require(script.Parent.createReducer)
local merge = require(script.Parent.merge)

local executeReducerBuilderCallback = require(script.Parent.mapBuilders).executeReducerBuilderCallback

local hasWarnedAboutObjectNotation = false

export type CreateSliceOptions<T> = {
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

export type Slice<S> = {
	name: string,
	reducer: ReducerFunction<S>,
	actions: { [string]: ActionCreator },
	caseReducers: {},
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
local function createSlice<S>(options: CreateSliceOptions<S>): Slice<S>
	local name = options.name
	if name == nil or name == "" then
		error("`name` is a required option for createSlice")
	end

	if _G.__DEV__ then
		if options.initialState == nil then
			-- Redux uses console.error, this should mimic that?
			task.spawn(
				error,
				"You must provide an `initialState` value that is not `undefined`. You may have misspelled `initialState`"
			)
		end
	end

	-- TODO: fix this
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
		if _G.__DEV__ then
			if typeof(options.extraReducers) == "table" then
				if not hasWarnedAboutObjectNotation then
					hasWarnedAboutObjectNotation = true
					warn(
						"The object notation for `createSlice.extraReducers` is deprecated, and will be removed in RTK 2.0. Please use the 'builder callback' notation instead: https://redux-toolkit.js.org/api/createSlice"
					)
				end
			end
		end

		-- TODO: fix this mess

		local extraReducersResults = if typeof(options.extraReducers) == "function"
			then { executeReducerBuilderCallback(options.extraReducers) }
			else { options.extraReducers }

		local extraReducers, actionMatchers, defaultCaseReducer = unpack(extraReducersResults)

		if extraReducers == nil then
			extraReducers = {}
		end

		if actionMatchers == nil then
			actionMatchers = {}
		end

		local finalCaseReducers = merge(sliceCaseReducersByType, extraReducers)

		return createReducer(initialState, function(builder)
			for key, value in finalCaseReducers do
				builder.addCase(key, value)
			end

			for _, m in actionMatchers do
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
	} :: Slice<S>
end

return createSlice
