local sys_types = require("@self/sys_types")
export type WebSocket = sys_types.WebSocket
export type Task = sys_types.Task

local sys: sys_types.SysLib
if string.match(_VERSION, "Lune") then
	sys = require("@self/lune")
end
return sys
