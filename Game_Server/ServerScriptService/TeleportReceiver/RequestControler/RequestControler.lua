local RequestControler = {
	ReservedServerAccessCode = false,
	ServerCode = false,
	PlayersQueue = false,
	NumPlayersPending = 0,
	TestingServer = game:GetService("RunService"):IsStudio()
}
RequestControler.PrivateServerId = RequestControler.TestingServer == false and game.PrivateServerId or 12345
math.randomseed(os.clock())

-- services
local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local PlayersControler = require(game.ServerScriptService.PlayersControler)
local RequestConfig = require(script.RequestConfig)
local GameConfig = require(game.ReplicatedStorage.Modules.GameConfig)

-- variables
local codeToServerAccessCode = DataStoreService:GetDataStore("Code_To_Reserved_Server_Access_Code_Store")
local serverIdToServerAccessCode = MemoryStoreService:GetSortedMap("Server_Id_To_Reserved_Server_Access_Code_Queue")

local CharacterTable = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V",
	"W", "X", "Y", "Z", "1", "2", "3", "4", "5", "6", "7", "8", "9", [0] = "0"}

-- local functions
local function GenerateServerCode()
	local secTime = os.clock()
	secTime -= math.floor(secTime / 3600) * 3600

	local mins = tostring(math.floor(secTime / 60))
	local sec = tostring(secTime - mins*60)
	local codeStr = string.sub(mins, string.len(mins), string.len(mins))..sec
	local periodPos, _ = string.find(codeStr, ".", 1, true)
	codeStr = string.sub(codeStr ,1, periodPos - 1)..string.sub(codeStr, periodPos + 1, periodPos + 3)..tostring(math.random(0, 9))

	local strIndex = {}
	for i = 1, string.len(codeStr) do
		strIndex[i] = i
	end

	local formattedCode = ""
	for index, value in pairs(strIndex) do
		if tonumber(string.sub(codeStr, index, index)) ~= 0 then
			if CharacterTable[tonumber(string.sub(codeStr, index, index + 1))] ~= nil then
				formattedCode = formattedCode..CharacterTable[tonumber(string.sub(codeStr, index, index + 1))]
				strIndex[index + 1] = nil
				continue
			end
		end

		formattedCode = formattedCode..CharacterTable[tonumber(string.sub(codeStr, index, index))]
	end
	return formattedCode
end

-- global functions
function RequestControler.GetGameConfig()
	-- attempt to get the game config
	for i = 1, RequestConfig.GameConfig.MaxGetAttempts do
		local getSuccess, getResult = pcall(function()
			return serverIdToServerAccessCode:GetAsync(RequestControler.PrivateServerId)
		end)

		-- check if the call was a success
		if getSuccess and RequestControler.TestingServer == false then
			if getResult == nil then
				task.wait(RequestConfig.AccessCode.SaveRetryInterval)
				
			elseif getResult.AccessCode ~= nil and getResult.ModeCode ~= nil then
				RequestControler.PlayersQueue = MemoryStoreService:GetQueue("PLAYERS_QUEUE: "..getResult.ModeCode)
				RequestControler.ReservedServerAccessCode = getResult.AccessCode
				return true, getResult
				
			else
				return false 
			end
			
		elseif getSuccess and RequestControler.TestingServer then
			RequestControler.ReservedServerAccessCode = 12345
			RequestControler.PlayersQueue = MemoryStoreService:GetQueue("PLAYERS_QUEUE: ".."1")
			return true, {ModeCode = 1}
			
		else
			task.wait(RequestConfig.GameConfig.GetRetryInterval)
		end
	end
	return false
end

function RequestControler.GenerateServerCode()
	-- attempt to generate a code 
	for i = 1, RequestConfig.ServerCode.MaxGenerateAttempts do
		local code = GenerateServerCode()
		
		-- attempt to save the code
		for i = 1, RequestConfig.ServerCode.MaxSaveAttempts do
			local codeInUse = false
			local saveSuccess, _ = pcall(function()
				return codeToServerAccessCode:UpdateAsync(code, function(currentValue)
					-- check if a value already exists
					if currentValue == nil then
						return RequestControler.ReservedServerAccessCode
						
					else
						codeInUse = true 
						return nil
					end
				end)
			end)
			
			-- check if the call was a success
			if saveSuccess == true and codeInUse == false then
				RequestControler.ServerCode = code
				return true, code
				
			elseif codeInUse == true then
				task.wait(math.random(1, 100) / 100)
				break -- try to generate a new code
				
			else
				task.wait(RequestConfig.ServerCode.GenerateRetryInterval)
			end
		end 
	end 
	return false 
end

function RequestControler.RemoveServerCode()
	-- attempt to remove the code
	for i = 1, RequestConfig.ServerCode.MaxRemoveAttempts do
		local removeSuccess, _ = pcall(function()
			return codeToServerAccessCode:RemoveAsync(RequestControler.ServerCode)
		end)
		
		-- check for a success
		if removeSuccess == true then
			return true
			
		else
			task.wait(RequestConfig.ServerCode.RemoveRetryInterval)
		end
	end
end

function RequestControler.InvitePlayer()
	-- attempt to get a player from the queue
	local playerUserId, id = nil, nil
	for i = 1, RequestConfig.Queue.MaxGetAttempts do
		local success, _ = pcall(function()
			playerUserId, id = RequestControler.PlayersQueue:ReadAsync(1, false, RequestConfig.Queue.MaxWaitForItemTime)
			playerUserId = playerUserId[1]
		end)
		
		if success then break end 
		task.wait(RequestConfig.Queue.GetRetryInterval)
	end
	if playerUserId == nil then return false end
	
	-- attempt to send a invite to the player
	local publishSuccess = false
	for i = 1, RequestConfig.Publish.MaxAttempts do
		publishSuccess, _ = pcall(function()
			MessagingService:PublishAsync(playerUserId, RequestControler.ReservedServerAccessCode)
		end)
		if publishSuccess == true then break end 
		task.wait(RequestConfig.Publish.RetryInterval)
	end
	if publishSuccess == false then return end 
	
	-- remove the player from the queue
	for i = 1, RequestConfig.Queue.MaxRemoveAttempts do
		local removeSuccess, _ = pcall(function()
			RequestControler.PlayersQueue:RemoveAsync(id)
		end)
		if removeSuccess == true then 
			return true, playerUserId
		end 
		task.wait(RequestConfig.Queue.RemoveRetryInterval)
	end
	return true 
end

return RequestControler
