local function spy(fn)
	fn = fn or function() end

	local calls = {}

	local function spyFn(...)
		table.insert(calls, { ... })
		return fn(...)
	end

	return {
		wasCalledWith = function(...)
			for _, args in calls do
				if #args == select("#", ...) then
					return true
				end
			end
			return false
		end,

		calls = calls,
		fn = spyFn,
	}
end

return spy
