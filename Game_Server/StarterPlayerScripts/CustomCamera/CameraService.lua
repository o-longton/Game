local cameraService = {
	TargetAngles = Vector3.new(0, 0, 0);
	TargetPosition = Vector3.new(0, 0, 0)
}

-- services
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local contextActionService = game:GetService("ContextActionService")
local charLoader = require(script.Parent:WaitForChild("CharacterLoader"))
local physicsService = game:GetService("PhysicsService")
local tweenService = game:GetService("TweenService")
local gameConfig = require(game.ReplicatedStorage.Modules.GameConfig)

local springService = require(game.ReplicatedStorage.Modules.SpringService)
local springConfig = springService.NewSpringConfig(0.875, 11.5)
local posSpringConfig = springService.NewSpringConfig(1, 20)

local cameraAnglesSpring = springConfig:NewSpring(3)
cameraService.AnglesSpring = cameraAnglesSpring

local cameraPosSpring = posSpringConfig:NewSpring(3)
cameraService.PosSpring = cameraPosSpring

local heightSpring = springConfig:NewSpring(1)
cameraService.HeightSpring = heightSpring

local cameraSwaySpring = springConfig:NewSpring(3, "Sway")
cameraService.SwaySpring = cameraSwaySpring
cameraSwaySpring.Multiplier = Vector3.new(0.025, 0.01, 0)
cameraSwaySpring.XPeriod = 2
cameraSwaySpring.YPeriod = 4

-- variables
local playerCamera = game.Workspace.CurrentCamera
local cameraInputBindName = "CameraInput"
local cameraConnections = {}
local autoSetConnections = {}
local reactToDeltaSensitivity = 1.5
local maxPitchAngle = gameConfig.CameraSettings.MaxPitchAngle
local maxRollAngle = math.rad(10)

local mouseIconGui = script:WaitForChild("mouseIconGui")
mouseIconGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

local defaultFOV = 70
local walkingFOV = 80
local FOVTweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0)

local lastHeadHeight = 0
local heightDeltaScaleFactor = 0.8
local maximumHeightYawAngle = math.rad(10)
local Pi = math.pi
local Pix2 = math.pi * 2

local charUpdateEvent = game.ReplicatedStorage.RemoteEvents.CharRemotes:WaitForChild(game.Players.LocalPlayer.UserId)
local charUpdateInterval = 0.25
local lastCharUpdate = 0

local R15_HEAD_OFFSET = Vector3.new(0, 1.5, 0)
local HUMANOID_ROOT_PART_SIZE = Vector3.new(2, 2, 1)
local R15_HEAD_OFFSET_NO_SCALING = Vector3.new(0, 2, 0)
local HEAD_OFFSET = Vector3.new(0, 1.5, 0)

-- -- angle set-up
local screenCenter = playerCamera:WorldToScreenPoint(playerCamera.CFrame.Position + playerCamera.CFrame.LookVector)
local anglePerPixel = math.acos((playerCamera:ScreenPointToRay(screenCenter.X + 1, screenCenter.Y).Direction):Dot(playerCamera.CFrame.LookVector))

-- local functions 
local function BindCameraInput(isBinding)
	if isBinding == true then
		contextActionService:BindAction(
			cameraInputBindName,
			function(actionName, inputState, inputObj)
				local scaledDelta = inputObj.Delta * reactToDeltaSensitivity
				local anglesToAdd = Vector3.new(scaledDelta.Y, scaledDelta.X, 0) * -anglePerPixel 
				local newAngles = cameraService.TargetAngles + anglesToAdd

				-- calculate the roll angle
				local newRollAngle = 0
				if math.abs(scaledDelta.X) > 1 then
					newRollAngle = math.clamp(scaledDelta.X * anglePerPixel, -maxRollAngle, maxRollAngle)
				end

				cameraService.SetTargetAngles(Vector3.new(math.clamp(newAngles.X, -maxPitchAngle, maxPitchAngle), newAngles.Y, newRollAngle))
			end,
			false,
			Enum.UserInputType.MouseMovement, Enum.UserInputType.Touch
		)

	else
		contextActionService:UnbindAction(cameraInputBindName)
	end
end

-- global functions
------------------------------------
function cameraService.SetUp()
	-- make sure the character has loaded and clone the character 
	local playerChar = charLoader.LoadCharacter()
end

