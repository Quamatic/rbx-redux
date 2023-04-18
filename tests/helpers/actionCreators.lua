local actionTypes = require(script.Parent.actionTypes)

local function addTodo(text: string)
	return { type = actionTypes.ADD_TODO, text = text }
end

local function addTodoAsync(text: string)
	return function(dispatch)
		task.defer(function()
			dispatch(addTodo(text))
		end)
	end
end

local function addTodoIfEmpty(text: string)
	return function(dispatch, getState)
		if #getState() == 0 then
			dispatch(addTodo(text))
		end
	end
end

local function dispatchInMiddle(boundDispatchFn)
	return {
		type = actionTypes.DISPATCH_IN_MIDDLE,
		boundDispatchFn = boundDispatchFn,
	}
end

local function getStateInMiddle(boundGetStateFn)
	return {
		type = actionTypes.GET_STATE_IN_MIDDLE,
		boundGetStateFn = boundGetStateFn,
	}
end

local function subscribeInMiddle(boundSubscribeFn)
	return {
		type = actionTypes.SUBSCRIBE_IN_MIDDLE,
		boundSubscribeFn = boundSubscribeFn,
	}
end

local function unsubscribeInMiddle(boundUnsubscribeFn)
	return {
		type = actionTypes.UNSUBSCRIBE_IN_MIDDLE,
		boundUnsubscribeFn = boundUnsubscribeFn,
	}
end

local function throwError()
	return {
		type = actionTypes.THROW_ERROR,
	}
end

local function unknownAction()
	return {
		type = actionTypes.UNKNOWN_ACTION,
	}
end

return {
	addTodo = addTodo,
	addTodoAsync = addTodoAsync,
	addTodoIfEmpty = addTodoIfEmpty,
	dispatchInMiddle = dispatchInMiddle,
	getStateInMiddle = getStateInMiddle,
	subscribeInMiddle = subscribeInMiddle,
	unsubscribeInMiddle = unsubscribeInMiddle,
	throwError = throwError,
	unknownAction = unknownAction,
}
