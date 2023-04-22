local types = require(script.types)

local Promise = require(script.Parent.Promise)

local PromiseTypes = require(script.Parent.types.promise)
type Promise<T> = PromiseTypes.Promise<T>

local createAction_ = require(script.Parent.Parent.Parent.createAction)
local nanoid = require(script.Parent.Parent.Parent.nanoid)
local merge = require(script.Parent.Parent.Parent.merge)

local tasks = require(script.tasks)

local createAction = createAction_.createAction
local isAction = createAction_.isAction

local INTERNAL_NIL_TOKEN = {}

local alm = "listenerMiddleware"

local createFork = function()
	return function<T>(taskExecutor: types.ForkedTaskExecutor<T>): types.ForkedTask<T>
		local result = tasks.runTask(function()
			return Promise.new(function(resolve, reject)
				resolve(taskExecutor({
					pause = tasks.createPause(),
					delay = tasks.createDelay(),
				}) :: T)
			end)
		end)

		return {
			result = tasks.createPause()(result),
			cancel = function()
				result:cancel()
			end,
		}
	end
end

local cancelActiveError = function(entry: types.ListenerEntry<any, any>)
	for _, controller in entry.pending do
	end
end

local cancelActiveListeners = function(entry: types.ListenerEntry<{}, any>) end

local createClearListenerMiddleware = function(listenerMap: { [string]: types.ListenerEntry<{}, any> })
	return function()
		for _, entry in listenerMap do
			cancelActiveListeners(entry)
		end

		table.clear(listenerMap)
	end
end

local createTakePattern = function<S>(startListening): types.TakePattern<S>
	local take = function<P>(predicate: P, timeout: number?)
		return Promise.new(function()
			local unsubscribe: types.UnsubscibeListener = function() end

			local tuplePromise = Promise.new(function(resolve, reject)
				local stopListening = startListening({
					predicate = predicate,
					effect = function(action, listenerAPI)
						listenerAPI.unsubscribe()
						resolve({
							action,
							listenerAPI.getState(),
							listenerAPI.getOriginalState(),
						})
					end,
				})

				unsubscribe = function()
					stopListening()
					reject()
				end
			end)

			local promises: { Promise<nil> } = { tuplePromise }

			if timeout then
				table.insert(promises, Promise.delay(timeout))
			end

			return Promise.race(promises):finallyCall(unsubscribe)
		end)
	end

	return function(predicate, timeout)
		return take(predicate, timeout)
	end
end

local getListenerEntryPropsFrom = function(options: types.FallbackAddListenerOptions)
	local type = options.type
	local actionCreator = options.actionCreator
	local matcher = options.matcher
	local predicate = options.predicate
	local effect = options.effect

	if type then
		predicate = createAction(type).match
	elseif actionCreator then
		type = actionCreator.type
		predicate = actionCreator.match
	elseif matcher then
		predicate = matcher
	elseif predicate then
		-- pass
	else
		error("Creating or removing a listener requires one of the known fields for matching an action")
	end

	return {
		predicate = predicate,
		type = type,
		effect = effect,
	}
end

local createListenerEntry = function(options: types.FallbackAddListenerOptions)
	local id = nanoid()

	local entry: types.ListenerEntry<any, any> = {
		id = id,
		type = options.type,
		effect = options.effect,
		predicate = options.predicate,
		pending = {},
		unsubscribe = function()
			error("Unsubscribe not initialized")
		end,
	}

	return entry
end

-- Safely notifying would just be spawning the error on a diff thread
local safelyNotifyError = function(
	errorHandler: types.ListenerErrorHandler,
	errorToNotify: any,
	errorInfo: types.ListenerErrorInfo
)
	local success, errorHandlerError = pcall(errorHandler, errorToNotify, errorInfo)

	if not success then
		task.spawn(error, errorHandlerError)
	end
end

-- Action handlers

local addListener = createAction(`{alm}/add`)
local clearAllListeners = createAction(`{alm}/removeAll`)
local removeListener = createAction(`{alm}/remove`)

local defaultErrorHandler: types.ListenerErrorHandler = function(...: any)
	task.spawn(error, `{alm}/error`, ...)
end

local function toJSBoolean(x: any)
	return not not x and x ~= 0 and x ~= ""
end

