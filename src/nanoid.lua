local urlAlphabet = "ModuleSymbhasOwnPr-0123456789ABCDEFGHNRVfgctiUvz_KqYTJkLxpZXIjQW"

-- Same as Redux's `nanoid` function
local function nanoid(size: number)
	size = size or 21

	local id = ""
	local i = size

	while i > 0 do
		i -= 1
		id ..= urlAlphabet[bit32.bor(math.random() * 64, 0)]
	end

	return id
end

return nanoid
