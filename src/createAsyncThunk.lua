local HttpService = game:GetService("HttpService")

-- TODO: Either check if the user has the Promise package or add it as a dependency.
local Promise = require(script.Parent.Promise)

local createAction = require(script.Parent.createAction).createAction
local merge = require(script.Parent.merge)

-- TODO: is this even necessary?
type Promise<T> = {
	andThen: (self: Promise<T>) -> T,
}

type CreateAsyncThunk<CurriedThunkApiConfig> =
	(<Returned, ThunkArg>(typePrefix: string) -> AsyncThunk<Returned, ThunkArg, CurriedThunkApiConfig>)
	| (<Returned, ThunkArg, ThunkApiConfig>(typePrefix: string) -> AsyncThunk<Returned, ThunkArg, ThunkApiConfig>)

type MaybePromise<T> = T | Promise<T>
type AsyncPayloadThunkCreatorReturnValue<Returned, ThunkApiConfig> = MaybePromise<any>
type AsyncPayloadThunkCreator<Returned, ThunkArg, ThunkApiConfig> = (
	arg: ThunkArg,
	thunkAPI: any
) -> AsyncPayloadThunkCreatorReturnValue<Returned, ThunkApiConfig>

type AsyncThunk<Returned, ThunkArg, ThunkApiConfig> = {}

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
		error(action.payload, 2)
	end

	if action.error then
		error(action.error, 2)
	end

	return action.payload
end

local Result = newproxy(false)

local FULFILLED = 1
local REJECTED = 2
local PENDING = 3

local function createAsyncThunk<Returned, ThunkArg, ThunkApiConfig>(
	typePrefix: string,
	payloadCreator: AsyncPayloadThunkCreator<
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
				meta = merge(meta or {}, {
					error = err,
					arg = arg,
					requestId = requestId,
					rejectedWithValue = not not payload,
					requestStatus = "rejected",
				}),
			}
		end
	)

	local function actionCreator(arg: ThunkArg): AsyncThunkAction<Returned, ThunkArg, ThunkApiConfig>
		return function(dispatch, getState, extra)
			local requestId = if options and options.idGenerator ~= nil
				then options.idGenerator(arg)
				else HttpService:GenerateGUID(false)

			local finalAction: typeof(fulfilled) | typeof(rejected)
			local promise: Promise<typeof(finalAction)>

			-- TODO: Finish this, and make sure aborting doesnt break the entire operation.

			promise = Promise.new(function(resolve, reject, onCancel)
				local conditionResult = nil

				if options and options.condition then
					conditionResult = options.condition(arg, { getState = getState, extra = extra })

					-- We only accept promises. This is equal to Redux's `isThenable` function.
					if Promise.is(conditionResult) then
						conditionResult = await(conditionResult)
					end
				end

				-- Semantically the same as Redux's abort method
				if conditionResult == false or onCancel() then
					return reject({
						name = "ConditionError",
						message = "Aborted due to condition callback returning false.",
					})
				end

				local abortedPromise = Promise.new(function(_, reject_, onCancel_)
					-- Calling this promise's onCancel makes more sense than its parent
					onCancel_(function()
						reject_({
							name = "AbortError",
							reason = "Aborted",
						})
					end)
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
				resolve(Promise.race({
					abortedPromise,
					Promise.resolve(payloadCreator(arg, {
						dispatch = dispatch,
						getState = getState,
						extra = extra,
						requestId = requestId,

						abort = function()
							promise:cancel()
							promise = nil
						end,

						onAborted = function() end,
						aborted = false,

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
					})),
				}))
			end)
				:andThen(function(result)
					if typeof(result) == "table" then
						if result[Result] == REJECTED then
							return Promise.reject(result)
						elseif result[Result] == FULFILLED then
							finalAction = fulfilled(result.payload, requestId, arg, result.meta)
						end
					end

					finalAction = fulfilled(result, requestId, arg)
				end)
				:catch(function(err)
					-- Make the final action whatever the error was
					finalAction = if err[Result] == REJECTED
						then rejected(nil, requestId, arg, err.payload, err.meta)
						else rejected(err, requestId, arg)
				end)
				:andThen(function()
					local skipDispatch = options
						and not options.dispatchConditionRejection
						and rejected.match(finalAction)
						and finalAction.meta.condition

					if not skipDispatch then
						dispatch(finalAction)
					end

					return finalAction
				end)

			-- Redux assigns fields to the promise with Object.assign here
			-- but instead we have to do some metatable magic to get the same result
			-- Why is javascript so stupid? Why are functions objects?

			return setmetatable({
				requestId = requestId,
				arg = arg,
				unwrap = function()
					return promise:andThen(unwrapResult)
				end,
			}, {
				__index = promise,
			})
		end
	end

	return setmetatable({
		fulfilled = fulfilled,
		pending = pending,
		rejected = rejected,
		typePrefix = typePrefix,
	}, {
		__call = function(_, arg: ThunkArg)
			-- TODO: Add self to `actionCreator` to prevent creating another function?
			return actionCreator(arg)
		end,
	}) :: CreateAsyncThunk<AsyncThunkConfig>
end

return {
	createAsyncThunk = createAsyncThunk,
	unwrapResult = unwrapResult,
}
