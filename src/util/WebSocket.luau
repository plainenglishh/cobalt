local net = require("@lune/net")
local task = require("@lune/task")

export type WebSocketStatus = "open" | "closed"

--[=[
    Polling-based WebSocket.
]=]
export type WebSocket = setmetatable<{
	_socket: net.WebSocket?,
	_queue: { string },
}, {
	__index: getmetatable<WebSocket>,

	--[=[
        Creates a new `WebSocket`.

        Will connect to the given url.
    ]=]
	new: (url: string) -> WebSocket,
	status: (self: WebSocket) -> WebSocketStatus,

	--[=[
        Returns the next message, if available.

        Doesn't yield or block.
    ]=]
	try_next: (self: WebSocket) -> string?,
	send: (self: WebSocket, data: buffer | string) -> (),
	close: (self: WebSocket, code: number?) -> (),
}>

local WebSocket = {}
WebSocket.__index = WebSocket

function WebSocket.new(url: string): WebSocket
	local self: WebSocket = setmetatable({
		_socket = nil :: net.WebSocket?,
		_queue = {},
	}, WebSocket)

	task.spawn(function()
		local socket = net.socket(url)
		self._socket = socket

		while task.wait() do
			local message = socket:next()
			if not message then
				break
			end

			table.insert(self._queue, message)
		end
	end)

	return self
end

function WebSocket.status(self: WebSocket): WebSocketStatus
	if (not self._socket) or self._socket.closeCode then
		return "closed"
	else
		return "open"
	end
end

function WebSocket.try_next(self: WebSocket): string?
	if self:status() ~= "open" then
		error("not open")
	end

	return table.remove(self._queue, 1)
end

function WebSocket.send(self: WebSocket, data: buffer | string)
	if not self._socket then
		error(`not connected`)
	end

	self._socket:send(data, false)
end

function WebSocket.close(self: WebSocket, code: number?)
	if not self._socket then
		error(`not connected`)
	end

	self._socket:close()
end

return WebSocket
