local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("Starting Redux tests... (This may take a while)")
require(ReplicatedStorage.TestEZ).TestBootstrap:run({ ReplicatedStorage.Tests })
