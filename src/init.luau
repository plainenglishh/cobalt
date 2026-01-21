local t = require("@self/types")

local cobalt = {}

cobalt.version = "0.1.0"

local Bot = require("@self/classes/Bot")
cobalt.Bot = Bot
export type Bot = t.Bot
export type BotOptions = t.BotOptions
export type Player = t.Player
export type IntoId = t.IntoId

local RconClient = require("@self/RconClient")
cobalt.RconClient = RconClient
export type RconClient = RconClient.RconClient
export type RconClientOptions = RconClient.RconClientOptions
export type RconClientStatus = RconClient.RconClientStatus
export type ServerMessage = RconClient.ServerMessage
export type ClientMessage = RconClient.ClientMessage

return cobalt
