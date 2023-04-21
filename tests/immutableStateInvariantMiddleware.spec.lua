local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LogService = game:GetService("LogService")

local Redux = require(ReplicatedStorage.Redux)

local merge = require(script.Parent.helpers.merge)
local deepEquals = require(script.Parent.helpers.deepEquals)

return function()
	describe("createImmutableStateInvariantMiddleware", function()
		local state: { foo: { bar: { number }, baz: string } }
		local getState = function()
			return state
		end

		local function middleware(options)
			options = options or {}

			return Redux.createImmutableStateInvariantMiddleware(options)({
				getState = getState,
			})
		end

		beforeEach(function()
			state = { foo = { bar = { 2, 3, 4 }, baz = "baz" } }
		end)

		it("sends the action through the middleware chain", function()
			local nextDispatch = function(action)
				action = table.clone(action)
				action.returned = true
				return action
			end

			local dispatch = middleware()(nextDispatch)

			expect(deepEquals(dispatch({ type = "SOME_ACTON" }), {
				type = "SOME_ACTION",
				returned = true,
			}))
		end)

		it("throws if mutating inside the dispatch", function()
			local nextDispatch = function(action)
				table.insert(state.foo.bar, 5)
				return action
			end

			local dispatch = middleware()(nextDispatch)

			expect(function()
				dispatch({ type = "SOME_ACTION" })
			end).to.throw()
		end)

		it("throws if mutating between dispatches", function()
			local nextDispatch = function(action)
				return action
			end

			local dispatch = middleware()(nextDispatch)

			dispatch({ type = "SOME_ACTION" })
			table.insert(state.foo.bar, 5)

			expect(function()
				dispatch({ type = "SOME_OTHER_ACTION" })
			end).to.throw()
		end)

		it("does not throw if not mutating inside the dispatch", function()
			local nextDispatch = function(action)
				state = merge(state, { foo = merge(state.foo, { baz = "changed!" }) })
				return action
			end

			local dispatch = middleware()(nextDispatch)

			expect(function()
				dispatch({ type = "SOME_ACTION" })
			end).never.to.throw()
		end)

		it("does not throw if not mutating between dispatches", function()
			local nextDispatch = function(action)
				return action
			end

			local dispatch = middleware()(nextDispatch)
			state = merge(state, { foo = merge(state.foo, { baz = "changed!" }) })

			expect(function()
				dispatch({ type = "SOME_OTHER_ACTION" })
			end).never.to.throw()
		end)

		it("works correctly with circular references", function()
			local nextDispatch = function(action)
				return action
			end

			local dispatch = middleware()(nextDispatch)

			local x = {}
			local y = {}

			x.y = y
			y.x = x

			expect(function()
				dispatch({ type = "SOME_ACTION", x = x })
			end).never.to.throw()
		end)

		it('respects "isImmutable" option', function()
			local isImmutable = function(_value)
				return true
			end

			local nextDispatch = function(action)
				table.insert(state.foo.bar, 5)
				return action
			end

			local dispatch = middleware({ isImmutable = isImmutable })(nextDispatch)

			expect(function()
				dispatch({ type = "SOME_ACTION" })
			end).never.to.throw()
		end)

		it('respects "ignoredPaths" option', function()
			local nextDispatch = function(action)
				table.insert(state.foo.bar, 5)
				return action
			end

			local dispatch1 = middleware({ ignoredPaths = { "foo.bar" } })(nextDispatch)

			expect(function()
				dispatch1({ type = "SOME_ACTION" })
			end).never.to.throw()

			local dispatch2 =
				middleware({ ignoredPaths = { { path = "^foo", useStringPattern = true } } })(nextDispatch)

			expect(function()
				dispatch2({ type = "SOME_ACTION" })
			end).never.to.throw()
		end)

		it('alias "ignore" to "ignoredPath" and respects option', function()
			local nextDispatch = function(action)
				table.insert(state.foo.bar, 5)
				return action
			end

			local dispatch = middleware({ ignore = { "foo.bar" } })(nextDispatch)

			expect(function()
				dispatch({ type = "SOME_ACTION" })
			end).never.to.throw()
		end)

		it("should print a warning if execution takes too long", function()
			state.foo.bar = table.create(10000, { value = "more" })

			local nextDispatch = function(action)
				return action
			end

			local dispatch = middleware({ warnAfter = 4 })(nextDispatch)
			dispatch({ type = "SOME_ACTION" })
		end)

		it('Should not print a warning if "next" takes too long', function()
			local nextDispatch = function(action)
				local started = os.clock()

				while os.clock() - started < 8 do
					task.wait()
				end

				return action
			end

			local dispatch = middleware({ warnAfter = 4 })(nextDispatch)
			dispatch({ type = "SOME_ACTION" })
		end)
	end)

	describe("trackForMutations", function()
		type TestConfig = {
			getState: () -> any,
			fn: <T>(s: T) -> T | table,
			middlewareOptions: any?,
			path: { string }?,
		}

		describe("mutations", function()
			local mutations: { [string]: TestConfig } = {
				["adding to nested array"] = {
					getState = function()
						return {
							foo = {
								bar = { 2, 3, 4 },
								baz = "baz",
							},
							stuff = {},
						}
					end,
					fn = function(s)
						table.insert(s.foo.bar, 5)
						return s
					end,
					path = { "foo", "bar", 3 },
				},
				["adding to nested array and setting new root object"] = {
					getState = function()
						return {
							foo = {
								bar = { 2, 3, 4 },
								baz = "baz",
							},
							stuff = {},
						}
					end,
					fn = function(s)
						table.insert(s.foo.bar, 5)
						return table.clone(s)
					end,
					path = { "foo", "bar", 3 },
				},
				["changing nested string"] = {
					getState = function()
						return {
							foo = {
								bar = { 2, 3, 4 },
								baz = "baz",
							},
							stuff = {},
						}
					end,
					fn = function(s)
						s.foo.baz = "changed!"
						return s
					end,
					path = { "foo", "baz" },
				},
				["removing nested state"] = {
					getState = function()
						return {
							foo = {
								bar = { 2, 3, 4 },
								baz = "baz",
							},
							stuff = {},
						}
					end,
					fn = function(s)
						s.foo = nil
						return s
					end,
					path = { "foo" },
				},
				["adding to array"] = {
					getState = function()
						return {
							foo = {
								bar = { 2, 3, 4 },
								baz = "baz",
							},
							stuff = {},
						}
					end,
					fn = function(s)
						table.insert(s.stuff, 1)
						return s
					end,
					path = { "stuff", "1" },
				},
				["adding object to array"] = {
					getState = function()
						return {
							stuff = {},
						}
					end,
					fn = function(s)
						table.insert(s.stuff, { foo = 1, bar = 2 })
						return s
					end,
					path = { "stuff", "1" },
				},
				["mutating previous state and returning new state"] = {
					getState = function()
						return {
							counter = 0,
						}
					end,
					fn = function(s)
						s.mutation = true
						local new = table.clone(s)
						new.counter = s.counter + 1
						return new
					end,
					path = { "mutation" },
				},
				["mutating previous state with non immutable type and returning new state"] = {
					getState = function()
						return {
							counter = 0,
						}
					end,
					fn = function(s)
						s.mutation = { 1, 2, 3 }
						local new = table.clone(s)
						new.counter = s.counter + 1
						return new
					end,
					path = { "mutation" },
				},
				["mutating previous state with non immutable type and returning new state without that property"] = {
					getState = function()
						return {
							counter = 0,
						}
					end,
					fn = function(s)
						s.mutation = { 1, 2, 3 }
						return { counter = s.counter + 1 }
					end,
					path = { "mutation" },
				},
				["mutating previous state with non immutable type and returning new simple state"] = {
					getState = function()
						return {
							counter = 0,
						}
					end,
					fn = function(s)
						s.mutation = { 1, 2, 3 }
						return 1
					end,
					path = { "mutation" },
				},
				["mutating previous state by deleting property and returning new state without that property"] = {
					getState = function()
						return {
							counter = 0,
							toBeDeleted = true,
						}
					end,
					fn = function(s)
						s.toBeDeleted = nil
						return { counter = s.counter + 1 }
					end,
					path = { "toBeDeleted" },
				},
				["mutating previous state by deleting nested property"] = {
					getState = function()
						return {
							nested = {
								counter = 0,
								toBeDeleted = true,
							},
							foo = 1,
						}
					end,
					fn = function(s)
						s.nested.toBeDeleted = nil
						return { nested = { counter = s.nested.counter + 1 } }
					end,
					path = { "nested", "toBeDeleted" },
				},
				["update reference"] = {
					getState = function()
						return {
							foo = {},
						}
					end,
					fn = function(s)
						s.foo = {}
						return s
					end,
					path = { "foo" },
				},
				["cannot ignore root state"] = {
					getState = function()
						return {
							foo = {},
						}
					end,
					fn = function(s)
						s.foo = {}
						return s
					end,
					middlewareOptions = {
						ignoredPaths = { "" },
					},
					path = { "foo" },
				},
				["catching state mutation in non-ignored branch"] = {
					getState = function()
						return {
							foo = {
								bar = { 1, 2 },
							},
							boo = {
								yah = { 1, 2 },
							},
						}
					end,
					fn = function(s)
						table.insert(s.foo.bar, 3)
						table.insert(s.boo.yah, 3)
						return s
					end,
					middlewareOptions = {
						ignoredPaths = { "foo" },
					},
					path = { "boo", "yah", "2" },
				},
			}

			for mutationDesc, spec in mutations do
				describe(mutationDesc, function()
					it("returns true and the mutated path", function()
						local state = spec.getState()
						local options = spec.middlewareOptions or {}

						local isImmutable = options.isImmutable or Redux.isImmutableDefault
						local ignoredPaths = options.ignoredPaths

						local tracker = Redux.__INTERNAL__trackForMutations(isImmutable, ignoredPaths, state)
						local newState = spec.fn(state)

						expect(deepEquals(tracker.detectMutations(), {
							wasMutated = true,
							path = table.concat(spec.path, "."),
						}))
					end)
				end)
			end
		end)

		describe("non mutations", function()
			local nonMutations: { [string]: TestConfig } = {
				["not doing anything"] = {
					getState = function()
						return { a = 1, b = 2 }
					end,
					fn = function(s)
						return s
					end,
				},
				["from undefined to something"] = {
					getState = function()
						return nil
					end,
					fn = function(s)
						return {
							foo = "bar",
						}
					end,
				},
				["returning same state"] = {
					getState = function()
						return {
							foo = {
								bar = { 2, 3, 4 },
								baz = "baz",
							},
							stuff = {},
						}
					end,
					fn = function(s)
						return s
					end,
				},
				["returning a new state object with nested new string"] = {
					getState = function()
						return {
							foo = {
								bar = { 2, 3, 4 },
								baz = "baz",
							},
							stuff = {},
						}
					end,
					fn = function(s)
						return merge(s, { foo = merge(s.foo, { baz = "changed" }) })
					end,
				},
				["returning a new state object with nested new array"] = {
					getState = function()
						return {
							foo = {
								bar = { 2, 3, 4 },
								baz = "baz",
							},
							stuff = {},
						}
					end,
					fn = function(s)
						return merge(s, { foo = merge(s.foo, { bar = merge(s.foo.bar, 5) }) })
					end,
				},
				["removing nested state"] = {
					getState = function()
						return {
							foo = {
								bar = { 2, 3, 4 },
								baz = "baz",
							},
							stuff = {},
						}
					end,
					fn = function(s)
						return merge(s, { foo = {} })
					end,
				},
				["having a NaN in the state"] = {
					getState = function()
						return {
							a = 0 / 0,
							b = 0 / 0,
						}
					end,
					fn = function(s)
						return s
					end,
				},
				["ignoring branches from mutation detection"] = {
					getState = function()
						return {
							foo = {
								bar = "bar",
							},
						}
					end,
					fn = function(s)
						s.foo.bar = "baz"
						return s
					end,
					middlewareOptions = {
						ignoredPaths = { "foo" },
					},
				},
				["ignoring nested branches from mutation detection"] = {
					getState = function()
						return {
							foo = {
								bar = { 1, 2 },
								boo = {
									yah = { 1, 2 },
								},
							},
						}
					end,
					fn = function(s)
						table.insert(s.foo.bar, 3)
						table.insert(s.foo.boo.yah, 3)
						return s
					end,
					middlewareOptions = {
						ignoredPaths = { "foo.bar", "foo.boo.yah" },
					},
				},
				["ignoring nested array indices from mutation detection"] = {
					getState = function()
						return {
							stuff = { { a = 1 }, { a = 2 } },
						}
					end,
					fn = function(s)
						s.stuff[2].a = 3
						return s
					end,
					middlewareOptions = {
						ignoredPaths = { "stuff.2" },
					},
				},
			}

			for nonMutationDesc, spec in nonMutations do
				describe(nonMutationDesc, function()
					it("returns false", function()
						local state = spec.getState()
						local options = spec.middlewareOptions or {}

						local isImmutable = options.isImmutable or Redux.isImmutableDefault
						local ignoredPaths = options.ignoredPaths

						local tracker = Redux.__INTERNAL__trackForMutations(isImmutable, ignoredPaths, state)
						local newState = spec.fn(state)

						expect(deepEquals(tracker.detectMutations(), { wasMutated = false }))
					end)
				end)
			end
		end)
	end)
end
