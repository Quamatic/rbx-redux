local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Redux = require(ReplicatedStorage.Redux)

local spy = require(script.Parent.helpers.spy)

local originalNamespaceMethods = {}

local function clearAllMocks()
	for originalMethod, orignalMethodFn in originalNamespaceMethods do
		Redux[originalMethod] = orignalMethodFn
	end

	table.clear(originalNamespaceMethods)
end

local function spyOn(method)
	local original = Redux[method]
	local new = spy(original)

	originalNamespaceMethods[method] = original
	Redux[method] = new.fn

	return new
end

return function()
	describe("configureStore", function()
		local applyMiddleware = spyOn("applyMiddleware")
		local createStore = spyOn("createStore")
		local combineReducers = spyOn("combineReducers")

		local reducer = function(state, action)
			state = state or {}
			return state
		end

		beforeEach(function()
			clearAllMocks()
		end)

		describe("given a function reducer", function()
			it("calls createStore with the reducer", function()
				Redux.configureStore({ reducer = reducer })
				expect(Redux.configureStore({ reducer = reducer })).to.be.a("table")
				expect(applyMiddleware.hasBeenCalled()).to.equal(true)
				expect(createStore.hasBeenCalled()).to.equal(true)
			end)
		end)

		describe("given an object of reducers", function()
			it("calls createStore with the combined reducers", function()
				local reducer = {
					reducer = function()
						return true
					end,
				}

				expect(Redux.configureStore({ reducer = reducer })).to.be.a("table")
				expect(combineReducers.wasCalledWith(reducer)).to.equal(true)
				expect(applyMiddleware.hasBeenCalled()).to.equal(true)
				expect(createStore.hasBeenCalled()).to.equal(true)
			end)
		end)

		describe("given no reducer", function()
			it("throws", function()
				expect(Redux.configureStore).to.throw()
			end)
		end)

		describe("given no middleware", function()
			it("calls createStore without any middleware", function()
				expect(Redux.configureStore({ reducer = reducer, middleware = {} })).to.be.a("table")
				expect(applyMiddleware.hasBeenCalled()).to.equal(true)
				expect(createStore.hasBeenCalled()).to.equal(true)
			end)
		end)

		describe("given nil middleware", function()
			it("calls createStore with the default middleware", function()
				expect(Redux.configureStore({ reducer = reducer, middleware = nil })).to.be.a("table")
				expect(applyMiddleware.hasBeenCalled()).to.equal(true)
			end)
		end)

		describe("given a middleware creation function that returns undefined", function()
			it("throws an error", function()
				local invalidBuilder = spy(function(_getDefaultMiddleware)
					return nil
				end)

				expect(function()
					Redux.configureStore({ middleware = invalidBuilder, reducer = reducer })
				end).to.throw()
			end)
		end)

		describe("given a middleware creation function that returns an array with non-functions", function()
			it("throws an error", function()
				local invalidBuilder = spy(function(_getDefaultMiddleware)
					return { true }
				end)

				expect(function()
					Redux.configureStore({ middleware = invalidBuilder, reducer = reducer })
				end).to.throw()
			end)
		end)

		describe("given custom middleware that contains non-functions", function()
			it("throws an error", function()
				expect(function()
					Redux.configureStore({ middleware = { true }, reducer = reducer })
				end).to.throw()
			end)
		end)

		describe("given custom middleware", function()
			it("calls createStore with custom middleware and without default middleware", function()
				local thank = function(_store)
					return function(nextDispatch)
						return function(action)
							return nextDispatch(action)
						end
					end
				end

				expect(Redux.configureStore({ reducer = reducer, middleware = { thank } })).to.be.a("table")
				expect(applyMiddleware.wasCalledWith(thank)).to.equal(true)
			end)
		end)

		describe("middleware builder notation", function()
			it("calls builder, passes getDefaultMiddleware and uses returned middlewares", function()
				local thank = spy(function(_store)
					return function(_nextDispatch)
						return function(_action)
							return "foobar"
						end
					end
				end)

				local builder = spy(function(getDefaultMiddleware)
					expect(getDefaultMiddleware).to.be.a("function")
					expect(getDefaultMiddleware()).to.be.a("table")

					return { thank.fn }
				end)

				local store = Redux.configureStore({ middleware = builder.fn, reducer = reducer })
				expect(builder.hasBeenCalled()).to.equal(true)

				expect(store.dispatch({ type = "test" })).to.equal("foobar")
			end)
		end)

		describe("given preloadedState", function()
			it("calls createStore with enhancers", function()
				local enhancer = function(_nextDispatch)
					return _nextDispatch
				end

				expect(Redux.configureStore({ reducer = reducer, enhancers = { enhancer } })).to.be.a("table")
				expect(applyMiddleware.hasBeenCalled()).to.equal(true)
			end)

			it("accepts a callback for customizing enhancers", function()
				local dummyEnhancerCalled = false

				local dummyEnhancer = function(createStore_)
					return function(reducer_, ...)
						dummyEnhancerCalled = true
						return createStore_(reducer_, ...)
					end
				end

				local reducer_ = function()
					return {}
				end

				local _store = Redux.configureStore({
					reducer = reducer_,
					enhancers = function(defaultEnhancers)
						return defaultEnhancers:concat(dummyEnhancer)
					end,
				})

				expect(dummyEnhancerCalled).to.equal(true)
			end)
		end)
	end)
end
