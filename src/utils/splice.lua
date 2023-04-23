local function splice<T>(array: { T }, start: number, deleteCount: number?, ...: T): { T }
	if start > #array then
		local varargCount = select("#", ...)
		for i = 1, varargCount do
			local toInsert = select(i, ...)
			table.insert(array, toInsert)
		end
		return {}
	else
		local length = #array

		if start < 1 then
			start = math.max(length - math.abs(start), 1)
		end

		local deletedItems = {} :: { T }

		local deleteCount_: number = deleteCount or length
		if deleteCount_ > 0 then
			local lastIndex = math.min(length, start + math.max(0, deleteCount_ - 1))

			for i = start, lastIndex do
				local deleted = table.remove(array, start) :: T
				table.insert(deletedItems, deleted)
			end
		end

		local varargCount = select("#", ...)
		-- Do this in reverse order so we can always insert in the same spot
		for i = varargCount, 1, -1 do
			local toInsert = select(i, ...)
			table.insert(array, start, toInsert)
		end

		return deletedItems
	end
end

return splice
