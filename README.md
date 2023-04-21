# rbx-redux
An (almost) 1:1 conversion of the JS state management library Redux.

This is extremely unfinished right now, so use at your own risk. (I haven't even tested if it works, so... But I'll do that eventually. It's just a proof of concept for the most part.)

The package could also be heavily unoptimized at the moment for a Luau environment. The reason was because I was writing this extremely quickly and only made a few things optimized directly for Luau.

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
    - [x] immutableStateInvariantMiddleware
    - [ ] serializableStateInvariantMiddleware
    - [x] nanoid
    - [ ] devtoolsExtension

* Redux Thunk
    - [x] thunkMiddleware

* Reselect
    - [x] createSelector

* React-Redux
    - Coming soon!

# Limitations
The only real limitation is the translations of typings. Many of Redux's types are impossible to translate due to Luau just not being able to convert them (atleast directly 1:1). With that being said, the best of effort was done to convert them.

Also, Redux uses Immer for mutations (although it's optional). This is not supported, you still have to do immutable updates like normal.

# Motivation
The motivation to do this was because I was bored. And because I wanted the modern features of Redux, mainly those from the toolkit package. Does a 1:1 translation of the entire library make much sense? No, not really. But then again, I was bored. So... whatever.

# To-do
- [ ] Make the package fully typed
- [ ] Export all typings to the entry file
- [ ] Add tests
- [ ] Add a feature similar to a production/development environment for stuff like throwing errors & warnings
- [ ] Add dev-tools extension (UI & Middleware)
- [ ] Add optimizations
- [ ] Add react-redux package
