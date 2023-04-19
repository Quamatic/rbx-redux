local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Redux = require(ReplicatedStorage.Redux)

local actionCreators = require(script.Parent.helpers.actionCreators)
local todos = require(script.Parent.helpers.reducers).todos

local merge = require(script.Parent.helpers.merge)
local deepEquals = require(script.Parent.helpers.deepEquals)

-- Need this because functions wont be the same
local function equalKeys(t1, t2)
	for key in t1 do
		if t2[key] == nil then
			return false
		end
	end
	return true
end

return function()
	describe("bindActionCreators", function()
		local store
		local actionCreatorFunctons

		beforeEach(function()
			store = Redux.createStore(todos)
			actionCreatorFunctons = table.clone(actionCreators)

			for key, value in actionCreatorFunctons do
				if typeof(value) ~= "function" then
					actionCreatorFunctons[key] = nil
				end
			end
		end)

		it("wraps the action creators with the dispatch function", function()
			local boundActionCreators = Redux.bindActionCreators(actionCreators, store.dispatch)
			expect(equalKeys(boundActionCreators, actionCreatorFunctons)).to.equal(true)

			local action = boundActionCreators.addTodo("Hello")
			expect(deepEquals(action, actionCreators.addTodo("Hello"))).to.equal(true)
			expect(deepEquals(store.getState(), { { id = 1, text = "Hello" } })).to.equal(true)
		end)

		it("wraps action creators transparently", function()
			local uniqueThis = {}
			local argArray = { 1, 2, 3 }

			local function actionCreator(this: any, ...)
				return { type = "UNKNOWN_ACTION", this = this, args = ... }
			end

			local boundActionCreator = Redux.bindActionCreators(actionCreator, store.dispatch)

			local boundAction = boundActionCreator(uniqueThis, argArray)
			local action = actionCreator(uniqueThis, argArray)

			expect(deepEquals(boundAction, action)).to.equal(true)
			expect(boundAction.this).to.equal(uniqueThis)
			expect(action.this).to.equal(uniqueThis)
		end)

		it("skips non-function values in the passed object", function()
			local boundActionCreators = Redux.bindActionCreators(
				merge(actionCreators, {
					foo = 42,
					bar = "baz",
					wow = nil,
					much = {},
				}),
				store.dispatch
			)

			expect(equalKeys(boundActionCreators, actionCreatorFunctons)).to.equal(true)
		end)

		it("supports wrapping a single function only", function()
			local actionCreator = actionCreators.addTodo
			local boundActionCreator = Redux.bindActionCreators(actionCreator, store.dispatch)

			local action = boundActionCreator("Hello")
			expect(deepEquals(action, actionCreator("Hello"))).to.equal(true)
			expect(deepEquals(store.getState(), { { id = 1, text = "Hello" } })).to.equal(true)
		end)

		it("throws for a nil actionCreator", function()
			expect(function()
				Redux.bindActionCreators(nil, store.dispatch)
			end).to.throw(`bindActionCreators expected an object or a function, but instead received: 'nil'`)
		end)

		it("throws for a primitive actionCreatore", function()
			expect(function()
				Redux.bindActionCreators("string", store.dispatch)
			end).to.throw(`bindActionCreators expected an object or a function, but instead received: 'string'`)
		end)
	end)
end
