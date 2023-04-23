local createAsyncThunk = require(script.createAsyncThunk)
local configureStore = require(script.configureStore)
local createAction = require(script.createAction)
local createSlice = require(script.createSlice)
local compose = require(script.compose)
local applyMiddleware = require(script.applyMiddleware)
local bindActionCreators = require(script.bindActionCreators)
local createStore = require(script.createStore)
local createSelector = require(script.createSelector)
local createReducer = require(script.createReducer)
local combineReducers = require(script.combineReducers)
local nanoid = require(script.nanoid)
local matchers = require(script.matchers)

local thunk = require(script.thunk)
local getDefaultMiddleware = require(script.getDefaultMiddleware)
local autoBatchEnhancer = require(script.autoBatchEnhancer)
local createImmutableStateInvariantMiddleware = require(script.immutableStateInvariantMiddleware)

-- !START EXPORTING VANILLA REDUX TYPES

-- *REDUX STORE TYPES EXPORTS
local store = require(script.types.store)

export type Dispatch<A, Args...> = store.Dispatch<A, Args...>
export type Unsubscribe = store.Unsubscribe
export type Store<S = any, A = any, StateExt = {}> = store.Store<S, A, StateExt>
export type StoreCreator = store.StoreCreator
export type StoreEnhancer<Ext = {}, StateExt = {}> = store.StoreEnhancer<Ext, StateExt>
export type StoreEnhancerStoreCreator<Ext = {}, StateExt = {}> = store.StoreEnhancerStoreCreator<Ext, StateExt>

-- *REDUX REDUCER TYPES EXPORTS
local reducers = require(script.types.reducers)

export type Reducer<S = any, A = reducers.AnyAction, PreloadedState = S> = reducers.Reducer<S, A, PreloadedState>
export type ReducersMapObject<S = any, A = AnyAction, PreloadedState = S> = reducers.ReducersMapObject<
	S,
	A,
	PreloadedState
>

-- *REDUX ACTION TYPES EXPORTS
local actions = require(script.types.actions)

export type AnyAction = actions.AnyAction
export type Action<T = any> = actions.Action<T>
export type ActionCreator<A, P...> = actions.ActionCreator<A, P...>
export type ActionCreatorsMapObject<A, P...> = actions.ActionCreatorsMapObject<A, P...>

-- *REDUX MIDDLEWARE TYPES EXPORTS
local middleware = require(script.types.middleware)

export type MiddlewareAPI<D = Dispatch, S = any> = middleware.MiddlewareAPI<D, S>
export type Middleware<_DispatchExt = {}, S = any, D = Dispatch> = middleware.Middleware<_DispatchExt, S, D>

-- !END EXPORTING VANILLA REDUX TYPES

-- !START EXPORTING REDUX TOOLKIT TYPES

-- *configureStore
type Middlewares<S> = configureStore.Middlewares<S>
type Enhancers = configureStore.Enhancers

export type ConfigureStoreOptions<S = any, A = actions.AnyAction, M = Middlewares<S>, E = Enhancers> =
	configureStore.ConfigureStoreOptions<S, A, M, E>

export type EnhancedStore<S = any, A = actions.AnyAction, M = Middlewares<S>, E = Enhancers> =
	configureStore.EnhancedStore<S, A, M, E>

export type ConfigureEnhancersCallback<E = Enhancers> = configureStore.ConfigureEnhancersCallback<E>

-- *createSlice
export type CreateSliceOptions<S> = createSlice.CreateSliceOptions<S>
export type Slice<S> = createSlice.Slice<S>

-- *createReducer
-- TODO: isnt this supposed to be exported directly from createReducer?
export type CaseReducer<S = any, A = {}> = reducers.CaseReducer<S, A>
export type CaseReducers<S, ActionUnion> = reducers.CaseReducers<S, ActionUnion>

-- *createAction
export type PayloadAction<P = nil, T = string, M = any, N = any> = createAction.PayloadAction<P, T, M, N>
export type PayloadActionCreator<P = any, T = string, PA = PreparedAction<P> | nil> = createAction.PayloadActionCreator<
	P,
	T,
	PA
>
export type ActionCreatorWithPayload<P, T = string> = createAction.ActionCreatorWithPayload<P, T>
export type PreparedAction<P, Args...> = createAction.PreparedAction<P, Args...>

-- *getDefaultMiddleware
export type ThunkMiddlewareFor = getDefaultMiddleware.ThunkMiddlewareFor
export type CurriedGetDefaultMiddleware = getDefaultMiddleware.CurriedGetDefaultMiddleware

