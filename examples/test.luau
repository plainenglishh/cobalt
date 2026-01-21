local process = require("@lune/process")
local cobalt = require("../src")

local bot = cobalt.Bot.new()

bot.started:connect(function()
	print("bot ready")
end)

bot.errored:connect(function(err)
	print(`Bot errored: {err.message}`)
	print(err.traceback)
end)

bot.player_joined:connect(function(player)
	print("Welcome", player.display_name)
end)

bot.player_left:connect(function(player)
	print("Goodbye", player.display_name)
end)

bot.player_spawned:connect(function(player)
	print(`Player {player.display_name} has spawned!`)
end)

bot.player_died:connect(function(player, cause, position)
	print(`Player {player.display_name} has died from {cause} at {position}!`)
	bot:say(`RIP {player.display_name} `)
end)

bot.chatted:connect(function(player: cobalt.Player?, message: string, colour: string, timestamp: number)
	if not player then
		return
	end

	if message == "!whoami" then
		bot:say(
			`You are {player.display_name} ({player.id})\nYou have been here for: {player.connected_seconds} seconds.`
		)
	elseif message == "!kill" then
		player:kill()
	elseif message == "!kick" then
		player:kick("GO AWAY!")
	elseif message == "!ak" then
		player:give_item("rifle.ak")
		player:give_item("ammo.rifle", 100)
	elseif message == "!pigs" then
		local eyes = player:eyes()
		local rad_pitch = math.rad(eyes.x)
		local rad_yaw = math.rad(eyes.y)
		local look_vector = vector.create(
			math.cos(rad_pitch) * math.sin(rad_yaw),
			-math.sin(rad_pitch),
			math.cos(rad_pitch) * math.cos(rad_yaw)
		)

		local position = player:position() + (look_vector * 15)

		bot:say(`spawning 20 pigs at {position}`)
		for i = 1, 20 do
			bot:spawn_entity("boar", position)
		end
	elseif message == "!mymini" then
		local position = player:position() + vector.create(0, 10, 0)
		bot:spawn_entity("minicopter.entity", position)
	end
end)

bot:run(process.args[1], process.args[2])
