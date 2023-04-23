local PathEZ = require(game:GetService("ReplicatedStorage").Packages.PathEZ.PathEZ)

local NPC : Model = game.Workspace:WaitForChild("NPC")

local path
game:GetService("Players").PlayerAdded:Connect(function(player)
	player.CharacterAdded:Wait()
	path = PathEZ.new(NPC)
	path.IsMoving = true
end)

PathEZ.Error:Connect(function(error: PathEZ.Error)
	print(error.Agent)
	--path:StopFollowing()
end)