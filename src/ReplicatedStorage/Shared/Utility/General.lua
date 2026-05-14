local UserInputS = game:GetService("UserInputService")
local RepS = game:GetService("ReplicatedStorage")

local shared = RepS.Shared
local events = RepS.Events

local camera: Camera = workspace.CurrentCamera

const RAYCAST_DISTANCE: number = 2^11

local General = {}

function General.IsPointInPart(part: BasePart, point: Vector3): boolean
	local relativePoint: Vector3 = part.CFrame:PointToObjectSpace(point)

	return math.abs(relativePoint.X) < part.Size.X / 2
		and math.abs(relativePoint.Y) < part.Size.Y / 2
		and math.abs(relativePoint.Z) < part.Size.Z / 2
end

function General.Weld(part0: BasePart, part1: BasePart): WeldConstraint
	local weldConstraint: WeldConstraint = Instance.new("WeldConstraint")
	weldConstraint.Part0 = part0
	weldConstraint.Part1 = part1
	weldConstraint.Parent = part0

	return weldConstraint
end

function General.Lerp(number1: number, number2: number, lerpSpeed: number): number
	return number1 + (number2 - number1) * lerpSpeed
end

function General.GetMouseResult(raycastParams: RaycastParams?): RaycastResult?
	local mousePos: Vector2 = UserInputS:GetMouseLocation()
	local ray: Ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	local raycastParams: RaycastParams = raycastParams or RaycastParams.new()
	local raycastResult: RaycastResult? = workspace:Raycast(ray.Origin, ray.Direction * RAYCAST_DISTANCE, raycastParams)

	return raycastResult
end

return General
