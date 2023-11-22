local TerminalControler = {
	TerminalOpen = false,
	TerminalClosing = false,
	TerminalOpening = false,
	LoginFrameOpen = true,
	LoadingFrameOpen = false,
	IsTeleporting = false
}

-- services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CustomCamera = game.Players.LocalPlayer.PlayerScripts:WaitForChild("CustomCamera")
local CameraService = require(CustomCamera:WaitForChild("CameraService"))
CameraService.SetUp() -- char is also loaded
CameraService.Enable()
local UIEffects = require(game.Players.LocalPlayer.PlayerScripts.Modules:WaitForChild("UIEffects"))

-- variables
local PlayerChar = game.Players.LocalPlayer.Character
local LobbyAssets = game.Workspace:WaitForChild("LobbyAssets")
local TermianlPart = LobbyAssets:WaitForChild("TerminalPart")
local TerminalPrompt = Instance.new("ProximityPrompt", TermianlPart:WaitForChild("PromptAtt"))
TerminalPrompt.RequiresLineOfSight = true
TerminalPrompt.ClickablePrompt = UserInputService.TouchEnabled
TerminalPrompt.HoldDuration = 0.5
TerminalPrompt.ActionText = "Terminal"
TerminalPrompt.MaxActivationDistance = 4
TerminalPrompt.Enabled = false

local CharControls = require(game:GetService("Players").LocalPlayer.PlayerScripts.PlayerModule):GetControls()
local LastCameraPos = Vector3.new(0, 0, 0)
local LastCameraAngles = Vector3.new(0, 0, 0)
local PlayerCamera = game.Workspace.CurrentCamera

local TerminalAssetsFolder = script:WaitForChild("Assets")
local BackButtonGui = TerminalAssetsFolder:WaitForChild("TerminalBackButtonGui")
local GuiBackButton = BackButtonGui:WaitForChild("BackButton")
GuiBackButton.ImageTransparency = 1
BackButtonGui.Enabled = true
BackButtonGui.Parent = game.Players.LocalPlayer.PlayerGui
local TerminalInteractTime = 0.65

local TerminalGui = TermianlPart.TerminalGui
local MissionStatusFrame = TerminalGui.TerminalFrame.MissionStatusFrame
local JoinCodeFrame = MissionStatusFrame.JoinCodeFrame
local JoinStatusFrame = MissionStatusFrame.JoinStatusFrame
local IsJoinCodeShowing = false
local JoinCodeDebounce = false

local JoinCodeTweenValue = Instance.new("NumberValue")
JoinCodeTweenValue.Value = 0

local GameStatusValuesFolder = game.ReplicatedStorage.GameStatusValues
local ServerOwnerValue = GameStatusValuesFolder.ServerOwner
local LobbyRemotesFolder = game.ReplicatedStorage.RemoteEvents.LobbyRemotes

local StartButtonFrame = TerminalGui.TerminalFrame.MissionStatusFrame.StartButtonFrame
local ToggleGameStartButton = StartButtonFrame.StartButton
local StartButtonDebounce = false
local IsButtonShowingStart = true 

-- local functions
local function ServerOwnershipChanged(player)
	if player ~= game.Players.LocalPlayer then return end 
	
	-- allow the player to access the start button 
	ToggleGameStartButton.OverlayButton.Visible = false
end

