local RunService = game:GetService("RunService")

local merge = require(script.Parent.merge)

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
local queueMicrotaskShim = function(notify: () -> nil)
	task.defer(notify)
end

local createQueueWithTimer = function(timeout: number)
	return function(notify: () -> nil)
		task.delay(timeout / 1000, notify)
	end
end

-- Redux internally uses requestAnimationFrame, but RunService.RenderStepped is the exact equivalent
local rAF = queueMicrotaskShim

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
					for listener in listeners do
						listener()
					end
				end
			end

			return merge({}, store, {
				subscribe = function(listener: () -> nil)
					local wrappedListener: typeof(listener) = function()
						if notifying then
							listener()
						end
					end

					local unsubscribe = store.subscribe(wrappedListener)
					listeners[listener] = true

					return function()
						unsubscribe()
						listeners[listener] = nil
					end
				end,

				dispatch = function(action: any)
					local success, result = pcall(function()
						local hasRtkAutoBatch = false
						if action ~= nil and action.meta ~= nil and action.meta[SHOULD_AUTOBATCH] ~= nil then
							hasRtkAutoBatch = true
						end

						notifying = not hasRtkAutoBatch

						shouldNotifyAtEndOfTick = not notifying
						if shouldNotifyAtEndOfTick then
							if not notificationQueued then
								notificationQueued = true
								queueCallback(notifyListeners)
							end
						end

						return store.dispatch(action)
					end)

					notifying = true

					if success then
						return result
					end
				end,
			})
		end
	end
end

return {
	autoBatchEnhancer = autoBatchEnhancer,
	prepareAutoBatched = prepareAutoBatched,
}
