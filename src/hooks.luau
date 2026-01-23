local RconClient = require("./RconClient")
local t = require("./types")
local rust_vector = require("./util/rust_vector")
local json = require("./dependencies/json")

type Callback = (bot: t.Bot, message: RconClient.ServerMessage, ...string) -> ()
type Hook = {
	identifier: number?,
	type: string?,
	pattern: string?,
	callback: Callback,
}

local HOOKS: { Hook } = {}
local function add_hook(identifier: number?, type: string?, pattern: string?, callback: Callback)
	table.insert(HOOKS, {
		identifier = identifier,
		type = type,
		pattern = pattern,
		callback = callback,
	})
end

add_hook(0, "Generic", "^.+%[(%d*)] has spawned", function(bot, message, id)
	local player = bot:get_player_by_id(id)
	if not player then
		bot:_update_players_async()
		player = bot:get_player_by_id(id)
	end

	if not player then
		error(`spawn event for non-existent player '{id}'`)
		return
	end

	bot.player_spawned:_fire(player)
end)

add_hook(0, "Generic", "^.+%[(%d*)] was killed by (.+) at %((.+)%)", function(bot, message, id, cause, location)
	local player = bot:get_player_by_id(id) or error(`death event for non-existent player '{id}'`) -- dont do spawns forced refresh
	bot.player_died:_fire(player, cause, rust_vector.decode(location))
end)

add_hook(-1, "Chat", nil, function(bot, message)
	local chat: any = json.decode(message.message)
	bot.chatted:_fire(bot:get_player_by_id(chat.UserId), chat.Message, chat.Color, chat.Time)
end)

local hooks = {}

function hooks.run_hooks(bot: t.Bot, message: RconClient.ServerMessage)
	local function hook_err_handler(err: any)
		local traceback = debug.traceback("", 2)
		bot:_error(err, traceback, t.ErrorSourceHook())
	end

	for _, hook in HOOKS do
		if
			(message.identifier or message.identifier) == hook.identifier
			and (message.type or hook.type) == hook.type
			and if hook.pattern then string.find(message.message, hook.pattern) else true
		then
			local matches = {}
			if hook.pattern then
				matches = { string.match(message.message, hook.pattern) }
			end

			xpcall(hook.callback, hook_err_handler, bot, message, unpack(matches))
		end
	end
end

return hooks
