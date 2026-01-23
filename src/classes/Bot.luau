local task = require("@lune/task")
local Player = require("./Player")
local json = require("../dependencies/json")
local rust_vector = require("../util/rust_vector")
local player_service = require("../services/player_service")
local Event = require("../util/Event")
local RconClient = require("../RconClient")
local t = require("../types")
local hooks = require("../hooks")

local function errored_errored(err: Event.Error)
	print(`[cobalt]: Bot.errored handler failed: {err.message}\n{err.traceback}`)
end

local Bot = {}
Bot.__index = Bot

function Bot.new(options: t.BotOptions?): t.Bot
	local options: t.BotOptions = options or {}
	local name: string = options.name or "Bot"

	local errored: Event.Event<t.Error> = Event.new(errored_errored)

	local function on_event_err(err: Event.Error)
		errored:_fire(t.Error(err.message, err.traceback, t.ErrorSourceEvent(err.event, err.listener)))
	end

	local self: t.Bot = setmetatable({
		name = name,

		started = Event.new(on_event_err),
		stopped = Event.new(on_event_err),
		errored = errored,

		console_log = Event.new(on_event_err),
		player_joined = Event.new(on_event_err),
		player_left = Event.new(on_event_err),
		player_spawned = Event.new(on_event_err),
		player_died = Event.new(on_event_err),
		chatted = Event.new(on_event_err),

		_initial_player_ids = {},
		_players = {},
		_services = {},
		_server = nil :: any,
		_rcon = RconClient.new({ name = name }),
	}, Bot)

	self._rcon.connected:connect(function()
		for _, info in json.decode(self:request_async("playerlist")) :: any do
			table.insert(self._initial_player_ids, info.SteamID :: string)
		end

		self:register_service(1, player_service)
		self.started:_fire()
	end)

	self._rcon.disconnected:connect(function()
		self.stopped:_fire()
	end)

	self._rcon.message_received:connect(function(message: RconClient.ServerMessage, handled: boolean)
		if handled then
			return
		end

		hooks.run_hooks(self, message)
		if not handled then
			self.console_log:_fire(message)
		end
	end)

	return self
end

function Bot.run(self: t.Bot, host: string, password: string, tls: boolean?)
	self._rcon:connect(host, password, tls)

	task.defer(function()
		local function handle_service_error(err: any)
			self:_error(err, debug.traceback("", 2), t.ErrorSourceService(debug.info(3, "f")))
		end

		self.started:wait()
		while self._rcon:status() == "active" do
			local now = os.clock()
			-- Once RconClient is converted to polling, do that here, instead of event handling (would rather have one loop for this.)

			for _, service in self._services do
				if service.next_fire > now then
					continue
				end

				xpcall(service.update, handle_service_error, self)

				service.next_fire = now + service.period
			end

			task.wait()
		end
	end)
end

function Bot._error(self: t.Bot, message: string, traceback: string, source: t.ErrorSource, context: { [string]: any }?)
	self.errored:_fire(t.Error(message, traceback, source, context))
end

function Bot.register_service(self: t.Bot, period: number, update: t.BotServiceUpdateFn): () -> ()
	local service: t.BotServiceInstance = {
		period = period,
		next_fire = os.clock(),
		update = update,
	}

	table.insert(self._services, service)

	return function()
		table.remove(self._services, table.find(self._services, service) or error("failed to remove service"))
	end
end

function Bot.execute(self: t.Bot, message: string)
	self._rcon:execute(message)
end

function Bot.request_async(self: t.Bot, message: string, timeout: number?, identifier: number?): string
	return self._rcon:request_async(message, timeout, identifier)
end

function Bot.players(self: t.Bot): { t.Player }
	return table.clone(self._players)
end

function Bot.get_player_by_id(self: t.Bot, id: string): t.Player?
	for _, player in self._players do
		if player.id == id then
			return player
		end
	end

	return nil
end

function Bot.say(self: t.Bot, message: string)
	self:execute(`say {message}`)
end

function Bot.spawn_entity(self: t.Bot, entity: string, position: vector)
	self:execute(`entity.spawn "{entity}" "{rust_vector.encode(position)}"`)
end

function Bot._update_players_async(self: t.Bot)
	local playerlist: any = json.decode(self._rcon:request_async("playerlist"))

	local old_players: { t.Player } = self._players
	local new_players: { t.Player } = {}

	for _, playerinfo in playerlist do
		local player = self:get_player_by_id(playerinfo.SteamID) or Player._new(self, playerinfo.SteamID)
		player:_update(playerinfo)
		table.insert(new_players, player)
	end

	self._players = new_players

	for _, new_player in new_players do
		local joined = true

		for _, old_player in old_players do
			if new_player.id == old_player.id then
				joined = false
			end
		end

		if joined then
			if table.find(self._initial_player_ids, new_player.id) then
				continue
			end

			self.player_joined:_fire(new_player)
		end
	end

	for _, old_player in old_players do
		local left = true

		for _, new_player in new_players do
			if old_player.id == new_player.id then
				left = false
			end
		end

		if left then
			if table.find(self._initial_player_ids, old_player.id) then
				table.remove(
					self._initial_player_ids,
					table.find(self._initial_player_ids, old_player.id) or error("never")
				)
			end

			self.player_left:_fire(old_player)
		end
	end
end

return Bot
