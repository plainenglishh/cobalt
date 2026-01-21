local serde = require("@lune/serde")
local Player = require("../classes/Player")
local t = require("../types")

--[=[
    Internal service for listing connected players, dispatching join/leave 
    events, and updating player objects.
]=]
local function player_service(bot: t.Bot)
	local playerlist = serde.decode("json", bot._rcon:request_async("playerlist"))

	local old_players: { t.Player } = bot._players
	local new_players: { t.Player } = {}

	for _, playerinfo in playerlist do
		local player = bot:get_player_by_id(playerinfo.SteamID) or Player._new(bot, playerinfo.SteamID)
		player:_update(playerinfo)
		table.insert(new_players, player)
	end

	bot._players = new_players

	for _, new_player in new_players do
		local joined = true

		for _, old_player in old_players do
			if new_player.id == old_player.id then
				joined = false
			end
		end

		if joined then
			if table.find(bot._initial_player_ids, new_player.id) then
				continue
			end

			bot.player_joined:_fire(new_player)
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
			if table.find(bot._initial_player_ids, old_player.id) then
				table.remove(
					bot._initial_player_ids,
					table.find(bot._initial_player_ids, old_player.id) or error("never")
				)
			end

			bot.player_left:_fire(old_player)
		end
	end
end

return player_service
