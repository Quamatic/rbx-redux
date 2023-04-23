local store = require(script.Parent.types.store)
local reducers = require(script.Parent.types.reducers)

local IS_REDUCER = require(script.Parent.createReducer).IS_REDUCER

local ActionTypes = require(script.Parent.utils.actionTypes)

type StoreEnhancerStoreCreator<Ext = {}, StateExt = {}> = (
) -> <S, A, PreloadedState>(
	reducer: reducers.Reducer<S, A, PreloadedState>,
	preloadedState: PreloadedState?
) -> Store<S, A, StateExt> & Ext

type StoreEnhancer<Ext = {}, StateExt = {}> = <NextExt, NextStateExt>(
	next: StoreEnhancerStoreCreator<NextExt, NextStateExt>
) -> StoreEnhancerStoreCreator<NextExt & Ext, NextStateExt & Ext>

type StoreCreator =
	(<S, A, Ext, StateExt>(
		reducer: reducers.Reducer<S, A, {}>,
		enhancer: StoreEnhancer<Ext, StateExt>?
	) -> Store<S, A, StateExt> & Ext)
	| (<S, A, Ext, StateExt, PreloadedState>(
		reducer: reducers.Reducer<S, A, PreloadedState>,
		preloadedState: PreloadedState?,
		enhancer: StoreEnhancer<Ext, StateExt>?
	) -> Store<S, A, StateExt> & Ext)

type Unsubscribe = () -> nil
type ListenerCallback = () -> nil

type Store<S = any, A = any, StateExt = {}> = {
	dispatch: store.Dispatch,
	getState: () -> S & StateExt,
	subscribe: (listener: ListenerCallback) -> Unsubscribe,
	replaceReducer: (nextReducer: reducers.Reducer<S, A, StateExt>) -> nil,
}

local function createStore<S, A, Ext, StateExt, PreloadedState>(
	reducer: reducers.Reducer<S, A, PreloadedState>,
	preloadedState: PreloadedState | StoreEnhancer<Ext, StateExt>?,
	enhancer: StoreEnhancer<Ext, StateExt>?,
	-- Dont use this argument
	_fakeEnhancerArg: StoreEnhancer<Ext, StateExt>?
): Store<S, A, StateExt> & Ext
	-- Check if its a vanilla reducer, or a reducer created from createReducer.
	if typeof(reducer) ~= "function" then
		if typeof(reducer) == "table" then
			if reducer[IS_REDUCER] == nil then
				error(
					"Attempted to pass a table as the reducer. Only reducers created from `createReducer` are valid tables to pass."
				)
			end
		else
			error(`Expected the root reducer to be a function. Instead, received: {typeof(reducer)}`, 2)
		end
	end

	if
		(typeof(preloadedState) == "function" and typeof(enhancer) == "function")
		or (typeof(enhancer) == "function" and typeof(_fakeEnhancerArg) == "function")
	then
		error(
			"It looks like you are passing several store enhancers to "
				+ "createStore(). This is not supported. Instead, compose them "
				+ "together to a single function. See https://redux.js.org/tutorials/fundamentals/part-4-store#creating-a-store-with-enhancers for an example."
		)
	end

	if typeof(preloadedState) == "function" and enhancer == nil then
		enhancer = preloadedState :: StoreEnhancer<Ext, StateExt>
		preloadedState = nil
	end

	if enhancer ~= nil then
		if typeof(enhancer) ~= "function" then
			error(`Expected the enhancer to be a function. Instead, received: {typeof(enhancer)}`)
		end

		return enhancer(createStore)(reducer, preloadedState :: PreloadedState?)
	end

	local currentReducer = reducer
	local currentState = preloadedState
	local listenerIdCounter = 0
	local currentListeners: { [number]: ListenerCallback } | nil = {}
	local nextListeners = currentListeners
	local isDispatching = false

	local function ensureCanMutateNextListeners()
		if nextListeners == currentListeners then
			nextListeners = {}

			for key, listener in currentListeners do
				nextListeners[key] = listener
			end
		end
	end

	local function getState(): S
		if isDispatching then
			error(
				"You may not call store.getState() while the reducer is executing. "
					.. "The reducer has already received the state as an argument. "
					.. "Pass it down from the top reducer instead of reading it from the store."
			)
		end

		return currentState :: S
	end

	local function dispatch(action)
		if typeof(action) ~= "table" then
			error(
				`Actions must be plain objects. Instead, the actual type was: {typeof(action)}`
					.. `You may need to add middleware to your store setup to handle dispatching other values, such as 'redux-thunk' to handle dispatching functions. See https://redux.js.org/tutorials/fundamentals/part-4-store#middleware and https://redux.js.org/tutorials/fundamentals/part-6-async-logic#using-the-redux-thunk-middleware for examples.`
			)
		end

		if action.type == nil then
			error(
				`Actions may not have an undefined "type" property. You may have misspelled an action type string constant.`
			)
		end

		if isDispatching then
			error("Reducers may not dispatch actions.")
		end

		local ok, problem = pcall(function()
			isDispatching = true
			currentState = currentReducer(currentState, action)
		end)

		isDispatching = false

		if not ok then
			error(`Caught error in reducer while dispatching: {problem}`)
		end

		currentListeners = nextListeners
		local listeners = currentListeners

		for _, listener in listeners do
			listener()
		end

		return action
	end

	local function subscribe(listener: () -> nil)
		if typeof(listener) ~= "function" then
			error(`Expected the listener to be a function. Instead, received: {typeof(listener)}`)
		end

		if isDispatching then
			error(
				"You may not call store.subscribe() while the reducer is executing. "
					.. "If you would like to be notified after the store has been updated, subscribe from a "
					.. "component and invoke store.getState() in the callback to access the latest state. "
					.. "See https://redux.js.org/api/store#subscribelistener for more details."
			)
		end

		local isSubscribed = true

		ensureCanMutateNextListeners()

		listenerIdCounter += 1
		local listenerId = listenerIdCounter
		nextListeners[listenerId] = listener

		return function()
			if not isSubscribed then
				return
			end

			if isDispatching then
				error(
					"You may not unsubscribe from a store listener while the reducer is executing. "
						.. "See https://redux.js.org/api/store#subscribelistener for more details."
				)
			end

			isSubscribed = false

			ensureCanMutateNextListeners()
			nextListeners[listenerId] = nil
			currentListeners = nil
		end
	end

	local function replaceReducer(nextReducer: reducers.Reducer<S, A, {}>)
		if typeof(nextReducer) ~= "function" then
			error(`Expected the nextReducer to be a function. Instead, received: {typeof(nextReducer)}`)
		end

		currentReducer = (nextReducer :: any) :: reducers.Reducer<S, A, PreloadedState>
		dispatch({ type = ActionTypes.REPLACE } :: A)
	end

	local function destruct()
		table.clear(currentListeners)
		currentListeners = nil
	end

	dispatch({ type = ActionTypes.INIT })

	return {
		getState = getState,
		dispatch = dispatch,
		subscribe = subscribe,
		replaceReducer = replaceReducer,
		destruct = destruct,
	}
end

return createStore
