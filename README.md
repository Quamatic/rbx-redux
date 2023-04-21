# rbx-redux
An (almost) 1:1 conversion of the JS state management library Redux.

The package has been heavily tested (with over 200 unit tests!), so it is pretty stable to use atm. If you are experiencing a bug or an issue, please don't hesitate to open an issue!

Although the package is usable, some things may be unoptimized. If you happen to notice something that could be changed, please open a PR.

# What's included?

* Redux
    - [x] createStore (obviously :P)
    - [x] bindActionCreators
    - [x] combineReducers
    - [x] compose
    - [x] applyMiddleware

* Redux Devtools
    - [x] autoBatchEnhancer
    - [x] getDefaultMiddleware
    - [x] configureStore
    - [x] createAction
    - [x] createAsyncThunk
    - [x] createReducer
    - [x] createSlice
    - [x] nanoid
    - [x] matchers
    - [x] immutableStateInvariantMiddleware
    - [ ] serializableStateInvariantMiddleware (This might not be super practical to implement, I'll see.)
    - [ ] createListenerMiddleware
    - [ ] creatEntityAdapter
    - [ ] devtoolsExtension
    - [ ] Immer (Probably won't be added due to added layer of complexity.)
    - [ ] RTK Query (This will not be implemented, has no practical use on Roblox.)

* Redux Thunk
    - [x] thunkMiddleware
    - [x] withExtraArgument

* Reselect
    - [x] createSelector
    - [x] createSelectorCreator

* React-Redux
    - Coming soon!

# Motivation
I wanted to have the modern features of Redux. Porting most of the library was quite overkill, but it was still fun to do.

# To-do
- [ ] Make the package fully typed
- [ ] Export all typings to the entry file
- [ ] Add a feature similar to a production/development environment for stuff like throwing errors & warnings
- [ ] Add optimizations
