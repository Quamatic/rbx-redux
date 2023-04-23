local Promise = require(script.Parent.Promise)

local PromiseTypes = require(script.Parent.types.promise)
type Promise<T> = PromiseTypes.Promise<T>

local createAction = require(script.Parent.createAction).createAction
local nanoid = require(script.Parent.nanoid)
local createSignal = require(script.Parent.utils.createSignal)
local merge = require(script.Parent.merge)

type CreateAsyncThunk<CurriedThunkApiConfig> =
	(<Returned, ThunkArg>(typePrefix: string) -> AsyncThunk<Returned, ThunkArg, CurriedThunkApiConfig>)
	| (<Returned, ThunkArg, ThunkApiConfig>(typePrefix: string) -> AsyncThunk<Returned, ThunkArg, ThunkApiConfig>)

type MaybePromise<T> = T | Promise<T>
export type AsyncThunkPayloadCreatorReturnValue<Returned, ThunkApiConfig> = MaybePromise<any>
export type AsyncThunkPayloadCreator<Returned, ThunkArg, ThunkApiConfig> = (
	arg: ThunkArg,
	thunkAPI: any
) -> AsyncThunkPayloadCreatorReturnValue<Returned, ThunkApiConfig>

export type AsyncThunk<Returned, ThunkArg, ThunkApiConfig> = {}

export type AsyncThunkAction<Returned, ThunkArg, ThunkApiConfig> = (
	dispatch: any,
	getState: () -> any,
	extra: any
) -> {
	promise: Promise<any>,
	abort: (reason: string?) -> nil,
	requestId: string,
	arg: ThunkArg,
	unwrap: () -> Promise<Returned>,
}

type AsyncThunkActionCreator<Returned, ThunkArg, ThunkApiConfig> = ThunkArg | (arg: ThunkArg) -> any

export type AsyncThunkOptions<ThunkArg, ThunkApiConfig> = {
	condition: (arg: ThunkArg, api: GetThunkAPI<ThunkApiConfig>) -> MaybePromise<boolean | nil>?,

	dispatchConditionRejection: boolean?,
	serializeError: (x: any) -> any?,

	getPendingMeta: (base: {
		arg: ThunkArg,
		requestId: string,
	}, api: GetThunkAPI<ThunkApiConfig>) -> any?,

	idGenerator: (arg: ThunkArg) -> string?,
}

export type BaseThunkAPI<State, Extra, Dispatch, RejectedValue = nil, RejectedMeta = any, FulfilledMeta = any> = {
	dispatch: Dispatch,
	getState: () -> State,
	extra: Extra,
	requestId: string,
	abort: (reason: string?) -> nil,
	rejectWithValue: any,
	fulfillWithValue: any,
}

type AsyncThunkConfig = {
	state: any?,
	dispatch: () -> any?,
	extra: any?,
	rejectValue: any?,
	serializedErrorType: any?,
	pendingMeta: any?,
	fulfilledMeta: any?,
	rejectedMeta: any?,
}

type GetThunkAPI<ThunkApiConfig> = BaseThunkAPI<any, any, any, any, any, any>

local function await(promise)
	local status, value = promise:awaitStatus()
	if status == Promise.Status.Resolved then
		return value
	elseif status == Promise.Status.Rejected then
		error(value, 2)
	else
		error("The awaited Promise was cancelled", 2)
	end
end

local function unwrapResult<R>(action: R)
	if action.meta and action.meta.rejectedWithValue then
		error(action.payload)
	end

	if action.error then
		error(action.error)
	end

	return action.payload
end

local Result = newproxy(false)

local FULFILLED = 1
local REJECTED = 2

