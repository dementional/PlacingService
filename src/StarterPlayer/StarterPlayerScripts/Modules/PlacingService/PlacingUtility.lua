local RepS = game:GetService("ReplicatedStorage")

local modules = script:FindFirstAncestor("Modules")
local shared = RepS.Shared
local events = RepS.Events

local Utility = require(shared.Utility)

local function ModifyDescendants(instance: Instance)
	instance:AddTag("Preview")
	
	for _, descendant: Instance in instance:GetDescendants() do
		descendant:AddTag("Preview")
		
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "DoNotCollideWithPlayers"
			descendant.Anchored = true
		elseif descendant:IsA("ProximityPrompt") then
			descendant.Enabled = false end
	end
end

return {
	SnapToGrid = function(number: number, unit: number, axisSize: number): number
		local sizeInUnits: number = math.round(axisSize / unit)
		
		return if sizeInUnits % 2 ~= 0 then math.floor(number / unit) * unit + 0.5 * unit
			else math.floor(number / unit + 0.5) * unit
	end,

	ModifyPreview = function(instance: Instance)
		if instance:IsA("Model") then ModifyDescendants(instance)
		elseif instance:IsA("BasePart") then
			instance.CollisionGroup = "DoNotCollideWithPlayers"
			instance.Anchored = true

			ModifyDescendants(instance)
		end
	end
}