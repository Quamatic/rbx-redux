local thunk = function(api)
	return function(nextDispatch)
		return function(action)
			return if typeof(action) == "function" then action(api.dispatch, api.getState) else nextDispatch(action)
		end
	end
end

return {
	thunk = thunk,
}
