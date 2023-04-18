# rbx-redux
An (almost) 1:1 conversion of the JS state management library Redux.

This is extremely unfinished right now, so use at your own risk. (I haven't even tested if it works, so... But I'll do that eventually. It's just a proof of concept for the most part.)

# Packages
All redux packages (dev-tools, thunk, etc.) are bundled into just this one package. I might change my mind and turn them all into seperate packages, but for now this is how it is designed.

# Limitations
The only real limitation is the translations of typings. Many of Redux's types are impossible to translate due to Luau just not being able to convert them (atleast directly 1:1). With that being said, the best of effort was done to convert them.

# To-do
- [ ] Make the package fully typed
- [ ] Export all typings to the entry file
- [ ] Add tests
- [ ] Add dev-tools extension (UI & Middleware)
- [ ] Add optimizations