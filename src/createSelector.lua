local defaultMemoize = require(script.Parent.utils.defaultMemoize)

export type CreateSelectorOptions<MemoizeOptions> = {
	memoizeOptions: MemoizeOptions,
}

local function getDependencies(funcs: { any })
	local dependencies = if typeof(funcs[1]) == "table" then funcs[1] else funcs
	local isEveryDependencyAFunction = true

	for _, dependency in dependencies do
		if typeof(dependency) ~= "function" then
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
			`createSelector expects all input-selectors to be functions, but received the following types: [{table.concat(
				dependencyTypes,
				", "
			)}]`,
			2
		)
	end

	return dependencies
end

local function createSelectorCreator<MemoizeOptions>(memoize)
	local createSelector = function(_, ...)
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

		local memoizeOptions = directlyPassedOptions.memoizeOptions
		local finalMemoizeOptions = if typeof(memoizeOptions) == "table"
			then memoizeOptions
			else { memoizeOptions } :: MemoizeOptions

		local dependencies = getDependencies(funcs)
		local memoizedFuncResult = memoize(function()
			recomputations += 1
			return resultFunc
		end, unpack(finalMemoizeOptions))

		local selector = memoize(function()
			local params = table.create(#dependencies)

			for _, dependency in dependencies do
				table.insert(params, dependency(unpack(funcs)))
			end

			lastResult = memoizedFuncResult(params)
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
			end,
		}, {
			__call = selector,
		})
	end

	return createSelector
end

return {
	createSelectorCreator,
	createSelector = createSelectorCreator(defaultMemoize),
}
