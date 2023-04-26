local Immer = require(script.Parent.Parent.Parent.Immer)

local function freezeDraftable<T>(val: T)
	return if Immer.isDraftable(val) then Immer.produce(val, function() end) else val
end

return freezeDraftable
