# rbx-redux
An (almost) 1:1 conversion of the JS state management library Redux.

I did my best to translate many of the features of Redux, including packages made for it, such as toolkit and thunk. However, translating these features was quite hard,
so even though I did lots of unit testing, there still could be some bugs or unoptimized sections. If you happen to notice anything, please open an issue.

# Installation
Add this to your `wally.toml` file:

```console
Redux = "quamatic/rbx-redux@1.0.0"
```

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
