local HttpService = game:GetService("HttpService")

local function randomString()
	return string.sub(HttpService:GenerateGUID(false), 7)
end

local ActionTypes = {
	INIT = `@@redux/INIT{randomString()}`,
	REPLACE = `@@redux/REPLACE{randomString()}`,
	PROBE_UNKNOWN_ACTION = function()
		return `@@redux/PROBE_UNKNOWN_ACTION{randomString()}`
	end,
}

return ActionTypes
