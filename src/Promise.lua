if script.Parent.Parent:FindFirstChild("Promise") then
	return require(script.Parent.Parent.Promise)
end

error("Promise package not found in same directory")
