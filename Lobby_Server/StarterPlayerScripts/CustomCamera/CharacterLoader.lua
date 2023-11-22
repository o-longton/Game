local characterLoader = {}
local RunService = game:GetService("RunService")

-- variables
local instancesToLoad = {
	"Head";
	"UpperTorso";
	"LowerTorso";
	"LeftUpperArm";
	"LeftLowerArm";
	"LeftHand";
	"RightUpperArm";
	"RightLowerArm";
	"RightHand";
	"LeftUpperLeg";
	"LeftLowerLeg";
	"LeftFoot";
	"RightUpperLeg";
	"RightLowerLeg";
	"RightFoot";
	"Humanoid";
	"HumanoidRootPart"
}
local transparencyBlacklist = {
	["HumanoidRootPart"] = true
}
local currentTransparencySetting = 0
local playerChar = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
local playerCharLoaded = false
local currentlyLoading = false

-- functions 
function characterLoader.LoadCharacter()
	if playerCharLoaded == true then return playerChar end 
	if currentlyLoading == true then
		local timeElasped = 0
		repeat
			timeElasped += RunService.Heartbeat:Wait()
		until timeElasped >= 10 or playerCharLoaded == true
		return playerChar
	end
	currentlyLoading = true
	local player = game.Players.LocalPlayer
	local playerChar = player.Character or player.CharacterAdded:Wait()
	
	-- load all of the needed parts 
	for _, instanceName in pairs(instancesToLoad) do
		playerChar:WaitForChild(instanceName)
	end
	
	-- set the offset
	characterLoader.CameraOffset = Vector3.new(0, playerChar.Head.CFrame.Position - playerChar.HumanoidRootPart.Position, 0)
	
	-- return the character 
	playerCharLoaded = true
	return playerChar
end

function characterLoader.SetCharTransparency(value, c)
	currentTransparencySetting = value
	local char = c == nil and playerChar or c
	
	-- set all the loaded instances to the set transparecy 
	for _, instance in pairs(char:GetDescendants()) do
		if (instance:IsA("BasePart") or instance:IsA("Decal")) and transparencyBlacklist[instance.Name] ~= true then
			task.wait()
			instance.Transparency = currentTransparencySetting
		end
	end
end

-- connections 
playerChar.DescendantAdded:Connect(function(instance)
	if instance:IsA("BasePart") == true and transparencyBlacklist[instance.Name] ~= true then
		instance.Transparency = currentTransparencySetting
	end
end)

return characterLoader
