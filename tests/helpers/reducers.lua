local actionTypes = require(script.Parent.actionTypes)

local exports = {}

exports.todos = function(state, action)
	state = state or {}

	if action.type == actionTypes.ADD_TODO then
		local new = table.clone(state)
		table.insert(new, { id = action.id, text = action.text })
	end

	return state
end

exports.dispatchInTheMiddleOfReducer = function(state, action)
	state = state or {}

	if action.type == actionTypes.DISPATCH_IN_MIDDLE then
		action.boundDispatchFn()
		return state
	end

	return state
end

exports.getStateInTheMiddleOfReducer = function(state, action)
	state = state or {}

	if action.type == actionTypes.GET_STATE_IN_MIDDLE then
		action.boundGetStateFn()
		return state
	end

	return state
end

exports.subscribeInTheMiddleOfReducer = function(state, action)
	state = state or {}

	if action.type == actionTypes.SUBSCRIBE_IN_MIDDLE then
		action.boundSubscribeFn()
		return state
	end

	return state
end

exports.unsubscribeInTheMiddleOfReducer = function(state, action)
	state = state or {}

	if action.type == actionTypes.UNSUBSCRIBE_IN_MIDDLE then
		action.boundUnsubscribeFn()
		return state
	end

	return state
end

return exports
