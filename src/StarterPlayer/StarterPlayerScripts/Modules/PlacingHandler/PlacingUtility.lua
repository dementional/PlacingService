local RepS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local cache = RepS:WaitForChild("Cache")
local events = RepS:WaitForChild("Events")

local Types = require(cache.Types)

local player = Players.LocalPlayer :: Player

local Settings = require(script.Parent.Settings)

local function ModifyDescendants(object: Types.Object)
	for _, descendant: Instance in object:GetDescendants() do
		if not (not descendant:HasTag("_NoReset")) then continue end
		
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false; descendant.CanTouch = false; descendant.CanQuery = false
		elseif descendant:IsA("ProximityPrompt") then descendant.Enabled = false end
		-- Add more if needed
	end
end

local function Snap(number: number, unit: number): number
	return math.floor(number / unit + 0.5) * unit
end

return {
	CheckPlacementValidity = function(object: Types.Object): boolean
		if not object then return false end

		local overlappingParts: {BasePart} = {}
		local overlapParams: OverlapParams = OverlapParams.new()
		overlapParams.FilterType = Enum.RaycastFilterType.Include
		overlapParams.FilterDescendantsInstances = Settings.ValidObjects
		
		local primaryPart: BasePart = object:IsA("Model") and object.PrimaryPart or (object :: BasePart)

		overlappingParts = workspace:GetPartsInPart(primaryPart, overlapParams)

		for _, part: BasePart in overlappingParts do
			if not (part:IsDescendantOf(object) and part.CanQuery) then return false end end

		return true
	end,
	
	SnapToGrid = function(pos: Vector3, unit: number, normal: Vector3): Vector3
		local up: Vector3 = normal.Unit
		local right: Vector3 = (math.abs(up:Dot(Vector3.yAxis)) > 0.99) and Vector3.xAxis or up:Cross(Vector3.yAxis).Unit
		local forward: Vector3 = up:Cross(right).Unit

		local origin: Vector3 = Vector3.zero
		local surfaceCF: CFrame = CFrame.fromMatrix(origin, right, up, forward)

		local localPos: Vector3 = surfaceCF:PointToObjectSpace(pos)
		local localSnappedPos: Vector3 = Vector3.new(
			Snap(localPos.X, unit),
			localPos.Y,
			Snap(localPos.Z, unit)
		)

		return surfaceCF:PointToWorldSpace(localSnappedPos)
	end,
	
	ModifyPreview = function(object: Types.Object)
		if object:IsA("Model") then ModifyDescendants(object)
		elseif object:IsA("BasePart") then
			object.Anchored = true
			object.CanCollide = false; object.CanTouch = false; object.CanQuery = false
			
			ModifyDescendants(object)
		end
	end
}