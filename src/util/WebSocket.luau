local net = require("@lune/net")
local task = require("@lune/task")

export type WebSocketStatus = "connecting" | "open" | "closed" | "errored"

--[=[
    Polling-based WebSocket.
]=]
export type WebSocket = setmetatable<{
	_status: WebSocketStatus,
	_error: any?,
	_queue: { string },
	_socket: net.WebSocket?,
	_thread: thread,
}, {
	__index: getmetatable<WebSocket>,

	_poll: (self: WebSocket) -> (),
	_assert_open: (self: WebSocket, message: string?, level: number?) -> (),

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
	local self: WebSocket
	self = setmetatable({
		_status = "connecting",
		_error = nil,
		_queue = {},
		_socket = nil :: net.WebSocket?,
		_thread = coroutine.create(function()
			if self._status == "closed" then
				return
			end

			local socket = net.socket(url)

			if self._status == "closed" then
				return
			end

			self._socket = socket
			self._status = "open"

			while true do
				if self._status == "closed" then
					return
				end

				local ok, msg_or_err = pcall(socket.next, socket)
				if not ok then
					self._status = "errored"
					self._error = msg_or_err
					return
				end

				if not msg_or_err then
					self._status = "closed"
				end

				table.insert(self._queue, msg_or_err)
			end
		end),
	}, WebSocket)
	self:_poll()
	return self
end

function WebSocket._poll(self: WebSocket)
	local thread = self._thread
	if coroutine.status(thread) == "dead" then
		if self._status ~= "errored" then
			self._status = "closed"
		end

		return
	end

	local ok, err = coroutine.resume(thread)
	if not ok then
		self._status = "errored"
		self._error = err
	end
end

function WebSocket._assert_open(self: WebSocket, message: string?, level: number?)
	if self._status ~= "open" then
		error(message or "WebSocket:_assert_open failed", (level or 1) + 1)
	end
end

function WebSocket.status(self: WebSocket): WebSocketStatus
	return self._status
end

function WebSocket.try_next(self: WebSocket): string?
	self:_assert_open("attempt to call WebSocket:try_next() on non-open WebSocket", 2)
	return table.remove(self._queue, 1)
end

function WebSocket.send(self: WebSocket, data: buffer | string)
	self:_assert_open("attempt to call WebSocket:send() on non-open WebSocket", 2)

	self:_poll()
	assert(self._socket)

	self._socket:send(data, false)
end

function WebSocket.close(self: WebSocket, code: number?)
	if self._status == "closed" then
		error(`attempt to call WebSocket:close() on a closed WebSocket.`, 2)
	end

	self._status = "closed"
	if self._socket then
		self._socket:close(code)
	end
end

return WebSocket
