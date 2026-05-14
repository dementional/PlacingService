local UserInputS = game:GetService("UserInputService")
local RepS = game:GetService("ReplicatedStorage")
local RunS = game:GetService("RunService")
local Players = game:GetService("Players")

local cache = RepS:WaitForChild("Cache")
local events = RepS:WaitForChild("Events")

local Types = require(cache.Types)

local PlacingUtility = require(script.PlacingUtility)
local Settings = require(script.Settings)

local player = Players.LocalPlayer :: Player
local camera = workspace.CurrentCamera :: Camera

local connections: {RBXScriptConnection} = {}

local PlacingHandler: Types.PlacingHandler = {
	Preview = nil,

	IsModel = false,
	IsPlacing = false,
	CanPlace = false,

	CurrentScale = 1,
	Rotations = {X = 0, Y = 0, Z = 0},
	
	InitiatePreview = function(object: Types.Object) end,
	CancelPreview = function() end,
}

local function CastMouse(): RaycastResult?
	local mousePos: Vector2 = UserInputS:GetMouseLocation()
	local ray: Ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	local raycastParams: RaycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = Settings.ValidObjects

	return workspace:Raycast(ray.Origin, ray.Direction * 2048, raycastParams)
end

local canRotate: boolean = true
local function Rotate(axis: Vector3)
	if not canRotate then return end; canRotate = false
	task.delay(Settings.TimeBetweenRotations, function() canRotate = true end)
	
	local xAxis: number = axis.X
	local yAxis: number = axis.Y
	local zAxis: number = axis.Z
	
	PlacingHandler.Rotations.X += math.rad(xAxis * Settings.RotationUnit)
	PlacingHandler.Rotations.Y += math.rad(yAxis * Settings.RotationUnit)
	PlacingHandler.Rotations.Z += math.rad(zAxis * Settings.RotationUnit)
end

local canScale: boolean = true
local function Scale(number: number)
	if not canScale or (not PlacingHandler.IsModel) then return end; canScale = false
	task.delay(Settings.TimeBetweenScaling, function() canScale = true end)

	PlacingHandler.CurrentScale = math.clamp(PlacingHandler.CurrentScale + number, Settings.MinScale, Settings.MaxScale)
end

local function PreparePreview(object: Types.Object)
	PlacingHandler.Preview = object:Clone()
	assert(PlacingHandler.Preview ~= nil, `Object {object.Name or "nil"} is invalid`)
	
	if not Settings.CanOverlapWithOtherParts then Settings.PreviewSB.Adornee = PlacingHandler.Preview end
	
	PlacingHandler.IsModel = PlacingHandler.Preview:IsA("Model")
	PlacingUtility.ModifyPreview(PlacingHandler.Preview); PlacingHandler.Preview.Parent = Settings.LocationToPlacePreviews

	PlacingHandler.CurrentScale = PlacingHandler.IsModel and (PlacingHandler.Preview :: Model):GetScale() or 1
	PlacingHandler.Preview:PivotTo(RenderPreview(0, true) :: CFrame)
end

