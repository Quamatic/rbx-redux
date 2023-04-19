local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Redux = require(ReplicatedStorage.Redux)

local spy = require(script.Parent.helpers.spy)
local deepEquals = require(script.Parent.helpers.deepEquals)

return function()
	describe("createSlice", function()
		describe("when slice is nil", function()
			it("should throw an error", function()
				expect(function()
					Redux.createSlice({
						reducers = {
							increment = function(state)
								return state + 1
							end,
							multiply = function(state, action)
								return state * action.payload
							end,
						},
						initialState = 0,
					})
				end).to.throw()
			end)
		end)

		describe("when slice is an empty string", function()
			it("should throw an error", function()
				expect(function()
					Redux.createSlice({
						name = "",
						reducers = {
							increment = function(state)
								return state + 1
							end,
							multiply = function(state, action)
								return state * action.payload
							end,
						},
						initialState = 0,
					})
				end).to.throw()
			end)
		end)

		describe("when initial state is undefined", function()
			it("should throw an error", function()
				expect(function()
					Redux.createSlice({
						name = "",
						reducers = {},
						initialState = nil,
					})
				end).to.throw()
			end)
		end)

		describe("when passing slice", function()
			local slice = Redux.createSlice({
				reducers = {
					increment = function(state)
						return state + 1
					end,
				},
				initialState = 0,
				name = "cool",
			})

			it("should create an increment action", function()
				expect(slice.actions.increment).to.be.ok()
			end)

			it("should have the correct action for increment", function()
				expect(deepEquals(slice.actions.increment(), {
					type = "cool/increment",
					payload = nil,
				})).to.equal(true)
			end)

			it("should return the correct value from reducer", function()
				expect(slice.reducer(nil, slice.actions.increment())).to.equal(1)
			end)

			it("should include the generated case reducers", function()
				expect(slice.caseReducers).to.be.ok()
				expect(slice.caseReducers.increment).to.be.ok()
				expect(slice.caseReducers.increment).to.be.a("function")
			end)

			it("getInitialState should return the state", function()
				local initialState = 42
				local slice = Redux.createSlice({
					name = "counter",
					initialState = initialState,
					reducers = {},
				})

				expect(slice.getInitialState()).to.equal(initialState)
			end)
		end)

		describe("when initialState is a function", function()
			local initialState = function()
				return {
					user = "",
				}
			end

			local slice = Redux.createSlice({
				reducers = {
					setUserName = function(state, action)
						local new = table.clone(state)
						new.user = action.payload
						return new
					end,
				},
				initialState = initialState,
				name = "user",
			})

			it("should set the username", function()
				expect(deepEquals(slice.reducer(nil, slice.actions.setUserName("eric")), {
					user = "eric",
				})).to.equal(true)
			end)

			it("getInitialState should return the state", function()
				local initialState = function()
					return 42
				end

				local slice = Redux.createSlice({
					name = "counter",
					initialState = initialState,
					reducers = {},
				})

				expect(slice.getInitialState()).to.equal(42)
			end)
		end)

		describe("when passing extra reducers", function()
			local addMore = Redux.createAction("ADD_MORE")

			local slice = Redux.createSlice({
				name = "test",
				reducers = {
					increment = function(state)
						return state + 1
					end,
					multiply = function(state, action)
						return state * action.payload
					end,
				},
				extraReducers = {
					[addMore.type] = function(state, action)
						return state + action.payload.amount
					end,
				},
				initialState = 0,
			})

			it("should call the extra reducers when their actions are dispatched", function()
				local result = slice.reducer(10, addMore({ amount = 5 }))
				expect(result).to.equal(15)
			end)

			describe("alternative builder callback for extraReducers", function()
				local increment = Redux.createAction("increment")

				it("can be used with actionCreators", function()
					local slice = Redux.createSlice({
						name = "counter",
						initialState = 0,
						reducers = {},
						extraReducers = function(builder)
							builder.addCase(increment, function(state, action)
								return state + action.payload
							end)
						end,
					})

					expect(slice.reducer(0, increment(5))).to.equal(5)
				end)

				it("can be used with string action types", function()
					local slice = Redux.createSlice({
						name = "counter",
						initialState = 0,
						reducers = {},
						extraReducers = function(builder)
							builder.addCase("increment", function(state, action)
								return state + action.payload
							end)
						end,
					})

					expect(slice.reducer(0, increment(5))).to.equal(5)
				end)

				it("prevents the same action from being added twice", function()
					expect(function()
						local slice = Redux.createSlice({
							name = "counter",
							initialState = 0,
							reducers = {},
							extraReducers = function(builder)
								builder.addCase("increment", function(state)
									return state + 1
								end)

								builder.addCase("increment", function(state)
									return state + 1
								end)
							end,
						})

						slice.reducer(nil, { type = "unrelated" })
					end).to.throw()
				end)

				it("can be used with addMatcher and type guard functions", function()
					local slice = Redux.createSlice({
						name = "counter",
						initialState = 0,
						reducers = {},
						extraReducers = function(builder)
							builder.addMatcher(increment.match, function(state, action)
								return state + action.payload
							end)
						end,
					})

					expect(slice.reducer(0, increment(5))).to.equal(5)
				end)

				it("can be used with addDefaultCase", function()
					local slice = Redux.createSlice({
						name = "counter",
						initialState = 0,
						reducers = {},
						extraReducers = function(builder)
							builder.addDefaultCase(function(state, action)
								return state + action.payload
							end)
						end,
					})

					expect(slice.reducer(0, increment(5))).to.equal(5)
				end)
			end)
		end)

		describe("behavior with enhanced case reducers", function()
			it("should pass all arguments to the prepare function", function()
				local prepare = spy(function(payload, _somethingElse)
					return { payload = payload }
				end)

				local testSlice = Redux.createSlice({
					name = "test",
					initialState = 0,
					reducers = {
						testReducer = {
							reducer = function(s)
								return s
							end,
							prepare = prepare.fn,
						},
					},
				})

				expect(deepEquals(testSlice.actions.testReducer("a", 1), {
					type = "test/testReducer",
					payload = "a",
				})).to.equal(true)

				expect(prepare.wasCalledWith("a", 1)).to.equal(true)
			end)

			it("should call the reducer function", function()
				local reducer = spy(function()
					return 5
				end)

				local testSlice = Redux.createSlice({
					name = "test",
					initialState = 0,
					reducers = {
						testReducer = {
							reducer = reducer.fn,
							prepare = function(payload)
								return { payload = payload }
							end,
						},
					},
				})

				testSlice.reducer(0, testSlice.actions.testReducer("testPayload"))
				expect(reducer.wasCalledWith(0, { payload = "testPayload" }))
			end)
		end)

		describe("circularity", function()
			it("extraReducers can reference each other circularity", function()
				local first, second

				first = Redux.createSlice({
					name = "first",
					initialState = "firstInitial",
					reducers = {
						something = function()
							return "firstSomething"
						end,
					},
					extraReducers = function(builder)
						builder.addCase(second.actions.other, function()
							return "firstOther"
						end)
					end,
				})

				second = Redux.createSlice({
					name = "test",
					initialState = "secondInitial",
					reducers = {
						other = function()
							return "secondOther"
						end,
					},
					extraReducers = function(builder)
						builder.addCase(first.actions.something, function()
							return "secondSomething"
						end)
					end,
				})

				expect(first.reducer(nil, { type = "unrelated" })).to.equal("firstInitial")
				expect(first.reducer(nil, first.actions.something())).to.equal("firstSomething")
				expect(first.reducer(nil, second.actions.other())).to.equal("firstOther")

				expect(second.reducer(nil, { type = "unrelated" })).to.equal("secondInitial")
				expect(second.reducer(nil, first.actions.something())).to.equal("secondSomething")
				expect(second.reducer(nil, second.actions.other())).to.equal("secondOther")
			end)
		end)
	end)
end
