local TerminalControler = {
	TerminalOpen = false,
	TerminalClosing = false,
	TerminalOpening = false,
	LoginFrameOpen = true,
	LoadingFrameOpen = false,
	IsTeleporting = false,
	TerminalGui = false
}

-- services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CustomCamera = game.Players.LocalPlayer.PlayerScripts:WaitForChild("CustomCamera")
local CameraService = require(CustomCamera:WaitForChild("CameraService"))
CameraService.SetUp() -- char is also loaded
CameraService.Enable()
local UIEffects = require(game.Players.LocalPlayer.PlayerScripts.Modules:WaitForChild("UIEffects"))
local Debris = game:GetService("Debris")

-- modules
local TerminalHomeControler = false
local DocumentsControler = false

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

local TerminalGui = game.Players.LocalPlayer.PlayerGui:WaitForChild("TerminalGui")
TerminalControler.TerminalGui = TerminalGui
TerminalGui.Adornee = TermianlPart
local LoginFrame = TerminalGui.TerminalFrame.LoginScreen
local LoadingFrame = TerminalGui.TerminalFrame.LoadingScreen

local AdminModulesFolder = script.Parent:WaitForChild("AdminModules")
local SoundsDumpFolder = script.Parent:WaitForChild("SoundsDump")
local TerminalAdminRemotesFolder = game.ReplicatedStorage.RemoteEvents.TerminalAdminRemotes
local CheckAdminCodeRemote = TerminalAdminRemotesFolder.CheckAdminCode

local LoadingBarsNames = {"A", "B", "C", "D", "E", "F", "G"}
local LoadingCallsIndex = {}

-- local functions
local function IsInputValid()
	return not (TerminalControler.TerminalOpen == false or TerminalControler.TerminalClosing == true or TerminalControler.IsTeleporting == true
		or TerminalControler.LoginFrameOpen == false or TerminalControler.LoadingFrameOpen == true)
end

-- global functions
function TerminalControler.Init()
	TerminalHomeControler = require(script.TerminalHomeControler)
	DocumentsControler = require(script.TerminalHomeControler.DocumentsControler)
end

function TerminalControler.EndLoading()
	-- move the character
	PlayerChar:PivotTo(CFrame.lookAt(LobbyAssets.CharLocation.Position, LobbyAssets.CharLocation.Position + LobbyAssets.CharLocation.CFrame.LookVector))
	
	-- enable the camera 
	task.wait(0.5)
	CameraService.EnableAutoSet(true)
	UIEffects.FadeOffScreen(2)
	task.wait(2)
	TerminalPrompt.Enabled = true
	warn("CLIENT: Loading stopped - camera enabled")
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
	
	-- play the boot sound
	local computerSFX1 = TerminalAssetsFolder.TerminalOpenSounds.ComputerSFX1
	local computerSFX_Blend = TerminalAssetsFolder.TerminalOpenSounds.ComputerSFX_Blend
	computerSFX_Blend.Volume = 0
	local computerHum = TerminalAssetsFolder.TerminalOpenSounds.Hum
	
	computerSFX1.TimePosition = 3
	computerSFX1.Volume = 0.5
	computerSFX1:Play()
	
	computerHum.TimePosition = 0
	computerHum.Volume = 0
	
	local sfx1Coroutine = coroutine.create(function()
		local isTweening = false
		while TerminalControler.TerminalClosing == false do
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
	
	-- tween the boot frame
	local bootFrame1 = TerminalGui.BootFrame1
	local bootFrame2 = TerminalGui.BootFrame2
	
	bootFrame1.Size = UDim2.fromScale(0, 0)
	bootFrame1.BackgroundTransparency = 0
	bootFrame1.Visible = true
	bootFrame2.Visible = false
	
	task.wait(1)
	TweenService:Create(bootFrame1, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Size = UDim2.fromScale(1.275, 1.275)}):Play()
	task.wait(0.25)
	bootFrame2.Visible = true
	TweenService:Create(bootFrame1, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {BackgroundTransparency = 1}):Play()
	TweenService:Create(computerHum, TweenInfo.new(0.25), {Volume = 0.025}):Play()
	
	task.wait(3.5)
	TerminalAssetsFolder.TerminalOpenSounds.TerminalFrameOpen:Play()
	task.wait(0.15)
	TerminalGui.TerminalFrame.Visible = true
	bootFrame1.Visible = false
	bootFrame2.Visible = false
	
	TerminalControler.TerminalOpen = true
	TerminalControler.TerminalOpening = false
end