local function createListenerMiddleware<S, D, ExtraArgument>(middlewareOptions: types.CreateListenerMiddlewareOptions<ExtraArgument>)
	middlewareOptions = middlewareOptions or {}

	local listenerMap: { [string]: types.ListenerEntry<{}, any> } = {}
	local extra = middlewareOptions.extra
	local onError = middlewareOptions.onError or defaultErrorHandler

	local insertEntry = function(entry: types.ListenerEntry<{}, any>)
		entry.unsubscribe = function()
			listenerMap[entry.id] = nil
		end

		listenerMap[entry.id] = entry
		return function(cancelOptions: types.UnsubscribeListenerOptions?)
			entry.unsubscribe()
			if cancelOptions and cancelOptions.cancelActive then
				cancelActiveError(entry)
			end
		end
	end

	local findListenerEntry = function(
		comparator: (entry: types.ListenerEntry<{}, any>) -> boolean
	): types.ListenerEntry<{}, any>?
		for _, entry in listenerMap do
			if comparator(entry) then
				return entry
			end
		end
		return nil
	end

	local startListening = function(options: types.FallbackAddListenerOptions)
		local entry = findListenerEntry(function(existingEntry)
			return existingEntry.effect == options.effect
		end)

		if entry == nil then
			entry = createListenerEntry(options)
		end

		return insertEntry(entry)
	end

	local stopListening = function(options: types.FallbackAddListenerOptions & types.UnsubscribeListenerOptions)
		local type, effect, predicate = unpack({})

		local entry = findListenerEntry(function(entry)
			local matchOrPredicateType = if typeof(type) == "string"
				then entry.type == type
				else entry.predicate == predicate

			return matchOrPredicateType and entry.effect == effect
		end)

		if entry then
			entry.unsubscribe()

			if options.cancelActive then
				cancelActiveListeners(entry)
			end
		end

		return not not entry
	end

	local notifyListener = function(
		entry: types.ListenerEntry<any, any>,
		action: any,
		api: any,
		getOriginalState: () -> S
	)
		local promise
		promise = Promise.new(function(resolve)
			local take = createTakePattern(startListening)
			entry.pending[promise] = true

			resolve(entry.effect(
					action,
					merge({}, api, {
						getOriginalState = getOriginalState,
						condition = function(predicate, timeout: number?)
							return take(predicate, timeout):andThen(toJSBoolean)
						end,
						take = take,
						delay = tasks.createDelay(),
						pause = tasks.createPause(),
						extra = extra,
						fork = createFork(),
						unsubscribe = entry.unsubscribe,
						subscribe = function()
							listenerMap[entry.id] = entry
						end,
						cancelActiveListeners = function()
							for promise_ in entry.pending do
								if promise_ ~= promise then
									promise_:cancel()
									entry.pending[promise_] = nil
								end
							end
						end,
					})
				))
				:catch(function(problem)
					safelyNotifyError(onError, problem, {
						raisedBy = "effect",
					})
				end)
				:finally(function()
					entry.pending[promise] = nil
				end)
		end)
	end

	local clearListenerMiddleware = createListenerMiddleware(listenerMap)

	local middleware: types.ListenerMiddleware<S, D, ExtraArgument> = function(api)
		return function(nextDispatch)
			return function(action)
				if not isAction(action) then
					-- We only want to notify listeners for action objects
					return nextDispatch(action)
				end

				if addListener.match(action) then
					return startListening(action.payload)
				end

				if clearAllListeners.match(action) then
					clearListenerMiddleware()
					return
				end

				if removeListener.match(action) then
					return stopListening(action.payload)
				end

				local originalState: S | typeof(INTERNAL_NIL_TOKEN) = api.getState()

				local getOriginalState = function(): S
					if originalState == INTERNAL_NIL_TOKEN then
						error(`{alm}: getOriginalState can only be called synchronously`)
					end

					return originalState :: S
				end

				local result: any

				local success, problem = pcall(function()
					result = nextDispatch(action)

					local listenerMapSize = 0
					for _ in listenerMap do
						listenerMapSize += 1
					end

					if listenerMapSize > 0 then
						local currentState = api.getState()

						for _, entry in listenerMap do
							local runListener = false

							local success, predicateError = pcall(function()
								runListener = entry.predicate(action, currentState, originalState)
							end)

							if not success then
								runListener = false

								safelyNotifyError(onError, predicateError, {
									raisedBy = "predicate",
								})
							end

							if not runListener then
								continue
							end

							notifyListener(entry, action, api, getOriginalState)
						end
					end
				end)

				if not success then
					task.spawn(error, `{alm}: {problem}`)
				end

				originalState = INTERNAL_NIL_TOKEN

				return result
			end
		end
	end

	return {
		middleware = middleware,
		startListening = startListening,
		stopListening = stopListening,
		clearListeners = clearListenerMiddleware,
	} :: types.ListenerMiddlewareInstance<S, D, ExtraArgument>
end

return {
	createListenerMiddleware = createListenerMiddleware,
}
