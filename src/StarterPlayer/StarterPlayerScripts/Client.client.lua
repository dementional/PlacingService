local UserInputS = game:GetService("UserInputService")
local RepS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local modules = script.Parent.Modules
local shared = RepS.Shared
local events = RepS.Events

local libraries = RepS.Libraries

local Settings = require(shared.Settings)

local Trove = require(libraries.Trove)
local LemonSignal = require(libraries.LemonSignal)

local PlacingService = require(modules.PlacingService)

local player: Player = Players.LocalPlayer
local coreGui: ScreenGui = player.PlayerGui:WaitForChild("CoreGui")

local guiVisual: Folder = coreGui.Visual

local objects: Frame = coreGui.Objects
local template: TextButton = objects.Template

local previewHighlight: Highlight = guiVisual.PreviewHighlight

local canPlaceColor: Color3 = Settings.CanPlaceColor
local cannotPlaceColor: Color3 = Settings.CannotPlaceColor

local previewTrove: Trove = Trove.new()
local renderedEvent: Signal<Instance, number, boolean> = PlacingService.Rendered

type Trove = Trove.Trove
type Signal<T...> = LemonSignal.Signal<T...>

template.Parent = nil

for _, object: Instance in shared.Assets:GetChildren() do
	assert(
		object:IsA("BasePart") or object:IsA("Model"),
		`{object} is not a valid object`
	)
	
	local newButton: TextButton = template:Clone()
	newButton.Name = object.Name
	newButton.Text = object.Name
	newButton.Parent = objects
	
	newButton.MouseButton1Click:Connect(function()
		previewTrove:Clean()
		
		PlacingService.SetPreview(object)
		previewTrove:Connect(renderedEvent, function(preview: Model, _, canPlace: boolean)
			previewHighlight.Adornee = preview

			if canPlace then previewHighlight.OutlineColor, previewHighlight.FillColor = canPlaceColor, canPlaceColor
			else previewHighlight.OutlineColor, previewHighlight.FillColor = cannotPlaceColor, cannotPlaceColor end
		end)

		previewTrove:Connect(UserInputS.InputBegan, function(inputObject: InputObject, gameProcessedEvent: boolean)
			if gameProcessedEvent then return end

			local rotateY: Enum.KeyCode = Settings.RotateY
			local cancel: Enum.KeyCode = Settings.Cancel

			if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then 
				local preview: Instance? = PlacingService.GetPreview()
				if not preview then return end

				local CF: CFrame = PlacingService._CF
				local canPlace: boolean = PlacingService.CanPlace
				
				if not canPlace then return end

				local objectName: string = object.Name

				preview:PivotTo(CF)
				events.Remotes.Place:FireServer({
					ObjectName = objectName,
					CF = CF
				})
				
				if UserInputS:IsKeyDown(Enum.KeyCode.LeftControl) then return end
				
				previewTrove:Clean()
				PlacingService.Cancel()
				
				previewHighlight.Adornee = nil
			elseif inputObject.KeyCode == rotateY then PlacingService.Rotate(Vector3.yAxis)
			elseif inputObject.KeyCode == cancel then
				previewTrove:Clean()
				PlacingService.Cancel()

				previewHighlight.Adornee = nil
			end
		end)
	end)
end

do
	local function OnCharacterAdded(char: Model)
		for _, child: Instance in char:GetChildren() do
			if not child:IsA("BasePart") then continue end
			
			child.CollisionGroup = "Player"
		end
	end
	
	player.CharacterAdded:Connect(OnCharacterAdded)
	
	local char: Model? = player.Character
	if char then OnCharacterAdded(char) end
end