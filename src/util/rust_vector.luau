local rust_vector = {}

function rust_vector.decode(str: string): vector
	local str = str:gsub("^%(", ""):gsub("%)$", "")
	local parts = string.split(str, ", ")
	local x = tonumber(parts[1]) or error("invalid vector")
	local y = tonumber(parts[2]) or error("invalid vector")
	local z = tonumber(parts[3]) or error("invalid vector")

	return vector.create(x, y, z)
end

function rust_vector.encode(vec: vector): string
	return `({vec.x}, {vec.y}, {vec.z})`
end

return rust_vector