-- *mapBuilders
local mapBuilders = require(script.mapBuilders)
export type ActionReducerMapBuilder<S> = mapBuilders.ActionReducerMapBuilder<S>

-- *createAsyncThunk
export type AsyncThunk<Returned, ThunkArg, ThunkApiConfig> = createAsyncThunk.AsyncThunk<
	Returned,
	ThunkArg,
	ThunkApiConfig
>
export type AsyncThunkOptions<ThunkArg, ThunkApiConfig> = createAsyncThunk.AsyncThunkOptions<ThunkArg, ThunkApiConfig>
export type AsyncThunkAction<Returned, ThunkArg, ThunkApiConfig> = createAsyncThunk.AsyncThunkAction<
	Returned,
	ThunkArg,
	ThunkApiConfig
>
export type AsyncThunkPayloadCreatorReturnValue<Returned, ThunkApiConfig> =
	createAsyncThunk.AsyncThunkPayloadCreatorReturnValue<Returned, ThunkApiConfig>
export type AsyncThunkPayloadCreator<Returned, ThunkArg, ThunkApiConfig> = createAsyncThunk.AsyncThunkPayloadCreator<
	Returned,
	ThunkArg,
	ThunkApiConfig
>

-- *thunk
export type ThunkDispatch<State, ExtraThunkArg, BasicAction> = thunk.ThunkDispatch<State, ExtraThunkArg, BasicAction>
export type ThunkAction<ReturnType, State, ExtraThunkArg, BasicAction> = thunk.ThunkAction<
	ReturnType,
	State,
	ExtraThunkArg,
	BasicAction
>
export type ThunkMiddleware<State = any, BasicAction = AnyAction, ExtraThunkArg = nil> = thunk.ThunkMiddleware<
	State,
	BasicAction,
	ExtraThunkArg
>

-- *autoBatchEnhancer
export type AutoBatchOptions = autoBatchEnhancer.AutoBatchOptions

-- *immutableStateInvariantMiddleware
export type ImmutableStateInvariantMiddlewareOptions =
	createImmutableStateInvariantMiddleware.ImmutableStateInvariantMiddlewareOptions

-- !END EXPORTING REDUX TOOLKIT TYPES

return {
	-- *matchers
	isAnyOf = matchers.isAnyOf,
	isAllOf = matchers.isAllOf,
	isPending = matchers.isPending,
	isRejected = matchers.isRejected,
	isFulfilled = matchers.isFulfilled,
	isAsyncThunkAction = matchers.isAsyncThunkAction,
	isAsyncThunkArray = matchers.isAsyncThunkArray,

	-- *vanilla
	createStore = createStore,
	combineReducers = combineReducers,
	compose = compose,
	applyMiddleware = applyMiddleware,
	bindActionCreators = bindActionCreators,

	-- *toolkit
	configureStore = configureStore,
	createSlice = createSlice,
	createReducer = createReducer.createReducer,
	getDefaultMiddleware = getDefaultMiddleware.getDefaultMiddleware,
	nanoid = nanoid,

	-- *createAction
	createAction = createAction.createAction,
	isAction = createAction.isAction,

	-- *createAsyncThunk
	createAsyncThunk = createAsyncThunk.createAsyncThunk,
	unwrapResult = createAsyncThunk.unwrapResult,

	-- *autoBatchEnhancer
	autoBatchEnhancer = autoBatchEnhancer.autoBatchEnhancer,
	prepareAutoBatched = autoBatchEnhancer.prepareAutoBatched,
	SHOULD_AUTOBATCH = autoBatchEnhancer.SHOULD_AUTOBATCH,

	-- *immutableStateInvariantMiddleware
	createImmutableStateInvariantMiddleware = createImmutableStateInvariantMiddleware.immutableStateInvariantMiddleware,
	isImmutableDefault = createImmutableStateInvariantMiddleware.isImmutableDefault,

	-- *reselect
	createSelector = createSelector.createSelector,

	-- *thunk
	thunkMiddleware = thunk.thunk,
	createThunkMiddleware = thunk.withExtraArgument,

	-- *utils
	MiddlewareArray = require(script.utils.MiddlewareArray),
	EnhancerArray = require(script.utils.EnhancerArray),

	-- @internal
	__DO_NOT_USE__trackForMutations = createImmutableStateInvariantMiddleware.trackForMutations,
}
