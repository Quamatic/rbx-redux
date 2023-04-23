local matches = function(matcher, action)
	if typeof(matcher) == "function" then
		return matcher(action)
	else
		return matcher.match(action)
	end
end

local function isAnyOf(...: {})
	local matchers = { ... }

	return function(action): boolean
		for _, matcher in matchers do
			if matches(matcher, action) then
				return true
			end
		end

		return false
	end
end

local function isAllOf(...)
	local matchers = { ... }

	return function(action): boolean
		for _, matcher in matchers do
			if not matches(matcher, action) then
				return false
			end
		end

		return true
	end
end

local function hasExpectedRequestedMetadata(action: any, validStatus: { string })
	if typeof(action) ~= "table" or not action.meta then
		return false
	end

	local hasValidRequestId = typeof(action.meta.requestId) == "string"
	local hasValidRequestStatus = table.find(validStatus, action.meta.requestStatus) ~= nil

	return hasValidRequestId and hasValidRequestStatus
end

local function isAsyncThunkArray(a: { any })
	return typeof(a[1]) == "table" and a[1].pending ~= nil and a[1].fulfilled ~= nil and a[1].rejected ~= nil
end

local isPending, isRejected, isFulfilled, isAsyncThunkAction
do
	local function createAsyncThunkMatcher(statuses: { string })
		local function isCurrentStatus(...)
			-- Pack it as we need the length
			local asyncThunks = { ... }
			local length = select("#", ...)

			if length == 0 then
				return function(action: any)
					return hasExpectedRequestedMetadata(action, statuses)
				end
			end

			if not isAsyncThunkArray(asyncThunks) then
				return isCurrentStatus()(asyncThunks[1])
			end

			return function(action: any)
				local matchers = table.create(length)

				for _, asyncThunk in asyncThunks do
					for _, status in statuses do
						table.insert(matchers, asyncThunk[status])
					end
				end

				local combinedMatcher = isAnyOf(unpack(matchers))

				return combinedMatcher(action)
			end
		end

		return isCurrentStatus
	end

	isPending = createAsyncThunkMatcher({ "pending" })
	isRejected = createAsyncThunkMatcher({ "rejected" })
	isFulfilled = createAsyncThunkMatcher({ "fulfilled" })
	isAsyncThunkAction = createAsyncThunkMatcher({ "pending", "rejected", "fulfilled" })
end

local function isRejectedWithValue(...)
	local thunks = { ... }

	local hasFlag = function(action)
		return action and action.meta and action.meta.rejectedWithValue
	end

	if select("#", ...) == 0 then
		return function(action)
			local combinedMatcher = isAllOf(isRejected(unpack(thunks)), hasFlag)
			return combinedMatcher(action)
		end
	end

	if not isAsyncThunkArray(thunks) then
		return isRejectedWithValue()(thunks[1])
	end

	return function(action)
		local combinedMatcher = isAllOf(isRejected(unpack(thunks)), hasFlag)
		return combinedMatcher(action)
	end
end

return {
	isAnyOf = isAnyOf,
	isAllOf = isAllOf,
	hasExpectedRequestedMetadata = hasExpectedRequestedMetadata,
	isAsyncThunkArray = isAsyncThunkArray,
	isPending = isPending,
	isRejected = isRejected,
	isFulfilled = isFulfilled,
	isRejectedWithValue = isRejectedWithValue,
	isAsyncThunkAction = isAsyncThunkAction,
}
