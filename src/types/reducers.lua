export type AnyAction = {}

export type Reducer<S = any, A = AnyAction, PreloadedState = S> = (state: (S | PreloadedState)?, action: A) -> S

export type ReducersMapObject<S = any, A = AnyAction, PreloadedState = S> = {
	-- Luau doesnt have mapped types, so this is the best we got.
	[string]: Reducer<S, A, PreloadedState>,
}

return nil
