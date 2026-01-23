local Player = require("../classes/Player")
local json = require("../dependencies/json")
local t = require("../types")

--[=[
    Internal service for listing connected players, dispatching join/leave 
    events, and updating player objects.
]=]
local function player_service(bot: t.Bot)
	bot:_update_players_async()
end

return player_service
