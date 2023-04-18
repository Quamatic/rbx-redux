local compose = require(script.Parent.compose)

export type DevtoolsEnhancerOptions = {
	name: string?,
	actionCreators: any?,
	latency: number?,
	maxAge: number?,
	trace: boolean?,
}

type Compose = typeof(compose)
type ComposeWithDevtools = ((options: DevtoolsEnhancerOptions) -> Compose) | (<StoreExt>(...any) -> any)

-- This works completely different than Redux, since we're not in a web environment.
-- Redux does a check on the window to see if the Devtools Extension is installed.
-- However, we cannot do that. We need to directly implement it.

-- !UNFINISHED
local composeWithDevTools: ComposeWithDevtools = function(...)
	local args = table.pack(...)

	if args.n == 0 then
		return nil
	end

	if typeof(args[0]) == "table" then
		return compose
	end

	return compose(... :: any)
end

-- !UNFINISHED
local devToolsEnhancer = function(_options: DevtoolsEnhancerOptions)
	return function(noop)
		return noop
	end
end

return {
	composeWithDevTools = composeWithDevTools,
	devToolsEnhancer = devToolsEnhancer,
}
