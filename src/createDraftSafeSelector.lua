local Immer = require(script.Parent.Parent.Immer)
local createSelector = require(script.Parent.createSelector)

local function createDraftSafeSelector(...)
	local selector = createSelector(...)
	local wrappedSelector = function(value, ...)
		return selector(if Immer.isDraft(value) then Immer.current(value) else value, ...)
	end

	return wrappedSelector
end

return createDraftSafeSelector
