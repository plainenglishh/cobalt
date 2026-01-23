local sys_types = require("./sys_types")
local lune_task = require("@lune/task")

local lune: sys_types.SysLib = {
	task = {
		spawn = lune_task.spawn,
		defer = lune_task.defer,
		wait = lune_task.wait,
	},
	WebSocket = require("@self/WebSocket"),
}

return lune
