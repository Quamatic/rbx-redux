local compose = require(script.Parent.compose)

export type DevtoolsEnhancerOptions = {
	name: string?,
	actionCreators: any?,
	latency: number?,
	maxAge: number?,

	actionSanitizer: <A>(action: A, id: number) -> A?,
	stateSanitizer: <S>(state: S, index: number) -> S?,
	actionsBlacklist: string | { string }?,
	actionsDenylist: string | { string }?,
	actionsAllowlist: string | { string }?,
	predicate: <S, A>(state: S, action: A) -> boolean?,

	shouldRecordChanges: boolean?,
	pauseActionType: string?,
	autoPause: boolean?,
	shouldStartLocked: boolean?,
	shouldHotReload: boolean?,
	shouldCatchErrors: boolean?,

	features: {
		pause: boolean?,
		lock: boolean?,
		persist: boolean?,
		export: boolean | "custom"?,
		import: boolean | "custom"?,
		jump: boolean?,
		skip: boolean?,
		reorder: boolean?,
		dispatch: boolean?,
		test: boolean?,
	}?,

	trace: boolean | ((action: any) -> string)?,
	traceLimit: number?,
}

type Compose = typeof(compose)
type ComposeWithDevTools = ((options: DevtoolsEnhancerOptions) -> Compose) | (<StoreExt>(...any) -> any)

-- This works completely different than Redux, since we're not in a web environment.
-- Redux does a check on the window to see if the Devtools Extension is installed.
-- However, we cannot do that. We need to directly implement it.

-- !UNFINISHED
local composeWithDevTools: ComposeWithDevTools = function(...)
	local args = { ... }

	if #args == 0 then
		return nil
	end

	if typeof(args[1]) == "table" then
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
