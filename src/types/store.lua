local reducers = require(script.Parent.reducers)

export type Dispatch<Action, Args...> = <T>(action: Action, Args...) -> T

export type StoreEnhancerStoreCreator<Ext = {}, StateExt = {}> = (
) -> <S, A, PreloadedState>(
	reducer: reducers.Reducer<S, A, PreloadedState>,
	preloadedState: PreloadedState?
) -> Store<S, A, StateExt> & Ext

export type StoreEnhancer<Ext = {}, StateExt = {}> = <NextExt, NextStateExt>(
	next: StoreEnhancerStoreCreator<NextExt, NextStateExt>
) -> StoreEnhancerStoreCreator<NextExt & Ext, NextStateExt & Ext>

export type StoreCreator =
	(<S, A, Ext, StateExt>(
		reducer: reducers.Reducer<S, A, {}>,
		enhancer: StoreEnhancer<Ext, StateExt>?
	) -> Store<S, A, StateExt> & Ext)
	| (<S, A, Ext, StateExt, PreloadedState>(
		reducer: reducers.Reducer<S, A, PreloadedState>,
		preloadedState: PreloadedState?,
		---@diagnostic disable-next-line: undefined-type
		enhancer: StoreEnhancer<Ext>?
	) -> Store<S, A, StateExt> & Ext)

export type Unsubscribe = () -> nil
type ListenerCallback = () -> nil

export type Store<S = any, A = any, StateExt = {}> = {
	dispatch: Dispatch,
	getState: () -> S & StateExt,
	subscribe: (listener: ListenerCallback) -> Unsubscribe,
	replaceReducer: (nextReducer: reducers.Reducer<S, A, StateExt>) -> nil,
}

return nil
