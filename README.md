# rbx-redux
An (almost) 1:1 conversion of the JS state management library Redux.

The package has been heavily tested (with over 200 unit tests!), so it is pretty stable to use atm. If you are experiencing a bug or an issue, please don't hesitate to open an issue!

Although the package is usable, some things may be unoptimized. If you happen to notice something that could be changed, please open a PR.

# To-do before package release
- [ ] Make the package fully typed
- [ ] Export all typings to the entry file
- [x] Add a feature similar to detect a development environment for throwing errors, warnings, and enabling certain features.
- [ ] Optimize

# Installation
Wally package will be pushed once the to-do above is complete.

# What's included?
NOTE: Just because something is said to be included does not guarantee it works correctly. There are unit tests put in place, but it may not catch all possible cases.

* Redux
    - [x] createStore (obviously :P)
    - [x] bindActionCreators
    - [x] combineReducers
    - [x] compose
    - [x] applyMiddleware

* Redux Toolkit
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
    - [ ] serializableStateInvariantMiddleware
        - For a Roblox environment, I do no see any practical use. But it still can be added.
    - [ ] createListenerMiddleware
    - [ ] creatEntityAdapter
    - [ ] Use of Immer to mutate state
        - Immer in Redux makes immutable state changes a breeze, but implementing it would just be another added layer of complexity (and I don't feel like
        trying to make it). The idea of using proxies is neat, but it could be quite slow. 
    - [ ] RTK Query
        - RTK Query definitely has no practical use on Roblox, and won't be implemented.

* Redux DevTools
    - [ ] DevTools are an amazing extension of Redux, and are great for live viewing the tree of a store. However, the devtools package itself it quite
    large with the amount of features it has, and would take quite the effort to implement. It is possible, but tough.

* Redux Thunk
    - [x] thunkMiddleware
    - [x] withExtraArgument

* Reselect
    - [x] createSelector
    - [x] createSelectorCreator

* React-Redux
    - Coming soon!
