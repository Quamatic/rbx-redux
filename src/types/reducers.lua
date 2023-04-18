export type AnyAction = {}

export type Reducer<S = any, A = AnyAction, PreloadedState = S> = (state: (S | PreloadedState)?, action: A) -> S

export type ReducersMapObject<S = any, A = AnyAction, PreloadedState = S> = {
	-- Luau doesnt have mapped types, so this is the best we got.
	[string]: Reducer<S, A, PreloadedState>,
}

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

return nil
