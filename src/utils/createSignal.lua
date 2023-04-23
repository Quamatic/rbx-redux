local function createSignal()
	local connections = {}
	local suspendedConnections = {}
	local firing = false

	local function subscribe(callback)
		assert(typeof(callback) == "function", "Can only subscribe to signals with a function.")

		local connection = {
			callback = callback,
			disconnected = false,
		}

		if firing and not connections[callback] then
			suspendedConnections[callback] = connection
		end

		connections[callback] = connection

		local function disconnect()
			assert(not connection.disconnected, "Listeners can only be disconnected once.")

			connection.disconnected = true
			connections[callback] = nil
			suspendedConnections[callback] = nil
		end

		return disconnect
	end

	local function fire(...)
		firing = true
		for callback, connection in connections do
			if not connection.disconnected and not suspendedConnections[callback] then
				callback(...)
			end
		end

		firing = false
		table.clear(suspendedConnections)
	end

	local function clear()
		table.clear(connections)
		table.clear(suspendedConnections)
	end

	return {
		subscribe = subscribe,
		fire = fire,
		clear = clear,
	}
end

return createSignal
