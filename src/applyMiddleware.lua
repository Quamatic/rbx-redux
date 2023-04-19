local merge = require(script.Parent.merge)
local compose = require(script.Parent.compose)
local types = require(script.Parent.types.store)

--[[
    Applies middleware to the current reducer.
]]
--
local function applyMiddleware<Ext, S>(...)
	local middlewares = { ... }

	return function(createStore)
		return function(reducer, preloadedState)
			local store = createStore(reducer, preloadedState)

			local dispatch: types.Dispatch = function()
				error(
					"Dispatching while constructing your middleware is not allowed. "
						+ "Other middleware would not be applied to this dispatch."
				)
			end

			local middlewareAPI = {
				getState = store.getState,
				dispatch = function(...)
					return dispatch(...)
				end,
			}

			local chain = table.create(#middlewares)
			for _, middleware in middlewares do
				table.insert(chain, middleware(middlewareAPI))
			end

			dispatch = compose(unpack(chain))(store.dispatch)

			return merge(store, { dispatch = dispatch })
		end
	end
end

return applyMiddleware
