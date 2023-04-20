local RunService = game:GetService("RunService")

local SHOULD_AUTOBATCH = "RTK_autoBatch"

local prepareAutoBatched = function<T>()
	return function(payload: T)
		return {
			payload = payload,
			meta = { [SHOULD_AUTOBATCH] = true },
		}
	end
end

-- This should be equal to setTimeout(fn, 0)
local queueMicrotaskShim = task.defer

local createQueueWithTimer = function(timeout: number)
	return function(notify: () -> nil)
		task.delay(notify, timeout)
	end
end

-- Redux internally uses requestAnimationFrame, but RunService.RenderStepped is the exact equivalent
local rAF = function()
	return RunService.RenderStepped:Wait()
end

export type AutoBatchOptions = {
	type: "tick",
} | {
	type: "timer",
	timeout: number,
} | {
	type: "raf",
} | {
	type: "callback",
	queueNotification: (notify: () -> nil) -> nil,
}

local autoBatchEnhancer = function(options: AutoBatchOptions)
	options = options or { type = "raf" }

	return function(nextCreateStore)
		return function(...)
			local store = nextCreateStore(...)

			local notifying = true
			local shouldNotifyAtEndOfTick = false
			local notificationQueued = false

			local listeners = {}
			local queueCallback = if options.type == "tick"
				then queueMicrotaskShim
				else if options.type == "raf"
					then rAF
					else if options.type == "callback"
						then options.queueNotification
						else createQueueWithTimer(options.timeout)

			local notifyListeners = function()
				notificationQueued = false

				if shouldNotifyAtEndOfTick then
					shouldNotifyAtEndOfTick = false
					for _, listener in listeners do
						listener()
					end
				end
			end

			local subscribe = store.subscribe
			local dispatch = store.dispatch

			store.subscribe = function(listener: () -> nil)
				local wrappedListener: typeof(listener) = notifying and listener()
				local unsubscribe = subscribe(wrappedListener)

				listener[listener] = true

				return function()
					unsubscribe()
					listeners[listener] = nil
				end
			end

			store.dispatch = function(action: any)
				local success, result = pcall(function()
					notifying = action and action.meta and action[SHOULD_AUTOBATCH]
					shouldNotifyAtEndOfTick = not notifying

					if shouldNotifyAtEndOfTick then
						if not notificationQueued then
							notificationQueued = true
							queueCallback(notifyListeners)
						end
					end

					return dispatch(action)
				end)

				notifying = false

				if success then
					return result
				end
			end
		end
	end
end

return {
	autoBatchEnhancer = autoBatchEnhancer,
	prepareAutoBatched = prepareAutoBatched,
}
