local defaultMemoize = require(script.Parent.utils.defaultMemoize)
local isArray = require(script.Parent.utils.isArray)
local reduce = require(script.Parent.utils.reduce)

-- This is to allow for chaining selectors, since the selector created isnt a function but a table with a __call metamethod
local SELECTOR_MARKER = {}

export type CreateSelectorOptions<MemoizeOptions> = {
	memoizeOptions: MemoizeOptions,
}

local function isSelector(x: any)
	if typeof(x) ~= "table" then
		return false
	end

	local mt = getmetatable(x)
	if mt == nil then
		return false
	end

	return mt[SELECTOR_MARKER] ~= nil
end

local function getDependencies(funcs: { any })
	local dependencies = if isArray(funcs[1]) then funcs[1] else funcs
	local isEveryDependencyAFunction = true

	for _, dependency in dependencies do
		if typeof(dependency) ~= "function" then
			-- Pass selector-marked tables
			if isSelector(dependency) then
				continue
			end

			isEveryDependencyAFunction = false
			break
		end
	end

	if not isEveryDependencyAFunction then
		local dependencyTypes: { string } = {}

		for _, dependency in dependencies do
			local format = if typeof(dependency) == "function"
				then `function ${dependency.name or "unnamed"}`
				else typeof(dependency)

			table.insert(dependencyTypes, format)
		end

		error(
			`createSelector expects all input-selectors to be functions OR other selectors, but received the following types: [{table.concat(
				dependencyTypes,
				", "
			)}]`
		)
	end

	return dependencies
end

local function createSelectorCreator<MemoizeOptions>(memoize, ...)
	local memoizeOptionsFromArgs = { ... }

	local createSelector = function(...)
		local funcs = { ... }

		local recomputations = 0
		local lastResult

		local directlyPassedOptions: CreateSelectorOptions<MemoizeOptions> = {
			memoizeOptions = nil,
		}

		local resultFunc = table.remove(funcs)

		if typeof(resultFunc) == "table" then
			directlyPassedOptions = resultFunc :: any
			resultFunc = table.remove(funcs)
		end

		if typeof(resultFunc) ~= "function" then
			error(`createSelector expects an output function after the inputs, but received: [{typeof(resultFunc)}]`)
		end

		-- TODO: Optimize?

		local memoizeOptions = directlyPassedOptions.memoizeOptions or memoizeOptionsFromArgs
		local finalMemoizeOptions = if isArray(memoizeOptions)
			then memoizeOptions
			else { memoizeOptions } :: MemoizeOptions

		local dependencies = getDependencies(funcs)

		local memoizedFuncResult = memoize(function(...) -- recomputationWrapper
			recomputations += 1
			return resultFunc(...)
		end, unpack(finalMemoizeOptions))

		local selector = memoize(function(...)
			local params = table.create(#dependencies)

			for index, dependency in dependencies do
				params[index] = dependency(...)
			end

			lastResult = memoizedFuncResult(unpack(params))
			return lastResult
		end)

		return setmetatable({
			resultFunc = resultFunc,
			memoizedFuncResult = memoizedFuncResult,
			dependencies = dependencies,
			lastResult = function()
				return lastResult
			end,
			recomputations = function()
				return recomputations
			end,
			resetRecomputations = function()
				recomputations = 0
				return recomputations
			end,
		}, {
			__call = function(_, ...)
				return selector(...)
			end,
			[SELECTOR_MARKER] = true,
		})
	end

	return createSelector
end

local createSelector = createSelectorCreator(defaultMemoize)

local function createStructureSelector(selectors: {}, selectorCreator)
	selectorCreator = selectorCreator or createSelector

	if typeof(selectors) ~= "table" then
		error(
			`createStructuredSelector expects first argument to be an object, where each property is a selector, instead received a {typeof(
				selectors
			)}`
		)
	end

	local keys = {}
	for key in selectors do
		table.insert(keys, key)
	end

	local selectors_ = {}
	for index, key in keys do
		selectors_[index] = selectors[key]
	end

	local resultSelector = selectorCreator(selectors_, function(...)
		return reduce({ ... }, function(composition, value, index)
			composition[keys[index]] = value
			return composition
		end, {})
	end)

	return resultSelector
end

return {
	createSelectorCreator = createSelectorCreator,
	createStructureSelector = createStructureSelector,
	createSelector = createSelector,
}
