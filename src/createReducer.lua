local merge = require(script.Parent.merge)
local executeReducerBuilderCallback = require(script.Parent.mapBuilders).executeReducerBuilderCallback

export type CaseReducer<S = any, A = {}> = (state: S, action: A) -> nil
export type CaseReducers<S, ActionUnion> = {
	[ActionUnion]: CaseReducer<S, ActionUnion>,
}

export type ActionMatcher<A> = (action: A) -> boolean
export type ActionMatcherDescription<S, A> = {
	matcher: ActionMatcher<A>,
	reducer: CaseReducer<S, A>,
}

export type ReadonlyActionMatcherDescriptionCollection<S> = { ActionMatcherDescription<S, any> }

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

local function createReducer<S>(
	initialState: S | (() -> S),
	mapOrBuilderCallback: CaseReducers<S, any> | ((any) -> nil),
	actionMatchers: ReadonlyActionMatcherDescriptionCollection<S>,
	defaultCaseReducer: CaseReducer<S, any>?
)
	local actionsMap, finalActionMatchers, finalDefaultCaseReducer

	if typeof(mapOrBuilderCallback) == "function" then
		actionsMap, finalActionMatchers, finalDefaultCaseReducer = executeReducerBuilderCallback(mapOrBuilderCallback)
	else
		actionsMap, finalActionMatchers, finalDefaultCaseReducer =
			unpack({ mapOrBuilderCallback, actionMatchers, defaultCaseReducer })
	end

	local getInitialState: () -> S
	if typeof(initialState) == "function" then
		getInitialState = function()
			return table.freeze(initialState())
		end
	else
		local frozenInitialState = if not table.isfrozen(initialState) then table.freeze(initialState) else initialState
		getInitialState = function()
			return frozenInitialState
		end
	end

	local function reducer(state: S, action: any)
		state = state or getInitialState()

		local filteredFinalActionReducers = table.create(#finalActionMatchers)
		for _, actionMatcher in finalActionMatchers do
			if actionMatcher.matcher(action) then
				table.insert(filteredFinalActionReducers, actionMatcher.reducer)
			end
		end

		local caseReducers = merge(actionsMap[action.type], filteredFinalActionReducers)
		local nonnullAssertions = table.create(#caseReducers)

		for _, cr in caseReducers do
			if not not cr then
				table.insert(nonnullAssertions, cr)
			end
		end

		if #nonnullAssertions == 0 then
			caseReducers = { finalDefaultCaseReducer }
		end

		return reduce(caseReducers, function(previousState, caseReducer): S
			if caseReducer then
				if typeof(previousState) ~= "table" then
					local draft = previousState
					local result = caseReducer(draft, action)

					if result == nil then
						return previousState
					end

					return result :: S
				else
					local result = caseReducer(previousState :: any, action)

					if result == nil then
						if previousState == nil then
							return previousState
						end
						error("A case reducer on a non-table value must not return nil")
					end

					return result :: S
				end
			end

			return previousState
		end, state)
	end

	return setmetatable({
		getInitialState = function(_self)
			return getInitialState()
		end,
	}, {
		__call = function(_self, ...)
			return reducer(...)
		end,
	})
end

return createReducer
