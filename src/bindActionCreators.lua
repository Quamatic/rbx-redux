local store = require(script.Parent.types.store)
local actions = require(script.Parent.types.actions)

local function bindActionCreator<A>(actionCreator: actions.ActionCreator<A>, dispatch: store.Dispatch)
	return function(self, ...)
		return dispatch(actionCreator(self, ...))
	end
end

type BindActionCreatorsFn =
	(<A>(actionCreator: actions.ActionCreator<A>, dispatch: store.Dispatch) -> actions.ActionCreator<A>)
	| (<A>(actionCreator: actions.ActionCreator<A>, dispatch: store.Dispatch) -> actions.ActionCreator<any>)
	| (<A>(
		actionCreators: actions.ActionCreatorsMapObject<A>,
		dispatch: store.Dispatch
	) -> actions.ActionCreatorsMapObject<A>)
	| ((actionCreators: actions.ActionCreatorsMapObject, dispatch: store.Dispatch) -> actions.ActionCreatorsMapObject)

local function bindActionCreators(
	actionCreators: actions.ActionCreator<any> | actions.ActionCreatorsMapObject,
	dispatch: store.Dispatch
)
	if typeof(actionCreators) == "function" then
		return bindActionCreator(actionCreators, dispatch)
	end

	if typeof(actionCreators) ~= "table" then
		error(`bindActionCreators expected an object or a function, but instead received: '{typeof(actionCreators)}'`)
	end

	local boundActionCreators: actions.ActionCreatorsMapObject = {}
	for key, actionCreator in actionCreators do
		if typeof(actionCreator) == "function" then
			boundActionCreators[key] = bindActionCreator(actionCreator, dispatch)
		end
	end

	return boundActionCreators
end

return bindActionCreators :: BindActionCreatorsFn
