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
local deepEquals = require(script.Parent.helpers.deepEquals)
local spy = require(script.Parent.helpers.spy)

return function()
	describe("createStore", function()
		it("exposes the public API", function()
			local store = Redux.createStore(Redux.combineReducers(reducers))

			local length = 0
			for _ in store do
				length += 1
			end

			expect(length).to.equal(5)
			expect(store.subscribe).to.be.ok()
			expect(store.dispatch).to.be.ok()
			expect(store.getState).to.be.ok()
			expect(store.replaceReducer).to.be.ok()
			expect(store.destruct).to.be.ok()
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

			expect(deepEquals(store.getState(), {
				{
					id = 1,
					text = "Hello",
				},
			})).to.equal(true)
		end)

		it("applies the reducer to the previous state", function()
			local store = Redux.createStore(reducers.todos)
			expect(deepEquals(store.getState(), {})).to.equal(true)

			store.dispatch(unknownAction())
			expect(deepEquals(store.getState(), {})).to.equal(true)

			store.dispatch(actionCreators.addTodo("Hello"))
			expect(deepEquals(store.getState(), { { id = 1, text = "Hello" } }))

			store.dispatch(addTodo("World"))
			expect(deepEquals(store.getState(), {
				{
					id = 1,
					text = "Hello",
				},
				{
					id = 2,
					text = "World",
				},
			}))
		end)

		it("applies the reducer to the initial state", function()
			local store = Redux.createStore(reducers.todos, {
				{
					id = 1,
					text = "Hello",
				},
			})
			expect(deepEquals(store.getState(), {
				{
					id = 1,
					text = "Hello",
				},
			})).to.equal(true)

			store.dispatch(unknownAction())
			expect(deepEquals(store.getState(), {
				{
					id = 1,
					text = "Hello",
				},
			})).to.equal(true)

			store.dispatch(addTodo("World"))
			expect(deepEquals(store.getState(), {
				{
					id = 1,
					text = "Hello",
				},
				{
					id = 2,
					text = "World",
				},
			})).to.equal(true)
		end)

		it("preserves the state when replacing a reducer", function()
			local store = Redux.createStore(reducers.todos)

			store.dispatch(addTodo("Hello"))
			store.dispatch(addTodo("World"))

			expect(deepEquals(store.getState(), {
				{
					id = 1,
					text = "Hello",
				},
				{
					id = 2,
					text = "World",
				},
			})).to.equal(true)

			store.replaceReducer(reducers.todosReverse)
			expect(deepEquals(store.getState(), {
				{
					id = 1,
					text = "Hello",
				},
				{
					id = 2,
					text = "World",
				},
			})).to.equal(true)

			store.dispatch(addTodo("Perhaps"))
			expect(deepEquals(store.getState(), {
				{
					id = 3,
					text = "Perhaps",
				},
				{
					id = 1,
					text = "Hello",
				},
				{
					id = 2,
					text = "World",
				},
			})).to.equal(true)

			store.replaceReducer(reducers.todos)
			expect(deepEquals(store.getState(), {
				{
					id = 3,
					text = "Perhaps",
				},
				{
					id = 1,
					text = "Hello",
				},
				{
					id = 2,
					text = "World",
				},
			})).to.equal(true)

			store.dispatch(addTodo("Surely"))
			expect(deepEquals(store.getState(), {
				{
					id = 3,
					text = "Perhaps",
				},
				{
					id = 1,
					text = "Hello",
				},
				{
					id = 2,
					text = "World",
				},
				{
					id = 4,
					text = "Surely",
				},
			})).to.equal(true)
		end)

		it("supports multiple subscriptions", function()
			local store = Redux.createStore(reducers.todos)

			local listenerA = spy()
			local listenerB = spy()

			local unsubscribeA = store.subscribe(listenerA.fn)
			store.dispatch(unknownAction())
			expect(#listenerA.calls).to.equal(1)
			expect(#listenerB.calls).to.equal(0)

			store.dispatch(unknownAction())
			expect(#listenerA.calls).to.equal(2)
			expect(#listenerB.calls).to.equal(0)

			local unsubscribeB = store.subscribe(listenerB.fn)
			expect(#listenerA.calls).to.equal(2)
			expect(#listenerB.calls).to.equal(0)

			store.dispatch(unknownAction())
			expect(#listenerA.calls).to.equal(3)
			expect(#listenerB.calls).to.equal(1)

			unsubscribeA()
			expect(#listenerA.calls).to.equal(3)
			expect(#listenerB.calls).to.equal(1)

			store.dispatch(unknownAction())
			expect(#listenerA.calls).to.equal(3)
			expect(#listenerB.calls).to.equal(2)

			unsubscribeB()
			expect(#listenerA.calls).to.equal(3)
			expect(#listenerB.calls).to.equal(2)

			store.dispatch(unknownAction())
			expect(#listenerA.calls).to.equal(3)
			expect(#listenerB.calls).to.equal(2)

			unsubscribeA = store.subscribe(listenerA.fn)
			expect(#listenerA.calls).to.equal(3)
			expect(#listenerB.calls).to.equal(2)

			store.dispatch(unknownAction())
			expect(#listenerA.calls).to.equal(4)
			expect(#listenerB.calls).to.equal(2)
		end)

		it("only removes listener once unsubscribe is called", function()
			local store = Redux.createStore(reducers.todos)
			local listenerA = spy()
			local listenerB = spy()

			local unsubscribeA = store.subscribe(listenerA.fn)
			store.subscribe(listenerB.fn)

			unsubscribeA()
			unsubscribeA()

			store.dispatch(unknownAction())
			expect(#listenerA.calls).to.equal(0)
			expect(#listenerB.calls).to.equal(1)
		end)

		it("only removes relevant listener when unsubscribe is called", function()
			local store = Redux.createStore(reducers.todos)
			local listener = spy()

			store.subscribe(listener.fn)
			local unsubscribeSecond = store.subscribe(listener.fn)

			unsubscribeSecond()
			unsubscribeSecond()

			store.dispatch(unknownAction())
			expect(#listener.calls).to.equal(1)
		end)

		it("supports removing a subscription within a subscription", function()
			local store = Redux.createStore(reducers.todos)
			local listenerA = spy()
			local listenerB = spy()
			local listenerC = spy()

			store.subscribe(listenerA.fn)
			local unSubB
			unSubB = store.subscribe(function()
				listenerB.fn()
				unSubB()
			end)
			store.subscribe(listenerC.fn)

			store.dispatch(unknownAction())
			store.dispatch(unknownAction())

			expect(#listenerA.calls).to.equal(2)
			expect(#listenerB.calls).to.equal(1)
			expect(#listenerC.calls).to.equal(2)
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

				local listener1 = spy()
				local listener2 = spy()
				local listener3 = spy()

				table.insert(
					unsubscribeHandles,
					store.subscribe(function()
						listener1.fn()
					end)
				)

				table.insert(
					unsubscribeHandles,
					store.subscribe(function()
						listener2.fn()
						doUnsubscribeAll()
					end)
				)

				table.insert(
					unsubscribeHandles,
					store.subscribe(function()
						listener3.fn()
					end)
				)

				store.dispatch(unknownAction())
				expect(#listener1.calls).to.equal(1)
				expect(#listener2.calls).to.equal(1)
				expect(#listener3.calls).to.equal(1)

				store.dispatch(unknownAction())
				expect(#listener1.calls).to.equal(1)
				expect(#listener2.calls).to.equal(1)
				expect(#listener3.calls).to.equal(1)
			end
		)

		it("notifies only subscribers active at the moment of a current dispatch", function()
			local store = Redux.createStore(reducers.todos)

			local listener1 = spy()
			local listener2 = spy()
			local listener3 = spy()

			local listener3Added = false
			local maybeAddThirdListener = function()
				if not listener3Added then
					listener3Added = true
					store.subscribe(function()
						listener3.fn()
					end)
				end
			end

			store.subscribe(function()
				listener1.fn()
			end)

			store.subscribe(function()
				listener2.fn()
				maybeAddThirdListener()
			end)

			store.dispatch(unknownAction())
			expect(#listener1.calls).to.equal(1)
			expect(#listener2.calls).to.equal(1)
			expect(#listener3.calls).to.equal(0)

			store.dispatch(unknownAction())
			expect(#listener1.calls).to.equal(2)
			expect(#listener2.calls).to.equal(2)
			expect(#listener3.calls).to.equal(1)
		end)

		-- look back at this unit test later

		--[[
		it("uses the last snapshot of subscribers during a nested dispatch", function()
			local store = Redux.createStore(reducers.todos)

			local listener1 = spy()
			local listener2 = spy()
			local listener3 = spy()
			local listener4 = spy()

			local unsubscribe4: any
			local unsubscribe1
			unsubscribe1 = store.subscribe(function()
				print("called but why")
				listener1.fn()
				expect(#listener1.calls).to.equal(1)
				expect(#listener2.calls).to.equal(0)
				expect(#listener3.calls).to.equal(0)
				expect(#listener4.calls).to.equal(0)

				print("H")

				unsubscribe1()
				unsubscribe4 = store.subscribe(listener4.fn)
				store.dispatch(unknownAction())

				expect(#listener1.calls).to.equal(1)
				expect(#listener2.calls).to.equal(1)
				expect(#listener3.calls).to.equal(1)
				expect(#listener4.calls).to.equal(1)
			end)

			print("Wait what")

			store.subscribe(listener2.fn)
			store.subscribe(listener3.fn)

			store.dispatch(unknownAction())
			expect(#listener1.calls).to.equal(1)
			expect(#listener2.calls).to.equal(2)
			expect(#listener3.calls).to.equal(2)
			expect(#listener4.calls).to.equal(1)

			unsubscribe4()
			store.dispatch(unknownAction())
			expect(#listener1.calls).to.equal(1)
			expect(#listener2.calls).to.equal(3)
			expect(#listener3.calls).to.equal(3)
			expect(#listener4.calls).to.equal(1)
		end)]]
		--

		it("provides an up-to-date state when a subscriber is notified", function()
			local store = Redux.createStore(reducers.todos)

			local thread: thread
			thread = coroutine.create(function()
				store.subscribe(function()
					coroutine.resume(thread, store.getState())
				end)

				store.dispatch(addTodo("Hello"))
				local state = coroutine.yield()

				expect(deepEquals(state, {
					{
						id = 1,
						text = "Hello",
					},
				})).to.equal(true)
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

				expect(state).to.never.be.ok()
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
				return if action.type == "bar" then 2 else state
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

			store.dispatch({ type = "foo" })
			expect(deepEquals(store.getState(), {
				foo = 1,
				bar = 2,
			})).to.equal(true)
		end)

		it("does not allow dispatch() from within a reducer", function()
			local store = Redux.createStore(reducers.dispatchInTheMiddleOfReducer)

			expect(function()
				return store.dispatch(dispatchInMiddle(store:dispatch(unknownAction())))
			end).to.throw()

			expect(function()
				return store.dispatch(dispatchInMiddle(function()
					return {}
				end))
			end).to.never.throw()
		end)

		it("does not allow getState() from within a reducer", function()
			local store = Redux.createStore(reducers.getStateInTheMiddleOfReducer)

			expect(function()
				store.dispatch(getStateInMiddle(store.getState))
			end).to.throw()

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
			end).to.throw()

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
				return store.dispatch(unsubscribeInMiddle(unsubscribe))
			end).to.throw()

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
			end).never.to.throw()
		end)

		it("throws if action type is missing", function()
			local store = Redux.createStore(reducers.todos)

			expect(function()
				return store.dispatch({})
			end).to.throw()
		end)

		it("throws an error that correctly describes the type of item dispatched", function()
			local store = Redux.createStore(reducers.todos)

			expect(function()
				return store.dispatch(noop)
			end).to.throw()

			expect(function()
				return store.dispatch(nil)
			end).to.throw()
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
			local emptyArray = {}
			local spyEnhancer = function(vanillaCreateStore)
				return function(...: any)
					local args = { ... }

					expect(deepEquals(args[1], reducers.todos)).to.equal(true)
					expect(args[2]).to.equal(emptyArray)
					expect(#args).to.equal(2)

					local vanillaStore = vanillaCreateStore(...)
					return merge(vanillaStore, {
						dispatch = spy(vanillaStore.dispatch).fn,
					})
				end
			end

			local store = Redux.createStore(reducers.todos, emptyArray, spyEnhancer)
			local action = addTodo("Hello")
			store.dispatch(action)

			expect(deepEquals(store.getState(), {
				{
					id = 1,
					text = "Hello",
				},
			})).to.equal(true)
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
				local fakeError = spy()

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

				expect(#fakeError.calls).to.equal(0)
			end
		)

		it("throws if passing several enhancer functions without preloaded state", function()
			local rootReducer = Redux.combineReducers(reducers)
			local dummyEnhancer = function(f: any)
				return f
			end

			expect(function()
				Redux.createStore(rootReducer, dummyEnhancer, dummyEnhancer)
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