-- global functions
function TerminalControler.EndLoading()	
	-- enable the camera 
	task.wait(0.5)
	CameraService.EnableAutoSet(true)
	UIEffects.FadeOffScreen(2)
	task.wait(2)
	TerminalPrompt.Enabled = true
	warn("CLIENT: Loading stopped - camera enabled")
	
	-- play the boot sound
	local TerminalOpenSoundsFolder = TerminalAssetsFolder:WaitForChild("TerminalOpenSounds")
	local computerSFX1 = TerminalOpenSoundsFolder:WaitForChild("ComputerSFX1")
	local computerSFX_Blend = TerminalOpenSoundsFolder:WaitForChild("ComputerSFX_Blend")
	computerSFX1.Parent = TermianlPart
	computerSFX_Blend.Parent = TermianlPart
	computerSFX_Blend.Volume = 0
	local computerHum = TerminalAssetsFolder.TerminalOpenSounds.Hum
	computerHum.Parent = TermianlPart

	computerSFX1.TimePosition = 21
	computerSFX1.Volume = 0
	computerSFX1:Play()
	TweenService:Create(computerSFX1, TweenInfo.new(1.5), {Volume = 0.5}):Play()

	computerHum.TimePosition = 0
	computerHum.Volume = 0
	TweenService:Create(computerHum, TweenInfo.new(1.5), {Volume = 0.05}):Play()
	computerHum:Play()

	local sfx1Coroutine = coroutine.create(function()
		local isTweening = false
		while true do
			task.wait()
			if computerSFX1.TimePosition >= 24 and isTweening == false then 
				isTweening = true

				computerSFX_Blend.TimePosition = 21 
				computerSFX_Blend.Volume = 0
				computerSFX_Blend:Play()
				local tween = TweenService:Create(computerSFX1, TweenInfo.new(1.5), {Volume = 0})
				tween.Completed:Connect(function()
					computerSFX1:Stop()
					computerSFX1.TimePosition = 21
					isTweening = false
				end)
				tween:Play()
				TweenService:Create(computerSFX_Blend, TweenInfo.new(1.5), {Volume = 0.5}):Play()

			elseif computerSFX_Blend.TimePosition >= 24 and isTweening == false then 
				isTweening = true

				computerSFX1.TimePosition = 21
				computerSFX1.Volume = 0
				computerSFX1:Play()
				local tween = TweenService:Create(computerSFX_Blend, TweenInfo.new(1.5), {Volume = 0})
				tween.Completed:Connect(function()
					computerSFX_Blend:Stop()
					computerSFX_Blend.TimePosition = 21
					isTweening = false
				end)
				tween:Play()
				TweenService:Create(computerSFX1, TweenInfo.new(1.5), {Volume = 0.5}):Play()
			end
		end
		TweenService:Create(computerSFX1, TweenInfo.new(TerminalInteractTime), {Volume = 0}):Play()
		TweenService:Create(computerSFX_Blend, TweenInfo.new(TerminalInteractTime), {Volume = 0}):Play()
		task.wait(TerminalInteractTime * 0.5)
	end)
	coroutine.resume(sfx1Coroutine)
end

function TerminalControler.OpenTerminal()
	if TerminalControler.TerminalOpening == true or TerminalControler.TerminalClosing == true or TerminalControler.TerminalOpen == true then return end 
	TerminalControler.TerminalOpening = true
	TerminalPrompt.Enabled = false
	CharControls:Disable()
	
	-- tween on the back button
	TweenService:Create(GuiBackButton, TweenInfo.new(TerminalInteractTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0), {ImageTransparency = 0.25}):Play()

	-- move the camera to the terminal
	local playerCamera = game.Workspace.CurrentCamera
	local cameraFromTerminalScale = 0
	local cameraVerticalFOV = playerCamera.FieldOfView
	local cameraHorizontalFOV = cameraVerticalFOV * (playerCamera.ViewportSize.X / playerCamera.ViewportSize.Y)

	local xOffsetValue = ((TermianlPart.Size.X + 0.75) * 0.5) / math.tan(math.rad(cameraHorizontalFOV * 0.5))
	local yOffsetValue = ((TermianlPart.Size.Y + 0.75) * 0.5) / math.tan(math.rad(cameraVerticalFOV * 0.5))
	cameraFromTerminalScale = xOffsetValue >= yOffsetValue and xOffsetValue or yOffsetValue
	
	CameraService.DisableAutoSet()
	CameraService.SwaySpring.Multiplier = Vector3.new(0.02, 0.0025, 0)
	CameraService.SwaySpring.XPeriod = 4
	CameraService.SwaySpring.YPeriod = 8
	
	local newCameraCFrame = CFrame.new(TermianlPart.Position + cameraFromTerminalScale * TermianlPart.CFrame.LookVector, TermianlPart.Position)
	CameraService.TargetPosition = newCameraCFrame.Position
	CameraService.SetTargetAngles(Vector3.new(newCameraCFrame:ToOrientation()))
	
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	
	task.wait(TerminalInteractTime)
	TerminalControler.TerminalOpening = false
	TerminalControler.TerminalOpen = true
end

