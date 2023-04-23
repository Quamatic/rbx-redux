local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Redux = require(ReplicatedStorage.Redux)

local Promise = require(ReplicatedStorage.Redux.Promise)

local deepEquals = require(script.Parent.helpers.deepEquals)
local spy = require(script.Parent.helpers.spy)

local thunk = function() end

return function()
	describe("matchers", function()
		describe("isAnyOf", function()
			it("returns true only if any matchers match (match function)", function()
				local actionA = Redux.createAction("a")
				local actionB = Redux.createAction("b")

				local trueAction = {
					type = "a",
					payload = "payload",
				}

				expect(Redux.isAnyOf(actionA, actionB)(trueAction)).to.equal(true)

				local falseAction = {
					type = "c",
					payload = "payload",
				}

				expect(Redux.isAnyOf(actionA, actionB)(falseAction)).to.equal(false)
			end)

			it("returns true only if any type guards match", function()
				local actionA = Redux.createAction("a")
				local actionB = Redux.createAction("b")

				local isActionA = actionA.match
				local isActionB = actionB.match

				local trueAction = {
					type = "a",
					payload = "payload",
				}

				expect(Redux.isAnyOf(isActionA, isActionB)(trueAction)).to.equal(true)

				local falseAction = {
					type = "c",
					payload = "payload",
				}

				expect(Redux.isAnyOf(isActionA, isActionB)(falseAction)).to.equal(false)
			end)

			it("returns true only if any matchers match (thunk action creators)", function()
				local thunkA = Redux.createAsyncThunk("a", function()
					return "noop"
				end)

				local thunkB = Redux.createAsyncThunk("b", function()
					return 0
				end)

				local action = thunkA.fulfilled("fakeRequestId", "test")
				expect(Redux.isAnyOf(thunkA.fulfilled, thunkB.fulfilled)(action)).to.equal(true)

				expect(Redux.isAnyOf(thunkA.pending, thunkA.rejected, thunkB.fulfilled)(action)).to.equal(false)
			end)

			it("works with reducers", function()
				local actionA = Redux.createAction("a")
				local actionB = Redux.createAction("b")

				local trueAction = {
					type = "a",
					payload = "payload",
				}

				local initialState = { value = false }

				local reducer = Redux.createReducer(initialState, function(builder)
					builder.addMatcher(Redux.isAnyOf(actionA, actionB), function(state)
						state = table.clone(state)
						state.value = true
						return state
					end)
				end)

				expect(deepEquals(reducer(initialState, trueAction), { value = true })).to.equal(true)
			end)
		end)

		describe("isAllOf", function()
			it("returns true only if all matchers match", function()
				local actionA = Redux.createAction("a")

				local isActionSpecial = function(action)
					return action.payload == "SPECIAL"
				end

				local trueAction = {
					type = "a",
					payload = "SPECIAL",
				}

				expect(Redux.isAllOf(actionA, isActionSpecial)(trueAction)).to.equal(true)

				local falseAction = {
					type = "c",
					payload = "ORDINARY",
				}

				expect(Redux.isAllOf(actionA, isActionSpecial)(falseAction)).to.equal(false)

				local thunkA = Redux.createAsyncThunk("a", function()
					return "result"
				end)

				local specialThunkAction = thunkA.fulfilled("SPECIAL", "fakeRequestId")

				expect(Redux.isAllOf(thunkA.fulfilled, isActionSpecial)(specialThunkAction)).to.equal(true)

				local ordinaryThunkAction = thunkA.fulfilled("ORDINARY", "fakeRequestId")

				expect(Redux.isAllOf(thunkA.fulfilled, isActionSpecial)(ordinaryThunkAction)).to.equal(false)
			end)
		end)

		describe("isPending", function()
			it("should return false for a regular action", function()
				local action = Redux.createAction("action/type")("testPayload")

				expect(Redux.isPending()(action)).to.equal(false)
				expect(Redux.isPending(action)).to.equal(false)
				expect(Redux.isPending(thunk)).to.equal(false)
			end)

			it("should return true only for pending async thunk actions", function()
				local thunk_ = Redux.createAsyncThunk("a", function()
					return "result"
				end)

				local pendingAction = thunk_.pending("fakeRequestId")
				expect(Redux.isPending()(pendingAction)).to.equal(true)
				expect(Redux.isPending(pendingAction)).to.equal(true)

				local rejectedAction = thunk_.rejected("rejected", "fakeRequestId")
				expect(Redux.isPending()(rejectedAction)).to.equal(false)

				local fulfilledAction = thunk_.fulfilled("result", "fakeRequestId")
				expect(Redux.isPending()(fulfilledAction)).to.equal(false)
			end)

			it("should return true only for thunks provided as arguments", function()
				local thunkA = Redux.createAsyncThunk("a", function()
					return "result"
				end)

				local thunkB = Redux.createAsyncThunk("b", function()
					return "result"
				end)

				local thunkC = Redux.createAsyncThunk("c", function()
					return "result"
				end)

				local matchAC = Redux.isPending(thunkA, thunkC)
				local matchB = Redux.isPending(thunkB)

				local function testPendingAction(thunk_, expected)
					local pendingAction = thunk_.pending("fakeRequestId")
					expect(matchAC(pendingAction)).to.equal(expected)
					expect(matchB(pendingAction)).to.equal(not expected)

					local rejectedAction = thunk_.rejected("rejected", "fakeRequestId")
					expect(matchAC(rejectedAction)).to.equal(false)

					local fulfilledAction = thunk_.fulfilled("result", "fakeRequestId")
					expect(matchAC(fulfilledAction)).to.equal(false)
				end

				testPendingAction(thunkA, true)
				testPendingAction(thunkC, true)
				testPendingAction(thunkB, false)
			end)
		end)

		describe("isRejected", function()
			it("should return false for a regular action", function()
				local action = Redux.createAction("action/type")("testPayload")

				expect(Redux.isRejected()(action)).to.equal(false)
				expect(Redux.isRejected(action)).to.equal(false)
				expect(Redux.isRejected(thunk)).to.equal(false)
			end)

			it("should return true only for rejected async thunk actions", function()
				local thunk_ = Redux.createAsyncThunk("a", function()
					return "result"
				end)

				local pendingAction = thunk_.pending("fakeRequestId")
				expect(Redux.isRejected()(pendingAction)).to.equal(false)

				local rejectedAction = thunk_.rejected("rejected", "fakeRequestId")
				expect(Redux.isRejected()(rejectedAction)).to.equal(true)
				expect(Redux.isRejected(rejectedAction)).to.equal(true)

				local fulfilledAction = thunk_.fulfilled("result", "fakeRequestId")
				expect(Redux.isRejected()(fulfilledAction)).to.equal(false)
			end)

			it("should return true only for thunks provided as arguments", function()
				local thunkA = Redux.createAsyncThunk("a", function()
					return "result"
				end)

				local thunkB = Redux.createAsyncThunk("b", function()
					return "result"
				end)

				local thunkC = Redux.createAsyncThunk("c", function()
					return "result"
				end)

				local matchAC = Redux.isRejected(thunkA, thunkC)
				local matchB = Redux.isRejected(thunkB)

				local function testRejectedAction(thunk_, expected)
					local pendingAction = thunk_.pending("fakeRequestId")
					expect(matchAC(pendingAction)).to.equal(false)

					local rejectedAction = thunk_.rejected("rejected", "fakeRequestId")
					expect(matchAC(rejectedAction)).to.equal(expected)
					expect(matchB(rejectedAction)).to.equal(not expected)

					local fulfilledAction = thunk_.fulfilled("result", "fakeRequestId")
					expect(matchAC(fulfilledAction)).to.equal(false)
				end

				testRejectedAction(thunkA, true)
				testRejectedAction(thunkC, true)
				testRejectedAction(thunkB, false)
			end)
		end)

		describe("isRejectedWithValue", function()
			it("should return false for a regular action", function()
				local action = Redux.createAction("action/type")("testPayload")

				expect(Redux.isRejectedWithValue()(action)).to.equal(false)
				expect(Redux.isRejectedWithValue(action)).to.equal(false)
				expect(Redux.isRejectedWithValue(thunk)).to.equal(false)
			end)

			it("should return true only for rejected-with-value async thunk actions", function()
				local thunk_ = Redux.createAsyncThunk("a", function(_, thunkAPI)
					return thunkAPI.rejectWithValue("rejectWithValue!")
				end)

				local pendingAction = thunk_.pending("fakeRequestId")
				expect(Redux.isRejectedWithValue()(pendingAction)).to.equal(false)

				local rejectedAction = thunk_.rejected("rejected", "fakeRequestId")
				expect(Redux.isRejectedWithValue()(rejectedAction)).to.equal(false)

				local getState = spy(function()
					return {}
				end)

				local dispatch = spy(function(x)
					return x
				end)

				local extra = {}

				local rejectedWithValueAction = thunk_()(dispatch.fn, getState.fn, extra):expect()
				expect(Redux.isRejectedWithValue()(rejectedWithValueAction)).to.equal(true)

				local fulfilledAction = thunk_.fulfilled("result", "fakeRequestId")
				expect(Redux.isRejectedWithValue()(fulfilledAction)).to.equal(false)
			end)

			it("should return true only for thunks provided as arguments", function()
				local payloadCreator = function(_, thunkAPI)
					return thunkAPI.rejectWithValue("rejectWithValue!")
				end

				local thunkA = Redux.createAsyncThunk("a", payloadCreator)
				local thunkB = Redux.createAsyncThunk("b", payloadCreator)
				local thunkC = Redux.createAsyncThunk("c", payloadCreator)

				local matchAC = Redux.isRejectedWithValue(thunkA, thunkC)
				local matchB = Redux.isRejectedWithValue(thunkB)

				local function testRejectedAction(thunk_, expected)
					local pendingAction = thunk_.pending("fakeRequestId")
					expect(matchAC(pendingAction)).to.equal(false)

					local rejectedAction = thunk_.rejected("rejected", "fakeRequestId")
					expect(matchAC(rejectedAction)).to.equal(false)

					local getState = spy(function()
						return {}
					end)

					local dispatch = spy(function(x)
						return x
					end)

					local extra = {}

					local rejectedWithValueAction = thunk_()(dispatch.fn, getState.fn, extra):expect()

					expect(matchAC(rejectedWithValueAction)).to.equal(expected)
					expect(matchB(rejectedWithValueAction)).to.equal(not expected)

					local fulfilledAction = thunk_.fulfilled("result", "fakeRequestId")
					expect(matchAC(fulfilledAction)).to.equal(false)
				end

				Promise.all({
					testRejectedAction(thunkA, true),
					testRejectedAction(thunkC, true),
					testRejectedAction(thunkB, false),
				}):expect()
			end)
		end)

		describe("isFulfilled", function()
			it("should return false for a regular action", function()
				local action = Redux.createAction("action/type")("testPayload")

				expect(Redux.isFulfilled()(action)).to.equal(false)
				expect(Redux.isFulfilled(action)).to.equal(false)
				expect(Redux.isFulfilled(thunk)).to.equal(false)
			end)

			it("should return true only for fulfilled async thunk actions", function()
				local thunk_ = Redux.createAsyncThunk("a", function()
					return "result"
				end)

				local pendingAction = thunk_.pending("fakeRequestId")
				expect(Redux.isFulfilled()(pendingAction)).to.equal(false)

				local rejectedAction = thunk_.rejected("rejected", "fakeRequestId")
				expect(Redux.isFulfilled()(rejectedAction)).to.equal(false)

				local fulfilledAction = thunk_.fulfilled("result", "fakeRequestId")
				expect(Redux.isFulfilled()(fulfilledAction)).to.equal(true)
				expect(Redux.isFulfilled(fulfilledAction)).to.equal(true)
			end)

			it("should return true only for thunks provided as arguments", function()
				local thunkA = Redux.createAsyncThunk("a", function()
					return "result"
				end)

				local thunkB = Redux.createAsyncThunk("b", function()
					return "result"
				end)

				local thunkC = Redux.createAsyncThunk("c", function()
					return "result"
				end)

				local matchAC = Redux.isFulfilled(thunkA, thunkC)
				local matchB = Redux.isFulfilled(thunkB)

				local function testFulfilledAction(thunk_, expected)
					local pendingAction = thunk_.pending("fakeRequestId")
					expect(matchAC(pendingAction)).to.equal(false)

					local rejectedAction = thunk_.rejected("rejected", "fakeRequestId")
					expect(matchAC(rejectedAction)).to.equal(false)

					local fulfilledAction = thunk_.fulfilled("result", "fakeRequestId")
					expect(matchAC(fulfilledAction)).to.equal(expected)
					expect(matchB(fulfilledAction)).to.equal(not expected)
				end

				testFulfilledAction(thunkA, true)
				testFulfilledAction(thunkC, true)
				testFulfilledAction(thunkB, false)
			end)
		end)

		describe("isAsyncThunkAction", function()
			it("should return false for a regular action", function()
				local action = Redux.createAction("action/type")("testPayload")

				expect(Redux.isAsyncThunkAction()(action)).to.equal(false)
				expect(Redux.isAsyncThunkAction(action)).to.equal(false)
				expect(Redux.isAsyncThunkAction(thunk)).to.equal(false)
			end)

			it("should return true for any async thunk action if no arguments were provided", function()
				local thunk_ = Redux.createAsyncThunk("a", function()
					return "result"
				end)

				local matcher = Redux.isAsyncThunkAction()

				local pendingAction = thunk_.pending("fakeRequestId")
				expect(matcher(pendingAction)).to.equal(true)

				local rejectedAction = thunk_.rejected("rejected", "fakeRequestId")
				expect(matcher(rejectedAction)).to.equal(true)

				local fulfilledAction = thunk_.fulfilled("result", "fakeRequestId")
				expect(matcher(fulfilledAction)).to.equal(true)
			end)

			it("should return true only for thunks provided as arguments", function()
				local thunkA = Redux.createAsyncThunk("a", function()
					return "result"
				end)

				local thunkB = Redux.createAsyncThunk("b", function()
					return "result"
				end)

				local thunkC = Redux.createAsyncThunk("c", function()
					return "result"
				end)

				local matchAC = Redux.isAsyncThunkAction(thunkA, thunkC)
				local matchB = Redux.isAsyncThunkAction(thunkB)

				local function testPendingAction(thunk_, expected)
					local pendingAction = thunk_.pending("fakeRequestId")
					expect(matchAC(pendingAction)).to.equal(expected)
					expect(matchB(pendingAction)).to.equal(not expected)

					local rejectedAction = thunk_.rejected("rejected", "fakeRequestId")
					expect(matchAC(rejectedAction)).to.equal(expected)
					expect(matchB(rejectedAction)).to.equal(not expected)

					local fulfilledAction = thunk_.fulfilled("result", "fakeRequestId")
					expect(matchAC(fulfilledAction)).to.equal(expected)
					expect(matchB(fulfilledAction)).to.equal(not expected)
				end

				testPendingAction(thunkA, true)
				testPendingAction(thunkC, true)
				testPendingAction(thunkB, false)
			end)
		end)
	end)
end
