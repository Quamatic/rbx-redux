local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Redux = require(ReplicatedStorage.Redux)

local thunkMiddleware = Redux.thunkMiddleware
local withExtraArgument = Redux.createThunkMiddleware

return function()
	describe("thunkMiddleware", function()
		local doDispatch = function() end
		local doGetState = function()
			return 42
		end

		local nextHandler = thunkMiddleware({
			dispatch = doDispatch,
			getState = doGetState,
		})

		it("must return a function to handle next", function()
			expect(nextHandler).to.be.a("function")
		end)

		describe("handle next", function()
			it("must return a function to handle action", function()
				local actionHandler = nextHandler()
				expect(actionHandler).to.be.a("function")
			end)

			describe("handle action", function()
				it("must run the given action function with dispatch and getState", function()
					local actionHandler = nextHandler()

					actionHandler(function(dispatch, getState)
						expect(dispatch).to.equal(doDispatch)
						expect(getState).to.equal(doGetState)
					end)
				end)

				it("must pass action to next if not a function", function()
					local actionObj = {}

					local actionHandler = nextHandler(function(action)
						expect(action).to.equal(actionObj)
					end)

					actionHandler(actionObj)
				end)

				it("must return the return value of next if not a function", function()
					local expected = "redux"
					local actionHandler = nextHandler(function()
						return expected
					end)

					local outcome = actionHandler()
					expect(outcome).to.equal(expected)
				end)

				it("must return value as expected if a function", function()
					local expected = "rocks"
					local actionHandler = nextHandler()

					local outcome = actionHandler(function()
						return expected
					end)

					expect(outcome).to.equal(expected)
				end)

				it("must be invoked synchronously if a function", function()
					local actionHandler = nextHandler()
					local mutated = 0

					actionHandler(function()
						mutated += 1
					end)

					expect(mutated).to.equal(1)
				end)
			end)
		end)

		describe("handle errors", function()
			it("must throw if argument is non-object", function()
				expect(function()
					thunkMiddleware()
				end).to.throw()
			end)
		end)

		describe("withExtraArgument", function()
			it("must pass the third argument", function()
				local extraArg = { lol = true }

				withExtraArgument(extraArg)({
					dispatch = doDispatch,
					getState = doGetState,
				})()(function(dispatch, getState, arg)
					expect(dispatch).to.equal(doDispatch)
					expect(getState).to.equal(getState)
					expect(arg).to.equal(extraArg)
				end)
			end)
		end)
	end)
end
