local ReplicatedStorage = game:GetService("ReplicatedStorage")
local compose = require(ReplicatedStorage.Redux).compose

return function()
	describe("Utils", function()
		describe("compose", function()
			it("composes from right to left", function()
				local double = function(x: number)
					return x * 2
				end

				local square = function(x: number)
					return x * x
				end

				expect(compose(square)(5)).to.equal(25)
				expect(compose(square, double)(5)).to.equal(100)
				expect(compose(double, square, double)(5)).to.equal(200)
			end)

			it("composes functions from right to left", function()
				local a = function(next: (x: string) -> string)
					return function(x: string)
						return next(x .. "a")
					end
				end

				local b = function(next: (x: string) -> string)
					return function(x: string)
						return next(x .. "b")
					end
				end

				local c = function(next: (x: string) -> string)
					return function(x: string)
						return next(x .. "c")
					end
				end

				local final = function(x: string)
					return x
				end

				expect(compose(a, b, c)(final)("")).to.equal("abc")
				expect(compose(b, c, a)(final)("")).to.equal("bca")
				expect(compose(c, a, b)(final)("")).to.equal("cab")
			end)

			it("throws at runtime if argument is not a function", function()
				local square = function(x: number, _y: number)
					return x * x
				end

				local add = function(x: number, y: number)
					return x + y
				end

				expect(function()
					compose(square, add, false)(1, 2)
				end).to.throw()

				expect(function()
					compose(square, add, true)(1, 2)
				end).to.throw()

				expect(function()
					compose(square, add, "")(1, 2)
				end).to.throw()

				expect(function()
					compose(square, add, {})(1, 2)
				end).to.throw()
			end)

			it("can be seeded with multiple arguments", function()
				local square = function(x: number, _y: number)
					return x * x
				end

				local add = function(x: number, y: number)
					return x + y
				end

				expect(compose(square, add)(1, 2)).to.equal(9)
			end)

			it("returns the first argument given if given no functions", function()
				expect(compose()(1, 2)).to.equal(1)
				expect(compose()(3)).to.equal(3)
				expect(compose()(nil)).to.equal(nil)
			end)

			it("returns the first function given if given only one", function()
				local fn = function() end
				expect(compose(fn)).to.equal(fn)
			end)
		end)
	end)
end
