local store = require(script.Parent.store)

export type MiddlewareAPI<D = store.Dispatch, S = any> = {
	dispatch: D,
	getState: () -> S,
}

export type Middleware<_DispatchExt = {}, S = any, D = store.Dispatch> = (
	api: MiddlewareAPI<D, S>
) -> (next: (action: any) -> (action: any) -> nil) -> nil

return nil
