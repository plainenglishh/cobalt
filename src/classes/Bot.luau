local serde = require("@lune/serde")
local task = require("@lune/task")
local rust_vector = require("../util/rust_vector")
local player_service = require("../services/player_service")
local Event = require("../util/Event")
local RconClient = require("../RconClient")
local t = require("../types")
local hooks = require("../hooks")

local Bot = {}
Bot.__index = Bot

function Bot.new(options: t.BotOptions?): t.Bot
	local options: t.BotOptions = options or {}
	local name: string = options.name or "Bot"

	local self: t.Bot = setmetatable({
		name = name,

		started = Event.new(),
		stopped = Event.new(),
		errored = Event.new(),

		console_log = Event.new(),
		player_joined = Event.new(),
		player_left = Event.new(),
		player_spawned = Event.new(),
		player_died = Event.new(),
		chatted = Event.new(),

		_initial_player_ids = {},
		_players = {},
		_services = {},
		_server = nil :: any,
		_rcon = RconClient.new({ name = name }),
	}, Bot)

	self._rcon.connected:connect(function()
		for _, info in serde.decode("json", self:request_async("playerlist")) do
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

		hooks.run_log_hooks(self, message)
		if not handled then
			self.console_log:_fire(message)
		end
	end)

	return self
end

function Bot.run(self: t.Bot, host: string, password: string, tls: boolean?)
	self._rcon:connect(host, password, tls)

	task.defer(function()
		self.started:wait()
		while self._rcon:status() == "active" do
			local now = os.clock()
			-- Once RconClient is converted to polling, do that here, instead of event handling (would rather have one loop for this.)

			for _, service in self._services do
				if service.next_fire > now then
					continue
				end

				local ok, err: string = pcall(service.callback, self)
				if not ok then
					self:_error(`error when running service {service.callback}: {err}`)
				end

				service.next_fire = now + service.period
			end

			task.wait()
		end
	end)
end

function Bot.register_service(self: t.Bot, period: number, callback: t.botServiceFn): () -> ()
	local service = {
		period = period,
		next_fire = os.clock(),
		callback = callback,
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

return Bot
