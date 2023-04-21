export type PathEZPath = {
	Agent: Model,
	GeneratedPath: Path,
	IsMoving: boolean,
	MoveTo: (place: Vector3 | Model | BasePart, moveSettings: MoveSettings?) -> string,
	Destroy: () -> (),
}

export type AgentParameters = {
	AgentRadius: number, --actually an integer
	AgentHeight: number, --actually an integer
	AgentCanJump: boolean,
	AgentCanClimb: boolean,
	WaypointSpacing: number,
	Costs: table,
}

export type GlobalComputationSettings = {
	TimeBetweenComputations: number,
}

export type Error = {
	Agent: Model,
	Status: string | Enum,
	msg: string,
}

export type MoveSettings = {
	ignoreNoPathError: boolean,
}

--[=[
	@class PathEZ
	
	PathEZ helps developers to easily use Pathdinding Service
]=]
local PathEZ = {}

--[=[
	@class PathEZPath
	
	PathEZ helps developers to easily use Pathdinding Service
]=]
PathEZ.prototype = {}
PathEZ.__index = PathEZ.prototype

local Dependencies = script.Parent

local Promise = require(Dependencies.promise)
local Signal = require(Dependencies.signal)

PathEZ.Error = Signal.new()

local DEFFAULT_GLOBAL_SETTINGS: GlobalSettings = {
	--How much time to wait before next ComputeAsync
	TimeBetweenComputations = 0.07,
}

local DEFFAULT_MOVE_SETTINGS: MoveSettings = {
	ignoreNoPathError = false,
}


--[=[
	Constructor for PathEZ
	@return PathEZPath
]=]
function PathEZ.new(agent: Model, agentParams: AgentParameters?, computationSettings: GlobalComputationSettings?)
	assert(agent:FindFirstChildOfClass("Humanoid"), "Agent has to have a humanoid in it")

	local self = setmetatable({}, PathEZ)
	self.Agent = agent
	self.GeneratedPath = game:GetService("PathfindingService"):CreatePath(agentParams)
	self.IsMoving = false

	self._computationSettings = computationSettings or DEFFAULT_GLOBAL_SETTINGS
	self._followingPromise = {}

	return self
end

--[=[
	@return Promise

	Computes waypoints for a given path. Technically a wrapper for PathfindingService's ComputeAsync and GetWaypoints.

	```lua
	local path = PathEZ.new(agent)

	local start = Vector3.new(0,0,0)
	local finish = player.Character.Position

	--first value from await() is promise's Status, which we don't need in this situation
	local _, waypoints = PathEZ.ComputeAndGetWaypoints(path.GeneratedPath, start, finish):catch(warn):await()

	if waypoints then
		for _, waypoint in waypoints do
			doSomething(waypoint)
		end
	end
	```
	Retruns a promise, which resolves with computed waypoints or rejects with a NoPath status.
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
	@within PathEZPath

	Move agent to a given place. Place can be `Vector3` | `Model` | `BasePart`

	```lua
	local path = PathEZ.new(agent)

	local character = player.Character

	path:MoveTo(character)
	```
]=]
function PathEZ.prototype:MoveTo(place: Vector3 | Model | BasePart, moveSettings: MoveSettings?): boolean
	assert(
		typeof(place) == "Vector3" or place:IsA("BasePart") or place:IsA("Model"),
		"Place must be a Vector3 or Model or a BasePart"
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

			local error: Error = { Agent = self.Agent, Status = status, msg = msg }
			PathEZ.Error:Fire(error)
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
	@within PathEZPath

	Makes agent follow a target. Targe can be `Player` | `Model` | `BasePart`

	```lua
	local path = PathEZ.new(agent)

	path:Follow(player)
	```
]=]
function PathEZ.prototype:Follow(target: Player | Model | BasePart, moveSettings: MoveSettings): table
	assert(
		target:IsA("Player") or target:IsA("Model") or target:IsA("BasePart"),
		"Target must be a Player or Model or a BasePart"
	)

	target = if target:IsA("Player") then target.Character or target.CharacterAdded:Wait() else target

	self._followingPromise = Promise.new(function(resolve, reject, onCancel)
		while true do
			self:MoveTo(target, moveSettings)

			task.wait(self._computationSettings.TimeBetweenComputations)
			if onCancel() then
				break
			end
		end
	end)
end

--[=[
	@within PathEZPath

	Stops agent from following a target

	```lua
	local path = PathEZ.new(agent)

	path:Follow(player)
	task.wait(6)
	path:StopFollowing()
	```
]=]
function PathEZ.prototype:StopFollowing()
	assert(Promise.is(self._followingPromise), "It is not following")

	self._followingPromise:cancel()
	self.IsMoving = false
	return self.IsMoving
end

--[=[
	@within PathEZPath

	Destroys a PathEZPath

	```lua
	local path = PathEZ.new(agent)

	path:Follow(player)
	task.wait(6)
	path:StopFollowing()
	path:Destroy()
	```
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
		elseif self[i] == DEFFAULT_GLOBAL_SETTINGS then
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
	Error = PathEZ.Error,
}