function TerminalControler.CloseTerminal()
	if TerminalControler.TerminalOpening == true or TerminalControler.TerminalClosing == true or TerminalControler.TerminalOpen == false then return end 
	TerminalControler.TerminalClosing = true
	
	-- move the camera back to the player 
	CameraService.EnableAutoSet()
	
	-- tween off the back button
	TweenService:Create(GuiBackButton, TweenInfo.new(TerminalInteractTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0), {ImageTransparency = 1}):Play()
	
	-- close the terminal frame and sounds
	local computerSFX2 = TerminalAssetsFolder.TerminalOpenSounds.ComputerSFX2
	local computerHum = TerminalAssetsFolder.TerminalOpenSounds.Hum
	
	computerSFX2.TimePosition = 34
	computerSFX2.Volume = 0
	computerSFX2:Play()
	TweenService:Create(computerHum, TweenInfo.new(0.25), {Volume = 0}):Play()
	TweenService:Create(computerSFX2, TweenInfo.new(0.4), {Volume = 0.5}):Play()
	
	local bootFrame1 = TerminalGui.BootFrame1
	bootFrame1.Size = UDim2.fromScale(1.275, 1.275)
	bootFrame1.BackgroundTransparency = 1
	bootFrame1.Visible = true
	
	TweenService:Create(bootFrame1, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {BackgroundTransparency = 0}):Play()
	task.wait(0.15)
	TerminalGui.TerminalFrame.Visible = false
	TweenService:Create(bootFrame1, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Size = UDim2.fromScale(0, 0)}):Play()
	task.wait(0.15)
	bootFrame1.Visible = false
	
	task.wait(0.45)
	CharControls:Enable()
	task.wait(0.65)
	TerminalPrompt.Enabled = true 
	TerminalControler.TerminalOpen = false
	TerminalControler.TerminalClosing = false
end

function TerminalControler.OpenScreen(overideSound)
	TerminalControler.LoginFrameOpen = true
	LoginFrame.Visible = true
	if overideSound ~= true then UIEffects.PlaySound() end 
end

function TerminalControler.CloseScreen()
	TerminalControler.LoginFrameOpen = false
	LoginFrame.Visible = false
end

function TerminalControler.StartLoadingAnim()
	TerminalControler.LoadingFrameOpen = true
	LoadingFrame.Visible = true
	local index = os.clock()
	LoadingCallsIndex[index] = true
	
	local loadingRoutine = coroutine.create(function()
		for _, barName in pairs(LoadingBarsNames) do
			local bar = LoadingFrame.BarsFrame[barName]
			bar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		end
		
		while LoadingCallsIndex[index] == true do
			
			if LoadingCallsIndex[index] ~= true then break end 
			task.wait(0.275)
			if LoadingCallsIndex[index] ~= true then break end 
			
			for _, barName in pairs(LoadingBarsNames) do
				local bar = LoadingFrame.BarsFrame[barName]
				bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				
				if LoadingCallsIndex[index] ~= true then break end 
				task.wait(0.275)
				if LoadingCallsIndex[index] ~= true then break end 
			end
			for _, barName in pairs(LoadingBarsNames) do
				local bar = LoadingFrame.BarsFrame[barName]
				if LoadingCallsIndex[index] ~= true then break end 
				bar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			end
		end
	end)
	coroutine.resume(loadingRoutine)
end

function TerminalControler.StopLoadingAnim()
	for index, _ in pairs(LoadingCallsIndex) do
		LoadingCallsIndex[index] = nil
	end
	LoadingFrame.Visible = false
	TerminalControler.LoadingFrameOpen = false
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

LoginFrame.ResearcherButton.Activated:Connect(function()
	if IsInputValid() == false then return end
	
	-- open the main frame
	TerminalControler.StartLoadingAnim()
	TerminalControler.CloseScreen()
	task.wait(math.random(125, 200)/100)
	TerminalHomeControler.OpenScreen()
	TerminalControler.StopLoadingAnim()
end)
LoginFrame.AdminButton.Activated:Connect(function()
	if IsInputValid() == false then return end
	
	-- local functions
	local function endRequest()
		task.wait(math.random(125, 150)/100)
		TerminalControler.StopLoadingAnim()
		TerminalControler.OpenScreen(true)
		TerminalAssetsFolder.ErrorSound:Play()
		return
	end
	local function openAdminModule(module)
		task.wait(math.random(125, 150)/100)
		TerminalControler.StopLoadingAnim()
		module.OpenDocument("Admin")
	end
	
	-- request with the code
	TerminalControler.StartLoadingAnim()
	TerminalControler.CloseScreen()
	local inputCode = LoginFrame.AdminFrame.AdminTextBox.Text
	LoginFrame.AdminFrame.AdminTextBox.Text = ""
	local identifier = CheckAdminCodeRemote:InvokeServer(inputCode)
	if identifier == false or identifier == nil then
		return endRequest()
	end
	if identifier == "CheckFolder" then
		local adminModule = AdminModulesFolder:WaitForChild(inputCode, 4)
		if adminModule == nil then
			return endRequest()
		end
		return openAdminModule(require(adminModule))
	end
	
	-- wait for the module
	local adminModule = game.Players.LocalPlayer.PlayerGui:WaitForChild(identifier, 8)
	if adminModule == nil then
		return endRequest()
	end
	
	-- as new module set up with documents 
	adminModule.Parent = AdminModulesFolder
	adminModule.Name = inputCode
	DocumentsControler.AdminCodeAdded(adminModule.Name, adminModule)
	
	-- open the module
	adminModule = require(adminModule)
	openAdminModule(adminModule)
end)

return TerminalControler
