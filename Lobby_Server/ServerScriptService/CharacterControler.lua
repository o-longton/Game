local CharacterControler = {
	PlayerProfiles = {}
}

-- services
local RunService = game:GetService("RunService")
local GameConfig = require(game.ReplicatedStorage.Modules.GameConfig)
local SpringService = require(game.ReplicatedStorage.Modules.SpringService)
local SpringConfig = SpringService.NewSpringConfig(1, 10)

-- variables
local CharRemotesFolder = game.ReplicatedStorage.RemoteEvents.CharRemotes

-- global functions 
function CharacterControler.PlayerAdded(player)
	local profile = {}
	profile.AnglesSpring = SpringConfig:NewSpring(2)
	
	profile.UpdateAnglesEvent = Instance.new("RemoteEvent")
	profile.UpdateAnglesEvent.Name = player.UserId
	profile.UpdateAnglesEvent.Parent = CharRemotesFolder
	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Responsiveness = 20
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	profile.AlignOrientation = alignOrientation
	
	profile.UpdateAnglesEvent.OnServerEvent:Connect(function(plr, angleX, angleY)
		if plr ~= player then
			-- impossible so kick the player
			plr:Kick()
			return 
		end 
		
		-- update the angles
		profile.AnglesSpring.TargetPosition = Vector2.new(math.clamp(angleX, -GameConfig.CameraSettings.MaxPitchAngle, GameConfig.CameraSettings.MaxPitchAngle), angleY)
	end)
	
	do -- load the character
		local playerChar = player.Character or player.CharacterAdded:Wait()
		local humanoid = playerChar:WaitForChild("Humanoid")
		humanoid.AutoRotate = false
		playerChar:WaitForChild("Head"):WaitForChild("Neck")
		playerChar:WaitForChild("UpperTorso"):WaitForChild("Waist")
		playerChar:WaitForChild("LowerTorso"):WaitForChild("Root")
	end 
	player.CharacterAdded:Connect(function()
		local humanoid = player.Character:WaitForChild("Humanoid")
		humanoid.AutoRotate = false
	end)
	
	local alignAttachment = Instance.new("Attachment", player.Character.HumanoidRootPart)
	alignAttachment.Name = "AlignAttachment"
	alignOrientation.Parent = alignAttachment
	alignOrientation.Attachment0 = alignAttachment
	profile.UpdateConnection = RunService.Stepped:Connect(function(_, deltaTime)
		profile.AnglesSpring:UpdateSpring(deltaTime)
		
		-- get the motors
		local playerChar = player.Character
		if playerChar == nil then return end 
		local neck = playerChar.Head.Neck
		local waist = playerChar.UpperTorso.Waist
		local rootPart = playerChar.HumanoidRootPart
		
		-- update the player char
		alignOrientation.CFrame = CFrame.fromOrientation(0, profile.AnglesSpring.Position.Y, 0)
		waist.C0 = CFrame.new(waist.C0.Position) * CFrame.fromOrientation(profile.AnglesSpring.Position.X / 2, 0, 0)
		neck.C1 = CFrame.new(neck.C1.Position) * CFrame.fromOrientation(-profile.AnglesSpring.Position.X / 2, 0, 0)
	end)
	CharacterControler.PlayerProfiles[player] = profile
end

function CharacterControler.PlayerRemoving(player)
	local profile = CharacterControler.PlayerProfiles[player]
	if profile == nil then return end 
	
	-- remove the profile
	profile.UpdateConnection:Disconnect()
	profile.UpdateAnglesEvent:Destroy()
	profile.AlignOrientation:Destroy()
	CharacterControler.PlayerProfiles[player] = nil
end

-- connections 
RunService.Stepped:Connect(function(_, deltaTime)
	SpringConfig:UpdateParams(deltaTime)
end)

return CharacterControler
