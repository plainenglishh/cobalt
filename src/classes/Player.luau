local rust_vector = require("../util/rust_vector")
local t = require("../types")

local Player = {}
Player.__index = Player

function Player._new(bot: t.Bot, id: string): t.Player
	return setmetatable({
		bot = bot,
		id = id,
		display_name = "?",
		ping = 0,
		address = "?",
		entity_id = 0,
		health = 0,
		connected_seconds = 0,
		violation_level = 0,
	}, Player)
end

function Player._update(self: t.Player, playerinfo: any)
	self.display_name = playerinfo.DisplayName
	self.ping = playerinfo.Ping
	self.address = playerinfo.address
	self.entity_id = playerinfo.EntityId
	self.health = playerinfo.Health
	self.connected_seconds = playerinfo.ConnectedSeconds
	self.violation_level = playerinfo.ViolationLevel
end

function Player.give_item(self: t.Player, item: string, quantity: number?, skin: number?)
	self.bot:execute(`inventory.giveto "{self.id}" "{item}" {quantity or 1} {if skin then skin else ""}`)
end

function Player.kill(self: t.Player)
	self.bot:execute(`killplayer "{self.id}"`)
end

function Player.kick(self: t.Player, reason: string?)
	self.bot:execute(`kick "{self.id}" {if reason then `"{reason}"` else ""}`)
end

function Player.eyes(self: t.Player): vector
	local position = self.bot:request_async(`server.printeyes {self.id}`)
	return rust_vector.decode(position)
end

function Player.position(self: t.Player): vector
	local position = self.bot:request_async(`server.printpos {self.id}`)
	return rust_vector.decode(position)
end

function Player.connected(self: t.Player): boolean
	return table.find(self.bot._players, self) ~= nil
end

return Player
