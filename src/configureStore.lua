local reducers = require(script.Parent.types.reducers)
local actions = require(script.Parent.types.actions)
local middlewareTypes = require(script.Parent.types.middleware)
local store = require(script.Parent.types.store)

local createStore = require(script.Parent.createStore)
local combineReducers = require(script.Parent.combineReducers)
local applyMiddleware = require(script.Parent.applyMiddleware)
local compose = require(script.Parent.compose)

local isArray = require(script.Parent.utils.isArray)
local merge = require(script.Parent.merge)
local EnhancerArray = require(script.Parent.utils.EnhancerArray)

local getDefaultMiddleware = require(script.Parent.getDefaultMiddleware)
local curryGetDefaultMiddleware = getDefaultMiddleware.curryGetDefaultMiddleware

local devtoolsExtension = require(script.Parent.devtoolsExtension)
local composeWithDevTools = devtoolsExtension.composeWithDevTools

local IS_PRODUCTION = not not _G.__DEV__

type DevToolsOptions = devtoolsExtension.DevtoolsEnhancerOptions
type CurriedGetDefaultMiddleware = getDefaultMiddleware.CurriedGetDefaultMiddleware

type ConfigureStoreOptions<S = any, A = actions.AnyAction, M = Middlewares<S>, E = Enhancers> = {
	reducer: reducers.Reducer<S, A, {}> | reducers.ReducersMapObject<S, A, {}>,
	middleware: ((getDefaultMiddleware: CurriedGetDefaultMiddleware) -> M) | M,
	devTools: boolean | DevToolsOptions?,
	preloadedState: S?,
	enhancers: E?,
}

type Middlewares<S> = { middlewareTypes.Middleware<{}, S, {}> }
type Enhancers = { {} }

export type ToolkitStore<S = any, A = actions.AnyAction, M = Middlewares<S>> = store.Store<S, A, {}> & {
	dispatch: store.Dispatch<A>,
}

export type EnhancedStore<S = any, A = actions.AnyAction, M = Middlewares<S>, E = Enhancers> = ToolkitStore<S, A, M>

local function configureStore<S, A, M, E>(options: ConfigureStoreOptions<S, A, M, E>): EnhancedStore<S, A, M, E>
	local curriedGetDefaultMiddleware = curryGetDefaultMiddleware()

	local reducer = options.reducer
	local middleware = options.middleware or curriedGetDefaultMiddleware()
	local devTools = options.devTools or false
	local preloadedState = options.preloadedState
	local enhancers = options.enhancers

	local rootReducer: reducers.Reducer<S, A, {}>

	if typeof(reducer) == "function" then
		rootReducer = options.reducer
	elseif typeof(reducer) == "table" then
		rootReducer = (combineReducers(reducer) :: any) :: reducers.Reducer<S, A, {}>
	else
		error(
			'"reducer" is a required argument, and must be a function or an object of functions that can be passed to combineReducers'
		)
	end

	local finalMiddleware = middleware
	if typeof(finalMiddleware) == "function" then
		finalMiddleware = finalMiddleware(curriedGetDefaultMiddleware)

		if not IS_PRODUCTION and not isArray(finalMiddleware) then
			error("When using a middleware builder function, an array of middleware must be returned")
		end
	end

	if not IS_PRODUCTION then
		for _, item in finalMiddleware do
			if typeof(item) ~= "function" then
				error("each middleware provided to configureStore must be a function")
			end
		end
	end

	local middlewareEnhancer = applyMiddleware(unpack(finalMiddleware))

	local finalCompose = compose

	if devTools then
		-- TODO: Compose with dev tools
		finalCompose = composeWithDevTools(merge({
			trace = not IS_PRODUCTION,
		}, typeof(devTools) == "table" and devTools))
	end

	local defaultEnhancers = EnhancerArray.new(middlewareEnhancer)
	local storeEnhancers: Enhancers = defaultEnhancers

	if isArray(enhancers) then
		storeEnhancers = { middlewareEnhancer, unpack(enhancers) }
	elseif typeof(enhancers) == "function" then
		storeEnhancers = enhancers(defaultEnhancers)
	end

	local composedEnhancer = finalCompose(unpack(storeEnhancers))

	return createStore(rootReducer, preloadedState, composedEnhancer)
end

return configureStore
