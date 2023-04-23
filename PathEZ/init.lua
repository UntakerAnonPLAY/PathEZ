local Dependencies = script.Parent.Parent

local Promise = require(Dependencies.promise)
local Signal = require(Dependencies.signal)

--[=[
	@interface PathEZPath
	@within PathEZ

	.Agent Model
	.GeneratedPath Path
	.IsMoving boolean

	Object returned by PathEZ constructor.
]=]

--[=[
	@interface ComputationSettings
	@within PathEZ

	.TimeBetweenCompute number --How much time to wait before next ComputeAsync

	- `TimeBetweenCompute` default value is `0.07` seconds.

	:::note

	To override the defaults provide new `ComputationSettings`, when calling a constructor.

	:::
]=]
export type ComputationSettings = {
	TimeBetweenCompute: number,
}

--[=[
	@interface MoveSettings
	@within PathEZ

	.ignoreNoPathError boolean --ignores computation errors when agent is trying to follow a target

	- `ignoreNoPathError` default value is `true`.

	:::note

	To override the defaults provide new `MoveSettings`, when calling Move functions.

	:::
]=]
export type MoveSettings = {
	ignoreNoPathError: boolean,
}

--[=[
	@class Error

	Class for Error handling
]=]
--[=[
	@interface Error
	@within Error

	.Agent Model	--agent, who caused an error
	.errorType string | Enum
	.errorMessage string --description of an error

	Errors are fired using [Sleitnick's Signal API](https://sleitnick.github.io/RbxUtil/api/Signal).
]=]
export type Error = {
	Agent: Model,
	errorType: string | Enum,
	errorMessage: string,
}

--[=[
	@class PathEZ
	@__index prototype

	PathEZ provides an easy access to PathfindingService using [Promises](https://eryn.io/roblox-lua-promise/api/Promise) and [Sleitnick's Signals](https://sleitnick.github.io/RbxUtil/api/Signal) APIs.
]=]
local PathEZ = {}
PathEZ.prototype = {}
PathEZ.__index = PathEZ.prototype

local DEFFAULT_COMPUTATION_SETTINGS: ComputationSettings = {
	TimeBetweenCompute = 0.07,
}

local DEFFAULT_MOVE_SETTINGS: MoveSettings = {
	ignoreNoPathError = false,
}

--[=[
	@prop Errored Signal
	@within Error

	A signal connection to handle errors from agents.

	```lua
	local PathEZ = require(game:GetService("ReplicatedStorage").Packages.PathEZ)

	function errorHandler(error: PathEZ.Error)
		if error.Agent.Name == "Oleg" and error.errorType == Enum.PathStatus.NoPath then
			print("Oleg can't reach the target")
		end
	end

	PathEZ.Errored:Connect(errorHandler)
	```

	:::info

	This signal connection will provide errors from ALL agents initialized in the same script.

	This means you have to filter errors by agent to handle errors from a specific agent.
	Or have a separate script for each agent, what is harmful for perfomance.

	:::
	
	More info about [Signals](https://sleitnick.github.io/RbxUtil/api/Signal) API.
]=]
PathEZ.Errored = Signal.new()

--[=[
	@within PathEZ
	@tag Constructor
	@param agentParams AgentParameters?
	@return PathEZPath

	Constructor of a PathEZPath

	:::note

	Accepts Roblox's AgentParameters as a second argument and custom computation settings as third or default one will be used.

	:::
]=]
function PathEZ.new(agent: Model, agentParams, computationSettings: ComputationSettings?)
	assert(agent:FindFirstChildOfClass("Humanoid"), "Agent has to have a humanoid in it")

	local self = setmetatable({}, PathEZ)
	self.Agent = agent
	self.GeneratedPath = game:GetService("PathfindingService"):CreatePath(agentParams)
	self.IsMoving = false

	self._computationSettings = computationSettings or DEFFAULT_COMPUTATION_SETTINGS
	self._followingPromise = {}

	return self
end

--[=[
	@return Promise

	Computes waypoints for a given path.
	
	Technically a wrapper for PathfindingService's ComputeAsync and GetWaypoints, but provide async functionality via Promises.

	```lua
	local path = PathEZ.new(agent)

	local start = Vector3.new(0,0,0)
	local finish = player.Character.Position

	--first value from await() is promise's Status, so we ignore it
	PathEZ.ComputeAndGetWaypoints(path.GeneratedPath, start, finish)
		:andThen(function(waypoints)
			for _, waypoint in waypoints do
				doSomething(waypoint)
			end
		end):catch(warn)
	```
	Useful, when you don't want your main function to yield during computation process.

	:::info

	Retruns a promise, which resolves with computed waypoints or rejects with a NoPath errorType.
	
	:::

	More info about [Promise](https://eryn.io/roblox-lua-promise/api/Promise) API.
]=]
function PathEZ.ComputeAndGetWaypoints(path: Path, startPoint: Vector3, finishPoint: Vector3)
	return Promise.new(function(resolve, reject)
		path:ComputeAsync(startPoint, finishPoint)
		if path.Status == Enum.PathStatus.Success then
			resolve(path:GetWaypoints())
		elseif path.Status == Enum.PathStatus.NoPath then
			reject(path.Status, "No path found")
		end
	end)
end

--[=[
	@within PathEZ
	@tag Move Function
	@return IsMoving

	Move agent to a given place. Place will be automatically converted to `Vector3`.

	```lua
	local path = PathEZ.new(agent)

	local character = player.Character

	path:MoveTo(character)
	```

	:::note

	Accepts MoveSettings as a second parameter or default will be used.

	:::
]=]
function PathEZ.prototype:MoveTo(place: Vector3 | Model | BasePart, moveSettings: MoveSettings?): boolean
	assert(
		typeof(place) == "Vector3" or place:IsA("BasePart") or place:IsA("Model"),
		"Place must be a Vector3, Model or a BasePart"
	)

	moveSettings = moveSettings or DEFFAULT_MOVE_SETTINGS

	local point = if place:IsA("Model")
		then place.PrimaryPart.Position
		elseif place:IsA("BasePart") then place.Position
		else place

	local _, waypoints = PathEZ.ComputeAndGetWaypoints(self.GeneratedPath, self.Agent.PrimaryPart.Position, point)
		:catch(function(status, msg)
			if moveSettings.ignoreNoPathError then
				return
			end

			local error: Error = { Agent = self.Agent, errorType = status, errorMessage = msg }
			PathEZ.Errored:Fire(error)
		end)
		:await()

	if not waypoints then
		return
	end

	self.IsMoving = true

	local humanoid: Humanoid = self.Agent:FindFirstChildOfClass("Humanoid")
	for _, waypoint: PathWaypoint in waypoints do
		if waypoint.Action.Value == Enum.PathWaypointAction.Jump then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
		humanoid:MoveTo(waypoint.Position)
	end

	return self.IsMoving
end

--[=[
	@within PathEZ
	@tag Move Function

	@return IsMoving
	Makes agent follow a target.

	```lua
	local path = PathEZ.new(agent)

	path:Follow(player)
	```

	:::note

	Accepts MoveSettings as a second parameter or default will be used.

	:::
]=]
function PathEZ.prototype:Follow(target: Player | Model | BasePart, moveSettings: MoveSettings?): boolean
	assert(
		target:IsA("Player") or target:IsA("Model") or target:IsA("BasePart"),
		"Target must be a Player or Model or a BasePart"
	)

	target = if target:IsA("Player") then target.Character or target.CharacterAdded:Wait() else target

	self._followingPromise = Promise.new(function(resolve, reject, onCancel)
		while true do
			self:MoveTo(target, moveSettings)

			task.wait(self._computationSettings.TimeBetweenCompute)
			if onCancel() then
				break
			end
		end
	end)

	return self.IsMoving
end

--[=[
	@within PathEZ
	@return IsMoving

	Stops agent from following a target.

	```lua
	local path = PathEZ.new(agent)

	path:Follow(player)
	task.wait(6)
	path:StopFollowing()
	```

	:::info

	Call this function before destroying a PathEZPath.

	:::
]=]
function PathEZ.prototype:StopFollowing(): boolean
	assert(Promise.is(self._followingPromise), "Agent isn't following anyone")

	self._followingPromise:cancel()
	self.IsMoving = false
	return self.IsMoving
end

--[=[
	@within PathEZ
	Destroys a PathEZPath

	```lua
	local path = PathEZ.new(agent)

	path:Follow(player)
	task.wait(6)
	path:StopFollowing()
	path:Destroy()
	```

	:::caution

	Automatically stops agent from following a target. But this behavior is not guaranteed and reliable.

	So call externally StopFollowing() before calling Destroy()

	:::
]=]
function PathEZ.prototype:Destroy(): ()
	for i, _ in self do
		if self[i] == self.Agent then
			continue
		elseif typeof(self[i]) == "Instance" then
			self[i]:Destroy()
		elseif Promise.is(self[i]) then
			self[i]:cancel()
			self[i] = nil
		elseif self[i] == DEFFAULT_COMPUTATION_SETTINGS then
			continue
		else
			self[i] = nil
		end
	end

	self = nil
end

return {
	new = PathEZ.new,
	ComputeAndGetWaypoints = PathEZ.ComputeAndGetWaypoints,
	Errored = PathEZ.Errored,
}
