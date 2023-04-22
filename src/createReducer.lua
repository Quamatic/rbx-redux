local reduce = require(script.Parent.utils.reduce)
local executeReducerBuilderCallback = require(script.Parent.mapBuilders).executeReducerBuilderCallback

local hasWarnedAboutObjectNotation = false

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

local function createReducer<S>(
	initialState: S | (() -> S),
	mapOrBuilderCallback: CaseReducers<S, any> | ((any) -> nil),
	actionMatchers: ReadonlyActionMatcherDescriptionCollection<S>,
	defaultCaseReducer: CaseReducer<S, any>?
)
	actionMatchers = actionMatchers or {}

	if _G.__DEV__ then
		if typeof(mapOrBuilderCallback) == "table" then
			if not hasWarnedAboutObjectNotation then
				hasWarnedAboutObjectNotation = true
				warn(
					"The object notation for `createReducer` is deprecated, and will be removed in RTK 2.0. Please use the 'builder callback' notation instead: https://redux-toolkit.js.org/api/createReducer"
				)
			end
		end
	end

	local actionsMap, finalActionMatchers, finalDefaultCaseReducer

	if typeof(mapOrBuilderCallback) == "function" then
		actionsMap, finalActionMatchers, finalDefaultCaseReducer = executeReducerBuilderCallback(mapOrBuilderCallback)
	else
		actionsMap, finalActionMatchers, finalDefaultCaseReducer =
			unpack({ mapOrBuilderCallback, actionMatchers, defaultCaseReducer })
	end

	-- TODO: remake this
	local getInitialState: () -> S
	if typeof(initialState) == "function" then
		getInitialState = function()
			return initialState()
		end
	else
		getInitialState = function()
			return initialState
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

		local caseReducers = { actionsMap[action.type] }
		for _, reducer_ in filteredFinalActionReducers do
			table.insert(caseReducers, reducer_)
		end

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
				local result = caseReducer(previousState, action)

				if result == nil then
					return previousState
				end

				return result :: S
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
