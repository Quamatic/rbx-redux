local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Redux = require(ReplicatedStorage.Redux)

local deepEquals = require(script.Parent.helpers.deepEquals)
local noop = require(script.Parent.helpers.noop)

type Todo = {
	text: string,
	completed: boolean?,
}

-- Have to pass it and expect because TestEZ cant act outside of the scope needed
local function behavesLikeReducer(todosReducer, it, expect)
	it("should handle initial state", function()
		local initialAction = { type = "", payload = nil }
		local result = todosReducer(nil, initialAction)

		expect(result).to.be.a("table")
		expect(#result).to.equal(0)
	end)

	it("should handle ADD_TODO", function()
		expect(deepEquals(
			todosReducer({}, {
				type = "ADD_TODO",
				payload = { newTodo = { text = "Run the tests" } },
			}),
			{
				{
					text = "Run the tests",
					completed = false,
				},
			}
		)).to.equal(true)

		expect(deepEquals(
			todosReducer({
				{
					text = "Run the tests",
					completed = false,
				},
			}, {
				type = "ADD_TODO",
				payload = { newTodo = { text = "Use Redux" } },
			}),
			{
				{
					text = "Run the tests",
					completed = false,
				},
				{
					text = "Use Redux",
					completed = false,
				},
			}
		)).to.equal(true)

		expect(deepEquals(
			todosReducer({
				{
					text = "Run the tests",
					completed = false,
				},
				{
					text = "Use Redux",
					completed = false,
				},
			}, {
				type = "ADD_TODO",
				payload = { newTodo = { text = "Fix the tests" } },
			}),
			{
				{
					text = "Run the tests",
					completed = false,
				},
				{
					text = "Use Redux",
					completed = false,
				},
				{
					text = "Fix the tests",
					completed = false,
				},
			}
		)).to.equal(true)
	end)

	it("should handle TOGGLE_TODO", function()
		expect(deepEquals(
			todosReducer({
				{
					text = "Run the tests",
					completed = false,
				},
				{
					text = "Use Redux",
					completed = false,
				},
			}, {
				type = "TOGGLE_TODO",
				payload = { index = 1 },
			}),
			{
				{
					text = "Run the tests",
					completed = true,
				},
				{
					text = "Use Redux",
					completed = false,
				},
			}
		)).to.equal(true)
	end)
end

return function()
	describe("createReducer", function()
		local addTodo = function(state, action)
			local newTodo = table.clone(action.payload.newTodo)
			newTodo.completed = false

			local copy = table.clone(state)
			table.insert(copy, newTodo)

			return copy
		end

		local toggleTodo = function(state, action)
			local index = action.payload.index

			local copy = table.clone(state)
			local todo = copy[index]

			if todo == nil then
				return copy
			end

			todo = table.clone(todo)
			todo.completed = not todo.completed

			copy[index] = todo

			return copy
		end

		describe("given pure reducers with immutable updates", function()
			local todosReducer = Redux.createReducer({}, {
				ADD_TODO = addTodo,
				TOGGLE_TODO = toggleTodo,
			})

			behavesLikeReducer(todosReducer, it, expect)
		end)

		describe("accepts a lazy state init function to generate initial state", function()
			local lazyStateInit = function()
				return {}
			end

			local todosReducer = Redux.createReducer(lazyStateInit, {
				ADD_TODO = addTodo,
				TOGGLE_TODO = toggleTodo,
			})

			behavesLikeReducer(todosReducer, it, expect)
		end)

		describe("actionMatchers argument", function()
			local prepareNumberAction = function(payload: number)
				return {
					payload = payload,
					meta = {
						type = "number_action",
					},
				}
			end

			local prepareStringAction = function(payload: string)
				return {
					payload = payload,
					meta = {
						type = "string_action",
					},
				}
			end

			local numberActionMatcher = function(a)
				return a.meta ~= nil and a.meta.type == "number_action"
			end

			local stringActionMatcher = function(a)
				return a.meta ~= nil and a.meta.type == "string_action"
			end

			local incrementBy = Redux.createAction("increment", prepareNumberAction)
			local decrementBy = Redux.createAction("decrement", prepareNumberAction)
			local concatWith = Redux.createAction("concat", prepareStringAction)

			local initialState = { numberActions = 0, stringActions = 0 }
			local numberActionsCounter = {
				matcher = numberActionMatcher,
				reducer = function(state)
					state = table.clone(state)
					state.numberActions = state.numberActions * 10 + 1
					return state
				end,
			}

			local stringActionsCounter = {
				matcher = stringActionMatcher,
				reducer = function(state)
					state = table.clone(state)
					state.stringActions = state.stringActions * 10 + 1
					return state
				end,
			}

			it("uses the reducer of matching actionMatchers", function()
				local reducer = Redux.createReducer(initialState, {}, {
					numberActionsCounter,
					stringActionsCounter,
				})

				expect(deepEquals(reducer(nil, incrementBy(1)), {
					numberActions = 1,
					stringActions = 0,
				})).to.equal(true)

				expect(deepEquals(reducer(nil, decrementBy(1)), {
					numberActions = 1,
					stringActions = 0,
				})).to.equal(true)

				expect(deepEquals(reducer(nil, concatWith("foo")), {
					numberActions = 0,
					stringActions = 1,
				})).to.equal(true)
			end)

			it("fallbacks to default case", function()
				local reducer = Redux.createReducer(initialState, {}, {
					numberActionsCounter,
					stringActionsCounter,
				}, function(state)
					state = table.clone(state)

					state.numberActions = -1
					state.stringActions = -1

					return state
				end)

				expect(deepEquals(reducer(nil, { type = "somethingElse" }), {
					numberActions = -1,
					stringActions = -1,
				})).to.equal(true)
			end)

			it("runs reducer cases followed by all matching actionMatchers", function()
				local reducer = Redux.createReducer(initialState, {
					[incrementBy.type] = function(state)
						state = table.clone(state)
						state.numberActions = state.numberActions * 10 + 2
						return state
					end,
				}, {
					{
						matcher = numberActionMatcher,
						reducer = function(state)
							state = table.clone(state)
							state.numberActions = state.numberActions * 10 + 3
							return state
						end,
					},
					numberActionsCounter,
					stringActionsCounter,
				})

				expect(deepEquals(reducer(nil, incrementBy(1)), {
					numberActions = 231,
					stringActions = 0,
				})).to.equal(true)

				expect(deepEquals(reducer(nil, decrementBy(1)), {
					numberActions = 31,
					stringActions = 0,
				})).to.equal(true)

				expect(deepEquals(reducer(nil, concatWith("foo")), {
					numberActions = 0,
					stringActions = 1,
				})).to.equal(true)
			end)

			it("works with `actionCreator.match`", function()
				local reducer = Redux.createReducer(initialState, {}, {
					{
						matcher = incrementBy.match,
						reducer = function(state)
							state = table.clone(state)
							state.numberActions += 100
							return state
						end,
					},
				})

				expect(deepEquals(reducer(nil, incrementBy(1)), {
					numberActions = 100,
					stringActions = 0,
				})).to.equal(true)
			end)
		end)

		describe("alternative builder callback for actionMap", function()
			local increment = Redux.createAction("increment")
			local decrement = Redux.createAction("decrement")

			it("can be used with ActionCreators", function()
				local reducer = Redux.createReducer(0, function(builder)
					builder
						.addCase(increment, function(state, action)
							return state + action.payload
						end)
						.addCase(decrement, function(state, action)
							return state - action.payload
						end)
				end)

				expect(reducer(0, increment(5))).to.equal(5)
				expect(reducer(5, decrement(5))).to.equal(0)
			end)

			it("can be used with string types", function()
				local reducer = Redux.createReducer(0, function(builder)
					builder
						.addCase("increment", function(state, action)
							return state + action.payload
						end)
						.addCase("decrement", function(state, action)
							return state - action.payload
						end)
				end)

				expect(reducer(0, increment(5))).to.equal(5)
				expect(reducer(5, decrement(5))).to.equal(0)
			end)

			it("can be used with ActionCreators and string types combined", function()
				local reducer = Redux.createReducer(0, function(builder)
					builder
						.addCase(increment, function(state, action)
							return state + action.payload
						end)
						.addCase("decrement", function(state, action)
							return state - action.payload
						end)
				end)

				expect(reducer(0, increment(5))).to.equal(5)
				expect(reducer(5, decrement(5))).to.equal(0)
			end)

			--[[it("allows you to return nil if the state was nil, thus skipping an update", function()
				itSKIP("returning nil when the state is nil has wrong behavior")

				local reducer = Redux.createReducer(nil, function(builder)
					builder.addCase("decrement", function(state, action)
						if typeof(state) == "number" then
							return state - action.payload
						end
						return nil
					end)
				end)

				expect(reducer(0, decrement(5))).to.equal(-5)
				expect(reducer(nil, decrement(5))).to.equal(nil)
			end)

			it("allows you to return nil", function()
				itSKIP("returning nil defaults to previous state")

				local reducer = Redux.createReducer(nil, function(builder)
					builder.addCase("decrement", function(state, action)
						return nil
					end)
				end)

				expect(reducer(5, decrement(5))).to.equal(nil)
			end)]]
			--

			it("allows you to return 0", function()
				local reducer = Redux.createReducer(nil, function(builder)
					builder.addCase("decrement", function(state, action)
						return state - action.payload
					end)
				end)

				expect(reducer(5, decrement(5))).to.equal(0)
			end)

			it("will throw if the same type is used twice", function()
				expect(function()
					Redux.createReducer(0, function(builder)
						local op = function(state, action)
							return state + action.payload
						end

						builder.addCase(increment, op).addCase(increment, op).addCase(increment, op)
					end)
				end).to.throw()

				expect(function()
					Redux.createReducer(0, function(builder)
						builder
							.addCase(increment, function(state, action)
								return state + action.payload
							end)
							.addCase("increment", function(state, action)
								return state + 1
							end)
							.addCase(decrement, function(state, action)
								return state - action.payload
							end)
					end)
				end).to.throw()
			end)
		end)

		describe('builder "addMatcher" method', function()
			local prepareNumberAction = function(payload: number)
				return {
					payload = payload,
					meta = {
						type = "number_action",
					},
				}
			end

			local prepareStringAction = function(payload: string)
				return {
					payload = payload,
					meta = {
						type = "string_action",
					},
				}
			end

			local numberActionMatcher = function(a)
				return a.meta ~= nil and a.meta.type == "number_action"
			end

			local stringActionMatcher = function(a)
				return a.meta ~= nil and a.meta.type == "string_action"
			end

			local incrementBy = Redux.createAction("increment", prepareNumberAction)
			local decrementBy = Redux.createAction("decrement", prepareNumberAction)
			local concatWith = Redux.createAction("concat", prepareStringAction)

			local initialState = { numberActions = 0, stringActions = 0 }

			it("uses the reducer of matching actionMatchers", function()
				local reducer = Redux.createReducer(initialState, function(builder)
					builder
						.addMatcher(numberActionMatcher, function(state)
							state = table.clone(state)
							state.numberActions += 1
							return state
						end)
						.addMatcher(stringActionMatcher, function(state)
							state = table.clone(state)
							state.stringActions += 1
							return state
						end)
				end)

				expect(deepEquals(reducer(nil, incrementBy(1)), {
					numberActions = 1,
					stringActions = 0,
				})).to.equal(true)

				expect(deepEquals(reducer(nil, decrementBy(1)), {
					numberActions = 1,
					stringActions = 0,
				})).to.equal(true)

				expect(deepEquals(reducer(nil, concatWith("foo")), {
					numberActions = 0,
					stringActions = 1,
				})).to.equal(true)
			end)

			it("falls back to defaultCase", function()
				local reducer = Redux.createReducer(initialState, function(builder)
					builder
						.addCase(concatWith, function(state)
							state = table.clone(state)
							state.stringActions += 1
							return state
						end)
						.addMatcher(numberActionMatcher, function(state)
							state = table.clone(state)
							state.numberActions += 1
							return state
						end)
						.addDefaultCase(function(state)
							state = table.clone(state)
							state.numberActions = -1
							state.stringActions = -1
							return state
						end)
				end)

				expect(deepEquals(reducer(nil, { type = "somethingElse" }), {
					numberActions = -1,
					stringActions = -1,
				})).to.equal(true)
			end)

			it("runs reducer cases followed by all matching actionMatchers", function()
				local reducer = Redux.createReducer(initialState, function(builder)
					builder
						.addCase(incrementBy, function(state)
							state = table.clone(state)
							state.numberActions = state.numberActions * 10 + 1
							return state
						end)
						.addMatcher(numberActionMatcher, function(state)
							state = table.clone(state)
							state.numberActions = state.numberActions * 10 + 2
							return state
						end)
						.addMatcher(stringActionMatcher, function(state)
							state = table.clone(state)
							state.stringActions = state.stringActions * 10 + 1
							return state
						end)
						.addMatcher(numberActionMatcher, function(state)
							state = table.clone(state)
							state.numberActions = state.numberActions * 10 + 3
							return state
						end)
				end)

				expect(deepEquals(reducer(nil, incrementBy(1)), {
					numberActions = 123,
					stringActions = 0,
				})).to.equal(true)

				expect(deepEquals(reducer(nil, decrementBy(1)), {
					numberActions = 23,
					stringActions = 0,
				})).to.equal(true)

				expect(deepEquals(reducer(nil, concatWith("foo")), {
					numberActions = 0,
					stringActions = 1,
				})).to.equal(true)
			end)

			it("works with `actionCreator.match", function()
				local reducer = Redux.createReducer(initialState, function(builder)
					builder.addMatcher(incrementBy.match, function(state)
						state = table.clone(state)
						state.numberActions += 100
						return state
					end)
				end)

				expect(deepEquals(reducer(nil, incrementBy(1)), {
					numberActions = 100,
					stringActions = 0,
				})).to.equal(true)
			end)

			it(
				"calling addCase, addMatcher and addDefaultCase in a nonsensical order should result in an error in development mode",
				function()
					expect(function()
						Redux.createReducer(initialState, function(builder)
							builder.addMatcher(numberActionMatcher, noop).addCase(incrementBy, noop)
						end)
					end).to.throw()

					expect(function()
						Redux.createReducer(initialState, function(builder)
							builder.addDefaultCase(noop).addCase(incrementBy, noop)
						end)
					end).to.throw()

					expect(function()
						Redux.createReducer(initialState, function(builder)
							builder.addDefaultCase(noop).addMatcher(numberActionMatcher, noop)
						end)
					end).to.throw()

					expect(function()
						Redux.createReducer(initialState, function(builder)
							builder.addDefaultCase(noop).addDefaultCase(noop)
						end)
					end).to.throw()
				end
			)
		end)
	end)
end
