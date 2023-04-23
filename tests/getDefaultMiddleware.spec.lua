local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Redux = require(ReplicatedStorage.Redux)

local deepEquals = require(script.Parent.helpers.deepEquals)

return function()
	describe("getDefaultMiddleware", function()
		it("returns an array with additional middleware in development", function()
			local middleware = Redux.getDefaultMiddleware()
			expect(table.find(middleware, Redux.thunkMiddleware)).to.be.ok()
			expect(#middleware).to.be.near(1)
		end)

		it("removes the thunk middleware if disabled", function()
			local middleware = Redux.getDefaultMiddleware({ thunk = false })

			expect(table.find(middleware, Redux.thunkMiddleware)).never.to.be.ok()
			expect(#middleware).to.equal(0)
		end)

		it("allows passing options to thunk", function()
			local extraArgument = 42
			local middleware = Redux.getDefaultMiddleware({
				thunk = { extraArgument = extraArgument },
				immutableCheck = false,
				serializableCheck = false,
			})

			local m2 = Redux.getDefaultMiddleware({
				thunk = false,
			})

			-- Cant do this in luau
			--expectType<MiddlewareArray<[]>>(m2)

			local dummyMiddleware = function(storeApi)
				return function(nextDispatch)
					return function(action)
						-- noop
					end
				end
			end

			local dummyMiddleware2 = function(storeApi)
				return function(nextDispatch)
					return function(action)
						-- noop
					end
				end
			end

			local m3 = middleware:concat(dummyMiddleware, dummyMiddleware2)

			local testThunk = function(_dispatch, _getState, extraArg)
				expect(extraArg).to.equal(extraArgument)
			end

			local reducer = function()
				return {}
			end

			local store = Redux.configureStore({
				reducer = reducer,
				middleware = middleware,
			})

			store.dispatch(testThunk)
		end)
	end)

	describe("MiddlewareArray functionality", function()
		local middleware1 = function()
			return function(nextDispatch)
				return function(action)
					return nextDispatch(action)
				end
			end
		end

		local middleware2 = function()
			return function(nextDispatch)
				return function(action)
					return nextDispatch(action)
				end
			end
		end

		local defaultMiddleware = Redux.getDefaultMiddleware()
		local originalDefaultMiddleware = table.clone(defaultMiddleware)

		it("allows to prepend a single value", function()
			local prepended = defaultMiddleware:prepend(middleware1)

			expect(deepEquals(prepended, { middleware1, unpack(defaultMiddleware) })).to.equal(true)
			expect(prepended.__index).to.equal(Redux.MiddlewareArray) -- quick instanceof check
			expect(prepended).never.to.equal(defaultMiddleware)
			expect(deepEquals(defaultMiddleware, originalDefaultMiddleware)).to.equal(true)
		end)

		it("allows to prepend multiple values (array as first argument)", function()
			local prepended = defaultMiddleware:prepend({ middleware1, middleware2 })

			expect(deepEquals(prepended, { middleware1, middleware2, unpack(defaultMiddleware) })).to.equal(true)
			expect(prepended.__index).to.equal(Redux.MiddlewareArray) -- quick instanceof check
			expect(prepended).never.to.equal(defaultMiddleware)
			expect(deepEquals(defaultMiddleware, originalDefaultMiddleware)).to.equal(true)
		end)

		it("allows to prepend multiple values (rest)", function()
			local prepended = defaultMiddleware:prepend(middleware1, middleware2)

			expect(deepEquals(prepended, { middleware1, middleware2, unpack(defaultMiddleware) })).to.equal(true)
			expect(prepended.__index).to.equal(Redux.MiddlewareArray) -- quick instanceof check
			expect(prepended).never.to.equal(defaultMiddleware)
			expect(deepEquals(defaultMiddleware, originalDefaultMiddleware)).to.equal(true)
		end)

		it("allows to concat a single value", function()
			local concatenated = defaultMiddleware:concat(middleware1)

			expect(deepEquals(concatenated, { unpack(defaultMiddleware), middleware1 })).to.equal(true)
			expect(concatenated.__index).to.equal(Redux.MiddlewareArray) -- quick instanceof check
			expect(concatenated).never.to.equal(defaultMiddleware)
			expect(deepEquals(defaultMiddleware, originalDefaultMiddleware)).to.equal(true)
		end)

		it("allows to concat multiple values (array as first argument)", function()
			local concatenated = defaultMiddleware:concat({ middleware1, middleware2 })

			expect(deepEquals(concatenated, { unpack(defaultMiddleware), middleware1, middleware2 })).to.equal(true)
			expect(concatenated.__index).to.equal(Redux.MiddlewareArray) -- quick instanceof check
			expect(concatenated).never.to.equal(defaultMiddleware)
			expect(deepEquals(defaultMiddleware, originalDefaultMiddleware)).to.equal(true)
		end)

		it("allows to concat multiple values (rest)", function()
			local concatenated = defaultMiddleware:concat(middleware1, middleware2)

			expect(deepEquals(concatenated, { unpack(defaultMiddleware), middleware1, middleware2 })).to.equal(true)
			expect(concatenated.__index).to.equal(Redux.MiddlewareArray) -- quick instanceof check
			expect(concatenated).never.to.equal(defaultMiddleware)
			expect(deepEquals(defaultMiddleware, originalDefaultMiddleware)).to.equal(true)
		end)

		it("allows to concat and then prepend", function()
			local concatenated = defaultMiddleware:concat(middleware1):prepend(middleware2)

			expect(deepEquals(concatenated, {
				middleware2,
				unpack(defaultMiddleware),
				middleware1,
			})).to.equal(true)
		end)

		it("allows to prepend and then concat", function()
			local concatenated = defaultMiddleware:prepend(middleware2):concat(middleware1)

			expect(deepEquals(concatenated, {
				middleware2,
				unpack(defaultMiddleware),
				middleware1,
			})).to.equal(true)
		end)
	end)
end
