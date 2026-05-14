local RepS = game:GetService("ReplicatedStorage")

local shared = RepS.Shared
local events = RepS.Events

local libraries = RepS.Libraries

local Settings = require(shared.Settings)

local ParamsBuilder = require(libraries.ParamsBuilder)

type Params = ParamsBuilder.Params

local Validation = {}

local function Snap(number: number, unit: number): number
	return math.floor(number / unit + 0.5) * unit
end

function Validation.HasValidPlacement(toCheck: any): boolean
	if not toCheck then return end
	
	local overlapParams: OverlapParams = OverlapParams.new()
	local params: Params = ParamsBuilder.new(overlapParams)

	local function HasValidPlacement(basePart: BasePart, parent: Instance?): boolean
		local CF: CFrame = basePart.CFrame
		local size: Vector3 = basePart.Size

		if not basePart.CanQuery then return true end
		if Settings.CanOverlapWithOtherParts then return true end
		
		local sizeHalf: Vector3 = size / 2
		local corners: { Vector3 } = {
			Vector3.new(sizeHalf.X, sizeHalf.Y, sizeHalf.Z),
			Vector3.new(-sizeHalf.X, sizeHalf.Y, sizeHalf.Z),  
			Vector3.new(sizeHalf.X, -sizeHalf.Y, sizeHalf.Z),
			Vector3.new(sizeHalf.X, sizeHalf.Y, -sizeHalf.Z),
			Vector3.new(-sizeHalf.X, -sizeHalf.Y, sizeHalf.Z),
			Vector3.new(sizeHalf.X, -sizeHalf.Y, -sizeHalf.Z),
			Vector3.new(-sizeHalf.X, sizeHalf.Y, -sizeHalf.Z),
			Vector3.new(-sizeHalf.X, -sizeHalf.Y, -sizeHalf.Z),
		}
		
		local intersectingParts: { BasePart } = workspace:GetPartsInPart(basePart, overlapParams)
		for _, intersectingPart: BasePart in intersectingParts do
			if (
				parent and
				intersectingPart:IsDescendantOf(parent)
				)
			then
				continue end
			
			local ignoreCollision: boolean = intersectingPart:HasTag("Object_IgnoreCollision")
			if ignoreCollision then continue end

			return false
		end

		return true
	end

	params.CollisionGroup = ""
	params:Include(workspace.Objects)
	params:Include(workspace.Other)

	if typeof(toCheck) == "table" then 
		for _, instance: Instance in toCheck do 
			if not instance:IsA("BasePart") then continue end

			local hasValidPlacement: boolean = HasValidPlacement(instance)
			if hasValidPlacement then continue end

			return false
		end
	elseif toCheck:IsA("BasePart") then
		local hasValidPlacement: boolean = HasValidPlacement(toCheck)
		return hasValidPlacement
	elseif toCheck:IsA("Model") then 
		for _, descendant: BasePart in toCheck:GetDescendants() do 
			if not descendant:IsA("BasePart") then continue end
			
			local hasValidPlacement: boolean = HasValidPlacement(descendant, toCheck)
			if hasValidPlacement then continue end

			return false
		end 
	end

	return true
end

return Validation