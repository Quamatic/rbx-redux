local ReplicatedStorage = game:GetService("ReplicatedStorage")

_G.__DEV__ = true

print("Starting Redux tests... (This may take a while)")
require(ReplicatedStorage.TestEZ).TestBootstrap:run({ ReplicatedStorage.Tests })
