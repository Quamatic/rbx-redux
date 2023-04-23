local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Redux = require(ReplicatedStorage.Redux)
local Promise = require(ReplicatedStorage.Redux.Promise)

local spy = require(script.Parent.helpers.spy)
local noop = require(script.Parent.helpers.noop)
local deepEquals = require(script.Parent.helpers.deepEquals)

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
				function(_arg: number, extra: { requestId: string })
					generatedRequestId = extra.requestId
					error("Panic!")
				end
			)

			local thunkFunction = thunkActionCreator(args)
			thunkFunction(dispatch.fn, noop, nil):expect()

			expect(dispatch.wasNthCalledWith(1, thunkActionCreator.pending(generatedRequestId, args)))
			expect(dispatch.wasNthExactlyCalled(2))

			local errorAction = dispatch.calls[2][1]
			expect(errorAction.error).to.be.a("string")
			expect(errorAction.meta.requestId).to.equal(generatedRequestId)
			expect(errorAction.meta.arg).to.equal(args)
		end)
	end)

	describe("createAsyncThunk with cancellation", function()
		local asyncThunk = Redux.createAsyncThunk("test", function(_: any, thunkAPI)
			return Promise.new(function(resolve, reject)
				--[[if thunkAPI.signal then
					reject("This should never be reached as it should already be handled.")
				end]]
				--

				thunkAPI.signal.subscribe(function()
					reject("Was aborted while running")
				end)

				task.delay(100 / 1000, resolve)
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
			promise:cancel("AbortReason")

			local result = promise:expect()

			expect(deepEquals(store.getState(), {
				{},
				{ type = "test/pending" },
				{ error = "-- Promise.Error(ExecutionError) -- " },
			}))

			expect(function()
				Redux.unwrapResult(result)
			end).to.throw()
		end)

		it(
			"even when the payloadCreator does not directly support the signal, no further actions are dispatched",
			function()
				local unawareAsyncThunk = Redux.createAsyncThunk("unaware", function()
					Promise.delay(100 / 1000):expect()
					return "finished"
				end)

				local promise = store.dispatch(unawareAsyncThunk())
				promise:cancel("AbortReason")

				local result = promise:expect()
				local expectedAbortAction = {
					type = "unaware/rejected",
					meta = {
						rejectedWithValue = false,
						requestId = result.meta.requestId,
						requestStatus = "rejected",
						condition = false,
					},
					error = "AbortReason",
				}

				expect(deepEquals(result, expectedAbortAction)).to.equal(true)

				expect(function()
					Redux.unwrapResult(result)
				end).to.throw()
			end
		)

		it("dispatch(asyncThunk) returns on abort and does not wait for the promiseProvider to finish", function()
			local running = false

			local longRunningAsyncThunk = Redux.createAsyncThunk("longRunning", function()
				running = true
				return Promise.delay(30000 / 1000):andThen(function()
					running = false
				end)
			end)

			local promise = store.dispatch(longRunningAsyncThunk())
			expect(running).to.equal(true)

			promise:cancel()

			local result = promise:expect()
			expect(running).to.equal(true)

			local expectedAbortAction = {
				type = "longRunning/rejected",
				error = "Aborted",
				meta = {
					rejectedWithValue = false,
					requestStatus = "rejected",
					requestId = result.meta.requestId,
					condition = false,
				},
			}

			expect(deepEquals(result, expectedAbortAction)).to.equal(true)
		end)
	end)

	describe("conditional skipping of asyncThunks", function()
		local arg = {}

		local getState = spy(function()
			return {}
		end)

		local dispatch = spy(function(x)
			return x
		end)

		local payloadCreator = spy(function(x: typeof(arg))
			return 10
		end)

		local condition = spy(function()
			return false
		end)

		local extra = {}

		beforeEach(function()
			getState.clear()
			dispatch.clear()
			payloadCreator.clear()
			condition.clear()
		end)

		it("returning false from condition skips payloadCreator and returns a rejected action", function()
			local asyncThunk = Redux.createAsyncThunk("test", payloadCreator.fn, { condition = condition.fn })
			local result = asyncThunk(arg)(dispatch.fn, getState.fn, extra):expect()

			expect(condition.hasBeenCalled()).to.equal(true)
			expect(payloadCreator.hasBeenCalled()).to.equal(false)
			expect(asyncThunk.rejected.match(result)).to.equal(true)
			expect((result :: any).meta.condition).to.equal(true)
		end)

		it("returning true from condition executes payloadCreator", function()
			condition.setReturnValueOnce(true)

			local asyncThunk = Redux.createAsyncThunk("test", payloadCreator.fn, { condition = condition.fn })
			local result = asyncThunk(arg)(dispatch.fn, getState.fn, extra):expect()

			expect(condition.hasBeenCalled()).to.equal(true)
			expect(payloadCreator.hasBeenCalled()).to.equal(true)
			expect(asyncThunk.fulfilled.match(result)).to.equal(true)
			expect(result.payload).to.equal(10)
		end)

		it("condition is called with arg, getState and extra", function()
			local asyncThunk = Redux.createAsyncThunk("test", payloadCreator.fn, { condition = condition.fn })
			asyncThunk(arg)(dispatch.fn, getState.fn, extra):expect()

			expect(condition.wasNthExactlyCalled(1)).to.equal(true)
			expect(condition.wasLastCalledWith(arg, { getState = getState.fn, extra = extra })).to.equal(true)
		end)

		--[[it("pending is dispatched synchronously if condition is synchronous", function()
			local condition_ = function()
				return true
			end

			local asyncThunk = Redux.createAsyncThunk("test", payloadCreator.fn, { condition = condition_ })
			local thunkCallPromise = asyncThunk(arg)(dispatch.fn, getState.fn, extra)

			expect(dispatch.wasNthExactlyCalled(1)).to.equal(true)
			thunkCallPromise:await()
			expect(dispatch.wasNthExactlyCalled(2)).to.equal(true)
		end)]]
		--

		it("async condition", function()
			local condition_ = function()
				return Promise.resolve(false)
			end

			local asyncThunk = Redux.createAsyncThunk("test", payloadCreator.fn, { condition = condition_ })
			asyncThunk(arg)(dispatch.fn, getState.fn, extra):expect()

			expect(dispatch.wasNthExactlyCalled(0)).to.equal(true)
		end)

		it("async condition with rejected promise", function()
			local condition_ = function()
				return Promise.reject()
			end

			local asyncThunk = Redux.createAsyncThunk("test", payloadCreator.fn, { condition = condition_ })
			asyncThunk(arg)(dispatch.fn, getState.fn, extra):expect()

			expect(dispatch.wasNthExactlyCalled(1)).to.equal(true)
			expect(dispatch.wasLastCalledWith({ type = "test/rejected" })).to.equal(true)
		end)

		it("async condition with abort signal first", function()
			local condition_ = function()
				return Promise.delay(25 / 1000):andThenReturn(true)
			end

			local asyncThunk = Redux.createAsyncThunk("test", payloadCreator.fn, { condition = condition_ })
			local thunkPromise = asyncThunk(arg)(dispatch.fn, getState.fn, extra)

			thunkPromise:cancel()
			thunkPromise:expect()

			expect(dispatch.wasNthExactlyCalled(0)).to.equal(true)
		end)

		it("rejected action is not dispatched by default", function()
			local asyncThunk = Redux.createAsyncThunk("test", payloadCreator.fn, { condition = condition.fn })
			asyncThunk(arg)(dispatch.fn, getState.fn, extra):expect()

			expect(dispatch.wasNthExactlyCalled(0)).to.equal(true)
		end)

		it("does not fail when attempting to abort a canceled promise", function()
			local asyncPayloadCreator = spy(function(x: typeof(arg))
				return Promise.delay(200 / 1000):andThenReturn(10)
			end)

			local asyncThunk = Redux.createAsyncThunk("test", asyncPayloadCreator, {
				condition = condition,
			})

			local promise = asyncThunk(arg)(dispatch.fn, getState.fn, extra)
			promise:cancel(
				"`If the promise was 1. somehow canceled, 2. in a 'started' state and 3. we attempted to abort, this would crash the tests"
			)
		end)

		it("rejected action can be dispatched via option", function()
			local asyncThunk = Redux.createAsyncThunk("test", payloadCreator, {
				condition = condition,
				dispatchConditionRejection = true,
			})

			local result = asyncThunk(arg)(dispatch.fn, getState.fn, extra):expect()

			expect(dispatch.wasNthExactlyCalled(1)).to.equal(true)
			expect(dispatch.wasLastCalledWith({
				error = "Aborted due to condition callback returning false.",
				meta = {
					arg = arg,
					rejectedWithValue = false,
					condition = true,
					requestId = result.meta.requestId,
					requestStatus = "rejected",
				},
				payload = nil,
				type = "test/rejected",
			}))
		end)
	end)

	describe("idGenerator option", function()
		local getState = function()
			return {}
		end

		local dispatch = function(x: any)
			return x
		end

		local extra = {}

		it("idGenerator implementation - can customizes how request IDs are generated", function()
			local function makeFakeIdGenerator()
				local id = 0
				return spy(function()
					id += 1
					return `fake-random-id-{id}`
				end).fn
			end

			local generatedRequestId = ""

			local idGenerator = makeFakeIdGenerator()
			local asyncThunk = Redux.createAsyncThunk("test", function(args, api)
				generatedRequestId = api.requestId
			end, { idGenerator = idGenerator })

			local promise0 = asyncThunk()(dispatch, getState, extra)
			expect(generatedRequestId).to.equal("fake-random-id-1")
			expect(promise0.requestId).to.equal("fake-random-id-1")
			expect(promise0:expect().meta.requestId).to.equal("fake-random-id-1")

			local promise1 = asyncThunk()(dispatch, getState, extra)
			expect(generatedRequestId).to.equal("fake-random-id-2")
			expect(promise1.requestId).to.equal("fake-random-id-2")
			expect(promise1:expect().meta.requestId).to.equal("fake-random-id-2")

			local promise2 = asyncThunk()(dispatch, getState, extra)
			expect(generatedRequestId).to.equal("fake-random-id-3")
			expect(promise2.requestId).to.equal("fake-random-id-3")
			expect(promise2:expect().meta.requestId).to.equal("fake-random-id-3")

			generatedRequestId = ""
			local defaultAsyncThunk = Redux.createAsyncThunk("test", function(args, api)
				generatedRequestId = api.requestId
			end)

			local promise3 = defaultAsyncThunk()(dispatch, getState, extra)
			expect(generatedRequestId).to.equal(promise3.requestId)
			expect(promise3.requestId).never.to.equal("")
			expect(promise3.requestId:find("fake-random-id")).never.to.be.ok()

			expect(promise3:expect().meta.requestId:find("fake-random-id")).never.to.be.ok()
		end)

		it("idGenerator should be called with thunkArg", function()
			local customIdGenerator = spy(function(seed)
				return `fake-unique-random-id-{seed}`
			end)

			local generatedRequestId = ""
			local asyncThunk = Redux.createAsyncThunk("test", function(args, api)
				generatedRequestId = api.requestId
			end, { idGenerator = customIdGenerator.fn })

			local thunkArg = 1
			local expected = "fake-unique-random-id-1"
			local asyncThunkPromise = asyncThunk(thunkArg)(dispatch, getState, extra)

			expect(customIdGenerator.wasCalledWith(thunkArg))
			expect(asyncThunkPromise.requestId).to.equal(expected)
			expect(asyncThunkPromise:expect().meta.requestId).to.equal(expected)
		end)
	end)

	describe("`condition` will see state changes from a synchronously invoked asyncThunk", function()
		local onStart = spy()

		local asyncThunk = Redux.createAsyncThunk("test", onStart.fn, {
			condition = function(arg, api)
				return arg.force or not api.getState().started
			end,
		})

		local store = Redux.configureStore({
			reducer = Redux.createReducer({ started = false }, function(builder)
				builder.addCase(asyncThunk.pending, function(state)
					state = table.clone(state)
					state.started = true
					return state
				end)
			end),
		})

		store.dispatch(asyncThunk({ force = false }))
		expect(onStart.wasNthExactlyCalled(1)).to.equal(true)
		store.dispatch(asyncThunk({ force = false }))
		expect(onStart.wasNthExactlyCalled(1)).to.equal(true)
		store.dispatch(asyncThunk({ force = true }))
		expect(onStart.wasNthExactlyCalled(2)).to.equal(true)
	end)

	describe("meta", function()
		local getNewStore = function()
			return Redux.configureStore({
				reducer = function(actions, action)
					actions = actions or {}
					actions = table.clone(actions)

					table.insert(actions, action)
					return actions
				end,
			})
		end

		local store

		beforeEach(function()
			store = getNewStore()
		end)

		it("pendingMeta", function()
			local pendingThunk = Redux.createAsyncThunk("test", function(arg: string)
				return {}
			end, {
				getPendingMeta = function(meta)
					expect(meta.arg).to.equal("testArg")
					expect(meta.requestId).to.be.a("string")
					return { extraProp = "foo" }
				end,
			})

			local ret = store.dispatch(pendingThunk("testArg"))

			expect(deepEquals(store.getState()[2], {
				meta = {
					arg = "testArg",
					extraProp = "foo",
					requestId = ret.requestId,
					requestStatus = "pending",
				},
				payload = nil,
				type = "test/pending",
			})).to.equal(true)
		end)

		it("fulfilledMeta", function()
			local fulfilledThunk = Redux.createAsyncThunk("test", function(arg: string, thunkAPI)
				return thunkAPI.fulfillWithValue("hooray!", { extraProp = "bar" })
			end)

			local ret = store.dispatch(fulfilledThunk("testArg"))

			expect(deepEquals(ret:expect(), {
				meta = {
					arg = "testArg",
					extraProp = "bar",
					requestId = ret.requestId,
					requestStatus = "fulfilled",
				},
				payload = "hooray!",
				type = "test/fulfilled",
			})).to.equal(true)
		end)

		it("rejectedMeta", function()
			local fulfilledThunk = Redux.createAsyncThunk("test", function(arg: string, thunkAPI)
				return thunkAPI.rejectWithValue("dangit!", { extraProp = "baz" })
			end)

			local promise = store.dispatch(fulfilledThunk("testArg"))
			local ret = promise:expect()

			expect(deepEquals(ret, {
				meta = {
					arg = "testArg",
					extraProp = "baz",
					requestId = promise.requestId,
					requestStatus = "rejected",
					rejectedWithValue = true,
					condition = false,
				},
				error = "Rejected",
				payload = "dangit!",
				type = "test/rejected",
			})).to.equal(true)
		end)
	end)
end
