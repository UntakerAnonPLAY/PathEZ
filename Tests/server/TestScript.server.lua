local PathEZ = require(game:GetService("ReplicatedStorage").Packages.PathEZ.PathEZ)

local NPC : Model = game.Workspace:WaitForChild("NPC")

local path = PathEZ.new(NPC)
game:GetService("Players").PlayerAdded:Connect(function(player)
	player.CharacterAdded:Wait()
	local moveSettings: PathEZ.MoveSettings = {
		ignoreNoPathError = false,
		visualizePath = true
	}
	path:Follow(player.Character, moveSettings)
end)

PathEZ.Errored:Connect(function(error: PathEZ.Error)
	print(error.Agent, error.errorMessage)
	--path:StopFollowing()
end)

path.Events.PlaceReached:Connect(function(pos)
	--print(pos)
end)