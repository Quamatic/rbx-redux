local reducers = require(script.Parent.types.reducers)

export type ActionReducerMapBuilder<S> = {
	addCase: (
		actionCreator: TypedActionCreator<string>,
		reducer: reducers.CaseReducer<S, any>
	) -> ActionReducerMapBuilder<S>,
	addMatcher: <A>(matcher: (action: any) -> boolean, reducer: reducers.CaseReducer<S, A>) -> nil,
	addDefaultCase: (reducer: reducers.CaseReducer<S, any>) -> nil,
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
		if _G.__DEV__ then
			if #actionMatchers > 0 then
				error("`builder.addCase` should only be called before calling `builder.addMatcher`")
			end

			if defaultCaseReducer then
				error("builder.addCase should only be called before calling 'builder.addDefaultCase'")
			end
		end

		local type = if typeof(typeOrActionCreator) == "string" then typeOrActionCreator else typeOrActionCreator.type

		if actionsMap[type] then
			error("builder.addCase cannot be called with two reducers for the same action type")
		end

		actionsMap[type] = reducer
		return builder
	end

	function builder.addMatcher<A>(matcher, reducer)
		if _G.__DEV__ then
			if defaultCaseReducer then
				error("builder.addMatcher should only be called before calling 'builder.addDefaultCase'")
			end
		end

		table.insert(actionMatchers, { matcher = matcher, reducer = reducer })
		return builder
	end

	function builder.addDefaultCase(reducer)
		if _G.__DEV__ then
			if defaultCaseReducer then
				error("builder.addDefaultCase can only be called once")
			end
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
