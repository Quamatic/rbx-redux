local actions = require(script.Parent.Parent.types.actions)
local middleware = require(script.Parent.Parent.types.middleware)

type AnyAction = actions.AnyAction

export type TaskResvoled<T> = {
	status: "ok",
	value: T,
}

export type TaskRejected<T> = {
	status: "rejected",
	error: any,
}

export type TaskCancelled<T> = {
	status: "cancelled",
	error: any,
}

export type TaskResult<Value> = TaskResvoled<Value> | TaskRejected<Value> | TaskCancelled<Value>

export type ForkedTask<T> = {
	result: any,
	cancel: () -> any,
}

export type ListenerErrorInfo = {
	raisedBy: "effect" | "predicate",
}

export type ListenerErrorHandler = (error: any, errorInfo: ListenerErrorInfo) -> nil

export type ListenerMiddleware<State, Dispatch, ExtraArgument> = middleware.Middleware<
	(action: AnyAction) -> UnsubscibeListener,
	State,
	Dispatch
>

export type UnsubscribeListenerOptions = {
	cancelActive: true?,
}

export type UnsubscibeListener = (options: UnsubscribeListenerOptions?) -> nil

export type CreateListenerMiddlewareOptions<ExtraArgument = any> = {
	extra: ExtraArgument?,
	onError: ListenerErrorHandler,
}

export type ListenerEffectAPI<State, Dispatch, ExtraArgument> = middleware.MiddlewareAPI<Dispatch, State> & {
	getOriginalState: () -> State,

	unsubscribe: () -> nil,
	subscribe: () -> nil,

	cancelActiveListeners: () -> nil,

	delay: (timeoutMs: number) -> any,
	fork: <T>(executor: ForkedTaskExecutor<T>) -> ForkedTask<T>,
	take: TakePattern<State>,

	extra: ExtraArgument,
}

export type ListenerMiddlewareInstance<State, Dispatch, ExtraArgument> = {
	middleware: ListenerMiddleware<State, Dispatch, ExtraArgument>,
	startListening: any,
	stopListening: any,
	clearListeners: () -> nil,
}

export type ForkedTaskAPI = {
	pause: <W>(waitFor: any) -> any,
	delay: (timeoutMs: any) -> any,
}

export type AsyncTaskExecutor<T> = (forkApi: ForkedTaskAPI) -> T
export type SyncTaskExector<T> = (forkApi: ForkedTaskAPI) -> T

export type ForkedTaskExecutor<T> = AsyncTaskExecutor<T> | SyncTaskExector<T>

export type TakePattern<State> = {}

export type ListenerPredicate<Action = AnyAction, State = {}> = (
	action: Action,
	currentState: State,
	originalState: State
) -> boolean

export type ListenerEffect<Action, State, Dispatch, ExtraArgument = any> = (
	action: Action,
	api: ListenerEffectAPI<State, Dispatch, ExtraArgument>
) -> nil

export type ListenerEntry<State = any, Dispatch = any> = {
	id: string,
	effect: ListenerEffect<any, State, Dispatch, any>,
	unsubscribe: () -> nil,
	pending: { [any]: true },
	type: string?,
	predicate: ListenerPredicate<AnyAction, State>,
}

export type FallbackAddListenerOptions = {
	actionCreator: any?,
	type: string?,
	matcher: any?,
	predicate: ListenerPredicate<any, any>,
	effect: ListenerEffect<any, any, any, any>,
}

return nil
