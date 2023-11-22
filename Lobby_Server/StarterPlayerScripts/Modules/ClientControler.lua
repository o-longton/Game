-- local functions
local function EndLoading()
	-- require all modules
	local TerminalControler = require(game.Players.LocalPlayer.PlayerScripts:WaitForChild("Modules"):WaitForChild("TerminalControler"))-- only load once gui in workspace is loaded
	
	for _, module in script.Parent:GetDescendants() do
		if module:IsA("ModuleScript") then
			local reqModule = require(module)
			if reqModule.Init ~= nil then reqModule.Init() end 
		end
	end
	
	-- end loading
	TerminalControler.EndLoading()
end

-- remotes
local RemotesFolder = game.ReplicatedStorage:WaitForChild("RemoteEvents")
local DataRemotes = game.ReplicatedStorage.RemoteEvents:WaitForChild("DataRemotes")

local ModulesLoadedEvent = game.ReplicatedStorage.RemoteEvents.DataRemotes:WaitForChild("ModulesLoaded")
local PlayerDataReceiver = require(script.Parent:WaitForChild("PlayerDataReceiver"))
ModulesLoadedEvent:FireServer() -- only fire once the data receiver has been loaded so all other modules have access to the players data

-- loading
if game.Players.LocalPlayer:GetAttribute("LoadingCompleted") == true then
	EndLoading()
	
else
	game.Players.LocalPlayer:GetAttributeChangedSignal("LoadingCompleted"):Connect(function()
		if game.Players.LocalPlayer:GetAttribute("LoadingCompleted") == false then return end 
		EndLoading()
	end)
end
