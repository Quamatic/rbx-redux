local Promise = require(script.Parent.Parent.Promise)

local createPause = function<T>()
	return function(promise)
		return Promise.race({ promise }):catch(function() end)
	end
end

local createDelay = function<T>()
	local pause = createPause()

	return function(timeoutMs: number)
		return pause(Promise.delay(timeoutMs))
	end
end

local runTask = function<T>(task: () -> any, cleanup: () -> nil)
	return Promise.defer(function(resolve)
		resolve(task())
	end)
		:andThen(function(value)
			return {
				status = "ok",
				value = value,
			}
		end)
		:catch(function(err)
			return {
				status = if Promise.Error.isKind(err, Promise.Error.Kind.AlreadyCancelled)
					then "canelled"
					else "rejected",
				error = err,
			}
		end)
		:finallyCall(cleanup)
end

return {
	runTask = runTask,
	createPause = createPause,
	createDelay = createDelay,
}
