local RepS = game:GetService("ReplicatedStorage")

local shared = RepS.Shared
local events = RepS.Events

local Validation = require(shared.Modules.Validation)

events.Remotes.Place.OnServerEvent:Connect(function(player: Player, arguments: {[string]: any})
	local objectName: string = arguments.ObjectName
	local CF: CFrame = arguments.CF
	
	assert(typeof(objectName) == "string", `"ObjectName" was not specified`)
	assert(typeof(CF) == "CFrame", `"CF" was not specified`)
	
	local object: Instance? = shared.Assets:FindFirstChild(objectName)
	assert(object, `{objectName} couldn't not found in {shared.Assets}`)

	local newObject: Instance = object:Clone()
	newObject:PivotTo(CF)
	
	local hasValidPlacement: boolean = Validation.HasValidPlacement(object)
	if not hasValidPlacement then
		newObject:Destroy()
		error(`{objectName} has invalid placement`)
		
		return
	end
	
	newObject.Parent = workspace.Objects
end)