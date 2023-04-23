local splice = require(script.Parent.splice)

local NOT_FOUND = newproxy(true)
type NOT_FOUND_TYPE = typeof(NOT_FOUND)

type Entry = {
	key: any,
	value: any,
}

type Cache = {
	get: (key: any) -> any | NOT_FOUND_TYPE,
	put: (key: any, value: any) -> nil,
	getEntries: () -> { Entry },
	clear: () -> nil,
}

type EqualityFn = (a: any, b: any) -> boolean

local function createSingletonCache(equals: EqualityFn): Cache
	local entry

	return {
		get = function(key)
			if entry and equals(entry.key, key) then
				return entry.value
			end

			return NOT_FOUND
		end,

		put = function(key, value)
			entry = {
				key = key,
				value = value,
			}
		end,

		getEntries = function()
			return if entry then { entry } else {}
		end,

		clear = function()
			entry = nil
		end,
	}
end

local function createLruCache(maxSize: number, equals): Cache
	local entries = {}

	local function get(key)
		local cacheIndex = -1

		for index, entry in entries do
			if equals(entry.key, key) then
				cacheIndex = index
				break
			end
		end

		if cacheIndex > -1 then
			local entry = entries[cacheIndex]

			if cacheIndex > 1 then
				splice(entries, cacheIndex, 1)
				table.insert(entries, 1, entry)
			end

			return entry.value
		end

		return NOT_FOUND
	end

	local function put(key, value)
		if get(key) == NOT_FOUND then
			table.insert(entries, 1, { key = key, value = value })

			local len = #entries
			if len > maxSize then
				table.remove(entries)
			end
		end
	end

	local function getEntries()
		return entries
	end

	local function clear()
		table.clear(entries)
	end

	return {
		get = get,
		put = put,
		getEntries = getEntries,
		clear = clear,
	}
end

local defaultEqualityCheck: EqualityFn = function(a, b)
	return a == b
end

local function createCacheKeyComparator(equalityCheck: any)
	local function areArgumentsShallowlyEqual(prev, next)
		if prev == nil or next == nil or #prev ~= #next then
			return false
		end

		for index, value in prev do
			if not equalityCheck(value, next[index]) then
				return false
			end
		end

		return true
	end

	return areArgumentsShallowlyEqual
end

export type DefaultMemoizeOptions = {
	equalityCheck: any?,
	resultEqualityCheck: any?,
	maxSize: number?,
}

local function defaultMemoize<Args...>(func: (Args...) -> any, equalityCheckOrOptions: EqualityFn | DefaultMemoizeOptions?)
	local providedOptions = if typeof(equalityCheckOrOptions) == "table"
		then equalityCheckOrOptions
		else { equalityCheck = equalityCheckOrOptions }

	local equalityCheck = providedOptions.equalityCheck or defaultEqualityCheck
	local maxSize = providedOptions.maxSize or 1
	local resultEqualityCheck = providedOptions.resultEqualityCheck

	local comparator = createCacheKeyComparator(equalityCheck)
	local cache = if maxSize == 1 then createSingletonCache(comparator) else createLruCache(maxSize, comparator)

	local function memoized(...: Args...)
		local arguments = { ... }
		local value = cache.get(arguments)

		if value == NOT_FOUND then
			value = func(...)

			if resultEqualityCheck then
				local entries = cache.getEntries()
				local matchingEntry: Entry?

				for _, entry in entries do
					if resultEqualityCheck(entry.value, value) then
						matchingEntry = entry
						break
					end
				end

				if matchingEntry then
					value = matchingEntry.value
				end
			end

			cache.put(arguments, value)
		end

		return value
	end

	return memoized :: (Args...) -> any
end

return defaultMemoize
