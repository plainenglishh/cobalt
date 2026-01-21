local task = require("@lune/task")
type Callback<T...> = (T...) -> ()

export type Event<T...> = setmetatable<{
    _callbacks: {Callback<T...>}
}, {
	__index: getmetatable<Event<T...>>,
	new: () -> Event<T...>,
	_fire: (self: Event<T...>, T...) -> (),
	connect: (self: Event<T...>, callback: Callback<T...>) -> () -> (),
	connect_once: (self: Event<T...>, callback: Callback<T...>) -> () -> (),
	wait: (self: Event<T...>) -> T...,
}>

local Event = {}
Event.__index = Event

function Event.new()
	local callbacks = {}
	local sig: Event<...any> = setmetatable({ _callbacks = callbacks }, Event)
    return sig
end

function Event._fire(self: any, ...)
	for _, callback in self._callbacks do
		task.spawn(callback, ...)
	end
end

function Event.connect(self: any, callback: Callback<...unknown>): () -> ()
	table.insert(self._callbacks, callback)
	return function()  
		table.remove(self._callbacks, table.find(self._callbacks, callback) or error("failed to disconnect"))
	end
end

function Event.connect_once(self: any, callback: Callback<...unknown>): () -> ()
	local disconnect; disconnect = self:connect(function(...)
		callback(...)
		disconnect()
	end)
	return disconnect
end

function Event.wait(self: any): ...any
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
