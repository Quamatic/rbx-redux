local actions = require(script.Parent.types.actions)
local types = require(script.types)

export type ThunkDispatch<State, ExtraThunkArg, BasicAction> = types.ThunkDispatch<State, ExtraThunkArg, BasicAction>
export type ThunkAction<ReturnType, State, ExtraThunkArg, BasicAction> = types.ThunkAction<
	ReturnType,
	State,
	ExtraThunkArg,
	BasicAction
>
export type ThunkActionDispatch<ActionCreator, Args...> = types.ThunkActionDispatch<ActionCreator, Args...>
export type ThunkMiddleware<State = any, BasicAction = actions.AnyAction, ExtraThunkArg = nil> = types.ThunkMiddleware<
	State,
	BasicAction,
	ExtraThunkArg
>

function createThunkMiddleware<State, BaseAction, ExtraThunkArg>(extraArgument: ExtraThunkArg?)
	local middleware: ThunkMiddleware<State, BaseAction, ExtraThunkArg> = function(store)
		local dispatch, getState = store.dispatch, store.getState

		return function(nextDispatch)
			return function(action)
				if typeof(action) == "function" then
					return action(dispatch, getState, extraArgument)
				end

				return nextDispatch(action)
			end
		end
	end

	return middleware
end

local thunk = createThunkMiddleware(nil) :: ThunkMiddleware<any, any, any> & {
	withExtraArgument: <ExtraThunkArg, State, BasicAction>(
		extraArgument: ExtraThunkArg
	) -> ThunkMiddleware<State, BasicAction, ExtraThunkArg>,
}

return {
	thunk = thunk,
	withExtraArgument = createThunkMiddleware,
}
