local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Redux = require(ReplicatedStorage.Redux)

local counterSlice = Redux.createSlice({
	name = "counter",
	initialState = { value = 0 },
	reducers = {
		incrementBatched = {
			reducer = function(state)
				return {
					value = state.value + 1,
				}
			end,
			prepare = Redux.prepareAutoBatched(),
		},
		decrementUnbatched = function(state)
			return {
				value = state.value - 1,
			}
		end,
	},
})

local incrementBatched = counterSlice.actions.incrementBatched
local decrementUnbatched = counterSlice.actions.decrementUnbatched

local makeStore = function(autoBatchOptions)
	return Redux.configureStore({
		reducer = counterSlice.reducer,
		enhancers = function(existingEnhancers)
			return existingEnhancers:concat(Redux.autoBatchEnhancer(autoBatchOptions))
		end,
	})
end

local store
local subscriptionNotifications = 0

local function debounce(fn: () -> nil, time: number)
	return function(...)
		task.delay(time / 1000, fn, ...)
	end
end

local cases = {
	{ type = "tick" },
	{ type = "raf" },
	{ type = "timer", timeout = 0 },
	{ type = "timer", timeout = 10 },
	{ type = "timer", timeout = 20 },
	{
		type = "callback",
		queueNotification = debounce(function(notify)
			notify()
		end, 5),
	},
}

return function()
	for _, case in cases do
		describe(`autoBatchedEnhancer: {case.type}`, function()
			beforeEach(function()
				subscriptionNotifications = 0
				store = makeStore(case)

				store.subscribe(function()
					subscriptionNotifications += 1
				end)
			end)

			it("does not alter normal subscription notification behavior", function()
				store.dispatch(decrementUnbatched())
				expect(subscriptionNotifications).to.equal(1)
				store.dispatch(decrementUnbatched())
				expect(subscriptionNotifications).to.equal(2)
				store.dispatch(decrementUnbatched())
				expect(subscriptionNotifications).to.equal(3)
				store.dispatch(decrementUnbatched())

				-- 25ms, equivalent to await delay(25)
				task.wait(0.025)

				expect(subscriptionNotifications).to.equal(4)
			end)

			it("only notifies once if several batched actions are dispatched in a row", function()
				store.dispatch(incrementBatched())
				expect(subscriptionNotifications).to.equal(0)
				store.dispatch(incrementBatched())
				expect(subscriptionNotifications).to.equal(0)
				store.dispatch(incrementBatched())
				expect(subscriptionNotifications).to.equal(0)
				store.dispatch(incrementBatched())

				task.wait(0.025)

				expect(subscriptionNotifications).to.equal(1)
			end)

			it("notifies immediately if a non-batched action is dispatched", function()
				store.dispatch(incrementBatched())
				expect(subscriptionNotifications).to.equal(0)
				store.dispatch(incrementBatched())
				expect(subscriptionNotifications).to.equal(0)
				store.dispatch(decrementUnbatched())
				expect(subscriptionNotifications).to.equal(1)
				store.dispatch(incrementBatched())

				task.wait(0.025)

				expect(subscriptionNotifications).to.equal(2)
			end)

			it("does not notify at end of tick if last action was normal priority", function()
				store.dispatch(incrementBatched())
				expect(subscriptionNotifications).to.equal(0)
				store.dispatch(incrementBatched())
				expect(subscriptionNotifications).to.equal(0)
				store.dispatch(decrementUnbatched())
				expect(subscriptionNotifications).to.equal(1)
				store.dispatch(incrementBatched())
				store.dispatch(decrementUnbatched())
				expect(subscriptionNotifications).to.equal(2)
				store.dispatch(decrementUnbatched())
				expect(subscriptionNotifications).to.equal(3)

				task.wait(0.025)

				expect(subscriptionNotifications).to.equal(3)
			end)
		end)
	end
end
