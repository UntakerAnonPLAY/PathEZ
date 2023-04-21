local PathEZ = require(game:GetService("ReplicatedStorage").PathEZ)

local NPC : Model = game.Workspace:WaitForChild("NPC")

local path
game:GetService("Players").PlayerAdded:Connect(function(player)
	player.CharacterAdded:Wait()
	path = PathEZ.new(NPC)
	path:Follow(player)
end)

PathEZ.Error:Connect(function(error: PathEZ.Error)
	print(error.Agent, error.msg)
	--path:StopFollowing()
end)

