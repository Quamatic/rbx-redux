local actionTypes = require(script.Parent.actionTypes)

local exports = {}

local function reduce<T>(
	arr: { T },
	callbackFn: (accumulator: T, currentValue: T, currentIndex: number, array: { T }) -> any,
	initialValue
)
	local result = initialValue or arr[1]

	for i = 2, #arr do
		result = callbackFn(result, arr[i], i - 1, arr)
	end

	return result
end

local function id(state)
	local highest = 0

	for _, item in state do
		if item.id > highest then
			highest = item.id
		end
	end

	return highest + 1

	--[[return reduce(state, function(result, item)
		return if item.id > result then item.id else result
	end, 0) + 1]]
	--
end

exports.todos = function(state, action)
	state = state or {}

	if action.type == actionTypes.ADD_TODO then
		local new = table.clone(state)

		table.insert(new, {
			id = id(state),
			text = action.text,
		})

		return new
	else
		return state
	end
end

exports.todosReverse = function(state, action)
	state = state or {}

	if action.type == actionTypes.ADD_TODO then
		local new = table.clone(state)

		table.insert(new, 1, {
			id = id(state),
			text = action.text,
		})

		return new
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

exports.errorThrowingReducer = function(state, action)
	state = state or {}

	if action.type == actionTypes.THROW_ERROR then
		error("Error from errorThrowingReducer")
	end

	return state
end

return exports