local function createAsyncThunk<Returned, ThunkArg, ThunkApiConfig>(
	typePrefix: string,
	payloadCreator: AsyncThunkPayloadCreator<
		Returned,
		ThunkArg,
		ThunkApiConfig
	>,
	options: AsyncThunkOptions<ThunkArg, ThunkApiConfig>
): AsyncThunk<Returned, ThunkArg, ThunkApiConfig>
	-- Create `fulfilled`
	local fulfilled = createAction(
		`{typePrefix}/fulfilled`,
		function(payload: Returned, requestId: string, arg: ThunkArg, meta: any?)
			return {
				payload = payload,
				meta = merge(meta or {}, {
					arg = arg,
					requestId = requestId,
					requestStatus = "fulfilled",
				}),
			}
		end
	)

	-- Create `pending`
	local pending = createAction(`{typePrefix}/pending`, function(requestId: string, arg: ThunkArg, meta: any?)
		return {
			payload = nil,
			meta = merge(meta or {}, {
				arg = arg,
				requestId = requestId,
				requestStatus = "pending",
			}),
		}
	end)

	-- Create `rejected`
	local rejected = createAction(
		`{typePrefix}/rejected`,
		function(err: any?, requestId: string, arg: ThunkArg, payload: any?, meta: any?)
			return {
				payload = payload,
				error = err or "Rejected",
				meta = merge(meta or {}, {
					arg = arg,
					requestId = requestId,
					rejectedWithValue = not not payload,
					requestStatus = "rejected",
					condition = err == "Aborted due to condition callback returning false.",
				}),
			}
		end
	)

	local function actionCreator(arg: ThunkArg): AsyncThunkAction<Returned, ThunkArg, ThunkApiConfig>
		return function(dispatch, getState, extra)
			local requestId = if options and options.idGenerator ~= nil then options.idGenerator(arg) else nanoid()

			local finalAction: typeof(fulfilled) | typeof(rejected)
			local promise: Promise<typeof(finalAction)>

			-- TODO: Finish this, and make sure aborting doesnt break the entire operation.
			local onAbortSignal = createSignal()
			local abortReason: string?
			local aborted = false

			promise = Promise.new(function(resolve, reject)
				local conditionResult = nil

				if options and options.condition then
					conditionResult = options.condition(arg, { getState = getState, extra = extra })

					-- We only accept promises. This is equal to Redux's `isThenable` function.
					if Promise.is(conditionResult) then
						conditionResult = await(conditionResult)
					end
				end

				-- Semantically the same as Redux's abort method
				if conditionResult == false or aborted then
					return reject("Aborted due to condition callback returning false.")
				end

				onAbortSignal.subscribe(function()
					reject(abortReason or "Aborted")
				end)

				-- Dispatch pending action
				local pendingMetaResult: any
				if options and options.getPendingMeta then
					pendingMetaResult = options.getPendingMeta(
						{ requestId = requestId, arg = arg },
						{ getState = getState, extra = extra }
					)
				end

				-- Dispatch pending action
				dispatch(pending(requestId, arg, pendingMetaResult))

				-- Race to see if the payload resolves or we forcefully abort before it's ready
				resolve(payloadCreator(arg, {
					dispatch = dispatch,
					getState = getState,
					extra = extra,
					requestId = requestId,
					signal = onAbortSignal,
					rejectWithValue = function(value: any, meta: any?)
						return {
							[Result] = REJECTED,
							payload = value,
							meta = meta,
						}
					end,
					fulfillWithValue = function(value: any, meta: any?)
						return {
							[Result] = FULFILLED,
							payload = value,
							meta = meta,
						}
					end,
				}))
			end)
				:andThen(function(result)
					-- Redux does two `instanceof` checks here, but just checking if its a table should be fine, due to using an unique proxy.
					if typeof(result) == "table" then
						if result[Result] == REJECTED then
							-- If it was sent as `rejected` then pass it on to the catch block
							return Promise.reject(result)
						end

						if result[Result] == FULFILLED then
							finalAction = fulfilled(result.payload, requestId, arg, result.meta)
							return
						end
					end

					finalAction = fulfilled(result :: any, requestId, arg)
				end)
				:catch(function(err)
					-- Not really sure if this is super necessary?
					if Promise.Error.is(err) then
						err = tostring(err)
					end

					-- Make the final action whatever the error was
					finalAction = if typeof(err) == "table" and err[Result] == REJECTED
						then rejected(nil, requestId, arg, err.payload, err.meta)
						else rejected(err :: any, requestId, arg)
				end)
				:andThen(function()
					-- Dispatch result after the catch

					local skipDispatch = options
						and not options.dispatchConditionRejection
						and rejected.match(finalAction)
						and finalAction.meta.condition

					if not skipDispatch then
						dispatch(finalAction)
					end

					return finalAction
				end)

			-- This is a super hacked in way to mimic ".abort(reason)"
			-- I do not like it at all, but this is how it works with Redux. should probably figure out how to work around cancellations
			promise.cancel = function(_: typeof(promise), reason: string)
				aborted = true
				abortReason = reason

				onAbortSignal.fire()
			end

			-- Added extra fields from Redux
			promise.requestId = requestId
			promise.arg = arg
			promise.unwrap = function()
				return promise:andThen(unwrapResult)
			end

			return promise
		end
	end

	return setmetatable({
		fulfilled = fulfilled,
		pending = pending,
		rejected = rejected,
		typePrefix = typePrefix,
	}, {
		__call = function(_, arg: ThunkArg)
			return actionCreator(arg)
		end,
	}) :: CreateAsyncThunk<AsyncThunkConfig>
end

return {
	createAsyncThunk = createAsyncThunk,
	unwrapResult = unwrapResult,
}
