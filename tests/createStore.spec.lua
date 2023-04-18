local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Redux = require(ReplicatedStorage.Redux)

local reducers = require(script.Parent.helpers.reducers)

local actionCreators = require(script.Parent.helpers.actionCreators)
local addTodo = actionCreators.addTodo
local unknownAction = actionCreators.unknownAction
local dispatchInMiddle = actionCreators.dispatchInMiddle
local getStateInMiddle = actionCreators.getStateInMiddle
local subscribeInMiddle = actionCreators.subscribeInMiddle
local unsubscribeInMiddle = actionCreators.unsubscribeInMiddle
local throwError = actionCreators.throwError

local noop = require(script.Parent.helpers.noop)
local merge = require(script.Parent.helpers.merge)

local function fn(fromFn: () -> any?)
	local calls = 0

	return {
		fn = function(...)
			if fromFn then
				fromFn(...)
			end
			calls += 1
		end,
		mock = {
			calls = calls,
		},
	}
end

return function()
	describe("createStore", function()
		it("exposes the public API", function()
			local store = Redux.createStore(Redux.combineReducers(reducers))

			local length = 0
			for _ in store do
				length += 1
			end

			expect(length).to.equal(4)
			expect(store.subscribe).to.never.equal(nil)
			expect(store.dispatch).to.never.equal(nil)
			expect(store.getState).to.never.equal(nil)
			expect(store.replaceReducer).to.never.equal(nil)
		end)

		it("throws if reducer is not a function", function()
			expect(function()
				return Redux.createStore(nil)
			end).to.throw()

			expect(function()
				return Redux.createStore("text")
			end).to.throw()

			expect(function()
				return Redux.createStore({})
			end).to.throw()

			expect(function()
				return Redux.createStore(function()
					return {}
				end)
			end).to.never.throw()
		end)

		it("passes the initial state", function()
			local store = Redux.createStore(reducers.todos, {
				{
					id = 1,
					text = "Hello",
				},
			})

			expect(store.getState()).to.equal({
				{
					id = 1,
					text = "Hello",
				},
			})
		end)

		it("applies the reducer to the previous state", function()
			local store = Redux.createStore(reducers.todos)
			expect(store.getState()).to.equal({})

			store.dispatch(unknownAction())
			expect(store.getState()).to.equal({})

			store.dispatch(actionCreators.addTodo("Hello"))
			expect(store.getState()).to.equal({
				{
					id = 1,
					text = "Hello",
				},
			})

			store.dispatch(addTodo("World"))
			expect(store.getState()).to.equal({
				{
					id = 1,
					text = "Hello",
				},
				{
					id = 2,
					text = "World",
				},
			})
		end)

		it("applies the reducer to the initial state", function()
			local store = Redux.createStore(reducers.todos, {
				{
					id = 1,
					text = "Hello",
				},
			})
			expect(store.getState()).to.equal({
				{
					id = 1,
					text = "Hello",
				},
			})

			store.dispatch(unknownAction())
			expect(store.getState()).to.equal({
				{
					id = 1,
					text = "Hello",
				},
			})

			store.dispatch(addTodo("World"))
			expect(store.getState()).to.equal({
				{
					id = 1,
					text = "Hello",
				},
				{
					id = 2,
					text = "World",
				},
			})
		end)

		it("preserves the state when replacing a reducer", function()
			local store = Redux.createStore(reducers.todos)

			store.dispatch(addTodo("Hello"))
			store.dispatch(addTodo("World"))

			expect(store.getState()).to.equal({
				{
					id = 1,
					text = "Hello",
				},
				{
					id = 2,
					text = "World",
				},
			})

			store.replaceReducer(reducers.todosReverse)
			expect(store.getState()).to.equal({
				{
					id = 1,
					text = "Hello",
				},
				{
					id = 2,
					text = "World",
				},
			})

			store.dispatch(addTodo("Perhaps"))
			expect(store.getState()).to.equal({
				{
					id = 1,
					text = "Hello",
				},
				{
					id = 2,
					text = "World",
				},
				{
					id = 3,
					text = "World",
				},
			})

			store.dispatch(addTodo("Surely"))
			expect(store.getState()).to.equal({
				{
					id = 1,
					text = "Hello",
				},
				{
					id = 2,
					text = "World",
				},
				{
					id = 3,
					text = "Perhaps",
				},
				{
					id = 4,
					text = "Surely",
				},
			})
		end)

		it("supports multiple subscriptions", function()
			local store = Redux.createStore(reducers.todos)

			local listenerA = fn()
			local listenerB = fn()

			local unsubscribeA = store.subscribe(listenerA.fn)
			store.dispatch(unknownAction())
			expect(listenerA.mock.calls).to.equal(1)
			expect(listenerB.mock.calls).to.equal(0)

			store.dispatch(unknownAction())
			expect(listenerA.mock.calls).to.equal(2)
			expect(listenerB.mock.calls).to.equal(0)

			local unsubscribeB = store.subscribe(listenerA.fn)
			expect(listenerA.mock.calls).to.equal(2)
			expect(listenerB.mock.calls).to.equal(0)

			store.dispatch(unknownAction())
			expect(listenerA.mock.calls).to.equal(3)
			expect(listenerB.mock.calls).to.equal(1)

			unsubscribeA()
			expect(listenerA.mock.calls).to.equal(3)
			expect(listenerB.mock.calls).to.equal(1)

			store.dispatch(unknownAction())
			expect(listenerA.mock.calls).to.equal(3)
			expect(listenerB.mock.calls).to.equal(2)

			unsubscribeB()
			expect(listenerA.mock.calls).to.equal(3)
			expect(listenerB.mock.calls).to.equal(2)

			store.dispatch(unknownAction())
			expect(listenerA.mock.calls).to.equal(3)
			expect(listenerB.mock.calls).to.equal(2)

			unsubscribeA = store.subscribe(listenerA)
			expect(listenerA.mock.calls).to.equal(3)
			expect(listenerB.mock.calls).to.equal(2)

			store.dispatch(unknownAction())
			expect(listenerA.mock.calls).to.equal(4)
			expect(listenerB.mock.calls).to.equal(2)
		end)

		it("only removes listener once unsubscribe is called", function()
			local store = Redux.createStore(reducers.todos)
			local listenerA = fn()
			local listenerB = fn()

			local unsubscribeA = store.subscribe(listenerA)
			store.subscribe(listenerB)

			unsubscribeA()
			unsubscribeA()

			store.dispatch(unknownAction())
			expect(listenerA.mock.calls).to.equal(0)
			expect(listenerB.mock.calls).to.equal(1)
		end)

		it("only removes relevant listener when unsubscribe is called", function()
			local store = Redux.createStore(reducers.todos)
			local listener = fn()

			store.subscribe(listener)
			local unsubscribeSecond = store.subscribe(listener)

			unsubscribeSecond()
			unsubscribeSecond()

			store.dispatch(unknownAction())
			expect(listener.mock.calls).to.equal(1)
		end)

		it("supports removing a subscription within a subscription", function()
			local store = Redux.createStore(reducers.todos)
			local listenerA = fn()
			local listenerB = fn()
			local listenerC = fn()

			store.subscribe(listenerA)
			local unSubB
			unSubB = store.subscribe(function()
				listenerB()
				unSubB()
			end)
			store.subscribe(listenerC)

			store.dispatch(unknownAction())
			store.dispatch(unknownAction())

			expect(listenerA.mock.calls).to.equal(2)
			expect(listenerB.mock.calls).to.equal(1)
			expect(listenerC.mock.calls).to.equal(2)
		end)

		it(
			"notifies all subscribers about current dispatch regardless if any of them gets unsubscribed in the process",
			function()
				local store = Redux.createStore(reducers.todos)

				local unsubscribeHandles = {}
				local doUnsubscribeAll = function()
					for _, unsubscribe in unsubscribeHandles do
						unsubscribe()
					end
				end

				local listener1 = fn()
				local listener2 = fn()
				local listener3 = fn()

				table.insert(
					unsubscribeHandles,
					store.subscribe(function()
						listener1()
					end)
				)

				table.insert(
					unsubscribeHandles,
					store.subscribe(function()
						listener2()
						doUnsubscribeAll()
					end)
				)

				table.insert(
					unsubscribeHandles,
					store.subscribe(function()
						listener3()
					end)
				)

				store.dispatch(unknownAction())
				expect(listener1.mock.calls).to.equal(1)
				expect(listener2.mock.calls).to.equal(1)
				expect(listener3.mock.calls).to.equal(1)

				store.dispatch(unknownAction())
				expect(listener1.mock.calls).to.equal(1)
				expect(listener2.mock.calls).to.equal(1)
				expect(listener3.mock.calls).to.equal(1)
			end
		)

		it("notifies only subscribers active at the moment of a current dispatch", function()
			local store = Redux.createStore(reducers.todos)

			local listener1 = fn()
			local listener2 = fn()
			local listener3 = fn()

			local listener3Added = false
			local maybeAddThirdListener = function()
				if not listener3Added then
					listener3Added = true
					store.subscribe(function()
						listener3()
					end)
				end
			end

			store.subscribe(function()
				listener1()
			end)

			store.subscribe(function()
				listener2()
				maybeAddThirdListener()
			end)

			store.dispatch(unknownAction())
			expect(listener1.mock.calls).to.equal(1)
			expect(listener2.mock.calls).to.equal(1)
			expect(listener3.mock.calls).to.equal(0)

			store.dispatch(unknownAction())
			expect(listener1.mock.calls).to.equal(2)
			expect(listener2.mock.calls).to.equal(2)
			expect(listener3.mock.calls).to.equal(1)
		end)

		it("uses the last snapshot of subscribers during a nested dispatch", function()
			local store = Redux.createStore(reducers.todos)

			local listener1 = fn()
			local listener2 = fn()
			local listener3 = fn()
			local listener4 = fn()

			local unsubscribe4: any
			local unsubscribe1
			unsubscribe1 = store.subscribe(function()
				listener1()
				expect(listener1.mock.calls).to.equal(1)
				expect(listener2.mock.calls).to.equal(0)
				expect(listener3.mock.calls).to.equal(0)
				expect(listener4.mock.calls).to.equal(0)

				unsubscribe1()
				unsubscribe4 = store.subscribe(listener4)
				store.dispatch(unknownAction())

				expect(listener1.mock.calls).to.equal(1)
				expect(listener2.mock.calls).to.equal(1)
				expect(listener3.mock.calls).to.equal(1)
				expect(listener4.mock.calls).to.equal(1)
			end)

			store.subscribe(listener1)
			store.subscribe(listener3)

			store.dispatch(unknownAction())
			expect(listener1.mock.calls).to.equal(1)
			expect(listener2.mock.calls).to.equal(2)
			expect(listener3.mock.calls).to.equal(2)
			expect(listener4.mock.calls).to.equal(1)

			unsubscribe4()
			store.dispatch(unknownAction())
			expect(listener1.mock.calls).to.equal(1)
			expect(listener2.mock.calls).to.equal(3)
			expect(listener3.mock.calls).to.equal(3)
			expect(listener4.mock.calls).to.equal(1)
		end)

		it("provides an up-to-date state when a subscriber is notified", function()
			local store = Redux.createStore(reducers.todos)

			local thread: thread
			thread = coroutine.create(function()
				store.subscribe(function()
					coroutine.resume(thread, store.getState())
				end)

				store.dispatch(addTodo("Hello"))
				local state = coroutine.yield()

				expect(state).to.equal({
					{
						id = 1,
						text = "Hello",
					},
				})
			end)

			coroutine.resume(thread)
		end)

		it("does not leak private listeners array", function()
			local store = Redux.createStore(reducers.todos)

			local thread: thread
			thread = coroutine.create(function()
				store.subscribe(function(self: any)
					coroutine.resume(thread, self)
				end)

				store.dispatch(addTodo("Hello"))
				local state = coroutine.yield()

				expect(state).to.equal(nil)
			end)

			coroutine.resume(thread)
		end)

		it("only accepts plain object actions", function()
			local store = Redux.createStore(reducers.todos)

			expect(function()
				return store.dispatch(unknownAction())
			end).to.never.throw()

			local nonObjects = { nil, nil, 42, "hey" }
			for _, nonObject in nonObjects do
				expect(function()
					return store.dispatch(nonObject)
				end).to.throw()
			end
		end)

		it("handles nested dispatches gracefully", function()
			local function foo(state, action)
				state = state or 0
				return if action.type == "foo" then 1 else state
			end

			local function bar(state, action)
				state = state or 0
				return if action.type == "bar" then 12 else state
			end

			local store = Redux.createStore(Redux.combineReducers({
				foo = foo,
				bar = bar,
			}))

			-- Exposing this for names sake
			local function kindaComponentDidUpdate()
				local state = store.getState()
				if state.bar == 0 then
					store.dispatch({ type = "bar" })
				end
			end

			store.subscribe(kindaComponentDidUpdate)

			store.dispatch({ type = "foo " })
			expect(store.getState()).to.equal({
				foo = 1,
				bar = 2,
			})
		end)

		it("does not allow dispatch() from within a reducer", function()
			local store = Redux.createStore(reducers.dispatchInTheMiddleOfReducer)

			expect(function()
				return store.dispatch(dispatchInMiddle(store:dispatch(unknownAction())))
			end).to.throw("may not dispatch")

			expect(function()
				return store.dispatch(dispatchInMiddle(function()
					return {}
				end))
			end).to.never.throw()
		end)

		it("does not allow getState() from within a reducer", function()
			local store = Redux.createStore(reducers.getStateInTheMiddleOfReducer)

			expect(function()
				return store.dispatch(getStateInMiddle(store:getState()))
			end).to.throw("You may not call store.getState()")

			expect(function()
				return store.dispatch(getStateInMiddle(function()
					return {}
				end))
			end).to.never.throw()
		end)

		it("does not allow subscribe() from within a reducer", function()
			local store = Redux.createStore(reducers.subscribeInTheMiddleOfReducer)

			expect(function()
				return store.dispatch(subscribeInMiddle(store:subscribe(function() end)))
			end).to.throw("You may not call store.subscribe()")

			expect(function()
				return store.dispatch(subscribeInMiddle(function()
					return {}
				end))
			end).to.never.throw()
		end)

		it("does not allow unsubscribe() from within a reducer", function()
			local store = Redux.createStore(reducers.unsubscribeInTheMiddleOfReducer)
			local unsubscribe = store.subscribe(function() end)

			expect(function()
				return store.dispatch(unsubscribeInMiddle(unsubscribe(store)))
			end).to.throw("You may not call store.subscribe()")

			expect(function()
				return store.dispatch(unsubscribeInMiddle(function()
					return {}
				end))
			end).to.never.throw()
		end)

		it("recovers from an error within the reducer", function()
			local store = Redux.createStore(reducers.errorThrowingReducer)

			expect(function()
				return store.dispatch(throwError())
			end).to.throw()

			expect(function()
				return store.dispatch(unknownAction())
			end).to.never.throw()
		end)

		it("throws if action type is missing", function()
			local store = Redux.createStore(reducers.todos)

			expect(function()
				return store.dispatch({})
			end).to.throw('Actions may not have an undefined "type" property')
		end)

		it("throws an error that correctly describes the type of item dispatched", function()
			local store = Redux.createStore(reducers.todos)

			expect(function()
				return store.dispatch(noop)
			end).to.throw("the actual type was: 'function'")

			expect(function()
				return store.dispatch(nil)
			end).to.throw("the actual type was: 'nil'")
		end)

		it("does not throw if action type is falsy", function()
			local store = Redux.createStore(reducers.todos)

			expect(function()
				return store.dispatch({ type = false })
			end).to.never.throw()

			expect(function()
				return store.dispatch({ type = 0 })
			end).to.never.throw()

			expect(function()
				return store.dispatch({ type = "" })
			end).to.never.throw()
		end)

		it("accepts enhancer as the third argument", function()
			local spyEnhancer = function(vanillaCreateStore)
				return function(...: any)
					local args = table.pack(...)

					expect(args[0]).to.be(reducers.todos)
					expect(args[1]).to.equal(nil)
					expect(args.n).to.equal(2)

					local vanillaStore = vanillaCreateStore(...)
					return merge(vanillaStore, {
						dispatch = fn(vanillaStore.dispatch),
					})
				end
			end

			local store = Redux.createStore(reducers.todos, spyEnhancer)
			local action = addTodo("Hello")
			store.dispatch(action)

			expect(store.getState()).to.equal({
				{
					id = 1,
					text = "Helo",
				},
			})
		end)

		it("throws if enhancer is neither nil nor a function", function()
			expect(function()
				return Redux.createStore(reducers.todos, nil, {})
			end).to.throw()

			expect(function()
				return Redux.createStore(reducers.todos, nil, false)
			end).to.throw()

			expect(function()
				return Redux.createStore(reducers.todos, nil, nil)
			end).to.never.throw()

			expect(function()
				return Redux.createStore(reducers.todos, nil, function(x)
					return x
				end)
			end).to.never.throw()

			expect(function()
				return Redux.createStore(reducers.todos, function(x)
					return x
				end)
			end).to.never.throw()

			expect(function()
				return Redux.createStore(reducers.todos, {})
			end).to.never.throw()
		end)

		it("throws if nextReducer is not a function", function()
			local store = Redux.createStore(reducers.todos)

			expect(function()
				return store.replaceReducer(nil)
			end).to.throw("Expected the nextReducer to be a function.")

			expect(function()
				return store.replaceReducer(noop)
			end).to.never.throw()
		end)

		it("throws if listener is not a function", function()
			local store = Redux.createStore(reducers.todos)

			expect(function()
				return store.subscribe(nil)
			end).to.throw()

			expect(function()
				return store.subscribe("")
			end).to.throw()

			expect(function()
				return store.subscribe(5)
			end).to.throw()

			expect(function()
				return store.subscribe({})
			end).to.throw()
		end)

		it(
			"does not log an error if parts of the current state will be ignored by a nextReducer using combineReducers",
			function()
				local fakeError = fn()

				local reducer = function(s)
					s = s or 0
					return s
				end

				local yReducer = Redux.combineReducers({
					z = reducer,
					w = reducer,
				})

				local store = Redux.createStore(Redux.combineReducers({
					x = reducer,
					y = yReducer,
				}))

				store.replaceReducer(Redux.combineReducers({
					y = Redux.combineReducers({
						z = reducer,
					}),
				}))

				expect(fakeError.mock.calls).to.equal(0)
			end
		)

		it("throws if passing several enhancer functions without preloaded state", function()
			local rootReducer = Redux.combineReducers(reducers)
			local dummyEnhancer = function(f: any)
				return f
			end

			expect(function()
				return Redux.createStore(rootReducer, dummyEnhancer, dummyEnhancer)
			end).to.throw()
		end)

		it("throws if passing several enhancer functions with preloaded state", function()
			local rootReducer = Redux.combineReducers(reducers)
			local dummyEnhancer = function(f: any)
				return f
			end

			expect(function()
				return Redux.createStore(rootReducer, { todos = {} }, dummyEnhancer, dummyEnhancer)
			end).to.throw()
		end)
	end)
end