function RenderPreview(deltaTime: number, onlyPivot: boolean?): CFrame?
	local ray: RaycastResult? = CastMouse()
	if not (ray and ray.Position and ray.Normal) then return nil end
	if not PlacingHandler.Preview then return nil end

	local normal: Vector3 = ray.Normal
	local up: Vector3 = Vector3.new(0, 1, 0)
	local back: Vector3 = normal

	local dot: number = back:Dot(up)
	local axis: Vector3 = (math.abs(dot) > 0.99) and Vector3.new(-dot, 0, 0) or up

	local right: Vector3 = (math.abs(dot) > 0.99) and Vector3.new(1, 0, 0) or (up:Cross(back)).Unit
	local top: Vector3 = back:Cross(right).Unit

	local partSizeOffset: Vector3 = PlacingHandler.IsModel and (PlacingHandler.Preview :: Model):GetExtentsSize() or (PlacingHandler.Preview :: BasePart).Size
	local CF: CFrame = PlacingHandler.IsModel and (PlacingHandler.Preview :: Model):GetBoundingBox() or (PlacingHandler.Preview :: BasePart):GetPivot()

	local offset: Vector3 = normal * math.abs(CF:VectorToWorldSpace(partSizeOffset / 2):Dot(normal))
	local baseCF: CFrame = CFrame.fromMatrix(ray.Position + offset, top, back, right)

	local userRotation: CFrame = CFrame.Angles(PlacingHandler.Rotations.X, PlacingHandler.Rotations.Y, PlacingHandler.Rotations.Z)
	local finalCF: CFrame = baseCF * userRotation
	finalCF = CFrame.new(PlacingUtility.SnapToGrid(finalCF.Position, Settings.GridUnit, normal)) * (finalCF - finalCF.Position)
	
	if onlyPivot then return finalCF end
	
	PlacingHandler.Preview:PivotTo(PlacingHandler.Preview:GetPivot():Lerp(finalCF, deltaTime * Settings.LerpSpeed))
	if PlacingHandler.IsModel then (PlacingHandler.Preview :: Model):ScaleTo(PlacingHandler.CurrentScale) end

	-- While `R` is held down, rotate the `Preview`
	if UserInputS:IsKeyDown(Enum.KeyCode.R) then Rotate(Vector3.new(0, 1, 0)) end

	-- While `E` or `Q` is held down, scale up/down the `Preview`
	if UserInputS:IsKeyDown(Enum.KeyCode.E) then Scale(Settings.ScaleUnit)
	elseif UserInputS:IsKeyDown(Enum.KeyCode.Q) then Scale(-Settings.ScaleUnit) end
	
	if Settings.CanOverlapWithOtherParts then PlacingHandler.CanPlace = true; return nil end
	PlacingHandler.CanPlace = PlacingUtility.CheckPlacementValidity(PlacingHandler.Preview)
	
	if PlacingHandler.CanPlace then Settings.PreviewSB.OutlineColor, Settings.PreviewSB.FillColor = Settings.CanPlaceColor, Settings.CanPlaceColor
	else Settings.PreviewSB.OutlineColor, Settings.PreviewSB.FillColor = Settings.CannotPlaceColor, Settings.CannotPlaceColor end
	
	return nil
end

local function Place()
	if not PlacingHandler.CanPlace or not PlacingHandler.Preview then return end
	
	local objectInfo: Types.ObjectInfo = {
		Preview = PlacingHandler.Preview.Name,
		CF = PlacingHandler.Preview:GetPivot(),
		Scale = PlacingHandler.CurrentScale,

		Location = Settings.LocationToPlaceObjects
	}

	events.Remotes.PlaceObject:FireServer(objectInfo)
	PlacingHandler.CancelPreview()
end

--[=[
	@param object Object -- The object to preview
	Starts a preview of the given `Object` argument

	```lua
		local part = Instance.new("Part", workspace)
		
		PlacingHandler.InitiatePreview(part)
	```
]=]
function PlacingHandler.InitiatePreview(object: Types.Object)
	if PlacingHandler.Preview then PlacingHandler.CancelPreview() end
	
	PreparePreview(object); PlacingHandler.IsPlacing = true
	RunS:BindToRenderStep("RenderPreview", Enum.RenderPriority.Camera.Value + 1, RenderPreview)

	-- Binding keybinds and buttons
	local connection: RBXScriptConnection = UserInputS.InputBegan:Connect(function(inputObject: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then return end

		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then Place() 
		elseif inputObject.KeyCode == Enum.KeyCode.X then PlacingHandler.CancelPreview() end
	end)
	
	table.insert(connections, connection)

	-- Mobile handling
	local lastTapTime: number = 0
	connection = UserInputS.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then return end

		if input.UserInputType == Enum.UserInputType.Touch then
			local currentTime: number = os.clock()

			if currentTime - lastTapTime <= 0.5 then Place() end; lastTapTime = currentTime
		end
	end)
	
	table.insert(connections, connection)
end

--[=[
	Stops the current `Preview`

	```lua
		local part = Instance.new("Part", workspace)
		
		PlacingHandler.InitiatePreview(part)
		task.wait(3)
		PlacingHandler.CancelPreview()
	```
]=]
function PlacingHandler.CancelPreview()
	if not PlacingHandler.Preview then return end
	for _, connection: RBXScriptConnection in connections do connection:Disconnect() end; table.clear(connections)

	RunS:UnbindFromRenderStep("RenderPreview"); PlacingHandler.IsPlacing = false
	
	PlacingHandler.Rotations.X, PlacingHandler.Rotations.Y, PlacingHandler.Rotations.Z = 0, 0, 0
	PlacingHandler.IsModel = false; PlacingHandler.CurrentScale = 1
	
	if not Settings.CanOverlapWithOtherParts then Settings.PreviewSB.Adornee = nil end

	PlacingHandler.Preview:Destroy(); PlacingHandler.Preview = nil
end

UserInputS:GetPropertyChangedSignal("PreferredInput"):Connect(function()
	Settings.PreferredInput = UserInputS.PreferredInput end)

return PlacingHandler