function cameraService.GetCameraOffset()
	local playerChar = charLoader.LoadCharacter()
	local humanoid = playerChar.Humanoid
	local rootPart = playerChar.HumanoidRootPart
	local heightOffset 
	
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		if humanoid.AutomaticScalingEnabled then
			heightOffset = R15_HEAD_OFFSET

			local rootPartSizeOffset = (rootPart.Size.Y - HUMANOID_ROOT_PART_SIZE.Y)/2
			heightOffset = heightOffset + Vector3.new(0, rootPartSizeOffset, 0)
			
		else
			heightOffset = R15_HEAD_OFFSET_NO_SCALING
		end
		
	else
		heightOffset = HEAD_OFFSET
	end
	return heightOffset
end

function cameraService.ResetSprings(hardReset)
	cameraSwaySpring.Multiplier = Vector3.new(0.025, 0.01, 0)
	cameraSwaySpring.XPeriod = 2
	cameraSwaySpring.YPeriod = 4
	
	if hardReset == true then
		cameraAnglesSpring.Velocity = Vector3.new(0, 0, 0)
		cameraPosSpring.Velocity = Vector3.new(0, 0, 0)

		heightSpring.Position = 0
		heightSpring.Velocity = 0
		heightSpring.TargetPosition = 0

	else
		heightSpring.TargetPosition = 0
	end
end

function cameraService.ToggleMouseIcon(enabled)
	if enabled == true then
		userInputService.MouseIconEnabled = false
		mouseIconGui.mouseIcon.GroupTransparency = 1
		mouseIconGui.Enabled = true
		tweenService:Create(mouseIconGui.mouseIcon, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0), {GroupTransparency = 0}):Play()

	else
		tweenService:Create(mouseIconGui.mouseIcon, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0), {GroupTransparency = 1}):Play()
	end
end

------------------------------------
function cameraService.EnableAutoSet(hardSet)
	cameraService.SetTargetAngles(Vector3.new(playerCamera.CFrame:ToOrientation()))
	cameraAnglesSpring.TargetPosition = cameraService.TargetAngles
	cameraService.TargetPosition = playerCamera.CFrame.Position
	cameraPosSpring.TargetPosition = cameraService.TargetPosition

	local playerChar = charLoader.LoadCharacter()
	charLoader.SetCharTransparency(1)
	local humanoid = playerChar.Humanoid
	local humanoidRootPart = playerChar.HumanoidRootPart
	local head = playerChar.Head
	lastHeadHeight = humanoidRootPart.Position.Y -- NOTE THIS IS ROOT PART NOT HEAD (VARIABLE NOT CHANGED)

	if hardSet == true then
		cameraAnglesSpring.Velocity = Vector3.new(0, 0, 0)
		cameraService.TargetAngles = Vector3.new(humanoidRootPart.CFrame:ToOrientation())
		cameraAnglesSpring.Position = cameraService.TargetAngles
		cameraAnglesSpring.TargetPosition = cameraService.TargetAngles

		cameraPosSpring.Velocity = Vector3.new(0, 0, 0)
		cameraService.TargetPosition = humanoidRootPart.Position + cameraService.GetCameraOffset()
		cameraPosSpring.Position = cameraService.TargetPosition
		cameraPosSpring.TargetPosition = cameraService.TargetPosition
	end
	cameraService.ToggleMouseIcon(true)

	-- enable the camera
	local wasLastMoveDirZero = true
	local mainLoopConnection
	mainLoopConnection = runService.RenderStepped:Connect(function(deltaTime)
		userInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

		-- check if the player is walking or not 
		if humanoid.MoveDirection == Vector3.new(0, 0, 0) then
			cameraSwaySpring.Multiplier = Vector3.new(0.025, 0.01, 0)
			cameraSwaySpring.XPeriod = 2
			cameraSwaySpring.YPeriod = 4

			-- tween the fov if needed 
			if wasLastMoveDirZero == false then
				wasLastMoveDirZero = true

				-- play the fov tween
				tweenService:Create(playerCamera, FOVTweenInfo, {FieldOfView = defaultFOV}):Play()
			end

		else
			cameraSwaySpring.Multiplier = Vector3.new(0.025, 0.03, 0)
			cameraSwaySpring.XPeriod = 1
			cameraSwaySpring.YPeriod = 2

			-- tween the fov if needed 
			if wasLastMoveDirZero == true then
				wasLastMoveDirZero = false

				-- play the fov tween
				tweenService:Create(playerCamera, FOVTweenInfo, {FieldOfView = walkingFOV}):Play()
			end
		end

		-- update the height spring
		local headHeightDelta = humanoidRootPart.Position.Y - lastHeadHeight
		lastHeadHeight = humanoidRootPart.Position.Y
		local jumpYawAngle = math.clamp(headHeightDelta * heightDeltaScaleFactor, -maximumHeightYawAngle, maximumHeightYawAngle)
		heightSpring.TargetPosition = jumpYawAngle

		-- update pos spring
		cameraService.TargetPosition = humanoidRootPart.Position + cameraService.GetCameraOffset()
		
		-- update the character 
		if os.clock() - lastCharUpdate >= charUpdateInterval then
			lastCharUpdate = os.clock()
			charUpdateEvent:FireServer(cameraService.TargetAngles.X, cameraService.TargetAngles.Y)
		end
	end)
	table.insert(autoSetConnections, mainLoopConnection)
	BindCameraInput(true)
