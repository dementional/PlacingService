local RepS = game:GetService("ReplicatedStorage")

local cache = RepS.Cache
local events = RepS.Events

local Types = require(cache.Types)

events.Remotes.PlaceObject.OnServerEvent:Connect(function(player: Player, objectInfo: Types.ObjectInfo)
	local preview: string = objectInfo.Preview; assert(typeof(preview) == "string", `"Preview" was not specified`)
	local CF: CFrame = objectInfo.CF; assert(typeof(CF) == "CFrame", `"CFrame" was not specified`)
	local scale: number = objectInfo.Scale or 1

	local location: Instance = objectInfo.Location; assert(typeof(location) == "Instance", `"Location" was not specified`)

	local newObject: Types.ObjectInfo = cache.Objects:FindFirstChild(preview); assert(newObject, `{preview} couldn't be found in {cache.Objects}`)
	newObject = newObject:Clone(); newObject.Parent = location

	if newObject:IsA("Model") then newObject:ScaleTo(scale) end
	newObject:PivotTo(CF); newObject:SetAttribute("Ownership", player.Name)
end)