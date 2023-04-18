local createReducer = require(script.Parent.createReducer)

export type ActionReducerMapBuilder<S> = {
	addCase: (
		actionCreator: TypedActionCreator<string>,
		reducer: createReducer.CaseReducer<S, any>
	) -> ActionReducerMapBuilder<S>,
	addMatcher: <A>(matcher: (action: any) -> boolean, reducer: createReducer.CaseReducer<S, A>) -> nil,
	addDefaultCase: (reducer: createReducer.CaseReducer<S, any>) -> nil,
}

export type TypedActionCreator<T, A...> = ((A...) -> any) & {
	type: T,
}

local function executeReducerBuilderCallback<S>(builderCallback: (builder: ActionReducerMapBuilder<S>) -> nil)
	local actionsMap = {}
	local actionMatchers = {}
	local defaultCaseReducer = nil

	local builder: ActionReducerMapBuilder<S> = {}

	function builder.addCase(typeOrActionCreator, reducer)
		if #actionMatchers > 0 then
			error("`builder.addCase` should only be called before calling `builder.addMatcher`", 2)
		end

		if defaultCaseReducer then
			error("builder.addCase should only be called before calling 'builder.addDefaultCase'", 2)
		end

		local type = if typeof(typeOrActionCreator) == "string" then typeOrActionCreator else typeOrActionCreator.type

		if actionsMap[type] then
			error("builder.addCase cannot be called with two reducers for the same action type", 2)
		end

		actionsMap[type] = reducer
		return builder
	end

	function builder.addMatcher<A>(matcher, reducer)
		if defaultCaseReducer then
			error("builder.addMatcher should only be called before calling 'builder.addDefaultCase'", 2)
		end

		table.insert(actionMatchers, { matcher, reducer })
		return builder
	end

	function builder.addDefaultCase(reducer)
		if defaultCaseReducer then
			error("builder.addDefaultCase can only be called once", 2)
		end

		defaultCaseReducer = reducer
		return builder
	end

	builderCallback(builder)
	return actionsMap, actionMatchers, defaultCaseReducer
end

return {
	executeReducerBuilderCallback = executeReducerBuilderCallback,
}
