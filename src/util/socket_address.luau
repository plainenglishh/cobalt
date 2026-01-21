export type SocketAddress = { hostname: string, port: number? }

local socket_address = {}

function socket_address.parse(addr: string): SocketAddress
	local hostname, port

	if string.sub(addr, 1, 1) == "[" then
		local closing_bracket = string.find(addr, "]")
		if not closing_bracket then
			error("expected closing bracket for IPv6 address", 2)
		end

		hostname = string.sub(addr, 2, closing_bracket - 1)

		local remainder = string.sub(addr, closing_bracket + 1)
		if remainder ~= "" then
			local raw_port = string.match(remainder, "^:(%d*)$")
			if not raw_port then
				error(`invalid port: {remainder}`, 2)
			end
			port = tonumber(raw_port) or error("never")
		end
	else
		hostname = addr:match("^([^:]+)$")

		local raw_port = string.match(addr, ":(%d*)$")
		if raw_port then
			port = tonumber(raw_port) or error(`invalid address: {addr}`, 2)
		end
	end

	if not hostname or hostname == "" then
		error("invalid hostname")
	end

	return {
		hostname = hostname,
		port = port,
	}
end

return socket_address
