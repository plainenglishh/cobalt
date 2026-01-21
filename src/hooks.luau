local serde = require("@lune/serde")
local RconClient = require("./RconClient")
local t = require("./types")
local rust_vector = require("./util/rust_vector")

type Callback = (bot: t.Bot, message: RconClient.ServerMessage, ...string) -> ()
type LogHook = {
	identifier: number?,
	type: string?,
	pattern: string?,
	callback: Callback,
}

local log_hooks: { LogHook } = {}
local function add_hook(identifier: number?, type: string?, pattern: string?, callback: Callback)
	table.insert(log_hooks, {
		identifier = identifier,
		type = type,
		pattern = pattern,
		callback = callback,
	})
end

add_hook(0, "Generic", "^.+%[(%d*)] has spawned", function(bot, message, id)
	local player = bot:get_player_by_id(id) or error(`non-existent spawn event for {id}?`)
	bot.player_spawned:_fire(player)
end)

add_hook(0, "Generic", "^.+%[(%d*)] was killed by (.+) at %((.+)%)", function(bot, message, id, cause, location)
	local player = bot:get_player_by_id(id) or error(`non-existent death event for {id}?`)
	bot.player_died:_fire(player, cause, rust_vector.decode(location))
end)

add_hook(-1, "Chat", nil, function(bot, message)
	local chat = serde.decode("json", message.message)
	bot.chatted:_fire(bot:get_player_by_id(chat.UserId), chat.Message, chat.Color, chat.Time)
end)

local hooks = {}

function hooks.run_log_hooks(bot: t.Bot, message: RconClient.ServerMessage)
	for _, hook in log_hooks do
		if
			(message.identifier or message.identifier) == hook.identifier
			and (message.type or hook.type) == hook.type
			and if hook.pattern then string.find(message.message, hook.pattern) else true
		then
			local matches = {}
			if hook.pattern then
				matches = { string.match(message.message, hook.pattern) }
			end

			local ok, err: string = pcall(hook.callback, bot, message, unpack(matches))
			if not ok then
				bot:_error(`error when calling log hook {hook.callback}: {err}`)
			end
		end
	end
end

return hooks
