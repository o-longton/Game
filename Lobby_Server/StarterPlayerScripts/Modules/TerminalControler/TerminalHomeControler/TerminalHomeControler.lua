-- NOTE: All sub modules (listed under modules) have been excluded for simplicity, but they mainly deal with user input and GUI animations 
-- and some server calls. 

local TerminalHomeControler = {
	TerminalHomeOpen = false
}

-- services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local PlayerDataReceiver = require(game.Players.LocalPlayer.PlayerScripts.Modules:WaitForChild("PlayerDataReceiver"))
local CharacterLoader = require(game.Players.LocalPlayer.PlayerScripts.CustomCamera.CharacterLoader)
local UIEffects = require(game.Players.LocalPlayer.PlayerScripts.Modules.UIEffects)

-- modules
local TerminalControler = false
local ArmouryControler = false
local DocumentsControler = false
local InventoryControler = false
local MissionsControler = false
local UpdatesControler = false

-- variables
local LobbyAssets = game.Workspace:WaitForChild("LobbyAssets")
local TermianlPart = LobbyAssets:WaitForChild("TerminalPart")

local TerminalGui = game.Players.LocalPlayer.PlayerGui:WaitForChild("TerminalGui")
local TerminalHomeFrame = TerminalGui.TerminalFrame.TerminalHomeFrame
local ProfileFrame = TerminalHomeFrame.ProfileFrame
TerminalHomeFrame.NameFrame.PlayerName.Text = "Welcome Back "..game.Players.LocalPlayer.DisplayName

local ButtonsFrame = TerminalHomeFrame.SelectionFrame.ButtonsFrame
local ButtonsFramesModules = {}
local UnactivatedButtonColor = Color3.fromRGB(255, 255, 255)
local ActivatedButtonColor = Color3.fromRGB(4, 222, 0)

-- local functions
local function IsInputValid()
	return not (TerminalControler.TerminalOpen == false or TerminalControler.TerminalClosing == true or TerminalControler.IsTeleporting == true
		or TerminalHomeControler.TerminalHomeOpen == false or TerminalControler.LoadingFrameOpen == true)
end

-- global functions
function TerminalHomeControler.Init()
	-- modules
	TerminalControler = require(script.Parent)
	
	ArmouryControler = require(script:WaitForChild("ArmouryControler"))
	DocumentsControler = require(script:WaitForChild("DocumentsControler"))
	InventoryControler = require(script:WaitForChild("InventoryControler"))
	MissionsControler = require(script:WaitForChild("MissionsControler"))
	UpdatesControler = require(script:WaitForChild("UpdatesControler"))
	ButtonsFramesModules = {
		[ButtonsFrame.ArmouryButton] = ArmouryControler,
		[ButtonsFrame.DocumentsButton] = DocumentsControler,
		[ButtonsFrame.InventoryButton] = InventoryControler,
		[ButtonsFrame.MissionsButton] = MissionsControler,
		[ButtonsFrame.UpdatesButton] = UpdatesControler
	}
	
	-------------------------------------------------------
	-- set up the profile frame
	local characterViewport = ProfileFrame.CharacterViewport
	
	local viewportCamera = Instance.new("Camera")
	viewportCamera.Parent = characterViewport
	characterViewport.CurrentCamera = viewportCamera
	
	local playerChar = game.Players.LocalPlayer.Character
	playerChar.Archivable = true
	local charClone = playerChar:Clone()
	playerChar.Archivable = false
	
	CharacterLoader.SetCharTransparency(0, charClone) -- char may be cloned whilst camera is active, so set transparecny back
	
	local worldModel = Instance.new("WorldModel", characterViewport)
	charClone.Parent = worldModel
	charClone:PivotTo(CFrame.new(Vector3.new(0, 0, 0)))
	
	viewportCamera.CFrame = CFrame.lookAt(charClone.HumanoidRootPart.Position + charClone.HumanoidRootPart.CFrame.LookVector * 4.5 + Vector3.new(0, 2, 0), charClone.UpperTorso.Position)
	
	-- data connections
	local creditsData = PlayerDataReceiver.WaitForData("Credits")
	ProfileFrame.CreditsText.Text = "CREDITS: "..creditsData.Value
	creditsData.Changed:Connect(function(newVal)
		ProfileFrame.CreditsText.Text = "CREDITS: "..newVal
	end)
	
	local missionsCompletedData = PlayerDataReceiver.WaitForData("MissionsCompleted")
	ProfileFrame.MissionsCompletedText.Text = "MISSIONS COMPLETED: "..missionsCompletedData.Value
	missionsCompletedData.Changed:Connect(function(newVal)
		ProfileFrame.MissionsCompletedText.Text = "MISSIONS COMPLETED: "..newVal
	end)
	
	-- buttons connections
	for FrameButton, buttonModule in pairs(ButtonsFramesModules) do
		FrameButton.Activated:Connect(function()
			if IsInputValid() == false then return end 

			-- open the module
			for _, module in pairs(ButtonsFramesModules) do
				module.CloseScreen()
			end
			buttonModule.OpenScreen()

			-- set the button colours
			for button, _ in pairs(ButtonsFramesModules) do
				button.Line.BackgroundColor3 = UnactivatedButtonColor
				button.ButtonText.TextColor3 = UnactivatedButtonColor
			end
			FrameButton.Line.BackgroundColor3 = ActivatedButtonColor
			FrameButton.ButtonText.TextColor3 = ActivatedButtonColor
		end)
	end

end

function TerminalHomeControler.OpenScreen(overideSound)
	TerminalHomeControler.TerminalHomeOpen = true
	TerminalHomeFrame.Visible = true
	if overideSound ~= true then UIEffects.PlaySound() end 
end

function TerminalHomeControler.CloseScreen()
	TerminalHomeControler.TerminalHomeOpen = false
	TerminalHomeFrame.Visible = false
end

-- connections 
TerminalHomeFrame.BackButton.Activated:Connect(function()
	if IsInputValid() == false then return end 
	
	-- open the login screen
	TerminalControler.StartLoadingAnim()
	TerminalHomeControler.CloseScreen()
	task.wait(math.random(90, 175)/100)
	TerminalControler.OpenScreen()
	TerminalControler.StopLoadingAnim()
end)

return TerminalHomeControler

