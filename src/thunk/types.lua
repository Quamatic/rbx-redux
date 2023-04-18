local actions = require(script.Parent.Parent.types.actions)
local middleware = require(script.Parent.Parent.types.middleware)

export type ThunkDispatch<State, ExtraThunkArg, BasicAction> =
	(<ReturnType>(thunkAction: ThunkAction<ReturnType, State, ExtraThunkArg, BasicAction>) -> ReturnType)
	| (<Action>(action: Action) -> Action)
	| (<ReturnType, Action>(
		action: Action | ThunkAction<ReturnType, State, ExtraThunkArg, BasicAction>
	) -> Action | ReturnType)

export type ThunkAction<ReturnType, State, ExtraThunkArg, BasicAction> = (
	dispatch: ThunkDispatch<State, ExtraThunkArg, BasicAction>,
	getState: () -> State,
	extraArgument: ExtraThunkArg
) -> ReturnType

export type ThunkActionDispatch<ActionCreator, Args...> = (Args...) -> {}

export type ThunkMiddleware<State = any, BasicAction = actions.AnyAction, ExtraThunkArg = nil> = middleware.Middleware<
	ThunkDispatch<State, ExtraThunkArg, BasicAction>,
	State,
	ThunkDispatch<State, ExtraThunkArg, BasicAction>
>

return nil
