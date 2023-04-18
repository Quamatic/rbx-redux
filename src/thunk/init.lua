local actions = require(script.Parent.types.actions)
local types = require(script.types)

function createThunkMiddleware<State, BaseAction, ExtraThunkArg>(extraArgument: ExtraThunkArg?)
	local middleware: types.ThunkMiddleware<State, BaseAction, ExtraThunkArg> = function(store)
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

local thunk = createThunkMiddleware(nil) :: types.ThunkMiddleware<any, any, any> & {
	withExtraArgument: <ExtraThunkArg, State, BasicAction>(
		extraArgument: ExtraThunkArg
	) -> types.ThunkMiddleware<State, BasicAction, ExtraThunkArg>,
}

return {
	thunk = thunk,
	withExtraArgument = createThunkMiddleware,
}
