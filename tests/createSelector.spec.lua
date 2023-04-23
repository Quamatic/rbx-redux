local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Redux = require(ReplicatedStorage.Redux)

local deepEquals = require(script.Parent.helpers.deepEquals)
local spy = require(script.Parent.helpers.spy)

local slice = require(ReplicatedStorage.Redux.utils.slice) -- quick access
local reduce = require(ReplicatedStorage.Redux.utils.reduce) -- quick access

local numOfStates = 1000000
local states = {}

for _ = 1, numOfStates do
	table.insert(states, { a = 1, b = 2 })
end

return function()
	describe("createSelector", function()
		describe("basic selector creator", function()
			describe("basic selector", function()
				local selector = Redux.createSelector(function(state)
					return state.a
				end, function(a)
					return a
				end)

				local firstState = { a = 1 }
				local firstStateNewPointer = { a = 1 }
				local secondState = { a = 2 }

				expect(selector(firstState)).to.equal(1)
				expect(selector(firstState)).to.equal(1)
				expect(selector.recomputations()).to.equal(1)
				expect(selector(firstStateNewPointer)).to.equal(1)
				expect(selector.recomputations()).to.equal(1)
				expect(selector(secondState)).to.equal(2)
				expect(selector.recomputations()).to.equal(2)
			end)

			it("don't pass extra parameters to inputSelector when only called with the state", function()
				local selector = Redux.createSelector(function(...)
					return select("#", ...)
				end, function(a)
					return a
				end)

				expect(selector({})).to.equal(1)
			end)

			it("basic selector multiple keys", function()
				local selector = Redux.createSelector(function(state)
					return state.a
				end, function(state)
					return state.b
				end, function(a, b)
					return a + b
				end)

				local state1 = { a = 1, b = 2 }

				expect(selector(state1)).to.equal(3)
				expect(selector(state1)).to.equal(3)
				expect(selector.recomputations()).to.equal(1)

				local state2 = { a = 2, b = 3 }

				expect(selector(state2)).to.equal(5)
				expect(selector(state2)).to.equal(5)
				expect(selector.recomputations()).to.equal(2)
			end)

			it("basic selector invalid input selector", function()
				expect(function()
					Redux.createSelector(
						function(state)
							return state.a
						end,
						function(state)
							return state.b
						end,
						"not a selector",
						function(a, b)
							return a + b
						end
					)
				end).to.throw()

				expect(function()
					Redux.createSelector(function(state)
						return state.a
					end, "not a function")
				end).to.throw()
			end)

			it("basic selector cache hit performance", function()
				_G.__RUN_PERFORMANCE_TESTS__ = true

				if not _G.__RUN_PERFORMANCE_TESTS__ then
					return
				end

				local selector = Redux.createSelector(function(state)
					return state.a
				end, function(state)
					return state.b
				end, function(a, b)
					return a + b
				end)

				local state1 = { a = 1, b = 2 }

				local start = os.clock()
				for _ = 1, 1000000 do
					selector(state1)
				end

				local totalTimeTaken = os.clock() - start

				expect(selector(state1)).to.equal(3)
				expect(selector.recomputations()).to.equal(1)
				expect(totalTimeTaken < 1).to.equal(true)
			end)

			it("basic selector cache hit performance for state changes but shallowly equal selector args", function()
				if not _G.__RUN_PERFORMANCE_TESTS__ then
					return
				end

				local selector = Redux.createSelector(function(state)
					return state.a
				end, function(state)
					return state.b
				end, function(a, b)
					return a + b
				end)

				local start = os.clock()
				for i = 1, numOfStates do
					selector(states[i])
				end

				local totalTimeTaken = os.clock() - start

				expect(selector(states[1])).to.equal(3)
				expect(selector.recomputations()).to.equal(1)
				-- Not sure why this wont perform under a second, some optimization is needed
				-- It has a range that seems to be [1.03, 1.2]
				expect(totalTimeTaken).to.be.near(1, 0.2)
			end)

			it("memoized composite arguments", function()
				local selector = Redux.createSelector(function(state)
					return state.sub
				end, function(sub)
					return sub
				end)

				local state1 = { sub = { a = 1 } }

				expect(deepEquals(selector(state1), { a = 1 })).to.equal(true)
				expect(deepEquals(selector(state1), { a = 1 })).to.equal(true)
				expect(selector.recomputations()).to.equal(1)

				local state2 = { sub = { a = 2 } }

				expect(deepEquals(selector(state2), { a = 2 })).to.equal(true)
				expect(selector.recomputations()).to.equal(2)
			end)

			it("first argument can be an array", function()
				local selector = Redux.createSelector({
					function(state)
						return state.a
					end,
					function(state)
						return state.b
					end,
				}, function(a, b)
					return a + b
				end)

				expect(selector({ a = 1, b = 2 })).to.equal(3)
				expect(selector({ a = 1, b = 2 })).to.equal(3)
				expect(selector.recomputations()).to.equal(1)

				expect(selector({ a = 3, b = 2 })).to.equal(5)
				expect(selector.recomputations()).to.equal(2)
			end)

			it("can accept props", function()
				local called = 0
				local selector = Redux.createSelector(function(state)
					return state.a
				end, function(state)
					return state.b
				end, function(state, props)
					return props.c
				end, function(a, b, c)
					called += 1
					return a + b + c
				end)

				expect(selector({ a = 1, b = 2 }, { c = 100 })).to.equal(103)
			end)

			it("recomputes result after exception", function()
				local called = 0
				local selector = Redux.createSelector(function(state)
					return state.a
				end, function()
					called += 1
					error("test error")
				end)

				expect(function()
					selector({ a = 1 })
				end).to.throw("test error")

				expect(function()
					selector({ a = 1 })
				end).to.throw("test error")

				expect(called).to.equal(2)
			end)

			it("memoizes previous result before exception", function()
				local called = 0
				local selector = Redux.createSelector(function(state)
					return state.a
				end, function(a)
					called += 1
					if a > 1 then
						error("test error")
					end
					return a
				end)

				local state1 = { a = 1 }
				local state2 = { a = 2 }

				expect(selector(state1)).to.equal(1)

				expect(function()
					selector(state2)
				end).to.throw("test error")

				expect(selector(state1)).to.equal(1)
				expect(called).to.equal(2)
			end)
		end)

		describe("Combining selectors", function()
			it("chained selector", function()
				local selector1 = Redux.createSelector(function(state)
					return state.sub
				end, function(sub)
					return sub
				end)

				local selector2 = Redux.createSelector(selector1, function(sub)
					return sub.a
				end)

				local state1 = { sub = { a = 1 } }

				expect(selector2(state1)).to.equal(1)
				expect(selector2(state1)).to.equal(1)
				expect(selector2.recomputations()).to.equal(1)

				local state2 = { sub = { a = 2 } }

				expect(selector2(state2)).to.equal(2)
				expect(selector2.recomputations()).to.equal(2)
			end)

			it("chained selector with props", function()
				local selector1 = Redux.createSelector(function(state)
					return state.sub
				end, function(state, props)
					return props.x
				end, function(sub, x)
					return { sub = sub, x = x }
				end)

				local selector2 = Redux.createSelector(selector1, function(state, props)
					return props.y
				end, function(param, y)
					return param.sub.a + param.x + y
				end)

				local state1 = { sub = { a = 1 } }

				expect(selector2(state1, { x = 100, y = 200 })).to.equal(301)
				expect(selector2(state1, { x = 100, y = 200 })).to.equal(301)
				expect(selector2.recomputations()).to.equal(1)

				local state2 = { sub = { a = 2 } }
				expect(selector2(state2, { x = 100, y = 201 })).to.equal(303)
				expect(selector2.recomputations()).to.equal(2)
			end)

			it("chained selector with variadic args", function()
				local selector1 = Redux.createSelector(function(state)
					return state.sub
				end, function(state, props, another)
					return props.x + another
				end, function(sub, x)
					return { sub = sub, x = x }
				end)

				local selector2 = Redux.createSelector(selector1, function(state, props)
					return props.y
				end, function(param, y)
					return param.sub.a + param.x + y
				end)

				local state1 = { sub = { a = 1 } }

				expect(selector2(state1, { x = 100, y = 200 }, 100)).to.equal(401)
				expect(selector2(state1, { x = 100, y = 200 }, 100)).to.equal(401)
				expect(selector2.recomputations()).to.equal(1)

				local state2 = { sub = { a = 2 } }
				expect(selector2(state2, { x = 100, y = 201 }, 200)).to.equal(503)
				expect(selector2.recomputations()).to.equal(2)
			end)

			it("override valueEquals", function()
				local createOverridenSelector = Redux.createSelectorCreator(Redux.defaultMemoize, function(a, b)
					return typeof(a) == typeof(b)
				end)

				local selector = createOverridenSelector(function(state)
					return state.a
				end, function(a)
					return a
				end)

				expect(selector({ a = 1 })).to.equal(1)
				expect(selector({ a = 2 })).to.equal(1)
				expect(selector.recomputations()).to.equal(1)

				expect(selector({ a = "A" })).to.equal("A")
				expect(selector.recomputations()).to.equal(2)
			end)
		end)

		describe("Customizing selectors", function()
			it("custom memoize", function()
				local hashFn = function(...)
					return reduce({ ... }, function(acc, val)
						return acc .. "+" .. HttpService:JSONEncode(val)
					end)
				end

				local function lodashMemoize(func, resolver)
					local cache = {}

					return function(...)
						local args = { ... }
						local key = if resolver then resolver(...) else args[1]

						if cache[key] then
							return cache[key]
						end

						local result = func(...)
						cache[key] = result

						return result
					end
				end

				local customSelectorCreator = Redux.createSelectorCreator(lodashMemoize, hashFn)
				local selector = customSelectorCreator(function(state)
					return state.a
				end, function(state)
					return state.b
				end, function(a, b)
					return a + b
				end)

				expect(selector({ a = 1, b = 2 })).to.equal(3)
				expect(selector({ a = 1, b = 2 })).to.equal(3)
				expect(selector.recomputations()).to.equal(1)
				expect(selector({ a = 1, b = 3 })).to.equal(4)
				expect(selector.recomputations()).to.equal(2)
				expect(selector({ a = 1, b = 3 })).to.equal(4)
				expect(selector.recomputations()).to.equal(2)
				expect(selector({ a = 2, b = 3 })).to.equal(5)
				expect(selector.recomputations()).to.equal(3)
			end)

			it("createSelector accepts direct memoizer arguments", function()
				local memoizer1Calls = 0
				local memoizer2Calls = 0
				local memoizer3Calls = 0

				local defaultMemoizeAcceptsFirstArgDirectly = Redux.createSelector(function(state)
					return state.a
				end, function(state)
					return state.b
				end, function(a, b)
					return a + b
				end, {
					memoizeOptions = function(a, b)
						memoizer1Calls += 1
						return a == b
					end,
				})

				defaultMemoizeAcceptsFirstArgDirectly({ a = 1, b = 2 })
				defaultMemoizeAcceptsFirstArgDirectly({ a = 1, b = 3 })

				expect(memoizer1Calls > 0).to.equal(true)

				local defaultMemoizeAcceptsArgsAsArray = Redux.createSelector(function(state)
					return state.a
				end, function(state)
					return state.b
				end, function(a, b)
					return a + b
				end, {
					memoizeOptions = {
						function(a, b)
							memoizer2Calls += 1
							return a == b
						end,
					},
				})

				defaultMemoizeAcceptsArgsAsArray({ a = 1, b = 2 })
				defaultMemoizeAcceptsArgsAsArray({ a = 1, b = 3 })

				expect(memoizer2Calls > 0).to.equal(true)

				local createSelectorWithSeparateArg = Redux.createSelectorCreator(Redux.defaultMemoize, function(a, b)
					memoizer3Calls += 1
					return a == b
				end)

				local defaultMemoizeAcceptsArgFromCSC = createSelectorWithSeparateArg(function(state)
					return state.a
				end, function(state)
					return state.b
				end, function(a, b)
					return a + b
				end)

				defaultMemoizeAcceptsArgFromCSC({ a = 1, b = 2 })
				defaultMemoizeAcceptsArgFromCSC({ a = 1, b = 3 })

				expect(memoizer3Calls > 0).to.equal(true)
			end)
		end)

		describe("defaultMemoize", function()
			it("Basic memoization", function()
				local called = 0
				local memoized = Redux.defaultMemoize(function(state)
					called += 1
					return state.a
				end)

				local o1 = { a = 1 }
				local o2 = { a = 2 }

				expect(memoized(o1)).to.equal(1)
				expect(memoized(o1)).to.equal(1)
				expect(called).to.equal(1)

				expect(memoized(o2)).to.equal(2)
				expect(called).to.equal(2)
			end)

			it("Memoizes with multiple arguments", function()
				local memoized = Redux.defaultMemoize(function(...)
					return reduce({ ... }, function(sum, value)
						return sum + value
					end, 0)
				end)

				expect(memoized(1, 2)).to.equal(3)
				expect(memoized(1)).to.equal(1)
			end)

			it("Memoizes with equalityCheck override", function()
				local called = 0

				local valueEquals = function(a, b)
					return typeof(a) == typeof(b)
				end

				local memoized = Redux.defaultMemoize(function(a)
					called += 1
					return a
				end, valueEquals)

				expect(memoized(1)).to.equal(1)
				expect(memoized(1)).to.equal(1)
				expect(called).to.equal(1)
				expect(memoized("A")).to.equal("A")
				expect(called).to.equal(2)
			end)

			it("Passes correct objects to equalityCheck", function()
				local fallthroughs = 0

				local function shallowEqual(a, b)
					if a == b then
						return true
					end

					fallthroughs += 1

					local countA = 0
					local countB = 0

					for key in a do
						if a[key] ~= b[key] then
							return false
						end
						countA += 1
					end

					for _ in b do
						countB += 1
					end

					return countA == countB
				end

				local someObject = { foo = "bar" }
				local anotherObject = { foo = "bar" }
				local memoized = Redux.defaultMemoize(function(a)
					return a
				end, shallowEqual)

				memoized(someObject)
				expect(fallthroughs).to.equal(0)

				memoized(anotherObject)
				expect(fallthroughs).to.equal(1)
			end)

			it("Accepts a max size greater than 1 with LRU cache behavior", function()
				local funcCalls = 0

				local memoizer = Redux.defaultMemoize(function(state)
					funcCalls += 1
					return state
				end, {
					maxSize = 3,
				})

				memoizer("a") -- ['a']
				expect(funcCalls).to.equal(1)

				memoizer("a") -- ['a']
				expect(funcCalls).to.equal(1)

				memoizer("b") -- ['b', 'a']
				expect(funcCalls).to.equal(2)

				memoizer("c") -- ['c', 'b', 'a']
				expect(funcCalls).to.equal(3)

				memoizer("d") -- ['d', 'c', 'b']
				expect(funcCalls).to.equal(4)

				memoizer("a") -- ['a', 'd', 'c']
				expect(funcCalls).to.equal(5)

				memoizer("c") -- ['c', 'a', 'd']
				expect(funcCalls).to.equal(5)

				memoizer("e") -- ['e', 'c', 'a']
				expect(funcCalls).to.equal(6)

				memoizer("d") -- ['d', 'e', 'c']
				expect(funcCalls).to.equal(7)
			end)

			it("Allows reusing an existing result if they are equivalent", function()
				local todos1 = {
					{ id = 1, name = "a" },
					{ id = 2, name = "b" },
					{ id = 3, name = "c" },
				}

				local todos2 = slice(todos1)
				todos2[3] = { id = 3, name = "d" }

				local function is(x, y)
					if x == y then
						return x ~= 0 and y ~= 0 and 1 / x == 1 / y
					else
						return x ~= x and y ~= y
					end
				end

				local function shallowEqual(a, b)
					if is(a, b) then
						return true
					end

					if typeof(a) ~= "table" and typeof(b) ~= "table" then
						return false
					end

					if #a ~= #b then
						return false
					end

					for key, value in a do
						if not is(value, b[key]) then
							return false
						end
					end

					return true
				end

				for _, maxSize in { 1, 3 } do
					local funcCalls = 0

					local memoizer = Redux.defaultMemoize(function(state)
						funcCalls += 1

						local newState = {}
						for index, todo in state do
							newState[index] = todo.id
						end

						return newState
					end, {
						maxSize = maxSize,
						resultEqualityCheck = shallowEqual,
					})

					local ids1 = memoizer(todos1)
					expect(funcCalls).to.equal(1)

					local ids2 = memoizer(todos1)
					expect(funcCalls).to.equal(1)
					expect(ids2).to.equal(ids1)

					local ids3 = memoizer(todos2)
					expect(funcCalls).to.equal(2)
					expect(ids3).to.equal(ids1)
				end
			end)

			it("updates the cache key even if resultEqualityCheck is a hit", function()
				local selector = spy(function(x)
					return x
				end)

				local equalityCheck = spy(function(a, b)
					return a == b
				end)

				local resultEqualityCheck = spy(function(a, b)
					return typeof(a) == typeof(b)
				end)

				local memoizedFn = Redux.defaultMemoize(selector.fn, {
					maxSize = 1,
					resultEqualityCheck = resultEqualityCheck.fn,
					equalityCheck = equalityCheck.fn,
				})

				memoizedFn("cache this result")
				expect(selector.wasNthExactlyCalled(1)).to.equal(true)

				local result = memoizedFn("arg1")
				expect(result).to.equal("cache this result")
				expect(selector.wasNthExactlyCalled(2)).to.equal(true)

				local result2 = memoizedFn("arg1")
				expect(result2).to.equal("cache this result")
				expect(selector.wasNthExactlyCalled(2)).to.equal(true)
			end)

			it("Allows caching a value of `nil`", function()
				local state = {
					foo = { baz = "baz" },
					bar = "qux",
				}

				local fooChangeSpy = spy()

				local fooChangeHandler = Redux.createSelector(function(state)
					return state.foo
				end, fooChangeSpy.fn)

				fooChangeHandler(state)
				expect(fooChangeSpy.wasNthExactlyCalled(1)).to.equal(true)

				fooChangeHandler(state)
				expect(fooChangeSpy.wasNthExactlyCalled(1)).to.equal(true)

				local state2 = { a = 1 }
				local count = 0

				local selector = Redux.createSelector({
					function(state)
						return state.a
					end,
				}, function()
					count += 1
					return nil
				end)

				selector(state)
				expect(count).to.equal(1)
				selector(state)
				expect(count).to.equal(1)
			end)

			it("Accepts an options object as an arg", function()
				local memoizer1Calls = 0

				local acceptsEqualityCheckAsOption = Redux.defaultMemoize(function(a)
					return a
				end, {
					equalityCheck = function(a, b)
						memoizer1Calls += 1
						return a == b
					end,
				})

				acceptsEqualityCheckAsOption(42)
				acceptsEqualityCheckAsOption(43)

				expect(memoizer1Calls > 0).to.equal(true)

				local called = 0
				local fallsBackToDefaultEqualityIfNoArgGiven = Redux.defaultMemoize(function(state)
					called += 1
					return state.a
				end, {})

				local o1 = { a = 1 }
				local o2 = { a = 2 }

				expect(fallsBackToDefaultEqualityIfNoArgGiven(o1)).to.equal(1)
				expect(fallsBackToDefaultEqualityIfNoArgGiven(o1)).to.equal(1)
				expect(called).to.equal(1)
				expect(fallsBackToDefaultEqualityIfNoArgGiven(o2)).to.equal(2)
				expect(called).to.equal(2)
			end)

			it("Exposes a clearCache method on the memoized function", function()
				itSKIP("clearCache is not a method for now")
			end)
		end)

		describe("createStructureSelector", function()
			it("structured selector", function()
				local selector = Redux.createStructureSelector({
					x = function(state)
						return state.a
					end,
					y = function(state)
						return state.b
					end,
				})

				local firstResult = selector({ a = 1, b = 2 })
				expect(deepEquals(firstResult, { x = 1, y = 2 })).to.equal(true)
				expect(deepEquals(selector({ a = 1, b = 2 }), firstResult)).to.equal(true)

				local secondResult = selector({ a = 2, b = 2 })
				expect(deepEquals(secondResult, { x = 2, y = 2 })).to.equal(true)
				expect(deepEquals(selector({ a = 2, b = 2 }), secondResult)).to.equal(true)
			end)

			it("structured selector with invalid arguments", function()
				expect(function()
					Redux.createStructureSelector(function(state)
						return state.a
					end, function(state)
						return state.b
					end)
				end).to.throw()

				expect(function()
					Redux.createStructureSelector({
						a = function(state)
							return state.b
						end,
						c = "d",
					})
				end).to.throw()
			end)

			it("structured selector with custom selector creator", function()
				local customSelectorCreator = Redux.createSelectorCreator(Redux.defaultMemoize, function(a, b)
					return a == b
				end)

				local selector = Redux.createStructureSelector({
					x = function(state)
						return state.a
					end,
					y = function(state)
						return state.b
					end,
				}, customSelectorCreator)

				local firstResult = selector({ a = 1, b = 2 })
				expect(deepEquals(firstResult, { x = 1, y = 2 })).to.equal(true)
				expect(deepEquals(selector({ a = 1, b = 2 }), firstResult)).to.equal(true)
				expect(deepEquals(selector({ a = 2, b = 2 }), { x = 2, y = 2 })).to.equal(true)
			end)
		end)

		describe("createSelector exposed utils", function()
			it("resetRecomputations", function()
				local selector = Redux.createSelector(function(state)
					return state.a
				end, function(a)
					return a
				end)

				expect(selector({ a = 1 })).to.equal(1)
				expect(selector({ a = 1 })).to.equal(1)
				expect(selector.recomputations()).to.equal(1)
				expect(selector({ a = 2 })).to.equal(2)
				expect(selector.recomputations()).to.equal(2)

				selector.resetRecomputations()
				expect(selector.recomputations()).to.equal(0)

				expect(selector({ a = 1 })).to.equal(1)
				expect(selector({ a = 1 })).to.equal(1)
				expect(selector.recomputations()).to.equal(1)
				expect(selector({ a = 2 })).to.equal(2)
				expect(selector.recomputations()).to.equal(2)
			end)

			it("export last function as resultFunc", function()
				local lastFunction = function() end

				local selector = Redux.createSelector(function(state)
					return state.a
				end, lastFunction)

				expect(selector.resultFunc).to.equal(lastFunction)
			end)

			it("export dependencies as dependencies", function()
				local dependencyA = function() end
				local dependencyB = function() end

				local selector = Redux.createSelector(dependencyA, dependencyB, function() end)
				expect(deepEquals(selector.dependencies, { dependencyA, dependencyB }))
			end)

			it("export lastResult function", function()
				local selector = Redux.createSelector(function(state)
					return state.a
				end, function(state)
					return state.b
				end, function(a, b)
					return a + b
				end)

				local result = selector({ a = 1, b = 2 })
				expect(result).to.equal(3)
				expect(selector.lastResult()).to.equal(3)
			end)
		end)
	end)
end
