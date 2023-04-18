export type Action<T = any> = {
	type: T,
}

export type AnyAction = Action<any> & {
	[string]: any,
}

export type ActionCreator<A, P...> = (P...) -> A

export type ActionCreatorsMapObject<A, P...> = {
	[string]: ActionCreator<A, P...>,
}

return nil
