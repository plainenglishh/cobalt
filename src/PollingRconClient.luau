local json = require("./dependencies/json")
local sys = require("./sys")
local socket_address = require("./util/socket_address")

local DEFAULT_RCON_PORT = 28016
local MAX_IDENTIFIER = 9_999_999
local RESERVED_IDENTIFIER = 0

export type RconClientStatus = "connecting" | "open" | "closed" | "errored"

export type IntoClientMessage = string | buffer | ClientMessage

export type ClientMessage = {
	message: string,
	identifier: number?,
	stacktrace: string?,
}

export type WireClientMessage = {
	Message: string,
	Identifier: number,
	Stacktrace: string?,
}

export type ServerMessage = {
	message: string,
	identifier: number,
	type: string,
	stacktrace: string,
}

export type WireServerMessage = {
	Message: string,
	Identifier: number,
	Type: string,
	Stacktrace: string,
}

export type MessageCallback = (reply: ServerMessage) -> ()

export type QueuedClientMessage = {
	message: ClientMessage,
	callback: MessageCallback?,
}

local function parse_into_client_message(into: IntoClientMessage): ClientMessage
	if type(into) == "string" then
		return {
			message = into,
		}
	elseif type(into) == "buffer" then
		return {
			message = buffer.tostring(into),
		}
	else
		return into
	end
end

local function find_free_request_id(session: RconClient): number
	for i = RESERVED_IDENTIFIER + 1, MAX_IDENTIFIER do
		if not session._callbacks[i] then
			return i
		end
	end

	error("failed to find free identifier, are you using callbacks for non-request messages?", 2)
end

--[=[
    Class representing a single RCON session.
]=]
export type RconClient = setmetatable<{
	_name: string,
	_socket: sys.WebSocket,
	_callbacks: { [number]: MessageCallback },
	_queue: { QueuedClientMessage },
}, {
	__index: getmetatable<RconClient>,
	new: (host: string, password: string, name: string?, tls: boolean?) -> RconClient,
	flush: (self: RconClient) -> (),

	--[=[
		Returns the current session status:

		1. `connecting` - The underlying WebSocket has yet to establish a connection.
		2. `open` - The session is open.
		3. `closed` - The session has naturally closed.
		4. `errored` - The session has errored and cannot be revived.
	]=]
	status: (self: RconClient) -> RconClientStatus,

	--[=[
		Enqueues a message, optionally registering a callback.
		
		`RconClient:flush` must be called periodically to send queued messages.

		### Custom Identifiers
		
		Identifier `0` is reserved for non-request messages\*. Request messages 
		must not use identifier `0`, and non-request messages must use 
		identifier `0`, otherwise an error will be thrown.
		
		Multiple request messages can be queued on the same identifier.

		If you don't specify an identifier in `message`, an appropriate 
		identifier will be selected.

		\* A request message is a message that expects a response by way of a
		callback.
	]=]
	send: (self: RconClient, message: IntoClientMessage, callback: MessageCallback?) -> (),

	--[=[
		Returns a `ServerMessage`, or nil if none are available.

		This function polls the underlying WebSocket, and triggers any 
		message callbacks before returning.
	]=]
	recv: (self: RconClient) -> ServerMessage?,
}>

local RconClient = {}
RconClient.__index = RconClient

function RconClient.new(host: string, password: string, name: string?, tls: boolean?): RconClient
	local name = name or "RconClient"
	local tls = if tls ~= nil then tls else false

	local addr = socket_address.parse(host)
	local port = addr.port or DEFAULT_RCON_PORT

	local protocol = if tls then "wss" else "ws"
	local url = `{protocol}://{addr.hostname}:{port}/{password}`

	return setmetatable({
		_name = name,
		_socket = sys.WebSocket.new(url),
		_callbacks = {},
		_queue = {},
	}, RconClient)
end

function RconClient.flush(self: RconClient)
	local queue = table.clone(self._queue)
	table.clear(self._queue)

	for _, queued in queue do
		local callback, message = queued.callback, queued.message

		if callback then
			assert(message.identifier ~= RESERVED_IDENTIFIER)
			if message.identifier and self._callbacks[message.identifier] then
				table.insert(self._queue, queued)
				continue
			end

			local identifier = message.identifier or find_free_request_id(self)
			self._callbacks[identifier] = callback

			local wire_message: WireClientMessage = {
				Message = message.message,
				Identifier = identifier,
				Stacktrace = message.stacktrace,
			}

			self._socket:send(json.encode(wire_message :: any))
		else
			assert(message.identifier == RESERVED_IDENTIFIER or message.identifier == nil)

			local wire_message: WireClientMessage = {
				Message = message.message,
				Identifier = 0,
				Stacktrace = message.stacktrace,
			}

			self._socket:send(json.encode(wire_message :: any))
		end
	end
end

function RconClient.status(self: RconClient): RconClientStatus
	return self._socket:status()
end

function RconClient.send(self: RconClient, message: IntoClientMessage, callback: MessageCallback?)
	local message = parse_into_client_message(message)
	if callback and message.identifier == RESERVED_IDENTIFIER then
		error("attempt to send request on reserved identifier 0", 2)
	elseif not callback and (message.identifier ~= 0 or message.identifier ~= nil) then
		error("attempt to send non-request on custom identifier", 2)
	end

	table.insert(self._queue, {
		message = message,
		callback = callback,
	})
end

function RconClient.recv(self: RconClient): ServerMessage?
	local wire_message = self._socket:try_next()
	if not wire_message then
		return nil
	end

	local wire_message = json.decode(wire_message) :: WireServerMessage
	local message: ServerMessage = {
		message = wire_message.Message,
		identifier = wire_message.Identifier,
		type = wire_message.Type,
		stacktrace = wire_message.Stacktrace,
	}

	local callback = self._callbacks[message.identifier]
	if callback then
		callback(message)
		self._callbacks[message.identifier] = nil
	end

	return message
end

return RconClient
