local Event = require("./util/Event")
local RconClient = require("./RconClient")

local t = {}

export type BotOptions = {
	name: string?,
}

export type botServiceFn = (bot: Bot) -> ()
export type botService = { period: number, next_fire: number, callback: botServiceFn }
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
		read errored: Event.Event<string>,

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

		_services: { botService },
		_initial_player_ids: { string },
		_players: { Player },
		_rcon: RconClient.RconClient,
	},
	{
		__index: getmetatable<Bot>,

		--[=[
			Creates a new `Bot`.
		]=]
		new: (options: BotOptions?) -> Bot,

		_error: (self: Bot, message: string) -> (),

		--[=[
			Registers a service to run every `period` seconds (or every cycle 
			if 0).
		]=]
		register_service: (self: Bot, period: number, callback: botServiceFn) -> () -> (),

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
	}
>

--[=[
	Class representing a Rust player.
]=]
export type Player = setmetatable<
	{
		--- The `Bot` this player belongs to.
		bot: Bot,
		id: string,
		display_name: string,
		ping: number,
		address: string,
		entity_id: number,
		health: number,
		connected_seconds: number,
		violation_level: number,
	},
	{
		__index: getmetatable<Player>,
		_new: (server: Bot, id: string) -> Player,
		_update: (self: Player, playerinfo: any) -> (),
		give_item: (self: Player, item: string, quantity: number?, skin: number?) -> (),
		kill: (self: Player) -> (),
		kick: (self: Player, reason: string?) -> (),
		eyes: (self: Player) -> vector,
		position: (self: Player) -> vector,
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
