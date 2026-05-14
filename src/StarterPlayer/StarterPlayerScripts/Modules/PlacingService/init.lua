local UserInputS = game:GetService("UserInputService")
local CollectionS = game:GetService("CollectionService")
local RepS = game:GetService("ReplicatedStorage")
local RunS = game:GetService("RunService")
local Players = game:GetService("Players")

local modules = script:FindFirstAncestor("Modules")
local shared = RepS.Shared
local events = RepS.Events

local libraries = RepS.Libraries

local Utility = require(shared.Utility)
local Settings = require(shared.Settings)

local Trove = require(libraries.Trove)
local LemonSignal = require(libraries.LemonSignal)
local ParamsBuilder = require(libraries.ParamsBuilder)

local player: Player = Players.LocalPlayer
local camera: Camera = workspace.CurrentCamera

local Validation = require(shared.Modules.Validation)

local PlacingUtility = require(script.PlacingUtility)
local ControlModule: { any } = require(player.PlayerScripts.PlayerModule)
ControlModule = ControlModule:GetControls()

local currentTrove: Trove = Trove.new()

local placementStartedEvent: Signal<> = LemonSignal.new()
local placementEndedEvent: Signal<> = LemonSignal.new()

local renderedEvent: Signal<Instance, number, boolean> = LemonSignal.new()

type Trove = Trove.Trove
type Signal<T...> = LemonSignal.Signal<T...>
type Params = ParamsBuilder.Params

local PlacingService = {
	Preview = nil,
	
	CanPlace = false,
	CanRender = true,
	
	GridUnit = nil,
	RaycastParams = nil,
	
	_RotationCF = CFrame.identity,
	
	PlacementStarted = placementStartedEvent,
	PlacementEnded = placementEndedEvent,
	
	Rendered = renderedEvent
}

function PlacingService.Rotate(axis: Vector3)
	local rotationUnit: number = Settings.RotationUnit

	PlacingService._RotationCF *= CFrame.fromAxisAngle(axis, math.rad(rotationUnit))
end

function PlacingService.GetTargetCF(): CFrame?
	local gridUnitOverride: number? = PlacingService.GridUnit
	local gridUnit: number = if gridUnitOverride then gridUnitOverride
		else Settings.GridUnit
	
	local raycastParams: RaycastParams = PlacingService.RaycastParams
	local raycastResult: RaycastResult? = Utility.General.GetMouseResult(raycastParams)
	
	if not (
		raycastResult
		and raycastResult.Instance
		)
	then
		return end

	local hitInstance: Instance = raycastResult.Instance
	local hitPos: Vector3 = raycastResult.Position
	
	local hitInstanceCF: CFrame = hitInstance:GetPivot()
	local hitInstancePos: Vector3 = hitInstanceCF.Position

	local normal: Vector3 = raycastResult.Normal

	local upVector: Vector3 = normal
	local rightVector: Vector3 = hitInstanceCF.RightVector
	local lookVector: Vector3

	if math.abs(upVector:Dot(rightVector)) > 0.999 then rightVector = hitInstanceCF.LookVector end

	rightVector = (rightVector - upVector * rightVector:Dot(upVector)).Unit
	lookVector = rightVector:Cross(upVector).Unit

	local preview: Instance? = PlacingService.GetPreview()
	if not preview then return end

	local _, previewSize: Vector3 = (function()
		if preview:IsA("Model") then
			local CF: CFrame, size: Vector3 = preview:GetBoundingBox()
			return CF, size
		else
			local CF: CFrame, size: Vector3 = preview:GetPivot(), preview.Size
			return CF, size
		end
	end)()

	local surfaceCF: CFrame = CFrame.fromMatrix(Vector3.zero, rightVector, upVector, lookVector)
	local rotationCF: CFrame = PlacingService._RotationCF
	
	local finalRotation: CFrame = surfaceCF * rotationCF

	local rotatedSize: Vector3 = rotationCF:VectorToWorldSpace(previewSize)
	local sizeX: number, sizeY: number, sizeZ: number = math.abs(rotatedSize.X), math.abs(rotatedSize.Y), math.abs(rotatedSize.Z)
	
	local relativePos: Vector3 = hitPos - hitInstanceCF.Position

	local height: number = relativePos:Dot(upVector)
	local tangentU: number = relativePos:Dot(rightVector)
	local tangentV: number = relativePos:Dot(lookVector)

	local snappedTangentU: number = PlacingUtility.SnapToGrid(tangentU, gridUnit, sizeX)
	local snappedTangentV: number = PlacingUtility.SnapToGrid(tangentV, gridUnit, sizeZ)

	local snappedPos: Vector3 = hitInstancePos + (upVector * height) + (rightVector * snappedTangentU) + (lookVector * snappedTangentV)
	local offsetDistance: number = (
		math.abs(finalRotation.RightVector:Dot(upVector)) * previewSize.X +
		math.abs(finalRotation.UpVector:Dot(upVector)) * previewSize.Y +
		math.abs(finalRotation.LookVector:Dot(upVector)) * previewSize.Z
	) / 2

	local finalPos: Vector3 = snappedPos + (upVector * offsetDistance)
	local finalCF: CFrame = CFrame.new(finalPos) * finalRotation
	
	return finalCF
