local actions = require(script.Parent.types.actions)
local merge = require(script.Parent.merge)

export type PreparedAction<P, Args...> =
	((Args...) -> { payload: P })
	| ((Args...) -> { payload: P, meta: any })
	| ((Args...) -> { payload: P, error: any })
	| ((Args...) -> { payload: P, meta: any, error: any })

-- impossible to implement
type IfPrepareActionMethodProvided<PA = PreparedAction<any>, True = any, False = any> = True | False
type _ActionCreatorWithPreparedPayload<PA = PreparedAction<any>, T = any> = {}

type BaseActionCreator<P, T = string, M = any, E = any> = {
	type: T,
	-- Luau does not have type predicates, so this only returns a boolean.
	-- Original source: action is PayloadAction<P, T, M, E>
	match: (action: actions.Action<any>) -> boolean,
}

type ActionCreatorWithPayload<P, T = string> =
	BaseActionCreator<P, T, any, any>
	& ((payload: P?) -> PayloadAction<P, T, any, any>)

type IsAny<Args...> = true | false

type PayloadAction<P = nil, T = string, M = any, N = any> = {
	payload: P,
	type: T,
} & ({
	meta: M,
} | {
	error: N,
})

-- This method probably does nothing, it maps as close as it can to Redux's Typescript source.
type PayloadActionCreator<P = any, T = string, PA = PreparedAction<P> | nil> = IfPrepareActionMethodProvided<
	PA,
	_ActionCreatorWithPreparedPayload<PA, T>,
	IsAny<P, ActionCreatorWithPayload<any, T>>
>

type CreateActionFn =
	(<P, T>(type: T) -> PayloadActionCreator<P, T, nil>)
	| (<PA, T>(type: T, prepareAction: PA) -> PayloadActionCreator<any, T, PA>)

local ACTION = newproxy(true)

--[[
	Creates an object that can be used to easily define a Redux action type & creator

	```lua
	local increment = createAction("increment")

	local action = increment()
	-- { type: "increment "}

	action = increment(3)
	-- { type: "increment", payload: 3 }

	print(tostring(action))
	-- "increment"

	print(`The action type is {action}`)
	-- "The action type is increment"
	```
]]
--
local function createAction<Args...>(type: string, prepareAction: PreparedAction<Args...>)
	return setmetatable({
		type = type,
		[ACTION] = true,

		match = function(other)
			return type == other.type
		end,
	}, {
		__call = function(_self: any, ...: Args...)
			local args = { ... }

			if prepareAction then
				local prepared = prepareAction(...)
				if prepared == nil then
					error("prepareAction did not return an object")
				end

				return merge({
					type = type,
					payload = prepared.payload,
					prepared.meta and { meta = prepared.meta },
					prepared.err and { error = prepared.error },
				})
			end

			return { type = type, payload = args[1] }
		end,

		__tostring = function()
			return type
		end,
	})
end

local function isAction(action: any): boolean
	if type(action) ~= "table" then
		return false
	end

	return action.type ~= nil and action[ACTION] ~= nil
end

return {
	createAction = createAction :: CreateActionFn,
	isAction = isAction,
}
