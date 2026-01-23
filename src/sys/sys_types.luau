local task = require("@lune/task")
--[=[
	Types that must be implemented by runtime implementations.
]=]
local sys_types = {}

export type WebSocket = setmetatable<{ [any]: any }, {
	__index: getmetatable<WebSocket>,

	--[=[
        Creates a new `WebSocket`.

        Will connect to the given url.
    ]=]
	new: (url: string) -> WebSocket,
	status: (self: WebSocket) -> "connecting" | "open" | "closed" | "errored",

	--[=[
        Returns the next message, if available.

        Doesn't yield or block.
    ]=]
	try_next: (self: WebSocket) -> string?,
	send: (self: WebSocket, data: buffer | string) -> (),
	close: (self: WebSocket, code: number?) -> (),
}>

export type Task = {
	spawn: <T...>((T...) -> () | thread, T...) -> thread,
	defer: <T...>((T...) -> () | thread, T...) -> thread,
	wait: (duration: number?) -> number,
}

export type SysLib = {
	task: Task,
	WebSocket: WebSocket,
}

return sys_types