end

function PlacingService.Render(deltaTime: number): CFrame?	
	local canRender: boolean = PlacingService.CanRender
	local preview: Instance? = PlacingService.GetPreview()
	
	if not (
		canRender
		and preview
		)
	then
		return end
	
	local CF: CFrame = PlacingService._CF
	local targetCF: CFrame? = PlacingService.GetTargetCF() or CF

	if not targetCF then return end
	
	local _, previewSize: Vector3 = (function()
		if preview:IsA("Model") then
			local CF: CFrame, size: Vector3 = preview:GetBoundingBox()
			return CF, size
		else
			local CF: CFrame, size: Vector3 = preview:GetPivot(), preview.Size
			return CF, size
		end
	end)()
	
	preview:PivotTo(targetCF)
	PlacingService._CF = targetCF

	local hasValidPlacement: boolean = Validation.HasValidPlacement(preview)
	PlacingService.CanPlace = hasValidPlacement
	
	local lerpSpeed: number = Settings.LerpSpeed
	local alpha: number = 1 - math.exp(-lerpSpeed * deltaTime)
	
	local visualCF: CFrame? = PlacingService._VisualCF
	if not visualCF then
		visualCF = targetCF
		
		PlacingService._VisualCF = visualCF
		PlacingService._PreviousVisualPos = visualCF.Position
	else
		visualCF = visualCF:Lerp(targetCF, alpha)
		PlacingService._VisualCF = visualCF
	end

	local visualPos: Vector3 = visualCF.Position
	local previousVisualPos: Vector3 = PlacingService._PreviousVisualPos
	
	local visualCF: CFrame = CFrame.new(visualPos) * targetCF.Rotation
	PlacingService._PreviousVisualPos = visualPos

	preview:PivotTo(visualCF)
	renderedEvent:Fire(preview, targetCF, hasValidPlacement)
end

function PlacingService.PreparePreview(instance: Instance)
	local newPreview: Instance = instance:Clone()

	PlacingService.Preview = newPreview
	PlacingUtility.ModifyPreview(newPreview)
	
	newPreview.Parent = workspace.Temp

	local targetCF: CFrame? = PlacingService.GetTargetCF()
	if not targetCF then return end

	newPreview:PivotTo(targetCF)
end

function PlacingService.GetPreview(): Instance?
	local preview: Instance? = PlacingService.Preview

	return preview
end

function PlacingService.SetPreview(instance: Instance)
	PlacingService.Cancel()
	PlacingService.RaycastParams = (function()
		local raycastParams: RaycastParams = RaycastParams.new()
		local params: Params = ParamsBuilder.new(raycastParams)
		
		params:Include(workspace.Objects)
		params:Include(workspace.Other)

		return raycastParams
	end)()
	
	PlacingService.PreparePreview(instance)

	currentTrove:Clean()
	currentTrove:BindToRenderStep("Render", Enum.RenderPriority.Camera.Value, PlacingService.Render)
	
	placementStartedEvent:Fire()
end

function PlacingService.Cancel()
	local preview: Instance? = PlacingService.GetPreview()
	if not preview then return end
	
	currentTrove:Clean()
	
	PlacingService.CanPlace = false
	
	PlacingService.GridUnit = nil
	PlacingService.RaycastParams = nil
	
	PlacingService._RotationCF = CFrame.identity
	
	PlacingService._VisualCF = nil
	PlacingService._CF = nil
	
	preview:Destroy()
	PlacingService.Preview = nil
	
	placementEndedEvent:Fire()
end

return PlacingService