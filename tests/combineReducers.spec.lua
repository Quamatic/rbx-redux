local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Redux = require(ReplicatedStorage.Redux)

return function()
	describe("Utils", function()
		describe("combineReducers", function()
			it("returns a composite reducer that maps the state keys to given reducers", function()
				local reducer = Redux.combineReducers({
					counter = function(state, action)
						state = state or 0
						return if action.type == "increment" then state + 1 else state
					end,
					stack = function(state, action)
						state = state or {}

						if action.type == "push" then
							local copy = {}

							table.move(state, 1, #state, #state + 1, copy)
							table.insert(copy, action.value)

							return copy
						else
							return state
						end
					end,
				})

				local s1 = reducer(nil, { type = "increment" })
				expect(s1).to.equal({ counter = 1, stack = {} })

				local s2 = reducer(s1, { type = "push", value = "a" })
				expect(s2).to.equal({ counter = 1, stack = { "a" } })
			end)
		end)

		it("ignores all props which are not a function", function()
			local reducer = Redux.combineReducers({
				fake = true,
				broken = "string",
				another = { nested = "object" },
				stack = function(state)
					state = state or {}
					return state
				end,
			})

			local keys = {}
			for name in reducer(nil, { type = "push" }) do
				table.insert(keys, name)
			end

			expect(keys).to.equal({ "stack" })
		end)

		it("throws an error if a reducer returns nil handling an action", function()
			local reducer = Redux.combineReducers({
				counter = function(state, action)
					state = state or 0

					if action.type == "increment" then
						return state + 1
					elseif action.type == "decrement" then
						return state - 1
					elseif action.type == "whatever" then
						return nil
					else
						return state
					end
				end,
			})

			expect(function()
				reducer({ counter = 0 }, { type = "whatever" })
			end).to.throw()

			expect(function()
				reducer({ counter = 0 }, nil)
			end).to.throw()

			expect(function()
				reducer({ counter = 0 }, {})
			end).to.throw()
		end)
	end)
end
