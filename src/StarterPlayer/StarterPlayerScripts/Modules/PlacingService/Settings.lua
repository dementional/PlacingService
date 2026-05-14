local UserInputS = game:GetService("UserInputService")
local RepS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local cache = RepS:WaitForChild("Cache")
local events = RepS:WaitForChild("Events")

local player = Players.LocalPlayer :: Player
local coreGui = player.PlayerGui:WaitForChild("CoreGui")

local Types = require(cache.Types)

local guiCache = coreGui.Cache

local Settings: Types.Settings =  {
	CanOverlapWithOtherParts = false,
	PreviewSB = guiCache.PreviewSB,
	
	CanPlaceColor = Color3.fromRGB(255, 255, 255),
	CannotPlaceColor = Color3.fromRGB(255, 165, 0),
	
	-- Units used to determine placement
	GridUnit = 0.5,
	ScaleUnit = 0.05,
	RotationUnit = 15,
	
	-- Speed of the lerp (transition between CFrames)
	LerpSpeed = 25,

	TimeBetweenRotations = 0.1,
	TimeBetweenScaling = 0.15,
	
	MaxScale = 1.5,
	MinScale = 0.5,
	
	LocationToPlacePreviews = workspace.Temp,
	LocationToPlaceObjects = workspace.Objects,
	ValidObjects = {workspace.Objects, workspace.Other},
	
	-- The preffered input of the device the player is on (Mobile, PC, Console)
	PreferredInput = UserInputS.PreferredInput
}

return Settings