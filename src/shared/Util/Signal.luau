--!strict
-- Minimal event object: connect handlers, fire values to all of them.

export type Connection = {
	Disconnect: (self: Connection) -> (),
}

export type Signal<T> = {
	Connect: (self: Signal<T>, handler: (T) -> ()) -> Connection,
	Fire: (self: Signal<T>, value: T) -> (),
}

local Signal = {}

function Signal.new<T>(): Signal<T>
	local handlers: { [number]: (T) -> () } = {}
	local nextId = 0

	local signal = {}

	function signal.Connect(_self: Signal<T>, handler: (T) -> ()): Connection
		nextId += 1
		local id = nextId
		handlers[id] = handler
		local connection = {}
		function connection.Disconnect(_conn: Connection)
			handlers[id] = nil
		end
		return connection :: Connection
	end

	function signal.Fire(_self: Signal<T>, value: T)
		for _, handler in handlers do
			task.spawn(handler, value)
		end
	end

	return signal :: Signal<T>
end

return Signal
