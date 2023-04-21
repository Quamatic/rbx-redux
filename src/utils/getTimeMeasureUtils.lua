local function getTimeMeasureUtils(maxDelay: number, fnName: string)
	local elasped = 0

	return {
		measureTime = function<T>(fn: () -> T): T
			local started = os.clock()
			fn()
			elasped += os.clock() - started
		end,

		warnIfExceeded = function()
			if elasped > maxDelay then
				warn(
					`{fnName} took {elasped}ms, which is more than the warning threshold of {maxDelay} ms.`
						.. "If your state or actions are very large, you may want to disable the middleware as it might cause too much of a slowdown in development mode. See https://redux-toolkit.js.org/api/getDefaultMiddleware for instructions."
						.. "It is disabled in production builds, so you don't need to worry about that."
				)
			end
		end,
	}
end

return getTimeMeasureUtils
