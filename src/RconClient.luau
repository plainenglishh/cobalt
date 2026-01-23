local Event = require("./util/Event")
local socket_address = require("./util/socket_address")
local json = require("./dependencies/json")
local sys = require("./sys")

local DEFAULT_RCON_PORT = 28016
local DEFAULT_REQUEST_TIMEOUT = 5

local RESERVED_IDENTIFIER = 0
local MAX_IDENTIFIER = 9_999_999

export type Callback = (message: ServerMessage) -> ()

export type ClientMessage = {
	message: string,
	identifier: number,
	stacktrace: string?,
}

export type ServerMessage = {
	message: string,
	identifier: number,
	type: string,
	stacktrace: string,
}

export type QueuedMessage = {
	callback: Callback?,
	message: ClientMessage,
}

export type RconClientOptions = {
	--- An optional name to encode with Rcon messages.
	name: string?,
}

export type RconClientStatus = "waiting" | "active" | "dead"

--[=[
    Class used to interact with a Rust RCON server.

    ### Lifecycle
]=]
export type RconClient = setmetatable<
	{
		read name: string,

		--[=[
            Fires when a connection is established.
        ]=]
		read connected: Event.Event<>,

		--[=[
            Fires when a message is received. Passed the `ServerMessage`, and a
            boolean indicating whether the message was a request response.
        ]=]
		read message_received: Event.Event<ServerMessage, boolean>,

		--[=[
            Fires when a message is sent. Passed the `ClientMessage`, and a 
            boolean indicating whether the message was a request.
        ]=]
		read message_sent: Event.Event<ClientMessage, boolean>,

		--[=[
            Fires when a connection is closed.
        ]=]
		read disconnected: Event.Event<>,

		--- Map of expectant requests.
		read _active_requests: { [number]: QueuedMessage },
		read _queue: { QueuedMessage },
		_status: RconClientStatus,
	},
	{
		__index: getmetatable<RconClient>,
		new: (options: RconClientOptions?) -> RconClient,
		status: (self: RconClient) -> RconClientStatus,
		_queue_message: (self: RconClient, message: ClientMessage, callback: Callback?) -> (),
		_find_free_request_id: (self: RconClient) -> number,

		--[=[
            Sends a message without expecting a response.

            Sent using identifier 0.
        ]=]
		execute: (self: RconClient, message: string) -> (),
		request_async: (self: RconClient, message: string, timeout: number?, identifier: number?) -> string,
		connect: (self: RconClient, host: string, password: string, tls: boolean?) -> (),
		disconnect: (self: RconClient) -> (),
	}
>

local RconClient = {}
RconClient.__index = RconClient

function RconClient.new(options: RconClientOptions?): RconClient
	local options: RconClientOptions = options or {}

	local self: RconClient = setmetatable({
		name = options.name or "RconClient",

		connected = Event.new(),
		message_received = Event.new(),
		message_sent = Event.new(),
		disconnected = Event.new(),

		_active_requests = {},
		_queue = {},
		_status = "waiting",
	}, RconClient)

	return self
end

function RconClient.status(self: RconClient): RconClientStatus
	return self._status
end

function RconClient._queue_message(self: RconClient, message: ClientMessage, callback: Callback?)
	table.insert(self._queue, {
		message = message,
		callback = callback,
	})
end

function RconClient._find_free_request_id(self: RconClient): number
	for i = RESERVED_IDENTIFIER + 1, MAX_IDENTIFIER do
		if self._active_requests[i] then
			continue
		end

		return i
	end

	error(`unable to find free request id`, 1)
end

function RconClient.execute(self: RconClient, message: string)
	self:_queue_message({ message = message, identifier = RESERVED_IDENTIFIER })
end

function RconClient.request_async(self: RconClient, message: string, timeout: number?, identifier: number?): string
	local timeout = timeout or DEFAULT_REQUEST_TIMEOUT
	local identifier = identifier or self:_find_free_request_id()
	if identifier == RESERVED_IDENTIFIER then
		error(`attempt to use reserved identifier {identifier} for request`)
	end

	local response: ServerMessage
	self:_queue_message({ message = message, identifier = identifier }, function(message: ServerMessage)
		response = message
	end)

	local timeout_at = os.clock() + timeout
	while not response do
		sys.task.wait()
		if os.clock() > timeout_at then
			error(`request timed-out, should this be a request?`, 2)
		end
	end

	return response.message
end

function RconClient.connect(self: RconClient, host: string, password: string, tls: boolean?)
	if self._status ~= "waiting" then
		error(`cant connect a {self._status} RconClient`, 2)
	end

	local addr = socket_address.parse(host)
	local port = addr.port or DEFAULT_RCON_PORT

	local protocol = if tls then "wss" else "ws"
	local url = `{protocol}://{addr.hostname}:{port}/{password}`

	local socket: sys.WebSocket = sys.WebSocket.new(url)

	sys.task.spawn(function()
		while socket:status() ~= "open" do
			sys.task.wait()
		end

		self._status = "active"
		self.connected:_fire()

		while sys.task.wait() do
			if socket:status() == "closed" then
				self._status = "dead"
			end

			if self._status == "dead" then
				socket:close()
				self.disconnected:_fire()
				return
			end

			while true do
				local wire_message = socket:try_next()
				if not wire_message then
					break
				end

				local raw_message: any = json.decode(wire_message)
				local message: ServerMessage = {
					message = raw_message.Message,
					identifier = raw_message.Identifier,
					type = raw_message.Type,
					stacktrace = raw_message.Stacktrace,
				}

				local request = self._active_requests[message.identifier]
				if request then
					(request.callback or error("never"))(message)
					self._active_requests[message.identifier] = nil
				end

				self.message_received:_fire(message, request ~= nil)
			end

			local queue = table.clone(self._queue)
			table.clear(self._queue)

			for _, queued_message in queue do
				if queued_message.callback then
					if self._active_requests[queued_message.message.identifier] then
						-- Current identifier is already in use. We don't need to check for non-request messages.
						table.insert(self._queue, queued_message)
						continue
					end

					self._active_requests[queued_message.message.identifier] = queued_message
				end

				local wire_message = json.encode({
					Message = queued_message.message.message,
					Identifier = queued_message.message.identifier,
					Name = self.name,
					Stacktrace = queued_message.message.stacktrace,
				})

				socket:send(wire_message)
				self.message_sent:_fire(queued_message.message, queued_message.callback ~= nil)
			end
		end
	end)
end

function RconClient.disconnect(self: RconClient)
	if self._status ~= "active" then
		error("cant disconnect non-living RconClient", 2)
	end

	self._status = "dead"
end

return RconClient
