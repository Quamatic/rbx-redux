local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Redux = require(ReplicatedStorage.Redux)
local Promise = require(ReplicatedStorage.Redux.Promise)

local spy = require(script.Parent.helpers.spy)
local noop = require(script.Parent.helpers.noop)

return function()
	describe("createAsyncThunk", function()
		it("creates the action types", function()
			local thunkActionCreator = Redux.createAsyncThunk("testType", function()
				return 42
			end)

			expect(thunkActionCreator.fulfilled.type).to.equal("testType/fulfilled")
			expect(thunkActionCreator.pending.type).to.equal("testType/pending")
			expect(thunkActionCreator.rejected.type).to.equal("testType/rejected")
		end)

		it("exposes the typePrefix it was created with", function()
			local thunkActionCreator = Redux.createAsyncThunk("testType", function()
				return 42
			end)

			expect(thunkActionCreator.typePrefix).to.equal("testType")
		end)

		it("works without passing arguments to the payload creator", function()
			local thunkActionCreator = Redux.createAsyncThunk("testType", function()
				return 42
			end)

			local timesReducerCalled = 0
			local reducer = function(_, action)
				timesReducerCalled += 1
			end

			local store = Redux.configureStore({
				reducer = reducer,
			})

			-- Reset to 0 cause of init method
			timesReducerCalled = 0

			store.dispatch(thunkActionCreator()):await()
			expect(timesReducerCalled).to.equal(2)
		end)

		it("accepts arguments and dispatches the actions on resolve", function()
			local dispatch = spy()

			local passedArg: any

			local result = 42
			local args = 123
			local generatedRequestId = ""

			local thunkActionCreator = Redux.createAsyncThunk(
				"testType",
				function(arg: number, extra: { requestId: string })
					passedArg = arg
					generatedRequestId = extra.requestId
					return result
				end
			)

			local thunkFunction = thunkActionCreator(args)
			local thunkPromise = thunkFunction(dispatch.fn, noop, nil)

			expect(thunkPromise.requestId).to.equal(generatedRequestId)
			expect(thunkPromise.arg).to.equal(args)

			thunkPromise:expect()

			expect(passedArg).to.equal(args)

			expect(dispatch.wasNthCalledWith(1, thunkActionCreator.pending(generatedRequestId, args))).to.equal(true)
			expect(dispatch.wasNthCalledWith(2, thunkActionCreator.fulfilled(result, generatedRequestId, args))).to.equal(
				true
			)
		end)

		it("accepts arguments and dispatches the actions on reject", function()
			local dispatch = spy()

			local args = 123
			local generatedRequestId = ""

			local thunkActionCreator = Redux.createAsyncThunk(
				"testType",
				function(arg: number, extra: { requestId: string })
					generatedRequestId = extra.requestId
					error("Panic!")
				end
			)

			local thunkFunction = thunkActionCreator(args)
			thunkFunction(dispatch.fn, noop, nil):expect()

			expect(dispatch.wasNthCalledWith(1, thunkActionCreator.pending(generatedRequestId, args)))
			expect(dispatch.wasNthExactlyCalled(2))

			local errorAction = dispatch.calls[2][1]
			print(errorAction.error)

			expect(errorAction.meta.requestId).to.equal(generatedRequestId)
			expect(errorAction.meta.arg).to.equal(args)
		end)
	end)

	describe("createAsyncThunk with abortController", function()
		local asyncThunk = Redux.createAsyncThunk("test", function(_: any, api)
			return Promise.new(function(resolve, reject)
				if api.aborted then
					reject("This should never be reached as it should already be handled.")
				end

				api.onAborted(function()
					reject("Was aborted while running")
				end)

				task.delay(resolve, 0.1)
			end)
		end)

		local store = Redux.configureStore({
			reducer = function(state)
				state = state or {}
				return state
			end,
		})

		beforeEach(function()
			store = Redux.configureStore({
				reducer = function(state, action)
					state = state or {}

					local new = table.clone(state)
					table.insert(new, action)

					return new
				end,
			})
		end)

		it("normal usage", function()
			store.dispatch(asyncThunk({})):expect()

			expect(store.getState())
		end)

		it("abort after dispatch", function()
			local promise = store.dispatch(asyncThunk({}))
			local result = promise:await()
		end)
	end)
end
