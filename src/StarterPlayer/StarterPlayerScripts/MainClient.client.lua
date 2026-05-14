local RepS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local modules = script.Parent.Modules
local cache = RepS:WaitForChild("Cache")
local events = RepS:WaitForChild("Events")

local Types = require(cache.Types)

local PlacingHandler = require(modules.PlacingHandler)

local player = Players.LocalPlayer :: Player
local coreGui = player.PlayerGui:WaitForChild("CoreGui")

for _, button: GuiButton in coreGui.Objects:GetChildren() do
	if not button:IsA("GuiButton") then continue end
	
	button.MouseButton1Click:Connect(function()
		local object: Instance? = cache.Objects:FindFirstChild(button.Name)
		assert(object ~= nil and (object:IsA("BasePart") or object:IsA("Model")), `Object {button.Name} not found or invalid`)
		
		PlacingHandler.InitiatePreview(object)
	end)
end