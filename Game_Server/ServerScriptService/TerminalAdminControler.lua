local HttpService = game:GetService("HttpService")
local PlayersControler = require(game.ServerScriptService.PlayersControler)

local AdminModulesFolder = game.ServerStorage.AdminModules
local TerminalAdminRemotes = game.ReplicatedStorage.RemoteEvents.TerminalAdminRemotes
local PlayerDebounce = {}
local PlayerDocsReplicated = {}
local CodeRequestDebounce = 0.5

-- connections
game.Players.PlayerAdded:Connect(function(player)
	PlayerDebounce[player] = os.clock()
	PlayerDocsReplicated[player] = {}
end)
game.Players.PlayerRemoving:Connect(function(player)
	PlayerDebounce[player] = nil
	PlayerDocsReplicated[player] = nil
end)

-- remote function
TerminalAdminRemotes.CheckAdminCode.OnServerInvoke = function(player, code)
	if os.clock() - PlayerDebounce[player] < CodeRequestDebounce then return false end 
	PlayerDebounce[player] = os.clock()

	-- return the instance
	local codeModule = AdminModulesFolder:FindFirstChild(code)	
	if codeModule == nil then return false end 
	
	-- check if the player has the module or if it has been replicated
	local documentsTable = PlayersControler.GetPlayerData(player, "Documents")
	if table.find(documentsTable, code) ~= nil then return "CheckFolder" end -- in both cases the module should be replicated soon 
	if PlayerDocsReplicated[player][code] == true then return "CheckFolder" end 
	PlayerDocsReplicated[player][code] = true
	
	-- replicate the module to the client
	local identifier = HttpService:GenerateGUID(false)
	local moduleClone = codeModule:Clone()
	moduleClone.Name = identifier
	moduleClone.Parent = player.PlayerGui
	
	-- update the docs value
	local docsTable = PlayersControler.GetPlayerData(player, "Documents")
	table.insert(docsTable, code)
	PlayersControler.SetPlayerData(player, "Documents", docsTable)
	
	return identifier
end
TerminalAdminRemotes.GetAdminModules.OnServerInvoke = function(player)
	local docsTable = PlayersControler.GetPlayerData(player, "Documents")
	
	-- replicate any documents
	local docsFolder = Instance.new("Folder")
	local identifier = HttpService:GenerateGUID(false)
	docsFolder.Name = identifier
	
	for _, code in pairs(docsTable) do
		if PlayerDocsReplicated[player][code] == true then continue end 
		
		-- get the module
		PlayerDocsReplicated[player][code] = true
		
		local codeModule = AdminModulesFolder:FindFirstChild(code)	
		if codeModule == nil then continue end 
		local moduleClone = codeModule:Clone()
		moduleClone.Parent = docsFolder
	end
	
	-- check if any documents were found 
	if #docsFolder:GetChildren() == 0 then
		docsFolder:Destroy()
		return false
		
	else
		docsFolder.Parent = player.PlayerGui
		return identifier
	end
end