end

function cameraService.DisableAutoSet()
	-- disable all connections
	BindCameraInput(false)
	for index, connection in pairs(autoSetConnections) do
		connection:Disconnect()
		autoSetConnections[index] = nil
	end

	-- reset the springs
	cameraService.ResetSprings()

	-- remove the mouse icon 
	cameraService.ToggleMouseIcon(false)
end

function cameraService.SetTargetAngles(angles)
	local delta = angles - cameraService.TargetAngles
	cameraService.TargetAngles = angles - Vector3.new(math.round(delta.X / (2*Pi)), math.round(delta.Y / (2*Pi)), math.round(delta.Z / (2*Pi))) * 2*Pi
end

------------------------------------
function cameraService.Enable()
	cameraService.TargetAngles = Vector3.new(playerCamera.CFrame:ToOrientation())
	cameraAnglesSpring.Position = cameraService.TargetAngles
	cameraAnglesSpring.Velocity = Vector3.new(0, 0, 0)

	heightSpring.Position = 0
	heightSpring.Velocity = 0
	heightSpring.TargetPosition = 0

	local playerChar = charLoader.LoadCharacter()
	charLoader.SetCharTransparency(1)
	local humanoid = playerChar.Humanoid
	local humanoidRootPart = playerChar.HumanoidRootPart
	local head = playerChar.Head
	
	cameraService.ToggleMouseIcon(false)

	-- enable the camera
	playerCamera.CameraType = Enum.CameraType.Scriptable
	local mainLoopConnection
	mainLoopConnection = runService.RenderStepped:Connect(function(deltaTime)

		-- update the parms
		springConfig:UpdateParams(deltaTime)
		posSpringConfig:UpdateParams(deltaTime)

		-- update all springs
		cameraAnglesSpring.TargetPosition = cameraService.TargetAngles
		cameraPosSpring.TargetPosition = cameraService.TargetPosition
		cameraPosSpring:UpdateSpring(deltaTime)
		cameraAnglesSpring:UpdateSpring(deltaTime)
		cameraSwaySpring:UpdateSpring(deltaTime)
		heightSpring:UpdateSpring(deltaTime)

		-- set the new camera cframe
		local cameraAnglesCFrame = CFrame.fromOrientation(cameraAnglesSpring.Position.X + cameraSwaySpring.Position.X + heightSpring.Position, cameraAnglesSpring.Position.Y + cameraSwaySpring.Position.Y, cameraAnglesSpring.Position.Z)
		playerCamera.CFrame = CFrame.new(cameraPosSpring.Position + (cameraSwaySpring.Position.Y * cameraAnglesCFrame.UpVector) + (cameraSwaySpring.Position.X * cameraAnglesCFrame.RightVector)) * cameraAnglesCFrame
		playerCamera.Focus = CFrame.lookAt(playerCamera.CFrame.Position + playerCamera.CFrame.LookVector, playerCamera.CFrame.Position + 2*playerCamera.CFrame.LookVector)
	end)
	table.insert(cameraConnections, mainLoopConnection)
end

function cameraService.Disable()
	playerCamera.CameraType = Enum.CameraType.Custom
	userInputService.MouseIconEnabled = true
	mouseIconGui.Enabled = false
	charLoader.SetCharTransparency(0)

	-- play the fov tween incase of walking 
	tweenService:Create(playerCamera, FOVTweenInfo, {FieldOfView = defaultFOV}):Play()

	-- disable the camera
	userInputService.MouseBehavior = Enum.MouseBehavior.Default
	BindCameraInput(false)
	for index, connection in pairs(cameraConnections) do
		connection:Disconnect()
		cameraConnections[index] = nil
	end
	for index, connection in pairs(autoSetConnections) do
		connection:Disconnect()
		autoSetConnections[index] = nil
	end

	-- reset springs
	cameraService.ResetSprings(true)

	-- remove the mouse icon 
	cameraService.ToggleMouseIcon(false)
end

return cameraService

