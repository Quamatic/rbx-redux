local deepEquals = require(script.Parent.deepEquals)

local function spy(fn)
	fn = fn or function() end

	local calls = {}
	local nextReturnValue = nil

	local function spyFn(...)
		table.insert(calls, { ... })

		if nextReturnValue ~= nil then
			fn(...)

			local value = nextReturnValue
			nextReturnValue = nil

			return value
		end

		return fn(...)
	end

	return {
		hasBeenCalled = function()
			return #calls ~= 0
		end,

		wasNthExactlyCalled = function(n: number)
			return n == #calls
		end,

		clear = function()
			nextReturnValue = nil
			table.clear(calls)
		end,

		wasCalledWith = function(...)
			for _, args in calls do
				if #args == select("#", ...) then
					return true
				end
			end
			return false
		end,

		wasLastCalledWith = function(...)
			local last = calls[#calls]
			if last == nil then
				print("Super sussy tbh")
				return false
			end

			local length = select("#", ...)
			if #last ~= length then
				return false
			end

			for i = 1, length do
				local arg = select(i, ...)
				local value = last[i]

				local same = false
				if typeof(value) == "table" and typeof(arg) == "table" then
					same = deepEquals(value, arg)
				else
					same = arg == value
				end

				if not same then
					return false
				end
			end

			return true
		end,

		setReturnValueOnce = function(value: any)
			nextReturnValue = value
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
