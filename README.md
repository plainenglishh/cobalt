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
local cobalt = require("@cobalt/")

type Kit = { { name: string, quantity: number } }

local KITS: { [string]: Kit } = {
	ak = {
		{ name = "rifle.ak", quantity = 1 },
		{ name = "ammo.rifle", quantity = 128 },
	},
}

local bot = cobalt.Bot.new()

bot.chatted:connect(function(player: cobalt.Player?, message: string)
	if not player then
		return
	end

	if string.sub(message, 1, 4) ~= "!kit" then
		return
	end

	local kit_name = string.match(message, "^!kit (%w+)$")
	if not kit_name then
		bot:say("specify kit")
		return
	end

	local kit = KITS[kit_name]
	if not kit then
		bot:say(`invalid kit '{kit_name}'`)
		return
	end

	for _, item in kit do
		player:give_item(item.name, item.quantity)
	end
end)

bot.started:connect(function()
	print("KitBot has started!")
end)

bot.errored:connect(function(err)
	print(`KitBot has suffered an error: {err}`)
	bot:say(`KitBot has suffered an error: {err}`)
end)

bot:run("rcon_ip", "rcon_password")
```

More examples can be found under `examples/`.
