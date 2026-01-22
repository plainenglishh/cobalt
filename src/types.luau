local Event = require("./util/Event")
local RconClient = require("./RconClient")

local t = {}

export type ErrorSourceService = {
	type: "service",
	service: BotServiceUpdateFn,
}

function t.ErrorSourceService(service: BotServiceUpdateFn): ErrorSourceService
	return {
		type = "service",
		service = service,
	}
end

export type ErrorSourceEvent = {
	type: "event",
	event: Event.Event<...any>,
	listener: Event.Listener<...any>,
}

function t.ErrorSourceEvent(event: Event.Event<...any>, listener: Event.Listener<...any>): ErrorSourceEvent
	return {
		type = "event",
		event = event,
		listener = listener,
	}
end

export type ErrorSourceHook = {
	type: "hook",
}

function t.ErrorSourceHook(): ErrorSourceHook
	return {
		type = "hook",
	}
end

export type ErrorSource = ErrorSourceService | ErrorSourceEvent | ErrorSourceHook

export type Error = {
	message: any,
	traceback: string,
	source: ErrorSource,
	context: { [string]: any },
}

function t.Error(message: any, traceback: string, source: ErrorSource, context: { [string]: any }?): Error
	return {
		message = message,
		traceback = traceback,
		source = source,
		context = context or {},
	}
end

export type BotOptions = {
	name: string?,
}

export type BotServiceUpdateFn = (bot: Bot) -> ()
export type BotServiceInstance = { period: number, next_fire: number, update: BotServiceUpdateFn }
export type LogLevel = "trace" | "debug" | "info" | "warn" | "error"

--[=[
	Class responsible for the lifecycle of a cobalt bot.
]=]
export type Bot = setmetatable<
	{
		--- The name of the botlication. Sent to the server in RCON messages.
		name: string,

		--- Fires when the Bot connects to the server.
		read started: Event.Event<>,

		--- Fires when the Bot disconnects from the server.
		read stopped: Event.Event<>,

		--- Fires when an internal error occurs.
		read errored: Event.Event<Error>,

		--- Fires for non-targetted messages.
		read console_log: Event.Event<RconClient.ServerMessage>,

		--- Fires when a new `Player` joins.
		read player_joined: Event.Event<Player>,

		--- Fires when a `Player` leaves.
		read player_left: Event.Event<Player>,

		--- Fires when a `Player` spawns.
		read player_spawned: Event.Event<Player>,

		--- Fires when a `Player` dies.
		read player_died: Event.Event<Player, string, vector>,

		--- Fires when someone sends a chat message.
		read chatted: Event.Event<Player?, string, string, number>,

		--- **PRIVATE -- DO NOT USE**
		_services: { BotServiceInstance },
		--- **PRIVATE -- DO NOT USE**
		_initial_player_ids: { string },
		--- **PRIVATE -- DO NOT USE**
		_players: { Player },
		--- **PRIVATE -- DO NOT USE**
		_rcon: RconClient.RconClient,
	},
	{
		__index: getmetatable<Bot>,

		--[=[
			Creates a new `Bot`.
		]=]
		new: (options: BotOptions?) -> Bot,

		--[=[
			Registers a service to run every `period` seconds (or every cycle 
			if 0).
		]=]
		register_service: (self: Bot, period: number, update: BotServiceUpdateFn) -> () -> (),

		--[=[
			Connects to the server.
		]=]
		run: (self: Bot, host: string, password: string, tls: boolean?) -> (),

		--[=[
			Sends an RCON message to the server, without expecting a reply.
		]=]
		execute: (self: Bot, message: string) -> (),

		--[=[
			Sends an RCON message to the server asynchronously, returning the 
			response, or erroring if one isn't received in time.

			Timeouts indicate the command failed.
		]=]
		request_async: (self: Bot, message: string, timeout: number?, identifier: number?) -> string,

		--[=[
			Returns an array of currently connected `Player`s.
		]=]
		players: (self: Bot) -> { Player },

		--[=[
			Returns a `Player` from their steamID64, or `nil` if they aren't
			present in the server.
		]=]
		get_player_by_id: (self: Bot, id: string) -> Player?,

		--[=[
			Sends a global chat message to the server.
		]=]
		say: (self: Bot, message: string) -> (),

		--[=[
			Spawns an entity at a given position.
		]=]
		spawn_entity: (self: Bot, entity: string, position: vector) -> (),

		--- **PRIVATE -- DO NOT USE**
		_error: (self: Bot, message: string, traceback: string, source: ErrorSource, context: { [string]: any }?) -> (),
	}
>

--[=[
	Class representing a Rust player.
]=]
export type Player = setmetatable<
	{
		--- The `Bot` this player belongs to.
		bot: Bot,

		--- The `Player`'s steamID64.
		id: string,

		--- The `Player`'s display name.
		display_name: string,

		--- The `Player`'s ping.
		ping: number,

		--- The `Player`'s network address.
		address: string,

		--- The `Player`'s character entity id.
		entity_id: number,

		--- The `Player`'s current health.
		health: number,

		--- How long the `Player` has been connected to the server.
		connected_seconds: number,

		--- The `Player`'s anti-cheat violation level.
		violation_level: number,
	},
	{
		__index: getmetatable<Player>,

		--[=[
			Awards an item to the `Player`.

			This emits a chat message. As far as I'm aware, there is no way to 
			get around this without a server plugin.
		]=]
		give_item: (self: Player, item: string, quantity: number?, skin: number?) -> (),

		--[=[
			Kills the `Player`.
		]=]
		kill: (self: Player) -> (),

		--[=[
			Disconnects the `Player` from the server, optionally with a reason.
		]=]
		kick: (self: Player, reason: string?) -> (),

		--[=[
			Returns a vector encoding the `Player`'s eye direction (pitch, yaw).
		]=]
		eyes: (self: Player) -> vector,

		--[=[
			Returns the `Player`s position.
		]=]
		position: (self: Player) -> vector,

		--- **PRIVATE -- DO NOT USE**
		_new: (server: Bot, id: string) -> Player,
		--- **PRIVATE -- DO NOT USE**
		_update: (self: Player, playerinfo: any) -> (),
	}
>

export type IntoId = Player | string
function t.parse_intoid(intoid: IntoId): string
	if type(intoid) == "table" then
		return intoid.id
	else
		return intoid
	end
end

return t
