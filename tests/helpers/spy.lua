local deepEquals = require(script.Parent.deepEquals)

local function spy(fn)
	fn = fn or function() end

	local calls = {}

	local function spyFn(...)
		table.insert(calls, { ... })
		return fn(...)
	end

	return {
		hasBeenCalled = function()
			return #calls ~= 0
		end,

		wasNthExactlyCalled = function(n: number)
			return n == #calls
		end,

		wasCalledWith = function(...)
			for _, args in calls do
				if #args == select("#", ...) then
					return true
				end
			end
			return false
		end,

		wasNthCalledWith = function(n: number, ...: any)
			local args = table.pack(...)
			if not calls[n] then
				return false
			end

			if args.n ~= #calls[n] then
				return false
			end

			for i = 1, args.n do
				local left = args[i]
				local right = calls[n][i]

				if typeof(left) == "table" and typeof(right) == "table" then
					if not deepEquals(left, right) then
						return false
					end
				elseif left ~= right then
					return false
				end
			end

			return true
		end,

		calls = calls,
		fn = spyFn,
	}
end

return spy
