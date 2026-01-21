local task = require("@lune/task")

export type Listener<T...> = (T...) -> ()
export type ErrorHandler = (err: Error) -> ()
export type Error = {
	message: any,
	traceback: string,
	event: any,
	listener: any,
}

local function DEFAULT_ERR_HANDLER(err: Error)
	print(`unhandled event error: {err.message}`)
end

export type Event<T...> = setmetatable<{
    _listeners: {Listener<T...>},
	_error_handler: (err: any) -> (),
}, {
	__index: getmetatable<Event<T...>>,
	new: (on_error: ErrorHandler?) -> Event<T...>,
	_fire: (self: Event<T...>, T...) -> (),
	connect: (self: Event<T...>, listener: Listener<T...>) -> () -> (),
	connect_once: (self: Event<T...>, listener: Listener<T...>) -> () -> (),
	wait: (self: Event<T...>) -> T...,
}>

local Event = {}
Event.__index = Event

function Event.new(on_error: ErrorHandler?)
	local sig: Event<...any> = setmetatable({ _listeners = {}, _error_handler = nil :: any }, Event)

	sig._error_handler = function(err: any)
		local handler: ErrorHandler = on_error or DEFAULT_ERR_HANDLER
		local traceback = debug.traceback(nil, 2)
		local listener = debug.info(3, "f")
		local ok, err = pcall(handler, {
			message = err:gsub("^.-:%d+: ", ""),
			traceback = traceback,
			listener = listener,
			event = sig,
		})

		if not ok then
			print(`!!! error handler {on_error} failed: {err}`)
		end
	end

    return sig
end

function Event._fire(self: any, ...)
	local self: Event<...any> = self
	for _, callback in self._listeners do
		task.spawn(xpcall, callback, self._error_handler, ...)
	end
end

function Event.connect(self: any, callback: Listener<...unknown>): () -> ()
	local self: Event<...any> = self
	table.insert(self._listeners, callback)
	return function()  
		table.remove(self._listeners, table.find(self._listeners, callback) or error("failed to disconnect"))
	end
end

function Event.connect_once(self: any, callback: Listener<...unknown>): () -> ()
	local self: Event<...any> = self
	local disconnect: () -> (); disconnect = self:connect(function(...)
		callback(...)
		disconnect()
	end)
	return disconnect
end

function Event.wait(self: any): ...any
	local self: Event<...any> = self
	local values: {any}?
	self:connect_once(function(...)
		values = { ... }
	end)
	
	while not values do
		task.wait()
	end

	local values = values :: {any}
	return unpack(values)
end

return Event