function TerminalControler.CloseTerminal()
	if TerminalControler.TerminalOpening == true or TerminalControler.TerminalClosing == true or TerminalControler.TerminalOpen == false then return end 
	TerminalControler.TerminalClosing = true
	
	-- move the camera back to the player 
	CameraService.EnableAutoSet()
	
	-- tween off the back button
	TweenService:Create(GuiBackButton, TweenInfo.new(TerminalInteractTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0), {ImageTransparency = 1}):Play()
	
	task.wait(0.65)
	CharControls:Enable()
	TerminalPrompt.Enabled = true 
	TerminalControler.TerminalOpen = false
	TerminalControler.TerminalClosing = false
end

-- connections 
TerminalPrompt.Triggered:Connect(function()
	if TerminalControler.TerminalOpen == true then return end 
	TerminalControler.OpenTerminal()
end)
GuiBackButton.Activated:Connect(function()
	if TerminalControler.TerminalOpen == false then return end 
	TerminalControler.CloseTerminal()
end)

JoinCodeFrame.ShowButton.Activated:Connect(function()
	if TerminalControler.TerminalOpen == false or TerminalControler.TerminalClosing == true then return end 
	if JoinCodeDebounce == true then return end 
	JoinCodeDebounce = true
	
	-- tween on or off the join code
	local goals = false
	if IsJoinCodeShowing == false then
		IsJoinCodeShowing = true 
		goals = {Value = 1}
		
	else
		IsJoinCodeShowing = false
		goals = {Value = 0}
	end
	local tweenTime = 0.8
	TweenService:Create(JoinCodeTweenValue, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), goals):Play()
	task.wait(tweenTime)
	JoinCodeDebounce = false
end)
JoinCodeTweenValue:GetPropertyChangedSignal("Value"):Connect(function() -- 1 = show, 0 = hide
	local newVal = JoinCodeTweenValue.Value
	
	-- gradient
	if newVal <= 0.002 then
		JoinCodeFrame.CodeText.UIGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 1)
		})
		
	elseif newVal >= 0.999 then
		JoinCodeFrame.CodeText.UIGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 0)
		})
		
	else
		JoinCodeFrame.CodeText.UIGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(newVal - 0.001, 1),
			NumberSequenceKeypoint.new(newVal, 1),
			NumberSequenceKeypoint.new(1, 1)
		})
	end
	
	-- button
	JoinCodeFrame.ShowButton.Rotation = 90 - (newVal * 180)
end)

JoinStatusFrame.JoinTypeButton.Activated:Connect(function()
	if TerminalControler.TerminalOpen == false or TerminalControler.TerminalClosing == true then return end 
	if ServerOwnerValue.Value ~= game.Players.LocalPlayer then return end 
	
	-- fire the change event
	LobbyRemotesFolder.SetJoinStatus:FireServer()
end)

ToggleGameStartButton.Activated:Connect(function()
	if TerminalControler.TerminalOpen == false or TerminalControler.TerminalClosing == true then return end 
	if ServerOwnerValue.Value ~= game.Players.LocalPlayer then return end 
	if StartButtonDebounce == true then return end
	StartButtonDebounce = true
	
	-- check if the button is showing start or cancle
	if IsButtonShowingStart == true then
		LobbyRemotesFolder.StartGame:FireServer(true)
		
	else
		LobbyRemotesFolder.StartGame:FireServer(false)
	end
	StartButtonDebounce = false
end)
LobbyRemotesFolder.StartTimerUpdated.OnClientEvent:Connect(function(countdownStarted)
	if ServerOwnerValue.Value ~= game.Players.LocalPlayer then return end 
	
	-- check if the countdown has started or has been overided
	if countdownStarted == true then
		IsButtonShowingStart = false
		
		ToggleGameStartButton.BackgroundColor3 = Color3.fromRGB(131, 0, 0)
		ToggleGameStartButton.StartText.Text = "CANCEL"
		
	else
		IsButtonShowingStart = true
		
		ToggleGameStartButton.BackgroundColor3 = Color3.fromRGB(70, 131, 0)
		ToggleGameStartButton.StartText.Text = "START"
	end
end)

ServerOwnershipChanged(ServerOwnerValue.Value)
ServerOwnerValue:GetPropertyChangedSignal("Value"):Connect(function()
	ServerOwnershipChanged(ServerOwnerValue.Value)
end)

return TerminalControler
