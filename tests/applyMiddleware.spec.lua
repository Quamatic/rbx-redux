local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Redux = require(ReplicatedStorage.Redux)

local reducers = require(script.Parent.helpers.reducers)
local actionCreators = require(script.Parent.helpers.actionCreators)
local thunk = require(script.Parent.helpers.middleware).thunk
local spy = require(script.Parent.helpers.spy)
local deepEquals = require(script.Parent.helpers.deepEquals)

local addTodo = actionCreators.addTodo
local addTodoIfEmpty = actionCreators.addTodoIfEmpty
local addTodoAsync = actionCreators.addTodoAsync

return function()
	describe("applyMiddleware", function()
		it("warns when dispatching during middleware setup", function()
			local function dispatchingMiddleware(store)
				store.dispatch(addTodo("Don't dispatch in a middleware setup"))
				return function(nextDispatch)
					return function(action)
						return nextDispatch(action)
					end
				end
			end

			expect(function()
				Redux.applyMiddleware(dispatchingMiddleware)(Redux.createStore)(reducers.todos)
			end).to.throw()
		end)

		it("wraps dispatch method with middleware once", function()
			local function test(spyOnMethods: any)
				return function(methods)
					spyOnMethods(methods)

					return function(nextDispatch)
						return function(action)
							return nextDispatch(action)
						end
					end
				end
			end

			local spiedOnFn = spy()
			local store = Redux.applyMiddleware(test(spiedOnFn.fn), thunk)(Redux.createStore)(reducers.todos)

			store.dispatch(addTodo("Use Redux"))
			store.dispatch(addTodo("Roblox FTW!"))

			expect(#spiedOnFn.calls).to.equal(1)

			expect(spiedOnFn.calls[1][1]["getState"]).to.be.ok()
			expect(spiedOnFn.calls[1][1]["dispatch"]).to.be.ok()

			expect(deepEquals(store.getState(), {
				{ id = 1, text = "Use Redux" },
				{ id = 2, text = "Roblox FTW!" },
			})).to.equal(true)
		end)

		it("passes recursive dispatches through the middleware chain", function()
			local function test(spyOnMethods: any)
				return function()
					return function(nextDispatch)
						return function(action)
							spyOnMethods(action)
							return nextDispatch(action)
						end
					end
				end
			end

			local spiedOnFn = spy()
			local store = Redux.applyMiddleware(test(spiedOnFn.fn), thunk)(Redux.createStore)(reducers.todos)

			local _ = store.dispatch(addTodoAsync("Use Redux"))
			expect(#spiedOnFn.calls).to.equal(1)
		end)

		it("works with thunk middleware", function()
			local store = Redux.applyMiddleware(thunk)(Redux.createStore)(reducers.todos)

			store.dispatch(addTodoIfEmpty("Hello"))
			expect(deepEquals(store.getState(), {
				{
					id = 1,
					text = "Hello",
				},
			}))

			store.dispatch(addTodoIfEmpty("Hello"))
			expect(deepEquals(store.getState(), {
				{
					id = 1,
					text = "Hello",
				},
			}))
		end)

		it("passes through all arguments of dispatch calls from within middleware", function()
			local spiedOnFn = spy()
			local testCallArgs = { "test" }

			local multiArgMiddleware = function(_store)
				return function(nextDispatch)
					return function(action, callArgs)
						if typeof(callArgs) == "table" then
							return action(unpack(callArgs))
						end
						return nextDispatch(action)
					end
				end
			end

			local function dummyMiddleware(api)
				return function(_nextDispatch)
					return function(action)
						return api.dispatch(action, testCallArgs)
					end
				end
			end

			local store = Redux.createStore(reducers.todos, Redux.applyMiddleware(multiArgMiddleware, dummyMiddleware))
			store.dispatch(spiedOnFn.fn)

			expect(deepEquals(spiedOnFn.calls[1], testCallArgs)).to.equal(true)
		end)
	end)
end
