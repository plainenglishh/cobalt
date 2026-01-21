# Cobalt

Lune library for writing Rust admin bots in Luau.

## About

Cobalt intends to provide a way to write quick, experimental automatic actions
for a Rust server in Luau, using Lune.

Cobalt works by attaching to the server's RCON interface, listening for specific
(by periodically sending commands and parsing server logs), and sending commands
back to perform in-game actions.

This is primarily a proof of concept; you should probably write a uMod/Oxide
plugin instead.

## Example

The following is an example kit bot:-

```luau
local process = require("@lune/process")
local stdio = require("@lune/stdio")
local cobalt = require("@cobalt/")

type Kit = { { name: string, quantity: number } }

local KITS: { [string]: Kit } = {
	ak = {
		{ name = "rifle.ak", quantity = 1 },
		{ name = "ammo.rifle", quantity = 128 },
	},
}

local function award_kit(player: cobalt.Player, kit: Kit)
	for _, item in kit do
		player:give_item(item.name, item.quantity)
	end
end

local bot = cobalt.Bot.new()

bot.chatted:connect(function(player: cobalt.Player?, message: string)
	if not player then
		return
	end

	if string.sub(message, 1, 4) ~= "!kit" then
		return
	end

	local args = string.split(string.sub(message, 5), " ")

	local kit_name = args[1]
	if not kit_name then
		bot:say("specify kit")
	end

	local kit = KITS[kit_name]
	if not kit then
		bot:say(`invalid kit '{kit_name}'`)
		return
	end

	award_kit(player, kit)
end)

bot.started:connect(function()
	print("KitBot has started!")
end)

bot.errored:connect(function(err: cobalt.Error)
	stdio.ewrite(`{stdio.color("red")}{err.source.type} error: {err.message}{stdio.color("reset")}\n`)
	stdio.ewrite(`{stdio.style("dim")}{err.traceback}{stdio.color("reset")}\n`)
	bot:say(`KitBot Error: {err.message}`)
end)

bot:run(process.args[1] or error("specify host"), process.args[2] or error("specify password"))
```

More examples can be found under `examples/`.
